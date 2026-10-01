-- account:    sa-presto-tier2
-- skeleton:   5107fc6a1cb4b542c4c95c4880ea32d7
-- pattern:    7d8da7faba7032b060d92bef7c5000aa  (1 execution(s))
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
  COUNT(DISTINCT candidate__creative_id) AS creative_count
FROM ${bcv_candidate}
WHERE
  candidate__internal_deal_id = 567170
GROUP BY
  candidate__error
