-- account:    sa-presto-tier2
-- skeleton:   dbca9e76421c53057ecdb65fac168452
-- pattern:    5856785ce516cd48f87171ef3af9941a  (2 execution(s))
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
  candidate__filter_reason__error AS filter_reason_error,
  candidate__filter_reason__error_category AS filter_reason_category,
  COUNT(*) AS cnt
FROM ${bcv_candidate}
CROSS JOIN UNNEST(candidate__filter_reason__error, candidate__filter_reason__error_category) AS t(candidate__filter_reason__error, candidate__filter_reason__error_category)
WHERE
  request__context__network_id = 393759
  AND CARDINALITY(candidate__filter_reason__error) > 0
GROUP BY
  1,
  2
