-- account:    sa-presto-tier2
-- skeleton:   42197c765175585f1debd7d6d7f5445a
-- pattern:    13476646f0dea6a19a270819eda14ca9  (1 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__context__video_cro_network_id AS cro_network_id,
  COUNT_IF(request__is_first_request) AS ad_requests,
  SUM(ack__metrics__ad_impression) AS impressions,
  ROUND(
    CAST(SUM(ack__metrics__ad_impression) AS DOUBLE) / NULLIF(COUNT_IF(request__is_first_request), 0),
    4
  ) AS imp_per_request_ratio
FROM ${bcv_transaction}
WHERE
  request__context__video_cro_network_id IN (169843, 372496)
GROUP BY
  request__context__video_cro_network_id
ORDER BY
  request__context__video_cro_network_id
