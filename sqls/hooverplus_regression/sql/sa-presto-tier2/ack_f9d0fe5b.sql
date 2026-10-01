-- account:    sa-presto-tier2
-- skeleton:   c162a62aa9fbe24bdb0fcf275fb8b78c
-- pattern:    f9d0fe5b6b5cd36d162f3662cdd9de2b  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__context__tv_network_id,
  COUNT(*) AS impression_count,
  SUM(ack__metrics__ad_impression) AS ad_impressions
FROM ${bcv_ack}
WHERE
  (
    advertisement__placement_id = 95289317 AND ack__ack_entity_type = 'ad'
  )
  AND ack__traffic_type = 0
GROUP BY
  1
