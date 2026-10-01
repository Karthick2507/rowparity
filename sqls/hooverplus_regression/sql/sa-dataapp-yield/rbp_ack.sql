-- account:    sa-dataapp-yield
-- skeleton:   2fc8d28133a02a9f5c1bce35fb731a40
-- pattern:    624833faf7ddfa89a0436223a09eff55  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  timestamp,
  network_local_time,
  COALESCE(video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(distributor_network_id, -1) AS distributor_network_id,
  COALESCE(dnw.name, 'na') AS distributor_network_name,
  COALESCE(ad_oo_network_id, -1) AS ad_network_id,
  COALESCE(anw.name, 'na') AS ad_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(pf.name, 'na') AS profile_name,
  COALESCE(advertisement__placement_id, -1) AS placement_id,
  rbp_platform,
  platform_group,
  rpt_rbp_platform,
  platform,
  COALESCE(prbb.data_source, 'na') AS rbp_data_source,
  CASE
    WHEN prbb.p2plus_target = 1 AND prbb.nielsen_use_unified_formula <= 0
    THEN 'old p2 plus'
    WHEN prbb.p2plus_target = 1 AND prbb.nielsen_use_unified_formula > 0
    THEN 'new p2 plus'
    WHEN plc.calculation_method = 'direct' AND prbb.nielsen_use_unified_formula <= 0
    THEN 'old direct'
    WHEN plc.calculation_method LIKE '%compositional%'
    AND prbb.nielsen_use_unified_formula <= 0
    AND prbb.enable_testing = 0
    THEN 'old compositional'
    WHEN plc.calculation_method LIKE '%compositional%'
    AND prbb.nielsen_use_unified_formula <= 0
    AND prbb.enable_testing = 1
    THEN 'ott compositional'
    WHEN plc.calculation_method = 'direct' AND prbb.nielsen_use_unified_formula = 1
    THEN 'new direct'
    WHEN plc.calculation_method LIKE '%compositional%'
    AND prbb.nielsen_use_unified_formula = 1
    THEN 'new compositional'
    ELSE 'na'
  END AS rbp_formula,
  COALESCE(plc.calculation_method, 'na') AS rbp_placement_mode,
  is_filtered,
  is_mrc_ivt,
  is_non_mrc_compliant,
  server_group,
  service_type,
  ad_unit_type,
  ack_ad_impression_rbp_with_beacon,
  ack_ad_impression_rbp
FROM (
  SELECT
    DATE_TRUNC('HOUR', ack__timestamp) AS timestamp,
    CAST(TO_UNIXTIME(
      DATE_TRUNC('HOUR', UTC_TO_NETWORKLOCAL(ack__timestamp, advertisement__ad_oo_network_id))
    ) AS BIGINT) * 1000 AS network_local_time,
    request__context__video_cro_network_id AS video_cro_network_id,
    request__context__network_id AS distributor_network_id,
    advertisement__ad_oo_network_id AS ad_oo_network_id,
    request__context__profile_id,
    advertisement__placement_id,
    COALESCE(request__context__rbp_platform, 'na') AS rbp_platform,
    COALESCE(visitor__platform_group, 'na') AS platform_group,
    CASE
      WHEN request__context__rbp_platform = 'desktop'
      THEN 'pc'
      WHEN request__context__rbp_platform = 'mobile_web'
      OR request__context__rbp_platform = 'mobile_app'
      THEN 'mob'
      WHEN request__context__rbp_platform = 'ott'
      THEN 'ott'
      WHEN request__context__rbp_platform = 'vod'
      THEN 'stb vod'
      ELSE 'na'
    END AS rpt_rbp_platform,
    COALESCE(visitor__user_agent_device_type, 'na') AS platform,
    CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
    CASE
      WHEN COALESCE(visitor__filtration_reason, 0) = 1001
      THEN 'true'
      ELSE 'false'
    END AS is_mrc_ivt,
    IF(CONTAINS(request__mrc_compliance_label, 'not_explicit_rendered'), 'true', 'false') AS is_non_mrc_compliant,
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
        AND BITWISE_AND(request__extra_flags, 16384) = 0
      )
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
    COALESCE(
      SUM(
        IF(BITWISE_AND(advertisement__flags, 1073741824) > 0, ack__metrics__ad_impression, 0)
      ),
      0
    ) AS ack_ad_impression_rbp_with_beacon,
    COALESCE(
      SUM(
        IF(BITWISE_AND(advertisement__flags, 16777216) > 0, ack__metrics__ad_impression, 0)
      ),
      0
    ) AS ack_ad_impression_rbp
  FROM ${bcv_ack}
  WHERE
    BITWISE_AND(advertisement__flags, 16777216) > 0
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
    17
) AS tmp
LEFT JOIN db.default.d_network AS nw
  ON video_cro_network_id = nw.id
LEFT JOIN db.default.d_network AS dnw
  ON distributor_network_id = dnw.id
LEFT JOIN db.default.d_network AS anw
  ON ad_oo_network_id = anw.id
LEFT JOIN db.default.d_ad_environment_compound_profile AS pf
  ON pf.id = request__context__profile_id
INNER JOIN db.default.d_placement_rating_based_buying AS prbb
  ON tmp.advertisement__placement_id = prbb.placement_id
  AND NOT prbb.data_source IS NULL
LEFT JOIN db.default.d_placement AS plc
  ON tmp.advertisement__placement_id = plc.id
