-- account:    sa-dataapp-yield
-- skeleton:   f57b585bf5ffcbbb11dedfa07b704fd0
-- pattern:    d104a315981320f95fa43d76b4ec910b  (610 execution(s))
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
  COALESCE(request__context__site_section_cro_asset_id, -1) AS distributor_site_section_id,
  COALESCE(ss.name, 'na') AS distributor_site_section_name,
  COALESCE(request__server_group, 'na') AS server_group,
  COALESCE(visitor__user_agent_device_type, 'na') AS platform,
  CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
  CASE
    WHEN visitor__caller = 'resp-format:scte-130 custom-template:scte-p1'
    THEN 'comcast-ws2'
    WHEN visitor__caller = 'resp-format:scte-130 custom-template:comcast'
    THEN 'comcast-ws1'
    WHEN visitor__caller = 'resp-format:scte-130 custom-template:all-ip-vod'
    THEN 'comcast-ws3'
    WHEN visitor__caller = 'resp-format:vmap1 custom-template:sky'
    THEN 'sky'
    ELSE 'others'
  END AS work_stream,
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
  COALESCE(SPLIT_PART(request__context__custom_asset_id, '/', 2), 'na') AS provider_name,
  SUM(ack__metrics__slot_impression) AS slot_impression,
  SUM(COALESCE(avails, 0) * COALESCE(ack__metrics__avails_event_count, 0)) AS slot_avails,
  SUM(COALESCE(unfilled_avails, 0) * COALESCE(ack__metrics__avails_event_count, 0)) AS slot_unfilled_avails
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__role, partners__avails_category__avails_in_played_slot, partners__avails_category__unfilled_avails_in_played_slot) AS network(role, avails, unfilled_avails)
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_site_section AS ss
  ON ss.id = request__context__site_section_cro_asset_id
WHERE
  (
    (
      (
        (
          (
            (
              request__context__response_format = 18
              OR request__context__request_format = 3
              OR visitor__caller = 'resp-format:scte-130 custom-template:viper-csai-vod'
            )
            AND BITWISE_AND(request__extra_flags, 1024) = 0
          )
          AND BITWISE_AND(slot__flags, 64) = 0
        )
        AND role = 'cro'
      )
      AND ack__ack_entity_type = 'slot'
    )
    AND COALESCE(ack__metrics__slot_impression, 0) > 0
  )
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
  15
