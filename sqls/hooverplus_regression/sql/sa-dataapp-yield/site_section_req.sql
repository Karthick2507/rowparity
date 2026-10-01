-- account:    sa-dataapp-yield
-- skeleton:   fa8290092522b8cdd788e18f8a53d802
-- pattern:    dd938afe1bc5961cc452a186201eb953  (697 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(request__context__video_cro_context_id, -1) AS video_cro_site_section_id,
  COALESCE(request__context__video_cro_site_id, -1) AS video_cro_site_id,
  COALESCE(request__context__site_section_cro_asset_id, -1) AS distributor_site_section_id,
  COALESCE(request__context__site_section_cro_site_id, -1) AS distributor_site_id,
  CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
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
    WHEN request__visitor__user_agent_device_type = 'set top box'
    THEN 'stb vod'
    WHEN BITWISE_AND(request__flags, 8) > 0
    AND request__visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - live ott'
    WHEN BITWISE_AND(request__flags, 8) > 0
    AND NOT request__visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - live others'
    WHEN BITWISE_AND(request__flags, 8) = 0
    AND request__visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - non-live ott'
    WHEN BITWISE_AND(request__flags, 8) = 0
    AND NOT request__visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - non-live others'
    ELSE 'na'
  END AS service_type,
  COALESCE(request__visitor__user_agent_device_type, 'na') AS platform,
  COALESCE(request__server_group, 'na') AS server_group,
  COALESCE(request__server_pool, 'na') AS server_pool,
  'na' AS market_integration_type,
  IF(BITWISE_AND(request__extra_flags, 16777216) > 0, 'true', 'false') AS is_mkpl,
  COUNT(1) AS req_ad_request_logged,
  SUM(COALESCE(request__log_sampling__magnifier, 1)) AS req_ad_request,
  SUM(
    IF(
      CARDINALITY(COALESCE(request__slots__flags, ARRAY[])) > 0
      AND CONTAINS(request__slots__environment, 'video'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_ad_request_with_video_slot,
  SUM(
    IF(
      CONTAINS(request__slots__time_position_class, 'midroll'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_ad_request_with_midroll_slot,
  SUM(
    IF(
      CARDINALITY(COALESCE(request__advertisements__flags, ARRAY[])) = 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_empty_response,
  SUM(
    IF(
      CARDINALITY(COALESCE(request__advertisements__flags, ARRAY[])) = 0
      AND CARDINALITY(COALESCE(request__slots__flags, ARRAY[])) > 0
      AND CONTAINS(request__slots__environment, 'video'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_empty_response_with_video_slot,
  SUM(
    IF(
      CARDINALITY(COALESCE(request__advertisements__flags, ARRAY[])) = 0
      AND CONTAINS(request__slots__time_position_class, 'midroll'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_empty_response_with_midroll_slot
FROM ${bcv_transaction}
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  request__is_first_request
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
  18
