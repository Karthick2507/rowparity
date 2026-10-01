-- account:    sa-presto-tier2
-- skeleton:   d88e43b04492a220fc7ebf935860ce87
-- pattern:    35cb787f50436c070531494310458107  (1 execution(s))
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
  COUNT(*) AS event_count,
  COUNT(CASE WHEN NOT deviceid IS NULL THEN 1 END) AS with_device_id,
  COUNT(CASE WHEN deviceid IS NULL THEN 1 END) AS without_device_id
FROM ${bcv_request}
WHERE
  network_id = 535279 AND video_cro_network_id = 169843
GROUP BY
  eventtype,
  networkid,
  contentproviderpartnerid
