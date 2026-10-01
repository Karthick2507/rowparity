-- account:    sa-presto-tier2
-- skeleton:   6198e1f1a96858a1e929341e715200e3
-- pattern:    05c244c67b5ab217401759b0d05cae02  (1 execution(s))
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
  COUNT_IF(NOT auction__network_id IS NULL) AS has_network_id,
  COUNT_IF(NOT auction__application_type IS NULL) AS has_app_type,
  COUNT_IF(NOT auction__device_type IS NULL) AS has_device_type,
  COUNT_IF(NOT auction__site_domain IS NULL AND auction__site_domain <> '') AS has_site_domain,
  ROUND(AVG(LENGTH(auction__site_domain)), 1) AS avg_site_domain_len,
  COUNT_IF(NOT auction__app_bundle IS NULL AND auction__app_bundle <> '') AS has_app_bundle,
  ROUND(AVG(LENGTH(auction__app_bundle)), 1) AS avg_app_bundle_len,
  COUNT_IF(NOT auction__app_storeurl IS NULL AND auction__app_storeurl <> '') AS has_app_storeurl,
  ROUND(AVG(LENGTH(auction__app_storeurl)), 1) AS avg_storeurl_len,
  COUNT_IF(
    NOT auction__auction_network_to_usd_exchange_rate IS NULL
    AND auction__auction_network_to_usd_exchange_rate <> 0
  ) AS has_usd_rate,
  COUNT_IF(
    NOT auction__auction_network_to_eur_exchange_rate IS NULL
    AND auction__auction_network_to_eur_exchange_rate <> 0
  ) AS has_eur_rate,
  COUNT_IF(NOT auction__publisher_id IS NULL AND auction__publisher_id <> '') AS has_publisher_id,
  ROUND(AVG(LENGTH(auction__publisher_id)), 1) AS avg_publisher_id_len,
  COUNT_IF(NOT auction__dynamic_floor_price_algorithm IS NULL) AS has_dfp_algo,
  COUNT_IF(NOT auction__site_domain IS NULL) AS proxy_content_fields,
  COUNT_IF(NOT auction__width IS NULL) AS has_width,
  COUNT_IF(NOT auction__height IS NULL) AS has_height,
  COUNT_IF(NOT auction__supply_chain IS NULL) AS has_supply_chain,
  COUNT_IF(NOT auction__device_ip IS NULL AND auction__device_ip <> '') AS has_device_ip,
  ROUND(AVG(LENGTH(auction__device_ip)), 1) AS avg_ip_len,
  COUNT_IF(NOT auction__device_ipv6 IS NULL AND auction__device_ipv6 <> '') AS has_device_ipv6,
  COUNT_IF(NOT auction__device_ext_truncated_ip IS NULL) AS has_truncated_ip,
  COUNT_IF(NOT auction__device_ext_lmt IS NULL) AS has_ext_lmt,
  COUNT_IF(NOT auction__device_lmt IS NULL) AS has_device_lmt,
  COUNT_IF(NOT auction__regs_coppa IS NULL) AS has_regs_coppa,
  COUNT_IF(NOT auction__content_livestream IS NULL) AS has_content_livestream,
  COUNT_IF(CARDINALITY(auction__third_party_identifier_ids) > 0) AS has_third_party_ids
FROM ${bcv_auction}
WHERE
  NOT auction__dsp_id IS NULL
