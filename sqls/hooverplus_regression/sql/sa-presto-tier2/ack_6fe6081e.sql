-- account:    sa-presto-tier2
-- skeleton:   b69f3be6eac333a6f489b9381d5d974d
-- pattern:    6fe6081e732a2d04397d89c97b0f376d  (2 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__transaction_id,
  SUBSTR(CAST(process_batch_id AS VARCHAR), 1, 10) AS batch_hour,
  COUNT(*) AS ack_count
FROM ${bcv_ack}
WHERE
  request__transaction_id = '1781802475392189716'
GROUP BY
  1,
  2
