-- account:    sa-presto-tier2
-- skeleton:   c4cf69e15dbf0d02c47c430aafdbdb78
-- pattern:    6652f0246c8f5283ad70be2c2a221204  (1 execution(s))
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
  DATE_FORMAT(request__timestamp, '%y-%m-%d') AS event_day,
  candidate__integration_type,
  COUNT(*) AS total_candidates,
  COUNT(DISTINCT candidate__internal_deal_id) AS distinct_deals,
  COUNT_IF(candidate__error IS NULL OR candidate__error = '') AS won_candidates,
  ROUND(
    100.0 * COUNT_IF(candidate__error IS NULL OR candidate__error = '') / NULLIF(COUNT(*), 0),
    1
  ) AS win_rate_pct
FROM ${bcv_candidate}
WHERE
  request__context__network_id = 393759
  AND candidate__integration_type IN ('openrtb_pg_td', 'openrtb_normal')
GROUP BY
  1,
  2
ORDER BY
  1,
  2
