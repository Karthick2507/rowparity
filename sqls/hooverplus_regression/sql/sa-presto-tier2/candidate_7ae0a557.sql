-- account:    sa-presto-tier2
-- skeleton:   fd972bf19cde9685dbb713150177a64e
-- pattern:    7ae0a55727780a9410e0e8729f0bb91c  (1 execution(s))
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
  candidate__integration_type,
  COUNT(*) AS candidate_count,
  COUNT(DISTINCT candidate__dsp_id) AS dsp_count,
  APPROX_PERCENTILE(candidate__price, 0.5) AS median_bid_price,
  APPROX_PERCENTILE(candidate__price, 0.95) AS p95_bid_price
FROM ${bcv_candidate}
WHERE
  request__context__video_cro_network_id = 525804
  AND candidate__internal_deal_id = 654433
GROUP BY
  1,
  2
