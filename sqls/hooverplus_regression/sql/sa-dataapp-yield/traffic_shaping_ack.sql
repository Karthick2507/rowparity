-- account:    sa-dataapp-yield
-- skeleton:   ea53337ada1ec99258983650b25321b9
-- pattern:    3ce8bd515a5526e0b6102ba06901bbe9  (695 execution(s))
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
  COALESCE(request__context__site_section_id, -1) AS site_section_id,
  COALESCE(request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
  IF(BITWISE_AND(request__extra_flags2, 65536) = 65536, 'true', 'false') AS is_sspu_traffic,
  IF(BITWISE_AND(request__extra_flags2, 524288) = 524288, 'true', 'false') AS is_sspu_pg_traffic,
  IF(BITWISE_AND(request__flags, 64) > 0, 'true', 'false') AS is_filtered,
  IF(COALESCE(request__advertisement_count, 0) = 0, 'true', 'false') AS is_empty_response,
  IF(
    BITWISE_AND(COALESCE(request__request_throttling_info__flags, 0), 1) > 0,
    'true',
    'false'
  ) AS is_baseline,
  IF(
    BITWISE_AND(COALESCE(request__request_throttling_info__flags, 0), 10) > 0,
    'true',
    'false'
  ) AS is_apply_prefilter,
  IF(
    BITWISE_AND(COALESCE(request__request_throttling_info__flags, 0), 4) > 0,
    'true',
    'false'
  ) AS is_prefiltered,
  IF(
    BITWISE_AND(COALESCE(request__request_throttling_info__flags, 0), 8) > 0,
    'true',
    'false'
  ) AS is_manual_shaping_applied,
  IF(BITWISE_AND(request__flags, 2097152) > 0, 'true', 'false') AS log_video_view,
  COALESCE(request__server_group, 'na') AS server_group,
  COALESCE(request__server_pool, 'na') AS server_pool,
  SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS ack_ad_impression,
  SUM(
    IF(
      BITWISE_AND(COALESCE(request__request_throttling_info__flags, 0), 10) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * (
        1000 / COALESCE(CAST(request__request_throttling_info__exempt_thousandth AS DOUBLE), 1000)
      ) * COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_apply_prefilter_impression,
  SUM(
    IF(
      BITWISE_AND(COALESCE(request__request_throttling_info__flags, 0), 14) IN (6, 8)
      AND COALESCE(request__request_throttling_info__exempt_thousandth, 0) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * (
        1000 / CAST(request__request_throttling_info__exempt_thousandth AS DOUBLE) - 1
      ) * COALESCE(ack__metrics__raw_ad_impression, 0),
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
  16,
  17,
  18
