-- account:    sa-presto-tier2
-- skeleton:   c43f0740c87660b1822747495e75058e
-- pattern:    ff1b06b876608273c8c115d6b3f670aa  (1 execution(s))
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
  COUNT(*) AS total_slots,
  SUM(slot__avails) AS total_avails,
  SUM(slot__unfilled_avails) AS unfilled_avails,
  SUM(slot__avails - slot__unfilled_avails) AS filled_avails,
  ROUND(
    100.0 * SUM(slot__avails - slot__unfilled_avails) / NULLIF(SUM(slot__avails), 0),
    1
  ) AS network_fill_rate_pct
FROM ${bcv_ad}
WHERE
  (
    request__context__network_id = 393759 AND NOT slot__avails IS NULL
  )
  AND request__is_first_user_visitor = FALSE
GROUP BY
  1
ORDER BY
  1
