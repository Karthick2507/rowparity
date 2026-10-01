-- account:    sa-dataapp-yield
-- skeleton:   efedcd9ab6b43dc879909003b37ee7ef
-- pattern:    1e2d5adcb835a05d0b17089d6866d196  (698 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH extension_data AS (
  SELECT
    rp.profile_id,
    rp.value,
    rp.name AS parameter_name,
    CASE
      WHEN single_extension_value LIKE '%omsdkextension%'
      OR (
        NOT rp.name IS NULL AND rp.name LIKE '%omsdk%'
      )
      OR single_extension_value LIKE '%openmeasurementextension%'
      THEN 'omsdkextension'
      WHEN single_extension_value LIKE '%skippableadextension%'
      OR (
        NOT rp.name IS NULL AND rp.name LIKE '%skippable%'
      )
      THEN 'skippableadextension'
      WHEN single_extension_value LIKE '%videostateextension%'
      OR (
        NOT rp.name IS NULL AND rp.name LIKE '%videostate%'
      )
      THEN 'videostateextension'
      WHEN (
        NOT rp.name IS NULL AND rp.name LIKE '%countdown%'
      )
      THEN 'countdowntimerextension'
      WHEN (
        NOT rp.name IS NULL AND rp.name LIKE '%survey%'
      )
      THEN 'surveyextension'
      WHEN (
        NOT rp.name IS NULL AND rp.name LIKE '%countdown.enabled%'
      )
      THEN 'countdowntimerextension'
      WHEN rp.name = 'autoloadextensions'
      AND REGEXP_LIKE(single_extension_value, '([^\/"]+?)"\)}')
      THEN REGEXP_EXTRACT(single_extension_value, '([^\/"]+?)"\)}', 1)
      WHEN rp.name = 'autoloadextensions'
      AND REGEXP_LIKE(single_extension_value, '([^\/"\)}\]]+)"?$')
      THEN REGEXP_EXTRACT(single_extension_value, '([^\/"]+)"?$', 1)
      ELSE 'n/a'
    END AS extension
  FROM oltp.fwmrm_oltp.renderer_parameter AS rp
  CROSS JOIN UNNEST(SPLIT(rp.value, ',')) AS t(single_extension_value)
  GROUP BY
    1,
    2,
    3,
    4
), profile_data AS (
  SELECT
    p.id AS profile_id,
    p.name AS profile_name,
    FILTER(ARRAY_AGG(DISTINCT ed.extension), x -> NOT x IS NULL AND x <> 'n/a') AS admanager_extensions,
    FILTER(
      ARRAY_AGG(DISTINCT COALESCE(TRIM(r.name), 'n/a')),
      x -> NOT x IS NULL AND x <> 'n/a'
    ) AS admanager_renderers,
    (
      ARRAY_AGG(DISTINCT pa.child_profile_id)
    ) AS child_profile_ids,
    (
      ARRAY_AGG(DISTINCT ed.parameter_name)
    ) AS parameter_names
  FROM oltp.fwmrm_oltp.ad_environment_compound_profile AS p
  LEFT JOIN oltp.fwmrm_oltp.ad_environment_profile_assignment AS pa
    ON p.id = pa.parent_profile_id
  LEFT JOIN oltp.fwmrm_oltp.ad_environment_profile AS pn
    ON pa.child_profile_id = pn.id
  LEFT JOIN oltp.fwmrm_oltp.renderer AS r
    ON pn.renderer_id = r.id
  LEFT JOIN extension_data AS ed
    ON p.id = ed.profile_id
  GROUP BY
    1,
    2
)
SELECT
  DATE_TRUNC('HOUR', a.ack__timestamp) AS timestamp,
  COALESCE(a.request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'unknown cro') AS video_cro_network_name,
  COALESCE(a.request__context__network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'unknown distributor') AS distributor_network_name,
  COALESCE(a.request__context__profile_id, -1) AS profile_id,
  COALESCE(pd.profile_name, 'unknown profile') AS profile_name,
  (
    CASE
      WHEN (
        BITWISE_AND(a.request__flags, 8) > 0
      )
      THEN 'live'
      ELSE 'on_demand'
    END
  ) AS content_format,
  COALESCE(
    (
      REGEXP_LIKE(visitor__caller, '^((js|android|iphone|tvos|as3|linktag2)-(heads\/)?v?[0-9]).*')
    ),
    FALSE
  ) AS is_adm,
  (
    CASE
      WHEN (
        visitor__platform_group IN ('ott-comcast x1', 'ctv-comcast x1')
      )
      THEN 'ctv-comcast x1'
      WHEN (
        visitor__platform_group IN ('ott-mibox', 'ctv-mibox')
      )
      THEN 'ctv-mibox'
      WHEN (
        visitor__platform_group IN ('ott-super tv', 'ctv-super tv')
      )
      THEN 'ctv-super tv'
      WHEN (
        visitor__platform_group IN ('ott-roku', 'ctv-roku')
      )
      THEN 'roku(native app)'
      WHEN (
        visitor__platform_group IN ('ott-google chromecast', 'ctv-google chromecast')
      )
      THEN 'html5 in chromecast'
      WHEN (
        visitor__platform_group IN ('ott-microsoft xbox', 'ctv-microsoft xbox')
        OR (
          REGEXP_LIKE(visitor__user_agent, '(xbox)')
          AND (
            visitor__platform_group = 'mobile web'
            OR visitor__platform_group = 'mobile in-app'
          )
        )
      )
      THEN 'xbox(native app)'
      WHEN (
        REGEXP_LIKE(visitor__user_agent, 'tizen')
      )
      THEN 'ctv-samsung tizen'
      WHEN (
        visitor__platform_group IN ('ctv-samsung smart tv', 'ott-samsung smart tv')
      )
      THEN 'ctv-samsung smart tv'
      WHEN (
        REGEXP_LIKE(visitor__user_agent, 'titanos')
      )
      THEN 'ctv-philips titanos'
      WHEN visitor__platform_group IN ('ott-shield android tv', 'ctv-shield android tv')
      THEN 'ctv-shield android tv'
      WHEN (
        REGEXP_LIKE(visitor__user_agent, 'bravia')
      )
      THEN 'ctv-sony bravia'
      WHEN (
        REGEXP_LIKE(visitor__user_agent, 'web0s')
      )
      THEN 'ctv-lge webos'
      WHEN (
        visitor__platform_group IN ('ott-amazon fire tv', 'ctv-amazon fire tv')
        OR (
          REGEXP_LIKE(visitor__user_agent, '(fire os)')
          AND REGEXP_LIKE(visitor__user_agent, '(firetv|firetv|fire tv)')
        )
      )
      THEN 'firetv(native app)'
      WHEN (
        REGEXP_LIKE(visitor__user_agent, '(mac os)')
        AND visitor__platform_group = 'desktop'
      )
      THEN 'macos(native app)'
      WHEN (
        visitor__platform_group IN ('ott-sony playstation', 'ctv-sony playstation')
      )
      THEN 'play station(native app)'
      WHEN (
        REGEXP_LIKE(visitor__user_agent, 'windows phone')
        AND visitor__platform_group = 'mobile in-app'
      )
      THEN 'windows(native app)'
      WHEN (
        (
          REGEXP_LIKE(visitor__user_agent, '(android)')
          AND visitor__platform_group = 'mobile in-app'
        )
        OR REGEXP_LIKE(visitor__caller, 'android-[0-9]')
      )
      THEN 'android(native app)'
      WHEN (
        (
          REGEXP_LIKE(visitor__user_agent, '(iphone|ipad|ipad|iphone)')
          AND visitor__platform_group = 'mobile in-app'
        )
        OR REGEXP_LIKE(visitor__caller, 'iphone-[0-9]')
      )
      THEN 'ios(native app)'
      WHEN (
        (
          REGEXP_LIKE(visitor__user_agent, '(apple tv|appletv)')
          AND visitor__platform_group = 'mobile in-app'
        )
        OR visitor__platform_group IN ('ott-apple apple tv', 'ctv-apple apple tv')
      )
      THEN 'tvos(native app)'
      WHEN (
        visitor__platform_group = 'mobile web'
      )
      THEN 'html5 in mobile browser'
      WHEN (
        visitor__platform_group = 'desktop'
      )
      THEN 'html5 in desktop browser'
      WHEN visitor__platform_group IN ('ott-others', 'ctv-others')
      THEN 'ctv-others'
      ELSE visitor__platform_group
    END
  ) AS player_platform,
  CASE
    WHEN (
      REGEXP_REPLACE(
        visitor__caller,
        '^((js|android|iphone|tvos|as3|linktag2)-(heads\/)?v?[0-9]).*',
        'admanager'
      ) = 'admanager'
    )
    THEN 'client side integration with admanager'
    WHEN (
      a.request__context__response_format IN (9, 16)
      OR pd.profile_name LIKE '%ssai%'
      OR pd.profile_name LIKE '%hls%'
      OR pd.profile_name LIKE '%uplink%'
      OR pd.profile_name LIKE '%uplynk%'
    )
    THEN 'ssai'
    WHEN (
      a.request__context__response_format IN (2, 3, 5, 7, 8, 10, 12, 13)
    )
    THEN 'direct xml'
    WHEN (
      a.request__context__response_format = 1
    )
    THEN 'type b / active tag'
    WHEN (
      a.request__context__response_format = 18
    )
    THEN 'scte-130'
    WHEN (
      a.request__context__response_format IN (4, 6)
    )
    THEN 'custom json'
    ELSE '9.others'
  END AS integration_type,
  CASE
    WHEN REGEXP_LIKE(visitor__caller, '_vega')
    THEN 'vega'
    WHEN REGEXP_LIKE(visitor__caller, '-prebid')
    THEN 'prebid'
    WHEN REGEXP_LIKE(visitor__caller, '-hbbtv')
    THEN 'hbbtv'
    WHEN REGEXP_LIKE(visitor__caller, 'js-[0-9]')
    THEN 'html5'
    WHEN REGEXP_LIKE(visitor__caller, 'android-[0-9]')
    THEN 'android'
    WHEN REGEXP_LIKE(visitor__caller, 'iphone-(heads\/v)?[0-9]')
    THEN 'ios'
    WHEN REGEXP_LIKE(visitor__caller, 'tvos-[0-9]')
    THEN 'tvos'
    WHEN REGEXP_LIKE(visitor__caller, 'as3-[0-9]')
    THEN 'as3'
    WHEN REGEXP_LIKE(visitor__caller, 'linktag2-v?[0-9]')
    THEN 'linktag2'
    ELSE 'n/a'
  END AS admanager_product,
  (
    CASE
      WHEN (
        REGEXP_REPLACE(
          visitor__caller,
          '^((js|android|iphone|tvos|as3|linktag2)-(heads\/)?v?[0-9]).*',
          'admanager'
        ) = 'admanager'
      )
      THEN REGEXP_EXTRACT(
        visitor__caller,
        '^(js|android|iphone|tvos|as3|linktag2)-(heads\/)?v?[0-9.]+(_es6|-prebid|-hbbtv|_vega)?'
      )
      ELSE 'n/a'
    END
  ) AS admanager_version,
  COALESCE(a.visitor__country_id, -1) AS country_id,
  COALESCE(ct.description, 'unknown country') AS country_name,
  pd.admanager_renderers,
  pd.admanager_extensions,
  CASE
    WHEN REGEXP_LIKE(visitor__caller, 'android-[0-9]')
    THEN CASE
      WHEN (
        CAST(SPLIT_PART(REGEXP_EXTRACT(visitor__caller, '[0-9.]+'), '.', 1) AS INTEGER) > 7
        OR (
          CAST(SPLIT_PART(REGEXP_EXTRACT(visitor__caller, '[0-9.]+'), '.', 1) AS INTEGER) = 7
          AND CAST(SPLIT_PART(REGEXP_EXTRACT(visitor__caller, '[0-9.]+'), '.', 2) AS INTEGER) >= 8
        )
      )
      AND NOT CONTAINS(pd.child_profile_ids, 19446)
      AND NOT CONTAINS(pd.parameter_names, 'renderer.video.forcemediaplayer')
      THEN 'exoplayer'
      ELSE 'mediaplayer'
    END
    ELSE 'n/a'
  END AS android_player,
  SUM(COALESCE(ack__metrics__ad_impression, 0)) AS ack_ad_impression,
  COUNT_IF(ack__event_type = 'e' AND REGEXP_LIKE(ack__event_name, 'fwcrashreporter')) AS ack_err_e_ios_crash,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_no_ad') AS ack_err_e_no_ad,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_timeout') AS ack_err_e_timeout,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_security') AS ack_err_e_security,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_3p-comp') AS ack_err_e_3p_comp,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_unknown') AS ack_err_e_unknown,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_io') AS ack_err_e_io,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_no-render') AS ack_err_e_no_render,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_parse') AS ack_err_e_parse,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_device-limit') AS ack_err_e_device_limit,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_render-init') AS ack_err_e_render_init,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_renderer-load') AS ack_err_e_renderer_load,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_in-app-view') AS ack_err_e_in_app_view,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_invalid-slot') AS ack_err_e_invalid_slot,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_dashjs') AS ack_err_e_dashjs,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_null-asset') AS ack_err_e_null_asset,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_invalid-value') AS ack_err_e_invalid_value,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_invalid-asset') AS ack_err_e_invalid_asset,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '_e_no-renderer') AS ack_err_e_no_renderer,
  COUNT_IF(
    ack__event_type = 'e'
    AND REGEXP_LIKE(ack__event_name, 'timeout%20when%20playing')
  ) AS ack_err_e_timeout_playing,
  COUNT_IF(ack__event_type = 'e' AND REGEXP_LIKE(ack__event_name, 'mediaerror')) AS ack_err_e_media_error,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = 'resellernoad') AS ack_err_e_reseller_no_ad,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '100') AS ack_err_vast_100,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '101') AS ack_err_vast_101,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '102') AS ack_err_vast_102,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '200') AS ack_err_vast_200,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '201') AS ack_err_vast_201,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '202') AS ack_err_vast_202,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '203') AS ack_err_vast_203,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '204') AS ack_err_vast_204,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '205') AS ack_err_vast_205,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '206') AS ack_err_vast_206,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '300') AS ack_err_vast_300,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '301') AS ack_err_vast_301,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '302') AS ack_err_vast_302,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '303') AS ack_err_vast_303,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '304') AS ack_err_vast_304,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '400') AS ack_err_vast_400,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '401') AS ack_err_vast_401,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '402') AS ack_err_vast_402,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '403') AS ack_err_vast_403,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '405') AS ack_err_vast_405,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '406') AS ack_err_vast_406,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '407') AS ack_err_vast_407,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '408') AS ack_err_vast_408,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '409') AS ack_err_vast_409,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '410') AS ack_err_vast_410,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '500') AS ack_err_vast_500,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '501') AS ack_err_vast_501,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '502') AS ack_err_vast_502,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '503') AS ack_err_vast_503,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '900') AS ack_err_vast_900,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '901') AS ack_err_vast_901,
  COUNT_IF(ack__event_type = 'e' AND ack__event_name = '902') AS ack_err_vast_902
FROM ${bcv_ack} AS a
LEFT JOIN profile_data AS pd
  ON a.request__context__profile_id = pd.profile_id
LEFT JOIN db.default.d_network AS nw
  ON nw.id = a.request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = a.request__context__network_id
LEFT JOIN db.default.d_country AS ct
  ON ct.id = a.visitor__country_id
WHERE
  (
    NOT a.request__context__profile_id IS NULL
    AND NOT a.visitor__platform_group IS NULL
  )
  AND NOT a.request__flags IS NULL
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
  18
