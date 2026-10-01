-- account:    sa-dataapp-yield
-- skeleton:   7ec3ebc6b822437f72d860569a6cf9ae
-- pattern:    b573f73a829e4e0ea12a28d82c9b90f4  (697 execution(s))
-- in suite:   daily commitment
-- hoover:     candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  CASE
    WHEN candidate__integration_type = 'openrtb_pg_td'
    THEN 'fullstack_pg'
    WHEN candidate__integration_type = 'openrtb_normal'
    THEN 'fullstack_non_pg'
    WHEN candidate__integration_type = 'openrtb_sfx'
    THEN 'sfx_openrtb'
    WHEN candidate__integration_type = 'reseller_tag'
    AND candidate__external_network_id = 127719
    THEN 'sfx_tag'
    WHEN candidate__integration_type = 'reseller_tag'
    THEN 'ssp_others'
    WHEN candidate__integration_type = 'mkpl_partner_tag'
    THEN 'mkpl_partner_tag'
    ELSE 'na'
  END AS market_integration_type,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(candidate__buyer_platform_id, -1) AS buyer_platform_id,
  COALESCE(d_ssp_buyer_platform.name, 'na') AS buyer_platform,
  COALESCE(auction__buyer_platform_url_id, -1) AS buyer_platform_url_id,
  COALESCE(candidate__dsp_id, -1) AS dsp_id,
  COALESCE(d_dsp.name, 'na') AS dsp_name,
  COALESCE(auction__network_id, -1) AS auction_network_id,
  COALESCE(auc_network.name, 'na') AS auction_network_name,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(cro.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(dis.name, 'na') AS distributor_network_name,
  COALESCE(request__server_group, 'na') AS server_group,
  COALESCE(p.name, 'na') AS profile_name,
  CASE
    WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
    AND request__context__request_format = 1
    THEN 'sspu vast'
    WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
    AND request__context__request_format = 7
    THEN 'sspu ortb'
    WHEN BITWISE_AND(request__extra_flags3, 1) > 0
    THEN 'streaminghub openrtb'
    WHEN BITWISE_AND(request__extra_flags2, 8) > 0
    AND COALESCE(request__server_pool, 'na') = 'ads-sfx'
    THEN 'smi bidder'
    WHEN BITWISE_AND(request__extra_flags2, 8) > 0
    THEN 'mrm bidder'
    WHEN request__delivery_method = 'gateway'
    THEN 'linear - scheduled based'
    WHEN (
      BITWISE_AND(request__extra_flags, 1024) > 0
      AND BITWISE_AND(request__extra_flags, 16384) > 0
    )
    OR BITWISE_AND(request__extra_flags, 128) > 0
    THEN 'linear - gateway dai'
    WHEN (
      BITWISE_AND(request__extra_flags, 1024) > 0
      AND BITWISE_AND(request__extra_flags, 67108864) > 0
    )
    THEN 'linear - ip player'
    WHEN BITWISE_AND(request__extra_flags, 1024) > 0
    OR request__delivery_method = 'casucpsu'
    THEN 'linear - stb dai'
    WHEN visitor__user_agent_device_type = 'set top box'
    THEN 'stb vod'
    WHEN BITWISE_AND(request__flags, 8) > 0
    AND visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - live ott'
    WHEN BITWISE_AND(request__flags, 8) > 0
    AND NOT visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - live others'
    WHEN BITWISE_AND(request__flags, 8) = 0
    AND visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - non-live ott'
    WHEN BITWISE_AND(request__flags, 8) = 0
    AND NOT visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - non-live others'
    ELSE 'na'
  END AS service_type,
  COALESCE(visitor__user_agent_device_type, 'na') AS platform,
  COALESCE(auction__device_type, 'na') AS auction_device_type,
  CASE WHEN BITWISE_AND(request__flags, 64) = 0 THEN 'false' ELSE 'true' END AS is_filtered,
  COALESCE(visitor__country, 'unknown country') AS country,
  COALESCE(ctry.description, 'unknown country') AS country_name,
  COALESCE(request__context__video_cro_context_id, -1) AS video_cro_site_section_id,
  COALESCE(request__context__video_cro_site_id, -1) AS video_cro_site_id,
  COALESCE(request__context__site_section_id, -1) AS distributor_site_section_id,
  COALESCE(request__context__site_section_cro_site_id, -1) AS distributor_site_id,
  COALESCE(request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
  COALESCE(ep.name, 'na') AS standard_endpoint_name,
  SUM(IF(BITWISE_AND(candidate__bid_status, 1) > 0, 1, 0)) AS bids_received,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND COALESCE(candidate__error, '') <> '', 1, 0)
  ) AS received_err_error,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'malformed_response', 1, 0)
  ) AS received_err_malformed_response,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'empty_response', 1, 0)
  ) AS received_err_empty_response,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'wrapper_timeout', 1, 0)
  ) AS received_err_wrapper_timeout,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'wrapper_http_error', 1, 0)
  ) AS received_err_wrapper_http_error,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'no_valid_price', 1, 0)
  ) AS received_err_no_valid_price,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'no_valid_creative', 1, 0)
  ) AS received_err_no_valid_creative,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'floor_price_notmet', 1, 0)
  ) AS received_err_floor_price_not_met,
  SUM(IF(candidate__bid_status IN (1, 5) AND candidate__error = 'no_ad_markup', 1, 0)) AS received_err_no_ad_markup,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'unexpected_bid_dealid', 1, 0)
  ) AS received_err_unexpected_bid_dealid,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'empty_bid_dealid', 1, 0)
  ) AS received_err_empty_bid_dealid,
  SUM(
    IF(
      candidate__bid_status IN (1, 5) AND candidate__error = 'inapplicable_for_https',
      1,
      0
    )
  ) AS received_err_inapplicable_for_https,
  SUM(IF(candidate__bid_status IN (1, 5) AND candidate__error = 'timeout', 1, 0)) AS received_err_timeout,
  SUM(IF(candidate__bid_status IN (1, 5) AND candidate__error = 'unknown_seat', 1, 0)) AS received_err_unknown_seat,
  SUM(IF(BITWISE_AND(candidate__bid_status, 2) > 0, 1, 0)) AS bids_resolved,
  SUM(
    IF(candidate__bid_status IN (3, 7) AND COALESCE(candidate__error, '') <> '', 1, 0)
  ) AS resolved_err_error,
  SUM(
    IF(candidate__bid_status IN (3, 7) AND candidate__error = 'profile_check_failed', 1, 0)
  ) AS resolved_err_profile_check_failed,
  SUM(
    IF(
      candidate__bid_status IN (3, 7) AND candidate__error = 'compliance_check_failed',
      1,
      0
    )
  ) AS resolved_err_compliance_check_failed,
  SUM(
    IF(
      candidate__bid_status IN (3, 7) AND candidate__error = 'no_applicable_creative',
      1,
      0
    )
  ) AS resolved_err_flash_not_supported_by_browser,
  SUM(
    IF(
      candidate__bid_status IN (3, 7) AND candidate__error = 'exclusivity_check_failed',
      1,
      0
    )
  ) AS resolved_err_exclusivity_check_failed,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__rtb_auction_index IS NULL
      AND candidate__integration_type = 'openrtb_pg_td',
      1,
      0
    )
  ) AS resolved_err_failed_before_biding,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'generate_impression_failed',
      1,
      0
    )
  ) AS resolved_err_generate_impression_failed,
  SUM(
    IF(candidate__bid_status IN (3, 7) AND candidate__error = 'competition_failure', 1, 0)
  ) AS resolved_err_competition_failure,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'external_creative_profile_check_failed',
      1,
      0
    )
  ) AS resolved_err_external_creative_profile_check_failed,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'advertiser_restricted_by_rule',
      1,
      0
    )
  ) AS resolved_err_advertiser_restricted_by_rule,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'auction_max_ad_duration_exceeded',
      1,
      0
    )
  ) AS resolved_err_auction_max_ad_duration_exceeded,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'no_brand_for_inventory_protection',
      1,
      0
    )
  ) AS resolved_err_no_brand_for_inventory_protection,
  SUM(
    IF(
      candidate__bid_status IN (3, 7) AND candidate__error = 'compliance_not_approved',
      1,
      0
    )
  ) AS resolved_err_compliance_not_approved,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'rule_compliance_check_failed',
      1,
      0
    )
  ) AS resolved_err_rule_compliance_check_failed,
  SUM(
    IF(candidate__bid_status IN (3, 7) AND candidate__error = 'floor_price_notmet', 1, 0)
  ) AS resolved_err_floor_price_notmet,
  SUM(
    IF(
      candidate__bid_status IN (3, 7) AND candidate__error = 'brand_restricted_by_rule',
      1,
      0
    )
  ) AS resolved_err_brand_restricted_by_rule,
  SUM(
    IF(
      candidate__bid_status IN (3, 7) AND candidate__error = 'ad_targeting_restricted',
      1,
      0
    )
  ) AS resolved_err_ad_targeting_restricted,
  SUM(
    IF(candidate__bid_status IN (3, 7) AND candidate__error = 'exclusivity_by_stream', 1, 0)
  ) AS resolved_err_exclusivity_by_stream,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'reseller_whitelist_not_allowed',
      1,
      0
    )
  ) AS resolved_err_reseller_whitelist_not_allowed,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'not_allowed_upstream_network_for_rule',
      1,
      0
    )
  ) AS resolved_err_not_allowed_upstream_network_for_rule,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'no_advertiser_for_inventory_protection',
      1,
      0
    )
  ) AS resolved_err_no_advertiser_for_inventory_protection,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'invalid_compliance_for_inventory_protection',
      1,
      0
    )
  ) AS resolved_err_invalid_compliance_for_inventory_protection,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'listing_industry_restriction',
      1,
      0
    )
  ) AS resolved_err_listing_industry_restriction,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'listing_creative_duration_check',
      1,
      0
    )
  ) AS resolved_err_listing_creative_duration_check_failed,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'pending_approval_by_distributor',
      1,
      0
    )
  ) AS resolved_err_pending_approval_by_distributor,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'not_approved_by_distributor',
      1,
      0
    )
  ) AS resolved_err_not_approved_by_distributor,
  SUM(IF(BITWISE_AND(candidate__bid_status, 8) > 0, 1, 0)) AS delivered_market_ad
FROM ${bcv_candidate}
LEFT JOIN db.default.d_ssp_demand_side_platform AS d_dsp
  ON d_dsp.id = candidate__dsp_id
LEFT JOIN db.default.d_ssp_buyer_platform
  ON d_ssp_buyer_platform.id = candidate__buyer_platform_id
LEFT JOIN db.default.d_network AS cand_network
  ON candidate__network_id = cand_network.id
LEFT JOIN db.default.d_network AS auc_network
  ON auction__network_id = auc_network.id
LEFT JOIN db.default.d_network AS cro
  ON cro.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS dis
  ON dis.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = visitor__country_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS ep
  ON ep.id = request__context__standard_endpoint_id
WHERE
  candidate__integration_type IN (
    'openrtb_normal',
    'openrtb_pg_td',
    'openrtb_sfx',
    'reseller_tag',
    'mkpl_partner_tag'
  )
  AND BITWISE_AND(auction__flags, 8) = 0
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
  28
