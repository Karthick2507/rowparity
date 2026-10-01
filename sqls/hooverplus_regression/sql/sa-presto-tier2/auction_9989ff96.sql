-- account:    sa-presto-tier2
-- skeleton:   5090786600316703199fbc1a0c0f5a6b
-- pattern:    9989ff96e4a699c4993816fb0dfa0066  (1 execution(s))
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
  request__transaction_id,
  COUNT(*) AS auction_cnt,
  SUM(IF(BITWISE_AND(auction__auction_status, 2) > 0, 1, 0)) AS bid_requests_sent,
  SUM(IF(BITWISE_AND(auction__auction_status, 8) > 0, 1, 0)) AS bid_responses
FROM ${bcv_auction}
WHERE
  request__context__video_cro_network_id = 534985
GROUP BY
  1
