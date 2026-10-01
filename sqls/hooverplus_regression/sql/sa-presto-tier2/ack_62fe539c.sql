-- account:    sa-presto-tier2
-- skeleton:   43150d7b1b90575a78d4b6da386dc850
-- pattern:    62fe539c288492a7c8b71fbef8f47fcb  (1 execution(s))
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
  partners__sales_channel AS sales_channel_code,
  COUNT(*) AS row_count,
  SUM(ack__metrics__ad_impression) AS impressions
FROM ${bcv_ack}
WHERE
  request__context__network_id = 393759
GROUP BY
  1
ORDER BY
  3 DESC
