-- account:    sa-dataapp-yield
-- skeleton:   86d4da3b6342326f4f3cd3fe3a39457b
-- pattern:    3a3fd06dc8bb767e35c6bab8ee95ee05  (696 execution(s))
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
  SUM(1) AS ad_delivered_ad,
  SUM(IF(BITWISE_AND(advertisement__flags, 32) = 0, 1, 0)) AS ad_delivered_ad_primary,
  SUM(IF(BITWISE_AND(advertisement__flags, 32) > 0, 1, 0)) AS ad_delivered_ad_fallback,
  SUM(
    IF(
      COALESCE(candidate__integration_type, 'na') IN ('openrtb_pg_td', 'openrtb_normal'),
      1,
      0
    )
  ) AS ad_delivered_prog_ad,
  SUM(
    IF(
      COALESCE(candidate__integration_type, 'na') IN ('openrtb_pg_td', 'openrtb_normal')
      AND BITWISE_AND(advertisement__flags, 32) = 0,
      1,
      0
    )
  ) AS ad_delivered_prog_ad_primary,
  SUM(
    IF(
      BITWISE_AND(advertisement__flags, 32) > 0
      AND BITWISE_AND(advertisement__flags, 33554432) > 0,
      1,
      0
    )
  ) AS ad_delivered_as_sstf_fallback,
  SUM(IF(BITWISE_AND(COALESCE(advertisement__extra_flags2, 0), 131072) > 0, 1, 0)) AS ad_delivered_in_high_value_bucket,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 1024) > 0, 1, 0)) AS ad_err_full_avail_no_variant_segment,
  SUM(
    IF(
      BITWISE_AND(advertisement__extra_flags, 128) > 0
      OR BITWISE_AND(advertisement__extra_flags, 256) > 0
      OR BITWISE_AND(advertisement__extra_flags, 512) > 0,
      1,
      0
    )
  ) AS ad_err_fallback_to_evergreen,
  SUM(
    IF(
      BITWISE_AND(advertisement__extra_flags, 128) > 0
      OR BITWISE_AND(advertisement__extra_flags, 256) > 0,
      1,
      0
    )
  ) AS ad_err_non_addressable_fallback_to_evergreen_internal,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 512) > 0, 1, 0)) AS ad_err_addressable_fallback_to_evergreen_internal,
  SUM(IF(BITWISE_AND(advertisement__extra_flags, 2048) > 0, 1, 0)) AS ad_err_inactive_addressable_order
FROM ${bcv_ad} AS a
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
