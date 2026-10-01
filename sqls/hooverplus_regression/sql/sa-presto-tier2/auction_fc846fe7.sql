-- account:    sa-presto-tier2
-- skeleton:   1a42bf62dc9c70a1085ba1b979aba6f0
-- pattern:    fc846fe791080c6832efec87f6bc7ff9  (1 execution(s))
-- in suite:   column coverage
-- hoover:     auction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   a.request__timestamp < CAST(? AS TIMESTAMP)
--   a.request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_FORMAT(a.request__timestamp, '%y-%m-%d %h') AS hour,
  COUNT(*) AS auction_cnt
FROM ${bcv_auction} AS a
CROSS JOIN UNNEST(FLATTEN(a.auction__impression__deals__internal_deal_id)) AS deal_id(internal_deal_id)
WHERE
  a.auction__network_id = 169843
  AND deal_id.internal_deal_id IN (CAST('28321' AS BIGINT), CAST('263478' AS BIGINT))
GROUP BY
  1
ORDER BY
  1
