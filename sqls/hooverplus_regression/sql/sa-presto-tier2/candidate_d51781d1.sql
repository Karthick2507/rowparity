-- account:    sa-presto-tier2
-- skeleton:   2401996e50bc8689e61fb2bc32c49470
-- pattern:    d51781d12ff77bb642a7e74ceee0fc92  (1 execution(s))
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
  COUNT(*) AS total_pg_td_candidates,
  COUNT(DISTINCT candidate__internal_deal_id) AS distinct_deals_competing,
  COUNT_IF(candidate__error IS NULL OR candidate__error = '') AS won,
  ROUND(
    100.0 * COUNT_IF(candidate__error IS NULL OR candidate__error = '') / NULLIF(COUNT(*), 0),
    1
  ) AS win_rate_pct
FROM ${bcv_candidate}
WHERE
  request__context__network_id = 393759
  AND candidate__integration_type = 'openrtb_pg_td'
GROUP BY
  1
ORDER BY
  1
