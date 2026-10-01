-- account:    sa-dataapp-yield
-- skeleton:   d913afdc065d6b25a01daed77b004fe4
-- pattern:    1304ad9c479953c88e39fb58801329a3  (698 execution(s))
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
  COALESCE(cro.name, 'unknown cro') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(dis.name, 'unknown distributor') AS distributor_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'unknown profile') AS profile_name,
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
  COALESCE(request__visitor__user_agent_device_type, 'unknown') AS platform,
  COALESCE(request__server_group, 'others') AS server_group,
  COALESCE(request__visitor__country, 'unknown country') AS country,
  COALESCE(ctry.description, 'unknown country') AS country_name,
  COALESCE(request__visitor__state, 'unknown state') AS state,
  COALESCE(st.description, 'unknown state') AS state_name,
  COALESCE(request__visitor__dma_code, -1) AS dma,
  COALESCE(lud.description, 'unknown dma') AS dma_name,
  COALESCE(request__visitor__platform_group, 'unknown platform group') AS platform_group,
  CASE
    WHEN BITWISE_AND(request__decision_info__value1 / 256, 255) = 0
    THEN 'ip'
    WHEN BITWISE_AND(request__decision_info__value1 / 256, 255) = 1
    THEN 'audience'
    WHEN BITWISE_AND(request__decision_info__value1 / 256, 255) = 2
    THEN 'sis'
    WHEN BITWISE_AND(request__decision_info__value1 / 256, 255) = 3
    THEN 'ltlg'
    WHEN BITWISE_AND(request__decision_info__value1 / 256, 255) = 4
    THEN 'zip code'
    WHEN BITWISE_AND(request__decision_info__value1 / 256, 255) = 5
    THEN 'kv'
    WHEN BITWISE_AND(request__decision_info__value1 / 256, 255) = 6
    THEN 'cookie'
    ELSE 'na'
  END AS geo_source,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value5, 255), 1, 0)) AS req_decision_info_value5_1,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value5 / 256, 255), 1, 0)) AS req_decision_info_value5_2,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value5 / 65536, 255), 1, 0)) AS req_decision_info_value5_3,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value5 / 16777216, 255), 1, 0)) AS req_decision_info_value5_4,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value5 / 4294967296, 255), 1, 0)) AS req_decision_info_value5_5,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value5 / 1099511627776, 255), 1, 0)) AS req_decision_info_value5_6,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value6, 255), 1, 0)) AS req_decision_info_value6_1,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value6 / 256, 255), 1, 0)) AS req_decision_info_value6_2,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value6 / 65536, 255), 1, 0)) AS req_decision_info_value6_3,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value6 / 16777216, 255), 1, 0)) AS req_decision_info_value6_4,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value6 / 4294967296, 255), 1, 0)) AS req_decision_info_value6_5,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value6 / 1099511627776, 255), 1, 0)) AS req_decision_info_value6_6,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value6 / 256, 65535), 1, 0)) AS req_decision_info_value6_3_enhance,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value7, 255), 1, 0)) AS req_decision_info_value7_1,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value7 / 256, 255), 1, 0)) AS req_decision_info_value7_2,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value7 / 65536, 255), 1, 0)) AS req_decision_info_value7_3,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value7 / 16777216, 255), 1, 0)) AS req_decision_info_value7_4,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value7 / 4294967296, 255), 1, 0)) AS req_decision_info_value7_5,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value7 / 1099511627776, 255), 1, 0)) AS req_decision_info_value7_6,
  COUNT_IF(BITWISE_AND(request__flags, 512) > 0) AS req_ad_https_request,
  COUNT_IF(request__visitor__filtration_reason = 1) AS req_filtered_by_white_list,
  COUNT_IF(request__visitor__filtration_reason = 2) AS req_filtered_by_black_list,
  COUNT_IF(request__visitor__filtration_reason = 3) AS req_filtered_by_internal_banning,
  COUNT_IF(request__visitor__filtration_reason = 4) AS req_filtered_by_referrer_banning,
  COUNT_IF(request__visitor__filtration_reason = 5) AS req_filtered_by_address,
  COUNT_IF(request__visitor__filtration_reason = 6) AS req_filtered_by_invalid_request,
  COUNT_IF(request__visitor__filtration_reason = 7) AS req_filtered_by_internal_error,
  COUNT_IF(request__visitor__filtration_reason = 8) AS req_filtered_by_ptiling,
  COUNT_IF(request__visitor__filtration_reason = 9) AS req_filtered_by_dot,
  COUNT_IF(request__visitor__filtration_reason = 10) AS req_filtered_by_deduplication,
  COUNT_IF(request__visitor__filtration_reason = 11) AS req_filtered_by_network_invalid_traffic_but_serve,
  COUNT_IF(request__visitor__filtration_reason = 12) AS req_filtered_by_black_list_but_serve,
  COUNT_IF(request__visitor__filtration_reason = 13) AS req_filtered_by_address_but_serve,
  COUNT_IF(request__visitor__filtration_reason = 14) AS req_filtered_by_domain,
  COUNT_IF(request__visitor__filtration_reason = 15) AS req_filtered_by_domain_but_serve,
  COUNT_IF(request__visitor__filtration_reason = 16) AS req_filtered_by_network_invalid_domain,
  COUNT_IF(request__visitor__filtration_reason = 17) AS req_filtered_by_network_invalid_domain_but_serve,
  COUNT_IF(request__visitor__filtration_reason = 18) AS req_filtered_by_browser_prefetch_but_serve,
  COUNT_IF(request__visitor__filtration_reason = 19) AS req_filtered_by_invalid_app_bundle_but_serve,
  COUNT_IF(request__visitor__filtration_reason = 23) AS req_filtered_by_prebid_detection,
  COUNT_IF(request__visitor__filtration_reason = 24) AS req_filtered_by_prebid_detection_but_serve,
  COUNT_IF(request__visitor__filtration_reason = 25) AS req_filtered_by_app_bundle_pmal,
  COUNT_IF(request__visitor__filtration_reason = 26) AS req_filtered_by_headless_browser,
  COUNT_IF(request__visitor__filtration_reason = 27) AS req_filtered_by_site_section_cut_tool,
  COUNT_IF(request__visitor__filtration_reason = 28) AS req_filtered_by_malicious_domain,
  COUNT_IF(request__visitor__filtration_reason = 29) AS req_filtered_by_defased_app,
  COUNT_IF(request__visitor__filtration_reason = 30) AS req_filtered_by_network_app_bundle,
  COUNT_IF(request__visitor__filtration_reason = 31) AS req_filtered_by_app_name,
  COUNT_IF(request__visitor__filtration_reason = 32) AS req_filtered_by_network_app_name,
  COUNT_IF(request__visitor__filtration_reason = 33) AS req_filtered_by_location,
  COUNT_IF(request__visitor__filtration_reason = 34) AS req_filtered_by_app_bundle,
  COUNT_IF(request__visitor__filtration_reason = 35) AS req_filtered_by_app_name_but_serve,
  COUNT_IF(request__visitor__filtration_reason = 36) AS req_filtered_by_wb_domain,
  COUNT_IF(request__visitor__filtration_reason = 37) AS req_filtered_by_wb_app,
  COUNT_IF(BITWISE_AND(request__flags, 1) > 0) AS req_request_flag_prefetch,
  COUNT_IF(BITWISE_AND(request__flags, 4) > 0) AS req_request_flag_has_tracking,
  COUNT_IF(BITWISE_AND(request__flags, 16) > 0) AS req_request_flag_tracking,
  COUNT_IF(BITWISE_AND(request__flags, 32) > 0) AS req_request_flag_no_selection,
  COUNT_IF(BITWISE_AND(request__flags, 128) > 0) AS req_request_flag_auto_play,
  COUNT_IF(BITWISE_AND(request__flags, 1024) > 0) AS req_request_flag_promote_asset,
  COUNT_IF(BITWISE_AND(request__flags, 2048) > 0) AS req_request_flag_promote_section,
  COUNT_IF(BITWISE_AND(request__flags, 8192) > 0) AS req_request_flag_unattended_play,
  COUNT_IF(BITWISE_AND(request__flags, 32768) > 0) AS req_request_flag_no_slot_transaction,
  COUNT_IF(BITWISE_AND(request__flags, 131072) > 0) AS req_request_flag_external_creative,
  COUNT_IF(BITWISE_AND(request__flags, 2097152) > 0) AS req_request_flag_log_video_view,
  COUNT_IF(BITWISE_AND(request__flags, 4194304) > 0) AS req_request_flag_pending_callback_allowed,
  COUNT_IF(BITWISE_AND(request__flags, 8388608) > 0) AS req_request_flag_display_refresh,
  COUNT_IF(BITWISE_AND(request__flags, 16777216) > 0) AS req_request_flag_use_device_id,
  COUNT_IF(BITWISE_AND(request__flags, 1073741824) > 0) AS req_request_flag_disable_tracking_redirect,
  COUNT_IF(BITWISE_AND(request__flags, 33554432) > 0) AS req_request_flag_has_hylda_kv,
  COUNT_IF(BITWISE_AND(request__flags, 64) > 0) AS req_request_flag_filtered,
  COUNT_IF(BITWISE_AND(request__flags, 512) > 0) AS req_request_flag_secure,
  COUNT_IF(BITWISE_AND(request__flags, 4096) > 0) AS req_request_flag_first_visit,
  COUNT_IF(BITWISE_AND(request__flags, 16384) > 0) AS req_request_flag_no_slot_template,
  COUNT_IF(BITWISE_AND(request__flags, 262144) > 0) AS req_request_flag_user_hit,
  COUNT_IF(BITWISE_AND(request__flags, 524288) > 0) AS req_request_flag_user_missed,
  COUNT_IF(BITWISE_AND(request__flags, 1048576) > 0) AS req_request_flag_user_filtered,
  COUNT_IF(COALESCE(request__context__custom_airing_break_id, '') <> '') AS req_request_flag_break_not_found,
  COUNT_IF(BITWISE_AND(request__extra_flags, 1) > 0) AS req_extra_flag_support_fallback_ad,
  COUNT_IF(BITWISE_AND(request__extra_flags, 2) > 0) AS req_extra_flag_use_user_ip,
  COUNT_IF(BITWISE_AND(request__extra_flags, 4) > 0) AS req_extra_flag_user_shadow,
  COUNT_IF(BITWISE_AND(request__extra_flags, 128) > 0) AS req_extra_flag_one_to_n_request,
  COUNT_IF(BITWISE_AND(request__extra_flags, 64) > 0) AS req_extra_flag_support_error_callback,
  COUNT_IF(BITWISE_AND(request__extra_flags, 1024) > 0) AS req_extra_flag_live_linear,
  COUNT_IF(BITWISE_AND(request__extra_flags, 2048) > 0) AS req_extra_flag_marketplace_audience_extension,
  COUNT_IF(BITWISE_AND(request__extra_flags, 16384) > 0) AS req_extra_flag_headend_linear,
  COUNT_IF(BITWISE_AND(request__extra_flags, 32768) > 0) AS req_extra_flag_browser_prefetch,
  COUNT_IF(BITWISE_AND(request__extra_flags, 131072) > 0) AS req_extra_flag_continuous_play,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags, 32) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_extra_flag_gdpr_no_consent,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags, 512) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_extra_flag_coppa,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags, 4096) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_extra_flag_lat,
  COUNT_IF(BITWISE_AND(request__extra_flags, 8192) > 0) AS req_extra_flag_enable_lat_fc,
  COUNT_IF(BITWISE_AND(request__extra_flags, 262144) > 0) AS req_extra_flag_invalid_custom_assert_id,
  COUNT_IF(BITWISE_AND(request__extra_flags, 524288) > 0) AS req_extra_flag_invalid_custom_site_section_id,
  COUNT_IF(BITWISE_AND(request__extra_flags, 8388608) > 0) AS req_extra_flag_valid_gdpr_consent,
  COUNT_IF(BITWISE_AND(request__extra_flags, 268435456) > 0) AS req_extra_flag_purchased_traffic,
  COUNT_IF(BITWISE_AND(request__extra_flags, 536870912) > 0) AS req_extra_flag_non_purchased_traffic,
  COUNT_IF(BITWISE_AND(request__traffic_compliance__mrc_compliance_flag, 1) > 0) AS req_mrc_compliance_flag_not_count_on_begin_to_render,
  COUNT(1) AS req_ad_request,
  SUM(COALESCE(request__log_sampling__magnifier, 1)) AS req_ad_request_all,
  SUM(
    IF(
      CARDINALITY(COALESCE(request__advertisements__flags, ARRAY[])) = 0
      AND BITWISE_AND(request__flags, 33554432) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_has_hylda_kv_empty_response,
  COUNT_IF(request__visitor__platform_group IN ('desktop', 'mobile web')) AS req_ad_request_desktop_or_mobile,
  COUNT_IF(
    (
      BITWISE_AND(request__decision_info__flag2, 1048576) = 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) = 0
    )
  ) AS req_ad_request_no_ssus_cookie,
  COUNT_IF(
    (
      BITWISE_AND(request__decision_info__flag2, 1048576) > 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) = 0
    )
  ) AS req_ad_request_ssus,
  COUNT_IF(
    (
      BITWISE_AND(request__decision_info__flag2, 1048576) = 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) > 0
    )
  ) AS req_ad_request_only_cookie,
  COUNT_IF(
    (
      BITWISE_AND(request__decision_info__flag2, 1048576) > 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) > 0
    )
  ) AS req_ad_request_both_ssus_cookie,
  COUNT_IF(
    (
      request__visitor__user_agent LIKE '%safari%'
      OR request__visitor__user_agent LIKE '%safari%'
    )
    AND (
      request__visitor__user_agent NOT LIKE '%chrome%'
    )
  ) AS req_ad_request_safari,
  COUNT_IF(
    (
      request__visitor__user_agent LIKE '%chrome%'
      OR request__visitor__user_agent LIKE '%chrome%'
    )
  ) AS req_ad_request_chrome,
  COUNT_IF(
    (
      request__visitor__user_agent LIKE '%safari%'
      OR request__visitor__user_agent LIKE '%safari%'
    )
    AND (
      request__visitor__user_agent NOT LIKE '%chrome%'
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 1048576) = 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) = 0
    )
  ) AS req_ad_request_safari_no_ssus_cookie,
  COUNT_IF(
    (
      request__visitor__user_agent LIKE '%safari%'
      OR request__visitor__user_agent LIKE '%safari%'
    )
    AND (
      request__visitor__user_agent NOT LIKE '%chrome%'
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 1048576) > 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) = 0
    )
  ) AS req_ad_request_safari_ssus,
  COUNT_IF(
    (
      request__visitor__user_agent LIKE '%safari%'
      OR request__visitor__user_agent LIKE '%safari%'
    )
    AND (
      request__visitor__user_agent NOT LIKE '%chrome%'
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 1048576) = 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) > 0
    )
  ) AS req_ad_request_safari_cookie,
  COUNT_IF(
    (
      request__visitor__user_agent LIKE '%safari%'
      OR request__visitor__user_agent LIKE '%safari%'
    )
    AND (
      request__visitor__user_agent NOT LIKE '%chrome%'
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 1048576) > 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) > 0
    )
  ) AS req_ad_request_safari_both_ssus_cookie,
  COUNT_IF(
    (
      request__visitor__user_agent LIKE '%chrome%'
      OR request__visitor__user_agent LIKE '%chrome%'
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 1048576) = 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) = 0
    )
  ) AS req_ad_request_chrome_no_ssus_cookie,
  COUNT_IF(
    (
      request__visitor__user_agent LIKE '%chrome%'
      OR request__visitor__user_agent LIKE '%chrome%'
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 1048576) > 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) = 0
    )
  ) AS req_ad_request_chrome_ssus,
  COUNT_IF(
    (
      request__visitor__user_agent LIKE '%chrome%'
      OR request__visitor__user_agent LIKE '%chrome%'
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 1048576) = 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) > 0
    )
  ) AS req_ad_request_chrome_cookie,
  COUNT_IF(
    (
      request__visitor__user_agent LIKE '%chrome%'
      OR request__visitor__user_agent LIKE '%chrome%'
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 1048576) > 0
    )
    AND (
      BITWISE_AND(request__decision_info__flag2, 2097152) > 0
    )
  ) AS req_ad_request_chrome_both_ssus_cookie,
  COUNT_IF(
    request__visitor__user_agent LIKE '%dalvik%'
    AND (
      request__visitor__user_agent LIKE '%sm-n%'
      OR request__visitor__user_agent LIKE '%sm-g%'
      OR request__visitor__user_agent LIKE '%sm-f%'
      OR request__visitor__user_agent LIKE '%sm-a%'
      OR request__visitor__user_agent LIKE '%sm-j%'
      OR request__visitor__user_agent LIKE '%sm-s%'
      OR request__visitor__user_agent LIKE '%sm-t%'
    )
  ) AS req_ad_request_standard_sm_dalvik,
  COUNT_IF(
    request__visitor__user_agent LIKE '%sm-n%'
    OR request__visitor__user_agent LIKE '%sm-g%'
    OR request__visitor__user_agent LIKE '%sm-f%'
    OR request__visitor__user_agent LIKE '%sm-a%'
    OR request__visitor__user_agent LIKE '%sm-j%'
    OR request__visitor__user_agent LIKE '%sm-s%'
    OR request__visitor__user_agent LIKE '%sm-t%'
  ) AS req_ad_request_standard_sm,
  SUM(
    IF(
      CONTAINS(request__context__key_value__key, '_fw_us_privacy')
      OR CONTAINS(request__context__key_value__key, 'us_privacy'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_ccpa_kv,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags, 1048576) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_extra_flag_ccpa_enable_total,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags, 1048576) > 0
      AND (
        CONTAINS(request__context__key_value__key, '_fw_us_privacy')
        OR CONTAINS(request__context__key_value__key, 'us_privacy')
      ),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_extra_flag_ccpa_by_kv,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags, 1048576) = 0
      AND (
        CONTAINS(request__context__key_value__key, '_fw_us_privacy')
        OR CONTAINS(request__context__key_value__key, 'us_privacy')
      )
      AND BITWISE_AND(request__decision_info__flag2, 4194304) = 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_extra_flag_valid_ccpa_kv_opt_in,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags, 1048576) = 0
      AND (
        CONTAINS(request__context__key_value__key, '_fw_us_privacy')
        OR CONTAINS(request__context__key_value__key, 'us_privacy')
      )
      AND BITWISE_AND(request__decision_info__flag2, 4194304) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_extra_flag_invalid_ccpa_kv,
  SUM(
    IF(
      CONTAINS(request__context__key_value__key, '_fw_opt_out'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_fw_opt_out_kv,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_gdpr_v2,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_fw_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 4) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_cookie_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 8) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_gdpr_default_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 16) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_gpc_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 32) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_ccpa_default_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 64) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_coppa_opt_out_by_kv,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 128) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_lat_kv_consent_string_valid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 256) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_lat_kv_consent_string_exist_but_invalid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 512) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_atts_kv_consent_string_valid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 1024) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_atts_kv_consent_string_exist_but_invalid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 2048) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_ccpa_kv_consent_string_valid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 4096) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_ccpa_kv_consent_string_exist_but_invalid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 8192) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_coppa_kv_consent_string_valid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 16384) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_coppa_kv_consent_string_exist_but_invalid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 32768) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_fw_opt_out_kv_consent_string_valid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 65536) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_fw_opt_out_kv_consent_string_exist_but_invalid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 131072) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_gpc_header_consent_string_valid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 262144) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_gpc_header_consent_string_exist_but_invalid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 128 + 512 + 2048 + 8192 + 32768 + 131072) = 0
      AND BITWISE_AND(request__privacy_info__gdpr_flag, 1024) = 0
      AND BITWISE_AND(request__privacy_info__gpp__flag, 16) = 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_no_valid_privacy_singal,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_impacted_features_pii_to_be_removed,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_impacted_features_frequency_capping_disabled,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 4) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_impacted_features_audience_targeting_disabled,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 8) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_impacted_features_geo_targeting_disabled,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 16) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_impacted_features_precise_geo_targeting_disabled,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 32) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_impacted_features_sensitive_data_need_removal,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 64) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_impacted_features_us_privacy_pii_need_removal,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 128) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_impacted_features_coppa_pii_need_removal,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 256) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_impacted_features_gpc_pii_need_removal,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 512) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_impacted_features_macro_expansion_disabled,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 8 + 16) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_impacted_features_postal_code_targeting_disabled,
  SUM(
    IF(
      (
        BITWISE_AND(request__extra_flags2, 64) > 0
        AND BITWISE_AND(request__privacy_info__gdpr_flag, 32 + 64) > 0
      )
      OR (
        BITWISE_AND(request__extra_flags2, 64) = 0
        AND BITWISE_AND(request__privacy_info__gdpr_flag, 1) > 0
      ),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_cookie_handling_disabled,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__impacted_features_flag, 32 + 64 + 128 + 256) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_pii_need_removed,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_v2_no_purpose_1,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_v2_no_purpose_2,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 4) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_v2_no_purpose_4,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 8) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_v2_no_purpose_7,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 16) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_v2_no_purpose_10,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 32) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_controller_no_purpose_1,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 64) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_controller_no_purpose_2,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 128) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_controller_no_purpose_4,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 256) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_controller_no_purpose_7,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 512) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_controller_no_purpose_10,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 1024) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_kv_consent_string_valid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 2048) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_kv_consent_string_exist_but_invalid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gdpr_flag, 1023) > 0
      AND BITWISE_AND(request__privacy_info__gdpr_flag, 1024) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_signal_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags, 1048576) > 0
      AND BITWISE_AND(request__privacy_info__compliance_flag, 32) = 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_ccpa_signal_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gpp__flag, 1 + 2 + 8) > 0
      AND BITWISE_AND(request__privacy_info__gpp__flag, 4) = 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gpp_signal_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags, 512) > 0
      AND BITWISE_AND(request__privacy_info__compliance_flag, 64) = 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_coppa_opt_out_inventory,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 8) > 0
      AND BITWISE_AND(request__privacy_info__gdpr_flag, 2048) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_compliance_gdpr_applied_but_consent_string_exit_and_invalid,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags2, 64) > 0
      AND BITWISE_AND(request__privacy_info__gdpr_flag, 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_processor_no_purpose_1,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags2, 64) > 0
      AND BITWISE_AND(request__privacy_info__gdpr_flag, 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_processor_no_purpose_2,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags2, 64) > 0
      AND BITWISE_AND(request__privacy_info__gdpr_flag, 4) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_processor_no_purpose_4,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags2, 64) > 0
      AND BITWISE_AND(request__privacy_info__gdpr_flag, 8) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_processor_no_purpose_7,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags2, 64) > 0
      AND BITWISE_AND(request__privacy_info__gdpr_flag, 16) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_privacy_info_gdpr_processor_no_purpose_10,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags2, 64) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_extra_flags2_tcf_hybrid_mode,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__compliance_flag, 1) > 0
      AND BITWISE_AND(request__extra_flags2, 64) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_tcf_hybrid_gdpr_apply,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 1) > 0) AS req_decision_info_flag1_bit1,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 2) > 0) AS req_decision_info_flag1_bit2,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 4) > 0) AS req_decision_info_flag1_bit3,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 8) > 0) AS req_decision_info_flag1_bit4,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 16) > 0) AS req_decision_info_flag1_bit5,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 32) > 0) AS req_decision_info_flag1_bit6,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 64) > 0) AS req_decision_info_flag1_bit7,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 128) > 0) AS req_decision_info_flag1_bit8,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 256) > 0) AS req_decision_info_flag1_bit9,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 512) > 0) AS req_decision_info_flag1_bit10,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 1024) > 0) AS req_decision_info_flag1_bit11,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 2048) > 0) AS req_decision_info_flag1_bit12,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 4096) > 0) AS req_decision_info_flag1_bit13,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 8192) > 0) AS req_decision_info_flag1_bit14,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 16384) > 0) AS req_decision_info_flag1_bit15,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 32768) > 0) AS req_decision_info_flag1_bit16,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 65536) > 0) AS req_decision_info_flag1_bit17,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 131072) > 0) AS req_decision_info_flag1_bit18,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 262144) > 0) AS req_decision_info_flag1_bit19,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 524288) > 0) AS req_decision_info_flag1_bit20,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 1048576) > 0) AS req_decision_info_flag1_bit21,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 2097152) > 0) AS req_decision_info_flag1_bit22,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 4194304) > 0) AS req_decision_info_flag1_bit23,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 8388608) > 0) AS req_decision_info_flag1_bit24,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 16777216) > 0) AS req_decision_info_flag1_bit25,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 33554432) > 0) AS req_decision_info_flag1_bit26,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 67108864) > 0) AS req_decision_info_flag1_bit27,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 134217728) > 0) AS req_decision_info_flag1_bit28,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 268435456) > 0) AS req_decision_info_flag1_bit29,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 536870912) > 0) AS req_decision_info_flag1_bit30,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 1073741824) > 0) AS req_decision_info_flag1_bit31,
  COUNT_IF(BITWISE_AND(request__decision_info__flag1, 2147483648) > 0) AS req_decision_info_flag1_bit32,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 1) > 0) AS req_decision_info_flag2_bit1,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 2) > 0) AS req_decision_info_flag2_bit2,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 4) > 0) AS req_decision_info_flag2_bit3,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 8) > 0) AS req_decision_info_flag2_bit4,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 16) > 0) AS req_decision_info_flag2_bit5,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 32) > 0) AS req_decision_info_flag2_bit6,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 64) > 0) AS req_decision_info_flag2_bit7,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 128) > 0) AS req_decision_info_flag2_bit8,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 256) > 0) AS req_decision_info_flag2_bit9,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 512) > 0) AS req_decision_info_flag2_bit10,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 1024) > 0) AS req_decision_info_flag2_bit11,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 2048) > 0) AS req_decision_info_flag2_bit12,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 4096) > 0) AS req_decision_info_flag2_bit13,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 8192) > 0) AS req_decision_info_flag2_bit14,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 16384) > 0) AS req_decision_info_flag2_bit15,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 32768) > 0) AS req_decision_info_flag2_bit16,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 65536) > 0) AS req_decision_info_flag2_bit17,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 131072) > 0) AS req_decision_info_flag2_bit18,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 262144) > 0) AS req_decision_info_flag2_bit19,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 524288) > 0) AS req_decision_info_flag2_bit20,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 1048576) > 0) AS req_decision_info_flag2_bit21,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 2097152) > 0) AS req_decision_info_flag2_bit22,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 4194304) > 0) AS req_decision_info_flag2_bit23,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 8388608) > 0) AS req_decision_info_flag2_bit24,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 16777216) > 0) AS req_decision_info_flag2_bit25,
  COUNT_IF(BITWISE_AND(request__flags, 1) = 0) AS req_request_flag_non_prefetch,
  COUNT_IF(
    BITWISE_AND(request__privacy_info__gdpr_flag, 1) > 0
    AND BITWISE_AND(request__privacy_info__gdpr_flag, 2) > 0
    AND BITWISE_AND(request__privacy_info__gdpr_flag, 4) > 0
    AND BITWISE_AND(request__privacy_info__gdpr_flag, 8) > 0
    AND BITWISE_AND(request__privacy_info__gdpr_flag, 16) > 0
  ) AS req_privacy_info_gdpr_v2_no_consent,
  COUNT_IF(request__visitor__filtration_reason = 1001) AS req_filtered_by_dip,
  COUNT_IF(BITWISE_AND(request__flags, 67108864) > 0) AS req_request_flag_hylda_1_n,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 33554432) > 0) AS req_decision_info_flag2_bit26,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 67108864) > 0) AS req_decision_info_flag2_bit27,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 134217728) > 0) AS req_decision_info_flag2_bit28,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 268435456) > 0) AS req_decision_info_flag2_bit29,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 536870912) > 0) AS req_decision_info_flag2_bit30,
  COUNT_IF(BITWISE_AND(request__decision_info__flag2, 1073741824) > 0) AS req_decision_info_flag2_bit31,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 1) > 0) AS req_decision_info_flag3_bit1,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 2) > 0) AS req_decision_info_flag3_bit2,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 4) > 0) AS req_decision_info_flag3_bit3,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 8) > 0) AS req_decision_info_flag3_bit4,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 16) > 0) AS req_decision_info_flag3_bit5,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 32) > 0) AS req_decision_info_flag3_bit6,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 64) > 0) AS req_decision_info_flag3_bit7,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 128) > 0) AS req_decision_info_flag3_bit8,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 256) > 0) AS req_decision_info_flag3_bit9,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 512) > 0) AS req_decision_info_flag3_bit10,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 1024) > 0) AS req_decision_info_flag3_bit11,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 2048) > 0) AS req_decision_info_flag3_bit12,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 4096) > 0) AS req_decision_info_flag3_bit13,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 8192) > 0) AS req_decision_info_flag3_bit14,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 16384) > 0) AS req_decision_info_flag3_bit15,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 32768) > 0) AS req_decision_info_flag3_bit16,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 65536) > 0) AS req_decision_info_flag3_bit17,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 131072) > 0) AS req_decision_info_flag3_bit18,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 262144) > 0) AS req_decision_info_flag3_bit19,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 524288) > 0) AS req_decision_info_flag3_bit20,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 1048576) > 0) AS req_decision_info_flag3_bit21,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 2097152) > 0) AS req_decision_info_flag3_bit22,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 4194304) > 0) AS req_decision_info_flag3_bit23,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 8388608) > 0) AS req_decision_info_flag3_bit24,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 16777216) > 0) AS req_decision_info_flag3_bit25,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 33554432) > 0) AS req_decision_info_flag3_bit26,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 67108864) > 0) AS req_decision_info_flag3_bit27,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 134217728) > 0) AS req_decision_info_flag3_bit28,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 268435456) > 0) AS req_decision_info_flag3_bit29,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 536870912) > 0) AS req_decision_info_flag3_bit30,
  COUNT_IF(BITWISE_AND(request__decision_info__flag3, 1073741824) > 0) AS req_decision_info_flag3_bit31,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 1) > 0) AS req_decision_info_flag4_bit1,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 2) > 0) AS req_decision_info_flag4_bit2,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 4) > 0) AS req_decision_info_flag4_bit3,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 8) > 0) AS req_decision_info_flag4_bit4,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 16) > 0) AS req_decision_info_flag4_bit5,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 32) > 0) AS req_decision_info_flag4_bit6,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 64) > 0) AS req_decision_info_flag4_bit7,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 128) > 0) AS req_decision_info_flag4_bit8,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 256) > 0) AS req_decision_info_flag4_bit9,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 512) > 0) AS req_decision_info_flag4_bit10,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 1024) > 0) AS req_decision_info_flag4_bit11,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 2048) > 0) AS req_decision_info_flag4_bit12,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 4096) > 0) AS req_decision_info_flag4_bit13,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 8192) > 0) AS req_decision_info_flag4_bit14,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 16384) > 0) AS req_decision_info_flag4_bit15,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 134217728) > 0) AS req_decision_info_flag4_bit28,
  COUNT_IF(BITWISE_AND(request__decision_info__flag4, 268435456) > 0) AS req_decision_info_flag4_bit29,
  COUNT_IF(CONTAINS(request__errors__code, 'airing_not_served')) AS req_err_airing_not_served,
  COUNT_IF(CONTAINS(request__errors__code, 'break_not_found_from_repa')) AS req_err_break_not_found_from_repa,
  COUNT_IF(CONTAINS(request__errors__code, 'hylda_kv_not_valid')) AS req_err_hylda_kv_not_all_valid,
  COUNT_IF(CONTAINS(request__errors__code, 'schedule_info_list_empty')) AS req_err_break_no_schedule_ad,
  COUNT_IF(CONTAINS(request__errors__code, 'break_not_configured_cbp_applied')) AS req_err_break_not_configured_cbp_applied,
  COUNT_IF(BITWISE_AND(request__audience_flags, 1) > 0) AS req_audience_flag_xdevice_dx_query,
  COUNT_IF(BITWISE_AND(request__audience_flags, 2) > 0) AS req_audience_flag_xdevice_dx_enriched_id,
  COUNT_IF(BITWISE_AND(request__audience_flags, 4) > 0) AS req_audience_flag_xdevice_dx_enriched_seg,
  COUNT_IF(BITWISE_AND(request__audience_flags, 8) > 0) AS req_audience_flag_xdevice_dx_enriched_plc,
  COUNT_IF(BITWISE_AND(request__audience_flags, 16) > 0) AS req_audience_flag_geo_as_audience_used,
  COUNT_IF(BITWISE_AND(request__audience_flags, 32) > 0) AS req_audience_flag_partial_geo_segment,
  COUNT_IF(CONTAINS(request__errors__code, 'network_not_found')) AS req_err_network_not_found,
  COUNT_IF(CONTAINS(request__errors__code, 'invalid_request')) AS req_err_invalid_request,
  COUNT_IF(CONTAINS(request__errors__code, 'invalid_request_duration')) AS req_err_invalid_request_duration,
  COUNT_IF(CONTAINS(request__errors__code, 'profile_not_found')) AS req_err_profile_not_found,
  COUNT_IF(CONTAINS(request__errors__code, 'root_asset_not_found')) AS req_err_root_asset_not_found,
  COUNT_IF(CONTAINS(request__errors__code, 'geo_not_found')) AS req_err_geo_not_found,
  COUNT_IF(CONTAINS(request__errors__code, 'meta_data_empty')) AS req_err_meta_data_empty,
  COUNT_IF(CONTAINS(request__errors__code, 'cbp_not_found')) AS req_err_cbp_not_found,
  COUNT_IF(CONTAINS(request__errors__code, 'invaild_midroll_slots_without_cbp')) AS req_err_midroll_slot_without_cbp,
  COUNT_IF(CONTAINS(request__errors__code, 'no_valid_video_slots')) AS req_err_no_valid_video_slot,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value1, 255), 1, 0)) AS req_decision_info_value1_1,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value1 / 256, 255), 1, 0)) AS req_decision_info_value1_2,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value1 / 65536, 65535), 1, 0)) AS req_decision_info_value1_3,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value2, 65535), 1, 0)) AS req_decision_info_value2_1,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value2 / 65536, 65535), 1, 0)) AS req_decision_info_value2_2,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value3, 65535), 1, 0)) AS req_decision_info_value3_1,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value3 / 65536, 65535), 1, 0)) AS req_decision_info_value3_2,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value3 / 4294967296, 65535), 1, 0)) AS req_decision_info_value3_3,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value4, 255), 1, 0)) AS req_decision_info_value4_1,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value4 / 256, 255), 1, 0)) AS req_decision_info_value4_2,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value4 / 65536, 255), 1, 0)) AS req_decision_info_value4_3,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value4 / 16777216, 255), 1, 0)) AS req_decision_info_value4_4,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value4 / 4294967296, 255), 1, 0)) AS req_decision_info_value4_5,
  SUM(COALESCE(BITWISE_AND(request__decision_info__value4 / 1099511627776, 255), 1, 0)) AS req_decision_info_value4_6,
  COUNT_IF(BITWISE_AND(request__decision_info__value1 / 65536, 65535) > 20000) AS req_length_more_than_20k,
  COUNT_IF(request__visitor__filtration_reason = 21) AS req_filtered_by_debug_internal_call_but_serve,
  COUNT_IF(BITWISE_AND(request__traffic_compliance__mrc_non_compliance_type, 1) > 0) AS req_non_mrc_compliance_video,
  COUNT_IF(BITWISE_AND(request__traffic_compliance__mrc_non_compliance_type, 2) > 0) AS req_non_mrc_compliance_display,
  COUNT_IF(request__traffic_compliance__endpoint_id = -2) AS req_adm_no_mrc_endpoint,
  COUNT_IF(request__traffic_compliance__endpoint_id = -3) AS req_non_adm_no_mrc_endpoint,
  COUNT_IF(REGEXP_LIKE(request__visitor__caller, '^((js|android|iphone|tvos|as3)-[0-9]).*')) AS req_adm_visitor_caller,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND (
      request__prebid_sivt__gateway_response = 'ok'
    )
  ) AS req_gateway_response_inhouse_ok,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND (
      request__prebid_sivt__gateway_response = 'error'
    )
  ) AS req_gateway_response_inhouse_error,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND (
      request__prebid_sivt__gateway_response = 'timeout'
    )
  ) AS req_gateway_response_inhouse_timeout,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 2) > 0
    )
    AND (
      request__prebid_sivt__gateway_response = 'ok'
    )
  ) AS req_gateway_response_whiteops_ok,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 2) > 0
    )
    AND (
      request__prebid_sivt__gateway_response = 'error'
    )
  ) AS req_gateway_response_whiteops_error,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 2) > 0
    )
    AND (
      request__prebid_sivt__gateway_response = 'timeout'
    )
  ) AS req_gateway_response_whiteops_timeout,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND (
      request__prebid_sivt__inhouse__invalid_reason = 0
    )
  ) AS req_inhouse_valid_traffic,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND (
      request__prebid_sivt__inhouse__invalid_reason > 0
    )
  ) AS req_inhouse_invalid_traffic,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND (
      request__prebid_sivt__inhouse__is_whitelisted = TRUE
    )
  ) AS req_inhouse_whitelisted_traffic,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 2) > 0
    )
    AND (
      request__prebid_sivt__whiteops__invalid_reason = 0
    )
  ) AS req_whiteops_valid_traffic,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 2) > 0
    )
    AND (
      request__prebid_sivt__whiteops__invalid_reason > 0
    )
  ) AS req_whiteops_invalid_traffic,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__inhouse__invalid_reason, 1) > 0
  ) AS req_inhouse_malicious_ip,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__inhouse__invalid_reason, 2) > 0
  ) AS req_inhouse_invalid_data_center,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__inhouse__invalid_reason, 4) > 0
  ) AS req_inhouse_prefetch_outlier,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__inhouse__invalid_reason, 8) > 0
  ) AS req_inhouse_non_prefetch_outlier,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__inhouse__invalid_reason, 16) > 0
  ) AS req_inhouse_ctr_by_ip,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__inhouse__invalid_reason, 32) > 0
  ) AS req_inhouse_ctr_by_user,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__inhouse__invalid_reason, 64) > 0
  ) AS req_inhouse_repeat_transaction,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__inhouse__invalid_reason, 128) > 0
  ) AS req_inhouse_speed_of_transaction,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__inhouse__invalid_reason, 256) > 0
  ) AS req_inhouse_interval_testing,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 2) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 1) > 0
  ) AS req_whiteops_automated_browsing,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 2) > 0
  ) AS req_whiteops_data_center,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 4) > 0
  ) AS req_whiteops_false_representation,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 8) > 0
  ) AS req_whiteops_irregular_pattern,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 16) > 0
  ) AS req_whiteops_known_crawler,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 32) > 0
  ) AS req_whiteops_manipulated_behaviour,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 64) > 0
  ) AS req_whiteops_misleading_user_interface,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 128) > 0
  ) AS req_whiteops_undisclosed_classification,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__sivt_model, 1) > 0
    )
    AND BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 256) > 0
  ) AS req_whiteops_undisclosed_use_of_incentives,
  COUNT_IF(CONTAINS(request__context__key_value__key, '_fw_did_idfa')) AS req_from_apple_device,
  SUM(
    IF(
      CONTAINS(request__context__key_value__key, '_fw_atts'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_atts_key,
  SUM(
    IF(
      CONTAINS(request__context__key_value__key, '_fw_atts')
      AND BITWISE_AND(request__extra_flags, 134217728) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_atts_restricted,
  SUM(
    IF(
      CONTAINS(request__context__key_value__key, '_fw_atts')
      AND BITWISE_AND(request__extra_flags, 134217728) = 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_atts_authorized,
  COUNT_IF(
    ARRAY_POSITION(request__context__key_value__key, '_fw_did') > 0
    AND request__context__key_value__value[ARRAY_POSITION(request__context__key_value__key, '_fw_did')] LIKE '%idfa%'
  ) AS req_device_id_with_idfa,
  COUNT_IF(BITWISE_AND(request__extra_flags2, 2) > 0) AS req_extra_flags2_fs_js_tracking,
  COUNT_IF(BITWISE_AND(request__extra_flags2, 4) > 0) AS req_extra_flags2_fs_pixel_tracking,
  COUNT_IF(NOT request__prebid_sivt__whiteops IS NULL) AS req_fw_send_mg_requests,
  COUNT_IF(NOT request__prebid_sivt__whiteops__invalid_reason IS NULL) AS req_mg_return_results_requests,
  COUNT_IF(
    NOT request__visitor__filtration_reason IN (23, 24)
    AND request__prebid_sivt__gateway_response IS NULL
    AND NOT request__prebid_sivt__whiteops IS NULL
  ) AS req_fw_internal_error,
  COUNT_IF(request__prebid_sivt__gateway_response = 'error') AS req_fw_ivt_gateway_response_error,
  COUNT_IF(request__prebid_sivt__gateway_response = 'timeout') AS req_fw_ivt_gateway_response_timeout,
  COUNT_IF(request__prebid_sivt__gateway_response = 'ok') AS req_fw_ivt_gateway_response_ok,
  COUNT_IF(request__prebid_sivt__whiteops__invalid_reason = 0) AS req_mg_valid_requests,
  COUNT_IF(request__prebid_sivt__whiteops__invalid_reason > 0) AS req_mg_invalid_requests,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 2) > 0
    )
    OR (
      BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 8) > 0
    )
    OR (
      BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 16) > 0
    )
  ) AS req_mg_givt,
  COUNT_IF(
    (
      BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 1) > 0
    )
    OR (
      BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 4) > 0
    )
    OR (
      BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 32) > 0
    )
    OR (
      BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 64) > 0
    )
    OR (
      BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 128) > 0
    )
    OR (
      BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 256) > 0
    )
  ) AS req_mg_sivt,
  COUNT_IF(BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 1) > 0) AS req_sivt_automated_browser,
  COUNT_IF(BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 2) > 0) AS req_givt_data_center,
  COUNT_IF(BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 4) > 0) AS req_sivt_false_representation,
  COUNT_IF(BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 8) > 0) AS req_givt_irregular_pattern,
  COUNT_IF(BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 16) > 0) AS req_givt_known_crawler,
  COUNT_IF(BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 32) > 0) AS req_sivt_manipulated_behaviour,
  COUNT_IF(BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 64) > 0) AS req_sivt_misleading_user_interface,
  COUNT_IF(BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 128) > 0) AS req_sivt_undisclosed_classification,
  COUNT_IF(BITWISE_AND(request__prebid_sivt__whiteops__invalid_reason, 256) > 0) AS req_sivt_undisclosed_use_of_incentives,
  SUM(
    IF(
      NOT request__privacy_info__gpp IS NULL,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_valid_gpp_string,
  SUM(
    IF(
      (
        BITWISE_AND(request__privacy_info__gpp__section, 1) > 0
      )
      OR (
        BITWISE_AND(request__privacy_info__gpp__section, 2) > 0
      )
      OR (
        BITWISE_AND(request__privacy_info__gpp__section, 4) > 0
      )
      OR (
        BITWISE_AND(request__privacy_info__gpp__section, 8) > 0
      )
      OR (
        BITWISE_AND(request__privacy_info__gpp__section, 16) > 0
      )
      OR (
        BITWISE_AND(request__privacy_info__gpp__section, 32) > 0
      ),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_valid_gpp_string_with_new_sections,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gpp__flag, 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_spi_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__audience_flags, 128) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_spi_audience_restricted,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gpp__flag, 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_gpp_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gpp__flag, 8) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_gpp_children_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gpp__flag, 4) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_gpp_us_privacy_default_opt_out,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gpp__flag, 16) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_gpp_kv_consent_string_valid,
  SUM(
    IF(
      BITWISE_AND(request__privacy_info__gpp__flag, 32) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_with_gpp_kv_consent_exist_but_invalid,
  COUNT_IF(BITWISE_AND(request__extra_flags2, 8192) > 0) AS req_iqs_tracking,
  COUNT_IF(BITWISE_AND(request__extra_flags2, 16777216) > 0) AS req_linear_break_dropped,
  SUM(COALESCE(request__advertisement_count, 0)) AS req_log_ad_cnt,
  SUM(COALESCE(request__advertisement_delivered_count, 0)) AS req_delivered_ad_cnt
FROM ${bcv_transaction} AS t1
LEFT JOIN db.default.d_network AS cro
  ON cro.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS dis
  ON dis.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_lu_dma AS lud
  ON lud.code = COALESCE(request__visitor__dma_code, -1)
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = request__visitor__country_id
LEFT JOIN db.default.d_lu_state AS st
  ON st.id = request__visitor__state_id
WHERE
  request__is_first_request = TRUE
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
