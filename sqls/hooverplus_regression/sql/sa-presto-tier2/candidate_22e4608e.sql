-- account:    sa-presto-tier2
-- skeleton:   39f633c9ec2f686ef3c53031242fcfb9
-- pattern:    22e4608ea185d2825f6062792be818f8  (1 execution(s))
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
  auction__impression__max_duration[1] AS imp_max_duration,
  COUNT(1) AS total_bw_deal_candidates,
  COUNT_IF(candidate__error = 'auction_max_ad_duration_exceeded') AS max_duration_exceeded,
  ROUND(
    100.0 * COUNT_IF(candidate__error = 'auction_max_ad_duration_exceeded') / COUNT(1),
    2
  ) AS pct_exceeded,
  COUNT_IF(candidate__error IS NULL) AS successful_bids,
  ROUND(100.0 * COUNT_IF(candidate__error IS NULL) / COUNT(1), 2) AS pct_successful
FROM ${bcv_candidate}
WHERE
  (
    candidate__dsp_id = 22 AND NOT candidate__internal_deal_id IS NULL
  )
  AND request__context__video_cro_network_id = 384777
GROUP BY
  auction__impression__max_duration[1]
