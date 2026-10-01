-- account:    sa-dmo-aqs
-- skeleton:   7622c89236cd49087e17d66ca85b0d34
-- pattern:    37cbcf0f5295bdeef06b6ebc4acfc130  (695 execution(s))
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
  COALESCE(candidate__internal_deal_id, -1) AS deal_id,
  COALESCE(network.network_id, -1) AS network_id,
  COALESCE(ack__traffic_type, 0) AS traffic_type,
  SUM(COALESCE(ack__metrics__ad_impression, 0)) AS impression,
  SUM(
    COALESCE(network.revenue, 0) * COALESCE(ack__metrics__fire_event_revenue_ratio, 0)
  ) AS revenue,
  process_batch_id
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__network_id, partners__revenue, partners__supply_source, partners__sales_channel) AS network(network_id, revenue, supply_source, sales_channel)
WHERE
  (
    (
      (
        ack__ack_entity_type = 'ad' AND COALESCE(candidate__internal_deal_id, -1) > 0
      )
      AND COALESCE(ack__traffic_type, 0) IN (0, 2)
    )
    AND COALESCE(network.supply_source, CAST(-1 AS INTEGER)) <> 4
  )
  AND COALESCE(network.sales_channel, CAST(-1 AS INTEGER)) = 4
GROUP BY
  1,
  2,
  3,
  4,
  5,
  8
