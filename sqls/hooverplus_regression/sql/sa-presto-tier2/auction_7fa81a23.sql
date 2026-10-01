-- account:    sa-presto-tier2
-- skeleton:   f8be6e118922efc0c87fb73e875cf86f
-- pattern:    7fa81a23e1f856a5bb8f6820deb0aca4  (1 execution(s))
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
  DATE_TRUNC('HOUR', request__timestamp) AS hr,
  COUNT(*) AS total_auctions,
  SUM(
    COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
  ) AS magnified_auctions
FROM ${bcv_auction}
WHERE
  auction__network_id = 534985
GROUP BY
  1
