-- account:    sa-presto-tier2
-- skeleton:   700098a3b0a4cd3cfffbcfc608f73d45
-- pattern:    c5d0f04b8ecbb26e5f45a93be5e5333c  (1 execution(s))
-- in suite:   column coverage
-- hoover:     slot
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.

SELECT
  event_name,
  COUNT(*) AS cnt
FROM ${bcv_slot}
WHERE
  slot_event_date = DATE('2026-07-21')
  AND candidate__order_id IN (465918, 682198, 547658, 363855, 278643)
GROUP BY
  event_name
