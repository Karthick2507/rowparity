-- account:    sa-presto-tier2
-- skeleton:   567142fa03a9c0d37e4cc3c96b9b3327
-- pattern:    3236223d75dd0a3da4b60d58b4e0e3de  (1 execution(s))
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
  eventtype,
  networkid,
  contentproviderpartnerid,
  deviceid,
  xifaid,
  COUNT(*) AS event_count
FROM ${bcv_request}
WHERE
  network_id = 535279 AND video_cro_network_id = 169843
GROUP BY
  eventtype,
  networkid,
  contentproviderpartnerid,
  deviceid,
  xifaid
