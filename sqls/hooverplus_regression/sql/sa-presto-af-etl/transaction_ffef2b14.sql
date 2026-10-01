-- account:    sa-presto-af-etl
-- skeleton:   06d9518323713c6ffe60bb6b90796b5c
-- pattern:    ffef2b1419d9131295f4d4e9bc11c103  (1 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   dt < ?
--   dt >= ?
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH magnifier_table AS (
  SELECT
    CASE
      WHEN NOT request__context__video_cro_network_id IN (
        532730,
        535275,
        533097,
        533475,
        535395,
        542970,
        543452,
        532715,
        535067,
        539359,
        531690,
        534984,
        534470,
        535253,
        512029,
        535261,
        538740,
        533474,
        534614,
        533600,
        536108,
        536089,
        534963,
        535168,
        542414,
        531691,
        529832,
        534465,
        535072,
        531688,
        533469,
        533598,
        536419,
        536086,
        535258,
        536082,
        535026,
        537415,
        539813,
        535247,
        535263,
        535082,
        535659,
        535262,
        543012,
        534970,
        535662,
        0,
        533483,
        535259,
        534996,
        533602,
        534983,
        534608,
        532716,
        537082,
        533595,
        543643,
        112214,
        510839,
        535664,
        534985,
        534466,
        535399,
        539061,
        542797,
        535182,
        539988,
        535070,
        535260,
        535068,
        535851,
        536124,
        536142,
        534464,
        545330,
        512116,
        533596,
        534609,
        533622,
        536174,
        545336,
        536081,
        536159,
        542912,
        534605,
        534987,
        545702,
        535177,
        534982,
        535354,
        539161,
        533499,
        531689,
        534482,
        535256,
        539073,
        534998,
        533471,
        535400,
        536122,
        536110,
        533484,
        533473,
        534969
      )
      THEN 0
      ELSE request__context__video_cro_network_id
    END AS network_id,
    CASE
      WHEN CONTAINS(request__context__ab_test_item__bucket_id, 484)
      THEN '484'
      WHEN CONTAINS(request__context__ab_test_item__bucket_id, 414)
      THEN '414'
      WHEN CONTAINS(request__context__ab_test_item__bucket_id, 524)
      THEN '524'
      WHEN CONTAINS(request__context__ab_test_item__bucket_id, 415)
      THEN '415'
      ELSE 'null'
    END AS bucket_id,
    'loss' AS escape_flag,
    MAX(COALESCE(CAST(request__decision_info__value8 AS DOUBLE) / 10000 - 1, 1)) AS real_magnifier
  FROM ${bcv_transaction}
  WHERE
    (
      (
        (
          request__context__video_cro_network_id = 512029
        )
        AND CONTAINS(request__context__ab_test_item__bucket_id, 414)
      )
      OR (
        (
          BITWISE_AND(request__extra_flags2, 65536) = 65536
        )
        AND CONTAINS(request__context__ab_test_item__bucket_id, 524)
      )
      OR (
        (
          BITWISE_AND(request__extra_flags2, 65536) = 65536
        )
        AND CONTAINS(request__context__ab_test_item__bucket_id, 484)
      )
      OR (
        (
          request__context__video_cro_network_id = 510839
        )
        AND CONTAINS(request__context__ab_test_item__bucket_id, 415)
      )
      OR (
        request__context__video_cro_network_id = 512116
      )
    )
    AND BITWISE_AND(COALESCE(request__request_throttling_info__flags, 0), 6) = 6
  GROUP BY
    1,
    2,
    3
), realtime_sspu_exempt_data AS (
  SELECT
    video_cro_network_id AS network_id,
    is_prefiltered,
    SUM(ack_ad_impression) AS ack_ad_impression,
    SUM(ack_real_filtered_impression) AS ack_real_filtered_impression,
    SUM(ack_apply_prefilter_impression) AS ack_apply_prefilter_impression
  FROM druid_pqm.default.traffic__traffic_shaping__realtime__second AS s
  WHERE
    (
      (
        s.__time >= CAST('2026-08-14 00:00:00' AS TIMESTAMP)
        AND s.__time < CAST('2026-08-14 15:10:06' AS TIMESTAMP)
      )
      AND is_apply_prefilter = 'true'
    )
    AND is_sspu_traffic = 'true'
  GROUP BY
    video_cro_network_id,
    is_prefiltered
), realtime_sspu_exempt_magnifier AS (
  SELECT
    CASE
      WHEN NOT network_id IN (
        532730,
        535275,
        533097,
        533475,
        535395,
        542970,
        543452,
        532715,
        535067,
        539359,
        531690,
        534984,
        534470,
        535253,
        512029,
        535261,
        538740,
        533474,
        534614,
        533600,
        536108,
        536089,
        534963,
        535168,
        542414,
        531691,
        529832,
        534465,
        535072,
        531688,
        533469,
        533598,
        536419,
        536086,
        535258,
        536082,
        535026,
        537415,
        539813,
        535247,
        535263,
        535082,
        535659,
        535262,
        543012,
        534970,
        535662,
        0,
        533483,
        535259,
        534996,
        533602,
        534983,
        534608,
        532716,
        537082,
        533595,
        543643,
        112214,
        510839,
        535664,
        534985,
        534466,
        535399,
        539061,
        542797,
        535182,
        539988,
        535070,
        535260,
        535068,
        535851,
        536124,
        536142,
        534464,
        545330,
        512116,
        533596,
        534609,
        533622,
        536174,
        545336,
        536081,
        536159,
        542912,
        534605,
        534987,
        545702,
        535177,
        534982,
        535354,
        539161,
        533499,
        531689,
        534482,
        535256,
        539073,
        534998,
        533471,
        535400,
        536122,
        536110,
        533484,
        533473,
        534969
      )
      THEN 0
      ELSE network_id
    END AS network_id,
    'loss' AS escape_flag,
    CASE
      WHEN SUM(CASE WHEN LOWER(is_prefiltered) = 'true' THEN ack_ad_impression ELSE 0 END) = 0
      THEN 1.0
      ELSE SUM(ack_real_filtered_impression) * 1.0 / SUM(CASE WHEN LOWER(is_prefiltered) = 'true' THEN ack_ad_impression ELSE 0 END)
    END AS real_magnifier
  FROM realtime_sspu_exempt_data
  GROUP BY
    1
), realtime_status AS (
  SELECT
    CASE
      WHEN NOT network_id IN (
        532730,
        535275,
        533097,
        533475,
        535395,
        542970,
        543452,
        532715,
        535067,
        539359,
        531690,
        534984,
        534470,
        535253,
        512029,
        535261,
        538740,
        533474,
        534614,
        533600,
        536108,
        536089,
        534963,
        535168,
        542414,
        531691,
        529832,
        534465,
        535072,
        531688,
        533469,
        533598,
        536419,
        536086,
        535258,
        536082,
        535026,
        537415,
        539813,
        535247,
        535263,
        535082,
        535659,
        535262,
        543012,
        534970,
        535662,
        0,
        533483,
        535259,
        534996,
        533602,
        534983,
        534608,
        532716,
        537082,
        533595,
        543643,
        112214,
        510839,
        535664,
        534985,
        534466,
        535399,
        539061,
        542797,
        535182,
        539988,
        535070,
        535260,
        535068,
        535851,
        536124,
        536142,
        534464,
        545330,
        512116,
        533596,
        534609,
        533622,
        536174,
        545336,
        536081,
        536159,
        542912,
        534605,
        534987,
        545702,
        535177,
        534982,
        535354,
        539161,
        533499,
        531689,
        534482,
        535256,
        539073,
        534998,
        533471,
        535400,
        536122,
        536110,
        533484,
        533473,
        534969
      )
      THEN 0
      ELSE network_id
    END AS network_id,
    CASE
      WHEN CONTAINS(bucket_id, 484)
      THEN '484'
      WHEN CONTAINS(bucket_id, 414)
      THEN '414'
      WHEN CONTAINS(bucket_id, 524)
      THEN '524'
      WHEN CONTAINS(bucket_id, 415)
      THEN '415'
      ELSE 'null'
    END AS bucket_id,
    IF(BITWISE_AND(COALESCE(request_throttling_info_flags, 0), 6) = 6, 'loss', 'no_loss') AS escape_flag,
    COALESCE(SUM(ad_cnt), 0) AS ad_cnt,
    COALESCE(SUM(ad_views), 0) AS ad_views,
    COALESCE(SUM(req_cnt_with_magnifier), 0) AS req_cnt
  FROM db.realtime.f_traffic_shaping_hourly
  WHERE
    (
      (
        FROM_UNIXTIME(timestamp) >= CAST('2026-08-14 00:00:00' AS TIMESTAMP)
        AND FROM_UNIXTIME(timestamp) < CAST('2026-08-14 15:10:06' AS TIMESTAMP)
      )
      AND (
        BITWISE_AND(COALESCE(request_throttling_info_flags, 0), 2) > 0
        OR network_id = 512116
      )
    )
    AND (
      (
        (
          network_id = 512029
        ) AND CONTAINS(bucket_id, 414)
      )
      OR (
        (
          is_fw_ssp_traffic = TRUE
        ) AND CONTAINS(bucket_id, 524)
      )
      OR (
        (
          is_fw_ssp_traffic = TRUE
        ) AND CONTAINS(bucket_id, 484)
      )
      OR (
        (
          network_id = 510839
        ) AND CONTAINS(bucket_id, 415)
      )
      OR (
        network_id = 512116
      )
    )
  GROUP BY
    1,
    2,
    3
), recover_metrics AS (
  SELECT
    realtime_status.network_id,
    realtime_status.bucket_id,
    realtime_status.escape_flag,
    realtime_status.ad_cnt * COALESCE(realtime_sspu_exempt_magnifier.real_magnifier, magnifier_table.real_magnifier, 1) AS ad_cnt,
    realtime_status.ad_views * COALESCE(realtime_sspu_exempt_magnifier.real_magnifier, magnifier_table.real_magnifier, 1) AS ad_views,
    realtime_status.req_cnt * COALESCE(realtime_sspu_exempt_magnifier.real_magnifier, magnifier_table.real_magnifier, 1) AS req_cnt
  FROM realtime_status
  LEFT JOIN realtime_sspu_exempt_magnifier
    ON realtime_status.network_id = realtime_sspu_exempt_magnifier.network_id
    AND realtime_status.escape_flag = realtime_sspu_exempt_magnifier.escape_flag
  LEFT JOIN magnifier_table
    ON realtime_status.network_id = magnifier_table.network_id
    AND realtime_status.bucket_id = magnifier_table.bucket_id
    AND realtime_status.escape_flag = magnifier_table.escape_flag
), grouped_metrics AS (
  SELECT
    network_id,
    bucket_id,
    MAX(IF(escape_flag = 'no_loss', ad_cnt, 0)) AS recall_ad_cnt,
    MAX(IF(escape_flag = 'no_loss', ad_views, 0)) AS recall_ad_views,
    MAX(IF(escape_flag = 'no_loss', req_cnt, 0)) AS recall_req_cnt,
    MAX(IF(escape_flag = 'loss', req_cnt, 0)) AS filter_req_cnt,
    SUM(ad_cnt) AS total_ad_cnt,
    SUM(ad_views) AS total_ad_views,
    SUM(req_cnt) AS total_req_cnt
  FROM recover_metrics
  GROUP BY
    1,
    2
)
SELECT
  network_id,
  bucket_id,
  IF(COALESCE(total_ad_cnt, 0) = 0, 1, recall_ad_cnt * 1.000000 / total_ad_cnt) AS ad_cnt_recall_ratio,
  IF(COALESCE(total_ad_views, 0) = 0, 1, recall_ad_views * 1.000000 / total_ad_views) AS ad_views_recall_ratio,
  IF(COALESCE(total_req_cnt, 0) = 0, 1, filter_req_cnt * 1.000000 / total_req_cnt) AS request_cut_ratio,
  total_req_cnt
FROM grouped_metrics
