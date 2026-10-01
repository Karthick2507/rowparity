-- account:    publisher
-- skeleton:   74c70e80f38bd6171b6ab9c41bcbc8bf
-- pattern:    2515b1df0051a6c03ae39919eadd1c86  (34 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  fact.day AS day,
  listing.name AS inventory_split_listing_name,
  fact.network_id AS inventroy_split_seller_id,
  seller_nw.name AS inventory_split_seller_name,
  io_nw.id AS inventory_partner_network_id,
  io_nw.name AS inventory_partner_network_name,
  SUM(total_avails_in_played_slot) AS total_avails_in_played_slot,
  SUM(total_unfilled_avails_in_played_slot) AS unfilled_avails_in_played_slot,
  SUM(selected_ads_primary) AS selected_ads_in_played_slot_primary,
  SUM(net_counted_ads) AS net_counted_ads,
  SUM(net_delivered_impression) AS net_delivered_impressions,
  IF(
    SUM(net_counted_ads + total_unfilled_avails_in_played_slot) = 0,
    0.0000,
    ROUND(
      SUM(direct_sold_paying + reseller_sold) * 1.0000 / SUM(net_counted_ads + total_unfilled_avails_in_played_slot),
      4
    )
  ) AS str
FROM (
  SELECT
    DATE_FORMAT(UTC_TO_NETWORKLOCAL(ack__timestamp, seller.network_id), '%y%m%d') AS day,
    seller.network_id,
    seller.carriage_inventory_owner_id,
    seller.carriage_listing_split_unit_id,
    SUM(ack__metrics__slot_impression * seller.total_avails_in_played_slot) AS total_avails_in_played_slot,
    SUM(ack__metrics__slot_impression * seller.total_unfilled_avails_in_played_slot) AS total_unfilled_avails_in_played_slot,
    SUM(
      ack__metrics__slot_impression * CARDINALITY(FILTER(ads_in_slot__advertisement__flags, flags -> BITWISE_AND(flags, 32) = 0))
    ) AS selected_ads_primary,
    0 AS net_counted_ads,
    0 AS net_delivered_impression,
    0 AS direct_sold_paying,
    0 AS reseller_sold
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(partners__carriage_listing_split_unit_id, partners__network_id, partners__carriage_inventory_owner_id, partners__avails_category__total_avails_in_played_slot, partners__avails_category__total_unfilled_avails, partners__avails_category__total_unfilled_avails_in_played_slot) AS seller(carriage_listing_split_unit_id, network_id, carriage_inventory_owner_id, total_avails_in_played_slot, total_unfilled_avails, total_unfilled_avails_in_played_slot)
  WHERE
    (
      (
        (
          (
            ack__ack_entity_type = 'slot' AND ack__traffic_type = 0
          )
          AND seller.network_id = 376521
        )
        AND BITWISE_AND(COALESCE(slot__flags, 0), 64) = 0
      )
      AND seller.carriage_inventory_owner_id > 0
    )
    AND ack__metrics__slot_impression > 0
  GROUP BY
    1,
    2,
    3,
    4
  UNION ALL
  SELECT
    DATE_FORMAT(UTC_TO_NETWORKLOCAL(ack__timestamp, seller.network_id), '%y%m%d') AS day,
    seller.network_id,
    seller.carriage_inventory_owner_id,
    seller.carriage_listing_split_unit_id,
    0 AS total_avails_in_played_slot,
    0 AS total_unfilled_avails_in_played_slot,
    0 AS selected_ads_primary,
    SUM(ack__metrics__ad_impression) AS net_counted_ads,
    SUM(
      IF(
        BITWISE_AND(advertisement__bit_flags, 2048) <> 2048
        AND BITWISE_AND(request__bit_flags, 4294967296) <> 4294967296,
        ack__metrics__ad_impression,
        0
      )
    ) AS net_delivered_impression,
    SUM(
      IF(
        seller.sales_channel = 2
        AND advertisement__placement_type_priority IN ('guaranteed', 'preemptible', 'flat_fee_sponsorship'),
        ack__metrics__ad_impression,
        0
      )
    ) AS direct_sold_paying,
    SUM(IF(seller.sales_channel <> 2, ack__metrics__ad_impression, 0)) AS reseller_sold
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(partners__carriage_listing_split_unit_id, partners__network_id, partners__carriage_inventory_owner_id, partners__network_is_ad_owner, partners__network_is_extra_item_owner, partners__sales_channel) AS seller(carriage_listing_split_unit_id, network_id, carriage_inventory_owner_id, network_is_ad_owner, network_is_extra_item_owner, sales_channel)
  WHERE
    (
      (
        (
          (
            (
              ack__ack_entity_type = 'ad' AND ack__traffic_type = 0
            )
            AND seller.network_id = 376521
          )
          AND advertisement__is_bumper = FALSE
        )
        AND (
          ack__is_private_impression = FALSE
          OR seller.network_is_ad_owner
          OR seller.network_is_extra_item_owner
        )
      )
      AND COALESCE(ack__metrics__ad_impression, 0) <> 0
    )
    AND seller.carriage_inventory_owner_id > 0
  GROUP BY
    1,
    2,
    3,
    4
) AS fact
LEFT JOIN db.default.d_inventory_owner AS io
  ON io.id = fact.carriage_inventory_owner_id
LEFT JOIN db.default.d_network AS io_nw
  ON io_nw.id = io.inventory_owner_network_id
LEFT JOIN db.default.d_network AS seller_nw
  ON seller_nw.id = fact.network_id
LEFT JOIN db.default.d_carriage_listing_split_unit AS clsu
  ON clsu.id = fact.carriage_listing_split_unit_id
LEFT JOIN db.default.d_mkpl_listing AS listing
  ON listing.id = clsu.listing_id
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6
