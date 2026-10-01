-- account:    sa-presto-tier2
-- skeleton:   6ba9da912d7401a2fb09d9085d23162f
-- pattern:    a3b53311a45a7f9cb630bf25a9b582bb  (1 execution(s))
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
  CASE
    WHEN auction__impression__max_duration[1] = 30
    THEN 'imp_max=30 (no discrepancy)'
    WHEN auction__impression__max_duration[1] > 30
    THEN 'imp_max>30 (discrepancy: deal=30, imp=' || CAST(auction__impression__max_duration[1] AS VARCHAR) || ')'
    ELSE 'imp_max<30'
  END AS discrepancy_bucket,
  COUNT(1) AS total_candidates,
  ROUND(100.0 * COUNT(1) / SUM(COUNT(1)) OVER (), 2) AS pct_of_total,
  COUNT_IF(candidate__error = 'auction_max_ad_duration_exceeded') AS exceeded,
  ROUND(
    100.0 * COUNT_IF(candidate__error = 'auction_max_ad_duration_exceeded') / COUNT(1),
    2
  ) AS pct_exceeded_within_bucket
FROM ${bcv_candidate}
WHERE
  (
    candidate__dsp_id = 22
    AND candidate__internal_deal_id IN (531921, 637165, 550717, 550712)
  )
  AND request__context__video_cro_network_id = 384777
GROUP BY
  1
ORDER BY
  total_candidates DESC
