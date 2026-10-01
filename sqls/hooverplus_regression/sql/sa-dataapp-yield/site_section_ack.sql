-- account:    sa-dataapp-yield
-- skeleton:   f9d881c968e451de76dc8a6ec0e9bc20
-- pattern:    39f81b94b976d1f7568afd570ed3a978  (697 execution(s))
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
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(request__context__video_cro_context_id, -1) AS video_cro_site_section_id,
  COALESCE(request__context__video_cro_site_id, -1) AS video_cro_site_id,
  COALESCE(request__context__site_section_cro_asset_id, -1) AS distributor_site_section_id,
  COALESCE(request__context__site_section_cro_site_id, -1) AS distributor_site_id,
  CASE WHEN request__is_filtered THEN 'true' ELSE 'false' END AS is_filtered,
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
    WHEN candidate__integration_type = 'openrtb_pg_td'
    THEN 'fullstack_pg'
    WHEN candidate__integration_type = 'openrtb_normal'
    THEN 'fullstack_non_pg'
    WHEN candidate__integration_type = 'openrtb_sfx'
    THEN 'sfx_openrtb'
    WHEN candidate__integration_type = 'reseller_tag'
    AND advertisement__external_reseller__network_id = 127719
    THEN 'sfx_tag'
    WHEN candidate__integration_type = 'reseller_tag'
    THEN 'ssp_others'
    WHEN candidate__integration_type = 'mkpl_partner_tag'
    THEN 'mkpl_partner_tag'
    WHEN NOT advertisement__external_reseller__network_id IS NULL
    THEN 'reseller_tag'
    ELSE 'na'
  END AS market_integration_type,
  IF(BITWISE_AND(request__extra_flags, 16777216) > 0, 'true', 'false') AS is_mkpl,
  COALESCE(advertisement__ad_oo_network_id, -1) AS ad_network_id,
  COALESCE(ad_nw.name, 'na') AS ad_network_name,
  SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS ack_ad_impression,
  SUM(COALESCE(ack__metrics__click, 0)) AS ack_ad_click,
  SUM(COALESCE(ack__metrics__video_view, 0)) AS ack_video_view,
  SUM(COALESCE(ack__metrics__slot_impression, 0)) AS ack_slot_impression
FROM ${bcv_ack} AS a
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_network AS ad_nw
  ON ad_nw.id = advertisement__ad_oo_network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  (
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
  19,
  20
