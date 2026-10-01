-- account:    ychan375
-- skeleton:   6c4f7ec316f9bbdf4148f58466221169
-- pattern:    81d1b5863ae338fff906ec0a28ac8816  (30 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP) - INTERVAL ? DAY
--   request__timestamp >= CAST(? AS TIMESTAMP) - INTERVAL ? DAY

SELECT
  DATE(request__timestamp) AS date_day,
  CASE
    WHEN visitor__platform_group IS NULL
    THEN 'unknown'
    ELSE visitor__platform_group
  END AS "platform",
  CASE
    WHEN (
      (
        MINUTE(ack__timestamp - request__timestamp) = 0
      )
      AND (
        HOUR(ack__timestamp - request__timestamp) < 1
      )
      AND (
        DAY(ack__timestamp - request__timestamp) < 1
      )
    )
    THEN SECOND(ack__timestamp - request__timestamp)
    WHEN (
      (
        MINUTE(ack__timestamp - request__timestamp) = 1
      )
      AND (
        HOUR(ack__timestamp - request__timestamp) < 1
      )
      AND (
        DAY(ack__timestamp - request__timestamp) < 1
      )
    )
    THEN SECOND(ack__timestamp - request__timestamp) + 60
    ELSE NULL
  END AS "latency_in_seconds",
  CASE
    WHEN (
      (
        MINUTE(ack__timestamp - request__timestamp) > 1
      )
      AND (
        HOUR(ack__timestamp - request__timestamp) < 1
      )
      AND (
        DAY(ack__timestamp - request__timestamp) < 1
      )
    )
    THEN MINUTE(ack__timestamp - request__timestamp)
    ELSE NULL
  END AS "latency_in_minutes",
  CASE
    WHEN (
      (
        HOUR(ack__timestamp - request__timestamp) >= 1
      )
      AND (
        DAY(ack__timestamp - request__timestamp) < 1
      )
    )
    THEN HOUR(ack__timestamp - request__timestamp)
    ELSE NULL
  END AS "latency_in_hours",
  CASE
    WHEN DAY(ack__timestamp - request__timestamp) >= 1
    THEN DAY(ack__timestamp - request__timestamp)
    ELSE NULL
  END AS "latency_in_days",
  SUM(ack__metrics__ad_impression) AS "impressions"
FROM ${bcv_ack}
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6
