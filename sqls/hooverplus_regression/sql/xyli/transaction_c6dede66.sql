-- account:    xyli
-- skeleton:   b1fe5071b5587b29bcea5a90131136dc
-- pattern:    c6dede6693221e1f6071097759cc158d  (2767 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  COUNT(1) AS mrc_count
FROM ${bcv_transaction}
WHERE
  request__is_first_request = TRUE
  AND BITWISE_AND(request__compliance_mark_flag, 8) > 0
