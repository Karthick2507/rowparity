-- account:    sa-presto-tier2
-- skeleton:   f1fcba167272fcabaa22c4d1dae5b2bc
-- pattern:    feb27dd5345866729f0bf3226a9cccfa  (1 execution(s))
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
  ROUND(100.0 * COUNT_IF(NOT auction__width IS NULL) / COUNT(*), 1) AS pct_has_width,
  ROUND(100.0 * COUNT_IF(NOT auction__supply_chain IS NULL) / COUNT(*), 1) AS pct_has_supply_chain,
  ROUND(
    100.0 * COUNT_IF(NOT auction__device_ip IS NULL AND auction__device_ip <> '') / COUNT(*),
    1
  ) AS pct_has_device_ip,
  ROUND(100.0 * COUNT_IF(NOT auction__device_lmt IS NULL) / COUNT(*), 1) AS pct_has_device_lmt,
  ROUND(100.0 * COUNT_IF(NOT auction__regs_coppa IS NULL) / COUNT(*), 1) AS pct_has_regs_coppa,
  ROUND(100.0 * COUNT_IF(NOT auction__dynamic_floor_price_algorithm IS NULL) / COUNT(*), 1) AS pct_has_dfp_algo,
  ROUND(
    100.0 * COUNT_IF(CARDINALITY(auction__third_party_identifier_ids) > 0) / COUNT(*),
    1
  ) AS pct_has_3p_ids,
  ROUND(AVG(CARDINALITY(auction__third_party_identifier_ids)), 2) AS avg_3p_ids_count
FROM ${bcv_auction}
WHERE
  NOT auction__dsp_id IS NULL
