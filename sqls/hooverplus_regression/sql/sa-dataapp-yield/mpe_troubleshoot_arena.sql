-- account:    sa-dataapp-yield
-- skeleton:   a952adb828d316bceee745643a4985b6
-- pattern:    ffa51d2bb720b35d8de79af5610bd0a4  (2 execution(s))
-- in suite:   column coverage
-- hoover:     candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   c.request__timestamp < CAST(? AS TIMESTAMP)
--   c.request__timestamp >= CAST(? AS TIMESTAMP)
--   dt < DATE_FORMAT(CAST(? AS TIMESTAMP) + INTERVAL ? HOUR, ?)
--   dt >= DATE_FORMAT(CAST(? AS TIMESTAMP) - INTERVAL ? HOUR, ?)
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  REDUCE(SET_AGG(process_stage), 0, (acc, val) -> acc + val, val -> val) AS process_stage,
  event_date AS timestamp,
  process_batch_id,
  process_batch_id AS partition_key,
  f.network_id,
  COALESCE(nw.name, 'na') AS network_name,
  f.content_owner_id,
  COALESCE(co.name, 'na') AS content_owner_name,
  f.content_owner_visibility,
  f.distributor_id,
  COALESCE(dist.name, 'na') AS distributor_name,
  f.transaction_type,
  f.reseller_id,
  COALESCE(reseller.name, 'na') AS reseller_name,
  f.reseller_visibility,
  f.reseller_network_type,
  f.supply_source,
  f.sales_channel,
  f.sales_strategy,
  f.site_id,
  COALESCE(site.name, 'na') AS site_name,
  f.site_section_id,
  COALESCE(section.name, 'na') AS site_section_name,
  f.standard_publisher_id,
  COALESCE(publisher.name, 'na') AS standard_publisher_name,
  f.standard_brand_id,
  COALESCE(brand.name, 'na') AS standard_brand_name,
  f.standard_brand_visibility,
  f.standard_programmer_id,
  COALESCE(programmer.name, 'na') AS standard_programmer_name,
  f.standard_programmer_visibility,
  f.content_form_id,
  COALESCE(content_form.name, 'na') AS content_form_name,
  f.stream_mode_id,
  COALESCE(stream.name, 'na') AS stream_mode_name,
  f.standard_endpoint_owner_id,
  COALESCE(endpoint_owner.name, 'na') AS standard_endpoint_owner_name,
  f.standard_endpoint_owner_visibility,
  f.standard_endpoint_id,
  COALESCE(endpoint.name, 'na') AS standard_endpoint_name,
  f.standard_endpoint_visibility,
  f.user_country_id,
  COALESCE(country.name, 'na') AS user_country_name,
  f.geo_country_visibility,
  f.standard_device_type_id,
  f.user_agent_visibility,
  f.profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  f.profile_type,
  f.live_linear_indicator,
  f.ssp_bidder_indicator,
  f.partner_tag_indicator,
  f.time_position_classes,
  f.slot_ad_unit_ids AS slot_ad_unit_ids,
  f.slot_sequence_normalized,
  f.slot_user_drop_off,
  f.slot_removed_by_ux_indicator,
  f.request_traffic_type,
  f.ack_traffic_type,
  f.outbound_listing_id AS outbound_exchange_listing_ids,
  f.global_advertiser_ids,
  f.global_brand_ids,
  f.local_advertiser_id,
  f.global_industry_ids,
  f.primary_ad_indicator,
  f.demand_type,
  SUM(candidate_ads) AS candidate_ads,
  SUM(tx_eligible_ads) AS tx_eligible_ads,
  SUM(slot_eligible_ads) AS slot_eligible_ads,
  SUM(placed_ads_sampled) AS placed_ads_sampled,
  SUM(placed_fallback_ads_sampled) AS placed_fallback_ads_sampled,
  SUM(filled_ads_sstf_fallback_sampled) AS filled_ads_sstf_fallback_sampled,
  SUM(selected_ads_sampled) AS selected_ads_sampled,
  SUM(gross_ad_views_sampled) AS gross_ad_views_sampled,
  SUM(placement_err_total) AS placement_err_total,
  SUM(ad_err_total) AS ad_err_total,
  SUM(slot_err_total) AS slot_err_total,
  SUM(tx_err_malformed_response) AS tx_err_malformed_response,
  SUM(tx_err_empty_response) AS tx_err_empty_response,
  SUM(tx_err_price_hurdle_check_failed) AS tx_err_price_hurdle_check_failed,
  SUM(tx_err_profile_check_failed) AS tx_err_profile_check_failed,
  SUM(tx_err_frequency_cap_failed) AS tx_err_frequency_cap_failed,
  SUM(tx_err_not_allowed_upstream_network_for_ad) AS tx_err_not_allowed_upstream_network_for_ad,
  SUM(tx_err_reseller_whitelist_not_allowed) AS tx_err_reseller_whitelist_not_allowed,
  SUM(tx_err_reseller_blacklist_banned) AS tx_err_reseller_blacklist_banned,
  SUM(tx_err_no_applicable_slot) AS tx_err_no_applicable_slot,
  SUM(tx_err_no_applicable_creative) AS tx_err_no_applicable_creative,
  SUM(tx_err_exceed_max_slot_duration) AS tx_err_exceed_max_slot_duration,
  SUM(tx_err_competition_failure) AS tx_err_competition_failure,
  SUM(tx_err_exclusivity_by_stream) AS tx_err_exclusivity_by_stream,
  SUM(tx_err_creative_restriction_check_failed) AS tx_err_creative_restriction_check_failed,
  SUM(tx_err_ad_targeting_restricted) AS tx_err_ad_targeting_restricted,
  SUM(tx_err_budget_met) AS tx_err_budget_met,
  SUM(tx_err_listing_creative_duration_check) AS tx_err_listing_creative_duration_check,
  SUM(tx_err_advertiser_industry_restriction) AS tx_err_advertiser_industry_restriction,
  SUM(tx_err_brand_blacklist_restriction) AS tx_err_brand_blacklist_restriction,
  SUM(tx_err_advertiser_blacklist_restriction) AS tx_err_advertiser_blacklist_restriction,
  SUM(tx_err_schedule_met) AS tx_err_schedule_met,
  SUM(tx_err_slot_compatiblity_check) AS tx_err_slot_compatiblity_check,
  SUM(tx_err_rating_restriction) AS tx_err_rating_restriction,
  SUM(tx_err_global_brand_restricted_by_inventory) AS tx_err_global_brand_restricted_by_inventory,
  SUM(tx_err_global_advertiser_restricted_by_inventory) AS tx_err_global_advertiser_restricted_by_inventory,
  SUM(tx_err_blocked_by_inventory_source_optimization_imr) AS tx_err_blocked_by_inventory_source_optimization_imr,
  SUM(tx_err_inbound_rule_targeting_not_met) AS tx_err_inbound_rule_targeting_not_met,
  SUM(tx_err_inbound_rule_explicit_targeting_required) AS tx_err_inbound_rule_explicit_targeting_required,
  SUM(tx_err_global_brand_restricted_by_listing) AS tx_err_global_brand_restricted_by_listing,
  SUM(tx_err_low_ranking_in_buyer) AS tx_err_low_ranking_in_buyer,
  SUM(tx_err_industry_restricted_by_listing) AS tx_err_industry_restricted_by_listing,
  SUM(tx_err_wrapper_timeout) AS tx_err_wrapper_timeout,
  SUM(tx_err_wrapper_http_error) AS tx_err_wrapper_http_error,
  SUM(tx_err_no_valid_creative) AS tx_err_no_valid_creative,
  SUM(tx_err_unsupported_vast_version) AS tx_err_unsupported_vast_version,
  SUM(tx_err_floor_price_notmet) AS tx_err_floor_price_notmet,
  SUM(tx_err_targeted_schedule_met) AS tx_err_targeted_schedule_met,
  SUM(tx_err_targeted_budget_met) AS tx_err_targeted_budget_met,
  SUM(tx_err_yield_opt_met) AS tx_err_yield_opt_met,
  SUM(tx_err_inflight_bid_met) AS tx_err_inflight_bid_met,
  SUM(tx_err_inbound_order_competition_failure) AS tx_err_inbound_order_competition_failure,
  SUM(tx_err_competition_failure_in_pick_many) AS tx_err_competition_failure_in_pick_many,
  SUM(tx_err_find_rule_path_failure) AS tx_err_find_rule_path_failure,
  SUM(tx_err_global_advertiser_restricted_by_listing) AS tx_err_global_advertiser_restricted_by_listing,
  SUM(tx_err_no_slot_selected) AS tx_err_no_slot_selected,
  SUM(tx_err_no_advertiser_for_inventory_protection) AS tx_err_no_advertiser_for_inventory_protection,
  SUM(tx_err_ad_pending_approval) AS tx_err_ad_pending_approval,
  SUM(tx_err_jitt_rendition_required) AS tx_err_jitt_rendition_required,
  SUM(tx_err_industry_restricted_by_deal) AS tx_err_industry_restricted_by_deal,
  SUM(tx_err_invalid_compliance_for_inventory_protection) AS tx_err_invalid_compliance_for_inventory_protection,
  SUM(tx_err_auction_max_ad_duration_exceeded) AS tx_err_auction_max_ad_duration_exceeded,
  SUM(tx_err_compliance_not_approved) AS tx_err_compliance_not_approved,
  SUM(tx_err_global_brand_restricted_by_deal) AS tx_err_global_brand_restricted_by_deal,
  SUM(tx_err_frequency_cap_reached) AS tx_err_frequency_cap_reached,
  SUM(tx_err_mkpl_order_floor_price_not_met) AS tx_err_mkpl_order_floor_price_not_met,
  SUM(tx_err_brand_restricted_by_rule) AS tx_err_brand_restricted_by_rule,
  SUM(tx_err_mkpl_exchange_industry_floor_price_not_met) AS tx_err_mkpl_exchange_industry_floor_price_not_met,
  SUM(tx_err_no_brand_for_inventory_protection) AS tx_err_no_brand_for_inventory_protection,
  SUM(tx_err_compliance_check_failed) AS tx_err_compliance_check_failed,
  SUM(tx_err_global_advertiser_restricted_by_deal) AS tx_err_global_advertiser_restricted_by_deal,
  SUM(tx_err_rule_compliance_check_failed) AS tx_err_rule_compliance_check_failed,
  SUM(tx_err_kv_opt_out) AS tx_err_kv_opt_out,
  SUM(tx_err_timeout) AS tx_err_timeout,
  SUM(tx_err_generate_impression_failed) AS tx_err_generate_impression_failed,
  SUM(tx_err_coppa_unsupported) AS tx_err_coppa_unsupported,
  SUM(tx_err_http_error) AS tx_err_http_error,
  SUM(tx_err_blocked_by_bid_throttling) AS tx_err_blocked_by_bid_throttling,
  SUM(tx_err_us_privacy_unsupported) AS tx_err_us_privacy_unsupported,
  SUM(tx_err_dsp_status_pause) AS tx_err_dsp_status_pause,
  SUM(tx_err_blocked_by_traffic_control) AS tx_err_blocked_by_traffic_control,
  SUM(tx_err_lat_unsupported) AS tx_err_lat_unsupported,
  SUM(tx_err_no_bids) AS tx_err_no_bids,
  SUM(tx_err_blocked_by_inventory_source_optimization) AS tx_err_blocked_by_inventory_source_optimization,
  SUM(tx_err_dsp_status_inactive) AS tx_err_dsp_status_inactive,
  SUM(tx_err_candidate_no_bids) AS tx_err_candidate_no_bids,
  SUM(tx_err_gdpr_unsupported) AS tx_err_gdpr_unsupported,
  SUM(tx_err_exceed_server_concurrent_limit) AS tx_err_exceed_server_concurrent_limit,
  SUM(tx_err_no_valid_market_ad) AS tx_err_no_valid_market_ad,
  SUM(tx_err_unexpected_bid_dealid) AS tx_err_unexpected_bid_dealid,
  SUM(tx_err_unknown_seat) AS tx_err_unknown_seat,
  SUM(tx_err_invalid_wrapper_url) AS tx_err_invalid_wrapper_url,
  SUM(tx_err_empty_bid_dealid) AS tx_err_empty_bid_dealid,
  SUM(tx_err_no_ad_markup) AS tx_err_no_ad_markup,
  SUM(tx_err_inapplicable_for_https) AS tx_err_inapplicable_for_https,
  SUM(tx_err_unexpected_external_ad_id) AS tx_err_unexpected_external_ad_id,
  SUM(tx_err_restricted_seat_by_auction_network) AS tx_err_restricted_seat_by_auction_network,
  SUM(tx_err_no_valid_price) AS tx_err_no_valid_price,
  SUM(tx_err_no_valid_external_ad_id) AS tx_err_no_valid_external_ad_id,
  SUM(tx_err_mismatched_creative_duration_with_scheduled) AS tx_err_mismatched_creative_duration_with_scheduled,
  SUM(slot_err_exceed_max_slot_duration) AS slot_err_exceed_max_slot_duration,
  SUM(slot_err_exceed_max_num_advertisements) AS slot_err_exceed_max_num_advertisements,
  SUM(slot_err_adjacent_exclusivity) AS slot_err_adjacent_exclusivity,
  SUM(slot_err_back2back_excluded) AS slot_err_back2back_excluded,
  SUM(slot_err_industry_separation_excluded) AS slot_err_industry_separation_excluded,
  SUM(slot_err_exclusivity_by_slot) AS slot_err_exclusivity_by_slot,
  SUM(slot_err_adjacent_same_4a_id) AS slot_err_adjacent_same_4a_id,
  SUM(slot_err_incompatible_rendition_file_size) AS slot_err_incompatible_rendition_file_size,
  SUM(slot_err_estimate_rendition_duration_for_live) AS slot_err_estimate_rendition_duration_for_live,
  SUM(slot_err_large_rendition_duration) AS slot_err_large_rendition_duration,
  SUM(slot_err_creative_api_banned) AS slot_err_creative_api_banned,
  SUM(slot_err_no_applicable_profiles_for_rendition) AS slot_err_no_applicable_profiles_for_rendition,
  SUM(slot_err_brand_separation_excluded) AS slot_err_brand_separation_excluded,
  SUM(slot_err_advertiser_separation_excluded) AS slot_err_advertiser_separation_excluded,
  SUM(slot_err_frequency_cap_reaching) AS slot_err_frequency_cap_reaching,
  SUM(slot_err_slot_filled_by_multi_ads) AS slot_err_slot_filled_by_multi_ads,
  SUM(slot_err_position_occupied) AS slot_err_position_occupied,
  SUM(slot_err_brand_frequency_cap_reaching) AS slot_err_brand_frequency_cap_reaching,
  SUM(slot_err_swapped_out_of_slot) AS slot_err_swapped_out_of_slot,
  SUM(slot_err_ad_asset_store_inapplicable_bitrate) AS slot_err_ad_asset_store_inapplicable_bitrate,
  SUM(slot_err_ad_asset_store_not_available) AS slot_err_ad_asset_store_not_available,
  SUM(slot_err_advertiser_frequency_cap_reaching) AS slot_err_advertiser_frequency_cap_reaching,
  SUM(slot_err_clearcast_code_restricted) AS slot_err_clearcast_code_restricted,
  SUM(slot_err_from_same_header_bidding) AS slot_err_from_same_header_bidding,
  SUM(slot_err_incompatible_flash_version) AS slot_err_incompatible_flash_version,
  SUM(slot_err_low_ranking_in_buyer) AS slot_err_low_ranking_in_buyer,
  SUM(slot_err_no_error) AS slot_err_no_error,
  SUM(slot_err_restricted_by_openrtb_impression_bid_capping) AS slot_err_restricted_by_openrtb_impression_bid_capping
FROM (
  SELECT
    CAST(1 AS INTEGER) AS process_stage,
    DATE_FORMAT(FROM_UNIXTIME(timestamp), '%y-%m-%d %h:00:00') AS event_date,
    DATE_FORMAT(DATE_PARSE(dt, '%y-%m-%d-%h'), '%y%m%d%h0000') AS process_batch_id,
    COALESCE(upstream_network.network_id, -1) AS network_id,
    COALESCE(upstream_network.upstream_network_id, -1) AS content_owner_id,
    'full_visibility' AS content_owner_visibility,
    IF(
      COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.distributor_network_id, -1),
      -1
    ) AS distributor_id,
    CASE
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated'
      AND upstream_network.network_id = request.video_cro_network_id
      THEN 'cro'
      ELSE 'r'
    END AS transaction_type,
    COALESCE(t.external_network_id, COALESCE(network.network_id, -1)) AS reseller_id,
    'full_visibility' AS reseller_visibility,
    IF(COALESCE(t.external_network_id, -1) = -1, 'full', 'internal') AS reseller_network_type,
    CASE
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated'
      THEN 1
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'mrm_rule'
      THEN 3
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'mpp'
      THEN 5
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'mpe'
      THEN 6
      ELSE -1
    END AS supply_source,
    'marketplace platform exchange' AS sales_channel,
    'marketplace platform exchange' AS sales_strategy,
    IF(
      COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_id, -1),
      -1
    ) AS site_id,
    IF(
      COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_section_id, -1),
      -1
    ) AS site_section_id,
    COALESCE(request.standard_publisher_id, -1) AS standard_publisher_id,
    IF(
      NOT upstream_network.data_right.standard_brand_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_brand_id, -1),
      -1
    ) AS standard_brand_id,
    COALESCE(
      upstream_network.data_right.standard_brand_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_brand_visibility,
    IF(
      NOT upstream_network.data_right.standard_programmer_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_programmer_id, -1),
      -1
    ) AS standard_programmer_id,
    COALESCE(
      upstream_network.data_right.standard_programmer_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_programmer_visibility,
    IF(
      upstream_network.supply_source_type <> 'mrm_rule',
      -1,
      COALESCE(request.content_form_id, -1)
    ) AS content_form_id,
    COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), -1) AS stream_mode_id,
    IF(
      NOT upstream_network.data_right.standard_endpoint_owner_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_endpoint_owner_id, -1),
      -1
    ) AS standard_endpoint_owner_id,
    COALESCE(
      upstream_network.data_right.standard_endpoint_owner_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_endpoint_owner_visibility,
    IF(
      NOT upstream_network.data_right.standard_endpoint_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_endpoint_owner_id, -1),
      -1
    ) AS standard_endpoint_id,
    COALESCE(
      upstream_network.data_right.standard_endpoint_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_endpoint_visibility,
    COALESCE(request.country_id, -1) AS user_country_id,
    'unknown' AS geo_country_visibility,
    IF(
      CARDINALITY(request.standard_device_type_ids) > 0,
      COALESCE(ELEMENT_AT(request.standard_device_type_ids, -1), -1),
      -1
    ) AS standard_device_type_id,
    COALESCE(request.standard_app_id, -1) AS standard_app_id,
    COALESCE(request.standard_environment_id, -1) AS standard_environment_id,
    COALESCE(request.standard_os_id, -1) AS standard_os_id,
    'unknown' AS user_agent_visibility,
    COALESCE(request.profile_id, -1) AS profile_id,
    'compound' AS profile_type,
    'false' AS live_linear_indicator,
    'false' AS ssp_bidder_indicator,
    'false' AS partner_tag_indicator,
    CAST(ARRAY[] AS ARRAY(VARCHAR)) AS time_position_classes,
    CAST(ARRAY[] AS ARRAY(BIGINT)) AS slot_ad_unit_ids,
    'not applicable' AS slot_sequence_normalized,
    'included' AS slot_user_drop_off,
    'not applicable' AS slot_removed_by_ux_indicator,
    'unknown' AS evergreen_ad_indicator,
    'unknown' AS promo_ad_indicator,
    CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 1 ELSE 0 END AS request_traffic_type,
    0 AS ack_traffic_type,
    ARRAY[] AS outbound_listing_id,
    CAST(ARRAY[] AS ARRAY(BIGINT)) AS global_advertiser_ids,
    CAST(ARRAY[] AS ARRAY(BIGINT)) AS global_brand_ids,
    -1 AS local_advertiser_id,
    ARRAY[] AS global_industry_ids,
    'not applicable' AS primary_ad_indicator,
    'ad/placement' AS demand_type,
    SUM(
      IF(
        BITWISE_AND(COALESCE(t.selection_status, 0), 1) > 0
        AND BITWISE_AND(COALESCE(t.selection_status, 0), 2) = 0,
        COALESCE(magnifier, 1),
        0
      )
    ) AS candidate_ads,
    CAST(0 AS BIGINT) AS tx_eligible_ads,
    CAST(0 AS BIGINT) AS slot_eligible_ads,
    CAST(0 AS BIGINT) AS placed_ads_sampled,
    CAST(0 AS BIGINT) AS placed_fallback_ads_sampled,
    CAST(0 AS BIGINT) AS filled_ads_sstf_fallback_sampled,
    CAST(0 AS BIGINT) AS selected_ads_sampled,
    CAST(0 AS BIGINT) AS gross_ad_views_sampled,
    SUM(IF(t.error > 0, COALESCE(magnifier, 1), 0)) AS placement_err_total,
    CAST(0 AS BIGINT) AS ad_err_total,
    CAST(0 AS BIGINT) AS slot_err_total,
    SUM(IF(COALESCE(t.error, -1) = 4, COALESCE(magnifier, 1), 0)) AS tx_err_malformed_response,
    SUM(IF(COALESCE(t.error, -1) = 5, COALESCE(magnifier, 1), 0)) AS tx_err_empty_response,
    SUM(IF(COALESCE(t.error, -1) = 100, COALESCE(magnifier, 1), 0)) AS tx_err_price_hurdle_check_failed,
    SUM(IF(COALESCE(t.error, -1) = 101, COALESCE(magnifier, 1), 0)) AS tx_err_profile_check_failed,
    SUM(IF(COALESCE(t.error, -1) = 103, COALESCE(magnifier, 1), 0)) AS tx_err_frequency_cap_failed,
    SUM(IF(COALESCE(t.error, -1) = 104, COALESCE(magnifier, 1), 0)) AS tx_err_not_allowed_upstream_network_for_ad,
    SUM(IF(COALESCE(t.error, -1) = 111, COALESCE(magnifier, 1), 0)) AS tx_err_reseller_whitelist_not_allowed,
    SUM(IF(COALESCE(t.error, -1) = 112, COALESCE(magnifier, 1), 0)) AS tx_err_reseller_blacklist_banned,
    SUM(IF(COALESCE(t.error, -1) = 113, COALESCE(magnifier, 1), 0)) AS tx_err_no_applicable_slot,
    SUM(IF(COALESCE(t.error, -1) = 114, COALESCE(magnifier, 1), 0)) AS tx_err_no_applicable_creative,
    SUM(IF(COALESCE(t.error, -1) = 121, COALESCE(magnifier, 1), 0)) AS tx_err_exceed_max_slot_duration,
    SUM(IF(COALESCE(t.error, -1) = 127, COALESCE(magnifier, 1), 0)) AS tx_err_competition_failure,
    SUM(IF(COALESCE(t.error, -1) = 128, COALESCE(magnifier, 1), 0)) AS tx_err_exclusivity_by_stream,
    SUM(IF(COALESCE(t.error, -1) = 139, COALESCE(magnifier, 1), 0)) AS tx_err_creative_restriction_check_failed,
    SUM(IF(COALESCE(t.error, -1) = 150, COALESCE(magnifier, 1), 0)) AS tx_err_ad_targeting_restricted,
    SUM(IF(COALESCE(t.error, -1) = 153, COALESCE(magnifier, 1), 0)) AS tx_err_budget_met,
    SUM(IF(COALESCE(t.error, -1) = 155, COALESCE(magnifier, 1), 0)) AS tx_err_listing_creative_duration_check,
    SUM(IF(COALESCE(t.error, -1) = 156, COALESCE(magnifier, 1), 0)) AS tx_err_advertiser_industry_restriction,
    SUM(IF(COALESCE(t.error, -1) = 157, COALESCE(magnifier, 1), 0)) AS tx_err_brand_blacklist_restriction,
    SUM(IF(COALESCE(t.error, -1) = 158, COALESCE(magnifier, 1), 0)) AS tx_err_advertiser_blacklist_restriction,
    SUM(IF(COALESCE(t.error, -1) = 159, COALESCE(magnifier, 1), 0)) AS tx_err_schedule_met,
    SUM(IF(COALESCE(t.error, -1) = 160, COALESCE(magnifier, 1), 0)) AS tx_err_slot_compatiblity_check,
    SUM(IF(COALESCE(t.error, -1) = 161, COALESCE(magnifier, 1), 0)) AS tx_err_rating_restriction,
    SUM(IF(COALESCE(t.error, -1) = 175, COALESCE(magnifier, 1), 0)) AS tx_err_global_brand_restricted_by_inventory,
    SUM(IF(COALESCE(t.error, -1) = 176, COALESCE(magnifier, 1), 0)) AS tx_err_global_advertiser_restricted_by_inventory,
    SUM(IF(COALESCE(t.error, -1) = 183, COALESCE(magnifier, 1), 0)) AS tx_err_blocked_by_inventory_source_optimization_imr,
    SUM(IF(COALESCE(t.error, -1) = 184, COALESCE(magnifier, 1), 0)) AS tx_err_inbound_rule_targeting_not_met,
    SUM(IF(COALESCE(t.error, -1) = 185, COALESCE(magnifier, 1), 0)) AS tx_err_inbound_rule_explicit_targeting_required,
    SUM(IF(COALESCE(t.error, -1) = 188, COALESCE(magnifier, 1), 0)) AS tx_err_global_brand_restricted_by_listing,
    SUM(IF(COALESCE(t.error, -1) = 192, COALESCE(magnifier, 1), 0)) AS tx_err_low_ranking_in_buyer,
    SUM(IF(COALESCE(t.error, -1) = 193, COALESCE(magnifier, 1), 0)) AS tx_err_industry_restricted_by_listing,
    SUM(IF(COALESCE(t.error, -1) = 200, COALESCE(magnifier, 1), 0)) AS tx_err_wrapper_timeout,
    SUM(IF(COALESCE(t.error, -1) = 201, COALESCE(magnifier, 1), 0)) AS tx_err_wrapper_http_error,
    SUM(IF(COALESCE(t.error, -1) = 205, COALESCE(magnifier, 1), 0)) AS tx_err_no_valid_creative,
    SUM(IF(COALESCE(t.error, -1) = 206, COALESCE(magnifier, 1), 0)) AS tx_err_unsupported_vast_version,
    SUM(IF(COALESCE(t.error, -1) = 214, COALESCE(magnifier, 1), 0)) AS tx_err_floor_price_notmet,
    SUM(IF(COALESCE(t.error, -1) = 300, COALESCE(magnifier, 1), 0)) AS tx_err_targeted_schedule_met,
    SUM(IF(COALESCE(t.error, -1) = 301, COALESCE(magnifier, 1), 0)) AS tx_err_targeted_budget_met,
    SUM(IF(COALESCE(t.error, -1) = 302, COALESCE(magnifier, 1), 0)) AS tx_err_yield_opt_met,
    SUM(IF(COALESCE(t.error, -1) = 306, COALESCE(magnifier, 1), 0)) AS tx_err_inflight_bid_met,
    SUM(IF(COALESCE(t.error, -1) = 1500, COALESCE(magnifier, 1), 0)) AS tx_err_inbound_order_competition_failure,
    SUM(IF(COALESCE(t.error, -1) = 1501, COALESCE(magnifier, 1), 0)) AS tx_err_competition_failure_in_pick_many,
    SUM(IF(COALESCE(t.error, -1) = 5001, COALESCE(magnifier, 1), 0)) AS tx_err_find_rule_path_failure,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_no_slot_selected,
    CAST(0 AS BIGINT) AS tx_err_no_advertiser_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_ad_pending_approval,
    CAST(0 AS BIGINT) AS tx_err_jitt_rendition_required,
    CAST(0 AS BIGINT) AS tx_err_industry_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_invalid_compliance_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_auction_max_ad_duration_exceeded,
    CAST(0 AS BIGINT) AS tx_err_compliance_not_approved,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_frequency_cap_reached,
    CAST(0 AS BIGINT) AS tx_err_mkpl_order_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_brand_restricted_by_rule,
    CAST(0 AS BIGINT) AS tx_err_mkpl_exchange_industry_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_no_brand_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_compliance_check_failed,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_rule_compliance_check_failed,
    CAST(0 AS BIGINT) AS tx_err_kv_opt_out,
    CAST(0 AS BIGINT) AS tx_err_timeout,
    CAST(0 AS BIGINT) AS tx_err_generate_impression_failed,
    CAST(0 AS BIGINT) AS tx_err_coppa_unsupported,
    CAST(0 AS BIGINT) AS tx_err_http_error,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_bid_throttling,
    CAST(0 AS BIGINT) AS tx_err_us_privacy_unsupported,
    CAST(0 AS BIGINT) AS tx_err_dsp_status_pause,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_traffic_control,
    CAST(0 AS BIGINT) AS tx_err_lat_unsupported,
    CAST(0 AS BIGINT) AS tx_err_no_bids,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_inventory_source_optimization,
    CAST(0 AS BIGINT) AS tx_err_dsp_status_inactive,
    CAST(0 AS BIGINT) AS tx_err_candidate_no_bids,
    CAST(0 AS BIGINT) AS tx_err_gdpr_unsupported,
    CAST(0 AS BIGINT) AS tx_err_exceed_server_concurrent_limit,
    CAST(0 AS BIGINT) AS tx_err_no_valid_market_ad,
    CAST(0 AS BIGINT) AS tx_err_unexpected_bid_dealid,
    CAST(0 AS BIGINT) AS tx_err_unknown_seat,
    CAST(0 AS BIGINT) AS tx_err_invalid_wrapper_url,
    CAST(0 AS BIGINT) AS tx_err_empty_bid_dealid,
    CAST(0 AS BIGINT) AS tx_err_no_ad_markup,
    CAST(0 AS BIGINT) AS tx_err_inapplicable_for_https,
    CAST(0 AS BIGINT) AS tx_err_unexpected_external_ad_id,
    CAST(0 AS BIGINT) AS tx_err_restricted_seat_by_auction_network,
    CAST(0 AS BIGINT) AS tx_err_no_valid_price,
    CAST(0 AS BIGINT) AS tx_err_no_valid_external_ad_id,
    CAST(0 AS BIGINT) AS tx_err_mismatched_creative_duration_with_scheduled,
    CAST(0 AS BIGINT) AS slot_err_exceed_max_slot_duration,
    CAST(0 AS BIGINT) AS slot_err_exceed_max_num_advertisements,
    CAST(0 AS BIGINT) AS slot_err_adjacent_exclusivity,
    CAST(0 AS BIGINT) AS slot_err_back2back_excluded,
    CAST(0 AS BIGINT) AS slot_err_industry_separation_excluded,
    CAST(0 AS BIGINT) AS slot_err_exclusivity_by_slot,
    CAST(0 AS BIGINT) AS slot_err_adjacent_same_4a_id,
    CAST(0 AS BIGINT) AS slot_err_incompatible_rendition_file_size,
    CAST(0 AS BIGINT) AS slot_err_estimate_rendition_duration_for_live,
    CAST(0 AS BIGINT) AS slot_err_large_rendition_duration,
    CAST(0 AS BIGINT) AS slot_err_creative_api_banned,
    CAST(0 AS BIGINT) AS slot_err_no_applicable_profiles_for_rendition,
    CAST(0 AS BIGINT) AS slot_err_brand_separation_excluded,
    CAST(0 AS BIGINT) AS slot_err_advertiser_separation_excluded,
    CAST(0 AS BIGINT) AS slot_err_frequency_cap_reaching,
    CAST(0 AS BIGINT) AS slot_err_slot_filled_by_multi_ads,
    CAST(0 AS BIGINT) AS slot_err_position_occupied,
    CAST(0 AS BIGINT) AS slot_err_brand_frequency_cap_reaching,
    CAST(0 AS BIGINT) AS slot_err_swapped_out_of_slot,
    CAST(0 AS BIGINT) AS slot_err_ad_asset_store_inapplicable_bitrate,
    CAST(0 AS BIGINT) AS slot_err_ad_asset_store_not_available,
    CAST(0 AS BIGINT) AS slot_err_advertiser_frequency_cap_reaching,
    CAST(0 AS BIGINT) AS slot_err_clearcast_code_restricted,
    CAST(0 AS BIGINT) AS slot_err_from_same_header_bidding,
    CAST(0 AS BIGINT) AS slot_err_incompatible_flash_version,
    CAST(0 AS BIGINT) AS slot_err_low_ranking_in_buyer,
    CAST(0 AS BIGINT) AS slot_err_no_error,
    CAST(0 AS BIGINT) AS slot_err_restricted_by_openrtb_impression_bid_capping
  FROM db.troubleshooting_log.fw_ads_demand_troubleshooting_log
  CROSS JOIN UNNEST(ad_selection_info) AS t
  WHERE
    (
      FROM_UNIXTIME(timestamp) >= CAST('2026-08-15 09:00:00' AS TIMESTAMP)
      AND FROM_UNIXTIME(timestamp) < CAST('2026-08-15 10:00:00' AS TIMESTAMP)
    )
    AND network.supply_source_type = 'mpe'
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
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55
  UNION ALL
  SELECT
    CAST(2 AS INTEGER) AS process_stage,
    DATE_FORMAT(FROM_UNIXTIME(timestamp), '%y-%m-%d %h:00:00') AS event_date,
    DATE_FORMAT(DATE_PARSE(dt, '%y-%m-%d-%h'), '%y%m%d%h0000') AS process_batch_id,
    COALESCE(upstream_network.network_id, -1) AS network_id,
    IF(
      COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(upstream_network.network_id, COALESCE(upstream_network.network_id, -1)),
      COALESCE(upstream_network.network_id, -1)
    ) AS content_owner_id,
    'full_visibility' AS content_owner_visibility,
    IF(
      COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.distributor_network_id, -1),
      -1
    ) AS distributor_id,
    CASE
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated'
      AND upstream_network.network_id = request.video_cro_network_id
      THEN 'cro'
      ELSE 'r'
    END AS transaction_type,
    COALESCE(t.external_network_id, COALESCE(network.network_id, -1)) AS reseller_id,
    'full_visibility' AS reseller_visibility,
    IF(COALESCE(t.external_network_id, -1) = -1, 'full', 'internal') AS reseller_network_type,
    CASE
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated'
      THEN 1
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'mrm_rule'
      THEN 3
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'mpp'
      THEN 5
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'mpe'
      THEN 6
      ELSE -1
    END AS supply_source,
    'marketplace platform exchange' AS sales_channel,
    'marketplace platform exchange' AS sales_strategy,
    IF(
      COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_id, -1),
      -1
    ) AS site_id,
    IF(
      COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_section_id, -1),
      -1
    ) AS site_section_id,
    COALESCE(request.standard_publisher_id, -1) AS standard_publisher_id,
    IF(
      NOT upstream_network.data_right.standard_brand_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_brand_id, -1),
      -1
    ) AS standard_brand_id,
    COALESCE(
      upstream_network.data_right.standard_brand_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_brand_visibility,
    IF(
      NOT upstream_network.data_right.standard_programmer_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_programmer_id, -1),
      -1
    ) AS standard_programmer_id,
    COALESCE(
      upstream_network.data_right.standard_programmer_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_programmer_visibility,
    IF(
      upstream_network.supply_source_type <> 'mrm_rule',
      -1,
      COALESCE(request.content_form_id, -1)
    ) AS content_form_id,
    COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), -1) AS stream_mode_id,
    IF(
      NOT upstream_network.data_right.standard_endpoint_owner_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_endpoint_owner_id, -1),
      -1
    ) AS standard_endpoint_owner_id,
    COALESCE(
      upstream_network.data_right.standard_endpoint_owner_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_endpoint_owner_visibility,
    IF(
      NOT upstream_network.data_right.standard_endpoint_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_endpoint_owner_id, -1),
      -1
    ) AS standard_endpoint_id,
    COALESCE(
      upstream_network.data_right.standard_endpoint_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_endpoint_visibility,
    COALESCE(request.country_id, -1) AS user_country_id,
    'unknown' AS geo_country_visibility,
    IF(
      CARDINALITY(request.standard_device_type_ids) > 0,
      COALESCE(ELEMENT_AT(request.standard_device_type_ids, -1), -1),
      -1
    ) AS standard_device_type_id,
    COALESCE(request.standard_app_id, -1) AS standard_app_id,
    COALESCE(request.standard_environment_id, -1) AS standard_environment_id,
    COALESCE(request.standard_os_id, -1) AS standard_os_id,
    'unknown' AS user_agent_visibility,
    COALESCE(request.profile_id, -1) AS profile_id,
    'compound' AS profile_type,
    'false' AS live_linear_indicator,
    'false' AS ssp_bidder_indicator,
    'false' AS partner_tag_indicator,
    CAST(ARRAY[] AS ARRAY(VARCHAR)) AS time_position_classes,
    CAST(ARRAY[] AS ARRAY(BIGINT)) AS slot_ad_unit_ids,
    'not applicable' AS slot_sequence_normalized,
    'included' AS slot_user_drop_off,
    'not applicable' AS slot_removed_by_ux_indicator,
    'unknown' AS evergreen_ad_indicator,
    'unknown' AS promo_ad_indicator,
    CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 1 ELSE 0 END AS request_traffic_type,
    0 AS ack_traffic_type,
    ARRAY[] AS outbound_listing_id,
    COALESCE(ad.global_advertiser_ids, ARRAY[]) AS global_advertiser_ids,
    COALESCE(ad.global_brand_ids, ARRAY[]) AS global_brand_ids,
    COALESCE(ad.advertiser_id, -1) AS local_advertiser_id,
    ARRAY[] AS global_industry_ids,
    'not applicable' AS primary_ad_indicator,
    'ad/placement' AS demand_type,
    SUM(
      IF(BITWISE_AND(COALESCE(ad.selection_status, 0), 1) > 0, COALESCE(magnifier, 1), 0)
    ) AS candidate_ads,
    SUM(
      IF(BITWISE_AND(COALESCE(ad.selection_status, 0), 8) > 0, COALESCE(magnifier, 1), 0)
    ) AS tx_eligible_ads,
    CAST(0 AS BIGINT) AS slot_eligible_ads,
    CAST(0 AS BIGINT) AS placed_ads_sampled,
    CAST(0 AS BIGINT) AS placed_fallback_ads_sampled,
    CAST(0 AS BIGINT) AS filled_ads_sstf_fallback_sampled,
    CAST(0 AS BIGINT) AS selected_ads_sampled,
    CAST(0 AS BIGINT) AS gross_ad_views_sampled,
    CAST(0 AS BIGINT) AS placement_err_total,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) > 0,
        COALESCE(magnifier, 1),
        0
      )
    ) AS ad_err_total,
    CAST(0 AS BIGINT) AS slot_err_total,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 4,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_malformed_response,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 5,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_empty_response,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 100,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_price_hurdle_check_failed,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 101,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_profile_check_failed,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 103,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_frequency_cap_failed,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 104,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_not_allowed_upstream_network_for_ad,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 111,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_reseller_whitelist_not_allowed,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 112,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_reseller_blacklist_banned,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 113,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_no_applicable_slot,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 114,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_no_applicable_creative,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 121,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_exceed_max_slot_duration,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 127,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_competition_failure,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 128,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_exclusivity_by_stream,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 139,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_creative_restriction_check_failed,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 150,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_ad_targeting_restricted,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 153,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_budget_met,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 155,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_listing_creative_duration_check,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 156,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_advertiser_industry_restriction,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 157,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_brand_blacklist_restriction,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 158,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_advertiser_blacklist_restriction,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 159,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_schedule_met,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 160,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_slot_compatiblity_check,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 161,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_rating_restriction,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 175,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_global_brand_restricted_by_inventory,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 176,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_global_advertiser_restricted_by_inventory,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 183,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_blocked_by_inventory_source_optimization_imr,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 184,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_inbound_rule_targeting_not_met,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 185,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_inbound_rule_explicit_targeting_required,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 188,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_global_brand_restricted_by_listing,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 192,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_low_ranking_in_buyer,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 193,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_industry_restricted_by_listing,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 200,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_wrapper_timeout,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 201,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_wrapper_http_error,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 205,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_no_valid_creative,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 206,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_unsupported_vast_version,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 214,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_floor_price_notmet,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 300,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_targeted_schedule_met,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 301,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_targeted_budget_met,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 302,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_yield_opt_met,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 306,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_inflight_bid_met,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 1500,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_inbound_order_competition_failure,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 1501,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_competition_failure_in_pick_many,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 5001,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_find_rule_path_failure,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_no_slot_selected,
    CAST(0 AS BIGINT) AS tx_err_no_advertiser_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_ad_pending_approval,
    CAST(0 AS BIGINT) AS tx_err_jitt_rendition_required,
    CAST(0 AS BIGINT) AS tx_err_industry_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_invalid_compliance_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_auction_max_ad_duration_exceeded,
    CAST(0 AS BIGINT) AS tx_err_compliance_not_approved,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_frequency_cap_reached,
    CAST(0 AS BIGINT) AS tx_err_mkpl_order_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_brand_restricted_by_rule,
    CAST(0 AS BIGINT) AS tx_err_mkpl_exchange_industry_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_no_brand_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_compliance_check_failed,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_rule_compliance_check_failed,
    CAST(0 AS BIGINT) AS tx_err_kv_opt_out,
    CAST(0 AS BIGINT) AS tx_err_timeout,
    CAST(0 AS BIGINT) AS tx_err_generate_impression_failed,
    CAST(0 AS BIGINT) AS tx_err_coppa_unsupported,
    CAST(0 AS BIGINT) AS tx_err_http_error,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_bid_throttling,
    CAST(0 AS BIGINT) AS tx_err_us_privacy_unsupported,
    CAST(0 AS BIGINT) AS tx_err_dsp_status_pause,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_traffic_control,
    CAST(0 AS BIGINT) AS tx_err_lat_unsupported,
    CAST(0 AS BIGINT) AS tx_err_no_bids,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_inventory_source_optimization,
    CAST(0 AS BIGINT) AS tx_err_dsp_status_inactive,
    CAST(0 AS BIGINT) AS tx_err_candidate_no_bids,
    CAST(0 AS BIGINT) AS tx_err_gdpr_unsupported,
    CAST(0 AS BIGINT) AS tx_err_exceed_server_concurrent_limit,
    CAST(0 AS BIGINT) AS tx_err_no_valid_market_ad,
    CAST(0 AS BIGINT) AS tx_err_unexpected_bid_dealid,
    CAST(0 AS BIGINT) AS tx_err_unknown_seat,
    CAST(0 AS BIGINT) AS tx_err_invalid_wrapper_url,
    CAST(0 AS BIGINT) AS tx_err_empty_bid_dealid,
    CAST(0 AS BIGINT) AS tx_err_no_ad_markup,
    CAST(0 AS BIGINT) AS tx_err_inapplicable_for_https,
    CAST(0 AS BIGINT) AS tx_err_unexpected_external_ad_id,
    CAST(0 AS BIGINT) AS tx_err_restricted_seat_by_auction_network,
    CAST(0 AS BIGINT) AS tx_err_no_valid_price,
    CAST(0 AS BIGINT) AS tx_err_no_valid_external_ad_id,
    CAST(0 AS BIGINT) AS tx_err_mismatched_creative_duration_with_scheduled,
    CAST(0 AS BIGINT) AS slot_err_exceed_max_slot_duration,
    CAST(0 AS BIGINT) AS slot_err_exceed_max_num_advertisements,
    CAST(0 AS BIGINT) AS slot_err_adjacent_exclusivity,
    CAST(0 AS BIGINT) AS slot_err_back2back_excluded,
    CAST(0 AS BIGINT) AS slot_err_industry_separation_excluded,
    CAST(0 AS BIGINT) AS slot_err_exclusivity_by_slot,
    CAST(0 AS BIGINT) AS slot_err_adjacent_same_4a_id,
    CAST(0 AS BIGINT) AS slot_err_incompatible_rendition_file_size,
    CAST(0 AS BIGINT) AS slot_err_estimate_rendition_duration_for_live,
    CAST(0 AS BIGINT) AS slot_err_large_rendition_duration,
    CAST(0 AS BIGINT) AS slot_err_creative_api_banned,
    CAST(0 AS BIGINT) AS slot_err_no_applicable_profiles_for_rendition,
    CAST(0 AS BIGINT) AS slot_err_brand_separation_excluded,
    CAST(0 AS BIGINT) AS slot_err_advertiser_separation_excluded,
    CAST(0 AS BIGINT) AS slot_err_frequency_cap_reaching,
    CAST(0 AS BIGINT) AS slot_err_slot_filled_by_multi_ads,
    CAST(0 AS BIGINT) AS slot_err_position_occupied,
    CAST(0 AS BIGINT) AS slot_err_brand_frequency_cap_reaching,
    CAST(0 AS BIGINT) AS slot_err_swapped_out_of_slot,
    CAST(0 AS BIGINT) AS slot_err_ad_asset_store_inapplicable_bitrate,
    CAST(0 AS BIGINT) AS slot_err_ad_asset_store_not_available,
    CAST(0 AS BIGINT) AS slot_err_advertiser_frequency_cap_reaching,
    CAST(0 AS BIGINT) AS slot_err_clearcast_code_restricted,
    CAST(0 AS BIGINT) AS slot_err_from_same_header_bidding,
    CAST(0 AS BIGINT) AS slot_err_incompatible_flash_version,
    CAST(0 AS BIGINT) AS slot_err_low_ranking_in_buyer,
    CAST(0 AS BIGINT) AS slot_err_no_error,
    CAST(0 AS BIGINT) AS slot_err_restricted_by_openrtb_impression_bid_capping
  FROM db.troubleshooting_log.fw_ads_demand_troubleshooting_log
  CROSS JOIN UNNEST(ad_selection_info) AS t
  CROSS JOIN UNNEST(t.ad_infos) AS ad
  WHERE
    (
      (
        FROM_UNIXTIME(timestamp) >= CAST('2026-08-15 09:00:00' AS TIMESTAMP)
        AND FROM_UNIXTIME(timestamp) < CAST('2026-08-15 10:00:00' AS TIMESTAMP)
      )
      AND NOT (
        COALESCE(ad.selection_status, 0) < 7
        AND BITWISE_AND(COALESCE(ad.ad_info_flag, 0), 1) > 0
      )
    )
    AND network.supply_source_type = 'mpe'
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
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55
  UNION ALL
  SELECT
    CAST(16 AS INTEGER) AS process_stage,
    DATE_FORMAT(FROM_UNIXTIME(timestamp), '%y-%m-%d %h:00:00') AS event_date,
    DATE_FORMAT(DATE_PARSE(dt, '%y-%m-%d-%h'), '%y%m%d%h0000') AS process_batch_id,
    COALESCE(upstream_network.network_id, -1) AS network_id,
    IF(
      COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(upstream_network.network_id, COALESCE(upstream_network.network_id, -1)),
      COALESCE(upstream_network.network_id, -1)
    ) AS content_owner_id,
    'full_visibility' AS content_owner_visibility,
    IF(
      COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.distributor_network_id, -1),
      -1
    ) AS distributor_id,
    CASE
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated'
      AND upstream_network.network_id = request.video_cro_network_id
      THEN 'cro'
    END AS transaction_type,
    COALESCE(t.external_network_id, COALESCE(network.network_id, -1)) AS reseller_id,
    'full_visibility' AS reseller_visibility,
    IF(COALESCE(t.external_network_id, -1) = -1, 'full', 'internal') AS reseller_network_type,
    CASE
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated'
      THEN 1
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'mrm_rule'
      THEN 3
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'mpp'
      THEN 5
      WHEN COALESCE(upstream_network.supply_source_type, 'unknown') = 'mpe'
      THEN 6
      ELSE -1
    END AS supply_source,
    'marketplace platform exchange' AS sales_channel,
    'marketplace platform exchange' AS sales_strategy,
    IF(
      COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_id, -1),
      -1
    ) AS site_id,
    IF(
      COALESCE(upstream_network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_section_id, -1),
      -1
    ) AS site_section_id,
    COALESCE(request.standard_publisher_id, -1) AS standard_publisher_id,
    IF(
      NOT upstream_network.data_right.standard_brand_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_brand_id, -1),
      -1
    ) AS standard_brand_id,
    COALESCE(
      upstream_network.data_right.standard_brand_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_brand_visibility,
    IF(
      NOT upstream_network.data_right.standard_programmer_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_programmer_id, -1),
      -1
    ) AS standard_programmer_id,
    COALESCE(
      upstream_network.data_right.standard_programmer_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_programmer_visibility,
    IF(
      upstream_network.supply_source_type <> 'mrm_rule',
      -1,
      COALESCE(request.content_form_id, -1)
    ) AS content_form_id,
    COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), -1) AS stream_mode_id,
    IF(
      NOT upstream_network.data_right.standard_endpoint_owner_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_endpoint_owner_id, -1),
      -1
    ) AS standard_endpoint_owner_id,
    COALESCE(
      upstream_network.data_right.standard_endpoint_owner_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_endpoint_owner_visibility,
    IF(
      NOT upstream_network.data_right.standard_endpoint_visibility.report_aggregate IS NULL
      OR upstream_network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_endpoint_owner_id, -1),
      -1
    ) AS standard_endpoint_id,
    COALESCE(
      upstream_network.data_right.standard_endpoint_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_endpoint_visibility,
    COALESCE(request.country_id, -1) AS user_country_id,
    'unknown' AS geo_country_visibility,
    IF(
      CARDINALITY(request.standard_device_type_ids) > 0,
      COALESCE(ELEMENT_AT(request.standard_device_type_ids, -1), -1),
      -1
    ) AS standard_device_type_id,
    COALESCE(request.standard_app_id, -1) AS standard_app_id,
    COALESCE(request.standard_environment_id, -1) AS standard_environment_id,
    COALESCE(request.standard_os_id, -1) AS standard_os_id,
    'unknown' AS user_agent_visibility,
    COALESCE(request.profile_id, -1) AS profile_id,
    'compound' AS profile_type,
    'false' AS live_linear_indicator,
    'false' AS ssp_bidder_indicator,
    'false' AS partner_tag_indicator,
    ARRAY[COALESCE(slot.time_position_class, 'unknown')] AS time_position_classes,
    ARRAY[COALESCE(slot.ad_unit_id, -1)] AS slot_ad_unit_ids,
    CASE
      WHEN slot.sequence IS NULL
      THEN 'null'
      WHEN slot.sequence > 5
      THEN '5+'
      ELSE CAST(slot.sequence AS VARCHAR)
    END AS slot_sequence_normalized,
    'included' AS slot_user_drop_off,
    IF(BITWISE_AND(COALESCE(slot.flags, 0), 8) > 0, 'yes', 'no') AS slot_removed_by_ux_indicator,
    'unknown' AS evergreen_ad_indicator,
    'unknown' AS promo_ad_indicator,
    CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 1 ELSE 0 END AS request_traffic_type,
    0 AS ack_traffic_type,
    ARRAY[] AS outbound_listing_id,
    COALESCE(ad.global_advertiser_ids, ARRAY[]) AS global_advertiser_ids,
    COALESCE(ad.global_brand_ids, ARRAY[]) AS global_brand_ids,
    COALESCE(ad.advertiser_id, -1) AS local_advertiser_id,
    ARRAY[] AS global_industry_ids,
    IF(
      BITWISE_AND(COALESCE(slot_ad.flags, 0), 32) = 0
      OR (
        BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 32) > 0
        AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 33554432) > 0
      ),
      'primary',
      'fallback'
    ) AS primary_ad_indicator,
    'ad/placement' AS demand_type,
    CAST(0 AS BIGINT) AS candidate_ads,
    CAST(0 AS BIGINT) AS tx_eligible_ads,
    SUM(
      IF(BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 8) > 0, COALESCE(magnifier, 1), 0)
    ) AS slot_eligible_ads,
    SUM(
      IF(
        BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 16) > 0
        AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 32) = 0,
        COALESCE(magnifier, 1),
        0
      )
    ) AS placed_ads_sampled,
    SUM(
      IF(
        BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 16) > 0
        AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 32) > 0,
        COALESCE(magnifier, 1),
        0
      )
    ) AS placed_fallback_ads_sampled,
    SUM(
      IF(
        BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 32) > 0
        AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 33554432) > 0,
        COALESCE(magnifier, 1),
        0
      )
    ) AS filled_ads_sstf_fallback_sampled,
    SUM(
      IF(
        BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 32) > 0,
        COALESCE(magnifier, 1),
        0
      )
    ) AS selected_ads_sampled,
    CAST(0 AS BIGINT) AS gross_ad_views_sampled,
    CAST(0 AS BIGINT) AS placement_err_total,
    CAST(0 AS BIGINT) AS ad_err_total,
    SUM(IF(slot_ad.error > 0, COALESCE(magnifier, 1), 0)) AS slot_err_total,
    CAST(0 AS BIGINT) AS tx_err_malformed_response,
    CAST(0 AS BIGINT) AS tx_err_empty_response,
    CAST(0 AS BIGINT) AS tx_err_price_hurdle_check_failed,
    CAST(0 AS BIGINT) AS tx_err_profile_check_failed,
    CAST(0 AS BIGINT) AS tx_err_frequency_cap_failed,
    CAST(0 AS BIGINT) AS tx_err_not_allowed_upstream_network_for_ad,
    CAST(0 AS BIGINT) AS tx_err_reseller_whitelist_not_allowed,
    CAST(0 AS BIGINT) AS tx_err_reseller_blacklist_banned,
    CAST(0 AS BIGINT) AS tx_err_no_applicable_slot,
    CAST(0 AS BIGINT) AS tx_err_no_applicable_creative,
    CAST(0 AS BIGINT) AS tx_err_exceed_max_slot_duration,
    CAST(0 AS BIGINT) AS tx_err_competition_failure,
    CAST(0 AS BIGINT) AS tx_err_exclusivity_by_stream,
    CAST(0 AS BIGINT) AS tx_err_creative_restriction_check_failed,
    CAST(0 AS BIGINT) AS tx_err_ad_targeting_restricted,
    CAST(0 AS BIGINT) AS tx_err_budget_met,
    CAST(0 AS BIGINT) AS tx_err_listing_creative_duration_check,
    CAST(0 AS BIGINT) AS tx_err_advertiser_industry_restriction,
    CAST(0 AS BIGINT) AS tx_err_brand_blacklist_restriction,
    CAST(0 AS BIGINT) AS tx_err_advertiser_blacklist_restriction,
    CAST(0 AS BIGINT) AS tx_err_schedule_met,
    CAST(0 AS BIGINT) AS tx_err_slot_compatiblity_check,
    CAST(0 AS BIGINT) AS tx_err_rating_restriction,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_inventory,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_inventory,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_inventory_source_optimization_imr,
    CAST(0 AS BIGINT) AS tx_err_inbound_rule_targeting_not_met,
    CAST(0 AS BIGINT) AS tx_err_inbound_rule_explicit_targeting_required,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_low_ranking_in_buyer,
    CAST(0 AS BIGINT) AS tx_err_industry_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_wrapper_timeout,
    CAST(0 AS BIGINT) AS tx_err_wrapper_http_error,
    CAST(0 AS BIGINT) AS tx_err_no_valid_creative,
    CAST(0 AS BIGINT) AS tx_err_unsupported_vast_version,
    CAST(0 AS BIGINT) AS tx_err_floor_price_notmet,
    CAST(0 AS BIGINT) AS tx_err_targeted_schedule_met,
    CAST(0 AS BIGINT) AS tx_err_targeted_budget_met,
    CAST(0 AS BIGINT) AS tx_err_yield_opt_met,
    CAST(0 AS BIGINT) AS tx_err_inflight_bid_met,
    CAST(0 AS BIGINT) AS tx_err_inbound_order_competition_failure,
    CAST(0 AS BIGINT) AS tx_err_competition_failure_in_pick_many,
    CAST(0 AS BIGINT) AS tx_err_find_rule_path_failure,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_no_slot_selected,
    CAST(0 AS BIGINT) AS tx_err_no_advertiser_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_ad_pending_approval,
    CAST(0 AS BIGINT) AS tx_err_jitt_rendition_required,
    CAST(0 AS BIGINT) AS tx_err_industry_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_invalid_compliance_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_auction_max_ad_duration_exceeded,
    CAST(0 AS BIGINT) AS tx_err_compliance_not_approved,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_frequency_cap_reached,
    CAST(0 AS BIGINT) AS tx_err_mkpl_order_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_brand_restricted_by_rule,
    CAST(0 AS BIGINT) AS tx_err_mkpl_exchange_industry_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_no_brand_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_compliance_check_failed,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_rule_compliance_check_failed,
    CAST(0 AS BIGINT) AS tx_err_kv_opt_out,
    CAST(0 AS BIGINT) AS tx_err_timeout,
    CAST(0 AS BIGINT) AS tx_err_generate_impression_failed,
    CAST(0 AS BIGINT) AS tx_err_coppa_unsupported,
    CAST(0 AS BIGINT) AS tx_err_http_error,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_bid_throttling,
    CAST(0 AS BIGINT) AS tx_err_us_privacy_unsupported,
    CAST(0 AS BIGINT) AS tx_err_dsp_status_pause,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_traffic_control,
    CAST(0 AS BIGINT) AS tx_err_lat_unsupported,
    CAST(0 AS BIGINT) AS tx_err_no_bids,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_inventory_source_optimization,
    CAST(0 AS BIGINT) AS tx_err_dsp_status_inactive,
    CAST(0 AS BIGINT) AS tx_err_candidate_no_bids,
    CAST(0 AS BIGINT) AS tx_err_gdpr_unsupported,
    CAST(0 AS BIGINT) AS tx_err_exceed_server_concurrent_limit,
    CAST(0 AS BIGINT) AS tx_err_no_valid_market_ad,
    CAST(0 AS BIGINT) AS tx_err_unexpected_bid_dealid,
    CAST(0 AS BIGINT) AS tx_err_unknown_seat,
    CAST(0 AS BIGINT) AS tx_err_invalid_wrapper_url,
    CAST(0 AS BIGINT) AS tx_err_empty_bid_dealid,
    CAST(0 AS BIGINT) AS tx_err_no_ad_markup,
    CAST(0 AS BIGINT) AS tx_err_inapplicable_for_https,
    CAST(0 AS BIGINT) AS tx_err_unexpected_external_ad_id,
    CAST(0 AS BIGINT) AS tx_err_restricted_seat_by_auction_network,
    CAST(0 AS BIGINT) AS tx_err_no_valid_price,
    CAST(0 AS BIGINT) AS tx_err_no_valid_external_ad_id,
    CAST(0 AS BIGINT) AS tx_err_mismatched_creative_duration_with_scheduled,
    SUM(IF(slot_ad.error = 121, COALESCE(magnifier, 1), 0)) AS slot_err_exceed_max_slot_duration,
    SUM(IF(slot_ad.error = 122, COALESCE(magnifier, 1), 0)) AS slot_err_exceed_max_num_advertisements,
    SUM(IF(slot_ad.error = 123, COALESCE(magnifier, 1), 0)) AS slot_err_adjacent_exclusivity,
    SUM(IF(slot_ad.error = 124, COALESCE(magnifier, 1), 0)) AS slot_err_back2back_excluded,
    SUM(IF(slot_ad.error = 125, COALESCE(magnifier, 1), 0)) AS slot_err_industry_separation_excluded,
    SUM(IF(slot_ad.error = 126, COALESCE(magnifier, 1), 0)) AS slot_err_exclusivity_by_slot,
    SUM(IF(slot_ad.error = 129, COALESCE(magnifier, 1), 0)) AS slot_err_adjacent_same_4a_id,
    SUM(IF(slot_ad.error = 131, COALESCE(magnifier, 1), 0)) AS slot_err_incompatible_rendition_file_size,
    SUM(IF(slot_ad.error = 132, COALESCE(magnifier, 1), 0)) AS slot_err_estimate_rendition_duration_for_live,
    SUM(IF(slot_ad.error = 133, COALESCE(magnifier, 1), 0)) AS slot_err_large_rendition_duration,
    SUM(IF(slot_ad.error = 135, COALESCE(magnifier, 1), 0)) AS slot_err_creative_api_banned,
    SUM(IF(slot_ad.error = 136, COALESCE(magnifier, 1), 0)) AS slot_err_no_applicable_profiles_for_rendition,
    SUM(IF(slot_ad.error = 143, COALESCE(magnifier, 1), 0)) AS slot_err_brand_separation_excluded,
    SUM(IF(slot_ad.error = 145, COALESCE(magnifier, 1), 0)) AS slot_err_advertiser_separation_excluded,
    SUM(IF(slot_ad.error = 147, COALESCE(magnifier, 1), 0)) AS slot_err_frequency_cap_reaching,
    SUM(IF(slot_ad.error = 167, COALESCE(magnifier, 1), 0)) AS slot_err_slot_filled_by_multi_ads,
    SUM(IF(slot_ad.error = 181, COALESCE(magnifier, 1), 0)) AS slot_err_position_occupied,
    SUM(IF(slot_ad.error = 187, COALESCE(magnifier, 1), 0)) AS slot_err_brand_frequency_cap_reaching,
    SUM(IF(slot_ad.error = 195, COALESCE(magnifier, 1), 0)) AS slot_err_swapped_out_of_slot,
    CAST(0 AS BIGINT) AS slot_err_ad_asset_store_inapplicable_bitrate,
    CAST(0 AS BIGINT) AS slot_err_ad_asset_store_not_available,
    CAST(0 AS BIGINT) AS slot_err_advertiser_frequency_cap_reaching,
    CAST(0 AS BIGINT) AS slot_err_clearcast_code_restricted,
    CAST(0 AS BIGINT) AS slot_err_from_same_header_bidding,
    CAST(0 AS BIGINT) AS slot_err_incompatible_flash_version,
    CAST(0 AS BIGINT) AS slot_err_low_ranking_in_buyer,
    CAST(0 AS BIGINT) AS slot_err_no_error,
    CAST(0 AS BIGINT) AS slot_err_restricted_by_openrtb_impression_bid_capping
  FROM db.troubleshooting_log.fw_ads_demand_troubleshooting_log
  CROSS JOIN UNNEST(ad_selection_info) AS t
  CROSS JOIN UNNEST(t.ad_infos) AS ad
  CROSS JOIN UNNEST(ad.slot_ad_infos) AS slot_ad
  CROSS JOIN UNNEST(slots) AS slot
  WHERE
    (
      (
        (
          FROM_UNIXTIME(timestamp) >= CAST('2026-08-15 09:00:00' AS TIMESTAMP)
          AND FROM_UNIXTIME(timestamp) < CAST('2026-08-15 10:00:00' AS TIMESTAMP)
        )
        AND slot_ad.slot_index = slot.index
      )
      AND BITWISE_AND(slot.flags, 64) = 0
    )
    AND network.supply_source_type = 'mpe'
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
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55
  UNION ALL
  SELECT
    CAST(1 AS INTEGER) AS process_stage,
    DATE_FORMAT(DATE_TRUNC('HOUR', request__timestamp), '%y-%m-%d %h:00:00') AS event_date,
    process_batch_id AS process_batch_id,
    COALESCE(t1.network_id, -1) AS network_id,
    COALESCE(t1.content_owner_network_id, -1) AS content_owner_id,
    'full_visibility' AS content_owner_visibility,
    IF(
      COALESCE(t1.supply_source_type, -1) = 1,
      COALESCE(request__context__network_id, -1),
      -1
    ) AS distributor_id,
    CASE
      WHEN COALESCE(t1.supply_source_type, -1) = 1
      AND c.request__context__video_cro_network_id = t1.network_id
      THEN 'cro'
      ELSE 'r'
    END AS transaction_type,
    COALESCE(t1.reseller_id, -1) AS reseller_id,
    'full_visibility' AS reseller_visibility,
    'full' AS reseller_network_type,
    COALESCE(t1.supply_source_type, -1) AS supply_source,
    'marketplace platform exchange' AS sales_channel,
    'marketplace platform exchange' AS sales_strategy,
    COALESCE(site_id, -1) AS site_id,
    COALESCE(site_section_id, -1) AS site_section_id,
    COALESCE(c.request__context__standard_publisher_id, -1) AS standard_publisher_id,
    COALESCE(c.request__context__standard_brand_id, -1) AS standard_brand_id,
    COALESCE(t1.standard_brand_visibility__report_aggregate, 'full_visibility') AS standard_brand_visibility,
    COALESCE(c.request__context__standard_programmer_id, -1) AS standard_programmer_id,
    COALESCE(t1.standard_programmer_visibility__report_aggregate, 'full_visibility') AS standard_programmer_visibility,
    COALESCE(c.request__context__content_form_id, -1) AS content_form_id,
    COALESCE(c.request__context__stream_mode_id, -1) AS stream_mode_id,
    COALESCE(c.request__context__standard_endpoint_owner_id, -1) AS standard_endpoint_owner_id,
    COALESCE(t1.standard_endpoint_owner_visibility__report_aggregate, 'full_visibility') AS standard_endpoint_owner_visibility,
    COALESCE(c.request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
    COALESCE(t1.standard_endpoint_visibility__report_aggregate, 'full_visibility') AS standard_endpoint_visibility,
    COALESCE(c.visitor__country_id, -1) AS user_country_id,
    COALESCE(t1.geo_country_visibility__report_aggregate, 'full_visibility') AS geo_country_visibility,
    COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
    COALESCE(request__context__standard_app_id, -1) AS standard_app_id,
    COALESCE(c.visitor__standard_environment_id, -1) AS standard_environment_id,
    COALESCE(c.visitor__standard_os_id, -1) AS standard_os_id,
    COALESCE(t1.user_agent_visibility__report_aggregate, 'full_visibility') AS user_agent_visibility,
    COALESCE(c.request__context__profile_id, -1) AS profile_id,
    'compound' AS profile_type,
    IF(BITWISE_AND(COALESCE(request__extra_flags, 0), 1024) > 0, 'true', 'false') AS live_linear_indicator,
    IF(BITWISE_AND(COALESCE(request__extra_flags2, 0), 8) > 0, 'true', 'false') AS ssp_bidder_indicator,
    'false' AS partner_tag_indicator,
    ARRAY[slot__time_position_class] AS time_position_classes,
    ARRAY[slot__ad_unit_id] AS slot_ad_unit_ids,
    CASE
      WHEN slot__sequence IS NULL
      THEN 'null'
      WHEN slot__sequence > 5
      THEN '5+'
      ELSE CAST(slot__sequence AS VARCHAR)
    END AS slot_sequence_normalized,
    'included' AS slot_user_drop_off,
    'not applicable' AS slot_removed_by_ux_indicator,
    'unknown' AS evergreen_ad_indicator,
    'unknown' AS promo_ad_indicator,
    CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 1 ELSE 0 END AS request_traffic_type,
    0 AS ack_traffic_type,
    COALESCE(t1.outbound_listing_id, ARRAY[]) AS outbound_listing_id,
    ARRAY_DISTINCT(ARRAY_SORT(c.candidate__global_advertiser_ids)) AS global_advertiser_ids,
    ARRAY_DISTINCT(ARRAY_SORT(c.candidate__global_brand_ids)) AS global_brand_ids,
    -1 AS local_advertiser_id,
    ARRAY_DISTINCT(ARRAY_SORT(c.candidate__global_industry_ids)) AS global_industry_ids,
    'not applicable' AS primary_ad_indicator,
    'programmatic' AS demand_type,
    SUM(COALESCE(request__decision_info__value13, 1)) AS candidate_ads,
    SUM(
      CASE
        WHEN BITWISE_AND(candidate__flags, 524288) > 0
        AND candidate__bid_status > 0
        AND (
          CARDINALITY(COALESCE(candidate__filter_reason__slot_index, ARRAY[])) > 0
          OR COALESCE(advertisement__slot_index, -1) > -1
        )
        THEN COALESCE(request__decision_info__value13, 1)
        WHEN BITWISE_AND(candidate__flags, 262144) > 0
        AND BITWISE_AND(candidate__bid_status, 2) > 0
        AND (
          CARDINALITY(COALESCE(candidate__filter_reason__slot_index, ARRAY[])) > 0
          OR COALESCE(advertisement__slot_index, -1) > -1
        )
        THEN COALESCE(request__decision_info__value13, 1)
        ELSE 0
      END
    ) AS tx_eligible_ads,
    SUM(0) AS slot_eligible_ads,
    SUM(0) AS placed_ads_sampled,
    SUM(0) AS placed_fallback_ads_sampled,
    SUM(0) AS filled_ads_sstf_fallback_sampled,
    SUM(0) AS selected_ads_sampled,
    SUM(0) AS gross_ad_views_sampled,
    SUM(0) AS placement_err_total,
    SUM(0) AS ad_err_total,
    SUM(0) AS slot_err_total,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'malformed_response',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_malformed_response,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'empty_response',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_empty_response,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'price_hurdle_check_failed',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_price_hurdle_check_failed,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'profile_check_failed',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_profile_check_failed,
    SUM(0) AS tx_err_frequency_cap_failed,
    SUM(0) AS tx_err_not_allowed_upstream_network_for_ad,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'reseller_whitelist_not_allowed',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_reseller_whitelist_not_allowed,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'reseller_blacklist_banned',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_reseller_blacklist_banned,
    SUM(0) AS tx_err_no_applicable_slot,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'no_applicable_creative',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_no_applicable_creative,
    SUM(0) AS tx_err_exceed_max_slot_duration,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'competition_failure',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_competition_failure,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'exclusivity_by_stream',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_exclusivity_by_stream,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'creative_restriction_check_failed',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_creative_restriction_check_failed,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'ad_targeting_restricted',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_ad_targeting_restricted,
    SUM(0) AS tx_err_budget_met,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'listing_creative_duration_check',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_listing_creative_duration_check,
    SUM(0) AS tx_err_advertiser_industry_restriction,
    SUM(0) AS tx_err_brand_blacklist_restriction,
    SUM(0) AS tx_err_advertiser_blacklist_restriction,
    SUM(0) AS tx_err_schedule_met,
    SUM(0) AS tx_err_slot_compatiblity_check,
    SUM(0) AS tx_err_rating_restriction,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'global_brand_restricted_by_inventory',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_global_brand_restricted_by_inventory,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'global_advertiser_restricted_by_inventory',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_global_advertiser_restricted_by_inventory,
    SUM(0) AS tx_err_blocked_by_inventory_source_optimization_imr,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'inbound_rule_targeting_not_met',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_inbound_rule_targeting_not_met,
    SUM(0) AS tx_err_inbound_rule_explicit_targeting_required,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'global_brand_restricted_by_listing',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_global_brand_restricted_by_listing,
    SUM(0) AS tx_err_low_ranking_in_buyer,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'industry_restricted_by_listing',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_industry_restricted_by_listing,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'wrapper_timeout',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_wrapper_timeout,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'wrapper_http_error',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_wrapper_http_error,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'no_valid_creative',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_no_valid_creative,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'unsupported_vast_version',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_unsupported_vast_version,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'floor_price_notmet',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_floor_price_notmet,
    SUM(0) AS tx_err_targeted_schedule_met,
    SUM(0) AS tx_err_targeted_budget_met,
    SUM(0) AS tx_err_yield_opt_met,
    SUM(0) AS tx_err_inflight_bid_met,
    SUM(0) AS tx_err_inbound_order_competition_failure,
    SUM(0) AS tx_err_competition_failure_in_pick_many,
    SUM(0) AS tx_err_find_rule_path_failure,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'global_advertiser_restricted_by_listing',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_global_advertiser_restricted_by_listing,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'no_slot_selected',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_no_slot_selected,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'no_advertiser_for_inventory_protection',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_no_advertiser_for_inventory_protection,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'ad_pending_approval',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_ad_pending_approval,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'jitt_rendition_required',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_jitt_rendition_required,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'industry_restricted_by_deal',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_industry_restricted_by_deal,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'invalid_compliance_for_inventory_protection',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_invalid_compliance_for_inventory_protection,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'auction_max_ad_duration_exceeded',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_auction_max_ad_duration_exceeded,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'compliance_not_approved',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_compliance_not_approved,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'global_brand_restricted_by_deal',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_global_brand_restricted_by_deal,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'frequency_cap_reached',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_frequency_cap_reached,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'mkpl_order_floor_price_not_met',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_mkpl_order_floor_price_not_met,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'brand_restricted_by_rule',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_brand_restricted_by_rule,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'mkpl_exchange_industry_floor_price_not_met',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_mkpl_exchange_industry_floor_price_not_met,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'no_brand_for_inventory_protection',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_no_brand_for_inventory_protection,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'compliance_check_failed',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_compliance_check_failed,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'global_advertiser_restricted_by_deal',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_global_advertiser_restricted_by_deal,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'rule_compliance_check_failed',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_rule_compliance_check_failed,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'kv_opt_out',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_kv_opt_out,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'timeout',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_timeout,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'generate_impression_failed',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_generate_impression_failed,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'coppa_unsupported',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_coppa_unsupported,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'http_error',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_http_error,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'blocked_by_bid_throttling',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_blocked_by_bid_throttling,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'us_privacy_unsupported',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_us_privacy_unsupported,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'dsp_status_pause',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_dsp_status_pause,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'blocked_by_traffic_control',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_blocked_by_traffic_control,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'lat_unsupported',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_lat_unsupported,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'no_bids',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_no_bids,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'blocked_by_inventory_source_optimization',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_blocked_by_inventory_source_optimization,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'dsp_status_inactive',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_dsp_status_inactive,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'candidate_no_bids',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_candidate_no_bids,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'gdpr_unsupported',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_gdpr_unsupported,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'exceed_server_concurrent_limit',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_exceed_server_concurrent_limit,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'no_valid_market_ad',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_no_valid_market_ad,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'unexpected_bid_dealid',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_unexpected_bid_dealid,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'unknown_seat',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_unknown_seat,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'invalid_wrapper_url',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_invalid_wrapper_url,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'empty_bid_dealid',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_empty_bid_dealid,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'no_ad_markup',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_no_ad_markup,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'inapplicable_for_https',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_inapplicable_for_https,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'unexpected_external_ad_id',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_unexpected_external_ad_id,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'restricted_seat_by_auction_network',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_restricted_seat_by_auction_network,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'no_valid_price',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_no_valid_price,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'no_valid_external_ad_id',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_no_valid_external_ad_id,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 4) = 0
        AND COALESCE(candidate__error, 'na') = 'mismatched_creative_duration_with_scheduled',
        COALESCE(request__decision_info__value13, 1),
        0
      )
    ) AS tx_err_mismatched_creative_duration_with_scheduled,
    CAST(0 AS BIGINT) AS slot_err_exceed_max_slot_duration,
    CAST(0 AS BIGINT) AS slot_err_exceed_max_num_advertisements,
    CAST(0 AS BIGINT) AS slot_err_adjacent_exclusivity,
    CAST(0 AS BIGINT) AS slot_err_back2back_excluded,
    CAST(0 AS BIGINT) AS slot_err_industry_separation_excluded,
    CAST(0 AS BIGINT) AS slot_err_exclusivity_by_slot,
    CAST(0 AS BIGINT) AS slot_err_adjacent_same_4a_id,
    CAST(0 AS BIGINT) AS slot_err_incompatible_rendition_file_size,
    CAST(0 AS BIGINT) AS slot_err_estimate_rendition_duration_for_live,
    CAST(0 AS BIGINT) AS slot_err_large_rendition_duration,
    CAST(0 AS BIGINT) AS slot_err_creative_api_banned,
    CAST(0 AS BIGINT) AS slot_err_no_applicable_profiles_for_rendition,
    CAST(0 AS BIGINT) AS slot_err_brand_separation_excluded,
    CAST(0 AS BIGINT) AS slot_err_advertiser_separation_excluded,
    CAST(0 AS BIGINT) AS slot_err_frequency_cap_reaching,
    CAST(0 AS BIGINT) AS slot_err_slot_filled_by_multi_ads,
    CAST(0 AS BIGINT) AS slot_err_position_occupied,
    CAST(0 AS BIGINT) AS slot_err_brand_frequency_cap_reaching,
    CAST(0 AS BIGINT) AS slot_err_swapped_out_of_slot,
    CAST(0 AS BIGINT) AS slot_err_ad_asset_store_inapplicable_bitrate,
    CAST(0 AS BIGINT) AS slot_err_ad_asset_store_not_available,
    CAST(0 AS BIGINT) AS slot_err_advertiser_frequency_cap_reaching,
    CAST(0 AS BIGINT) AS slot_err_clearcast_code_restricted,
    CAST(0 AS BIGINT) AS slot_err_from_same_header_bidding,
    CAST(0 AS BIGINT) AS slot_err_incompatible_flash_version,
    CAST(0 AS BIGINT) AS slot_err_low_ranking_in_buyer,
    CAST(0 AS BIGINT) AS slot_err_no_error,
    CAST(0 AS BIGINT) AS slot_err_restricted_by_openrtb_impression_bid_capping
  FROM ${bcv_candidate} AS c
  CROSS JOIN UNNEST(partners__entity_source, partners__inbound_order_id, partners__supply_source, partners__sales_channel, partners__network_id, partners__content_owner_network_id, partners__reseller_network_id, partners__site_id, partners__site_section_id, partners__standard_brand_visibility__report_aggregate, partners__standard_programmer_visibility__report_aggregate, partners__standard_endpoint_owner_visibility__report_aggregate, partners__standard_endpoint_visibility__report_aggregate, partners__geo_country_visibility__report_aggregate, partners__user_agent_visibility__report_aggregate, partners__outbound_listing_id) AS t1(entity_source, inbound_order_id, supply_source_type, sales_channel, network_id, content_owner_network_id, reseller_id, site_id, site_section_id, standard_brand_visibility__report_aggregate, standard_programmer_visibility__report_aggregate, standard_endpoint_owner_visibility__report_aggregate, standard_endpoint_visibility__report_aggregate, geo_country_visibility__report_aggregate, user_agent_visibility__report_aggregate, outbound_listing_id)
  WHERE
    (
      (
        (
          c.request__delivery_method IS NULL OR c.request__delivery_method <> 'casucpsu'
        )
        AND t1.entity_source = 'auction_upstream'
      )
      AND t1.sales_channel = 6
    )
    AND COALESCE(request__demand_log_magnifier, 0) > 0
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
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55
  UNION ALL
  SELECT
    CAST(2 AS INTEGER) AS process_stage,
    DATE_FORMAT(DATE_TRUNC('HOUR', c.request__timestamp), '%y-%m-%d %h:00:00') AS event_date,
    c.process_batch_id AS process_batch_id,
    COALESCE(t1.network_id, -1) AS network_id,
    COALESCE(t1.content_owner_network_id, -1) AS content_owner_id,
    'full_visibility' AS content_owner_visibility,
    IF(
      COALESCE(t1.supply_source_type, -1) = 1,
      COALESCE(c.request__context__network_id, -1),
      -1
    ) AS distributor_id,
    CASE
      WHEN COALESCE(t1.supply_source_type, -1) = 1
      AND c.request__context__video_cro_network_id = t1.network_id
      THEN 'cro'
      ELSE 'r'
    END AS transaction_type,
    COALESCE(t1.reseller_id, -1) AS reseller_id,
    'full_visibility' AS reseller_visibility,
    'full' AS reseller_network_type,
    COALESCE(t1.supply_source_type, -1) AS supply_source,
    'marketplace platform exchange' AS sales_channel,
    'marketplace platform exchange' AS sales_strategy,
    COALESCE(t1.site_id, -1) AS site_id,
    COALESCE(t1.site_section_id, -1) AS site_section_id,
    COALESCE(c.request__context__standard_publisher_id, -1) AS standard_publisher_id,
    COALESCE(c.request__context__standard_brand_id, -1) AS standard_brand_id,
    COALESCE(t1.standard_brand_visibility__report_aggregate, 'full_visibility') AS standard_brand_visibility,
    COALESCE(c.request__context__standard_programmer_id, -1) AS standard_programmer_id,
    COALESCE(t1.standard_programmer_visibility__report_aggregate, 'full_visibility') AS standard_programmer_visibility,
    COALESCE(c.request__context__content_form_id, -1) AS content_form_id,
    COALESCE(c.request__context__stream_mode_id, -1) AS stream_mode_id,
    COALESCE(c.request__context__standard_endpoint_owner_id, -1) AS standard_endpoint_owner_id,
    COALESCE(t1.standard_endpoint_owner_visibility__report_aggregate, 'full_visibility') AS standard_endpoint_owner_visibility,
    COALESCE(c.request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
    COALESCE(t1.standard_endpoint_visibility__report_aggregate, 'full_visibility') AS standard_endpoint_visibility,
    COALESCE(c.visitor__country_id, -1) AS user_country_id,
    COALESCE(t1.geo_country_visibility__report_aggregate, 'full_visibility') AS geo_country_visibility,
    COALESCE(c.visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
    COALESCE(c.request__context__standard_app_id, -1) AS standard_app_id,
    COALESCE(c.visitor__standard_environment_id, -1) AS standard_environment_id,
    COALESCE(c.visitor__standard_os_id, -1) AS standard_os_id,
    COALESCE(t1.user_agent_visibility__report_aggregate, 'full_visibility') AS user_agent_visibility,
    COALESCE(c.request__context__profile_id, -1) AS profile_id,
    'compound' AS profile_type,
    IF(BITWISE_AND(COALESCE(c.request__extra_flags, 0), 1024) > 0, 'true', 'false') AS live_linear_indicator,
    IF(BITWISE_AND(COALESCE(c.request__extra_flags2, 0), 8) > 0, 'true', 'false') AS ssp_bidder_indicator,
    'false' AS partner_tag_indicator,
    ARRAY[] AS time_position_classes,
    ARRAY[] AS slot_ad_unit_ids,
    CASE
      WHEN c.slot__sequence IS NULL
      THEN 'null'
      WHEN c.slot__sequence > 5
      THEN '5+'
      ELSE CAST(c.slot__sequence AS VARCHAR)
    END AS slot_sequence_normalized,
    'included' AS slot_user_drop_off,
    'not applicable' AS slot_removed_by_ux_indicator,
    'unknown' AS evergreen_ad_indicator,
    'unknown' AS promo_ad_indicator,
    CASE WHEN BITWISE_AND(c.request__flags, 64) > 0 THEN 1 ELSE 0 END AS request_traffic_type,
    0 AS ack_traffic_type,
    COALESCE(t1.outbound_listing_id, ARRAY[]) AS outbound_listing_id,
    ARRAY_DISTINCT(ARRAY_SORT(c.candidate__global_advertiser_ids)) AS global_advertiser_ids,
    ARRAY_DISTINCT(ARRAY_SORT(c.candidate__global_brand_ids)) AS global_brand_ids,
    -1 AS local_advertiser_id,
    ARRAY_DISTINCT(ARRAY_SORT(c.candidate__global_industry_ids)) AS global_industry_ids,
    CASE
      WHEN advertisement__slot_index = e.slot_index
      AND BITWISE_AND(candidate__bid_status, 8) > 0
      AND advertisement__is_fallback = FALSE
      THEN 'primary'
      WHEN advertisement__slot_index = e.slot_index
      AND BITWISE_AND(candidate__bid_status, 8) > 0
      AND advertisement__is_fallback
      THEN 'fallback'
      ELSE 'not applicable'
    END AS primary_ad_indicator,
    'programmatic' AS demand_type,
    CAST(0 AS BIGINT) AS candidate_ads,
    CAST(0 AS BIGINT) AS tx_eligible_ads,
    SUM(COALESCE(c.request__demand_log_magnifier, 0)) AS slot_eligible_ads,
    SUM(
      IF(
        advertisement__slot_index = e.slot_index
        AND BITWISE_AND(candidate__bid_status, 4) > 0
        AND advertisement__is_fallback = FALSE,
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS placed_ads_sampled,
    SUM(
      IF(
        advertisement__slot_index = e.slot_index
        AND BITWISE_AND(candidate__bid_status, 4) > 0
        AND advertisement__is_fallback = TRUE,
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS placed_fallback_ads_sampled,
    SUM(
      IF(
        advertisement__slot_index = e.slot_index
        AND BITWISE_AND(candidate__bid_status, 4) > 0
        AND advertisement__is_sstf_fallback = TRUE,
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS filled_ads_sstf_fallback_sampled,
    SUM(
      IF(
        advertisement__slot_index = e.slot_index
        AND BITWISE_AND(candidate__bid_status, 8) > 0,
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS selected_ads_sampled,
    CAST(0 AS BIGINT) AS gross_ad_views_sampled,
    CAST(0 AS BIGINT) AS placement_err_total,
    CAST(0 AS BIGINT) AS ad_err_total,
    SUM(
      IF(
        advertisement__slot_index = e.slot_index AND COALESCE(e.error, 'na') <> 'na',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_total,
    CAST(0 AS BIGINT) AS tx_err_malformed_response,
    CAST(0 AS BIGINT) AS tx_err_empty_response,
    CAST(0 AS BIGINT) AS tx_err_price_hurdle_check_failed,
    CAST(0 AS BIGINT) AS tx_err_profile_check_failed,
    CAST(0 AS BIGINT) AS tx_err_frequency_cap_failed,
    CAST(0 AS BIGINT) AS tx_err_not_allowed_upstream_network_for_ad,
    CAST(0 AS BIGINT) AS tx_err_reseller_whitelist_not_allowed,
    CAST(0 AS BIGINT) AS tx_err_reseller_blacklist_banned,
    CAST(0 AS BIGINT) AS tx_err_no_applicable_slot,
    CAST(0 AS BIGINT) AS tx_err_no_applicable_creative,
    CAST(0 AS BIGINT) AS tx_err_exceed_max_slot_duration,
    CAST(0 AS BIGINT) AS tx_err_competition_failure,
    CAST(0 AS BIGINT) AS tx_err_exclusivity_by_stream,
    CAST(0 AS BIGINT) AS tx_err_creative_restriction_check_failed,
    CAST(0 AS BIGINT) AS tx_err_ad_targeting_restricted,
    CAST(0 AS BIGINT) AS tx_err_budget_met,
    CAST(0 AS BIGINT) AS tx_err_listing_creative_duration_check,
    CAST(0 AS BIGINT) AS tx_err_advertiser_industry_restriction,
    CAST(0 AS BIGINT) AS tx_err_brand_blacklist_restriction,
    CAST(0 AS BIGINT) AS tx_err_advertiser_blacklist_restriction,
    CAST(0 AS BIGINT) AS tx_err_schedule_met,
    CAST(0 AS BIGINT) AS tx_err_slot_compatiblity_check,
    CAST(0 AS BIGINT) AS tx_err_rating_restriction,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_inventory,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_inventory,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_inventory_source_optimization_imr,
    CAST(0 AS BIGINT) AS tx_err_inbound_rule_targeting_not_met,
    CAST(0 AS BIGINT) AS tx_err_inbound_rule_explicit_targeting_required,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_low_ranking_in_buyer,
    CAST(0 AS BIGINT) AS tx_err_industry_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_wrapper_timeout,
    CAST(0 AS BIGINT) AS tx_err_wrapper_http_error,
    CAST(0 AS BIGINT) AS tx_err_no_valid_creative,
    CAST(0 AS BIGINT) AS tx_err_unsupported_vast_version,
    CAST(0 AS BIGINT) AS tx_err_floor_price_notmet,
    CAST(0 AS BIGINT) AS tx_err_targeted_schedule_met,
    CAST(0 AS BIGINT) AS tx_err_targeted_budget_met,
    CAST(0 AS BIGINT) AS tx_err_yield_opt_met,
    CAST(0 AS BIGINT) AS tx_err_inflight_bid_met,
    CAST(0 AS BIGINT) AS tx_err_inbound_order_competition_failure,
    CAST(0 AS BIGINT) AS tx_err_competition_failure_in_pick_many,
    CAST(0 AS BIGINT) AS tx_err_find_rule_path_failure,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_no_slot_selected,
    CAST(0 AS BIGINT) AS tx_err_no_advertiser_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_ad_pending_approval,
    CAST(0 AS BIGINT) AS tx_err_jitt_rendition_required,
    CAST(0 AS BIGINT) AS tx_err_industry_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_invalid_compliance_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_auction_max_ad_duration_exceeded,
    CAST(0 AS BIGINT) AS tx_err_compliance_not_approved,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_frequency_cap_reached,
    CAST(0 AS BIGINT) AS tx_err_mkpl_order_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_brand_restricted_by_rule,
    CAST(0 AS BIGINT) AS tx_err_mkpl_exchange_industry_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_no_brand_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_compliance_check_failed,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_deal,
    CAST(0 AS BIGINT) AS tx_err_rule_compliance_check_failed,
    CAST(0 AS BIGINT) AS tx_err_kv_opt_out,
    CAST(0 AS BIGINT) AS tx_err_timeout,
    CAST(0 AS BIGINT) AS tx_err_generate_impression_failed,
    CAST(0 AS BIGINT) AS tx_err_coppa_unsupported,
    CAST(0 AS BIGINT) AS tx_err_http_error,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_bid_throttling,
    CAST(0 AS BIGINT) AS tx_err_us_privacy_unsupported,
    CAST(0 AS BIGINT) AS tx_err_dsp_status_pause,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_traffic_control,
    CAST(0 AS BIGINT) AS tx_err_lat_unsupported,
    CAST(0 AS BIGINT) AS tx_err_no_bids,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_inventory_source_optimization,
    CAST(0 AS BIGINT) AS tx_err_dsp_status_inactive,
    CAST(0 AS BIGINT) AS tx_err_candidate_no_bids,
    CAST(0 AS BIGINT) AS tx_err_gdpr_unsupported,
    CAST(0 AS BIGINT) AS tx_err_exceed_server_concurrent_limit,
    CAST(0 AS BIGINT) AS tx_err_no_valid_market_ad,
    CAST(0 AS BIGINT) AS tx_err_unexpected_bid_dealid,
    CAST(0 AS BIGINT) AS tx_err_unknown_seat,
    CAST(0 AS BIGINT) AS tx_err_invalid_wrapper_url,
    CAST(0 AS BIGINT) AS tx_err_empty_bid_dealid,
    CAST(0 AS BIGINT) AS tx_err_no_ad_markup,
    CAST(0 AS BIGINT) AS tx_err_inapplicable_for_https,
    CAST(0 AS BIGINT) AS tx_err_unexpected_external_ad_id,
    CAST(0 AS BIGINT) AS tx_err_restricted_seat_by_auction_network,
    CAST(0 AS BIGINT) AS tx_err_no_valid_price,
    CAST(0 AS BIGINT) AS tx_err_no_valid_external_ad_id,
    CAST(0 AS BIGINT) AS tx_err_mismatched_creative_duration_with_scheduled,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'exceed_max_slot_duration',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_exceed_max_slot_duration,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'exceed_max_num_advertisements',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_exceed_max_num_advertisements,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'adjacent_exclusivity',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_adjacent_exclusivity,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'back2back_excluded',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_back2back_excluded,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'industry_separation_excluded',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_industry_separation_excluded,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'exclusivity_by_slot',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_exclusivity_by_slot,
    SUM(0) AS slot_err_adjacent_same_4a_id,
    SUM(0) AS slot_err_incompatible_rendition_file_size,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'estimate_rendition_duration_for_live',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_estimate_rendition_duration_for_live,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'large_rendition_duration',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_large_rendition_duration,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'creative_api_banned',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_creative_api_banned,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'no_applicable_profiles_for_rendition',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_no_applicable_profiles_for_rendition,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'brand_separation_excluded',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_brand_separation_excluded,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'advertiser_separation_excluded',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_advertiser_separation_excluded,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'frequency_cap_reaching',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_frequency_cap_reaching,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'slot_filled_by_multi_ads',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_slot_filled_by_multi_ads,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'position_occupied',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_position_occupied,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'brand_frequency_cap_reaching',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_brand_frequency_cap_reaching,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'swapped_out_of_slot',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_swapped_out_of_slot,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'ad_asset_store_inapplicable_bitrate',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_ad_asset_store_inapplicable_bitrate,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'ad_asset_store_not_available',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_ad_asset_store_not_available,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'advertiser_frequency_cap_reaching',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_advertiser_frequency_cap_reaching,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'clearcast_code_restricted',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_clearcast_code_restricted,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'from_same_header_bidding',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_from_same_header_bidding,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'incompatible_flash_version',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_incompatible_flash_version,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'low_ranking_in_buyer',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_low_ranking_in_buyer,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'no_error',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_no_error,
    SUM(
      IF(
        COALESCE(e.error, 'na') = 'restricted_by_openrtb_impression_bid_capping',
        COALESCE(c.request__demand_log_magnifier, 0),
        0
      )
    ) AS slot_err_restricted_by_openrtb_impression_bid_capping
  FROM ${bcv_candidate} AS c
  CROSS JOIN UNNEST(partners__entity_source, partners__inbound_order_id, partners__supply_source, partners__sales_channel, partners__network_id, partners__content_owner_network_id, partners__reseller_network_id, partners__site_id, partners__site_section_id, partners__standard_brand_visibility__report_aggregate, partners__standard_programmer_visibility__report_aggregate, partners__standard_endpoint_owner_visibility__report_aggregate, partners__standard_endpoint_visibility__report_aggregate, partners__geo_country_visibility__report_aggregate, partners__user_agent_visibility__report_aggregate, partners__outbound_listing_id) AS t1(entity_source, inbound_order_id, supply_source_type, sales_channel, network_id, content_owner_network_id, reseller_id, site_id, site_section_id, standard_brand_visibility__report_aggregate, standard_programmer_visibility__report_aggregate, standard_endpoint_owner_visibility__report_aggregate, standard_endpoint_visibility__report_aggregate, geo_country_visibility__report_aggregate, user_agent_visibility__report_aggregate, outbound_listing_id)
  CROSS JOIN UNNEST(CONCAT(
    candidate__filter_reason__slot_index,
    ARRAY[COALESCE(advertisement__slot_index, -1)]
  ), CONCAT(candidate__filter_reason__error, ARRAY['no_error'])) AS e(slot_index, error)
  WHERE
    (
      (
        (
          (
            c.request__delivery_method IS NULL OR c.request__delivery_method <> 'casucpsu'
          )
          AND COALESCE(e.slot_index, -1) > -1
        )
        AND t1.entity_source = 'auction_upstream'
      )
      AND t1.sales_channel = 6
    )
    AND COALESCE(c.request__demand_log_magnifier, 0) > 0
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
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    52,
    53,
    54,
    55
) AS f
LEFT JOIN db.default.d_network AS dist
  ON dist.id = f.distributor_id
LEFT JOIN db.default.d_network AS nw
  ON nw.id = f.network_id
LEFT JOIN db.default.d_network AS co
  ON co.id = f.content_owner_id
LEFT JOIN db.default.d_network AS reseller
  ON reseller.id = f.reseller_id
LEFT JOIN db.default.d_site_section AS section
  ON section.id = f.site_section_id
LEFT JOIN (
  SELECT
    site_id AS id,
    site_name AS name
  FROM db.default.d_site_section
  GROUP BY
    1,
    2
) AS site
  ON site.id = f.site_id
LEFT JOIN db.default.d_lu_mkpl_standard_brand AS brand
  ON brand.id = f.standard_brand_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS endpoint
  ON endpoint.id = f.standard_endpoint_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS endpoint_owner
  ON endpoint_owner.id = f.standard_endpoint_owner_id
LEFT JOIN db.default.d_lu_mkpl_standard_programmer AS programmer
  ON programmer.id = f.standard_programmer_id
LEFT JOIN db.default.d_lu_mkpl_standard_content_form AS content_form
  ON content_form.id = f.content_form_id
LEFT JOIN db.default.d_lu_mkpl_stream_mode AS stream
  ON stream.id = f.stream_mode_id
LEFT JOIN db.default.d_lu_mkpl_standard_publisher AS publisher
  ON publisher.id = f.standard_publisher_id
LEFT JOIN db.default.d_country AS country
  ON country.id = f.user_country_id
LEFT JOIN db.default.d_advertiser AS local_adv
  ON local_adv.id = f.local_advertiser_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = f.profile_id
GROUP BY
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
  35,
  36,
  37,
  38,
  39,
  40,
  41,
  42,
  43,
  44,
  45,
  46,
  47,
  48,
  49,
  50,
  51,
  52,
  53,
  54,
  55,
  56,
  57,
  58,
  59,
  60,
  61,
  62,
  63,
  64,
  65,
  66
