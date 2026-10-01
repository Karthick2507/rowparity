-- account:    sa-presto-tier2
-- skeleton:   1686e4f9522c389bbb910f8e80bffd69
-- pattern:    ff19e134a4831c9813eee9ed6a9addb8  (1 execution(s))
-- in suite:   column coverage
-- hoover:     auction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < NETWORKLOCAL_TO_UTC(CAST(? AS TIMESTAMP), ?)
--   request__timestamp >= NETWORKLOCAL_TO_UTC(CAST(? AS TIMESTAMP), ?)

SELECT
  imp_error,
  COUNT(*) AS cnt
FROM ${bcv_auction}
CROSS JOIN UNNEST(partners__network_id, partners__sales_channel, partners__internal_deal_ids) AS nw(network_id, sales_channel, deal_ids)
CROSS JOIN UNNEST(deal_ids) AS d(deal_id)
CROSS JOIN UNNEST(auction__impression__error) AS imp(imp_error)
WHERE
  (
    (
      network_id = 520311 AND sales_channel = 4
    ) AND deal_id = 567170
  )
  AND imp_error IN ('global_brand_restricted_by_deal', 'brand_restricted_by_rule')
GROUP BY
  1
