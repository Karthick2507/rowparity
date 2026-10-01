-- account:    sa-presto-tier2
-- skeleton:   8f8cadb0db76db9977f45e91126d6483
-- pattern:    65301310242d5b328e7e0e0db706aa0d  (1 execution(s))
-- in suite:   column coverage
-- hoover:     request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  CARDINALITY(request__slots__max_duration) AS inbound_slot_count,
  COUNT(*) AS request_cnt,
  SUM(COALESCE(request__log_sampling__magnifier, 1)) AS magnified
FROM ${bcv_request}
WHERE
  request__context__network_id = 534985 AND request__context__profile_id = 16934
GROUP BY
  1
