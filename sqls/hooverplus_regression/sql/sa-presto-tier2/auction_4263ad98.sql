-- account:    sa-presto-tier2
-- skeleton:   ffa0f22ca6b211ede23d02e2b4a98271
-- pattern:    4263ad981f1fc92e9ba4e7beb337ad6e  (1 execution(s))
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
  ROUND(100.0 * COUNT_IF(NOT auction__supply_chain IS NULL) / COUNT(*), 1) AS pct_supply_chain,
  ROUND(
    100.0 * COUNT_IF(NOT auction__device_ip IS NULL AND auction__device_ip <> '') / COUNT(*),
    1
  ) AS pct_device_ip,
  ROUND(100.0 * COUNT_IF(NOT auction__regs_coppa IS NULL) / COUNT(*), 1) AS pct_regs_coppa,
  ROUND(100.0 * COUNT_IF(NOT auction__dynamic_floor_price_algorithm IS NULL) / COUNT(*), 1) AS pct_dfp,
  ROUND(
    100.0 * COUNT_IF(CARDINALITY(auction__third_party_identifier_ids) > 0) / COUNT(*),
    1
  ) AS pct_3p_ids,
  COUNT(*) AS sampled_rows
FROM (
  SELECT
    auction__supply_chain,
    auction__device_ip,
    auction__regs_coppa,
    auction__dynamic_floor_price_algorithm,
    auction__third_party_identifier_ids
  FROM ${bcv_auction}
  WHERE
    NOT auction__dsp_id IS NULL
  
)
