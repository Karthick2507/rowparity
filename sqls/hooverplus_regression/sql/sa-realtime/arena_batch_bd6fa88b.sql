-- account:    sa-realtime
-- skeleton:   9f6eeef9435e1e4a6e1b17b2d1665778
-- pattern:    bd6fa88b8a6e84a6b58e77edb4cf949f  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP) - INTERVAL ? HOUR
--   request__timestamp >= CAST(? AS TIMESTAMP) - INTERVAL ? HOUR

SELECT
  request__context__network_id AS distributor_id,
  network_distributor.name AS distributor_name,
  COALESCE(
    request__context__video_cro_network_id,
    request__context__site_section_cro_network_id
  ) AS cro_id,
  network_cro.name AS cro_name,
  request__context__profile_id AS profile_id,
  COUNT(*) AS request,
  SUM(IF(request__advertisement_count > 0, 1, 0)) AS request_with_select_ad,
  SUM(IF(request__advertisement_count > 0, 1, 0)) * 1.0000 / COUNT(*) AS request_with_select_ad_ratio,
  SUM(IF(NOT request__advertisement_count > 0, 1, 0)) AS request_without_select_ad,
  SUM(IF(NOT request__advertisement_count > 0, 1, 0)) * 1.0000 / COUNT(*) AS request_without_select_ad_ratio,
  SUM(IF(BITWISE_AND(request__extra_flags2, 262144) > 0, 1, 0)) AS request_lowroi_filtered,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags2, 262144) > 0
      AND request__advertisement_count = 0
      AND (
        BITWISE_AND(request__flags, 2097152) > 0
        AND BITWISE_AND(request__flags, 32768) > 0
      )
      AND BITWISE_AND(request__extra_flags2, 65536) = 0,
      1,
      0
    )
  ) AS request_safe_mod_filtered,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags2, 262144) > 0
      AND request__advertisement_count = 0
      AND BITWISE_AND(request__extra_flags2, 65536) > 0,
      1,
      0
    )
  ) AS request_sspu_filtered
FROM ${bcv_request} AS request
LEFT JOIN oltp.fwmrm_oltp.network AS network_distributor
  ON request.request__context__network_id = network_distributor.id
LEFT JOIN oltp.fwmrm_oltp.network AS network_cro
  ON COALESCE(
    request__context__video_cro_network_id,
    request__context__site_section_cro_network_id
  ) = network_cro.id
GROUP BY
  1,
  2,
  3,
  4,
  5
