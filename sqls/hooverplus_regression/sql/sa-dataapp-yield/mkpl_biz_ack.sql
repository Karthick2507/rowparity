-- account:    sa-dataapp-yield
-- skeleton:   ccbdf50787225244602c4826297501e7
-- pattern:    7cc0c783df621c7a97a460502277372c  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', ack__timestamp) AS timestamp,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(vcro.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(dis.name, 'na') AS distributor_network_name,
  COALESCE(seller_id, -1) AS seller_network_id,
  COALESCE(seller_nw.name, 'na') AS seller_network_name,
  COALESCE(buyer_id, -1) AS buyer_network_id,
  COALESCE(buyer_nw.name, 'na') AS buyer_network_name,
  COALESCE(order_type, 'na') AS order_type,
  SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS ack_order_impression,
  SUM(
    COALESCE(ack__metrics__raw_ad_impression, 0) * COALESCE(order_price, 0.0) * COALESCE(
      ELEMENT_AT(
        MAP_FROM_ENTRIES(ARRAY[(62, 1.0), (49, 1.1421), (44, 1.3196), (21, 0.1097)]),
        seller_nw.default_currency_id
      ),
      1
    )
  ) AS trading_volume,
  SUM(
    IF(
      buyer_id = advertisement__ad_oo_network_id,
      COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_ad_impression,
  SUM(
    COALESCE(ack__metrics__ad_bid_won, 0) * COALESCE(ssp_clearing_revenue, 0.0) * COALESCE(
      ELEMENT_AT(
        MAP_FROM_ENTRIES(ARRAY[(62, 1.0), (49, 1.1421), (44, 1.3196), (21, 0.1097)]),
        seller_nw.default_currency_id
      ),
      1
    )
  ) AS ack_ssp_clearing_revenue
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__outbound_order_id, partners__outbound_exchange_order_id, partners__reseller_network_id, partners__network_id, partners__revenue, partners__outbound_order_type, partners__ssp_clearing_revenue) AS mkpl_info(order_id, exchange_order_id, buyer_id, seller_id, order_price, order_type, ssp_clearing_revenue)
LEFT JOIN db.default.d_network AS buyer_nw
  ON buyer_nw.id = buyer_id
LEFT JOIN db.default.d_network AS seller_nw
  ON seller_nw.id = seller_id
LEFT JOIN db.default.d_network AS vcro
  ON vcro.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS dis
  ON dis.id = request__context__network_id
WHERE
  (
    order_id > 0 OR exchange_order_id > 0
  ) AND ack__ack_entity_type = 'ad'
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
  10
