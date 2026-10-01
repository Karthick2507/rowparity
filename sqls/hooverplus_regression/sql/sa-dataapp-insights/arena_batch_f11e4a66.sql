-- account:    sa-dataapp-insights
-- skeleton:   9092154c387f16b5bdb573606170c47b
-- pattern:    f11e4a66ee02624e0d3e49fad7ab79f2  (302 execution(s))
-- in suite:   column coverage
-- hoover:     ack, auction, candidate, slot
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   dt = DATE_FORMAT(DATE_PARSE(?, ?), ?)
--   process_batch_id = ?

SELECT
  REDUCE(SET_AGG(process_stage), 0, (acc, val) -> acc + val, val -> val) AS process_stage,
  f.network_id,
  f.stream_mode_id,
  f.standard_brand_id,
  f.standard_brand_visibility,
  f.standard_programmer_id,
  f.standard_programmer_visibility,
  f.standard_endpoint_id,
  f.standard_endpoint_visibility,
  f.standard_endpoint_owner_id,
  f.standard_endpoint_owner_visibility,
  f.standard_device_type_id,
  f.user_agent_visibility,
  f.user_country_id,
  f.geo_country_visibility,
  f.global_advertiser_ids,
  f.global_brand_ids,
  f.outbound_exchange_listing_ids,
  6 AS sales_channel,
  f.slot_user_drop_off,
  f.request_traffic_type,
  f.ack_traffic_type,
  f.process_batch_id,
  f.event_date,
  SUM(f.outbound_exchange_opportunity) AS outbound_exchange_opportunity,
  SUM(f.targeted_listings) AS targeted_listings,
  SUM(f.effective_listings) AS effective_listings,
  SUM(f.candidated_listings) AS candidated_listings,
  SUM(f.expanded_listings) AS expanded_listings,
  SUM(f.listing_err_total) AS listing_err_total,
  SUM(f.listing_err_unknown) AS listing_err_unknown,
  SUM(f.listing_err_out_of_schedule) AS listing_err_out_of_schedule,
  SUM(f.listing_err_split_source_target_not_met) AS listing_err_split_source_target_not_met,
  SUM(f.listing_err_supply_source_target_not_met) AS listing_err_supply_source_target_not_met,
  SUM(f.listing_err_programmatic_banned) AS listing_err_programmatic_banned,
  SUM(f.listing_err_exchange_banned) AS listing_err_exchange_banned,
  SUM(f.listing_err_met_volume_cap) AS listing_err_met_volume_cap,
  SUM(f.listing_err_no_applicable_slots) AS listing_err_no_applicable_slots,
  SUM(f.ad_err_total) AS ad_err_total,
  SUM(f.ad_err_ad_pending_approval) AS ad_err_ad_pending_approval,
  SUM(f.ad_err_ad_rejected) AS ad_err_ad_rejected,
  SUM(f.ad_err_competition_failure) AS ad_err_competition_failure,
  SUM(f.ad_err_listing_advertiser_restriction) AS ad_err_listing_advertiser_restriction,
  SUM(f.ad_err_listing_brand_restriction) AS ad_err_listing_brand_restriction,
  SUM(f.ad_err_listing_industry_restriction) AS ad_err_listing_industry_restriction,
  SUM(f.ad_err_listing_seat_restriction) AS ad_err_listing_seat_restriction,
  SUM(f.ad_err_listing_creative_duration_restriction) AS ad_err_listing_creative_duration_restriction,
  SUM(f.ad_err_profile_check_failed) AS ad_err_profile_check_failed,
  SUM(f.ad_err_listing_advertiser_floor_price_not_met) AS ad_err_listing_advertiser_floor_price_not_met,
  SUM(f.ad_err_listing_brand_floor_price_not_met) AS ad_err_listing_brand_floor_price_not_met,
  SUM(f.ad_err_listing_industry_floor_price_not_met) AS ad_err_listing_industry_floor_price_not_met,
  SUM(f.ad_err_listing_seat_floor_price_not_met) AS ad_err_listing_seat_floor_price_not_met,
  SUM(f.ad_err_demand_partner_disallowed_by_profile) AS ad_err_demand_partner_disallowed_by_profile,
  SUM(f.ad_err_lat_unsupported) AS ad_err_lat_unsupported,
  SUM(f.ad_err_ccpa_gpp_us_privacy_opt_out) AS ad_err_ccpa_gpp_us_privacy_opt_out,
  SUM(f.ad_err_coppa_unsupported) AS ad_err_coppa_unsupported,
  SUM(f.ad_err_apple_app_tracking_transparency_unsupported) AS ad_err_apple_app_tracking_transparency_unsupported,
  SUM(f.ad_err_kv_unsupported) AS ad_err_kv_unsupported,
  SUM(f.ad_err_no_tcp_consent) AS ad_err_no_tcp_consent,
  SUM(f.ad_err_gpp_not_supported) AS ad_err_gpp_not_supported,
  SUM(f.ad_err_gpp_spi_opt_out) AS ad_err_gpp_spi_opt_out,
  SUM(f.slot_err_competition_failure) AS slot_err_competition_failure,
  SUM(f.slot_err_adjacent_ads_exclusivity) AS slot_err_adjacent_ads_exclusivity,
  SUM(f.slot_err_adjacent_same_4a_id) AS slot_err_adjacent_same_4a_id,
  SUM(f.slot_err_advertiser_frequency_cap_reaching) AS slot_err_advertiser_frequency_cap_reaching,
  SUM(f.slot_err_inventory_protection_advertiser) AS slot_err_inventory_protection_advertiser,
  SUM(f.slot_err_back_to_back_exclusivity) AS slot_err_back_to_back_exclusivity,
  SUM(f.slot_err_brand_frequency_cap_reaching) AS slot_err_brand_frequency_cap_reaching,
  SUM(f.slot_err_inventory_protection_brand) AS slot_err_inventory_protection_brand,
  SUM(f.slot_err_clearcast_restriction) AS slot_err_clearcast_restriction,
  SUM(f.slot_err_cro_advertiser_frequency_cap_reaching) AS slot_err_cro_advertiser_frequency_cap_reaching,
  SUM(f.slot_err_cro_brand_frequency_cap_reaching) AS slot_err_cro_brand_frequency_cap_reaching,
  SUM(f.slot_err_max_number_of_ads_exceeded) AS slot_err_max_number_of_ads_exceeded,
  SUM(f.slot_err_max_slot_duration_exceeded) AS slot_err_max_slot_duration_exceeded,
  SUM(f.slot_err_slot_exclusivity) AS slot_err_slot_exclusivity,
  SUM(f.slot_err_frequency_cap_reaching) AS slot_err_frequency_cap_reaching,
  SUM(f.slot_err_header_bidding_repeating_key_value_exclusivity) AS slot_err_header_bidding_repeating_key_value_exclusivity,
  SUM(f.slot_err_inventory_protection_industry) AS slot_err_inventory_protection_industry,
  SUM(f.slot_err_sequency_variat_targeting_failed) AS slot_err_sequency_variat_targeting_failed,
  SUM(f.slot_err_dsp_bid_cap_reaching) AS slot_err_dsp_bid_cap_reaching,
  SUM(f.slot_err_excluded_by_pod_ads) AS slot_err_excluded_by_pod_ads,
  SUM(f.slot_err_other) AS slot_err_other,
  SUM(f.listing_err_no_compatible_slots) AS listing_err_no_compatible_slots,
  f.supply_source,
  f.content_owner_id,
  f.inbound_order_id,
  f.standard_app_bundle_id,
  f.standard_site_domain_id,
  'full_visibility' AS content_owner_visibility,
  SUM(f.listing_err_blocked_by_bidder_private_auction) AS listing_err_blocked_by_bidder_private_auction,
  SUM(f.listing_err_blocked_by_pg_only_ad_request) AS listing_err_blocked_by_pg_only_ad_request,
  SUM(f.listing_err_restricted_by_pick_one_logic) AS listing_err_restricted_by_pick_one_logic,
  SUM(f.listing_err_no_available_exchange_buyer) AS listing_err_no_available_exchange_buyer,
  SUM(f.listing_err_blocked_by_buyer_exclusion) AS listing_err_blocked_by_buyer_exclusion,
  SUM(f.listing_err_blocked_by_exchange_filter) AS listing_err_blocked_by_exchange_filter,
  f.market_ad_id,
  f.primary_ad_indicator,
  SUM(f.bid_requests) AS bid_requests,
  SUM(f.opportunities_in_bid_request) AS opportunities_in_bid_request,
  SUM(f.received_bids) AS received_bids,
  SUM(f.failed_bids) AS failed_bids,
  SUM(f.resolved_bids) AS resolved_bids,
  SUM(f.filtered_bids) AS filtered_bids,
  SUM(f.selected_bids) AS selected_bids,
  SUM(ad_err_creative_not_applicable) AS ad_err_creative_not_applicable,
  SUM(ad_err_deal_floor_price_not_met) AS ad_err_deal_floor_price_not_met,
  SUM(ad_err_empty_deal_id) AS ad_err_empty_deal_id,
  SUM(ad_err_empty_vast) AS ad_err_empty_vast,
  SUM(ad_err_invalid_vast_wrapper_url) AS ad_err_invalid_vast_wrapper_url,
  SUM(ad_err_malformed_vast_xml) AS ad_err_malformed_vast_xml,
  SUM(ad_err_mismatched_seat_id) AS ad_err_mismatched_seat_id,
  SUM(ad_err_network_item_advertiser_restriction) AS ad_err_network_item_advertiser_restriction,
  SUM(ad_err_network_item_brand_restriction) AS ad_err_network_item_brand_restriction,
  SUM(ad_err_network_item_industry_restriction) AS ad_err_network_item_industry_restriction,
  SUM(ad_err_no_ad_in_vast) AS ad_err_no_ad_in_vast,
  SUM(ad_err_no_jitt_rendition) AS ad_err_no_jitt_rendition,
  SUM(ad_err_non_secure_ad) AS ad_err_non_secure_ad,
  SUM(ad_err_yield_optimization_cap_reached) AS ad_err_yield_optimization_cap_reached,
  SUM(ad_err_exclusivity) AS ad_err_exclusivity,
  SUM(ad_err_standard_attribute_industry_restriction) AS ad_err_standard_attribute_industry_restriction,
  SUM(ad_err_upstream_order_floor_price_not_met) AS ad_err_upstream_order_floor_price_not_met,
  SUM(ad_err_vast_wrapper_http_error) AS ad_err_vast_wrapper_http_error,
  SUM(ad_err_vast_wrapper_timeout) AS ad_err_vast_wrapper_timeout,
  SUM(ad_err_empty_bid_id) AS ad_err_empty_bid_id,
  SUM(ad_err_unsupported_vast_version) AS ad_err_unsupported_vast_version,
  SUM(ad_err_empty_vast_ad_markup) AS ad_err_empty_vast_ad_markup,
  SUM(ad_err_mismatched_deal_id) AS ad_err_mismatched_deal_id,
  SUM(ad_err_demand_partner_unsupported_on_external_ssp_supply) AS ad_err_demand_partner_unsupported_on_external_ssp_supply,
  SUM(ad_err_mismatched_ad_id) AS ad_err_mismatched_ad_id,
  SUM(ad_err_creative_restriction_failure) AS ad_err_creative_restriction_failure,
  SUM(ad_err_inbound_order_competition_failure) AS ad_err_inbound_order_competition_failure,
  SUM(ad_err_advertiser_domain_restricted) AS ad_err_advertiser_domain_restricted,
  SUM(ad_err_ad_duration_exceeded) AS ad_err_ad_duration_exceeded,
  SUM(ad_err_creative_duration_mismatched) AS ad_err_creative_duration_mismatched,
  SUM(ad_err_no_slot_selected) AS ad_err_no_slot_selected,
  SUM(ad_err_unknown) AS ad_err_unknown,
  SUM(slot_err_profile_check_failed) AS slot_err_profile_check_failed,
  SUM(slot_err_adstor_creative_unavailable) AS slot_err_adstor_creative_unavailable,
  SUM(slot_err_creative_ad_unit_duration_incompatible) AS slot_err_creative_ad_unit_duration_incompatible,
  SUM(slot_err_creative_profile_incompatible) AS slot_err_creative_profile_incompatible,
  SUM(slot_err_estimated_duration_disabled_for_live_inventory) AS slot_err_estimated_duration_disabled_for_live_inventory,
  SUM(slot_err_adstor_linear_creative_unavailable) AS slot_err_adstor_linear_creative_unavailable,
  f.standard_channel_id,
  f.standard_channel_visibility,
  f.site_section_id,
  SUM(ad_err_yield_optimization_rule_met) AS ad_err_yield_optimization_rule_met,
  f.process_batch_id AS partition_key
FROM (
  SELECT
    2 AS process_stage,
    DATE_FORMAT(DATE_PARSE(dt, '%y-%m-%d-%h'), '%y%m%d%h0000') AS process_batch_id,
    DATE_TRUNC('HOUR', FROM_UNIXTIME(timestamp)) AS event_date,
    COALESCE(network.network_id, -1) AS network_id,
    'included' AS slot_user_drop_off,
    CASE
      WHEN COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated'
      THEN 1
      WHEN COALESCE(network.supply_source_type, 'unknown') = 'mrm_rule'
      THEN 3
      WHEN COALESCE(network.supply_source_type, 'unknown') = 'mpp'
      THEN 5
      WHEN COALESCE(network.supply_source_type, 'unknown') = 'mpe'
      THEN 6
      ELSE -1
    END AS supply_source,
    CASE
      WHEN COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated'
      THEN COALESCE(network.upstream_network_id, COALESCE(network.network_id, -1))
      WHEN COALESCE(network.supply_source_type, 'unknown') = 'mrm_rule'
      THEN -1
      ELSE COALESCE(network.upstream_network_id, -1)
    END AS content_owner_id,
    COALESCE(network.inbound_order.order_id, -1) AS inbound_order_id,
    CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 1 ELSE 0 END AS request_traffic_type,
    0 AS ack_traffic_type,
    COALESCE(network.site_section_id, -1) AS site_section_id,
    COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), -1) AS stream_mode_id,
    IF(
      NOT network.data_right.standard_brand_visibility.report_aggregate IS NULL
      OR network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_brand_id, -1),
      -1
    ) AS standard_brand_id,
    COALESCE(network.data_right.standard_brand_visibility.report_aggregate, 'full_visibility') AS standard_brand_visibility,
    IF(
      NOT network.data_right.standard_programmer_visibility.report_aggregate IS NULL
      OR network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_programmer_id, -1),
      -1
    ) AS standard_programmer_id,
    COALESCE(
      network.data_right.standard_programmer_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_programmer_visibility,
    IF(
      NOT network.data_right.standard_endpoint_visibility.report_aggregate IS NULL
      OR network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_endpoint_id, -1),
      -1
    ) AS standard_endpoint_id,
    COALESCE(
      network.data_right.standard_endpoint_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_endpoint_visibility,
    IF(
      NOT network.data_right.standard_endpoint_owner_visibility.report_aggregate IS NULL
      OR network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_endpoint_owner_id, -1),
      -1
    ) AS standard_endpoint_owner_id,
    COALESCE(
      network.data_right.standard_endpoint_owner_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_endpoint_owner_visibility,
    IF(
      CARDINALITY(request.standard_device_type_ids) > 0,
      COALESCE(ELEMENT_AT(request.standard_device_type_ids, -1), -1),
      -1
    ) AS standard_device_type_id,
    COALESCE(network.data_right.user_agent_visibility.report_aggregate, 'full_visibility') AS user_agent_visibility,
    COALESCE(request.country_id, -1) AS user_country_id,
    COALESCE(network.data_right.geo_country_visibility.report_aggregate, 'full_visibility') AS geo_country_visibility,
    COALESCE(request.standard_app_bundle_id, -1) AS standard_app_bundle_id,
    COALESCE(request.standard_site_domain_id, -1) AS standard_site_domain_id,
    IF(
      NOT network.data_right.standard_channel_visibility.report_aggregate IS NULL
      OR network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_channel_id, -1),
      -1
    ) AS standard_channel_id,
    COALESCE(network.data_right.standard_channel_visibility.report_aggregate, 'full_visibility') AS standard_channel_visibility,
    ARRAY[] AS global_advertiser_ids,
    ARRAY[] AS global_brand_ids,
    ARRAY[COALESCE(t.listing_id, -1)] AS outbound_exchange_listing_ids,
    -1 AS market_ad_id,
    'not applicable' AS primary_ad_indicator,
    0 AS bid_requests,
    0 AS opportunities_in_bid_request,
    0 AS received_bids,
    0 AS failed_bids,
    0 AS resolved_bids,
    0 AS filtered_bids,
    0 AS selected_bids,
    0 AS outbound_exchange_opportunity,
    SUM(
      IF(BITWISE_AND(COALESCE(t.selection_status, 0), 1) > 0, COALESCE(magnifier, 1), 0)
    ) AS targeted_listings,
    SUM(
      IF(BITWISE_AND(COALESCE(t.selection_status, 0), 2) > 0, COALESCE(magnifier, 1), 0)
    ) AS effective_listings,
    SUM(
      IF(BITWISE_AND(COALESCE(t.selection_status, 0), 4) > 0, COALESCE(magnifier, 1), 0)
    ) AS candidated_listings,
    SUM(
      IF(BITWISE_AND(COALESCE(t.selection_status, 0), 8) > 0, COALESCE(magnifier, 1), 0)
    ) AS expanded_listings,
    SUM(IF(COALESCE(t.error, 0) <> 0, COALESCE(magnifier, 1), 0)) AS listing_err_total,
    SUM(IF(COALESCE(t.error, 0) = -1, COALESCE(magnifier, 1), 0)) AS listing_err_unknown,
    SUM(IF(COALESCE(t.error, 0) = 1601, COALESCE(magnifier, 1), 0)) AS listing_err_out_of_schedule,
    SUM(IF(COALESCE(t.error, 0) = 1602, COALESCE(magnifier, 1), 0)) AS listing_err_split_source_target_not_met,
    SUM(IF(COALESCE(t.error, 0) = 1603, COALESCE(magnifier, 1), 0)) AS listing_err_supply_source_target_not_met,
    SUM(IF(COALESCE(t.error, 0) = 1604, COALESCE(magnifier, 1), 0)) AS listing_err_programmatic_banned,
    SUM(IF(COALESCE(t.error, 0) = 1605, COALESCE(magnifier, 1), 0)) AS listing_err_exchange_banned,
    SUM(IF(COALESCE(t.error, 0) = 1606, COALESCE(magnifier, 1), 0)) AS listing_err_met_volume_cap,
    SUM(IF(COALESCE(t.error, 0) = 1607, COALESCE(magnifier, 1), 0)) AS listing_err_no_applicable_slots,
    SUM(IF(COALESCE(t.error, 0) = 1608, COALESCE(magnifier, 1), 0)) AS listing_err_no_compatible_slots,
    SUM(IF(COALESCE(t.error, 0) = 1610, COALESCE(magnifier, 1), 0)) AS listing_err_blocked_by_bidder_private_auction,
    SUM(IF(COALESCE(t.error, 0) = 1611, COALESCE(magnifier, 1), 0)) AS listing_err_blocked_by_pg_only_ad_request,
    SUM(IF(COALESCE(t.error, 0) = 1612, COALESCE(magnifier, 1), 0)) AS listing_err_restricted_by_pick_one_logic,
    SUM(IF(COALESCE(t.error, 0) = 1613, COALESCE(magnifier, 1), 0)) AS listing_err_no_available_exchange_buyer,
    SUM(IF(COALESCE(t.error, 0) = 1614, COALESCE(magnifier, 1), 0)) AS listing_err_blocked_by_buyer_exclusion,
    SUM(IF(COALESCE(t.error, 0) = 1615, COALESCE(magnifier, 1), 0)) AS listing_err_blocked_by_exchange_filter,
    0 AS ad_err_total,
    0 AS ad_err_ad_pending_approval,
    0 AS ad_err_ad_rejected,
    0 AS ad_err_competition_failure,
    0 AS ad_err_listing_advertiser_restriction,
    0 AS ad_err_listing_brand_restriction,
    0 AS ad_err_listing_industry_restriction,
    0 AS ad_err_listing_seat_restriction,
    0 AS ad_err_listing_creative_duration_restriction,
    0 AS ad_err_profile_check_failed,
    0 AS ad_err_listing_advertiser_floor_price_not_met,
    0 AS ad_err_listing_brand_floor_price_not_met,
    0 AS ad_err_listing_industry_floor_price_not_met,
    0 AS ad_err_listing_seat_floor_price_not_met,
    0 AS ad_err_demand_partner_disallowed_by_profile,
    0 AS ad_err_lat_unsupported,
    0 AS ad_err_ccpa_gpp_us_privacy_opt_out,
    0 AS ad_err_coppa_unsupported,
    0 AS ad_err_apple_app_tracking_transparency_unsupported,
    0 AS ad_err_kv_unsupported,
    0 AS ad_err_no_tcp_consent,
    0 AS ad_err_gpp_not_supported,
    0 AS ad_err_gpp_spi_opt_out,
    0 AS ad_err_creative_not_applicable,
    0 AS ad_err_deal_floor_price_not_met,
    0 AS ad_err_empty_deal_id,
    0 AS ad_err_empty_vast,
    0 AS ad_err_invalid_vast_wrapper_url,
    0 AS ad_err_malformed_vast_xml,
    0 AS ad_err_mismatched_seat_id,
    0 AS ad_err_network_item_advertiser_restriction,
    0 AS ad_err_network_item_brand_restriction,
    0 AS ad_err_network_item_industry_restriction,
    0 AS ad_err_no_ad_in_vast,
    0 AS ad_err_no_jitt_rendition,
    0 AS ad_err_non_secure_ad,
    0 AS ad_err_yield_optimization_cap_reached,
    0 AS ad_err_exclusivity,
    0 AS ad_err_standard_attribute_industry_restriction,
    0 AS ad_err_upstream_order_floor_price_not_met,
    0 AS ad_err_vast_wrapper_http_error,
    0 AS ad_err_vast_wrapper_timeout,
    0 AS ad_err_empty_bid_id,
    0 AS ad_err_unsupported_vast_version,
    0 AS ad_err_empty_vast_ad_markup,
    0 AS ad_err_mismatched_deal_id,
    0 AS ad_err_demand_partner_unsupported_on_external_ssp_supply,
    0 AS ad_err_mismatched_ad_id,
    0 AS ad_err_creative_restriction_failure,
    0 AS ad_err_inbound_order_competition_failure,
    0 AS ad_err_advertiser_domain_restricted,
    0 AS ad_err_ad_duration_exceeded,
    0 AS ad_err_creative_duration_mismatched,
    0 AS ad_err_yield_optimization_rule_met,
    0 AS ad_err_no_slot_selected,
    0 AS ad_err_unknown,
    0 AS slot_err_competition_failure,
    0 AS slot_err_adjacent_ads_exclusivity,
    0 AS slot_err_adjacent_same_4a_id,
    0 AS slot_err_advertiser_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_advertiser,
    0 AS slot_err_back_to_back_exclusivity,
    0 AS slot_err_brand_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_brand,
    0 AS slot_err_clearcast_restriction,
    0 AS slot_err_cro_advertiser_frequency_cap_reaching,
    0 AS slot_err_cro_brand_frequency_cap_reaching,
    0 AS slot_err_max_number_of_ads_exceeded,
    0 AS slot_err_max_slot_duration_exceeded,
    0 AS slot_err_slot_exclusivity,
    0 AS slot_err_frequency_cap_reaching,
    0 AS slot_err_header_bidding_repeating_key_value_exclusivity,
    0 AS slot_err_inventory_protection_industry,
    0 AS slot_err_sequency_variat_targeting_failed,
    0 AS slot_err_dsp_bid_cap_reaching,
    0 AS slot_err_excluded_by_pod_ads,
    0 AS slot_err_other,
    0 AS slot_err_profile_check_failed,
    0 AS slot_err_adstor_creative_unavailable,
    0 AS slot_err_creative_ad_unit_duration_incompatible,
    0 AS slot_err_creative_profile_incompatible,
    0 AS slot_err_estimated_duration_disabled_for_live_inventory,
    0 AS slot_err_adstor_linear_creative_unavailable
  FROM db.troubleshooting_log.fw_ads_demand_troubleshooting_log
  CROSS JOIN UNNEST(outbound_exchange_listing_selection_info) AS t
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
    33
  UNION ALL
  SELECT
    8 AS process_stage,
    process_batch_id AS process_batch_id,
    DATE_TRUNC('HOUR', request__timestamp) AS event_date,
    COALESCE(nw.network_id, -1) AS network_id,
    'included' AS slot_user_drop_off,
    COALESCE(nw.supply_source, -1) AS supply_source,
    COALESCE(nw.content_owner_network_id, -1) AS content_owner_network_id,
    COALESCE(nw.inbound_order_id, -1) AS inbound_order_id,
    COALESCE(request__traffic_type, 0) AS request_traffic_type,
    0 AS ack_traffic_type,
    COALESCE(nw.site_section_id, -1) AS site_section_id,
    COALESCE(request__context__stream_mode_id, -1) AS stream_mode_id,
    COALESCE(request__context__standard_brand_id, -1) AS standard_brand_id,
    COALESCE(nw.brand_visibility, 'full_visibility') AS standard_brand_visibility,
    COALESCE(request__context__standard_programmer_id, -1) AS standard_programmer_id,
    COALESCE(nw.programmer_visibility, 'full_visibility') AS standard_programmer_visibility,
    COALESCE(request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
    COALESCE(nw.endpoint_visibility, 'full_visibility') AS standard_endpoint_visibility,
    COALESCE(request__context__standard_endpoint_owner_id, -1) AS standard_endpoint_owner_id,
    COALESCE(nw.endpoint_owner_visibility, 'full_visibility') AS standard_endpoint_owner_visibility,
    COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
    COALESCE(nw.user_agent_visibility, 'full_visibility') AS user_agent_visibility,
    COALESCE(visitor__country_id, -1) AS user_country_id,
    COALESCE(nw.country_visibility, 'full_visibility') AS geo_country_visibility,
    COALESCE(request__context__standard_app_bundle_id, -1) AS standard_app_bundle_id,
    COALESCE(request__context__standard_site_domain_id, -1) AS standard_site_domain_id,
    COALESCE(request__context__standard_channel_id, -1) AS standard_channel_id,
    COALESCE(nw.sa_channel_visibility, 'full_visibility') AS standard_channel_visibility,
    COALESCE(candidate__global_advertiser_ids, ARRAY[]) AS global_advertiser_ids,
    COALESCE(candidate__global_brand_ids, ARRAY[]) AS global_brand_ids,
    COALESCE(nw.outbound_listing_id, ARRAY[]) AS outbound_exchange_listing_ids,
    COALESCE(candidate__market_ad_id, -1) AS market_ad_id,
    CASE
      WHEN advertisement__is_fallback IS NULL
      THEN 'not applicable'
      WHEN advertisement__is_fallback = TRUE
      THEN 'fallback'
      ELSE 'primary'
    END AS primary_ad_indicator,
    0 AS bid_requests,
    0 AS opportunities_in_bid_request,
    SUM(IF(BITWISE_AND(candidate__bid_status, 1) > 0, 1, 0)) AS received_bids,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 1) > 0
        AND BITWISE_AND(candidate__bid_status, 2) = 0,
        1,
        0
      )
    ) AS failed_bids,
    SUM(IF(BITWISE_AND(candidate__bid_status, 2) > 0, 1, 0)) AS resolved_bids,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 2) > 0
        AND BITWISE_AND(candidate__bid_status, 8) = 0,
        1,
        0
      )
    ) AS filtered_bids,
    SUM(IF(BITWISE_AND(candidate__bid_status, 8) > 0, 1, 0)) AS selected_bids,
    0 AS outbound_exchange_opportunity,
    0 AS targeted_listings,
    0 AS effective_listings,
    0 AS candidated_listings,
    0 AS expanded_listings,
    0 AS listing_err_total,
    0 AS listing_err_unknown,
    0 AS listing_err_out_of_schedule,
    0 AS listing_err_split_source_target_not_met,
    0 AS listing_err_supply_source_target_not_met,
    0 AS listing_err_programmatic_banned,
    0 AS listing_err_exchange_banned,
    0 AS listing_err_met_volume_cap,
    0 AS listing_err_no_applicable_slots,
    0 AS listing_err_no_compatible_slots,
    0 AS listing_err_blocked_by_bidder_private_auction,
    0 AS listing_err_blocked_by_pg_only_ad_request,
    0 AS listing_err_restricted_by_pick_one_logic,
    0 AS listing_err_no_available_exchange_buyer,
    0 AS listing_err_blocked_by_buyer_exclusion,
    0 AS listing_err_blocked_by_exchange_filter,
    SUM(1) AS ad_err_total,
    SUM(IF(candidate__error = 'ad_pending_approval', 1, 0)) AS ad_err_ad_pending_approval,
    SUM(IF(candidate__error = 'compliance_not_approved', 1, 0)) AS ad_err_ad_rejected,
    SUM(IF(candidate__error = 'competition_failure', 1, 0)) AS ad_err_competition_failure,
    SUM(IF(candidate__error = 'global_advertiser_restricted_by_listing', 1, 0)) AS ad_err_listing_advertiser_restriction,
    SUM(IF(candidate__error = 'global_brand_restricted_by_listing', 1, 0)) AS ad_err_listing_brand_restriction,
    SUM(IF(candidate__error = 'industry_restricted_by_listing', 1, 0)) AS ad_err_listing_industry_restriction,
    SUM(IF(candidate__error = 'restricted_seat_by_mkpl_exchange', 1, 0)) AS ad_err_listing_seat_restriction,
    SUM(IF(candidate__error = 'listing_creative_duration_check', 1, 0)) AS ad_err_listing_creative_duration_restriction,
    SUM(
      IF(
        candidate__error IN ('external_creative_profile_check_failed', 'profile_check_failed'),
        1,
        0
      )
    ) AS ad_err_profile_check_failed,
    SUM(IF(candidate__error = 'mkpl_exchange_advertiser_floor_price_not_met', 1, 0)) AS ad_err_listing_advertiser_floor_price_not_met,
    SUM(IF(candidate__error = 'mkpl_exchange_brand_floor_price_not_met', 1, 0)) AS ad_err_listing_brand_floor_price_not_met,
    SUM(IF(candidate__error = 'mkpl_exchange_industry_floor_price_not_met', 1, 0)) AS ad_err_listing_industry_floor_price_not_met,
    SUM(IF(candidate__error = 'mkpl_exchange_seat_floor_price_not_met', 1, 0)) AS ad_err_listing_seat_floor_price_not_met,
    SUM(IF(candidate__error = 'dsp_blocked_by_profile', 1, 0)) AS ad_err_demand_partner_disallowed_by_profile,
    SUM(IF(candidate__error = 'lat_unsupported', 1, 0)) AS ad_err_lat_unsupported,
    SUM(IF(candidate__error = 'us_privacy_unsupported', 1, 0)) AS ad_err_ccpa_gpp_us_privacy_opt_out,
    SUM(IF(candidate__error = 'coppa_unsupported', 1, 0)) AS ad_err_coppa_unsupported,
    SUM(IF(candidate__error = 'atts_unsupported', 1, 0)) AS ad_err_apple_app_tracking_transparency_unsupported,
    SUM(IF(candidate__error = 'kv_opt_out', 1, 0)) AS ad_err_kv_unsupported,
    SUM(IF(candidate__error = 'gdpr_unsupported', 1, 0)) AS ad_err_no_tcp_consent,
    SUM(IF(candidate__error = 'gpp_unsupported', 1, 0)) AS ad_err_gpp_not_supported,
    SUM(IF(candidate__error = 'gpp_spi_unsupported', 1, 0)) AS ad_err_gpp_spi_opt_out,
    SUM(IF(candidate__error = 'no_applicable_creative', 1, 0)) AS ad_err_creative_not_applicable,
    SUM(IF(candidate__error = 'floor_price_notmet', 1, 0)) AS ad_err_deal_floor_price_not_met,
    SUM(IF(candidate__error = 'empty_bid_dealid', 1, 0)) AS ad_err_empty_deal_id,
    SUM(IF(candidate__error = 'empty_response', 1, 0)) AS ad_err_empty_vast,
    SUM(IF(candidate__error = 'invalid_wrapper_url', 1, 0)) AS ad_err_invalid_vast_wrapper_url,
    SUM(IF(candidate__error = 'malformed_response', 1, 0)) AS ad_err_malformed_vast_xml,
    SUM(IF(candidate__error = 'unknown_seat', 1, 0)) AS ad_err_mismatched_seat_id,
    SUM(IF(candidate__error = 'global_advertiser_restricted_by_inventory', 1, 0)) AS ad_err_network_item_advertiser_restriction,
    SUM(IF(candidate__error = 'global_brand_restricted_by_inventory', 1, 0)) AS ad_err_network_item_brand_restriction,
    SUM(IF(candidate__error = 'compliance_check_failed', 1, 0)) AS ad_err_network_item_industry_restriction,
    SUM(IF(candidate__error = 'no_valid_creative', 1, 0)) AS ad_err_no_ad_in_vast,
    SUM(IF(candidate__error = 'jitt_rendition_required', 1, 0)) AS ad_err_no_jitt_rendition,
    SUM(IF(candidate__error = 'inapplicable_for_https', 1, 0)) AS ad_err_non_secure_ad,
    SUM(IF(candidate__error = 'met_yield_opt_cap', 1, 0)) AS ad_err_yield_optimization_cap_reached,
    SUM(IF(candidate__error = 'exclusivity_by_stream', 1, 0)) AS ad_err_exclusivity,
    SUM(IF(candidate__error = 'industry_restricted_by_sa', 1, 0)) AS ad_err_standard_attribute_industry_restriction,
    SUM(IF(candidate__error = 'mkpl_order_floor_price_not_met', 1, 0)) AS ad_err_upstream_order_floor_price_not_met,
    SUM(IF(candidate__error = 'wrapper_http_error', 1, 0)) AS ad_err_vast_wrapper_http_error,
    SUM(IF(candidate__error = 'wrapper_timeout', 1, 0)) AS ad_err_vast_wrapper_timeout,
    SUM(IF(candidate__error = 'empty_bid_id', 1, 0)) AS ad_err_empty_bid_id,
    SUM(IF(candidate__error = 'unsupported_vast_version', 1, 0)) AS ad_err_unsupported_vast_version,
    SUM(IF(candidate__error = 'no_ad_markup', 1, 0)) AS ad_err_empty_vast_ad_markup,
    SUM(IF(candidate__error = 'unexpected_bid_dealid', 1, 0)) AS ad_err_mismatched_deal_id,
    SUM(IF(candidate__error = 'two_phase_translation_unsupported', 1, 0)) AS ad_err_demand_partner_unsupported_on_external_ssp_supply,
    SUM(IF(candidate__error = 'unexpected_external_ad_id', 1, 0)) AS ad_err_mismatched_ad_id,
    SUM(IF(candidate__error = 'creative_restriction_check_failed', 1, 0)) AS ad_err_creative_restriction_failure,
    SUM(IF(candidate__error = 'inbound_order_competition_failure', 1, 0)) AS ad_err_inbound_order_competition_failure,
    SUM(IF(candidate__error = 'global_advertiser_restricted_by_domain', 1, 0)) AS ad_err_advertiser_domain_restricted,
    SUM(IF(candidate__error = 'auction_max_ad_duration_exceeded', 1, 0)) AS ad_err_ad_duration_exceeded,
    SUM(IF(candidate__error = 'mismatched_creative_duration_with_scheduled', 1, 0)) AS ad_err_creative_duration_mismatched,
    SUM(IF(candidate__error = 'yield_opt_met', 1, 0)) AS ad_err_yield_optimization_rule_met,
    SUM(IF(candidate__error = 'no_slot_selected', 1, 0)) AS ad_err_no_slot_selected,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 8) = 0 AND COALESCE(candidate__error, '') = '',
        1,
        0
      )
    ) AS ad_err_unknown,
    0 AS slot_err_competition_failure,
    0 AS slot_err_adjacent_ads_exclusivity,
    0 AS slot_err_adjacent_same_4a_id,
    0 AS slot_err_advertiser_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_advertiser,
    0 AS slot_err_back_to_back_exclusivity,
    0 AS slot_err_brand_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_brand,
    0 AS slot_err_clearcast_restriction,
    0 AS slot_err_cro_advertiser_frequency_cap_reaching,
    0 AS slot_err_cro_brand_frequency_cap_reaching,
    0 AS slot_err_max_number_of_ads_exceeded,
    0 AS slot_err_max_slot_duration_exceeded,
    0 AS slot_err_slot_exclusivity,
    0 AS slot_err_frequency_cap_reaching,
    0 AS slot_err_header_bidding_repeating_key_value_exclusivity,
    0 AS slot_err_inventory_protection_industry,
    0 AS slot_err_sequency_variat_targeting_failed,
    0 AS slot_err_dsp_bid_cap_reaching,
    0 AS slot_err_excluded_by_pod_ads,
    0 AS slot_err_other,
    0 AS slot_err_profile_check_failed,
    0 AS slot_err_adstor_creative_unavailable,
    0 AS slot_err_creative_ad_unit_duration_incompatible,
    0 AS slot_err_creative_profile_incompatible,
    0 AS slot_err_estimated_duration_disabled_for_live_inventory,
    0 AS slot_err_adstor_linear_creative_unavailable
  FROM ${bcv_candidate}
  CROSS JOIN UNNEST(partners__network_id, partners__network_is_extra_item_owner, partners__supply_source, partners__sales_channel, partners__entity_source, partners__role, partners__content_owner_network_id, partners__inbound_order_id, partners__site_section_id, partners__outbound_listing_id, partners__geo_country_visibility__report_aggregate, partners__user_agent_visibility__report_aggregate, partners__standard_endpoint_owner_visibility__report_aggregate, partners__standard_endpoint_visibility__report_aggregate, partners__standard_programmer_visibility__report_aggregate, partners__standard_brand_visibility__report_aggregate, partners__standard_channel_visibility__report_aggregate) AS nw(network_id, extra_item_owner, supply_source, sales_channel, entity_source, role, content_owner_network_id, inbound_order_id, site_section_id, outbound_listing_id, country_visibility, user_agent_visibility, endpoint_owner_visibility, endpoint_visibility, programmer_visibility, brand_visibility, sa_channel_visibility)
  WHERE
    (
      nw.entity_source = 'auction_upstream' AND nw.sales_channel = 6
    )
    AND (
      BITWISE_AND(candidate__flags, 131072) > 0
      OR BITWISE_AND(candidate__bid_status, 1) > 0
    )
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
    33
  UNION ALL
  SELECT
    4 AS process_stage,
    process_batch_id AS process_batch_id,
    DATE_TRUNC('HOUR', request__timestamp) AS event_date,
    COALESCE(nw.network_id, -1) AS network_id,
    'included' AS slot_user_drop_off,
    COALESCE(nw.supply_source, -1) AS supply_source,
    COALESCE(nw.content_owner_network_id, -1) AS content_owner_network_id,
    COALESCE(nw.inbound_order_id, -1) AS inbound_order_id,
    COALESCE(request__traffic_type, 0) AS request_traffic_type,
    0 AS ack_traffic_type,
    COALESCE(nw.site_section_id, -1) AS site_section_id,
    COALESCE(request__context__stream_mode_id, -1) AS stream_mode_id,
    COALESCE(request__context__standard_brand_id, -1) AS standard_brand_id,
    COALESCE(nw.brand_visibility, 'full_visibility') AS standard_brand_visibility,
    COALESCE(request__context__standard_programmer_id, -1) AS standard_programmer_id,
    COALESCE(nw.programmer_visibility, 'full_visibility') AS standard_programmer_visibility,
    COALESCE(request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
    COALESCE(nw.endpoint_visibility, 'full_visibility') AS standard_endpoint_visibility,
    COALESCE(request__context__standard_endpoint_owner_id, -1) AS standard_endpoint_owner_id,
    COALESCE(nw.endpoint_owner_visibility, 'full_visibility') AS standard_endpoint_owner_visibility,
    COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
    COALESCE(nw.user_agent_visibility, 'full_visibility') AS user_agent_visibility,
    COALESCE(visitor__country_id, -1) AS user_country_id,
    COALESCE(nw.country_visibility, 'full_visibility') AS geo_country_visibility,
    COALESCE(request__context__standard_app_bundle_id, -1) AS standard_app_bundle_id,
    COALESCE(request__context__standard_site_domain_id, -1) AS standard_site_domain_id,
    COALESCE(request__context__standard_channel_id, -1) AS standard_channel_id,
    COALESCE(nw.sa_channel_visibility, 'full_visibility') AS standard_channel_visibility,
    ARRAY[] AS global_advertiser_ids,
    ARRAY[] AS global_brand_ids,
    COALESCE(nw.outbound_listing_id, ARRAY[]) AS outbound_exchange_listing_ids,
    -1 AS market_ad_id,
    'not applicable' AS primary_ad_indicator,
    SUM(
      IF(BITWISE_AND(auction__auction_status, 2) > 0, 1, 0) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS bid_requests,
    SUM(
      IF(BITWISE_AND(auction__auction_status, 2) > 0, imp.imp_opp, 0) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS opportunities_in_bid_request,
    0 AS received_bids,
    0 AS failed_bids,
    0 AS resolved_bids,
    0 AS filtered_bids,
    0 AS selected_bids,
    0 AS outbound_exchange_opportunity,
    0 AS targeted_listings,
    0 AS effective_listings,
    0 AS candidated_listings,
    0 AS expanded_listings,
    0 AS listing_err_total,
    0 AS listing_err_unknown,
    0 AS listing_err_out_of_schedule,
    0 AS listing_err_split_source_target_not_met,
    0 AS listing_err_supply_source_target_not_met,
    0 AS listing_err_programmatic_banned,
    0 AS listing_err_exchange_banned,
    0 AS listing_err_met_volume_cap,
    0 AS listing_err_no_applicable_slots,
    0 AS listing_err_no_compatible_slots,
    0 AS listing_err_blocked_by_bidder_private_auction,
    0 AS listing_err_blocked_by_pg_only_ad_request,
    0 AS listing_err_restricted_by_pick_one_logic,
    0 AS listing_err_no_available_exchange_buyer,
    0 AS listing_err_blocked_by_buyer_exclusion,
    0 AS listing_err_blocked_by_exchange_filter,
    SUM(1) AS ad_err_total,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'ad_pending_approval',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_ad_pending_approval,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'compliance_not_approved',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_ad_rejected,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'competition_failure',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_competition_failure,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'global_advertiser_restricted_by_listing',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_listing_advertiser_restriction,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'global_brand_restricted_by_listing',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_listing_brand_restriction,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'industry_restricted_by_listing',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_listing_industry_restriction,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'restricted_seat_by_mkpl_exchange',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_listing_seat_restriction,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'listing_creative_duration_check',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_listing_creative_duration_restriction,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error IN ('external_creative_profile_check_failed', 'profile_check_failed'),
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_profile_check_failed,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'mkpl_exchange_advertiser_floor_price_not_met',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_listing_advertiser_floor_price_not_met,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'mkpl_exchange_brand_floor_price_not_met',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_listing_brand_floor_price_not_met,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'mkpl_exchange_industry_floor_price_not_met',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_listing_industry_floor_price_not_met,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'mkpl_exchange_seat_floor_price_not_met',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_listing_seat_floor_price_not_met,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'dsp_blocked_by_profile',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_demand_partner_disallowed_by_profile,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'lat_unsupported',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_lat_unsupported,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'us_privacy_unsupported',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_ccpa_gpp_us_privacy_opt_out,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'coppa_unsupported',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_coppa_unsupported,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'atts_unsupported',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_apple_app_tracking_transparency_unsupported,
    SUM(
      IF(BITWISE_AND(auction__auction_status, 1) > 0 AND auction__error = 'kv_opt_out', 1, 0) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_kv_unsupported,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'gdpr_unsupported',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_no_tcp_consent,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'gpp_unsupported',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_gpp_not_supported,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'gpp_spi_unsupported',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_gpp_spi_opt_out,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'no_applicable_creative',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_creative_not_applicable,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'floor_price_notmet',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_deal_floor_price_not_met,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'empty_bid_dealid',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_empty_deal_id,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0 AND auction__error = 'empty_response',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_empty_vast,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'invalid_wrapper_url',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_invalid_vast_wrapper_url,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'malformed_response',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_malformed_vast_xml,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0 AND auction__error = 'unknown_seat',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_mismatched_seat_id,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'global_advertiser_restricted_by_inventory',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_network_item_advertiser_restriction,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'global_brand_restricted_by_inventory',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_network_item_brand_restriction,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'compliance_check_failed',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_network_item_industry_restriction,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'no_valid_creative',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_no_ad_in_vast,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'jitt_rendition_required',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_no_jitt_rendition,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'inapplicable_for_https',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_non_secure_ad,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'met_yield_opt_cap',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_yield_optimization_cap_reached,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'exclusivity_by_stream',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_exclusivity,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'industry_restricted_by_sa',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_standard_attribute_industry_restriction,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'mkpl_order_floor_price_not_met',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_upstream_order_floor_price_not_met,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'wrapper_http_error',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_vast_wrapper_http_error,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'wrapper_timeout',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_vast_wrapper_timeout,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0 AND auction__error = 'empty_bid_id',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_empty_bid_id,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'unsupported_vast_version',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_unsupported_vast_version,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0 AND auction__error = 'no_ad_markup',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_empty_vast_ad_markup,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'unexpected_bid_dealid',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_mismatched_deal_id,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'two_phase_translation_unsupported',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_demand_partner_unsupported_on_external_ssp_supply,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'unexpected_external_ad_id',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_mismatched_ad_id,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'creative_restriction_check_failed',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_creative_restriction_failure,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'inbound_order_competition_failure',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_inbound_order_competition_failure,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'global_advertiser_restricted_by_domain',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_advertiser_domain_restricted,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'auction_max_ad_duration_exceeded',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_ad_duration_exceeded,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'mismatched_creative_duration_with_scheduled',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_creative_duration_mismatched,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0 AND auction__error = 'yield_opt_met',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_yield_optimization_rule_met,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 1) > 0
        AND auction__error = 'no_slot_selected',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_no_slot_selected,
    SUM(
      IF(
        BITWISE_AND(auction__auction_status, 8) = 0 AND COALESCE(auction__error, '') = '',
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__invite_deal_size, 1)
    ) AS ad_err_unknown,
    0 AS slot_err_competition_failure,
    0 AS slot_err_adjacent_ads_exclusivity,
    0 AS slot_err_adjacent_same_4a_id,
    0 AS slot_err_advertiser_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_advertiser,
    0 AS slot_err_back_to_back_exclusivity,
    0 AS slot_err_brand_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_brand,
    0 AS slot_err_clearcast_restriction,
    0 AS slot_err_cro_advertiser_frequency_cap_reaching,
    0 AS slot_err_cro_brand_frequency_cap_reaching,
    0 AS slot_err_max_number_of_ads_exceeded,
    0 AS slot_err_max_slot_duration_exceeded,
    0 AS slot_err_slot_exclusivity,
    0 AS slot_err_frequency_cap_reaching,
    0 AS slot_err_header_bidding_repeating_key_value_exclusivity,
    0 AS slot_err_inventory_protection_industry,
    0 AS slot_err_sequency_variat_targeting_failed,
    0 AS slot_err_dsp_bid_cap_reaching,
    0 AS slot_err_excluded_by_pod_ads,
    0 AS slot_err_other,
    0 AS slot_err_profile_check_failed,
    0 AS slot_err_adstor_creative_unavailable,
    0 AS slot_err_creative_ad_unit_duration_incompatible,
    0 AS slot_err_creative_profile_incompatible,
    0 AS slot_err_estimated_duration_disabled_for_live_inventory,
    0 AS slot_err_adstor_linear_creative_unavailable
  FROM ${bcv_auction}
  CROSS JOIN UNNEST(auction__impression__index, auction__impression__equivalent_opportunity_number) AS imp(imp_index, imp_opp)
  CROSS JOIN UNNEST(partners__network_id, partners__network_is_extra_item_owner, partners__supply_source, partners__content_owner_network_id, partners__inbound_order_id, partners__site_section_id, partners__sales_channel, partners__entity_source, partners__role, partners__outbound_listing_id, partners__geo_country_visibility__report_aggregate, partners__user_agent_visibility__report_aggregate, partners__standard_endpoint_owner_visibility__report_aggregate, partners__standard_endpoint_visibility__report_aggregate, partners__standard_programmer_visibility__report_aggregate, partners__standard_brand_visibility__report_aggregate, partners__standard_channel_visibility__report_aggregate) AS nw(network_id, extra_item_owner, supply_source, content_owner_network_id, inbound_order_id, site_section_id, sales_channel, entity_source, role, outbound_listing_id, country_visibility, user_agent_visibility, endpoint_owner_visibility, endpoint_visibility, programmer_visibility, brand_visibility, sa_channel_visibility)
  WHERE
    (
      (
        auction__is_faked_auction = FALSE AND nw.entity_source = 'auction_upstream'
      )
      AND auction__integration_type IN ('normal', 'pg_td')
    )
    AND nw.sales_channel = 6
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
    33
  UNION ALL
  SELECT
    16 AS process_stage,
    process_batch_id AS process_batch_id,
    DATE_TRUNC('HOUR', request__timestamp) AS event_date,
    COALESCE(nw.network_id, -1) AS network_id,
    'included' AS slot_user_drop_off,
    COALESCE(nw.supply_source, -1) AS supply_source,
    COALESCE(nw.content_owner_network_id, -1) AS content_owner_network_id,
    COALESCE(nw.inbound_order_id, -1) AS inbound_order_id,
    COALESCE(request__traffic_type, 0) AS request_traffic_type,
    0 AS ack_traffic_type,
    COALESCE(nw.site_section_id, -1) AS site_section_id,
    COALESCE(request__context__stream_mode_id, -1) AS stream_mode_id,
    COALESCE(request__context__standard_brand_id, -1) AS standard_brand_id,
    COALESCE(nw.brand_visibility, 'full_visibility') AS standard_brand_visibility,
    COALESCE(request__context__standard_programmer_id, -1) AS standard_programmer_id,
    COALESCE(nw.programmer_visibility, 'full_visibility') AS standard_programmer_visibility,
    COALESCE(request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
    COALESCE(nw.endpoint_visibility, 'full_visibility') AS standard_endpoint_visibility,
    COALESCE(request__context__standard_endpoint_owner_id, -1) AS standard_endpoint_owner_id,
    COALESCE(nw.endpoint_owner_visibility, 'full_visibility') AS standard_endpoint_owner_visibility,
    COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
    COALESCE(nw.user_agent_visibility, 'full_visibility') AS user_agent_visibility,
    COALESCE(visitor__country_id, -1) AS user_country_id,
    COALESCE(nw.country_visibility, 'full_visibility') AS geo_country_visibility,
    COALESCE(request__context__standard_app_bundle_id, -1) AS standard_app_bundle_id,
    COALESCE(request__context__standard_site_domain_id, -1) AS standard_site_domain_id,
    COALESCE(request__context__standard_channel_id, -1) AS standard_channel_id,
    COALESCE(nw.sa_channel_visibility, 'full_visibility') AS standard_channel_visibility,
    COALESCE(candidate__global_advertiser_ids, ARRAY[]) AS global_advertiser_ids,
    COALESCE(candidate__global_brand_ids, ARRAY[]) AS global_brand_ids,
    COALESCE(nw.outbound_listing_id, ARRAY[]) AS outbound_exchange_listing_ids,
    COALESCE(candidate__market_ad_id, -1) AS market_ad_id,
    CASE
      WHEN advertisement__is_fallback IS NULL
      THEN 'not applicable'
      WHEN advertisement__is_fallback = TRUE
      THEN 'fallback'
      ELSE 'primary'
    END AS primary_ad_indicator,
    0 AS bid_requests,
    0 AS opportunities_in_bid_request,
    0 AS received_bids,
    0 AS failed_bids,
    0 AS resolved_bids,
    0 AS filtered_bids,
    0 AS selected_bids,
    0 AS outbound_exchange_opportunity,
    0 AS targeted_listings,
    0 AS effective_listings,
    0 AS candidated_listings,
    0 AS expanded_listings,
    0 AS listing_err_total,
    0 AS listing_err_unknown,
    0 AS listing_err_out_of_schedule,
    0 AS listing_err_split_source_target_not_met,
    0 AS listing_err_supply_source_target_not_met,
    0 AS listing_err_programmatic_banned,
    0 AS listing_err_exchange_banned,
    0 AS listing_err_met_volume_cap,
    0 AS listing_err_no_applicable_slots,
    0 AS listing_err_no_compatible_slots,
    0 AS listing_err_blocked_by_bidder_private_auction,
    0 AS listing_err_blocked_by_pg_only_ad_request,
    0 AS listing_err_restricted_by_pick_one_logic,
    0 AS listing_err_no_available_exchange_buyer,
    0 AS listing_err_blocked_by_buyer_exclusion,
    0 AS listing_err_blocked_by_exchange_filter,
    0 AS ad_err_total,
    0 AS ad_err_ad_pending_approval,
    0 AS ad_err_ad_rejected,
    0 AS ad_err_competition_failure,
    0 AS ad_err_listing_advertiser_restriction,
    0 AS ad_err_listing_brand_restriction,
    0 AS ad_err_listing_industry_restriction,
    0 AS ad_err_listing_seat_restriction,
    0 AS ad_err_listing_creative_duration_restriction,
    0 AS ad_err_profile_check_failed,
    0 AS ad_err_listing_advertiser_floor_price_not_met,
    0 AS ad_err_listing_brand_floor_price_not_met,
    0 AS ad_err_listing_industry_floor_price_not_met,
    0 AS ad_err_listing_seat_floor_price_not_met,
    0 AS ad_err_demand_partner_disallowed_by_profile,
    0 AS ad_err_lat_unsupported,
    0 AS ad_err_ccpa_gpp_us_privacy_opt_out,
    0 AS ad_err_coppa_unsupported,
    0 AS ad_err_apple_app_tracking_transparency_unsupported,
    0 AS ad_err_kv_unsupported,
    0 AS ad_err_no_tcp_consent,
    0 AS ad_err_gpp_not_supported,
    0 AS ad_err_gpp_spi_opt_out,
    0 AS ad_err_creative_not_applicable,
    0 AS ad_err_deal_floor_price_not_met,
    0 AS ad_err_empty_deal_id,
    0 AS ad_err_empty_vast,
    0 AS ad_err_invalid_vast_wrapper_url,
    0 AS ad_err_malformed_vast_xml,
    0 AS ad_err_mismatched_seat_id,
    0 AS ad_err_network_item_advertiser_restriction,
    0 AS ad_err_network_item_brand_restriction,
    0 AS ad_err_network_item_industry_restriction,
    0 AS ad_err_no_ad_in_vast,
    0 AS ad_err_no_jitt_rendition,
    0 AS ad_err_non_secure_ad,
    0 AS ad_err_yield_optimization_cap_reached,
    0 AS ad_err_exclusivity,
    0 AS ad_err_standard_attribute_industry_restriction,
    0 AS ad_err_upstream_order_floor_price_not_met,
    0 AS ad_err_vast_wrapper_http_error,
    0 AS ad_err_vast_wrapper_timeout,
    0 AS ad_err_empty_bid_id,
    0 AS ad_err_unsupported_vast_version,
    0 AS ad_err_empty_vast_ad_markup,
    0 AS ad_err_mismatched_deal_id,
    0 AS ad_err_demand_partner_unsupported_on_external_ssp_supply,
    0 AS ad_err_mismatched_ad_id,
    0 AS ad_err_creative_restriction_failure,
    0 AS ad_err_inbound_order_competition_failure,
    0 AS ad_err_advertiser_domain_restricted,
    0 AS ad_err_ad_duration_exceeded,
    0 AS ad_err_creative_duration_mismatched,
    0 AS ad_err_yield_optimization_rule_met,
    0 AS ad_err_no_slot_selected,
    0 AS ad_err_unknown,
    SUM(IF(sub_err.error_category = 'competition_failure', 1, 0)) AS slot_err_competition_failure,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'adjacent_exclusivity',
        1,
        0
      )
    ) AS slot_err_adjacent_ads_exclusivity,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'adjacent_same_4a_id',
        1,
        0
      )
    ) AS slot_err_adjacent_same_4a_id,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'advertiser_frequency_cap_reaching',
        1,
        0
      )
    ) AS slot_err_advertiser_frequency_cap_reaching,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'advertiser_separation_excluded',
        1,
        0
      )
    ) AS slot_err_inventory_protection_advertiser,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'back2back_excluded',
        1,
        0
      )
    ) AS slot_err_back_to_back_exclusivity,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'brand_frequency_cap_reaching',
        1,
        0
      )
    ) AS slot_err_brand_frequency_cap_reaching,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'brand_separation_excluded',
        1,
        0
      )
    ) AS slot_err_inventory_protection_brand,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'clearcast_no_applicable_position_in_slot',
        1,
        0
      )
    ) AS slot_err_clearcast_restriction,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'cro_advertiser_frequency_cap_reaching',
        1,
        0
      )
    ) AS slot_err_cro_advertiser_frequency_cap_reaching,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'cro_brand_frequency_cap_reaching',
        1,
        0
      )
    ) AS slot_err_cro_brand_frequency_cap_reaching,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'exceed_max_num_advertisements',
        1,
        0
      )
    ) AS slot_err_max_number_of_ads_exceeded,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'exceed_max_slot_duration',
        1,
        0
      )
    ) AS slot_err_max_slot_duration_exceeded,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'exclusivity_by_slot',
        1,
        0
      )
    ) AS slot_err_slot_exclusivity,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'frequency_cap_reaching',
        1,
        0
      )
    ) AS slot_err_frequency_cap_reaching,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'from_same_header_bidding',
        1,
        0
      )
    ) AS slot_err_header_bidding_repeating_key_value_exclusivity,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'industry_separation_excluded',
        1,
        0
      )
    ) AS slot_err_inventory_protection_industry,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'position_occupied',
        1,
        0
      )
    ) AS slot_err_sequency_variat_targeting_failed,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'restricted_by_openrtb_impression_bid_capping',
        1,
        0
      )
    ) AS slot_err_dsp_bid_cap_reaching,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code = 'slot_filled_by_multi_ads',
        1,
        0
      )
    ) AS slot_err_excluded_by_pod_ads,
    SUM(
      IF(
        sub_err.error_category = 'competition_failure'
        AND sub_err.error_code IN ('low_ranking_in_buyer', 'swapped_out_of_slot'),
        1,
        0
      )
    ) AS slot_err_other,
    SUM(
      IF(
        sub_err.error_category IN ('profile_check_failed', 'external_creative_profile_check_failed'),
        1,
        0
      )
    ) AS slot_err_profile_check_failed,
    SUM(
      IF(
        sub_err.error_category IN ('profile_check_failed', 'external_creative_profile_check_failed')
        AND sub_err.error_code = 'ad_asset_store_not_available',
        1,
        0
      )
    ) AS slot_err_adstor_creative_unavailable,
    SUM(
      IF(
        sub_err.error_category IN ('profile_check_failed', 'external_creative_profile_check_failed')
        AND sub_err.error_code = 'large_rendition_duration',
        1,
        0
      )
    ) AS slot_err_creative_ad_unit_duration_incompatible,
    SUM(
      IF(
        sub_err.error_category IN ('profile_check_failed', 'external_creative_profile_check_failed')
        AND sub_err.error_code IN ('incompatible_flash_version', 'no_applicable_profiles_for_rendition'),
        1,
        0
      )
    ) AS slot_err_creative_profile_incompatible,
    SUM(
      IF(
        sub_err.error_category IN ('profile_check_failed', 'external_creative_profile_check_failed')
        AND sub_err.error_code = 'estimate_rendition_duration_for_live',
        1,
        0
      )
    ) AS slot_err_estimated_duration_disabled_for_live_inventory,
    SUM(
      IF(
        sub_err.error_category IN ('profile_check_failed', 'external_creative_profile_check_failed')
        AND sub_err.error_code = 'creative_not_available_for_linear',
        1,
        0
      )
    ) AS slot_err_adstor_linear_creative_unavailable
  FROM ${bcv_candidate}
  CROSS JOIN UNNEST(partners__network_id, partners__network_is_extra_item_owner, partners__supply_source, partners__content_owner_network_id, partners__inbound_order_id, partners__site_section_id, partners__sales_channel, partners__entity_source, partners__role, partners__outbound_listing_id, partners__geo_country_visibility__report_aggregate, partners__user_agent_visibility__report_aggregate, partners__standard_endpoint_owner_visibility__report_aggregate, partners__standard_endpoint_visibility__report_aggregate, partners__standard_programmer_visibility__report_aggregate, partners__standard_brand_visibility__report_aggregate, partners__standard_channel_visibility__report_aggregate) AS nw(network_id, extra_item_owner, supply_source, content_owner_network_id, inbound_order_id, site_section_id, sales_channel, entity_source, role, outbound_listing_id, country_visibility, user_agent_visibility, endpoint_owner_visibility, endpoint_visibility, programmer_visibility, brand_visibility, sa_channel_visibility)
  CROSS JOIN UNNEST(candidate__filter_reason__error, candidate__filter_reason__error_category) AS sub_err(error_code, error_category)
  WHERE
    (
      nw.entity_source = 'auction_upstream' AND nw.sales_channel = 6
    )
    AND sub_err.error_category = candidate__error
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
    33
  UNION ALL
  SELECT
    2 AS process_stage,
    process_batch_id AS process_batch_id,
    request__timestamp AS event_date,
    COALESCE(nw.nw_id, -1) AS network_id,
    'included' AS slot_user_drop_off,
    COALESCE(nw.supply_source, -1) AS supply_source,
    COALESCE(nw.content_owner_network_id, -1) AS content_owner_network_id,
    COALESCE(nw.inbound_order_id, -1) AS inbound_order_id,
    COALESCE(request__traffic_type, 0) AS request_traffic_type,
    0 AS ack_traffic_type,
    COALESCE(nw.site_section_id, -1) AS site_section_id,
    COALESCE(request__context__stream_mode_id, -1) AS stream_mode_id,
    IF(
      NOT nw.standard_brand_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_brand_id, -1),
      -1
    ) AS standard_brand_id,
    COALESCE(nw.standard_brand_visibility, 'full_visibility') AS standard_brand_visibility,
    IF(
      NOT nw.standard_programmer_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_programmer_id, -1),
      -1
    ) AS standard_programmer_id,
    COALESCE(nw.standard_programmer_visibility, 'full_visibility') AS standard_programmer_visibility,
    IF(
      NOT nw.standard_endpoint_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_endpoint_id, -1),
      -1
    ) AS standard_endpoint_id,
    COALESCE(nw.standard_endpoint_visibility, 'full_visibility') AS standard_endpoint_visibility,
    IF(
      NOT nw.standard_endpoint_owner_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_endpoint_owner_id, -1),
      -1
    ) AS standard_endpoint_owner_id,
    COALESCE(nw.standard_endpoint_owner_visibility, 'full_visibility') AS standard_endpoint_owner_visibility,
    COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
    COALESCE(nw.user_agent_visibility, 'full_visibility') AS user_agent_visibility,
    COALESCE(visitor__country_id, -1) AS user_country_id,
    COALESCE(nw.geo_country_visibility, 'full_visibility') AS geo_country_visibility,
    COALESCE(request__context__standard_app_bundle_id, -1) AS standard_app_bundle_id,
    COALESCE(request__context__standard_site_domain_id, -1) AS standard_site_domain_id,
    IF(
      NOT nw.sa_channel_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_channel_id, -1),
      -1
    ) AS standard_channel_id,
    COALESCE(nw.sa_channel_visibility, 'full_visibility') AS standard_channel_visibility,
    ARRAY[] AS global_advertiser_ids,
    ARRAY[] AS global_brand_ids,
    COALESCE(outbound.listing_ids, ARRAY[]) AS outbound_exchange_listing_ids,
    -1 AS market_ad_id,
    'not applicable' AS primary_ad_indicator,
    0 AS bid_requests,
    0 AS opportunities_in_bid_request,
    0 AS received_bids,
    0 AS failed_bids,
    0 AS resolved_bids,
    0 AS filtered_bids,
    0 AS selected_bids,
    SUM(COALESCE(outbound.opportunity, 0)) AS outbound_exchange_opportunity,
    0 AS targeted_listings,
    0 AS effective_listings,
    0 AS candidated_listings,
    0 AS expanded_listings,
    0 AS listing_err_total,
    0 AS listing_err_unknown,
    0 AS listing_err_out_of_schedule,
    0 AS listing_err_split_source_target_not_met,
    0 AS listing_err_supply_source_target_not_met,
    0 AS listing_err_programmatic_banned,
    0 AS listing_err_exchange_banned,
    0 AS listing_err_met_volume_cap,
    0 AS listing_err_no_applicable_slots,
    0 AS listing_err_no_compatible_slots,
    0 AS listing_err_blocked_by_bidder_private_auction,
    0 AS listing_err_blocked_by_pg_only_ad_request,
    0 AS listing_err_restricted_by_pick_one_logic,
    0 AS listing_err_no_available_exchange_buyer,
    0 AS listing_err_blocked_by_buyer_exclusion,
    0 AS listing_err_blocked_by_exchange_filter,
    0 AS ad_err_total,
    0 AS ad_err_ad_pending_approval,
    0 AS ad_err_ad_rejected,
    0 AS ad_err_competition_failure,
    0 AS ad_err_listing_advertiser_restriction,
    0 AS ad_err_listing_brand_restriction,
    0 AS ad_err_listing_industry_restriction,
    0 AS ad_err_listing_seat_restriction,
    0 AS ad_err_listing_creative_duration_restriction,
    0 AS ad_err_profile_check_failed,
    0 AS ad_err_listing_advertiser_floor_price_not_met,
    0 AS ad_err_listing_brand_floor_price_not_met,
    0 AS ad_err_listing_industry_floor_price_not_met,
    0 AS ad_err_listing_seat_floor_price_not_met,
    0 AS ad_err_demand_partner_disallowed_by_profile,
    0 AS ad_err_lat_unsupported,
    0 AS ad_err_ccpa_gpp_us_privacy_opt_out,
    0 AS ad_err_coppa_unsupported,
    0 AS ad_err_apple_app_tracking_transparency_unsupported,
    0 AS ad_err_kv_unsupported,
    0 AS ad_err_no_tcp_consent,
    0 AS ad_err_gpp_not_supported,
    0 AS ad_err_gpp_spi_opt_out,
    0 AS ad_err_creative_not_applicable,
    0 AS ad_err_deal_floor_price_not_met,
    0 AS ad_err_empty_deal_id,
    0 AS ad_err_empty_vast,
    0 AS ad_err_invalid_vast_wrapper_url,
    0 AS ad_err_malformed_vast_xml,
    0 AS ad_err_mismatched_seat_id,
    0 AS ad_err_network_item_advertiser_restriction,
    0 AS ad_err_network_item_brand_restriction,
    0 AS ad_err_network_item_industry_restriction,
    0 AS ad_err_no_ad_in_vast,
    0 AS ad_err_no_jitt_rendition,
    0 AS ad_err_non_secure_ad,
    0 AS ad_err_yield_optimization_cap_reached,
    0 AS ad_err_exclusivity,
    0 AS ad_err_standard_attribute_industry_restriction,
    0 AS ad_err_upstream_order_floor_price_not_met,
    0 AS ad_err_vast_wrapper_http_error,
    0 AS ad_err_vast_wrapper_timeout,
    0 AS ad_err_empty_bid_id,
    0 AS ad_err_unsupported_vast_version,
    0 AS ad_err_empty_vast_ad_markup,
    0 AS ad_err_mismatched_deal_id,
    0 AS ad_err_demand_partner_unsupported_on_external_ssp_supply,
    0 AS ad_err_mismatched_ad_id,
    0 AS ad_err_creative_restriction_failure,
    0 AS ad_err_inbound_order_competition_failure,
    0 AS ad_err_advertiser_domain_restricted,
    0 AS ad_err_ad_duration_exceeded,
    0 AS ad_err_creative_duration_mismatched,
    0 AS ad_err_yield_optimization_rule_met,
    0 AS ad_err_no_slot_selected,
    0 AS ad_err_unknown,
    0 AS slot_err_competition_failure,
    0 AS slot_err_adjacent_ads_exclusivity,
    0 AS slot_err_adjacent_same_4a_id,
    0 AS slot_err_advertiser_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_advertiser,
    0 AS slot_err_back_to_back_exclusivity,
    0 AS slot_err_brand_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_brand,
    0 AS slot_err_clearcast_restriction,
    0 AS slot_err_cro_advertiser_frequency_cap_reaching,
    0 AS slot_err_cro_brand_frequency_cap_reaching,
    0 AS slot_err_max_number_of_ads_exceeded,
    0 AS slot_err_max_slot_duration_exceeded,
    0 AS slot_err_slot_exclusivity,
    0 AS slot_err_frequency_cap_reaching,
    0 AS slot_err_header_bidding_repeating_key_value_exclusivity,
    0 AS slot_err_inventory_protection_industry,
    0 AS slot_err_sequency_variat_targeting_failed,
    0 AS slot_err_dsp_bid_cap_reaching,
    0 AS slot_err_excluded_by_pod_ads,
    0 AS slot_err_other,
    0 AS slot_err_profile_check_failed,
    0 AS slot_err_adstor_creative_unavailable,
    0 AS slot_err_creative_ad_unit_duration_incompatible,
    0 AS slot_err_creative_profile_incompatible,
    0 AS slot_err_estimated_duration_disabled_for_live_inventory,
    0 AS slot_err_adstor_linear_creative_unavailable
  FROM ${bcv_slot}
  CROSS JOIN UNNEST(partners__network_id, partners__bit_flags, partners__role, partners__supply_source, partners__content_owner_network_id, partners__inbound_order_id, partners__site_section_id, partners__outbound_exchange_listings__listing_ids, partners__outbound_exchange_listings__avails_metrics__opportunity, partners__standard_endpoint_visibility__report_aggregate, partners__standard_endpoint_owner_visibility__report_aggregate, partners__standard_programmer_visibility__report_aggregate, partners__standard_brand_visibility__report_aggregate, partners__geo_country_visibility__report_aggregate, partners__user_agent_visibility__report_aggregate, partners__standard_channel_visibility__report_aggregate) AS nw(nw_id, bit_flags, nw_role, supply_source, content_owner_network_id, inbound_order_id, site_section_id, outbound_exchange_listings__listing_ids, outbound_exchange_listings__opportunity, standard_endpoint_visibility, standard_endpoint_owner_visibility, standard_programmer_visibility, standard_brand_visibility, geo_country_visibility, user_agent_visibility, sa_channel_visibility)
  CROSS JOIN UNNEST(nw.outbound_exchange_listings__listing_ids, nw.outbound_exchange_listings__opportunity) AS outbound(listing_ids, opportunity)
  WHERE
    (
      (
        (
          request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
        )
        AND BITWISE_AND(slot__flags, 64) = 0
      )
      AND COALESCE(nw.nw_role, '') IN ('cro', 'r')
    )
    AND COALESCE(outbound.opportunity, 0) > 0
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
    33
  UNION ALL
  SELECT
    2 AS process_stage,
    process_batch_id AS process_batch_id,
    request__timestamp AS event_date,
    COALESCE(nw.nw_id, -1) AS network_id,
    'removed' AS slot_user_drop_off,
    COALESCE(nw.supply_source, -1) AS supply_source,
    COALESCE(nw.content_owner_network_id, -1) AS content_owner_network_id,
    COALESCE(nw.inbound_order_id, -1) AS inbound_order_id,
    COALESCE(request__traffic_type, 0) AS request_traffic_type,
    COALESCE(ack__traffic_type, 0) AS ack_traffic_type,
    COALESCE(nw.site_section_id, -1) AS site_section_id,
    COALESCE(request__context__stream_mode_id, -1) AS stream_mode_id,
    IF(
      NOT nw.standard_brand_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_brand_id, -1),
      -1
    ) AS standard_brand_id,
    COALESCE(nw.standard_brand_visibility, 'full_visibility') AS standard_brand_visibility,
    IF(
      NOT nw.standard_programmer_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_programmer_id, -1),
      -1
    ) AS standard_programmer_id,
    COALESCE(nw.standard_programmer_visibility, 'full_visibility') AS standard_programmer_visibility,
    IF(
      NOT nw.standard_endpoint_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_endpoint_id, -1),
      -1
    ) AS standard_endpoint_id,
    COALESCE(nw.standard_endpoint_visibility, 'full_visibility') AS standard_endpoint_visibility,
    IF(
      NOT nw.standard_endpoint_owner_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_endpoint_owner_id, -1),
      -1
    ) AS standard_endpoint_owner_id,
    COALESCE(nw.standard_endpoint_owner_visibility, 'full_visibility') AS standard_endpoint_owner_visibility,
    COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
    COALESCE(nw.user_agent_visibility, 'full_visibility') AS user_agent_visibility,
    COALESCE(visitor__country_id, -1) AS user_country_id,
    COALESCE(nw.geo_country_visibility, 'full_visibility') AS geo_country_visibility,
    COALESCE(request__context__standard_app_bundle_id, -1) AS standard_app_bundle_id,
    COALESCE(request__context__standard_site_domain_id, -1) AS standard_site_domain_id,
    IF(
      NOT nw.sa_channel_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_channel_id, -1),
      -1
    ) AS standard_channel_id,
    COALESCE(nw.sa_channel_visibility, 'full_visibility') AS standard_channel_visibility,
    ARRAY[] AS global_advertiser_ids,
    ARRAY[] AS global_brand_ids,
    COALESCE(outbound.listing_ids, ARRAY[]) AS outbound_exchange_listing_ids,
    IF(
      demand_dim_awareability,
      COALESCE(advertisement__market_ad_id, COALESCE(candidate__market_ad_id, -1)),
      -1
    ) AS market_ad_id,
    IF(
      advertisement__is_fallback = FALSE
      OR (
        advertisement__is_undeliverable = FALSE
        AND BITWISE_AND(COALESCE(advertisement__flags, 0), 33554432) > 0
      ),
      'primary',
      'fallback'
    ) AS primary_ad_indicator,
    0 AS bid_requests,
    0 AS opportunities_in_bid_request,
    0 AS received_bids,
    0 AS failed_bids,
    0 AS resolved_bids,
    0 AS filtered_bids,
    0 AS selected_bids,
    SUM(COALESCE(outbound.opportunity, 0)) AS outbound_exchange_opportunity,
    0 AS targeted_listings,
    0 AS effective_listings,
    0 AS candidated_listings,
    0 AS expanded_listings,
    0 AS listing_err_total,
    0 AS listing_err_unknown,
    0 AS listing_err_out_of_schedule,
    0 AS listing_err_split_source_target_not_met,
    0 AS listing_err_supply_source_target_not_met,
    0 AS listing_err_programmatic_banned,
    0 AS listing_err_exchange_banned,
    0 AS listing_err_met_volume_cap,
    0 AS listing_err_no_applicable_slots,
    0 AS listing_err_no_compatible_slots,
    0 AS listing_err_blocked_by_bidder_private_auction,
    0 AS listing_err_blocked_by_pg_only_ad_request,
    0 AS listing_err_restricted_by_pick_one_logic,
    0 AS listing_err_no_available_exchange_buyer,
    0 AS listing_err_blocked_by_buyer_exclusion,
    0 AS listing_err_blocked_by_exchange_filter,
    0 AS ad_err_total,
    0 AS ad_err_ad_pending_approval,
    0 AS ad_err_ad_rejected,
    0 AS ad_err_competition_failure,
    0 AS ad_err_listing_advertiser_restriction,
    0 AS ad_err_listing_brand_restriction,
    0 AS ad_err_listing_industry_restriction,
    0 AS ad_err_listing_seat_restriction,
    0 AS ad_err_listing_creative_duration_restriction,
    0 AS ad_err_profile_check_failed,
    0 AS ad_err_listing_advertiser_floor_price_not_met,
    0 AS ad_err_listing_brand_floor_price_not_met,
    0 AS ad_err_listing_industry_floor_price_not_met,
    0 AS ad_err_listing_seat_floor_price_not_met,
    0 AS ad_err_demand_partner_disallowed_by_profile,
    0 AS ad_err_lat_unsupported,
    0 AS ad_err_ccpa_gpp_us_privacy_opt_out,
    0 AS ad_err_coppa_unsupported,
    0 AS ad_err_apple_app_tracking_transparency_unsupported,
    0 AS ad_err_kv_unsupported,
    0 AS ad_err_no_tcp_consent,
    0 AS ad_err_gpp_not_supported,
    0 AS ad_err_gpp_spi_opt_out,
    0 AS ad_err_creative_not_applicable,
    0 AS ad_err_deal_floor_price_not_met,
    0 AS ad_err_empty_deal_id,
    0 AS ad_err_empty_vast,
    0 AS ad_err_invalid_vast_wrapper_url,
    0 AS ad_err_malformed_vast_xml,
    0 AS ad_err_mismatched_seat_id,
    0 AS ad_err_network_item_advertiser_restriction,
    0 AS ad_err_network_item_brand_restriction,
    0 AS ad_err_network_item_industry_restriction,
    0 AS ad_err_no_ad_in_vast,
    0 AS ad_err_no_jitt_rendition,
    0 AS ad_err_non_secure_ad,
    0 AS ad_err_yield_optimization_cap_reached,
    0 AS ad_err_exclusivity,
    0 AS ad_err_standard_attribute_industry_restriction,
    0 AS ad_err_upstream_order_floor_price_not_met,
    0 AS ad_err_vast_wrapper_http_error,
    0 AS ad_err_vast_wrapper_timeout,
    0 AS ad_err_empty_bid_id,
    0 AS ad_err_unsupported_vast_version,
    0 AS ad_err_empty_vast_ad_markup,
    0 AS ad_err_mismatched_deal_id,
    0 AS ad_err_demand_partner_unsupported_on_external_ssp_supply,
    0 AS ad_err_mismatched_ad_id,
    0 AS ad_err_creative_restriction_failure,
    0 AS ad_err_inbound_order_competition_failure,
    0 AS ad_err_advertiser_domain_restricted,
    0 AS ad_err_ad_duration_exceeded,
    0 AS ad_err_creative_duration_mismatched,
    0 AS ad_err_yield_optimization_rule_met,
    0 AS ad_err_no_slot_selected,
    0 AS ad_err_unknown,
    0 AS slot_err_competition_failure,
    0 AS slot_err_adjacent_ads_exclusivity,
    0 AS slot_err_adjacent_same_4a_id,
    0 AS slot_err_advertiser_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_advertiser,
    0 AS slot_err_back_to_back_exclusivity,
    0 AS slot_err_brand_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_brand,
    0 AS slot_err_clearcast_restriction,
    0 AS slot_err_cro_advertiser_frequency_cap_reaching,
    0 AS slot_err_cro_brand_frequency_cap_reaching,
    0 AS slot_err_max_number_of_ads_exceeded,
    0 AS slot_err_max_slot_duration_exceeded,
    0 AS slot_err_slot_exclusivity,
    0 AS slot_err_frequency_cap_reaching,
    0 AS slot_err_header_bidding_repeating_key_value_exclusivity,
    0 AS slot_err_inventory_protection_industry,
    0 AS slot_err_sequency_variat_targeting_failed,
    0 AS slot_err_dsp_bid_cap_reaching,
    0 AS slot_err_excluded_by_pod_ads,
    0 AS slot_err_other,
    0 AS slot_err_profile_check_failed,
    0 AS slot_err_adstor_creative_unavailable,
    0 AS slot_err_creative_ad_unit_duration_incompatible,
    0 AS slot_err_creative_profile_incompatible,
    0 AS slot_err_estimated_duration_disabled_for_live_inventory,
    0 AS slot_err_adstor_linear_creative_unavailable
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(partners__network_id, partners__bit_flags, partners__role, partners__supply_source, partners__content_owner_network_id, partners__inbound_order_id, partners__site_section_id, partners__outbound_exchange_listings__listing_ids, partners__outbound_exchange_listings__avails_metrics__opportunity, partners__standard_endpoint_visibility__report_aggregate, partners__standard_endpoint_owner_visibility__report_aggregate, partners__standard_programmer_visibility__report_aggregate, partners__standard_brand_visibility__report_aggregate, partners__geo_country_visibility__report_aggregate, partners__user_agent_visibility__report_aggregate, partners__demand_dim_awareability, partners__standard_channel_visibility__report_aggregate) AS nw(nw_id, bit_flags, nw_role, supply_source, content_owner_network_id, inbound_order_id, site_section_id, outbound_exchange_listings__listing_ids, outbound_exchange_listings__opportunity, standard_endpoint_visibility, standard_endpoint_owner_visibility, standard_programmer_visibility, standard_brand_visibility, geo_country_visibility, user_agent_visibility, demand_dim_awareability, sa_channel_visibility)
  CROSS JOIN UNNEST(nw.outbound_exchange_listings__listing_ids, nw.outbound_exchange_listings__opportunity) AS outbound(listing_ids, opportunity)
  WHERE
    (
      (
        (
          (
            (
              request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
            )
            AND BITWISE_AND(slot__flags, 64) = 0
          )
          AND COALESCE(nw.nw_role, '') IN ('cro', 'r')
        )
        AND COALESCE(ack__ack_entity_type, '') = 'slot'
      )
      AND COALESCE(ack__metrics__slot_impression, 0) > 0
    )
    AND COALESCE(outbound.opportunity, 0) > 0
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
    33
  UNION ALL
  SELECT
    16 AS process_stage,
    process_batch_id AS process_batch_id,
    ack__timestamp AS event_date,
    COALESCE(nw.network_id, -1) AS network_id,
    'removed' AS slot_user_drop_off,
    COALESCE(nw.supply_source, -1) AS supply_source,
    COALESCE(nw.co_id, -1) AS content_owner_network_id,
    COALESCE(nw.inbound_order_id, -1) AS inbound_order_id,
    COALESCE(request__traffic_type, 0) AS request_traffic_type,
    COALESCE(ack__traffic_type, 0) AS ack_traffic_type,
    COALESCE(nw.site_section_id, -1) AS site_section_id,
    COALESCE(request__context__stream_mode_id, -1) AS stream_mode_id,
    IF(
      NOT nw.brand_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_brand_id, -1),
      -1
    ) AS standard_brand_id,
    COALESCE(nw.brand_visibility, 'full_visibility') AS standard_brand_visibility,
    IF(
      NOT nw.programmer_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_programmer_id, -1),
      -1
    ) AS standard_programmer_id,
    COALESCE(nw.programmer_visibility, 'full_visibility') AS standard_programmer_visibility,
    IF(
      NOT nw.endpoint_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_endpoint_id, -1),
      -1
    ) AS standard_endpoint_id,
    COALESCE(nw.endpoint_visibility, 'full_visibility') AS standard_endpoint_visibility,
    IF(
      NOT nw.endpoint_owner_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_endpoint_owner_id, -1),
      -1
    ) AS standard_endpoint_owner_id,
    COALESCE(nw.endpoint_owner_visibility, 'full_visibility') AS standard_endpoint_owner_visibility,
    COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
    COALESCE(nw.user_agent_visibility, 'full_visibility') AS user_agent_visibility,
    COALESCE(visitor__country_id, -1) AS user_country_id,
    COALESCE(nw.country_visibility, 'full_visibility') AS geo_country_visibility,
    COALESCE(request__context__standard_app_bundle_id, -1) AS standard_app_bundle_id,
    COALESCE(request__context__standard_site_domain_id, -1) AS standard_site_domain_id,
    IF(
      NOT nw.sa_channel_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_channel_id, -1),
      -1
    ) AS standard_channel_id,
    COALESCE(nw.sa_channel_visibility, 'full_visibility') AS standard_channel_visibility,
    ARRAY[] AS global_advertiser_ids,
    ARRAY[] AS global_brand_ids,
    COALESCE(nw.outbound_listing_id, ARRAY[]) AS outbound_exchange_listing_ids,
    IF(
      demand_dim_awareability,
      COALESCE(ads.advertisement__market_ad_id, COALESCE(ads.candidate__market_ad_id, -1)),
      -1
    ) AS market_ad_id,
    IF(
      ads.advertisement__is_fallback = FALSE
      OR (
        ads.advertisement__is_undeliverable = FALSE
        AND BITWISE_AND(COALESCE(ads.advertisement__flags, 0), 33554432) > 0
      ),
      'primary',
      'fallback'
    ) AS primary_ad_indicator,
    0 AS bid_requests,
    0 AS opportunities_in_bid_request,
    0 AS received_bids,
    0 AS failed_bids,
    0 AS resolved_bids,
    0 AS filtered_bids,
    SUM(IF(BITWISE_AND(ads.candidate__bid_status, 8) > 0, 1, 0)) AS selected_bids,
    0 AS outbound_exchange_opportunity,
    0 AS targeted_listings,
    0 AS effective_listings,
    0 AS candidated_listings,
    0 AS expanded_listings,
    0 AS listing_err_total,
    0 AS listing_err_unknown,
    0 AS listing_err_out_of_schedule,
    0 AS listing_err_split_source_target_not_met,
    0 AS listing_err_supply_source_target_not_met,
    0 AS listing_err_programmatic_banned,
    0 AS listing_err_exchange_banned,
    0 AS listing_err_met_volume_cap,
    0 AS listing_err_no_applicable_slots,
    0 AS listing_err_no_compatible_slots,
    0 AS listing_err_blocked_by_bidder_private_auction,
    0 AS listing_err_blocked_by_pg_only_ad_request,
    0 AS listing_err_restricted_by_pick_one_logic,
    0 AS listing_err_no_available_exchange_buyer,
    0 AS listing_err_blocked_by_buyer_exclusion,
    0 AS listing_err_blocked_by_exchange_filter,
    0 AS ad_err_total,
    0 AS ad_err_ad_pending_approval,
    0 AS ad_err_ad_rejected,
    0 AS ad_err_competition_failure,
    0 AS ad_err_listing_advertiser_restriction,
    0 AS ad_err_listing_brand_restriction,
    0 AS ad_err_listing_industry_restriction,
    0 AS ad_err_listing_seat_restriction,
    0 AS ad_err_listing_creative_duration_restriction,
    0 AS ad_err_profile_check_failed,
    0 AS ad_err_listing_advertiser_floor_price_not_met,
    0 AS ad_err_listing_brand_floor_price_not_met,
    0 AS ad_err_listing_industry_floor_price_not_met,
    0 AS ad_err_listing_seat_floor_price_not_met,
    0 AS ad_err_demand_partner_disallowed_by_profile,
    0 AS ad_err_lat_unsupported,
    0 AS ad_err_ccpa_gpp_us_privacy_opt_out,
    0 AS ad_err_coppa_unsupported,
    0 AS ad_err_apple_app_tracking_transparency_unsupported,
    0 AS ad_err_kv_unsupported,
    0 AS ad_err_no_tcp_consent,
    0 AS ad_err_gpp_not_supported,
    0 AS ad_err_gpp_spi_opt_out,
    0 AS ad_err_creative_not_applicable,
    0 AS ad_err_deal_floor_price_not_met,
    0 AS ad_err_empty_deal_id,
    0 AS ad_err_empty_vast,
    0 AS ad_err_invalid_vast_wrapper_url,
    0 AS ad_err_malformed_vast_xml,
    0 AS ad_err_mismatched_seat_id,
    0 AS ad_err_network_item_advertiser_restriction,
    0 AS ad_err_network_item_brand_restriction,
    0 AS ad_err_network_item_industry_restriction,
    0 AS ad_err_no_ad_in_vast,
    0 AS ad_err_no_jitt_rendition,
    0 AS ad_err_non_secure_ad,
    0 AS ad_err_yield_optimization_cap_reached,
    0 AS ad_err_exclusivity,
    0 AS ad_err_standard_attribute_industry_restriction,
    0 AS ad_err_upstream_order_floor_price_not_met,
    0 AS ad_err_vast_wrapper_http_error,
    0 AS ad_err_vast_wrapper_timeout,
    0 AS ad_err_empty_bid_id,
    0 AS ad_err_unsupported_vast_version,
    0 AS ad_err_empty_vast_ad_markup,
    0 AS ad_err_mismatched_deal_id,
    0 AS ad_err_demand_partner_unsupported_on_external_ssp_supply,
    0 AS ad_err_mismatched_ad_id,
    0 AS ad_err_creative_restriction_failure,
    0 AS ad_err_inbound_order_competition_failure,
    0 AS ad_err_advertiser_domain_restricted,
    0 AS ad_err_ad_duration_exceeded,
    0 AS ad_err_creative_duration_mismatched,
    0 AS ad_err_yield_optimization_rule_met,
    0 AS ad_err_no_slot_selected,
    0 AS ad_err_unknown,
    0 AS slot_err_competition_failure,
    0 AS slot_err_adjacent_ads_exclusivity,
    0 AS slot_err_adjacent_same_4a_id,
    0 AS slot_err_advertiser_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_advertiser,
    0 AS slot_err_back_to_back_exclusivity,
    0 AS slot_err_brand_frequency_cap_reaching,
    0 AS slot_err_inventory_protection_brand,
    0 AS slot_err_clearcast_restriction,
    0 AS slot_err_cro_advertiser_frequency_cap_reaching,
    0 AS slot_err_cro_brand_frequency_cap_reaching,
    0 AS slot_err_max_number_of_ads_exceeded,
    0 AS slot_err_max_slot_duration_exceeded,
    0 AS slot_err_slot_exclusivity,
    0 AS slot_err_frequency_cap_reaching,
    0 AS slot_err_header_bidding_repeating_key_value_exclusivity,
    0 AS slot_err_inventory_protection_industry,
    0 AS slot_err_sequency_variat_targeting_failed,
    0 AS slot_err_dsp_bid_cap_reaching,
    0 AS slot_err_excluded_by_pod_ads,
    0 AS slot_err_other,
    0 AS slot_err_profile_check_failed,
    0 AS slot_err_adstor_creative_unavailable,
    0 AS slot_err_creative_ad_unit_duration_incompatible,
    0 AS slot_err_creative_profile_incompatible,
    0 AS slot_err_estimated_duration_disabled_for_live_inventory,
    0 AS slot_err_adstor_linear_creative_unavailable
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(ads_in_slot__candidate__bid_status, ads_in_slot__auction__integration_type, ads_in_slot__partners__network_id, ads_in_slot__partners__supply_source, ads_in_slot__partners__sales_channel, ads_in_slot__partners__entity_source, ads_in_slot__partners__content_owner_network_id, ads_in_slot__partners__outbound_listing_id, ads_in_slot__partners__inbound_order_id, ads_in_slot__partners__site_section_id, ads_in_slot__partners__geo_country_visibility__report_aggregate, ads_in_slot__partners__user_agent_visibility__report_aggregate, ads_in_slot__partners__standard_endpoint_owner_visibility__report_aggregate, ads_in_slot__partners__standard_endpoint_visibility__report_aggregate, ads_in_slot__partners__standard_programmer_visibility__report_aggregate, ads_in_slot__partners__standard_brand_visibility__report_aggregate, ads_in_slot__partners__demand_dim_awareability, ads_in_slot__advertisement__market_ad_id, ads_in_slot__candidate__market_ad_id, ads_in_slot__advertisement__flags, ads_in_slot__advertisement__is_undeliverable, ads_in_slot__advertisement__is_fallback, ads_in_slot__partners__standard_channel_visibility__report_aggregate) AS ads(candidate__bid_status, auction__integration_type, network_id, supply_source, sales_channel, entity_source, co_id, outbound_listing_id, inbound_order_id, site_section_id, country_visibility, user_agent_visibility, endpoint_owner_visibility, endpoint_visibility, programmer_visibility, brand_visibility, demand_dim_awareabilities, advertisement__market_ad_id, candidate__market_ad_id, advertisement__flags, advertisement__is_undeliverable, advertisement__is_fallback, sa_channel_visibility)
  CROSS JOIN UNNEST(ads.network_id, ads.supply_source, ads.sales_channel, ads.entity_source, ads.co_id, ads.outbound_listing_id, ads.inbound_order_id, ads.site_section_id, ads.country_visibility, ads.user_agent_visibility, ads.endpoint_owner_visibility, ads.endpoint_visibility, ads.programmer_visibility, ads.brand_visibility, ads.demand_dim_awareabilities, ads.sa_channel_visibility) AS nw(network_id, supply_source, sales_channel, entity_source, co_id, outbound_listing_id, inbound_order_id, site_section_id, country_visibility, user_agent_visibility, endpoint_owner_visibility, endpoint_visibility, programmer_visibility, brand_visibility, demand_dim_awareability, sa_channel_visibility)
  WHERE
    (
      (
        (
          (
            (
              ads.auction__integration_type IN ('normal', 'pg_td')
              AND BITWISE_AND(ads.candidate__bid_status, 8) > 0
            )
            AND nw.sales_channel = 6
          )
          AND nw.supply_source <> 4
        )
        AND COALESCE(advertisement__is_bumper, FALSE) = FALSE
      )
      AND COALESCE(ack__ack_entity_type, '') = 'slot'
    )
    AND COALESCE(ack__metrics__slot_impression, 0) > 0
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
    33
) AS f
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
  84,
  85,
  86,
  87,
  88,
  89,
  96,
  97,
  143,
  144,
  145,
  147
