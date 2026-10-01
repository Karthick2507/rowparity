-- account:    sa-dataapp-yield
-- skeleton:   cfbb30fe602383d19af76053dbc4af12
-- pattern:    51e03a2d6e8966f60ed5cc4a27388e68  (697 execution(s))
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
  COALESCE(candidate__network_id, -1) AS candidate_network_id,
  COALESCE(cand_network.name, 'na') AS candidate_network_name,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(cro.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(dis.name, 'na') AS distributor_network_name,
  IF(
    auction__network_id = 523319
    AND CONTAINS(partners__entity_source, 'auction_upstream'),
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
    -1
  ) AS auction_upstream_network_id,
  COALESCE(auc_upstream.name, 'na') AS auction_upstream_network_name,
  COALESCE(request__server_group, 'na') AS server_group,
  COALESCE(request__server_pool, 'na') AS server_pool,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(auction__device_type, 'na') AS auction_device_type,
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
  CASE
    WHEN STRPOS(auction__time_position_class, 'preroll') > 0
    THEN 'preroll'
    WHEN STRPOS(auction__time_position_class, 'pause_midroll') > 0
    THEN 'pause'
    WHEN STRPOS(auction__time_position_class, 'midroll') > 0
    THEN 'midroll'
    WHEN STRPOS(auction__time_position_class, 'postroll') > 0
    THEN 'postroll'
    WHEN STRPOS(auction__time_position_class, 'overlay') > 0
    THEN 'overlay'
    WHEN STRPOS(auction__time_position_class, 'display') > 0
    THEN 'display'
    ELSE 'na'
  END AS ad_unit_type,
  CASE WHEN (
    NOT visitor__cookie_user_id IS NULL
  ) THEN 'true' ELSE 'false' END AS has_cookie_id,
  CASE WHEN BITWISE_AND(request__flags, 64) = 0 THEN 'false' ELSE 'true' END AS is_filtered,
  -1 AS video_cro_site_section_id,
  -1 AS auction_site_section_id,
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
  SUM(
    IF(
      candidate__bid_status IN (1, 5)
      AND candidate__error = 'bid_impression_id_nomatch',
      1,
      0
    )
  ) AS received_err_bid_impression_id_nomatch,
  SUM(IF(candidate__bid_status IN (1, 5) AND candidate__error = 'empty_bid_id', 1, 0)) AS received_err_empty_bid_id,
  SUM(
    IF(
      candidate__bid_status IN (1, 5)
      AND candidate__error = 'bid_impression_id_nomatch',
      1,
      0
    )
  ) AS received_err_bid_imp_id_nomatch,
  SUM(
    IF(
      candidate__bid_status IN (1, 5) AND candidate__error = 'no_valid_external_ad_id',
      1,
      0
    )
  ) AS received_err_no_valid_external_ad_id,
  SUM(
    IF(
      candidate__bid_status IN (1, 5)
      AND candidate__error = 'unexpected_external_ad_id',
      1,
      0
    )
  ) AS received_err_unexpected_external_ad_id,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'no_valid_currency', 1, 0)
  ) AS received_err_no_valid_currency,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'invalid_wrapper_url', 1, 0)
  ) AS received_err_invalid_wrapper_url,
  SUM(
    IF(
      candidate__bid_status IN (1, 5) AND candidate__error = 'unsupported_vast_version',
      1,
      0
    )
  ) AS received_err_unsupported_vast_version,
  SUM(
    IF(
      candidate__bid_status IN (1, 5)
      AND candidate__error = 'client_rendition_required',
      1,
      0
    )
  ) AS received_err_client_rendition_required,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'competition_failure', 1, 0)
  ) AS received_err_competition_failure,
  SUM(
    IF(
      candidate__bid_status IN (1, 5) AND candidate__error = 'jitt_rendition_required',
      1,
      0
    )
  ) AS received_err_jitt_rendition_required,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'no_slot_selected', 1, 0)
  ) AS received_err_no_slot_selected,
  SUM(
    IF(candidate__bid_status IN (1, 5) AND candidate__error = 'profile_check_failed', 1, 0)
  ) AS received_err_profile_check_failed,
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
  SUM(IF(BITWISE_AND(candidate__flags, 32768) > 0, 1, 0)) AS resolved_err_failed_before_biding,
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
      AND candidate__error = 'listing_advertiser_restriction',
      1,
      0
    )
  ) AS resolved_err_listing_advertiser_restriction,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'listing_brand_restriction',
      1,
      0
    )
  ) AS resolved_err_listing_brand_restriction,
  SUM(
    IF(candidate__bid_status IN (3, 7) AND candidate__error = 'ad_pending_approval', 1, 0)
  ) AS resolved_err_ad_pending_approval,
  SUM(
    IF(
      candidate__bid_status IN (3, 7) AND candidate__error = 'jitt_rendition_required',
      1,
      0
    )
  ) AS resolved_err_jitt_rendition_required,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'client_rendition_required',
      1,
      0
    )
  ) AS resolved_err_client_rendition_required,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'brand_frequency_cap_reached',
      1,
      0
    )
  ) AS resolved_err_brand_frequency_cap_reached,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'mkpl_order_floor_price_not_met',
      1,
      0
    )
  ) AS resolved_err_mkpl_order_floor_price_not_met,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'restricted_seat_by_mkpl_exchange',
      1,
      0
    )
  ) AS resolved_err_restricted_seat_by_mkpl_exchange,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'mkpl_exchange_seat_floor_price_not_met',
      1,
      0
    )
  ) AS resolved_err_mkpl_exchange_seat_floor_price_not_met,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'mkpl_exchange_industry_floor_price_not_met',
      1,
      0
    )
  ) AS resolved_err_mkpl_exchange_industry_floor_price_not_met,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'mkpl_exchange_brand_floor_price_not_met',
      1,
      0
    )
  ) AS resolved_err_mkpl_exchange_brand_floor_price_not_met,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'mkpl_exchange_advertiser_floor_price_not_met',
      1,
      0
    )
  ) AS resolved_err_mkpl_exchange_advertiser_floor_price_not_met,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'global_brand_restricted_by_listing',
      1,
      0
    )
  ) AS resolved_err_global_brand_restricted_by_listing,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'global_brand_restricted_by_deal',
      1,
      0
    )
  ) AS resolved_err_global_brand_restricted_by_deal,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'industry_restricted_by_listing',
      1,
      0
    )
  ) AS resolved_err_industry_restricted_by_listing,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'industry_restricted_by_deal',
      1,
      0
    )
  ) AS resolved_err_industry_restricted_by_deal,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'creative_restriction_check_failed',
      1,
      0
    )
  ) AS resolved_err_creative_restriction_check_failed,
  SUM(
    IF(candidate__bid_status IN (3, 7) AND candidate__error = 'frequency_cap_reached', 1, 0)
  ) AS resolved_err_frequency_cap_reached,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'global_advertiser_restricted_by_deal',
      1,
      0
    )
  ) AS resolved_err_global_advertiser_restricted_by_deal,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'global_advertiser_restricted_by_inventory',
      1,
      0
    )
  ) AS resolved_err_global_advertiser_restricted_by_inventory,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'global_advertiser_restricted_by_listing',
      1,
      0
    )
  ) AS resolved_err_global_advertiser_restricted_by_listing,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'global_brand_restricted_by_inventory',
      1,
      0
    )
  ) AS resolved_err_global_brand_restricted_by_inventory,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'inbound_rule_targeting_not_met',
      1,
      0
    )
  ) AS resolved_err_inbound_rule_targeting_not_met,
  SUM(
    IF(candidate__bid_status IN (3, 7) AND candidate__error = 'no_slot_selected', 1, 0)
  ) AS resolved_err_no_slot_selected,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'reseller_blacklist_banned',
      1,
      0
    )
  ) AS resolved_err_reseller_blacklist_banned,
  SUM(
    IF(
      candidate__bid_status IN (3, 7)
      AND candidate__error = 'mismatched_creative_duration_with_scheduled',
      1,
      0
    )
  ) AS resolved_err_mismatched_creative_duration_with_scheduled,
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
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'ad_pending_approval',
      1,
      0
    )
  ) AS pre_filtered_ad_pending_approval,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'ad_targeting_restricted',
      1,
      0
    )
  ) AS pre_filtered_ad_targeting_restricted,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'no_advertiser_for_inventory_protection',
      1,
      0
    )
  ) AS pre_filtered_no_advertiser_for_inventory_protection,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'blocked_by_inventory_source_optimization',
      1,
      0
    )
  ) AS pre_filtered_blocked_by_inventory_source_opt,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'blocked_by_inventory_source_optimization_imr',
      1,
      0
    )
  ) AS pre_filtered_blocked_by_inventory_source_opt_imr,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'brand_frequency_cap_reached',
      1,
      0
    )
  ) AS pre_filtered_brand_frequency_cap_reached,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'competition_failure',
      1,
      0
    )
  ) AS pre_filtered_competition_failure,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'compliance_check_failed',
      1,
      0
    )
  ) AS pre_filtered_compliance_check_failed,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'compliance_not_approved',
      1,
      0
    )
  ) AS pre_filtered_compliance_not_approved,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'creative_restriction_check_failed',
      1,
      0
    )
  ) AS pre_filtered_creative_restriction_check_failed,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'exclusivity_by_stream',
      1,
      0
    )
  ) AS pre_filtered_exclusivity_by_stream,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'frequency_cap_reached',
      1,
      0
    )
  ) AS pre_filtered_frequency_cap_reached,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'global_advertiser_restricted_by_deal',
      1,
      0
    )
  ) AS pre_filtered_global_advertiser_restricted_by_deal,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'no_brand_for_inventory_protection',
      1,
      0
    )
  ) AS pre_filtered_no_brand_for_inventory_protection,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'no_slot_selected',
      1,
      0
    )
  ) AS pre_filtered_no_slot_selected,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'profile_check_failed',
      1,
      0
    )
  ) AS pre_filtered_profile_check_failed,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'reseller_blacklist_banned',
      1,
      0
    )
  ) AS pre_filtered_reseller_restriction_blacklist_banned,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'reseller_whitelist_not_allowed',
      1,
      0
    )
  ) AS pre_filtered_reseller_restriction_whitelist_not_allowed,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'ccpa_unsupported',
      1,
      0
    )
  ) AS pre_filtered_ccpa_unsupported,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'gdpr_unsupported',
      1,
      0
    )
  ) AS pre_filtered_gdpr_unsupported,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0 AND candidate__error = 'lat_unsupported',
      1,
      0
    )
  ) AS pre_filtered_lat_unsupported,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'coppa_unsupported',
      1,
      0
    )
  ) AS pre_filtered_coppa_unsupported,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'atts_unsupported',
      1,
      0
    )
  ) AS pre_filtered_atts_unsupported,
  SUM(
    IF(BITWISE_AND(candidate__flags, 32768) > 0 AND candidate__error = 'kv_opt_out', 1, 0)
  ) AS pre_filtered_kn_opt_out,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'dsp_status_inactive',
      1,
      0
    )
  ) AS pre_filtered_dsp_status_inactive,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'dsp_status_pause',
      1,
      0
    )
  ) AS pre_filtered_dsp_status_pause,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'dsp_status_complete',
      1,
      0
    )
  ) AS pre_filtered_dsp_status_complete,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'dsp_status_unknown',
      1,
      0
    )
  ) AS pre_filtered_dsp_status_unknown,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'blocked_by_bid_throttling',
      1,
      0
    )
  ) AS pre_filtered_blocked_by_bid_throttling,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'global_advertiser_restricted_by_inventory',
      1,
      0
    )
  ) AS pre_filtered_global_advertiser_restricted_by_inventory,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'global_brand_restricted_by_inventory',
      1,
      0
    )
  ) AS pre_filtered_global_brand_restricted_by_inventory,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'industry_restricted_by_listing',
      1,
      0
    )
  ) AS pre_filtered_industry_restricted_by_listing,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'invalid_compliance_for_inventory_protection',
      1,
      0
    )
  ) AS pre_filtered_invalid_compliance_for_inventory_protection,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'mismatched_creative_duration_with_scheduled',
      1,
      0
    )
  ) AS pre_filtered_mismatched_creative_duration_with_scheduled,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'pending_approval_by_distributor',
      1,
      0
    )
  ) AS pre_filtered_pending_approval_by_distributor,
  SUM(
    IF(
      BITWISE_AND(candidate__flags, 32768) > 0
      AND candidate__error = 'not_approved_by_distributor',
      1,
      0
    )
  ) AS pre_filtered_not_approved_by_distributor,
  SUM(IF(BITWISE_AND(candidate__bid_status, 8) > 0, 1, 0)) AS delivered_market_ad,
  SUM(
    IF(
      BITWISE_AND(candidate__bid_status, 8) > 0
      AND BITWISE_AND(advertisement__flags, 32) = 0,
      1,
      0
    )
  ) AS delivered_market_ad_primary,
  SUM(
    IF(
      BITWISE_AND(candidate__bid_status, 8) > 0
      AND BITWISE_AND(advertisement__flags, 32) > 0,
      1,
      0
    )
  ) AS delivered_market_ad_fallback
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
LEFT JOIN db.default.d_network AS auc_upstream
  ON auc_upstream.id = IF(
    auction__network_id = 523319
    AND CONTAINS(partners__entity_source, 'auction_upstream'),
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
    -1
  )
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
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
  28,
  29
