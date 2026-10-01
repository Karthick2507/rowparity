-- account:    sa-dataapp-yield
-- skeleton:   0032dacaad697dffe1d9f8dc49607dfe
-- pattern:    b9494e010060acf55b0805ef7c649364  (698 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
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
  APPROX_DISTINCT(request__transaction_id) AS ad_request,
  COUNT_IF(BITWISE_AND(auction__auction_status, 2) > 0) AS auction_request,
  COUNT_IF(
    BITWISE_AND(auction__auction_status, 2) > 0
    AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0
    AND BITWISE_AND(COALESCE(auction__extra_flags, 0), 2) = 0
  ) AS no_smart_bidding_auction_request,
  COUNT_IF(BITWISE_AND(auction__auction_status, 4) > 0) AS auction_response,
  COUNT_IF(
    BITWISE_AND(auction__auction_status, 4) > 0
    AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0
    AND BITWISE_AND(COALESCE(auction__extra_flags, 0), 2) = 0
  ) AS no_smart_bidding_auction_response,
  COUNT_IF(BITWISE_AND(auction__auction_status, 8) > 0) AS auction_response_with_bids,
  COUNT_IF(
    BITWISE_AND(auction__auction_status, 8) > 0
    AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0
    AND BITWISE_AND(COALESCE(auction__extra_flags, 0), 2) = 0
  ) AS no_smart_bidding_auction_response_with_bids,
  COUNT_IF(auction__error = 'http_error') AS auction_http_error,
  SUM(
    IF(
      BITWISE_AND(auction__auction_status, 2) > 0,
      REDUCE(auction__impression__equivalent_opportunity_number, 0, (s, x) -> s + x, s -> s),
      0
    )
  ) AS auction_opportunity,
  SUM(
    IF(
      BITWISE_AND(auction__auction_status, 2) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0
      AND BITWISE_AND(COALESCE(auction__extra_flags, 0), 2) = 0,
      REDUCE(auction__impression__equivalent_opportunity_number, 0, (s, x) -> s + x, s -> s),
      0
    )
  ) AS no_smart_bidding_auction_opportunity
FROM ${bcv_auction}
CROSS JOIN UNNEST(request__context__ab_test_item__bucket_id) AS abtest(bucket_id)
LEFT JOIN db.default.d_network AS nw
  ON nw.id = auction__network_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = auction__dsp_id
WHERE
  auction__integration_type = 'normal'
  AND CARDINALITY(request__context__ab_test_item__bucket_id) > 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8
