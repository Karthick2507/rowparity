-- account:    sa-dataapp-yield
-- skeleton:   c1e0867561c2cff12133eb30f3fdae03
-- pattern:    8e27d965323b704edfcbccf4315090f2  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH tmp AS (
  SELECT
    timestamp,
    video_cro_network_id,
    distributor_network_id,
    profile_id,
    programmer_id,
    brand_id,
    endpoint_id,
    endpoint_owner_id,
    environment_id,
    os_id,
    device_type_child_id,
    managed_exchange_network_id,
    seller_network_id,
    listing_id,
    dsp_id,
    COALESCE(d.deal_id, -1) AS deal_id,
    COALESCE(d.buyer_group_id, -1) AS buyer_group_id,
    server_pool,
    SUM(IF(BITWISE_AND(auction__auction_status, 2) > 0, magnifier, 0)) AS auction_request,
    SUM(IF(COALESCE(auction__error, '') <> '', magnifier, 0)) AS auction_err_error,
    SUM(IF(auction__error = 'http_error', magnifier, 0)) AS auction_err_http_error,
    SUM(IF(auction__error = 'timeout', magnifier, 0)) AS auction_err_timeout,
    SUM(IF(auction__error = 'exceed_server_concurrent_limit', magnifier, 0)) AS auction_err_server_concurrent_limit,
    SUM(IF(auction__error = 'exceed_transaction_concurrent_limit', magnifier, 0)) AS auction_err_transaction_concurrent_limit,
    SUM(IF(auction__error = 'blocked_by_traffic_control', magnifier, 0)) AS auction_err_blocked_by_traffic_control,
    SUM(IF(auction__error = 'request_domain_blocked', magnifier, 0)) AS auction_err_request_domain_blocked,
    SUM(IF(auction__error = 'malformed_response', magnifier, 0)) AS auction_err_malformed_response,
    SUM(IF(auction__error = 'no_bids', magnifier, 0)) AS auction_err_no_bids,
    SUM(IF(auction__error = 'impression_no_bids', magnifier, 0)) AS auction_err_impression_no_bids,
    SUM(IF(auction__error = 'coppa_unsupported', magnifier, 0)) AS auction_err_coppa_unsupport,
    SUM(IF(auction__error = 'lat_unsupported', magnifier, 0)) AS auction_err_lat_unsupport,
    SUM(IF(auction__error = 'bid_response_id_nomatch', magnifier, 0)) AS auction_err_bid_response_id_nomatch,
    SUM(IF(auction__error = 'empty_response', magnifier, 0)) AS auction_err_empty_response,
    SUM(IF(auction__error = 'kv_opt_out', magnifier, 0)) AS auction_err_kv_opt_out,
    SUM(IF(auction__error = 'blocked_by_bid_throttling', magnifier, 0)) AS auction_err_blocked_by_bid_throttling,
    SUM(IF(auction__error = 'ccpa_unsupported', magnifier, 0)) AS auction_err_ccpa_unsupport,
    SUM(IF(auction__error = 'gdpr_unsupported', magnifier, 0)) AS auction_err_gdpr_unsupport,
    SUM(IF(auction__error = 'atts_unsupported', magnifier, 0)) AS auction_err_atts_unsupport
  FROM (
    SELECT
      DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
      COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
      COALESCE(request__context__network_id, -1) AS distributor_network_id,
      COALESCE(request__context__profile_id, -1) AS profile_id,
      COALESCE(request__context__standard_programmer_id, -1) AS programmer_id,
      COALESCE(request__context__standard_brand_id, -1) AS brand_id,
      COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
      COALESCE(request__context__standard_endpoint_owner_id, -1) AS endpoint_owner_id,
      COALESCE(visitor__standard_environment_id, -1) AS environment_id,
      COALESCE(visitor__standard_os_id, -1) AS os_id,
      COALESCE(visitor__standard_device_type_child_id, -1) AS device_type_child_id,
      nw_id AS managed_exchange_network_id,
      COALESCE(co_id, -1) AS seller_network_id,
      IF(CARDINALITY(inbound_listing_ids) > 0, ELEMENT_AT(inbound_listing_ids, 1), -1) AS listing_id,
      COALESCE(auction__dsp_id, -1) AS dsp_id,
      auction__auction_status,
      auction__error,
      auction__impression__deals__internal_deal_id,
      auction__impression__deals__buyer_group_id,
      COALESCE(request__server_pool, 'na') AS server_pool,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) AS magnifier
    FROM ${bcv_auction}
    CROSS JOIN UNNEST(partners__network_id, partners__content_owner_network_id, partners__supply_source, partners__inbound_listing_id) AS t(nw_id, co_id, supply_source, inbound_listing_ids)
    WHERE
      t.supply_source = 6
  ) AS tmp1
  CROSS JOIN UNNEST(auction__impression__deals__internal_deal_id, auction__impression__deals__buyer_group_id) AS imp(deal_ids, buyer_group_ids)
  CROSS JOIN UNNEST(imp.deal_ids, imp.buyer_group_ids) AS d(deal_id, buyer_group_id)
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
    18
)
SELECT
  tmp.*,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(programmer.name, 'na') AS programmer_name,
  COALESCE(brand.name, 'na') AS brand_name,
  COALESCE(endpoint.name, 'na') AS endpoint_name,
  COALESCE(endpoint_owner.name, 'na') AS endpoint_owner_name,
  COALESCE(env.name, 'na') AS environment_name,
  COALESCE(os.name, 'na') AS os_name,
  COALESCE(device_type.name, 'na') AS device_type_child_name,
  COALESCE(buyer_nw.name, 'na') AS managed_exchange_network_name,
  COALESCE(seller_nw.name, 'na') AS seller_network_name,
  COALESCE(listing.name, 'na') AS listing_name,
  COALESCE(dsp.name, 'na') AS dsp_name,
  IF(buyer_group_id > 0, 'open exchange', COALESCE(d_ssp_deal_metadata.type, 'na')) AS deal_type,
  COALESCE(d_ssp_deal_metadata.external_id, 'na') AS public_deal_id,
  COALESCE(bg.name, 'na') AS buyer_group_name
FROM tmp
LEFT JOIN db.default.d_network AS nw
  ON nw.id = video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = distributor_network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = profile_id
LEFT JOIN db.default.d_lu_mkpl_standard_programmer AS programmer
  ON programmer.id = programmer_id
LEFT JOIN db.default.d_lu_mkpl_standard_brand AS brand
  ON brand.id = brand_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS endpoint
  ON endpoint.id = endpoint_id
LEFT JOIN db.default.d_lu_mkpl_endpoint_owner AS endpoint_owner
  ON endpoint_owner.id = endpoint_owner_id
LEFT JOIN db.default.d_lu_mkpl_standard_environment AS env
  ON env.id = environment_id
LEFT JOIN db.default.d_lu_mkpl_standard_os AS os
  ON os.id = os_id
LEFT JOIN db.default.d_lu_mkpl_standard_device_type AS device_type
  ON device_type.id = device_type_child_id
LEFT JOIN db.default.d_network AS buyer_nw
  ON buyer_nw.id = managed_exchange_network_id
LEFT JOIN db.default.d_network AS seller_nw
  ON seller_nw.id = tmp.seller_network_id
LEFT JOIN db.default.d_mkpl_listing AS listing
  ON listing.id = listing_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = dsp_id
LEFT JOIN db.default.d_ssp_deal_metadata AS d_ssp_deal_metadata
  ON d_ssp_deal_metadata.id = deal_id
LEFT JOIN db.default.d_ssp_buyer_group AS bg
  ON bg.id = buyer_group_id
