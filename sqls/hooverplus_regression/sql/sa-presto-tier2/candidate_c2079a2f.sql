-- account:    sa-presto-tier2
-- skeleton:   7c884326076ce050d356495f1bfc816e
-- pattern:    c2079a2fb665bac9c9bc449aefaf8a97  (1 execution(s))
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
  COUNT_IF(NOT candidate__error IS NULL AND candidate__error <> '') AS pre_filtered,
  COUNT_IF(candidate__error = 'max_num_ads_exceeded') AS max_num_ads_exceeded,
  COUNT_IF(candidate__error = 'max_slot_duration_exceeded') AS max_slot_dur_exceeded,
  COUNT_IF(candidate__error = 'floor_price_notmet') AS floor_price_not_met,
  ROUND(
    100.0 * COUNT_IF(NOT candidate__error IS NULL AND candidate__error <> '') / NULLIF(COUNT(*), 0),
    1
  ) AS pre_filter_rate_pct
FROM ${bcv_candidate}
WHERE
  request__context__network_id = 393759
  AND candidate__internal_deal_id IN (669219, 667139, 667140, 670539, 670542)
GROUP BY
  1,
  2
ORDER BY
  2,
  1
