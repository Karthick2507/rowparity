-- account:    sa-presto-tier2
-- skeleton:   2d22f0d430d84f004d1b8f02bc881a29
-- pattern:    cb72c80b23cbe7b166d6b2422e93bf1d  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.

SELECT
  event_name,
  COUNT(*) AS cnt
FROM ${bcv_ack}
WHERE
  log_event_date = DATE('2026-07-21')
  AND candidate__order_id IN (465918, 682198, 547658, 363855, 278643)
GROUP BY
  event_name
