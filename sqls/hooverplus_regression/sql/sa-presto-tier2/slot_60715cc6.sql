-- account:    sa-presto-tier2
-- skeleton:   a44dab9f357977d47eef44bc4496bd53
-- pattern:    60715cc61534ed3deb8d447dfe1956d8  (1 execution(s))
-- in suite:   column coverage
-- hoover:     slot
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request_event_date >= DATE_ADD(?, -?, CURRENT_DATE)

SELECT
  request_event_date AS day,
  COUNT(*) AS total_requests,
  SUM(CASE WHEN NOT slot__error_code IS NULL THEN 1 ELSE 0 END) AS error_requests
FROM ${bcv_slot}
WHERE
  network_id = 530362
GROUP BY
  1
