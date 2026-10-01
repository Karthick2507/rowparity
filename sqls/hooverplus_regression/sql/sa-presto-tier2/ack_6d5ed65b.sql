-- account:    sa-presto-tier2
-- skeleton:   078fd85255a1aab41a678772b8c64fe9
-- pattern:    6d5ed65bdcceb6b1e0cc92b0590cce4b  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__transaction_id,
  COUNT(*) AS ack_row_count
FROM ${bcv_ack}
WHERE
  request__transaction_id = '1781802475392189716'
GROUP BY
  1
HAVING
  COUNT(*) > 1
