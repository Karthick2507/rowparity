-- account:    sa-presto-tier2
-- skeleton:   eafffbcd534ac67c1980af2777854954
-- pattern:    35205b83ec6c77185590ea6c080bbb87  (2 execution(s))
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
  event_name,
  givt_decision_result,
  COUNT(*) AS cnt
FROM ${bcv_ack}
WHERE
  candidate__order_id IN (465918, 682198, 547658, 363855, 278643)
GROUP BY
  event_name,
  givt_decision_result
