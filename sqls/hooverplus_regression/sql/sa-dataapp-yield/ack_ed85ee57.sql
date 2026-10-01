-- account:    sa-dataapp-yield
-- skeleton:   ed85ee57a577bdd2399a52e9adfb040e
-- pattern:    ed85ee57a577bdd2399a52e9adfb040e  (2108 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  MAX(ack__timestamp) AS max_time,
  MIN(ack__timestamp) AS min_time
FROM ${bcv_ack}
