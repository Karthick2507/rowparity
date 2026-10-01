-- account:    sa-dataapp-yield
-- skeleton:   961cd1a26262a48bd9ca3ae8ead1ea74
-- pattern:    5fec3776fb7a80026f923cde7be286f1  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('MINUTE', request__timestamp) AS timestamp,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(request__server_group, 'na') AS server_group,
  COALESCE(request__system_degradation__level, 'none') AS degradation_level,
  COUNT(1) AS req_ad_request_logged,
  SUM(COALESCE(request__log_sampling__magnifier, 1)) AS req_ad_request,
  SUM(
    IF(
      BITWISE_AND(COALESCE(request__system_degradation__features, 0), 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_closure_cache,
  SUM(
    IF(
      BITWISE_AND(COALESCE(request__system_degradation__features, 0), 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_candidate_truncation,
  SUM(
    IF(
      BITWISE_AND(COALESCE(request__system_degradation__features, 0), 4) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_knapsack_slot_filling,
  SUM(
    IF(
      BITWISE_AND(COALESCE(request__system_degradation__features, 0), 8) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_delayed_async_logging,
  SUM(
    IF(
      BITWISE_AND(COALESCE(request__system_degradation__features, 0), 16) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_deal_truncation
FROM ${bcv_transaction}
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  request__is_first_request
  AND (
    request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
  )
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9
