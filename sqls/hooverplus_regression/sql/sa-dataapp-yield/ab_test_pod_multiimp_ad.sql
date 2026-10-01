-- account:    sa-dataapp-yield
-- skeleton:   5ace8e1786b0d47889c10217ff816e04
-- pattern:    dc11520fe777c751106183715bc152ac  (697 execution(s))
-- in suite:   daily commitment
-- hoover:     candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  COALESCE(request__server_group, 'na') AS server_group,
  COALESCE(abtest.bucket_id, -1) AS bucket_id,
  COALESCE(auction__network_id, -1) AS auction_network_id,
  COALESCE(nw.name, 'na') AS auction_network_name,
  COALESCE(auction__dsp_id, -1) AS dsp_id,
  COALESCE(dsp.name, 'na') AS dsp_name,
  COALESCE(auction__buyer_platform_id, -1) AS buyer_platform_id,
  COUNT_IF(BITWISE_AND(candidate__bid_status, 1) > 0) AS bids_received,
  COUNT_IF(
    BITWISE_AND(candidate__bid_status, 1) > 0
    AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0
    AND BITWISE_AND(COALESCE(auction__extra_flags, 0), 2) = 0
  ) AS no_smart_bidding_bids_received,
  COUNT_IF(BITWISE_AND(candidate__bid_status, 8) > 0) AS ad_delivered,
  COUNT_IF(
    BITWISE_AND(candidate__bid_status, 8) > 0
    AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0
    AND BITWISE_AND(COALESCE(auction__extra_flags, 0), 2) = 0
  ) AS no_smart_bidding_ad_delivered
FROM ${bcv_candidate}
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
