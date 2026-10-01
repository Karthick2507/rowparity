-- account:    sa-presto-tier2
-- skeleton:   8596fdbe568e430aef1cca71319bff98
-- pattern:    4bdf0b1099616d6b67fb56fe38d0b13e  (1 execution(s))
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
  COUNT(*) AS candidate_count,
  SUM(IF(candidate__error IS NULL OR candidate__error = '', 1, 0)) AS successful_candidates,
  SUM(IF(NOT candidate__error IS NULL AND candidate__error <> '', 1, 0)) AS errored_candidates,
  APPROX_DISTINCT(candidate__external_network_id) AS distinct_seller_networks
FROM ${bcv_candidate}
WHERE
  request__context__video_cro_network_id = 530362
  AND candidate__internal_deal_id IN (250645, 250652)
GROUP BY
  1
