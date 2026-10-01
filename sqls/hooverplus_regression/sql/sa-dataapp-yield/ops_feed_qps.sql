-- account:    sa-dataapp-yield
-- skeleton:   e21a4fb07ed9d57d4f26468eff646f33
-- pattern:    a19b84ad1859d5c6b391bcb5fb272a09  (1735 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_TRUNC('MINUTE', request_time) AS timestamp,
  video_cro_network_id,
  IF(video_cro_network_id = -2, 'all', COALESCE(nw.name, 'na')) AS video_cro_network_name,
  service_type,
  server_group,
  MAX(qps) AS max_qps
FROM (
  SELECT
    request_time,
    COALESCE(video_cro_network_id, -2) AS video_cro_network_id,
    COALESCE(service_type, 'all') AS service_type,
    COALESCE(server_group, 'all') AS server_group,
    SUM(request_number) AS qps
  FROM (
    SELECT
      request__timestamp AS request_time,
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
      COALESCE(request__server_group, 'na') AS server_group,
      SUM(COALESCE(request__log_sampling__magnifier, 1)) AS request_number
    FROM ${bcv_request}
    GROUP BY
      1,
      2,
      3,
      4
  ) AS a
  GROUP BY
    GROUPING SETS (
      (request_time, video_cro_network_id, service_type, server_group),
      (request_time, video_cro_network_id, service_type),
      (request_time, video_cro_network_id, server_group),
      (request_time, video_cro_network_id),
      (request_time, server_group),
      (
        request_time
      )
    )
) AS b
LEFT JOIN db.default.d_network AS nw
  ON nw.id = video_cro_network_id
GROUP BY
  1,
  2,
  3,
  4,
  5
