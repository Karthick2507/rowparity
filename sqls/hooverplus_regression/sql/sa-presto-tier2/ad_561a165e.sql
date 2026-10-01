-- account:    sa-presto-tier2
-- skeleton:   34a241ecae036d15bccce456f3458333
-- pattern:    561a165ea929c76f87aef8b660e5c290  (2 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request_event_date = ?

SELECT
  request__transaction_id,
  COUNT(*) AS record_count,
  MIN(request__timestamp) AS first_seen,
  MAX(request__timestamp) AS last_seen,
  COUNT(DISTINCT request__timestamp) AS distinct_timestamps,
  COUNT(DISTINCT advertisement__ad_id) AS distinct_ad_ids
FROM ${bcv_ad}
WHERE
  candidate__network_id = 500763
  AND request__transaction_id = '1781802475392189716-w91fb'
GROUP BY
  request__transaction_id
HAVING
  COUNT(*) > 1
