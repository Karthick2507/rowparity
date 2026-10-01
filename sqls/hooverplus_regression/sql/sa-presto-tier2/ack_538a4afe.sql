-- account:    sa-presto-tier2
-- skeleton:   411fa5e9413b80e585fb0c4aa63d0078
-- pattern:    538a4afe85d7a9ab477f82f1fe1daf81  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id < ?
--   process_batch_id >= ?

SELECT
  ack__event_name,
  ack__is_slot_impression,
  COUNT(*) AS cnt
FROM ${bcv_ack}
WHERE
  candidate__order_id IN (465918, 682198, 547658, 363855, 278643)
  AND ack__is_slot_impression = TRUE
GROUP BY
  1,
  2
