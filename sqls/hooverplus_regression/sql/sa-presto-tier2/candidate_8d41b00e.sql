-- account:    sa-presto-tier2
-- skeleton:   7d1901dc8c0655888f8797fd00cc28c4
-- pattern:    8d41b00ec77c754a9b099952063209ed  (1 execution(s))
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
  candidate__ad_id AS dsp_ad_id,
  candidate__creative_id AS dsp_creative_id,
  candidate__error,
  COUNT(*) AS candidate_count
FROM ${bcv_candidate}
WHERE
  (
    request__context__video_cro_network_id = 525804
    AND candidate__internal_deal_id = 654433
  )
  AND candidate__error = 'mismatched_creative_duration_with_scheduled'
GROUP BY
  1,
  2,
  3
