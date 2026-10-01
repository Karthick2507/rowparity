-- account:    sa-presto-tier2
-- skeleton:   ded696985b15af57c3db60ff32bbb375
-- pattern:    467cecfa1074b3d2c37298beab356d18  (1 execution(s))
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
  COUNT_IF(NOT candidate__error IS NULL AND candidate__error <> '') AS pre_filtered,
  COUNT_IF(candidate__error = 'max_num_ads_exceeded') AS max_num_ads_exceeded,
  COUNT_IF(candidate__error = 'max_slot_duration_exceeded') AS max_slot_duration_exceeded,
  COUNT_IF(candidate__error = 'floor_price_notmet') AS floor_price_not_met,
  COUNT_IF(candidate__error = 'empty_response') AS empty_response,
  COUNT_IF(candidate__error = 'exclusivity_by_stream') AS exclusivity_stream,
  COUNT_IF(candidate__error = 'exclusivity_by_slot') AS exclusivity_slot,
  COUNT_IF(candidate__error = 'slot_filled_by_multi_ads') AS slot_filled_multi_ads,
  COUNT_IF(candidate__error IS NULL OR candidate__error = '') AS no_error
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
