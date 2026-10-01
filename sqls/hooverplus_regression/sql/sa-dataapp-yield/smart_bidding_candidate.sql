-- account:    sa-dataapp-yield
-- skeleton:   4bb0b02abd8b3b95d8eda85bec16ec6f
-- pattern:    dc146f82f145653d5ea9f4acfb9ddca1  (697 execution(s))
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
  CASE
    WHEN candidate__integration_type = 'openrtb_pg_td'
    THEN 'fullstack_pg'
    WHEN candidate__integration_type = 'openrtb_normal'
    THEN 'fullstack_non_pg'
    WHEN candidate__integration_type = 'openrtb_sfx'
    THEN 'sfx_openrtb'
    WHEN candidate__integration_type = 'reseller_tag'
    AND candidate__external_network_id = 127719
    THEN 'sfx_tag'
    WHEN candidate__integration_type = 'reseller_tag'
    THEN 'ssp_others'
    WHEN candidate__integration_type = 'mkpl_partner_tag'
    THEN 'mkpl_partner_tag'
    ELSE 'na'
  END AS market_integration_type,
  COALESCE(candidate__dsp_id, -1) AS dsp_id,
  COALESCE(d_dsp.name, 'na') AS dsp_name,
  COALESCE(auction__network_id, -1) AS auction_network_id,
  COALESCE(auc_network.name, 'na') AS auction_network_name,
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
  SUM(IF(BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0, 1, 0)) AS bids_resolved,
  SUM(
    IF(
      BITWISE_AND(candidate__bid_status, 2) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 2097152) > 0,
      1,
      0
    )
  ) AS bids_resolved_smartly_bidding_baseline,
  SUM(
    IF(
      BITWISE_AND(candidate__bid_status, 2) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
      1,
      0
    )
  ) AS bids_resolved_smartly_bidding_probe_original,
  SUM(
    IF(
      BITWISE_AND(candidate__bid_status, 2) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) > 0,
      1,
      0
    )
  ) AS bids_resolved_smartly_bidding_probe_additional,
  SUM(
    IF(
      BITWISE_AND(candidate__bid_status, 2) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 8388608) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
      1,
      0
    )
  ) AS bids_resolved_smartly_bidding_feedback_original,
  SUM(
    IF(
      BITWISE_AND(candidate__bid_status, 2) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 8388608) > 0
      AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) > 0,
      1,
      0
    )
  ) AS bids_resolved_smartly_bidding_feedback_additional
FROM ${bcv_candidate}
LEFT JOIN db.default.d_ssp_demand_side_platform AS d_dsp
  ON d_dsp.id = candidate__dsp_id
LEFT JOIN db.default.d_ssp_buyer_platform
  ON d_ssp_buyer_platform.id = candidate__buyer_platform_id
LEFT JOIN db.default.d_network AS cand_network
  ON candidate__network_id = cand_network.id
LEFT JOIN db.default.d_network AS auc_network
  ON auction__network_id = auc_network.id
LEFT JOIN db.default.d_network AS cro
  ON cro.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS dis
  ON dis.id = request__context__network_id
LEFT JOIN db.default.d_network AS auc_upstream
  ON auc_upstream.id = IF(
    auction__network_id = 523319
    AND CONTAINS(partners__entity_source, 'auction_upstream'),
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
    -1
  )
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  candidate__integration_type IN (
    'openrtb_normal',
    'openrtb_pg_td',
    'openrtb_sfx',
    'reseller_tag',
    'mkpl_partner_tag'
  )
  AND BITWISE_AND(auction__flags, 8) = 0
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
