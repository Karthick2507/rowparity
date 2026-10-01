-- account:    sa-presto-tier2
-- skeleton:   1dd70f69feb750e17e3c48f97360431a
-- pattern:    678dca7d65024a229635763a5040735e  (1 execution(s))
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
  auction__impression__deals__bid_floor,
  auction__impression__max_duration,
  auction__impression__min_duration,
  COUNT(1) AS cnt
FROM ${bcv_auction}
WHERE
  (
    request__context__video_cro_network_id = 384777
    AND BITWISE_AND(auction__auction_status, 2) > 0
  )
  AND CARDINALITY(FLATTEN(auction__impression__deals__internal_deal_id)) > 0
GROUP BY
  1,
  2,
  3
