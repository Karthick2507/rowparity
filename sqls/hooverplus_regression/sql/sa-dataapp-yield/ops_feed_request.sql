-- account:    sa-dataapp-yield
-- skeleton:   8a9e7aaea09a9309e5c6c70efe355257
-- pattern:    1c22a31784aee12ab134ea898146d1ad  (698 execution(s))
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
  CASE
    WHEN BITWISE_AND(request__extra_flags2, 4194304) > 0
    THEN 'mrs_1st_request'
    WHEN BITWISE_AND(request__extra_flags2, 8388608) > 0
    THEN 'mrs_2nd_request'
    ELSE 'non_mrs_request'
  END AS mrs_request_type,
  COALESCE(request__visitor__country, 'unknown country') AS country,
  COALESCE(ctry.description, 'unknown country') AS country_name,
  COALESCE(request__visitor__state, 'unknown state') AS state,
  COALESCE(st.description, 'unknown state') AS state_name,
  IF(request__visitor__country_id = 165, COALESCE(request__visitor__dma_code, -1), -1) AS dma,
  IF(
    request__visitor__country_id = 165,
    COALESCE(lud.description, 'unknown dma'),
    'unknown dma'
  ) AS dma_name,
  SUM(1) AS req_ad_request_logged,
  SUM(COALESCE(request__log_sampling__magnifier, 1)) AS req_ad_request,
  SUM(
    COALESCE(request__log_sampling__magnifier, 1) * (
      1000 / COALESCE(CAST(request__request_throttling_info__exempt_thousandth AS DOUBLE), 1000)
    )
  ) AS req_ad_request_before_shaping,
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
      BITWISE_AND(request__extra_flags, 262144) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_asset_not_found,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags, 524288) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_site_section_not_found,
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
  ) AS req_empty_response_with_midroll_slot,
  SUM(
    IF(request__time_record__total <= 5, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_lt_5ms,
  SUM(
    IF(request__time_record__total <= 10, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_lt_10ms,
  SUM(
    IF(request__time_record__total <= 20, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_lt_20ms,
  SUM(
    IF(request__time_record__total <= 50, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_lt_50ms,
  SUM(
    IF(request__time_record__total <= 100, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_lt_100ms,
  SUM(
    IF(request__time_record__total <= 150, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_lt_150ms,
  SUM(
    IF(request__time_record__total <= 300, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_lt_300ms,
  SUM(
    IF(request__time_record__total <= 500, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_lt_500ms,
  SUM(
    IF(
      request__time_record__total <= 1500,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_resp_time_lt_1500ms,
  SUM(
    IF(request__time_record__total > 1500, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_1500ms,
  SUM(
    IF(
      request__time_record__total <= 2000,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_resp_time_lt_2000ms,
  SUM(
    IF(
      request__time_record__total <= 3000,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_resp_time_lt_3000ms,
  SUM(
    IF(request__time_record__total > 3000, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_3000ms,
  SUM(IF(CARDINALITY(request__rtb_auction__index) > 0, 1, 0)) AS req_prog_request_internal,
  SUM(IF(BITWISE_AND(request__flags, 512) > 0, 1, 0)) AS req_is_secure_request,
  SUM(
    IF(
      request__visitor__filtration_reason = 1,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_white_list,
  SUM(
    IF(
      request__visitor__filtration_reason = 2,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_black_list,
  SUM(
    IF(
      request__visitor__filtration_reason = 5,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_address,
  SUM(
    IF(
      request__visitor__filtration_reason = 6,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_invalid_request,
  SUM(
    IF(
      request__visitor__filtration_reason = 7,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_internal_error,
  SUM(
    IF(
      request__visitor__filtration_reason = 8,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_ptiling,
  SUM(
    IF(
      request__visitor__filtration_reason = 9,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_dot,
  SUM(
    IF(
      request__visitor__filtration_reason = 11,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_network_invalid_traffic_but_serve,
  SUM(
    IF(
      request__visitor__filtration_reason = 12,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_black_list_but_serve,
  SUM(
    IF(
      request__visitor__filtration_reason = 13,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_address_list_but_serve,
  SUM(
    IF(
      request__visitor__filtration_reason = 14,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_domain,
  SUM(
    IF(
      request__visitor__filtration_reason = 15,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_domain_but_serve,
  SUM(
    IF(
      request__visitor__filtration_reason = 16,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_network_invalid_domain,
  SUM(
    IF(
      request__visitor__filtration_reason = 17,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_network_invalid_domain_but_serve,
  SUM(
    IF(
      request__visitor__filtration_reason = 18,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_browser_prefetch_but_serve,
  SUM(
    IF(
      request__visitor__filtration_reason = 19,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_app_bundle_but_serve,
  SUM(
    IF(
      request__visitor__filtration_reason = 21,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_debug_internal_call_but_serve,
  SUM(
    IF(
      request__visitor__filtration_reason = 23,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_prebid_detection,
  SUM(
    IF(
      request__visitor__filtration_reason = 24,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_prebid_detection_but_serve,
  SUM(
    IF(
      request__visitor__filtration_reason = 25,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_app_bundle_pmal,
  SUM(
    IF(
      request__visitor__filtration_reason = 26,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_headless_browser,
  SUM(
    IF(
      request__visitor__filtration_reason = 27,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_site_section_cut_tool,
  SUM(
    IF(
      request__visitor__filtration_reason = 28,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_malicious_domain,
  SUM(
    IF(
      request__visitor__filtration_reason = 29,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_defased_app,
  SUM(
    IF(
      request__visitor__filtration_reason = 30,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_network_app_bundle,
  SUM(
    IF(
      request__visitor__filtration_reason = 31,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_app_name,
  SUM(
    IF(
      request__visitor__filtration_reason = 32,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_network_app_name,
  SUM(
    IF(
      request__visitor__filtration_reason = 33,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_location,
  SUM(
    IF(
      request__visitor__filtration_reason = 34,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_app_bundle,
  SUM(
    IF(
      request__visitor__filtration_reason = 35,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_app_name_but_serve,
  SUM(
    IF(
      request__visitor__filtration_reason = 36,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_wb_domain,
  SUM(
    IF(
      request__visitor__filtration_reason = 37,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_filtered_by_wb_app,
  SUM(IF(BITWISE_AND(request__flags, 262144) > 0, 1, 0)) AS req_user_hit_cnt,
  SUM(IF(BITWISE_AND(request__flags, 524288) > 0, 1, 0)) AS req_user_miss_cnt,
  SUM(IF(BITWISE_AND(request__decision_info__flag4, 4194304) > 0, 1, 0)) AS req_ids_request_cnt,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag4, 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_ids_downgrade_flag4_bit1,
  SUM(IF(NOT request__visitor__household_id IS NULL, 1, 0)) AS req_oper_hhid_matched_cnt,
  SUM(IF(NOT request__visitor__universal_hhid IS NULL, 1, 0)) AS req_universal_hhid_matched_cnt,
  SUM(IF(BITWISE_AND(COALESCE(request__audience_flags, 0), 2) > 0, 1, 0)) AS req_enriched_alias_cnt,
  SUM(IF(BITWISE_AND(COALESCE(request__audience_flags, 0), 4) > 0, 1, 0)) AS req_enriched_segment_cnt,
  SUM(IF(BITWISE_AND(COALESCE(request__audience_flags, 0), 8) > 0, 1, 0)) AS req_enriched_plc_cnt,
  SUM(COALESCE(request__userdb_audience_user_info__bg_alias_growth_ratio, 0)) AS req_total_segment_cnt,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_gdpr_apply,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags2, 64) > 0
      AND BITWISE_AND(request__privacy_info__compliance_flag, 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_gdpr_hybrid
FROM ${bcv_transaction} AS a
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_lu_dma AS lud
  ON lud.id = request__visitor__dma_code_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = request__visitor__country_id
LEFT JOIN db.default.d_lu_state AS st
  ON st.id = request__visitor__state_id
WHERE
  (
    request__is_first_request
    AND (
      request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
    )
  )
  AND COALESCE(request__visitor__filtration_reason, 0) <> 20
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
  19
