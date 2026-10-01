-- account:    sa-presto-tier2
-- skeleton:   ccb90a9d47dfcc2b546fae81299b4895
-- pattern:    e536a56b85548db7ba36d4927f5f9004  (1 execution(s))
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
  candidate__dsp_crid AS dsp_crid,
  candidate__market_ad_id AS fw_market_ad_id,
  candidate__ad_id AS fw_ad_id,
  COUNT(*) AS failed_bids
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
