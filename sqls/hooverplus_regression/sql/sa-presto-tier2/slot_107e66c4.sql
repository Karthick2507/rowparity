-- account:    sa-presto-tier2
-- skeleton:   1aa60669360e32c36e737be76f651d35
-- pattern:    107e66c491004d3c1e43a654038b2dde  (1 execution(s))
-- in suite:   column coverage
-- hoover:     slot
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  COUNT(*) AS total_requests,
  AVG(slot_count) AS avg_slots_per_request,
  APPROX_PERCENTILE(slot_count, ARRAY[0.5, 0.9, 0.95, 0.99]) AS slot_count_distribution
FROM (
  SELECT
    request__transaction_id,
    CAST(COUNT(*) AS DOUBLE) AS slot_count
  FROM ${bcv_slot}
  WHERE
    (
      request__context__network_id = 534985
      AND BITWISE_AND(COALESCE(slot__flags, 0), 4) = 0
    )
    AND BITWISE_AND(COALESCE(slot__flags, 0), 64) = 0
  GROUP BY
    1
) AS t
