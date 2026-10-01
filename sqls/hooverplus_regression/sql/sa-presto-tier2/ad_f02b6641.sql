-- account:    sa-presto-tier2
-- skeleton:   83f96979c93e073973f1df324742072d
-- pattern:    f02b6641602bc176113f2c37b03e520f  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.

SELECT
  event_name,
  COUNT(*) AS cnt
FROM ${bcv_ad}
WHERE
  ad_event_date = DATE('2026-07-21')
  AND candidate__order_id IN (465918, 682198, 547658, 363855, 278643)
GROUP BY
  event_name
