-- account:    sa-mktplaceanalytics
-- skeleton:   b37d34d8cca882e47a8e29702d2d09c3
-- pattern:    3d7e0de5433c122d5c77df0afdd6fcea  (700 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE_ADD(?, -?, DATE_TRUNC(?, CAST(? AS TIMESTAMP)))
--   request__timestamp >= DATE_ADD(?, -?, DATE_TRUNC(?, CAST(? AS TIMESTAMP)))

WITH filter_keys AS (
  SELECT
    request__timestamp,
    request__context__network_id,
    request__context__site_section_id,
    request__visitor__country,
    request__transaction_id,
    request__server_id,
    request__context__stream_mode_ids,
    request__context__standard_programmer_id,
    request__context__standard_brand_id,
    request__context__standard_genre_ids,
    request__context__standard_channel_id,
    request__visitor__standard_environment_id,
    request__context__standard_iab_category_ids,
    request__context__standard_iab_category_ids_raw,
    request__context__standard_language_ids,
    request__visitor__standard_device_type_ids,
    request__visitor__user_agent_device_type,
    ARRAY_DISTINCT(request__external_candidate_ad__integration_type) AS ad__integration_type,
    ARRAY_DISTINCT(request__external_candidate_ad__market_integration_type) AS ad__market_integration_type,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_content_category%') AS a1,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_content_language%') AS a2,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_content_rating%') AS a3,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_content_genre%') AS a4,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_content_channel%') AS a5,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_content_title%') AS a6,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_content_length%') AS a7,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_production_quality%') AS a8,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_content_producer_name%') AS a9,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_content_network%') AS a10,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_did%') AS a11,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_devicemake%') AS a12,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_device_model%') AS a13,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_devicetype%') AS a14,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_app_name%') AS a15,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_app_bundle%') AS a16,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_app_store_url%') AS a17,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_placement_type%') AS a18,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_plcmt_type%') AS a19,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_player_height%') AS a20,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_player_width%') AS a21,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_site_page%') AS a22,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_us_privacy%') AS a23,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_coppa%') AS a24,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_is_lat%') AS a25,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_atts%') AS a26,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_opt_out%') AS a27,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_gdpr"%') AS a28,
    FILTER(request__context__key_value, x -> x LIKE '%_fw_gdpr_consent%') AS a29,
    FILTER(request__context__key_value, x -> x LIKE '%livestream_flag%') AS a30,
    FILTER(request__context__key_value, x -> x LIKE '%content_series%') AS a31,
    FILTER(request__context__key_value, x -> x LIKE '%schain%') AS a32
  FROM ${bcv_transaction}
)
SELECT
  DATE_TRUNC('MINUTE', request__timestamp) AS request_timestamp,
  request__context__network_id,
  request__context__site_section_id,
  request__visitor__country,
  ad__integration_type,
  ad__market_integration_type,
  request__context__stream_mode_ids,
  request__context__standard_programmer_id,
  request__context__standard_brand_id,
  request__context__standard_genre_ids,
  request__context__standard_channel_id,
  request__visitor__standard_environment_id,
  request__context__standard_iab_category_ids,
  request__context__standard_iab_category_ids_raw,
  request__context__standard_language_ids,
  request__visitor__standard_device_type_ids,
  CASE
    WHEN CARDINALITY(request__visitor__standard_device_type_ids) >= 1
    THEN request__visitor__standard_device_type_ids[1]
    ELSE NULL
  END AS standard_parent_device_type_id,
  request__visitor__user_agent_device_type,
  CASE
    WHEN CARDINALITY(a1) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a1, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a1, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS content_category,
  CASE
    WHEN CARDINALITY(a2) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a2, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a2, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS content_language,
  CASE
    WHEN CARDINALITY(a3) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a3, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a3, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS content_rating,
  CASE
    WHEN CARDINALITY(a4) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a4, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a4, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS content_genre,
  CASE
    WHEN CARDINALITY(a5) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a5, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a5, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS content_channel,
  CASE
    WHEN CARDINALITY(a6) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a6, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a6, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS content_title,
  CASE
    WHEN CARDINALITY(a7) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a7, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a7, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS content_length,
  CASE
    WHEN CARDINALITY(a8) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a8, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a8, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS production_quality,
  CASE
    WHEN CARDINALITY(a9) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a9, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a9, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS content_producer_name,
  CASE
    WHEN CARDINALITY(a10) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a10, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a10, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS content_network,
  CASE
    WHEN CARDINALITY(a11) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a11, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    WHEN REGEXP_REPLACE(RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a11, ', '), '.*\"value\"\:\"', ''), '"}'), ':.*', '') IS NULL
    OR REGEXP_EXTRACT(RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a11, ', '), '.*\"value\"\:\"', ''), '"}'), ':') IS NULL
    THEN 'no prefix passed'
    ELSE REGEXP_REPLACE(RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a11, ', '), '.*\"value\"\:\"', ''), '"}'), ':.*', '')
  END AS device_ifa,
  CASE
    WHEN CARDINALITY(a12) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a12, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a12, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS device_make,
  CASE
    WHEN CARDINALITY(a13) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a13, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a13, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS device_model,
  CASE
    WHEN CARDINALITY(a14) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a14, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a14, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS device_type,
  CASE
    WHEN CARDINALITY(a15) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a15, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a15, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS app_name,
  CASE
    WHEN CARDINALITY(a16) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a16, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a16, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS app_bundle,
  CASE
    WHEN CARDINALITY(a17) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a17, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a17, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS app_store_url,
  CASE
    WHEN CARDINALITY(a18) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a18, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a18, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS placement_type,
  CASE
    WHEN CARDINALITY(a19) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a19, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a19, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS plcmt,
  CASE
    WHEN CARDINALITY(a20) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a20, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a20, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS player_height,
  CASE
    WHEN CARDINALITY(a21) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a21, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a21, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS player_width,
  CASE
    WHEN CARDINALITY(a22) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a22, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a22, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS site_page,
  CASE
    WHEN CARDINALITY(a23) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a23, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a23, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS ccpa_compliance,
  CASE
    WHEN CARDINALITY(a24) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a24, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a24, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS coppa,
  CASE
    WHEN CARDINALITY(a25) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a25, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a25, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS limited_ad_tracking,
  CASE
    WHEN CARDINALITY(a26) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a26, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a26, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS atts,
  CASE
    WHEN CARDINALITY(a27) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a27, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a26, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS opt_out_track_measure,
  CASE
    WHEN CARDINALITY(a28) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a28, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a28, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS gdpr,
  CASE
    WHEN CARDINALITY(a29) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a29, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a29, ', '), '.*\"value\"\:\"', ''), '"}') = '1'
    THEN '1'
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a29, ', '), '.*\"value\"\:\"', ''), '"}') = '{consent'
    THEN '{consent'
    ELSE 'consent string passed'
  END AS gdpr_consent,
  CASE
    WHEN CARDINALITY(a30) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a30, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a30, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS livestream_flag,
  CASE
    WHEN CARDINALITY(a31) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a31, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a31, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS content_series,
  CASE
    WHEN CARDINALITY(a32) = 0
    THEN NULL
    WHEN NOT ARRAY_JOIN(a32, ', ') LIKE '%value%'
    THEN 'key passed; no value passed'
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE '1.0,1!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        '1.0,1!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE '1.0,0!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        '1.0,0!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE '!%'
    THEN CONCAT(
      REGEXP_EXTRACT(RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'), '!.*?,'),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE '+1.0,0!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        '\+1.0,0!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE '+1.0,1!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        '\+1.0,1!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE ',1!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        ',1!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE '+,1!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        '\+,1!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE ' 1.0,1!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        ' 1.0,1!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE ' 1.0,0!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        ' 1.0,0!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE ' !%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        ' !.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE ' +1.0,0!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        ' \+1.0,0!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE ' +1.0,1!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        ' \+1.0,1!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE ' ,1!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        ' ,1!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE ' +,1!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        ' \+,1!.*?,'
      ),
      ' [...]'
    )
    WHEN RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}') LIKE 'asi=%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        'asi=.*?,'
      ),
      ' [...]'
    )
    WHEN REGEXP_REPLACE(
      RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
      '%3d',
      '='
    ) LIKE 'asi=%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        'asi\%3d.*?,'
      ),
      ' [...]'
    )
    WHEN REGEXP_REPLACE(RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'), '%', '=') LIKE '=7b=7bschain=7d=7d!%'
    THEN CONCAT(
      REGEXP_EXTRACT(
        RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}'),
        '\%7b\%7bschain\%7d\%7d!.*?,'
      ),
      ' [...]'
    )
    ELSE RTRIM(REGEXP_REPLACE(ARRAY_JOIN(a32, ', '), '.*\"value\"\:\"', ''), '"}')
  END AS schain_shortened,
  COUNT(DISTINCT CONCAT(request__transaction_id, request__server_id)) AS requests
FROM filter_keys
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
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
  37,
  38,
  39,
  40,
  41,
  42,
  43,
  44,
  45,
  46,
  47,
  48,
  49,
  50
