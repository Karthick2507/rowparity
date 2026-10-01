-- account:    sa-presto-tier2
-- skeleton:   6bb8334847c8bad4a76848543af4615b
-- pattern:    575d5a5dbeaf0285ef32f8aa77b968ce  (1 execution(s))
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
  DATE_TRUNC('DAY', request__timestamp) AS dt,
  COUNT(*) AS total_auctions,
  SUM(
    COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
  ) AS magnified_auctions
FROM ${bcv_auction}
WHERE
  auction__network_id = 534985
GROUP BY
  1
