-- account:    sa-dataapp-yield
-- skeleton:   27e0adcca8b69ca224a0f55a34dd3556
-- pattern:    6d7772896e29bcf257dbc6115fb43226  (695 execution(s))
-- in suite:   daily commitment
-- hoover:     ad
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH language_map AS (
  SELECT
    MAP_AGG(id, name) AS language_map
  FROM db.default.d_lu_mkpl_standard_language
)
SELECT
  COALESCE(nw.name, 'na') AS ssp_shell_network_name,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(ad_nw.name, 'na') AS ad_network_name,
  COALESCE(listing.name, 'na') AS inbound_listing_name,
  COALESCE(o.name, 'na') AS inbound_order_name,
  COALESCE(o.transaction_type, 'na') AS inbound_order_transaction_type,
  COALESCE(plc.name, 'na') AS placement_name,
  COALESCE(pub.name, 'na') AS publisher_name,
  COALESCE(app.name, 'na') AS app_name,
  COALESCE(ctry.name, 'na') AS country_name,
  COALESCE(device.name, 'na') AS device_type_name,
  TRANSFORM(language_ids, x -> COALESCE(ELEMENT_AT(language_map, x), 'na')) AS language_names,
  COALESCE(channel.name, 'na') AS ssp_channel_name,
  COALESCE(site_domain.name, 'na') AS site_domain_name,
  COALESCE(nw2.name, 'na') AS network_name,
  COALESCE(reseller.name, 'na') AS reseller_network_name,
  COALESCE(co.name, 'na') AS content_owner_network_name,
  CASE
    WHEN supply_source_tmp = 1
    THEN 'o&o'
    WHEN supply_source_tmp = 3 AND nw2.network_type = 'full'
    THEN 'mrm2mrm'
    WHEN supply_source_tmp = 3 AND nw2.network_type = 'internal'
    THEN 'reseller tag'
    WHEN supply_source_tmp = 4
    THEN 'programmatic'
    WHEN supply_source_tmp = 5
    THEN 'partner trading(mpp)'
    WHEN supply_source_tmp = 6
    THEN 'marketplace platform exchange(mpe)'
    ELSE 'na'
  END AS supply_source,
  CASE
    WHEN sales_channel_tmp = 2
    THEN 'direct sold'
    WHEN sales_channel_tmp = 3 AND reseller.network_type = 'full'
    THEN 'mrm2mrm'
    WHEN sales_channel_tmp = 3 AND reseller.network_type = 'internal'
    THEN 'reseller tag'
    WHEN sales_channel_tmp = 4
    THEN 'programmatic'
    WHEN sales_channel_tmp = 5 AND is_pt
    THEN 'partner tag'
    WHEN sales_channel_tmp = 5
    THEN 'partner trading(mpp)'
    WHEN sales_channel_tmp = 6
    THEN 'marketplace platform exchange(mpe)'
    ELSE 'na'
  END AS sales_channel,
  tmp.*
FROM (
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    COALESCE(request__context__video_cro_network_id, -1) AS ssp_shell_network_id,
    COALESCE(request__context__network_id, -1) AS distributor_network_id,
    COALESCE(network_id, -1) AS network_id,
    COALESCE(reseller_network_id, -1) AS reseller_network_id,
    COALESCE(content_owner_network_id, -1) AS content_owner_network_id,
    role AS network_role,
    CASE
      WHEN (
        network_is_extra_item_owner = TRUE OR network_is_ad_owner = TRUE
      )
      THEN COALESCE(network_id, -1)
      ELSE -1
    END AS ad_network_id,
    COALESCE(inbound_order_id, -1) AS inbound_order_id,
    COALESCE(inbound_order_type, 'na') AS inbound_order_type,
    COALESCE(ELEMENT_AT(inbound_listing_id, 1), -1) AS inbound_listing_id,
    COALESCE(outbound_order_id, -1) AS outbound_order_id,
    COALESCE(outbound_order_type, 'na') AS outbound_order_type,
    COALESCE(ELEMENT_AT(outbound_listing_id, 1), -1) AS outbound_listing_id,
    COALESCE(outbound_exchange_order_id, -1) AS outbound_exchange_order_id,
    CASE WHEN request__is_filtered THEN 'true' ELSE 'false' END AS is_filtered,
    CASE
      WHEN network_is_extra_item_owner
      THEN COALESCE(advertisement__ad_id, -1)
      ELSE -1
    END AS ad_id,
    CASE
      WHEN network_is_extra_item_owner
      THEN COALESCE(advertisement__placement_id, -1)
      ELSE -1
    END AS placement_id,
    IF(BITWISE_AND(advertisement__extra_flags2, 128) > 0, 'true', 'false') AS bid_shading_enabled,
    IF(BITWISE_AND(advertisement__extra_flags2, 256) > 0, 'true', 'false') AS bid_shading_applied,
    COALESCE(request__global_currency_version, 'na') AS global_currency_version,
    COALESCE(global_currency_id, -1) AS global_currency_id,
    COALESCE(request__context__standard_publisher_id, -1) AS publisher_id,
    COALESCE(request__context__standard_app_id, -1) AS app_id,
    COALESCE(request__context__standard_site_domain_id, -1) AS site_domain_id,
    COALESCE(request__context__standard_ssp_channel_id, -1) AS ssp_channel_id,
    COALESCE(visitor__country_id, -1) AS country_id,
    COALESCE(visitor__standard_device_type_child_id, -1) AS device_type_id,
    COALESCE(request__context__standard_language_ids, ARRAY[]) AS language_ids,
    CASE
      WHEN COALESCE(bidding_revenue, 0) * 1000 <= 15
      THEN '0-15'
      WHEN COALESCE(bidding_revenue, 0) * 1000 > 15
      AND COALESCE(bidding_revenue, 0) * 1000 <= 20
      THEN '15-20'
      WHEN COALESCE(bidding_revenue, 0) * 1000 > 20
      AND COALESCE(bidding_revenue, 0) * 1000 <= 25
      THEN '20-25'
      WHEN COALESCE(bidding_revenue, 0) * 1000 > 25
      AND COALESCE(bidding_revenue, 0) * 1000 <= 30
      THEN '25-30'
      WHEN COALESCE(bidding_revenue, 0) * 1000 > 30
      THEN '30+'
      ELSE 'na'
    END AS bid_price,
    COALESCE(request__context__response_format, -1) AS response_format,
    sales_channel AS sales_channel_tmp,
    supply_source AS supply_source_tmp,
    CASE
      WHEN BITWISE_AND(bit_flag, BITWISE_SHIFT_LEFT(1, 40, 64)) > 0
      THEN TRUE
      ELSE FALSE
    END AS is_pt,
    COALESCE(request__server_group, 'na') AS server_group,
    COALESCE(request__server_pool, 'na') AS server_pool,
    CASE
      WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
      AND request__context__request_format = 1
      THEN 'sspu vast'
      WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
      AND request__context__request_format = 7
      THEN 'sspu ortb'
      WHEN BITWISE_AND(request__extra_flags3, 1) > 0
      THEN 'streaminghub openrtb'
      WHEN BITWISE_AND(request__extra_flags2, 8) > 0
      AND COALESCE(request__server_pool, 'na') = 'ads-sfx'
      THEN 'smi bidder'
      WHEN BITWISE_AND(request__extra_flags2, 8) > 0
      THEN 'mrm bidder'
      WHEN request__delivery_method = 'gateway'
      THEN 'linear - scheduled based'
      WHEN (
        BITWISE_AND(request__extra_flags, 1024) > 0
        AND BITWISE_AND(request__extra_flags, 16384) > 0
      )
      OR BITWISE_AND(request__extra_flags, 128) > 0
      THEN 'linear - gateway dai'
      WHEN (
        BITWISE_AND(request__extra_flags, 1024) > 0
        AND BITWISE_AND(request__extra_flags, 67108864) > 0
      )
      THEN 'linear - ip player'
      WHEN BITWISE_AND(request__extra_flags, 1024) > 0
      OR request__delivery_method = 'casucpsu'
      THEN 'linear - stb dai'
      WHEN visitor__user_agent_device_type = 'set top box'
      THEN 'stb vod'
      WHEN BITWISE_AND(request__flags, 8) > 0
      AND visitor__user_agent_device_type IN ('smart tv', 'game console')
      THEN 'digital - live ott'
      WHEN BITWISE_AND(request__flags, 8) > 0
      AND NOT visitor__user_agent_device_type IN ('smart tv', 'game console')
      THEN 'digital - live others'
      WHEN BITWISE_AND(request__flags, 8) = 0
      AND visitor__user_agent_device_type IN ('smart tv', 'game console')
      THEN 'digital - non-live ott'
      WHEN BITWISE_AND(request__flags, 8) = 0
      AND NOT visitor__user_agent_device_type IN ('smart tv', 'game console')
      THEN 'digital - non-live others'
      ELSE 'na'
    END AS service_type,
    SUM(IF(advertisement__is_undeliverable = FALSE, 1, 0)) AS ad_selected_ad,
    SUM(
      IF(
        advertisement__is_undeliverable = FALSE
        AND BITWISE_AND(advertisement__flags, 32) = 0,
        1,
        0
      )
    ) AS ad_selected_ad_primary,
    SUM(
      IF(
        advertisement__is_undeliverable = FALSE
        AND BITWISE_AND(advertisement__flags, 32) > 0,
        1,
        0
      )
    ) AS ad_selected_ad_fallback,
    SUM(COALESCE(bidding_modified_revenue, 0)) AS ad_bidding_modified_revenue,
    SUM(COALESCE(bidding_original_revenue, 0)) AS ad_bidding_original_revenue,
    SUM(COALESCE(bidding_revenue, 0)) AS ad_bidding_revenue
  FROM ${bcv_ad} AS a
  CROSS JOIN UNNEST(partners__network_id, partners__inbound_order_id, partners__inbound_order_type, partners__inbound_listing_id, partners__global_currency_id, partners__network_is_extra_item_owner, partners__network_is_ad_owner, partners__supply_source, partners__content_owner_bidding_modified_revenue, partners__content_owner_bidding_original_revenue, partners__content_owner_bidding_revenue, partners__role, partners__reseller_network_id, partners__content_owner_network_id, partners__outbound_order_id, partners__outbound_order_type, partners__outbound_listing_id, partners__outbound_exchange_order_id, partners__sales_channel, partners__bit_flags) AS network(network_id, inbound_order_id, inbound_order_type, inbound_listing_id, global_currency_id, network_is_extra_item_owner, network_is_ad_owner, supply_source, bidding_modified_revenue, bidding_original_revenue, bidding_revenue, role, reseller_network_id, content_owner_network_id, outbound_order_id, outbound_order_type, outbound_listing_id, outbound_exchange_order_id, sales_channel, bit_flag)
  WHERE
    (
      (
        (
          (
            (
              request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
            )
            AND NOT advertisement__ad_id IS NULL
          )
          AND BITWISE_AND(request__extra_flags2, 8) > 0
        )
        AND role IN ('cro', 'r')
      )
      AND advertisement__is_bumper = FALSE
    )
    AND supply_source <> 4
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    36,
    37
) AS tmp
LEFT JOIN db.default.d_network AS nw
  ON nw.id = ssp_shell_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = distributor_network_id
LEFT JOIN db.default.d_network AS ad_nw
  ON ad_nw.id = tmp.ad_network_id
LEFT JOIN db.default.d_placement AS plc
  ON plc.id = placement_id
LEFT JOIN db.default.d_mkpl_order AS o
  ON o.id = inbound_order_id
LEFT JOIN db.default.d_mkpl_listing AS listing
  ON listing.id = inbound_listing_id
LEFT JOIN db.default.d_lu_mkpl_standard_publisher AS pub
  ON pub.id = publisher_id
LEFT JOIN db.default.d_lu_mkpl_standard_app AS app
  ON app.id = app_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = country_id
LEFT JOIN db.default.d_lu_mkpl_standard_device_type AS device
  ON device.id = device_type_id
LEFT JOIN db.default.d_lu_mkpl_standard_channel AS channel
  ON channel.id = ssp_channel_id
LEFT JOIN oltp.fwmrm_oltp.lu_mkpl_standard_site_domain AS site_domain
  ON site_domain.id = site_domain_id
LEFT JOIN db.default.d_network AS nw2
  ON nw2.id = tmp.network_id
LEFT JOIN db.default.d_network AS reseller
  ON reseller.id = reseller_network_id
LEFT JOIN db.default.d_network AS co
  ON co.id = content_owner_network_id
JOIN language_map
  ON 1 = 1
