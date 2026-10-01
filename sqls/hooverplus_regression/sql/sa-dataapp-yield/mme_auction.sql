-- account:    sa-dataapp-yield
-- skeleton:   803422f49e072b06923c1439b5ad23b0
-- pattern:    a554286a6fd4e35e01fc37a41c26b5f3  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(request__context__standard_programmer_id, -1) AS programmer_id,
  COALESCE(programmer.name, 'na') AS programmer_name,
  COALESCE(request__context__standard_brand_id, -1) AS brand_id,
  COALESCE(brand.name, 'na') AS brand_name,
  COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
  COALESCE(endpoint.name, 'na') AS endpoint_name,
  COALESCE(request__context__standard_endpoint_owner_id, -1) AS endpoint_owner_id,
  COALESCE(endpoint_owner.name, 'na') AS endpoint_owner_name,
  COALESCE(visitor__standard_environment_id, -1) AS environment_id,
  COALESCE(env.name, 'na') AS environment_name,
  COALESCE(visitor__standard_os_id, -1) AS os_id,
  COALESCE(os.name, 'na') AS os_name,
  COALESCE(visitor__standard_device_type_child_id, -1) AS device_type_child_id,
  COALESCE(device_type.name, 'na') AS device_type_child_name,
  nw_id AS managed_exchange_network_id,
  COALESCE(buyer_nw.name, 'na') AS managed_exchange_network_name,
  COALESCE(co_id, -1) AS seller_network_id,
  COALESCE(seller_nw.name, 'na') AS seller_network_name,
  IF(CARDINALITY(inbound_listing_ids) > 0, ELEMENT_AT(inbound_listing_ids, 1), -1) AS listing_id,
  COALESCE(listing.name, 'na') AS listing_name,
  COALESCE(auction__dsp_id, -1) AS dsp_id,
  COALESCE(dsp.name, 'na') AS dsp_name,
  -1 AS deal_id,
  -1 AS buyer_group_id,
  'na' AS deal_type,
  'na' AS public_deal_id,
  'na' AS buyer_group_name,
  COALESCE(request__server_pool, 'na') AS server_pool,
  SUM(
    IF(
      BITWISE_AND(auction__auction_status, 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_request,
  SUM(
    IF(
      COALESCE(auction__error, '') <> '',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_error,
  SUM(
    IF(
      auction__error = 'http_error',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_http_error,
  SUM(
    IF(
      auction__error = 'timeout',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_timeout,
  SUM(
    IF(
      auction__error = 'exceed_server_concurrent_limit',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_server_concurrent_limit,
  SUM(
    IF(
      auction__error = 'exceed_transaction_concurrent_limit',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_transaction_concurrent_limit,
  SUM(
    IF(
      auction__error = 'blocked_by_traffic_control',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_blocked_by_traffic_control,
  SUM(
    IF(
      auction__error = 'request_domain_blocked',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_request_domain_blocked,
  SUM(
    IF(
      auction__error = 'malformed_response',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_malformed_response,
  SUM(
    IF(
      auction__error = 'no_bids',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_no_bids,
  SUM(
    IF(
      auction__error = 'impression_no_bids',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_impression_no_bids,
  SUM(
    IF(
      auction__error = 'coppa_unsupported',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_coppa_unsupport,
  SUM(
    IF(
      auction__error = 'lat_unsupported',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_lat_unsupport,
  SUM(
    IF(
      auction__error = 'bid_response_id_nomatch',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_bid_response_id_nomatch,
  SUM(
    IF(
      auction__error = 'empty_response',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_empty_response,
  SUM(
    IF(
      auction__error = 'kv_opt_out',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_kv_opt_out,
  SUM(
    IF(
      auction__error = 'blocked_by_bid_throttling',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_blocked_by_bid_throttling,
  SUM(
    IF(
      auction__error = 'ccpa_unsupported',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_ccpa_unsupport,
  SUM(
    IF(
      auction__error = 'gdpr_unsupported',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_gdpr_unsupport,
  SUM(
    IF(
      auction__error = 'atts_unsupported',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_atts_unsupport
FROM ${bcv_auction}
CROSS JOIN UNNEST(partners__network_id, partners__content_owner_network_id, partners__supply_source, partners__inbound_listing_id) AS t(nw_id, co_id, supply_source, inbound_listing_ids)
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_lu_mkpl_standard_programmer AS programmer
  ON programmer.id = request__context__standard_programmer_id
LEFT JOIN db.default.d_lu_mkpl_standard_brand AS brand
  ON brand.id = request__context__standard_brand_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS endpoint
  ON endpoint.id = request__context__standard_endpoint_id
LEFT JOIN db.default.d_lu_mkpl_endpoint_owner AS endpoint_owner
  ON endpoint_owner.id = request__context__standard_endpoint_owner_id
LEFT JOIN db.default.d_lu_mkpl_standard_environment AS env
  ON env.id = visitor__standard_environment_id
LEFT JOIN db.default.d_lu_mkpl_standard_os AS os
  ON os.id = visitor__standard_os_id
LEFT JOIN db.default.d_lu_mkpl_standard_device_type AS device_type
  ON device_type.id = visitor__standard_device_type_child_id
LEFT JOIN db.default.d_network AS buyer_nw
  ON buyer_nw.id = nw_id
LEFT JOIN db.default.d_network AS seller_nw
  ON seller_nw.id = co_id
LEFT JOIN db.default.d_mkpl_listing AS listing
  ON listing.id = IF(CARDINALITY(inbound_listing_ids) > 0, ELEMENT_AT(inbound_listing_ids, 1), -1)
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = auction__dsp_id
WHERE
  t.supply_source = 6
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  32,
  33,
  34,
  35
