-- account:    sa-presto-tier2
-- skeleton:   dc827de6d86606cab1a11fbb081ed25b
-- pattern:    3d03c3f4aa05c8af5b514224ee41320f  (1 execution(s))
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
    WHEN unique_dsps_per_tx <= 5
    THEN '1-5 dsps'
    WHEN unique_dsps_per_tx <= 10
    THEN '6-10 dsps'
    WHEN unique_dsps_per_tx <= 20
    THEN '11-20 dsps'
    WHEN unique_dsps_per_tx <= 30
    THEN '21-30 dsps'
    WHEN unique_dsps_per_tx <= 50
    THEN '31-50 dsps'
    ELSE '51+ dsps'
  END AS dsp_bucket,
  COUNT(*) AS num_transactions,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct,
  ROUND(AVG(new_key_count * 1.0 / current_key_count), 2) AS avg_expansion_ratio,
  ROUND(MIN(new_key_count * 1.0 / current_key_count), 2) AS min_expansion_ratio,
  ROUND(MAX(new_key_count * 1.0 / current_key_count), 2) AS max_expansion_ratio
FROM (
  SELECT
    request__transaction_id,
    COUNT(DISTINCT auction__network_id) AS current_key_count,
    COUNT(DISTINCT (auction__network_id, auction__dsp_id)) AS new_key_count,
    COUNT(DISTINCT auction__dsp_id) AS unique_dsps_per_tx
  FROM ${bcv_auction}
  WHERE
    NOT auction__dsp_id IS NULL
  GROUP BY
    request__transaction_id
) AS sub
GROUP BY
  1
ORDER BY
  MIN(unique_dsps_per_tx)
