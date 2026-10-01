-- account:    sa-dataapp-yield
-- skeleton:   bf9fdc35531986bcda77ac85759b3892
-- pattern:    17c4757c1eeeaaf6ec6c091281ecaeec  (1735 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)

WITH qps AS (
  SELECT
    ack__timestamp AS ack_time,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
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
    COALESCE(visitor__syscode, -1) AS syscode,
    SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS impression
  FROM ${bcv_ack}
  WHERE
    (
      (
        NOT advertisement__extra_flags IS NULL
        AND BITWISE_AND(advertisement__extra_flags, 3) = 1
      )
      AND request__context__video_cro_network_id = 384777
    )
    AND ack__ack_entity_type = 'ad'
  GROUP BY
    1,
    2,
    3,
    4
)
SELECT
  DATE_TRUNC('HOUR', ack_time) AS timestamp,
  video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  service_type,
  syscode,
  COALESCE(luz.name, 'unknown syscode') AS syscode_name,
  MAX(impression) AS max_qps
FROM qps
LEFT JOIN db.default.d_network AS nw
  ON nw.id = video_cro_network_id
LEFT JOIN db.default.d_lu_operator_zone AS luz
  ON luz.external_id = syscode
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6
