-- account:    sa-presto-tier2
-- skeleton:   625a269270d9be3daf09d6b735112e53
-- pattern:    5923b7800c1e48aedf815384053c23cb  (1 execution(s))
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
  candidate__integration_type,
  COUNT(*) AS candidate_rows
FROM ${bcv_candidate}
WHERE
  request__context__network_id = 393759
GROUP BY
  1
ORDER BY
  2 DESC
