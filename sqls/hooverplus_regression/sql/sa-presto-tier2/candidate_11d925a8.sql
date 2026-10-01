-- account:    sa-presto-tier2
-- skeleton:   2ec219d300d163bd4e0e5327405ade92
-- pattern:    11d925a81fa5b9fd221492b49ac98543  (1 execution(s))
-- in suite:   column coverage
-- hoover:     candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE(request__timestamp) AS request_date,
  COUNT(DISTINCT candidate__order_id) AS unique_orders,
  COUNT(*) AS total_candidates,
  SUM(CASE WHEN candidate__error = 'exclusivity_by_slot' THEN 1 ELSE 0 END) AS exclusivity_by_slot_errors,
  SUM(CASE WHEN candidate__error = 'exclusivity_by_stream' THEN 1 ELSE 0 END) AS exclusivity_by_stream_errors,
  SUM(CASE WHEN NOT candidate__error IS NULL THEN 1 ELSE 0 END) AS total_errors,
  ROUND(
    100.0 * SUM(CASE WHEN candidate__error = 'exclusivity_by_slot' THEN 1 ELSE 0 END) / COUNT(*),
    2
  ) AS exclusivity_by_slot_pct
FROM ${bcv_candidate}
WHERE
  candidate__order_id = 632772
GROUP BY
  DATE(request__timestamp)
ORDER BY
  request_date
