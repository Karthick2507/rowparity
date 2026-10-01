-- account:    sa-dmo-aqs
-- skeleton:   4937ac72474456220145dd15be2cb88d
-- pattern:    455385375e743be2d5455170c2940233  (695 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id <= ?
--   process_batch_id > ?

SELECT
  FROM_UNIXTIME(CAST(SPLIT_PART(ack__kafka_msg_key, '-', 3) AS BIGINT) / 1000 / 300 * 300) AS process_time,
  CAST(SPLIT_PART(ack__kafka_msg_key, '-', 3) AS BIGINT) / 1000 / 300 * 300 AS process_timestamp,
  COALESCE(advertisement__ad_id, -1) AS ad_id,
  COALESCE(advertisement__placement_id, -1) AS placement_id,
  COALESCE(advertisement__io_id, -1) AS io_id,
  COALESCE(advertisement__campaign_id, -1) AS campaign_id,
  COALESCE(network.network_id, -1) AS network_id,
  COALESCE(ack__traffic_type, 0) AS traffic_type,
  SUM(COALESCE(ack__metrics__ad_impression, 0)) AS impression,
  SUM(
    COALESCE(advertisement__external_reseller__revenue, network.revenue, 0) * COALESCE(ack__metrics__fire_event_revenue_ratio, 0)
  ) AS currency,
  process_batch_id
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__network_id, partners__revenue, partners__network_is_ad_owner) AS network(network_id, revenue, network_is_ad_owner)
WHERE
  (
    ack__ack_entity_type = 'ad'
    AND IF(network.network_is_ad_owner, COALESCE(advertisement__ad_id, -1), -1) > 0
  )
  AND COALESCE(ack__traffic_type, 0) IN (0, 2)
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  11
