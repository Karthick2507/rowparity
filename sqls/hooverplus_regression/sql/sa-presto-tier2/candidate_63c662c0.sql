-- account:    sa-presto-tier2
-- skeleton:   7adebe16c610d7d1f3e16d00140ae3dc
-- pattern:    63c662c03f48bf5017400250ac4d70e8  (1 execution(s))
-- in suite:   column coverage
-- hoover:     candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CURRENT_TIMESTAMP
--   request__timestamp >= CURRENT_TIMESTAMP - INTERVAL ? HOUR

SELECT
  DATE_TRUNC('MINUTE', request__timestamp) - INTERVAL '1' MINUTE * (
    MINUTE(request__timestamp) % 10
  ) AS time_bucket,
  COUNT(*) AS total_candidates,
  SUM(IF(candidate__error IS NULL, 1, 0)) AS won,
  ROUND(SUM(IF(candidate__error IS NULL, 1, 0)) * 100.0 / COUNT(*), 2) AS win_rate_pct,
  SUM(IF(candidate__error = 'competition_failure', 1, 0)) AS competition_failure,
  SUM(
    IF(
      candidate__error IN ('no_bids', 'empty_response', 'wrapper_http_error', 'wrapper_timeout'),
      1,
      0
    )
  ) AS demand_side_errors,
  SUM(
    IF(candidate__error IN ('floor_price_notmet', 'mkpl_order_floor_price_not_met'), 1, 0)
  ) AS floor_errors
FROM ${bcv_candidate}
WHERE
  request__context__video_cro_network_id = 376521
GROUP BY
  1
ORDER BY
  1
