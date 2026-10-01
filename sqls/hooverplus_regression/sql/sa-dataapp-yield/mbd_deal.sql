-- account:    sa-dataapp-yield
-- skeleton:   8d46e71644cfd4e60802d7b50ce478b3
-- pattern:    9ba75304a35ee405dc5e6ee3d200261e  (698 execution(s))
-- in suite:   daily commitment
-- hoover:     ack, auction, candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  tmp.*,
  IF(video_cro_network_id = -1, 'na', COALESCE(nw.name, 'na')) AS video_cro_network_name,
  IF(distributor_network_id = -1, 'na', COALESCE(d_nw.name, 'na')) AS distributor_network_name,
  COALESCE(p.name, 'na') AS profile_name,
  IF(tmp.seller_network_id = -1, 'na', COALESCE(seller_nw.name, 'na')) AS seller_network_name,
  COALESCE(listing.name, 'na') AS listing_name,
  COALESCE(endpoint_owner.name, 'na') AS endpoint_owner_name,
  COALESCE(endpoint.name, 'na') AS endpoint_name,
  COALESCE(programmer.name, 'na') AS programmer_name,
  COALESCE(brand.name, 'na') AS brand_name,
  COALESCE(channel.name, 'na') AS channel_name,
  COALESCE(dsp.name, 'na') AS dsp_name,
  COALESCE(d_ssp_deal_metadata.external_id, 'na') AS deal_public_id,
  COALESCE(d_ssp_deal_metadata.name, 'na') AS deal_name
FROM (
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(request__context__network_id, -1) AS distributor_network_id,
    COALESCE(request__context__profile_id, -1) AS profile_id,
    COALESCE(co_id, -1) AS seller_network_id,
    IF(CARDINALITY(inbound_listing_ids) > 0, ELEMENT_AT(inbound_listing_ids, 1), -1) AS listing_id,
    COALESCE(request__context__standard_endpoint_owner_id, -1) AS endpoint_owner_id,
    COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
    COALESCE(request__context__standard_programmer_id, -1) AS programmer_id,
    COALESCE(request__context__standard_brand_id, -1) AS brand_id,
    COALESCE(request__context__standard_channel_id, -1) AS channel_id,
    COALESCE(auction__dsp_id, -1) AS dsp_id,
    COALESCE(d.deal_id, -1) AS deal_id,
    CAST(ROUND(COALESCE(d.deal_floor_price, 0.0), 1) AS VARCHAR) AS deal_floor_price,
    CAST(ROUND(COALESCE(d.deal_floor_uplift, 0.0), 1) AS VARCHAR) AS deal_floor_uplift,
    '' AS deal_bidding_price,
    '' AS deal_clearing_price,
    SUM(
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
    ) AS auction_request,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 8) > 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_response_with_bids,
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
        auction__error = 'no_bids',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_err_no_bids,
    SUM(
      IF(
        auction__error = 'bid_response_id_nomatch',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_err_id_no_match,
    SUM(
      IF(
        auction__error = 'empty_response',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_err_empty_response,
    SUM(
      IF(
        auction__error = 'malformed_response',
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_err_malformed_response,
    0 AS bids_received,
    0 AS bids_resolved,
    0 AS bids_selected,
    0 AS bids_selected_primary,
    0 AS bids_selected_fallback,
    0 AS bids_err_no_deal,
    0 AS bids_err_no_ad,
    0 AS bids_err_no_seat,
    0 AS bids_err_no_vast,
    0 AS bids_err_wrapper_http_error,
    0 AS bids_err_wrapper_timeout,
    0 AS bids_err_ad_rejected,
    0 AS bids_err_exclusivity,
    0 AS bids_err_floor_price_not_met,
    0 AS bids_err_industry_restrict_by_deal,
    0 AS bids_err_industry_restrict_by_ni,
    0 AS bids_err_industry_restrict_by_listing,
    0 AS bids_err_industry_restrict_by_ip,
    0 AS bids_err_brand_related,
    0 AS bids_err_advertiser_related,
    0 AS bids_err_industry_related,
    0 AS bids_err_competition_failure,
    0 AS bids_err_profile_check_failed,
    0 AS ack_ad_impression,
    0 AS ack_ad_revenue
  FROM ${bcv_auction}
  CROSS JOIN UNNEST(partners__network_id, partners__content_owner_network_id, partners__inbound_listing_id) AS t(nw_id, co_id, inbound_listing_ids)
  CROSS JOIN UNNEST(auction__impression__deals__internal_deal_id, auction__impression__deals__bid_floor, auction__impression__deals__bid_floor_uplift) AS imp(deal_ids, deal_floor_prices, deal_floor_uplifts)
  CROSS JOIN UNNEST(imp.deal_ids, imp.deal_floor_prices, imp.deal_floor_uplifts) AS d(deal_id, deal_floor_price, deal_floor_uplift)
  WHERE
    t.nw_id = 523319 AND BITWISE_AND(auction__auction_status, 2) > 0
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
    17
  UNION ALL
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(request__context__network_id, -1) AS distributor_network_id,
    COALESCE(request__context__profile_id, -1) AS profile_id,
    COALESCE(co_id, -1) AS seller_network_id,
    IF(CARDINALITY(inbound_listing_ids) > 0, ELEMENT_AT(inbound_listing_ids, 1), -1) AS listing_id,
    COALESCE(request__context__standard_endpoint_owner_id, -1) AS endpoint_owner_id,
    COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
    COALESCE(request__context__standard_programmer_id, -1) AS programmer_id,
    COALESCE(request__context__standard_brand_id, -1) AS brand_id,
    COALESCE(request__context__standard_channel_id, -1) AS channel_id,
    COALESCE(candidate__dsp_id, -1) AS dsp_id,
    COALESCE(candidate__internal_deal_id, -1) AS deal_id,
    CAST(ROUND(COALESCE(d.deal_floor_price, 0.0), 1) AS VARCHAR) AS deal_floor_price,
    CAST(ROUND(COALESCE(d.deal_floor_uplift, 0.0), 1) AS VARCHAR) AS deal_floor_uplift,
    CAST(ROUND(
      COALESCE(
        candidate__raw_price * candidate__candidate_network_to_auction_network_exchange_rate,
        0.0
      ),
      1
    ) AS VARCHAR) AS deal_bidding_price,
    CAST(ROUND(
      COALESCE(
        candidate__clearing_price * candidate__candidate_network_to_auction_network_exchange_rate,
        0.0
      ),
      1
    ) AS VARCHAR) AS deal_clearing_price,
    0 AS auction_request,
    0 AS auction_response_with_bids,
    0 AS auction_err_http_error,
    0 AS auction_err_timeout,
    0 AS auction_err_no_bids,
    0 AS auction_err_id_no_match,
    0 AS auction_err_empty_response,
    0 AS auction_err_malformed_response,
    SUM(IF(BITWISE_AND(candidate__bid_status, 1) > 0, 1, 0)) AS bids_received,
    SUM(IF(BITWISE_AND(candidate__bid_status, 2) > 0, 1, 0)) AS bids_resolved,
    SUM(IF(BITWISE_AND(candidate__bid_status, 8) > 0, 1, 0)) AS bids_selected,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 8) > 0
        AND BITWISE_AND(advertisement__flags, 32) = 0,
        1,
        0
      )
    ) AS bids_selected_primary,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 8) > 0
        AND BITWISE_AND(advertisement__flags, 32) > 0,
        1,
        0
      )
    ) AS bids_selected_fallback,
    SUM(IF(candidate__error = 'empty_bid_dealid', 1, 0)) AS bids_err_no_deal,
    SUM(IF(candidate__error = 'no_valid_creative', 1, 0)) AS bids_err_no_ad,
    SUM(IF(candidate__error = 'unknown_seat', 1, 0)) AS bids_err_no_seat,
    SUM(IF(candidate__error IN ('empty_response', 'malformed_response'), 1, 0)) AS bids_err_no_vast,
    SUM(IF(candidate__error = 'wrapper_http_error', 1, 0)) AS bids_err_wrapper_http_error,
    SUM(IF(candidate__error = 'wrapper_timeout', 1, 0)) AS bids_err_wrapper_timeout,
    SUM(IF(candidate__error = 'compliance_not_approved', 1, 0)) AS bids_err_ad_rejected,
    SUM(IF(candidate__error = 'exclusivity_by_stream', 1, 0)) AS bids_err_exclusivity,
    SUM(IF(candidate__error LIKE '%floor_price_not%', 1, 0)) AS bids_err_floor_price_not_met,
    SUM(IF(candidate__error = 'industry_restricted_by_deal', 1, 0)) AS bids_err_industry_restrict_by_deal,
    SUM(IF(candidate__error = 'compliance_check_failed', 1, 0)) AS bids_err_industry_restrict_by_ni,
    SUM(IF(candidate__error = 'industry_restricted_by_listing', 1, 0)) AS bids_err_industry_restrict_by_listing,
    SUM(IF(candidate__error = 'invalid_compliance_for_inventory_protection', 1, 0)) AS bids_err_industry_restrict_by_ip,
    SUM(IF(candidate__error LIKE '%brand%', 1, 0)) AS bids_err_brand_related,
    SUM(IF(candidate__error LIKE '%advertiser%', 1, 0)) AS bids_err_advertiser_related,
    SUM(IF(candidate__error LIKE '%industry%', 1, 0)) AS bids_err_industry_related,
    SUM(IF(candidate__error = 'competition_failure', 1, 0)) AS bids_err_competition_failure,
    SUM(IF(candidate__error LIKE '%profile_check%', 1, 0)) AS bids_err_profile_check_failed,
    0 AS ack_ad_impression,
    0 AS ack_ad_revenue
  FROM ${bcv_candidate}
  CROSS JOIN UNNEST(partners__network_id, partners__content_owner_network_id, partners__inbound_listing_id) AS t(nw_id, co_id, inbound_listing_ids)
  CROSS JOIN UNNEST(auction__impression__deals__internal_deal_id, auction__impression__deals__bid_floor, auction__impression__deals__bid_floor_uplift) AS imp(deal_ids, deal_floor_prices, deal_floor_uplifts)
  CROSS JOIN UNNEST(imp.deal_ids, imp.deal_floor_prices, imp.deal_floor_uplifts) AS d(deal_id, deal_floor_price, deal_floor_uplift)
  WHERE
    t.nw_id = 523319 AND d.deal_id = candidate__internal_deal_id
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
    17
  UNION ALL
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(request__context__network_id, -1) AS distributor_network_id,
    COALESCE(request__context__profile_id, -1) AS profile_id,
    COALESCE(co_id, -1) AS seller_network_id,
    IF(CARDINALITY(inbound_listing_ids) > 0, ELEMENT_AT(inbound_listing_ids, 1), -1) AS listing_id,
    COALESCE(request__context__standard_endpoint_owner_id, -1) AS endpoint_owner_id,
    COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
    COALESCE(request__context__standard_programmer_id, -1) AS programmer_id,
    COALESCE(request__context__standard_brand_id, -1) AS brand_id,
    COALESCE(request__context__standard_channel_id, -1) AS channel_id,
    COALESCE(candidate__dsp_id, -1) AS dsp_id,
    COALESCE(candidate__internal_deal_id, -1) AS deal_id,
    CAST(ROUND(COALESCE(d.deal_floor_price, 0.0), 1) AS VARCHAR) AS deal_floor_price,
    CAST(ROUND(COALESCE(d.deal_floor_uplift, 0.0), 1) AS VARCHAR) AS deal_floor_uplift,
    CAST(ROUND(
      COALESCE(
        candidate__raw_price * candidate__candidate_network_to_auction_network_exchange_rate,
        0.0
      ),
      1
    ) AS VARCHAR) AS deal_bidding_price,
    CAST(ROUND(
      COALESCE(
        candidate__clearing_price * candidate__candidate_network_to_auction_network_exchange_rate,
        0.0
      ),
      1
    ) AS VARCHAR) AS deal_clearing_price,
    0 AS auction_request,
    0 AS auction_response_with_bids,
    0 AS auction_err_http_error,
    0 AS auction_err_timeout,
    0 AS auction_err_no_bids,
    0 AS auction_err_id_no_match,
    0 AS auction_err_empty_response,
    0 AS auction_err_malformed_response,
    0 AS bids_received,
    0 AS bids_resolved,
    0 AS bids_selected,
    0 AS bids_selected_primary,
    0 AS bids_selected_fallback,
    0 AS bids_err_no_deal,
    0 AS bids_err_no_ad,
    0 AS bids_err_no_seat,
    0 AS bids_err_no_vast,
    0 AS bids_err_wrapper_http_error,
    0 AS bids_err_wrapper_timeout,
    0 AS bids_err_ad_rejected,
    0 AS bids_err_exclusivity,
    0 AS bids_err_floor_price_not_met,
    0 AS bids_err_industry_restrict_by_deal,
    0 AS bids_err_industry_restrict_by_ni,
    0 AS bids_err_industry_restrict_by_listing,
    0 AS bids_err_industry_restrict_by_ip,
    0 AS bids_err_brand_related,
    0 AS bids_err_advertiser_related,
    0 AS bids_err_industry_related,
    0 AS bids_err_competition_failure,
    0 AS bids_err_profile_check_failed,
    SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS ack_ad_impression,
    SUM(
      COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000
    ) AS ack_ad_revenue
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(partners__network_id, partners__content_owner_network_id, partners__inbound_listing_id) AS t(nw_id, co_id, inbound_listing_ids)
  CROSS JOIN UNNEST(auction__impression__deals__internal_deal_id, auction__impression__deals__bid_floor, auction__impression__deals__bid_floor_uplift) AS imp(deal_ids, deal_floor_prices, deal_floor_uplifts)
  CROSS JOIN UNNEST(imp.deal_ids, imp.deal_floor_prices, imp.deal_floor_uplifts) AS d(deal_id, deal_floor_price, deal_floor_uplift)
  WHERE
    (
      t.nw_id = 523319 AND ack__ack_entity_type = 'ad'
    )
    AND candidate__internal_deal_id = d.deal_id
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
    17
) AS tmp
LEFT JOIN db.default.d_network AS nw
  ON nw.id = video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = distributor_network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = profile_id
LEFT JOIN db.default.d_network AS seller_nw
  ON seller_nw.id = tmp.seller_network_id
LEFT JOIN db.default.d_mkpl_listing AS listing
  ON listing.id = listing_id
LEFT JOIN db.default.d_lu_mkpl_endpoint_owner AS endpoint_owner
  ON endpoint_owner.id = endpoint_owner_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS endpoint
  ON endpoint.id = endpoint_id
LEFT JOIN db.default.d_lu_mkpl_standard_programmer AS programmer
  ON programmer.id = programmer_id
LEFT JOIN db.default.d_lu_mkpl_standard_brand AS brand
  ON brand.id = brand_id
LEFT JOIN db.default.d_lu_mkpl_standard_channel AS channel
  ON channel.id = channel_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = dsp_id
LEFT JOIN db.default.d_ssp_deal_metadata AS d_ssp_deal_metadata
  ON d_ssp_deal_metadata.id = tmp.deal_id
