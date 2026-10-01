-- account:    sa-presto-tier2
-- skeleton:   7b4bc3ef70095c3566128af43f58f484
-- pattern:    e6b99db5732108101fe5994dda00e73c  (1 execution(s))
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
  candidate__internal_deal_id AS deal_id,
  COUNT(*) AS total_candidates,
  COUNT_IF(candidate__error IS NULL OR candidate__error = '') AS won,
  ROUND(
    100.0 * COUNT_IF(candidate__error IS NULL OR candidate__error = '') / NULLIF(COUNT(*), 0),
    1
  ) AS win_rate_pct,
  COUNT_IF(fr_error = 'exceed_max_num_advertisements') AS max_ads_exceeded_errors,
  ROUND(
    100.0 * COUNT_IF(fr_error = 'exceed_max_num_advertisements') / NULLIF(COUNT(*), 0),
    1
  ) AS max_ads_pct
FROM ${bcv_candidate}
LEFT JOIN UNNEST(candidate__filter_reason__error) AS t(fr_error)
  ON TRUE
WHERE
  request__context__network_id = 393759
  AND candidate__internal_deal_id IN (667139, 667140, 670539, 670542)
GROUP BY
  1,
  2
ORDER BY
  2,
  1
