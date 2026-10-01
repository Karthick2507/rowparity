-- account:    sa-presto-af-etl
-- skeleton:   a825eb4ff24178188390499f64b8b661
-- pattern:    f9cd1da9c3ca486e2551b301c90873c7  (1382 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__context__network_id AS network_id,
  request__transaction_id AS transactional_id,
  slot__ad_unit_id AS ad_unit_id,
  gurantee_mode,
  CAST(IF(NOT MIN(ad_unit_price) IS NULL, MIN(ad_unit_price), -1) AS DOUBLE) AS min_price,
  DATE_TRUNC('HOUR', request__timestamp) AS event_date
FROM (
  SELECT
    request__context__network_id,
    request__transaction_id,
    slot__ad_unit_id,
    ack__ad_id,
    request__timestamp
  FROM ${bcv_ack}
) AS delivery
LEFT JOIN db.default.d_ad_tree_node AS ad
  ON ad.id = delivery.ack__ad_id
LEFT JOIN db.default.d_placement AS plc
  ON ad.placement_id = plc.id
GROUP BY
  1,
  2,
  3,
  4,
  6
