-- account:    sa-dataapp-yield
-- skeleton:   782899ae6cee8d4a55af526c7064be35
-- pattern:    653ab6d7e7a4a3b924d6d5cda4365466  (697 execution(s))
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
  COALESCE(request__context__po_type, 'na') AS po_type,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(request__context__video_cro_context_id, -1) AS video_cro_site_section_id,
  COALESCE(request__context__site_section_cro_asset_id, -1) AS distributor_site_section_id,
  CASE WHEN request__is_filtered THEN 'true' ELSE 'false' END AS is_filtered,
  CASE visitor__active_state WHEN FALSE THEN 'false' ELSE 'true' END AS is_active_device,
  CASE request__prebid_sivt__capnedit__traffic_valid
    WHEN FALSE
    THEN 'false'
    ELSE 'true'
  END AS is_capnedit_traffic_valid,
  CASE WHEN CARDINALITY(request__linear_capnedit) > 0 THEN 'true' ELSE 'false' END AS has_capnedit,
  CASE WHEN visitor__filtration_reason = 22 THEN 'true' ELSE 'false' END AS is_filtered_by_capnedit,
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
  COALESCE(visitor__user_agent_device_type, 'na') AS platform,
  COALESCE(request__server_group, 'na') AS server_group,
  COALESCE(request__server_pool, 'na') AS server_pool,
  CASE
    WHEN STRPOS(slot__time_position_class, 'preroll') > 0
    THEN 'preroll'
    WHEN STRPOS(slot__time_position_class, 'midroll') > 0
    THEN 'midroll'
    WHEN STRPOS(slot__time_position_class, 'postroll') > 0
    THEN 'postroll'
    WHEN STRPOS(slot__time_position_class, 'overlay') > 0
    THEN 'overlay'
    WHEN STRPOS(slot__time_position_class, 'display') > 0
    THEN 'display'
    ELSE 'na'
  END AS ad_unit_type,
  COALESCE(visitor__country, 'unknown country') AS country,
  COALESCE(ctry.description, 'unknown country') AS country_name,
  COALESCE(visitor__state, 'unknown state') AS state,
  COALESCE(st.description, 'unknown state') AS state_name,
  IF(visitor__country_id = 165, COALESCE(visitor__dma_code, -1), -1) AS dma,
  IF(visitor__country_id = 165, COALESCE(lud.description, 'unknown dma'), 'unknown dma') AS dma_name,
  IF(BITWISE_AND(request__extra_flags, 1024) > 0, COALESCE(visitor__syscode, -1), -1) AS syscode,
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
    (
      IF(
        partners__airing_channel_id IS NULL OR ARRAY_POSITION(partners__role, 'cro') = 0,
        -1,
        ELEMENT_AT(partners__airing_channel_id, ARRAY_POSITION(partners__role, 'cro'))
      )
    ),
    -1
  ) AS channel_id,
  IF(
    BITWISE_AND(request__extra_flags, 1024) > 0,
    COALESCE(request__context__tv_network_id, -1),
    -1
  ) AS tv_network_id,
  IF(BITWISE_AND(request__extra_flags, 1024) > 0, COALESCE(tvn.name, 'na'), 'na') AS tv_network_name,
  IF(BITWISE_AND(request__extra_flags, 1024) > 0, COALESCE(tvn.mrm_network_id, -1), -1) AS tv_network_mrm_id,
  CASE
    WHEN NOT advertisement__extra_flags IS NULL
    AND BITWISE_AND(advertisement__extra_flags, 3) = 1
    THEN 'dynvar'
    WHEN NOT advertisement__extra_flags IS NULL
    AND BITWISE_AND(advertisement__extra_flags, 3) = 2
    THEN 'dynear'
    WHEN NOT advertisement__extra_flags IS NULL
    AND BITWISE_AND(advertisement__extra_flags, 3) = 3
    THEN 'default'
    WHEN NOT advertisement__extra_flags IS NULL
    AND BITWISE_AND(advertisement__extra_flags, 3) = 0
    THEN 'linear'
    ELSE 'na'
  END AS linear_campaign_type,
  COALESCE(slot__avail_type, 'na') AS spot_type,
  SUM(
    IF(
      BITWISE_AND(request__extra_flags, 16384) > 0,
      COALESCE(ack__metrics__ad_insertion, 0),
      COALESCE(ack__metrics__raw_ad_impression, 0)
    )
  ) AS ack_ad_impression,
  SUM(COALESCE(ack__metrics__complete_quartile, 0)) AS ack_ad_complete,
  SUM(COALESCE(ack__metrics__first_quartile, 0)) AS ack_ad_first_quartile,
  SUM(COALESCE(ack__metrics__middle_quartile, 0)) AS ack_ad_mid_point,
  SUM(COALESCE(ack__metrics__third_quartile, 0)) AS ack_ad_third_quartile,
  SUM(COALESCE(ack__metrics__click, 0)) AS ack_ad_click,
  SUM(
    IF(
      COALESCE(candidate__integration_type, 'na') IN ('openrtb_pg_td', 'openrtb_normal'),
      COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_ad_prog_impression,
  SUM(
    IF(
      BITWISE_AND(advertisement__flags, 32) > 0
      AND BITWISE_AND(advertisement__flags, 33554432) > 0,
      COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_ad_impression_as_sstf_fallback,
  SUM(
    IF(
      BITWISE_AND(COALESCE(advertisement__extra_flags2, 0), 131072) > 0,
      IF(
        BITWISE_AND(request__extra_flags, 16384) > 0,
        COALESCE(ack__metrics__ad_insertion, 0),
        COALESCE(ack__metrics__raw_ad_impression, 0)
      ),
      0
    )
  ) AS ack_ad_impression_in_high_value_bucket,
  SUM(IF(ack__event_type = 'e' AND ack__event_value = '2', 1, 0)) AS ack_err_psn_message_validation_failed,
  SUM(IF(ack__event_type = 'e' AND ack__event_value = '11', 1, 0)) AS ack_err_psn_asset_info_invalid,
  SUM(IF(ack__event_type = 'e' AND ack__event_value = '14', 1, 0)) AS ack_err_psn_unknown_message_reference,
  SUM(IF(ack__event_type = 'e' AND ack__event_value = '17', 1, 0)) AS ack_err_psn_timeout,
  SUM(IF(ack__event_type = 'e' AND ack__event_value = '18', 1, 0)) AS ack_err_psn_insertion_point_time_exceeded,
  SUM(IF(ack__event_type = 'e' AND ack__event_value = '3004', 1, 0)) AS ack_err_psn_abnormal_termination_of_playout,
  SUM(IF(ack__event_type = 'e' AND ack__event_value = '3011', 1, 0)) AS ack_err_psn_bit_rate_mismatch,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'invalidversion', 1, 0)) AS ack_err_psn_event_invalid_version,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'messagemalformed', 1, 0)) AS ack_err_psn_event_message_malformed,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'missingcontentlocation', 1, 0)) AS ack_err_psn_event_missing_content_location,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'assetdurationgap', 1, 0)) AS ack_err_psn_event_asset_duration_gap,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'assetdurationexceeded', 1, 0)) AS ack_err_psn_event_asset_duration_exceeded,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'playoutshortened', 1, 0)) AS ack_err_psn_event_playout_shortened,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'assetunreachable', 1, 0)) AS ack_err_psn_event_asset_unreachable,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'unexpectedadtermination', 1, 0)) AS ack_err_psn_event_unexpected_ad_termination,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'timeoutonassetfetch', 1, 0)) AS ack_err_psn_event_timeout_on_asset_fetch,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'matchingtypenotfound', 1, 0)) AS ack_err_psn_event_matching_type_not_found,
  SUM(
    IF(ack__event_type = 'e' AND ack__event_name = 'matchingaudiotypenotfound', 1, 0)
  ) AS ack_err_psn_event_matching_audio_type_not_found,
  SUM(
    IF(ack__event_type = 'e' AND ack__event_name = 'missingmediatypeattributes', 1, 0)
  ) AS ack_err_psn_event_missing_media_type_attributes,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'qamgatewayoutputmuted', 1, 0)) AS ack_err_psn_event_qam_gateway_output_muted,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'assetplayoutexceeded', 1, 0)) AS ack_err_psn_event_asset_playout_exceeded,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'messagerefmismatch', 1, 0)) AS ack_err_psn_event_message_ref_mismatch,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'lateplacementresponse', 1, 0)) AS ack_err_psn_event_late_placement_response,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'lateplacement', 1, 0)) AS ack_err_psn_event_late_placement,
  SUM(
    IF(ack__event_type = 'e' AND ack__event_name = 'placementresponsenotreceived', 1, 0)
  ) AS ack_err_psn_event_placement_response_not_received,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'insertionpointdelta', 1, 0)) AS ack_err_psn_event_insertion_point_delta,
  SUM(
    IF(ack__event_type = 'e' AND ack__event_name = 'abnormalplayouttermination', 1, 0)
  ) AS ack_err_psn_event_abnormal_play_out_termination,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'bitratemismatch', 1, 0)) AS ack_err_psn_event_bitrate_mismatch,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'corruptedasset', 1, 0)) AS ack_err_psn_event_corrupted_asset,
  SUM(
    IF(ack__event_type = 'e' AND ack__event_name = 'incompatiblestreamcomponents', 1, 0)
  ) AS ack_err_psn_event_incompatible_stream_components,
  SUM(IF(ack__event_type = 'e' AND ack__event_name = 'linearstatus', 1, 0)) AS ack_err_psn_event_linear_status
FROM ${bcv_ack} AS a
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_lu_dma AS lud
  ON lud.id = visitor__dma_code_id
LEFT JOIN db.default.d_lu_operator_zone AS luz
  ON luz.id = visitor__operator_zone_id
LEFT JOIN db.default.d_linear_television_network AS tvn
  ON tvn.id = request__context__tv_network_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = visitor__country_id
LEFT JOIN db.default.d_lu_state AS st
  ON st.id = visitor__state_id
WHERE
  (
    request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
  )
  AND (
    BITWISE_AND(request__extra_flags, 1024) > 0
    OR BITWISE_AND(request__extra_flags, 128) > 0
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
  37
