-- account:    sa-presto-tier2
-- skeleton:   c214cce6f36ef0687297bc8a7be30243
-- pattern:    1cedcc9dba1aacc5d7505c24be147259  (1 execution(s))
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
  candidate__error,
  COUNT(*) AS error_count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS error_pct
FROM ${bcv_candidate}
WHERE
  candidate__order_id = 632772
GROUP BY
  candidate__error
