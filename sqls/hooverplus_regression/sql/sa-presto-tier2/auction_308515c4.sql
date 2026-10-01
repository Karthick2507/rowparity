-- account:    sa-presto-tier2
-- skeleton:   fcf55e2a123784496a542df3ed4889f9
-- pattern:    308515c4f44537797777382f9041e2f8  (1 execution(s))
-- in suite:   column coverage
-- hoover:     auction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  COUNT(*) AS total_transactions,
  ROUND(SUM(new_key_count * 1.0) / SUM(current_key_count), 3) AS traffic_weighted_expansion_ratio,
  ROUND(AVG(new_key_count * 1.0 / current_key_count), 3) AS avg_expansion_ratio,
  APPROX_PERCENTILE(unique_dsps_per_tx, 0.50) AS p50_dsps,
  APPROX_PERCENTILE(unique_dsps_per_tx, 0.90) AS p90_dsps,
  APPROX_PERCENTILE(unique_dsps_per_tx, 0.99) AS p99_dsps,
  MAX(unique_dsps_per_tx) AS max_dsps
FROM (
  SELECT
    request__transaction_id,
    COUNT(DISTINCT auction__network_id) AS current_key_count,
    COUNT(DISTINCT (auction__network_id, auction__dsp_id)) AS new_key_count,
    COUNT(DISTINCT auction__dsp_id) AS unique_dsps_per_tx
  FROM ${bcv_auction}
  WHERE
    NOT auction__dsp_id IS NULL AND BITWISE_AND(auction__auction_status, 8) > 0
  GROUP BY
    request__transaction_id
) AS sub
