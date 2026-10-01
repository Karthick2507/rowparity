-- account:    sa-presto-tier2
-- skeleton:   33155ae063183203d0d53adbe21f624e
-- pattern:    6e30ee9966dd4c857cb52e66e404d021  (1 execution(s))
-- in suite:   column coverage
-- hoover:     request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  COUNT(1) AS req_count,
  MIN(request__timestamp) AS earliest_req,
  MAX(request__timestamp) AS latest_req
FROM ${bcv_request} AS r
WHERE
  request__context__network_id = 372496
  AND request__context__site_section_id = 23720059
