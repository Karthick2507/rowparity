-- account:    sa-presto-tier2
-- skeleton:   527c148abf568eddd635fd8000a77a20
-- pattern:    6e26d849b447fd43306c716130771790  (1 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request_event_date < CAST(? AS TIMESTAMP)
--   request_event_date >= CAST(? AS TIMESTAMP)

SELECT
  transaction_id,
  record_identifier,
  COUNT(*) AS occurrence_count,
  COUNT(DISTINCT request_event_date) AS distinct_dates,
  MIN(request_event_date) AS earliest_event,
  MAX(request_event_date) AS latest_event
FROM ${bcv_transaction}
WHERE
  network_id = 500763 AND transaction_id = '1781802475392189716'
GROUP BY
  transaction_id,
  record_identifier
HAVING
  COUNT(*) > 1
