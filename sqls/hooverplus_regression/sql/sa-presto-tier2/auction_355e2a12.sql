-- account:    sa-presto-tier2
-- skeleton:   d3d1688c20095a69d77cb13553e25c49
-- pattern:    355e2a1225fe0ecff623c0bb42a097f3  (1 execution(s))
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
  auction__network_id,
  COUNT(1) AS total_auctions,
  COUNT_IF(NOT auction__tag_id IS NULL AND auction__tag_id <> '') AS with_tag_id,
  ROUND(
    COUNT_IF(NOT auction__tag_id IS NULL AND auction__tag_id <> '') * 100.0 / COUNT(1),
    2
  ) AS tag_id_pass_rate_pct
FROM ${bcv_auction}
WHERE
  BITWISE_AND(auction__auction_status, 2) > 0
GROUP BY
  1
