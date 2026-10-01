-- account:    sa-presto-tier2
-- skeleton:   5e7a05871a79b2b7b2951a68649301b7
-- pattern:    80594dad6e42254cefa9eb0bfff18637  (1 execution(s))
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
  auction__integration_type,
  auction__is_exchange_auction,
  auction__is_ssp_auction,
  auction__is_order_prog_auction,
  auction__is_market_auction,
  COUNT(*) AS cnt
FROM ${bcv_auction}
WHERE
  request__is_ssp_bidder_request = TRUE
GROUP BY
  1,
  2,
  3,
  4,
  5
