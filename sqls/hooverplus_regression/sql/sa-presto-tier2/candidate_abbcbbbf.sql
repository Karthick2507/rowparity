-- account:    sa-presto-tier2
-- skeleton:   0ba0432bd62e44170abdb745fd6a212f
-- pattern:    abbcbbbf57dc04a90bee284dbdcdc6a8  (1 execution(s))
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
  COUNT_IF(candidate__error IS NULL OR candidate__error = '') AS won_slots
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
