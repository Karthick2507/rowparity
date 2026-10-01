-- account:    sa-dataapp-yield
-- skeleton:   1a0296b0c561f8825f70146f149ff90a
-- pattern:    d06c65c3f126917807750769016a3658  (698 execution(s))
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
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
  IF(COALESCE(request__advertisement_count, 0) = 0, 'true', 'false') AS is_empty_response,
  IF(BITWISE_AND(COALESCE(request__request_prefilter__flag, 0), 1) > 0, 'true', 'false') AS is_apply_prefilter,
  IF(BITWISE_AND(COALESCE(request__request_prefilter__flag, 0), 2) > 0, 'true', 'false') AS is_prefiltered,
  IF(BITWISE_AND(COALESCE(request__request_prefilter__flag, 0), 4) > 0, 'true', 'false') AS is_bypass_selection,
  IF(BITWISE_AND(COALESCE(request__request_prefilter__flag, 0), 8) > 0, 'true', 'false') AS is_baseline,
  IF(BITWISE_AND(request__flags, 2097152) > 0, 'true', 'false') AS log_video_view,
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
  COALESCE(request__server_group, 'na') AS server_group,
  SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS ack_ad_impression,
  SUM(
    IF(
      BITWISE_AND(COALESCE(request__request_prefilter__flag, 0), 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(CAST(request__decision_info__value8 AS DOUBLE) / 10000, 1) * COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_apply_prefilter_impression,
  SUM(
    IF(
      BITWISE_AND(COALESCE(request__request_prefilter__flag, 0), 3) = 3
      AND (
        COALESCE(request__decision_info__value8, 0) > 0
        OR COALESCE(request__log_sampling__magnifier, 1) > 1
      ),
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(CAST(request__decision_info__value8 AS DOUBLE) / 10000 - 1, 1) * COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_real_filtered_impression
FROM ${bcv_ack} AS a
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  (
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
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16
