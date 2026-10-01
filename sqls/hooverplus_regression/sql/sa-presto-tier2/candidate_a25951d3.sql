-- account:    sa-presto-tier2
-- skeleton:   7b5a243000115ed6ed6a53ad176542d8
-- pattern:    a25951d3c2b849e311cec4d18fceb0ae  (1 execution(s))
-- in suite:   column coverage
-- hoover:     candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   c.request__timestamp < CAST(? AS TIMESTAMP)
--   c.request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  c.request__context__network_id AS cro_network,
  c.auction__network_id AS auction_network_id,
  c.auction__dynamic_floor_price_algorithm,
  COUNT(*) AS cnt,
  ROUND(
    AVG(
      ELEMENT_AT(
        c.auction__impression__deals__bid_floor_uplift[ARRAY_POSITION(c.auction__impression__index, c.candidate__rtb_impression_index)],
        ARRAY_POSITION(
          c.auction__impression__deals__internal_deal_id[ARRAY_POSITION(c.auction__impression__index, c.candidate__rtb_impression_index)],
          CAST('52561' AS BIGINT)
        )
      )
    ),
    4
  ) AS avg_deal_uplift
FROM ${bcv_candidate} AS c
WHERE
  c.candidate__internal_deal_id = 52561
  AND c.candidate__auction_outbound_bid_floor < 7.5
GROUP BY
  1,
  2,
  3
