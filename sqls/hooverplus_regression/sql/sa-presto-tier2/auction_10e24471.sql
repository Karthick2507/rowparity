-- account:    sa-presto-tier2
-- skeleton:   e5c3d9bf5d320a974d1444a4d36bc2a9
-- pattern:    10e2447130843074deb585d66dec5084  (1 execution(s))
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
  COUNT(DISTINCT request__transaction_id) AS total_tx_with_any_auction,
  COUNT(
    DISTINCT IF(BITWISE_AND(auction__auction_status, 8) > 0, request__transaction_id, NULL)
  ) AS tx_with_bid_received,
  ROUND(
    100.0 * COUNT(
      DISTINCT IF(BITWISE_AND(auction__auction_status, 8) > 0, request__transaction_id, NULL)
    ) / COUNT(DISTINCT request__transaction_id),
    1
  ) AS pct_tx_with_bid_received,
  COUNT(DISTINCT (request__transaction_id, auction__network_id)) AS total_anc_entries_today,
  COUNT(
    DISTINCT IF(
      BITWISE_AND(auction__auction_status, 8) > 0,
      (request__transaction_id, auction__network_id),
      NULL
    )
  ) AS anc_entries_with_bid_received,
  ROUND(
    100.0 * COUNT(
      DISTINCT IF(
        BITWISE_AND(auction__auction_status, 8) > 0,
        (request__transaction_id, auction__network_id),
        NULL
      )
    ) / COUNT(DISTINCT (request__transaction_id, auction__network_id)),
    1
  ) AS pct_anc_entries_surviving
FROM ${bcv_auction}
WHERE
  NOT auction__dsp_id IS NULL
