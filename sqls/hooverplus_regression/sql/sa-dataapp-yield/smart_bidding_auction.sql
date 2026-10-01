-- account:    sa-dataapp-yield
-- skeleton:   88a7e913cf476d81f6e4942e8331b0e7
-- pattern:    70f2ea64a36e24e033af7f832d864efb  (697 execution(s))
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
  CASE
    WHEN auction__integration_type = 'normal'
    THEN 'fullstack_non_pg'
    WHEN auction__integration_type = 'pg_td'
    THEN 'fullstack_pg'
    WHEN auction__integration_type = 'sfx'
    THEN 'sfx_openrtb'
    ELSE 'sfx_tag'
  END AS market_integration_type,
  COALESCE(auction__dsp_id, -1) AS dsp_id,
  COALESCE(d_dsp.name, 'na') AS dsp_name,
  COALESCE(auction__network_id, -1) AS auction_network_id,
  COALESCE(d_network.name, 'na') AS auction_network_name,
  IF(
    auction__network_id = 523319
    AND CONTAINS(partners__entity_source, 'auction_upstream'),
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
    -1
  ) AS auction_upstream_network_id,
  COALESCE(auc_upstream.name, 'na') AS auction_upstream_network_name,
  COALESCE(NULLIF(auction__ab_test_items__bucket_id, ARRAY[]), ARRAY[-1]) AS bucket_id,
  COALESCE(NULLIF(auction__ab_test_items__collection_id, ARRAY[]), ARRAY[-1]) AS collection_id,
  BITWISE_AND(COALESCE(auction__flags, 0), 1075838976) > 0 AS is_smart_bidding_traffic,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_request_sent,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 2097152) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_request_smartly_bidding_baseline,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_request_smartly_bidding_probe_original,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_request_smartly_bidding_probe_additional,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 8388608) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_request_smartly_bidding_feedback_original,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 8388608) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_request_smartly_bidding_feedback_additional
FROM ${bcv_auction}
LEFT JOIN db.default.d_ssp_demand_side_platform AS d_dsp
  ON d_dsp.id = auction__dsp_id
LEFT JOIN db.default.d_network AS d_network
  ON auction__network_id = d_network.id
LEFT JOIN db.default.d_network AS auc_upstream
  ON auc_upstream.id = IF(
    auction__network_id = 523319
    AND CONTAINS(partners__entity_source, 'auction_upstream'),
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
    -1
  )
WHERE
  (
    auction__integration_type IN ('normal', 'pg_td', 'sfx', 'reseller_tag')
    AND BITWISE_AND(auction__flags, 8) = 0
  )
  AND BITWISE_AND(auction__flags, 64) = 0
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
  11
