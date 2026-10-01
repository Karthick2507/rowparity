-- account:    sa-realtime
-- skeleton:   fa10c144f7b04dba80a226d92d2094e5
-- pattern:    892fe5dc195698715a86bc53a2f9e313  (692 execution(s))
-- in suite:   daily commitment
-- hoover:     ack, request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   CAST(TO_UNIXTIME(ack__timestamp) AS BIGINT) >= CAST(TO_UNIXTIME(DATE_ADD(?, -?, CAST(? AS TIMESTAMP))) AS BIGINT)
--   CAST(TO_UNIXTIME(request__timestamp) AS BIGINT) >= CAST(TO_UNIXTIME(DATE_ADD(?, -?, CAST(? AS TIMESTAMP))) AS BIGINT)
--   process_batch_id = DATE_FORMAT(DATE_TRUNC(?, DATE_ADD(?, -?, CAST(? AS TIMESTAMP))), ?)

WITH request_no_selected_ads_with_real_acks AS (
  SELECT
    __time,
    distributor_id,
    cro_id,
    profile_id AS profile_id,
    COUNT(*) AS no_selected_ads_with_real_acks
  FROM (
    SELECT
      CAST(DATE_FORMAT(ack__timestamp, '%y-%m-%d %h:00:00') AS TIMESTAMP) AS __time,
      request__transaction_id,
      request__server_id,
      IF(
        request__context__network_id IS NULL OR request__context__network_id = 0,
        -1,
        request__context__network_id
      ) AS distributor_id,
      COALESCE(
        request__context__video_cro_network_id,
        request__context__site_section_cro_network_id,
        -1
      ) AS cro_id,
      COALESCE(request__context__profile_id, -1) AS profile_id
    FROM ${bcv_ack} AS ack
    WHERE
      BITWISE_AND(ack__flags, 65536) = 0 AND request__advertisement_count = 0
    GROUP BY
      1,
      2,
      3,
      4,
      5,
      6
  )
  GROUP BY
    1,
    2,
    3,
    4
), ack_impression AS (
  SELECT
    CAST(DATE_FORMAT(ack__timestamp, '%y-%m-%d %h:00:00') AS TIMESTAMP) AS __time,
    IF(
      request__context__network_id IS NULL OR request__context__network_id = 0,
      -1,
      request__context__network_id
    ) AS distributor_id,
    COALESCE(
      request__context__video_cro_network_id,
      request__context__site_section_cro_network_id,
      -1
    ) AS cro_id,
    COALESCE(request__context__profile_id, -1) AS profile_id,
    SUM(COALESCE(ack__metrics__ad_impression, 0)) AS impression
  FROM ${bcv_ack} AS ack
  WHERE
    ack__event_type = 'i' AND ack__event_name = 'defaultimpression'
  GROUP BY
    1,
    2,
    3,
    4
), request AS (
  SELECT
    CAST(DATE_FORMAT(request__timestamp, '%y-%m-%d %h:00:00') AS TIMESTAMP) AS __time,
    IF(
      request__context__network_id IS NULL OR request__context__network_id = 0,
      -1,
      request__context__network_id
    ) AS distributor_id,
    COALESCE(
      request__context__video_cro_network_id,
      request__context__site_section_cro_network_id,
      -1
    ) AS cro_id,
    COALESCE(request__context__profile_id, -1) AS profile_id,
    COUNT(*) AS request,
    SUM(IF(NOT request__advertisement_count > 0, 1, 0)) AS request_without_select_ad,
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
  GROUP BY
    1,
    2,
    3,
    4
), union_table AS (
  SELECT
    __time,
    distributor_id,
    cro_id,
    profile_id,
    SUM(request) AS request,
    SUM(request_without_select_ad) AS request_without_select_ad,
    SUM(request_lowroi_filtered) AS request_lowroi_filtered,
    SUM(request_safe_mod_filtered) AS request_safe_mod_filtered,
    SUM(request_sspu_filtered) AS request_sspu_filtered,
    SUM(request_lowroi_filtered) - SUM(request_safe_mod_filtered) - SUM(request_sspu_filtered) AS request_ext_mode_filtered,
    SUM(request_no_selected_ads_with_real_acks) AS request_no_selected_ads_with_real_acks,
    SUM(impression) AS impression
  FROM (
    SELECT
      __time,
      distributor_id,
      cro_id,
      profile_id,
      0 AS request,
      0 AS request_without_select_ad,
      0 AS request_lowroi_filtered,
      0 AS request_safe_mod_filtered,
      0 AS request_sspu_filtered,
      request_no_selected_ads_with_real_acks.no_selected_ads_with_real_acks AS request_no_selected_ads_with_real_acks,
      0 AS impression
    FROM request_no_selected_ads_with_real_acks
    UNION ALL
    SELECT
      __time,
      distributor_id,
      cro_id,
      profile_id,
      0 AS request,
      0 AS request_without_select_ad,
      0 AS request_lowroi_filtered,
      0 AS request_safe_mod_filtered,
      0 AS request_sspu_filtered,
      0 AS request_no_selected_ads_with_real_acks,
      ack_impression.impression AS impression
    FROM ack_impression
    UNION ALL
    SELECT
      __time,
      distributor_id,
      cro_id,
      profile_id,
      request.request AS request,
      request.request_without_select_ad AS request_without_select_ad,
      request.request_lowroi_filtered AS request_lowroi_filtered,
      request.request_safe_mod_filtered AS request_safe_mod_filtered,
      request.request_sspu_filtered AS request_sspu_filtered,
      0 AS request_no_selected_ads_with_real_acks,
      0 AS impression
    FROM ${bcv_request}
  )
  GROUP BY
    1,
    2,
    3,
    4
)
SELECT
  __time,
  CAST(union_table.distributor_id AS VARCHAR) AS distributor_id,
  network_distributor.name AS distributor_name,
  CAST(union_table.cro_id AS VARCHAR) AS cro_id,
  network_cro.name AS cro_name,
  CAST(union_table.profile_id AS VARCHAR) AS profile_id,
  union_table.request AS request_total,
  union_table.request_without_select_ad AS request_without_select_ad,
  union_table.request_no_selected_ads_with_real_acks AS request_no_selected_ads_with_real_acks,
  union_table.request_lowroi_filtered AS request_lowroi_filtered,
  union_table.request_safe_mod_filtered AS request_safe_mod_filtered,
  union_table.request_sspu_filtered AS request_sspu_filtered,
  union_table.request_ext_mode_filtered AS request_ext_mode_filtered,
  union_table.impression AS impression
FROM union_table
LEFT JOIN oltp.fwmrm_oltp.network AS network_distributor
  ON union_table.distributor_id = network_distributor.id
LEFT JOIN oltp.fwmrm_oltp.network AS network_cro
  ON union_table.cro_id = network_cro.id
ORDER BY
  __time,
  distributor_id,
  cro_id,
  profile_id
