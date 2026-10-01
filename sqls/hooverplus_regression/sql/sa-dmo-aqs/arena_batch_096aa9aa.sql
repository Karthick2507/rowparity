-- account:    sa-dmo-aqs
-- skeleton:   1e652e0b368ee4a0eca22b1db4621da4
-- pattern:    096aa9aa9f90dbcf28a9201b83aee797  (694 execution(s))
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
  COALESCE(network.inbound_order_id, -1) AS order_id,
  COALESCE(ack__traffic_type, 0) AS traffic_type,
  network.network_id AS network_id,
  SUM(COALESCE(ack__metrics__ad_impression, 0)) AS impression,
  0 AS total_avails,
  process_batch_id
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__network_id, partners__inbound_order_id, partners__network_is_ad_owner, partners__network_is_extra_item_owner) AS network(network_id, inbound_order_id, network_is_ad_owner, network_is_extra_item_owner)
WHERE
  (
    (
      ack__ack_entity_type = 'ad' AND COALESCE(ack__traffic_type, 0) IN (0, 2)
    )
    AND COALESCE(network.inbound_order_id, -1) > 0
  )
  AND (
    (
      NOT ack__is_private_impression
    )
    OR network.network_is_ad_owner
    OR network.network_is_extra_item_owner
  )
GROUP BY
  1,
  2,
  3,
  4,
  5,
  8
UNION ALL
SELECT
  FROM_UNIXTIME(CAST(SPLIT_PART(ack__kafka_msg_key, '-', 3) AS BIGINT) / 1000 / 300 * 300) AS process_time,
  CAST(SPLIT_PART(ack__kafka_msg_key, '-', 3) AS BIGINT) / 1000 / 300 * 300 AS process_timestamp,
  COALESCE(network.inbound_order_id, -1) AS order_id,
  COALESCE(ack__traffic_type, 0) AS traffic_type,
  network.network_id AS network_id,
  0 AS impression,
  SUM(COALESCE(network.total_avails, 0) * COALESCE(ack__metrics__slot_impression, 0)) AS total_avails,
  process_batch_id
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__network_id, partners__inbound_order_id, partners__avails_category__total_avails_in_played_slot) AS network(network_id, inbound_order_id, total_avails)
WHERE
  (
    (
      COALESCE(ack__traffic_type, 0) IN (0, 2) AND ack__ack_entity_type = 'slot'
    )
    AND BITWISE_AND(slot__flags, 64) = 0
  )
  AND COALESCE(network.inbound_order_id, -1) > 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  8
