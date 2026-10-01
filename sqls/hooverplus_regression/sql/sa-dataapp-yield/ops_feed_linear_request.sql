-- account:    sa-dataapp-yield
-- skeleton:   2ff517d78ecbc61264e2c9091e4475c6
-- pattern:    0b5388b71a258a2d16803acd5e83a016  (696 execution(s))
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
  COALESCE(request__context__po_type, 'na') AS po_type,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(request__context__video_cro_context_id, -1) AS video_cro_site_section_id,
  COALESCE(request__context__site_section_cro_asset_id, -1) AS distributor_site_section_id,
  CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
  CASE request__visitor__active_state WHEN FALSE THEN 'false' ELSE 'true' END AS is_active_device,
  CASE request__prebid_sivt__capnedit__traffic_valid
    WHEN FALSE
    THEN 'false'
    ELSE 'true'
  END AS is_capnedit_traffic_valid,
  CASE WHEN CARDINALITY(request__linear_capnedit) > 0 THEN 'true' ELSE 'false' END AS has_capnedit,
  CASE WHEN request__visitor__filtration_reason = 22 THEN 'true' ELSE 'false' END AS is_filtered_by_capnedit,
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
  IF(
    BITWISE_AND(request__extra_flags, 1024) > 0,
    COALESCE(request__visitor__syscode, -1),
    -1
  ) AS syscode,
  IF(
    BITWISE_AND(request__extra_flags, 1024) > 0,
    COALESCE(luz.name, 'unknown syscode'),
    'unknown syscode'
  ) AS syscode_name,
  IF(
    BITWISE_AND(request__extra_flags, 1024) > 0,
    COALESCE(request__context__station_id, 'na'),
    'na'
  ) AS station_id,
  IF(
    BITWISE_AND(request__extra_flags, 1024) > 0,
    COALESCE(request__context__stream_id, 'na'),
    'na'
  ) AS stream_id,
  IF(
    BITWISE_AND(request__extra_flags, 1024) > 0,
    COALESCE(request__context__source_id, 'na'),
    'na'
  ) AS source_id,
  IF(
    BITWISE_AND(request__extra_flags, 1024) > 0,
    COALESCE(request__context__asset_chain__content_right_owner__airing_channel_id, -1),
    -1
  ) AS channel_id,
  IF(
    BITWISE_AND(request__extra_flags, 1024) > 0,
    COALESCE(request__context__tv_network_id, -1),
    -1
  ) AS tv_network_id,
  COALESCE(tvn.name, 'na') AS tv_network_name,
  IF(BITWISE_AND(request__extra_flags, 1024) > 0, COALESCE(tvn.mrm_network_id, -1), -1) AS tv_network_mrm_id,
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
    IF(
      BITWISE_AND(request__decision_info__flag2, 536870912) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_capnedit_use_default_threshold_internal,
  SUM(
    IF(
      BITWISE_AND(request__prebid_sivt__capnedit__invalid_reason, 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_capnedit_invalid_reason_inactive_state_internal,
  SUM(
    IF(
      BITWISE_AND(request__prebid_sivt__capnedit__invalid_reason, 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_capnedit_invalid_reason_is_dvr_internal,
  SUM(
    IF(
      BITWISE_AND(request__prebid_sivt__capnedit__invalid_reason, 4) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_capnedit_invalid_reason_inactive_session_internal,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'linear_request_no_profile'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_no_profile,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'stb_request_no_terminal_address'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_no_mac_address,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'signal_id_invalid'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_no_signal_id,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'stb_request_syscode_not_found')
      OR CONTAINS(request__errors__code, 'vde_request_syscode_not_found'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_syscode_not_found,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'station_not_found'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_station_not_found,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'linear_channel_not_found'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_schedule_not_found,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'break_id_not_found'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_signal_no_bind_break,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'break_not_found_from_repa'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_break_not_found_from_repa_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag2, 4) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_signal_not_processed_by_p2_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag2, 8) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_break_not_found_in_as_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag2, 256) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_break_not_found_ads_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag2, 512) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_break_bind_by_ads_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag2, 32768) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_station_no_channel,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'break_duration_invalid'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_break_duration_invalid,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'schedule_info_list_empty'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_break_no_schedule_ad,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'programmer_poid_not_found'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_programmer_poid_not_found_internal,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'programmer_network_not_found'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_programmer_network_not_found_internal,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'linear_poid_invalid_in_req'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_programmer_poid_invalid_internal,
  SUM(
    IF(
      CONTAINS(request__errors__code, 'linear_request_no_po_type'),
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_programmer_no_po_type_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag1, 16777216) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_evergreen_rendition_load_failed_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag2, 16) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_schedule_ad_initialize_failed_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag1, 128) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_schedule_creative_validation_failed,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag2, 64) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_creative_duration_invalid_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag2, 32) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_schedule_ad_fill_failed_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag2, 1024) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_p2_invalid_break_on_syscode_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag2, 268435456) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_enable_p1_late_bind_internal,
  SUM(
    IF(
      request__context__linear_break_source = 1,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_break_source_from_ads_local_cache_internal,
  SUM(
    IF(
      request__context__linear_break_source = 2,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_break_source_from_ads_decision_internal,
  SUM(
    IF(
      request__context__linear_break_source = 3,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_break_source_from_as_break_signal_internal,
  SUM(
    IF(
      request__context__linear_break_source = 4,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_break_source_from_signal_binder_internal,
  SUM(
    IF(
      request__context__linear_break_source = 5,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_break_source_from_request_override_internal,
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
      BITWISE_AND(request__decision_info__flag2, 2048) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_p1_bind_empty_window_ads_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag2, 4096) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_p1_bind_window_no_break_ads_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag3, 1024) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_max_interval_bs_with_current_epoch_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag3, 2048) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_addressable_disabled_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag3, 524288) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_err_max_interval_cross_signals_in_one_break_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag3, 4194304) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_fod_break_internal,
  SUM(
    IF(
      BITWISE_AND(request__decision_info__flag3, 8192) > 0,
      COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS req_fod_creative_internal
FROM ${bcv_transaction} AS a
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_lu_dma AS lud
  ON lud.id = request__visitor__dma_code_id
LEFT JOIN db.default.d_lu_operator_zone AS luz
  ON luz.id = request__visitor__operator_zone_id
LEFT JOIN db.default.d_linear_television_network AS tvn
  ON tvn.id = request__context__tv_network_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = request__visitor__country_id
LEFT JOIN db.default.d_lu_state AS st
  ON st.id = request__visitor__state_id
WHERE
  (
    (
      request__is_first_request
      AND (
        request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
      )
    )
    AND (
      BITWISE_AND(request__extra_flags, 1024) > 0
      OR BITWISE_AND(request__extra_flags, 128) > 0
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
  34
