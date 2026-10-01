-- account:    sa-presto-af-etl
-- skeleton:   61291abf85e492f312f11440e29a2d45
-- pattern:    fe17a5738c998cfd7452dfc9ca7e6e63  (699 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_TRUNC('HOUR', ack__timestamp) AS batch_start_time,
  advertisement__placement_id AS placement_id,
  CASE
    WHEN CARDINALITY(visitor__standard_device_type_ids) > 0
    THEN visitor__standard_device_type_ids[1]
    ELSE -1
  END AS device_type,
  request__context__profile_id AS profile_id,
  8 AS standard_ad_unit,
  request__bid_request__app_bundle AS app_bundle,
  SUM(
    CASE
      WHEN DATE_DIFF('SECOND', request__timestamp, ack__timestamp) < 30
      THEN ack__metrics__raw_ad_impression
      ELSE 0
    END
  ) AS lt30s_impressions,
  SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS total_impressions
FROM ${bcv_ack}
WHERE
  ack__event_name = 'defaultimpression'
  AND BITWISE_AND(request__extra_flags2, 8) > 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6
ORDER BY
  1
