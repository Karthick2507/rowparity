-- account:    sa-dataapp-yield
-- skeleton:   56fbf75a384450aa137c66fcfee8d0a4
-- pattern:    aad2981fd8d0b8e00a12475424d2a381  (698 execution(s))
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
  COALESCE(nw.name, 'unknown cro') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'unknown distributor') AS distributor_network_name,
  COALESCE(REGEXP_EXTRACT(visitor__referrer, '^https?://(www\.)?([^/?#]*).*', 2), 'n/a') AS domain_or_bundle,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'unknown profile') AS profile_name,
  COALESCE(visitor__platform_group, 'unknown platform') AS endpoint_platform_group,
  CASE WHEN BITWISE_AND(request__flags, 8) > 0 THEN 'live' ELSE 'on_demand' END AS content_format,
  CASE
    WHEN visitor__platform_group IN ('ott-roku', 'ctv-roku')
    THEN 'roku (native app)'
    WHEN visitor__platform_group IN ('ott-google chromecast', 'ctv-google chromecast')
    THEN 'html5 in chromecast'
    WHEN visitor__platform_group IN ('ott-microsoft xbox', 'ctv-microsoft xbox')
    OR (
      REGEXP_LIKE(visitor__user_agent, '(xbox)')
      AND (
        visitor__platform_group = 'mobile web'
        OR visitor__platform_group = 'mobile in-app'
      )
    )
    THEN 'xbox (native app)'
    WHEN visitor__platform_group IN ('ott-amazon fire tv', 'ctv-amazon fire tv')
    OR (
      REGEXP_LIKE(visitor__user_agent, '(fire os)')
      AND REGEXP_LIKE(visitor__user_agent, '(firetv|firetv|fire tv)')
    )
    THEN 'firetv (native app)'
    WHEN (
      REGEXP_LIKE(visitor__user_agent, '(iphone|ipad|ipad|iphone)')
      AND visitor__platform_group = 'mobile in-app'
    )
    OR REGEXP_LIKE(visitor__caller, 'iphone-[0-9]')
    THEN 'ios (native app)'
    WHEN REGEXP_LIKE(visitor__user_agent, '(mac os)')
    AND visitor__platform_group = 'desktop'
    THEN 'macos (native app)'
    WHEN visitor__platform_group IN ('ott-sony playstation', 'ctv-sony playstation')
    THEN 'play station (native app)'
    WHEN REGEXP_LIKE(visitor__user_agent, 'windows phone')
    AND visitor__platform_group = 'mobile in-app'
    THEN 'windows (native app)'
    WHEN (
      REGEXP_LIKE(visitor__user_agent, '(android)')
      AND visitor__platform_group = 'mobile in-app'
    )
    OR REGEXP_LIKE(visitor__caller, 'android-[0-9]')
    THEN 'android (native app)'
    WHEN REGEXP_LIKE(visitor__user_agent, '(apple tv|appletv)')
    AND visitor__platform_group = 'mobile in-app'
    OR visitor__platform_group IN ('ott-apple apple tv', 'ctv-apple apple tv')
    THEN 'tvos (native app)'
    WHEN visitor__platform_group = 'mobile web'
    THEN 'html5 in mobile browser'
    WHEN visitor__platform_group = 'desktop' OR REGEXP_LIKE(visitor__caller, 'js-[0-9]')
    THEN 'html5 in desktop browser'
    ELSE 'other (please specify)'
  END AS player_platform,
  CASE
    WHEN REGEXP_REPLACE(visitor__caller, '^((js|android|iphone|tvos|as3)-[0-9]).*', 'admanager') = 'admanager'
    THEN 'client side integration with admanager'
    WHEN request__context__response_format IN (9, 16)
    OR p.name LIKE '%ssai%'
    OR p.name LIKE '%hls%'
    OR p.name LIKE '%uplink%'
    OR p.name LIKE '%uplynk%'
    THEN 'ssai'
    WHEN request__context__response_format IN (2, 3, 5, 7, 8, 10, 12, 13)
    THEN 'direct xml'
    WHEN request__context__response_format = 1
    THEN 'type b / active tag'
    WHEN request__context__response_format = 18
    THEN 'scte-130'
    WHEN request__context__response_format IN (4, 6)
    THEN 'custom json'
    ELSE '9.others'
  END AS integration_type,
  CASE
    WHEN REGEXP_REPLACE(visitor__caller, '^((js|android|iphone|tvos|as3)-[0-9]).*', 'admanager') = 'admanager'
    THEN REGEXP_EXTRACT(visitor__caller, '^(js|android|iphone|tvos|as3)-[0-9.]+')
    ELSE 'n/a'
  END AS admanager_version,
  SUM(COALESCE(ack__metrics__ad_impression, 0)) AS ack_ad_impression,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_no_ad') AS ack_err_adm_e_no_ad,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_timeout') AS ack_err_adm_e_timeout,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_security') AS ack_err_adm_e_security,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_3p-comp') AS ack_err_adm_e_3p_comp,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_unknown') AS ack_err_adm_e_unknown,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_io') AS ack_err_adm_e_io,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_no-render') AS ack_err_adm_e_no_render,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_parse') AS ack_err_adm_e_parse,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_device-limit') AS ack_err_adm_e_device_limit,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_render-init') AS ack_err_adm_e_render_init,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '303') AS ack_err_vast_303,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '301') AS ack_err_vast_301,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '202') AS ack_err_vast_202,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '100') AS ack_err_vast_100,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '400') AS ack_err_vast_400,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '403') AS ack_err_vast_403,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '402') AS ack_err_vast_402,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '900') AS ack_err_vast_900,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '302') AS ack_err_vast_302,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '300') AS ack_err_vast_300
FROM ${bcv_ack} AS a
LEFT JOIN db.default.d_network AS nw
  ON nw.id = a.request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = a.request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON a.request__context__profile_id = p.id
WHERE
  (
    NOT request__context__profile_id IS NULL AND NOT visitor__platform_group IS NULL
  )
  AND NOT request__flags IS NULL
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
  13
