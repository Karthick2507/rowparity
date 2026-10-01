-- account:    sa-presto-tier2
-- skeleton:   062ad464e4b07ba287e07e757f7a720e
-- pattern:    73fb839cc9952c20b2494f4370aa8d52  (1 execution(s))
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
  SUM(IF(candidate__error IS NULL, 1, 0)) AS won,
  SUM(IF(candidate__error = 'competition_failure', 1, 0)) AS competition_failure,
  SUM(IF(candidate__error = 'floor_price_notmet', 1, 0)) AS floor_not_met,
  SUM(IF(candidate__error = 'mkpl_order_floor_price_not_met', 1, 0)) AS mkpl_floor_not_met,
  SUM(
    IF(
      candidate__error IN ('no_bids', 'empty_response', 'wrapper_http_error', 'wrapper_timeout'),
      1,
      0
    )
  ) AS demand_side_errors,
  COUNT(*) AS total_candidates
FROM ${bcv_candidate}
WHERE
  request__context__video_cro_network_id = 376521
GROUP BY
  1
ORDER BY
  1
