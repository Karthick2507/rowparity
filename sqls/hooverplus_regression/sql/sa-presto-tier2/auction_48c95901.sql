-- account:    sa-presto-tier2
-- skeleton:   80072b2908be22fb8ae3325e93378b78
-- pattern:    48c959012472ff3e1bb2595b53bbe75c  (1 execution(s))
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
  unique_dsps_per_tx,
  COUNT(*) AS num_transactions,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_transactions,
  ROUND(AVG(new_key_count * 1.0 / current_key_count), 3) AS avg_expansion_ratio
FROM (
  SELECT
    request__transaction_id,
    COUNT(DISTINCT auction__network_id) AS current_key_count,
    COUNT(DISTINCT (auction__network_id, auction__dsp_id)) AS new_key_count,
    COUNT(DISTINCT auction__dsp_id) AS unique_dsps_per_tx
  FROM ${bcv_auction}
  WHERE
    (
      auction__integration_type IN ('openrtb_normal', 'openrtb_pg_td')
      AND BITWISE_AND(auction__auction_status, 2) > 0
    )
    AND NOT auction__dsp_id IS NULL
  GROUP BY
    request__transaction_id
) AS sub
GROUP BY
  unique_dsps_per_tx
