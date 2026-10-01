-- account:    sa-presto-tier2
-- skeleton:   5eaa22ac0192c0a274b5d1af955ea237
-- pattern:    acc9568c2ee6d1ee9be6b8d93683194d  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_FORMAT(request__timestamp, '%y-%m-%d') AS event_day,
  slot__time_position_class AS position_class,
  COUNT(*) AS total_slots,
  SUM(slot__avails) AS total_avails,
  SUM(slot__unfilled_avails) AS unfilled_avails,
  SUM(slot__avails - slot__unfilled_avails) AS filled_avails,
  ROUND(
    100.0 * SUM(slot__avails - slot__unfilled_avails) / NULLIF(SUM(slot__avails), 0),
    1
  ) AS fill_rate_pct
FROM ${bcv_ad}
WHERE
  request__context__network_id = 393759 AND NOT slot__avails IS NULL
GROUP BY
  1,
  2
ORDER BY
  1,
  3 DESC
