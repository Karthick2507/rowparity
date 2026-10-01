-- account:    sa-presto-tier2
-- skeleton:   4a5126e6fb070d7a7949033c27ec85b7
-- pattern:    099fca2f1f479323b8f017afa017b81c  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_FORMAT(ack__timestamp, '%y-%m-%d') AS ack_day,
  COUNT(*) AS ack_events,
  SUM(ack__metrics__ad_impression) AS impressions
FROM ${bcv_ack}
WHERE
  advertisement__placement_id = 94330123
GROUP BY
  1
