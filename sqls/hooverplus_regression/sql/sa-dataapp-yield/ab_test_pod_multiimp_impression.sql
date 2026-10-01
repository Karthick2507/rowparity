-- account:    sa-dataapp-yield
-- skeleton:   3d5af8c63128ef0daaffd40e948f3fb5
-- pattern:    7d7d6ed9c06f625fcc8ccc4663d4bf6d  (696 execution(s))
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
  COALESCE(request__server_group, 'na') AS server_group,
  COALESCE(abtest.bucket_id, -1) AS bucket_id,
  COALESCE(auction__network_id, -1) AS auction_network_id,
  COALESCE(nw.name, 'na') AS auction_network_name,
  COALESCE(auction__dsp_id, -1) AS dsp_id,
  COALESCE(dsp.name, 'na') AS dsp_name,
  COALESCE(auction__buyer_platform_id, -1) AS buyer_platform_id,
  SUM(COALESCE(ack__metrics__ad_impression, 0)) AS ack_ad_impression,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0
      AND BITWISE_AND(COALESCE(auction__extra_flags, 0), 2) = 0,
      COALESCE(ack__metrics__ad_impression, 0),
      0
    )
  ) AS no_smart_bidding_ack_ad_impression,
  SUM(
    COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__ad_impression, 0) / 1000
  ) AS ack_ad_revenue,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0
      AND BITWISE_AND(COALESCE(auction__extra_flags, 0), 2) = 0,
      COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__ad_impression, 0) / 1000,
      0
    )
  ) AS no_smart_bidding_ack_ad_revenue
FROM ${bcv_ack}
CROSS JOIN UNNEST(request__context__ab_test_item__bucket_id) AS abtest(bucket_id)
LEFT JOIN db.default.d_network AS nw
  ON nw.id = auction__network_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = auction__dsp_id
WHERE
  (
    candidate__integration_type = 'openrtb_normal'
    AND CARDINALITY(request__context__ab_test_item__bucket_id) > 0
  )
  AND BITWISE_AND(candidate__bid_status, 1) > 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8
