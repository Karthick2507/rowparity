-- account:    sa-presto-tier2
-- skeleton:   71cd90b05cdc274f7c5b0fdf0ef38b97
-- pattern:    7e26b785fc83cf902f01b0661efcc1b7  (2 execution(s))
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
  fr_error,
  fr_category,
  COUNT(*) AS cnt
FROM ${bcv_candidate}
CROSS JOIN UNNEST(candidate__filter_reason__error, candidate__filter_reason__error_category) AS t(fr_error, fr_category)
WHERE
  request__context__network_id = 393759
  AND CARDINALITY(candidate__filter_reason__error) > 0
GROUP BY
  1,
  2
