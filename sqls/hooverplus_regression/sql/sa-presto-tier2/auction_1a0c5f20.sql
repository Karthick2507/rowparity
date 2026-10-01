-- account:    sa-presto-tier2
-- skeleton:   611c5b684b8183da80e04e7a638e7a78
-- pattern:    1a0c5f20ce269b852d35fe3d4e1c309a  (1 execution(s))
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
  COUNT(*) AS total_auctions,
  COUNT_IF(CARDINALITY(auction__impression__deals__internal_deal_id) > 1) AS multi_imp_auctions_by_deals,
  SUM(
    COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
  ) AS magnified_total
FROM ${bcv_auction}
WHERE
  request__context__video_cro_network_id = 534985
GROUP BY
  DATE_TRUNC('HOUR', request__timestamp)
