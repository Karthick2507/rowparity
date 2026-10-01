-- account:    sa-presto-tier2
-- skeleton:   bdab3d1e72bad425d4070f90c77c1a8f
-- pattern:    db10395469168faf5df471c252810ab6  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request_event_date = DATE(?)

SELECT
  DATE(FROM_UNIXTIME(request_timestamp / 1000000)) AS event_date,
  COUNT(DISTINCT CASE WHEN event_name = 'slotimpression' THEN transaction_id END) AS selected_ads_in_played_slot,
  COUNT(
    DISTINCT CASE
      WHEN event_name = 'defaultimpression'
      THEN transaction_id || '_' || CAST(position_in_slot AS VARCHAR)
    END
  ) AS net_counted_ads_approx
FROM ${bcv_ack}
WHERE
  network_id = 523969 AND order_id IN (465918, 682198, 547658, 363855, 278643)
