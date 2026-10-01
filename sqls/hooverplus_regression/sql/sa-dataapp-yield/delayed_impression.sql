-- account:    sa-dataapp-yield
-- skeleton:   dc84bc33868f8c2d7dc8e783b2915d3f
-- pattern:    7d1943d3d9f2d26d68399a22198010b7  (696 execution(s))
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
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(advertisement__placement_id, -1) AS placement_id,
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
  CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
  COALESCE(request__context__site_section_id, -1) AS distributor_site_section_id,
  COALESCE(section.name, 'na') AS distributor_site_section_name,
  COALESCE(visitor__country, 'unknown country') AS country,
  COALESCE(ctry.description, 'unknown country') AS country_name,
  COALESCE(slot__time_position_class, 'na') AS time_position_class,
  CASE
    WHEN (
      CARDINALITY(visitor__standard_device_type_ids) > 0
    )
    THEN ELEMENT_AT(visitor__standard_device_type_ids, 1)
    ELSE -1
  END AS standard_device_type_id,
  device_type.name AS standard_device_type_name,
  visitor__platform_group AS platform_group,
  SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS ack_ad_impression,
  SUM(
    CASE
      WHEN DATE_DIFF('SECOND', request__timestamp, ack__timestamp) < 5
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt5s,
  SUM(
    CASE
      WHEN DATE_DIFF('SECOND', request__timestamp, ack__timestamp) < 10
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt10s,
  SUM(
    CASE
      WHEN DATE_DIFF('SECOND', request__timestamp, ack__timestamp) < 30
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt30s,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 3
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt3min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 6
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt6min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 9
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt9min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 12
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt12min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 15
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt15min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 18
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt18min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 21
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt21min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 24
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt24min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 27
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt27min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 30
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt30min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 33
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt33min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 36
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt36min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 39
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt39min,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) < 42
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt42min,
  SUM(
    CASE
      WHEN DATE_DIFF('HOUR', request__timestamp, ack__timestamp) < 1
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt1h,
  SUM(
    CASE
      WHEN DATE_DIFF('HOUR', request__timestamp, ack__timestamp) < 2
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt2h,
  SUM(
    CASE
      WHEN DATE_DIFF('HOUR', request__timestamp, ack__timestamp) < 3
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt3h,
  SUM(
    CASE
      WHEN DATE_DIFF('HOUR', request__timestamp, ack__timestamp) < 6
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt6h,
  SUM(
    CASE
      WHEN DATE_DIFF('HOUR', request__timestamp, ack__timestamp) < 9
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt9h,
  SUM(
    CASE
      WHEN DATE_DIFF('HOUR', request__timestamp, ack__timestamp) < 12
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt12h,
  SUM(
    CASE
      WHEN DATE_DIFF('HOUR', request__timestamp, ack__timestamp) < 18
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt18h,
  SUM(
    CASE
      WHEN DATE_DIFF('DAY', request__timestamp, ack__timestamp) < 1
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS lt1d,
  SUM(
    CASE
      WHEN DATE_DIFF('DAY', request__timestamp, ack__timestamp) >= 1
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS ge1d,
  SUM(
    CASE
      WHEN DATE_DIFF('MINUTE', request__timestamp, ack__timestamp) >= 42
      THEN COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS ge42min
FROM ${bcv_ack}
LEFT JOIN db.default.d_site_section AS section
  ON request__context__site_section_id = section.id
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = visitor__country_id
LEFT JOIN db.default.d_lu_mkpl_standard_device_type AS device_type
  ON device_type.id = IF(
    CARDINALITY(visitor__standard_device_type_ids) > 0,
    ELEMENT_AT(visitor__standard_device_type_ids, 1),
    -1
  )
WHERE
  (
    (
      request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
    )
    AND ack__event_name = 'defaultimpression'
  )
  AND slot__time_position_class IN ('preroll', 'midroll', 'postroll')
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
