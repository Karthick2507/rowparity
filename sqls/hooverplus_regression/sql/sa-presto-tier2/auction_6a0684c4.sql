-- account:    sa-presto-tier2
-- skeleton:   a0f8997f37239bbacfc025745d4136c2
-- pattern:    6a0684c4877aed5fbe34c55072051c9b  (1 execution(s))
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
  CASE
    WHEN unique_dsps_per_tx = 1
    THEN '1 dsp'
    WHEN unique_dsps_per_tx <= 3
    THEN '2-3 dsps'
    WHEN unique_dsps_per_tx <= 5
    THEN '4-5 dsps'
    WHEN unique_dsps_per_tx <= 10
    THEN '6-10 dsps'
    ELSE '11+ dsps'
  END AS dsp_bucket,
  COUNT(*) AS num_transactions,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct,
  ROUND(AVG(new_key_count * 1.0 / current_key_count), 2) AS avg_expansion_ratio,
  MAX(unique_dsps_per_tx) AS max_dsps_in_bucket
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
GROUP BY
  1
ORDER BY
  MIN(unique_dsps_per_tx)
