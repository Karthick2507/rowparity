-- account:    sa-presto-tier2
-- skeleton:   19d01741407bd0255fffd79025cdb280
-- pattern:    7ade25fce678b5e616a097d863049d75  (1 execution(s))
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
  COUNT_IF(NOT auction__width IS NULL) AS has_width,
  COUNT_IF(NOT auction__height IS NULL) AS has_height,
  COUNT_IF(NOT auction__supply_chain IS NULL) AS has_supply_chain,
  COUNT_IF(NOT auction__device_ip IS NULL AND auction__device_ip <> '') AS has_device_ip,
  ROUND(
    AVG(
      IF(
        NOT auction__device_ip IS NULL AND auction__device_ip <> '',
        LENGTH(auction__device_ip),
        NULL
      )
    ),
    1
  ) AS avg_ip_len,
  COUNT_IF(NOT auction__device_ipv6 IS NULL AND auction__device_ipv6 <> '') AS has_device_ipv6,
  COUNT_IF(NOT auction__device_ext_truncated_ip IS NULL) AS has_truncated_ip,
  COUNT_IF(NOT auction__device_ext_lmt IS NULL) AS has_ext_lmt,
  COUNT_IF(NOT auction__device_lmt IS NULL) AS has_device_lmt,
  COUNT_IF(NOT auction__regs_coppa IS NULL) AS has_regs_coppa,
  COUNT_IF(NOT auction__content_livestream IS NULL) AS has_content_livestream,
  COUNT_IF(NOT auction__dynamic_floor_price_algorithm IS NULL) AS has_dfp_algo,
  COUNT_IF(CARDINALITY(auction__third_party_identifier_ids) > 0) AS has_third_party_ids,
  ROUND(AVG(CARDINALITY(auction__third_party_identifier_ids)), 2) AS avg_third_party_ids_count
FROM ${bcv_auction}
WHERE
  NOT auction__dsp_id IS NULL
