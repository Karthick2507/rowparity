-- account:    sa-presto-tier2
-- skeleton:   a40d8bcd40e4a93387d5a2e790e910c1
-- pattern:    c7f799ac74c6b50975eb037397c67443  (1 execution(s))
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
  DATE_TRUNC('DAY', request__timestamp) AS day,
  candidate__internal_deal_id AS deal_id,
  COUNT(*) AS candidate_count,
  COUNT(DISTINCT candidate__error) AS distinct_errors,
  SUM(IF(candidate__error IS NULL OR candidate__error = '', 1, 0)) AS successful_candidates,
  SUM(IF(NOT candidate__error IS NULL AND candidate__error <> '', 1, 0)) AS errored_candidates
FROM ${bcv_candidate}
WHERE
  request__context__video_cro_network_id = 530362
  AND candidate__internal_deal_id IN (250645, 250652)
GROUP BY
  1,
  2
