-- account:    sa-presto-tier2
-- skeleton:   1cbf3cf75443b235c94f0b7786135d83
-- pattern:    3e030a3a75e91ec73785a9d4e8772ff6  (1 execution(s))
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
  DATE_FORMAT(request__timestamp, '%y-%m-%d') AS day,
  candidate__order_id,
  candidate__error,
  candidate__integration_type,
  COUNT(*) AS candidate_count,
  SUM(IF(candidate__error IS NULL, 1, 0)) AS no_error,
  SUM(IF(candidate__error = 'profile_check_failed', 1, 0)) AS profile_check_failed,
  SUM(IF(candidate__error = 'external_creative_profile_check_failed', 1, 0)) AS ext_creative_profile_failed,
  SUM(IF(candidate__error = 'no_valid_creative', 1, 0)) AS no_valid_creative,
  SUM(IF(candidate__error = 'floor_price_notmet', 1, 0)) AS floor_price_notmet,
  SUM(IF(candidate__error = 'empty_response', 1, 0)) AS empty_response
FROM ${bcv_candidate}
WHERE
  candidate__order_id = 469265
GROUP BY
  1,
  2,
  3,
  4
