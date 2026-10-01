-- account:    xyli
-- skeleton:   b100f71f7bbf3bb6feecc28e9bf89f52
-- pattern:    7f82fe5194e8cd27eac415c04862add1  (2768 execution(s))
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
  request__traffic_type = 1
