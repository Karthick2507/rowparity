-- account:    sa-dataapp-yield
-- skeleton:   7f67b794c00d508e0086802e8d9e9084
-- pattern:    759feb4ab82fa9afbbf2fcba6e5afe92  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     ad
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
  COALESCE(advertisement__ad_oo_network_id, -1) AS ad_network_id,
  COALESCE(ad_nw.name, 'na') AS ad_network_name,
  COALESCE(advertisement__external_reseller__network_id, -1) AS ad_external_network_id,
  IF(advertisement__external_reseller__network_id = -1, 'na', COALESCE(ex_nw.name, 'na')) AS ad_external_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
  COALESCE(visitor__user_agent_device_type, 'na') AS platform,
  COALESCE(visitor__platform_group, 'na') AS platform_group,
  COALESCE(platform_browser.name, 'na') AS browser_name,
  COALESCE(platform_os.name, 'na') AS os_name,
  COALESCE(platform_device.name, 'na') AS device_name,
  COALESCE(visitor__user_agent_device_type, 'na') AS device_type,
  COALESCE(request__server_group, 'na') AS server_group,
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
  CASE
    WHEN BITWISE_AND(advertisement__extra_flags, 67108864) > 0
    THEN 'true'
    ELSE 'false'
  END AS creative_auto_select,
  CASE
    WHEN BITWISE_AND(advertisement__extra_flags, 524288) > 0
    OR BITWISE_AND(advertisement__flags, 2097152) > 0
    THEN 'true'
    ELSE 'false'
  END AS replaceable_for_yield,
  CASE WHEN BITWISE_AND(request__flags, 33554432) > 0 THEN 'true' ELSE 'false' END AS req_has_hylda_kv,
  SUM(IF(BITWISE_AND(advertisement__flags, 8) > 0, 1, 0)) AS ad_delivered_ad_flag_guaranteed_inventory,
  SUM(IF(BITWISE_AND(advertisement__flags, 32) > 0, 1, 0)) AS ad_delivered_ad_flag_fallback,
  SUM(IF(BITWISE_AND(advertisement__flags, 128) > 0, 1, 0)) AS ad_delivered_ad_flag_bumper,
  SUM(IF(BITWISE_AND(advertisement__flags, 512) > 0, 1, 0)) AS ad_delivered_ad_flag_has_fallback,
  SUM(IF(BITWISE_AND(advertisement__flags, 1024) > 0, 1, 0)) AS ad_delivered_ad_flag_meet_schedule,
  SUM(IF(BITWISE_AND(advertisement__flags, 2048) > 0, 1, 0)) AS ad_delivered_ad_flag_force_repeated,
  SUM(IF(BITWISE_AND(advertisement__flags, 16384) > 0, 1, 0)) AS ad_delivered_ad_flag_looped,
  SUM(IF(BITWISE_AND(advertisement__flags, 32768) > 0, 1, 0)) AS ad_delivered_ad_flag_static_schedule,
  SUM(IF(BITWISE_AND(advertisement__flags, 65536) > 0, 1, 0)) AS ad_delivered_ad_flag_cpx_compositional,
  SUM(IF(BITWISE_AND(advertisement__flags, 131072) > 0, 1, 0)) AS ad_delivered_ad_flag_cpx_include_in_billable_rate,
  SUM(IF(BITWISE_AND(advertisement__flags, 262144) > 0, 1, 0)) AS ad_delivered_ad_flag_committed_inventory,
  SUM(IF(BITWISE_AND(advertisement__flags, 524288) > 0, 1, 0)) AS ad_delivered_ad_flag_hylda_placeholder,
  SUM(IF(BITWISE_AND(advertisement__flags, 1048576) > 0, 1, 0)) AS ad_delivered_ad_flag_repeat_within_slot,
  SUM(IF(BITWISE_AND(advertisement__flags, 2097152) > 0, 1, 0)) AS ad_delivered_ad_flag_hylda_replacement,
  SUM(IF(BITWISE_AND(advertisement__flags, 4194304) > 0, 1, 0)) AS ad_delivered_ad_flag_market_ad,
  SUM(IF(BITWISE_AND(advertisement__flags, 8388608) > 0, 1, 0)) AS ad_delivered_ad_flag_invalid_playlist_ack,
  SUM(IF(BITWISE_AND(advertisement__flags, 16777216) > 0, 1, 0)) AS ad_delivered_ad_flag_rbp_ad,
  SUM(IF(BITWISE_AND(advertisement__flags, 33554432) > 0, 1, 0)) AS ad_delivered_ad_flag_sstf_fallback,
  SUM(IF(BITWISE_AND(advertisement__flags, 67108864) > 0, 1, 0)) AS ad_delivered_ad_flag_sstf_failed,
  SUM(IF(BITWISE_AND(advertisement__flags, 134217728) > 0, 1, 0)) AS ad_delivered_ad_flag_sstf_fallback_enabled,
  SUM(IF(BITWISE_AND(advertisement__flags, 268435456) > 0, 1, 0)) AS ad_delivered_ad_flag_client_fallback_enabled,
  SUM(IF(BITWISE_AND(advertisement__flags, 536870912) > 0, 1, 0)) AS ad_delivered_ad_flag_driving_fallback,
  SUM(IF(BITWISE_AND(advertisement__flags, 1073741824) > 0, 1, 0)) AS ad_delivered_ad_flag_rbp_placement_beacon_generated,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 1) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_linear_dynamic,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 2) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_linear_default,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 4) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_id_graph_enriched,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 16) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_rbp_mobile,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 128) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_evergreen_into_fallback_non_addressable,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 256) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_evergreen_into_non_addressable,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 512) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_evergreen_into_addressable,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 1024) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_creative_audience_targeting_fail,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 2048) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_inactive_addressable_ad_fallback,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 4096) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_bidding_price_recommendation,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 8192) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_reseller_optimized_ad_ranking,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 65536) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_swap_out_condition_none,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 131072) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_swap_out_condition_budget_reached,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 262144) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_swap_out_condition_audience_targeting_unmet,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 524288) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_scheduled_ad_replaceable,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 1048576) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_ax_ad,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 2097152) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_creative_audience_targeitng_success,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 4194304) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_creative_audience_targeitng_default,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 67108864) > 0, 1, 0)) AS ad_delivered_ad_extra_flag_creative_auto_select,
  SUM(1) AS ad_delivered_ad,
  SUM(IF(BITWISE_AND(advertisement__flags, 32) = 0, 1, 0)) AS ad_delivered_ad_primary,
  SUM(IF(BITWISE_AND(advertisement__flags, 32) > 0, 1, 0)) AS ad_delivered_ad_fallback,
  SUM(IF(slot__environment = 'video', 1, 0)) AS ad_delivered_video_ad,
  SUM(IF(slot__environment <> 'video', 1, 0)) AS ad_delivered_display_ad,
  SUM(IF(BITWISE_AND(advertisement__flags, 2) > 0, 1, 0)) AS ad_delivered_ad_flag_external
FROM ${bcv_ad} AS a
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_network AS ad_nw
  ON ad_nw.id = advertisement__ad_oo_network_id
LEFT JOIN db.default.d_network AS ex_nw
  ON ex_nw.id = advertisement__external_reseller__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_lu_dma AS lud
  ON lud.code = COALESCE(visitor__dma_code, -1)
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = visitor__country_id
LEFT JOIN db.default.d_lu_state AS st
  ON st.id = visitor__state_id
LEFT JOIN db.default.d_lu_user_agent_platform AS platform_browser
  ON platform_browser.id = visitor__platform_browser_id
LEFT JOIN db.default.d_lu_user_agent_platform AS platform_os
  ON platform_os.id = visitor__platform_os_id
LEFT JOIN db.default.d_lu_user_agent_platform AS platform_device
  ON platform_device.id = visitor__platform_device_id
WHERE
  (
    request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
  )
  AND NOT advertisement__ad_id IS NULL
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
  24
