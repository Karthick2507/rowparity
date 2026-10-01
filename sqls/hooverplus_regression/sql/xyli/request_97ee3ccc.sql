-- account:    xyli
-- skeleton:   b100f71f7bbf3bb6feecc28e9bf89f52
-- pattern:    97ee3ccc1a179c2fd3cbb1e14918accc  (2768 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  COUNT(1) AS ivt_count
FROM ${bcv_request}
WHERE
  request__traffic_type = 2
