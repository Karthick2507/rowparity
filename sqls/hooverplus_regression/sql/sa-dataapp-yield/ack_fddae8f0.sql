-- account:    sa-dataapp-yield
-- skeleton:   24e8eb77f07ca39c1219cd2e2ac2e9fa
-- pattern:    fddae8f0fc0f41755aff5bbaa145d4dc  (2 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP) + INTERVAL ? HOUR
--   ack__timestamp >= CAST(? AS TIMESTAMP) - INTERVAL ? HOUR

SELECT
  DATE_TRUNC(
    'DAY',
    UTC_TIMESTAMP_TO_LOCAL(ack__timestamp, TIMEZONE_OF_NETWORK(request__context__video_cro_network_id))
  ) AS eventdate,
  request__context__video_cro_network_id AS network_id,
  COALESCE(d_network.name, 'unknown') AS network,
  CASE
    WHEN request__delivery_method = 'casucpsu'
    THEN 'charter log translator'
    WHEN request__delivery_method = 'gateway'
    THEN 'ax log translator'
    WHEN BITWISE_AND(request__extra_flags, 128) > 0
    THEN 'charter ngi'
    WHEN (
      BITWISE_AND(request__extra_flags, 1024) > 0
      AND request__delivery_method IS NULL
      AND NOT advertisement__extra_flags IS NULL
    )
    THEN 'comcast linear'
  END AS delivery_method,
  IF(NOT nf.function_id IS NULL, 'true', 'false') AS is_report,
  COALESCE(SUM(ack__metrics__ad_impression), 0) AS impressions
FROM ${bcv_ack} AS ack
JOIN db.default.d_network AS d_network
  ON request__context__video_cro_network_id = d_network.id
LEFT JOIN db.default.d_network_function AS nf
  ON nf.network_id = request__context__video_cro_network_id AND nf.function_id = 1021
WHERE
  (
    (
      (
        request__delivery_method = 'casucpsu'
        OR request__delivery_method = 'gateway'
        OR BITWISE_AND(request__extra_flags, 128) > 0
        OR (
          BITWISE_AND(request__extra_flags, 1024) > 0
          AND request__delivery_method IS NULL
          AND NOT advertisement__extra_flags IS NULL
        )
      )
      AND UTC_TIMESTAMP_TO_LOCAL(ack__timestamp, TIMEZONE_OF_NETWORK(request__context__video_cro_network_id)) >= CAST('2026-07-23 00:00:00' AS TIMESTAMP)
    )
    AND UTC_TIMESTAMP_TO_LOCAL(ack__timestamp, TIMEZONE_OF_NETWORK(request__context__video_cro_network_id)) < CAST('2026-07-24 00:00:00' AS TIMESTAMP)
  )
  AND ack__ack_entity_type = 'ad'
GROUP BY
  1,
  2,
  3,
  4,
  5
