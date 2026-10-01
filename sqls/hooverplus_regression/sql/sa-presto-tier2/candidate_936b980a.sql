-- account:    sa-presto-tier2
-- skeleton:   051e65f0d17abd76cc210908734a88db
-- pattern:    936b980a0ad4062608b73d1f422e239f  (2 execution(s))
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
  candidate__internal_deal_id AS deal_id,
  COUNT(*) AS total_candidates,
  COUNT_IF(candidate__error IS NULL OR candidate__error = '') AS won,
  COUNT_IF(fr_error = 'exceed_max_num_advertisements') AS max_ads_exceeded
FROM ${bcv_candidate}
LEFT JOIN UNNEST(candidate__filter_reason__error) AS t(fr_error)
  ON TRUE
WHERE
  request__context__network_id = 393759
  AND candidate__integration_type = 'openrtb_pg_td'
GROUP BY
  1
