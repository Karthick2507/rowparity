-- account:    sa-dataapp-insights
-- skeleton:   0f47384f038728d2f46b1c202e856687
-- pattern:    fafe06bd68923dd39d60834619343588  (711 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   dt = DATE_FORMAT(DATE_PARSE(?, ?), ?)
--   process_batch_id = ?

WITH ad_unit_map AS (
  SELECT
    network_id,
    ARRAY_UNION(ARRAY_AGG(id), ARRAY[1, 2, 3, 4, 5, 6]) AS ids
  FROM db.default.d_ad_unit
  WHERE
    network_id > 0
  GROUP BY
    1
)
SELECT
  REDUCE(SET_AGG(process_stage), 0, (acc, val) -> acc + val, val -> val) AS process_stage,
  f.network_id,
  content_owner_id,
  'full_visibility' AS content_owner_visibility,
  distributor_id,
  transaction_type,
  reseller_id,
  reseller_visibility,
  reseller_network_type,
  supply_source,
  sales_channel,
  sales_strategy,
  site_id,
  site_section_id,
  standard_publisher_id,
  standard_brand_id,
  standard_brand_visibility,
  standard_programmer_id,
  standard_programmer_visibility,
  content_form_id,
  stream_mode_id,
  standard_endpoint_owner_id,
  standard_endpoint_owner_visibility,
  standard_endpoint_id,
  standard_endpoint_visibility,
  user_country_id,
  geo_country_visibility,
  standard_device_type_id,
  standard_app_id,
  standard_environment_id,
  standard_os_id,
  user_agent_visibility,
  profile_id,
  profile_type,
  request_fill_status,
  live_linear_indicator,
  ssp_bidder_indicator,
  partner_tag_indicator,
  time_position_classes,
  ARRAY_DISTINCT(
    TRANSFORM(COALESCE(slot_ad_unit_ids, ARRAY[]), x -> IF(CONTAINS(aum.ids, x), x, -1))
  ) AS slot_ad_unit_ids,
  slot_sequence_normalized,
  slot_user_drop_off,
  slot_removed_by_ux_indicator,
  slot_fill_status,
  evergreen_ad_indicator,
  promo_ad_indicator,
  priority_tier,
  CASE
    WHEN priority_tier = 'tier_1' AND priority_value IS NULL
    THEN 25
    WHEN priority_tier = 'tier_2' AND priority_value IS NULL
    THEN 11
    WHEN priority_tier = 'tier_3'
    AND priority_type NOT LIKE '%sponsorship%'
    AND (
      priority_value IS NULL OR priority_value < 0 OR priority_value > 10
    )
    THEN 0
    WHEN priority_tier = 'tier_4'
    THEN IF(meet_schedule = 1, -65536, COALESCE(priority_value, -65535))
    WHEN priority_tier = 'tier_5'
    THEN 0
    WHEN priority_tier = 'tier_6'
    AND (
      priority_value IS NULL OR priority_value = -65535
    )
    THEN 0
    ELSE IF(priority_value IS NULL, 0, priority_value)
  END AS priority_value,
  priority_type,
  request_traffic_type,
  ack_traffic_type,
  inbound_order_id,
  ad_id,
  placement_id,
  global_advertiser_ids,
  global_brand_ids,
  local_advertiser_id,
  primary_ad_indicator,
  SUM(candidate_ads) AS candidate_ads,
  SUM(tx_eligible_ads) AS tx_eligible_ads,
  SUM(slot_eligible_ads) AS slot_eligible_ads,
  SUM(selected_ads_sampled) AS selected_ads_sampled,
  SUM(gross_ad_views_sampled) AS gross_ad_views_sampled,
  SUM(placement_err_total) AS placement_err_total,
  SUM(ad_err_total) AS ad_err_total,
  SUM(slot_err_total) AS slot_err_total,
  SUM(tx_err_malformed_response) AS tx_err_malformed_response,
  SUM(tx_err_empty_response) AS tx_err_empty_response,
  SUM(tx_err_profile_check_failed) AS tx_err_profile_check_failed,
  SUM(tx_err_frequency_cap_failed) AS tx_err_frequency_cap_failed,
  SUM(tx_err_reseller_whitelist_not_allowed) AS tx_err_reseller_whitelist_not_allowed,
  SUM(tx_err_reseller_blacklist_banned) AS tx_err_reseller_blacklist_banned,
  SUM(tx_err_no_applicable_slot) AS tx_err_no_applicable_slot,
  SUM(tx_err_no_applicable_creative) AS tx_err_no_applicable_creative,
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
  SUM(tx_err_global_brand_restricted_by_listing) AS tx_err_global_brand_restricted_by_listing,
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
  SUM(tx_err_find_rule_path_failure) AS tx_err_find_rule_path_failure,
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
  event_date,
  process_batch_id,
  SUM(placed_ads_sampled) AS placed_ads_sampled,
  SUM(placed_fallback_ads_sampled) AS placed_fallback_ads_sampled,
  SUM(filled_ads_sstf_fallback_sampled) AS filled_ads_sstf_fallback_sampled,
  SUM(tx_err_not_allowed_upstream_network_for_ad) AS tx_err_not_allowed_upstream_network_for_ad,
  SUM(tx_err_exceed_max_slot_duration) AS tx_err_exceed_max_slot_duration,
  SUM(tx_err_blocked_by_inventory_source_optimization_imr) AS tx_err_blocked_by_inventory_source_optimization_imr,
  SUM(tx_err_low_ranking_in_buyer) AS tx_err_low_ranking_in_buyer,
  SUM(tx_err_inbound_order_competition_failure) AS tx_err_inbound_order_competition_failure,
  SUM(tx_err_price_hurdle_check_failed) AS tx_err_price_hurdle_check_failed,
  SUM(tx_err_inbound_rule_targeting_not_met) AS tx_err_inbound_rule_targeting_not_met,
  SUM(tx_err_inbound_rule_explicit_targeting_required) AS tx_err_inbound_rule_explicit_targeting_required,
  SUM(tx_err_competition_failure_in_pick_many) AS tx_err_competition_failure_in_pick_many,
  SUM(tx_err_failed_sov_percent_check) AS tx_err_failed_sov_percent_check,
  SUM(tx_err_failed_sop_percent_check) AS tx_err_failed_sop_percent_check,
  SUM(tx_err_failed_soi_percent_check) AS tx_err_failed_soi_percent_check,
  content_form_visibility,
  SUM(tx_err_invalid_compliance_for_inventory_protection) AS tx_err_invalid_compliance_for_inventory_protection,
  SUM(tx_err_rule_compliance_check_failed) AS tx_err_rule_compliance_check_failed,
  SUM(tx_err_clearcast_code_restricted) AS tx_err_clearcast_code_restricted,
  SUM(tx_err_mkpl_order_floor_price_not_met) AS tx_err_mkpl_order_floor_price_not_met,
  SUM(tx_err_global_advertiser_restricted_by_listing) AS tx_err_global_advertiser_restricted_by_listing,
  SUM(tx_err_industry_restricted_by_sa) AS tx_err_industry_restricted_by_sa,
  SUM(slot_err_advertiser_frequency_cap_reaching) AS slot_err_advertiser_frequency_cap_reaching,
  SUM(tx_err_not_allowed_upstream_network_for_rule) AS tx_err_not_allowed_upstream_network_for_rule,
  SUM(tx_err_compliance_not_approved) AS tx_err_compliance_not_approved,
  SUM(tx_err_data_visibility_banned) AS tx_err_data_visibility_banned,
  SUM(tx_err_mkpl_exchange_advertiser_floor_price_not_met) AS tx_err_mkpl_exchange_advertiser_floor_price_not_met,
  SUM(tx_err_mkpl_exchange_brand_floor_price_not_met) AS tx_err_mkpl_exchange_brand_floor_price_not_met,
  SUM(tx_err_mkpl_exchange_industry_floor_price_not_met) AS tx_err_mkpl_exchange_industry_floor_price_not_met,
  SUM(tx_err_no_brand_for_inventory_protection) AS tx_err_no_brand_for_inventory_protection,
  SUM(tx_err_global_advertiser_restricted_by_domain) AS tx_err_global_advertiser_restricted_by_domain,
  SUM(tx_err_blocked_by_empty_advertiser_domain) AS tx_err_blocked_by_empty_advertiser_domain,
  SUM(tx_err_lower_bidding_price_than_mkpl_order_price) AS tx_err_lower_bidding_price_than_mkpl_order_price,
  SUM(tx_err_no_valid_currency) AS tx_err_no_valid_currency,
  process_batch_id AS partition_key
FROM (
  SELECT
    CAST(1 AS INTEGER) AS process_stage,
    COALESCE(network.network_id, -1) AS network_id,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(upstream_network.network_id, COALESCE(network.network_id, -1)),
      COALESCE(upstream_network.network_id, -1)
    ) AS content_owner_id,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.distributor_network_id, -1),
      -1
    ) AS distributor_id,
    CASE
      WHEN COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated'
      AND network.network_id = request.video_cro_network_id
      THEN 'cro'
      ELSE 'r'
    END AS transaction_type,
    COALESCE(t.external_network_id, COALESCE(network.network_id, -1)) AS reseller_id,
    'full_visibility' AS reseller_visibility,
    IF(COALESCE(t.external_network_id, -1) = -1, 'full', 'internal') AS reseller_network_type,
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
    IF(COALESCE(t.external_network_id, -1) = -1, 2, 3) AS sales_channel,
    IF(
      COALESCE(t.external_network_id, -1) = -1,
      'direct sold',
      'reseller sold - reseller tag'
    ) AS sales_strategy,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_id, -1),
      -1
    ) AS site_id,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_section_id, -1),
      -1
    ) AS site_section_id,
    COALESCE(request.standard_publisher_id, -1) AS standard_publisher_id,
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
      NOT network.data_right.content_form_visibility.report_aggregate IS NULL
      OR network.supply_source_type <> 'mrm_rule',
      COALESCE(request.content_form_id, -1),
      -1
    ) AS content_form_id,
    COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), -1) AS stream_mode_id,
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
      NOT network.data_right.standard_endpoint_visibility.report_aggregate IS NULL
      OR network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_endpoint_id, -1),
      -1
    ) AS standard_endpoint_id,
    COALESCE(
      network.data_right.standard_endpoint_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_endpoint_visibility,
    COALESCE(request.country_id, -1) AS user_country_id,
    COALESCE(network.data_right.geo_country_visibility.report_aggregate, 'full_visibility') AS geo_country_visibility,
    IF(
      CARDINALITY(request.standard_device_type_ids) > 0,
      COALESCE(ELEMENT_AT(request.standard_device_type_ids, -1), -1),
      -1
    ) AS standard_device_type_id,
    COALESCE(request.standard_app_id, -1) AS standard_app_id,
    COALESCE(request.standard_environment_id, -1) AS standard_environment_id,
    COALESCE(request.standard_os_id, -1) AS standard_os_id,
    COALESCE(network.data_right.user_agent_visibility.report_aggregate, 'full_visibility') AS user_agent_visibility,
    COALESCE(request.profile_id, -1) AS profile_id,
    'compound' AS profile_type,
    'unknown' AS request_fill_status,
    FALSE AS live_linear_indicator,
    IF(BITWISE_AND(COALESCE(request.extra_flags2, 0), 8) > 0, TRUE, FALSE) AS ssp_bidder_indicator,
    FALSE AS partner_tag_indicator,
    CAST(ARRAY[] AS ARRAY(VARCHAR)) AS time_position_classes,
    CAST(ARRAY[] AS ARRAY(BIGINT)) AS slot_ad_unit_ids,
    'not applicable' AS slot_sequence_normalized,
    'included' AS slot_user_drop_off,
    'not applicable' AS slot_removed_by_ux_indicator,
    'not applicable' AS slot_fill_status,
    'not applicable' AS evergreen_ad_indicator,
    'not applicable' AS promo_ad_indicator,
    'unknown' AS priority_tier,
    'unknown' AS priority_type,
    NULL AS priority_value,
    0 AS meet_schedule,
    CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 1 ELSE 0 END AS request_traffic_type,
    0 AS ack_traffic_type,
    COALESCE(network.inbound_order.order_id, -1) AS inbound_order_id,
    -1 AS ad_id,
    COALESCE(t.placement_id, -1) AS placement_id,
    CAST(ARRAY[] AS ARRAY(BIGINT)) AS global_advertiser_ids,
    CAST(ARRAY[] AS ARRAY(BIGINT)) AS global_brand_ids,
    -1 AS local_advertiser_id,
    'not applicable' AS primary_ad_indicator,
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
    SUM(IF(COALESCE(t.error, -1) = 105, COALESCE(magnifier, 1), 0)) AS tx_err_not_allowed_upstream_network_for_rule,
    SUM(IF(COALESCE(t.error, -1) = 107, COALESCE(magnifier, 1), 0)) AS tx_err_compliance_not_approved,
    SUM(IF(COALESCE(t.error, -1) = 109, COALESCE(magnifier, 1), 0)) AS tx_err_data_visibility_banned,
    SUM(IF(COALESCE(t.error, -1) = 111, COALESCE(magnifier, 1), 0)) AS tx_err_reseller_whitelist_not_allowed,
    SUM(IF(COALESCE(t.error, -1) = 112, COALESCE(magnifier, 1), 0)) AS tx_err_reseller_blacklist_banned,
    SUM(IF(COALESCE(t.error, -1) = 113, COALESCE(magnifier, 1), 0)) AS tx_err_no_applicable_slot,
    SUM(IF(COALESCE(t.error, -1) = 114, COALESCE(magnifier, 1), 0)) AS tx_err_no_applicable_creative,
    SUM(IF(COALESCE(t.error, -1) = 115, COALESCE(magnifier, 1), 0)) AS tx_err_invalid_compliance_for_inventory_protection,
    SUM(IF(COALESCE(t.error, -1) = 117, COALESCE(magnifier, 1), 0)) AS tx_err_rule_compliance_check_failed,
    SUM(IF(COALESCE(t.error, -1) = 121, COALESCE(magnifier, 1), 0)) AS tx_err_exceed_max_slot_duration,
    SUM(IF(COALESCE(t.error, -1) = 127, COALESCE(magnifier, 1), 0)) AS tx_err_competition_failure,
    SUM(IF(COALESCE(t.error, -1) = 128, COALESCE(magnifier, 1), 0)) AS tx_err_exclusivity_by_stream,
    SUM(IF(COALESCE(t.error, -1) = 139, COALESCE(magnifier, 1), 0)) AS tx_err_creative_restriction_check_failed,
    SUM(IF(COALESCE(t.error, -1) = 140, COALESCE(magnifier, 1), 0)) AS tx_err_clearcast_code_restricted,
    SUM(IF(COALESCE(t.error, -1) = 142, COALESCE(magnifier, 1), 0)) AS tx_err_no_brand_for_inventory_protection,
    SUM(IF(COALESCE(t.error, -1) = 150, COALESCE(magnifier, 1), 0)) AS tx_err_ad_targeting_restricted,
    SUM(IF(COALESCE(t.error, -1) = 153, COALESCE(magnifier, 1), 0)) AS tx_err_budget_met,
    SUM(IF(COALESCE(t.error, -1) = 155, COALESCE(magnifier, 1), 0)) AS tx_err_listing_creative_duration_check,
    SUM(IF(COALESCE(t.error, -1) = 156, COALESCE(magnifier, 1), 0)) AS tx_err_advertiser_industry_restriction,
    SUM(IF(COALESCE(t.error, -1) = 157, COALESCE(magnifier, 1), 0)) AS tx_err_brand_blacklist_restriction,
    SUM(IF(COALESCE(t.error, -1) = 158, COALESCE(magnifier, 1), 0)) AS tx_err_advertiser_blacklist_restriction,
    SUM(IF(COALESCE(t.error, -1) = 159, COALESCE(magnifier, 1), 0)) AS tx_err_schedule_met,
    SUM(IF(COALESCE(t.error, -1) = 160, COALESCE(magnifier, 1), 0)) AS tx_err_slot_compatiblity_check,
    SUM(IF(COALESCE(t.error, -1) = 161, COALESCE(magnifier, 1), 0)) AS tx_err_rating_restriction,
    SUM(IF(COALESCE(t.error, -1) = 163, COALESCE(magnifier, 1), 0)) AS tx_err_mkpl_order_floor_price_not_met,
    SUM(IF(COALESCE(t.error, -1) = 175, COALESCE(magnifier, 1), 0)) AS tx_err_global_brand_restricted_by_inventory,
    SUM(IF(COALESCE(t.error, -1) = 176, COALESCE(magnifier, 1), 0)) AS tx_err_global_advertiser_restricted_by_inventory,
    SUM(IF(COALESCE(t.error, -1) = 177, COALESCE(magnifier, 1), 0)) AS tx_err_global_advertiser_restricted_by_listing,
    SUM(IF(COALESCE(t.error, -1) = 179, COALESCE(magnifier, 1), 0)) AS tx_err_global_advertiser_restricted_by_domain,
    SUM(IF(COALESCE(t.error, -1) = 183, COALESCE(magnifier, 1), 0)) AS tx_err_blocked_by_inventory_source_optimization_imr,
    SUM(IF(COALESCE(t.error, -1) = 184, COALESCE(magnifier, 1), 0)) AS tx_err_inbound_rule_targeting_not_met,
    SUM(IF(COALESCE(t.error, -1) = 185, COALESCE(magnifier, 1), 0)) AS tx_err_inbound_rule_explicit_targeting_required,
    SUM(IF(COALESCE(t.error, -1) = 188, COALESCE(magnifier, 1), 0)) AS tx_err_global_brand_restricted_by_listing,
    SUM(IF(COALESCE(t.error, -1) = 190, COALESCE(magnifier, 1), 0)) AS tx_err_blocked_by_empty_advertiser_domain,
    SUM(IF(COALESCE(t.error, -1) = 192, COALESCE(magnifier, 1), 0)) AS tx_err_low_ranking_in_buyer,
    SUM(IF(COALESCE(t.error, -1) = 193, COALESCE(magnifier, 1), 0)) AS tx_err_industry_restricted_by_listing,
    SUM(IF(COALESCE(t.error, -1) = 198, COALESCE(magnifier, 1), 0)) AS tx_err_lower_bidding_price_than_mkpl_order_price,
    SUM(IF(COALESCE(t.error, -1) = 200, COALESCE(magnifier, 1), 0)) AS tx_err_wrapper_timeout,
    SUM(IF(COALESCE(t.error, -1) = 201, COALESCE(magnifier, 1), 0)) AS tx_err_wrapper_http_error,
    SUM(IF(COALESCE(t.error, -1) = 205, COALESCE(magnifier, 1), 0)) AS tx_err_no_valid_creative,
    SUM(IF(COALESCE(t.error, -1) = 206, COALESCE(magnifier, 1), 0)) AS tx_err_unsupported_vast_version,
    SUM(IF(COALESCE(t.error, -1) = 214, COALESCE(magnifier, 1), 0)) AS tx_err_floor_price_notmet,
    SUM(IF(COALESCE(t.error, -1) = 230, COALESCE(magnifier, 1), 0)) AS tx_err_no_valid_currency,
    SUM(IF(COALESCE(t.error, -1) = 254, COALESCE(magnifier, 1), 0)) AS tx_err_mkpl_exchange_advertiser_floor_price_not_met,
    SUM(IF(COALESCE(t.error, -1) = 255, COALESCE(magnifier, 1), 0)) AS tx_err_mkpl_exchange_brand_floor_price_not_met,
    SUM(IF(COALESCE(t.error, -1) = 256, COALESCE(magnifier, 1), 0)) AS tx_err_mkpl_exchange_industry_floor_price_not_met,
    SUM(IF(COALESCE(t.error, -1) = 273, COALESCE(magnifier, 1), 0)) AS tx_err_industry_restricted_by_sa,
    SUM(IF(COALESCE(t.error, -1) = 300, COALESCE(magnifier, 1), 0)) AS tx_err_targeted_schedule_met,
    SUM(IF(COALESCE(t.error, -1) = 301, COALESCE(magnifier, 1), 0)) AS tx_err_targeted_budget_met,
    SUM(IF(COALESCE(t.error, -1) = 302, COALESCE(magnifier, 1), 0)) AS tx_err_yield_opt_met,
    SUM(IF(COALESCE(t.error, -1) = 306, COALESCE(magnifier, 1), 0)) AS tx_err_inflight_bid_met,
    SUM(IF(COALESCE(t.error, -1) = 1500, COALESCE(magnifier, 1), 0)) AS tx_err_inbound_order_competition_failure,
    SUM(IF(COALESCE(t.error, -1) = 1501, COALESCE(magnifier, 1), 0)) AS tx_err_competition_failure_in_pick_many,
    SUM(IF(COALESCE(t.error, -1) = 5001, COALESCE(magnifier, 1), 0)) AS tx_err_find_rule_path_failure,
    SUM(IF(COALESCE(t.error, -1) = 5002, COALESCE(magnifier, 1), 0)) AS tx_err_failed_sov_percent_check,
    SUM(IF(COALESCE(t.error, -1) = 5003, COALESCE(magnifier, 1), 0)) AS tx_err_failed_sop_percent_check,
    SUM(IF(COALESCE(t.error, -1) = 5004, COALESCE(magnifier, 1), 0)) AS tx_err_failed_soi_percent_check,
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
    CAST(0 AS BIGINT) AS slot_err_advertiser_frequency_cap_reaching,
    COALESCE(network.data_right.content_form_visibility.report_aggregate, 'full_visibility') AS content_form_visibility,
    DATE_TRUNC('HOUR', FROM_UNIXTIME(timestamp)) AS event_date,
    DATE_FORMAT(DATE_PARSE(dt, '%y-%m-%d-%h'), '%y%m%d%h0000') AS process_batch_id
  FROM db.troubleshooting_log.fw_ads_demand_troubleshooting_log
  CROSS JOIN UNNEST(ad_selection_info) AS t
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
    55,
    56,
    57,
    58,
    153,
    154,
    155
  UNION ALL
  SELECT
    CAST(1 AS INTEGER) AS process_stage,
    COALESCE(network.network_id, -1) AS network_id,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(upstream_network.network_id, COALESCE(network.network_id, -1)),
      COALESCE(upstream_network.network_id, -1)
    ) AS content_owner_id,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.distributor_network_id, -1),
      -1
    ) AS distributor_id,
    CASE
      WHEN COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated'
      AND network.network_id = request.video_cro_network_id
      THEN 'cro'
      ELSE 'r'
    END AS transaction_type,
    COALESCE(t.external_network_id, COALESCE(network.network_id, -1)) AS reseller_id,
    'full_visibility' AS reseller_visibility,
    IF(COALESCE(t.external_network_id, -1) = -1, 'full', 'internal') AS reseller_network_type,
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
    IF(COALESCE(t.external_network_id, -1) = -1, 2, 3) AS sales_channel,
    IF(
      COALESCE(t.external_network_id, -1) = -1,
      'direct sold',
      'reseller sold - reseller tag'
    ) AS sales_strategy,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_id, -1),
      -1
    ) AS site_id,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_section_id, -1),
      -1
    ) AS site_section_id,
    COALESCE(request.standard_publisher_id, -1) AS standard_publisher_id,
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
      NOT network.data_right.content_form_visibility.report_aggregate IS NULL
      OR network.supply_source_type <> 'mrm_rule',
      COALESCE(request.content_form_id, -1),
      -1
    ) AS content_form_id,
    COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), -1) AS stream_mode_id,
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
      NOT network.data_right.standard_endpoint_visibility.report_aggregate IS NULL
      OR network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_endpoint_id, -1),
      -1
    ) AS standard_endpoint_id,
    COALESCE(
      network.data_right.standard_endpoint_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_endpoint_visibility,
    COALESCE(request.country_id, -1) AS user_country_id,
    COALESCE(network.data_right.geo_country_visibility.report_aggregate, 'full_visibility') AS geo_country_visibility,
    IF(
      CARDINALITY(request.standard_device_type_ids) > 0,
      COALESCE(ELEMENT_AT(request.standard_device_type_ids, -1), -1),
      -1
    ) AS standard_device_type_id,
    COALESCE(request.standard_app_id, -1) AS standard_app_id,
    COALESCE(request.standard_environment_id, -1) AS standard_environment_id,
    COALESCE(request.standard_os_id, -1) AS standard_os_id,
    COALESCE(network.data_right.user_agent_visibility.report_aggregate, 'full_visibility') AS user_agent_visibility,
    COALESCE(request.profile_id, -1) AS profile_id,
    'compound' AS profile_type,
    'unknown' AS request_fill_status,
    FALSE AS live_linear_indicator,
    IF(BITWISE_AND(COALESCE(request.extra_flags2, 0), 8) > 0, TRUE, FALSE) AS ssp_bidder_indicator,
    FALSE AS partner_tag_indicator,
    CAST(ARRAY[] AS ARRAY(VARCHAR)) AS time_position_classes,
    CAST(ARRAY[] AS ARRAY(BIGINT)) AS slot_ad_unit_ids,
    'not applicable' AS slot_sequence_normalized,
    'included' AS slot_user_drop_off,
    'not applicable' AS slot_removed_by_ux_indicator,
    'not applicable' AS slot_fill_status,
    IF(
      BITWISE_AND(COALESCE(ad.entity_flags, 0), BITWISE_SHIFT_LEFT(1, 35, 64)) > 0,
      'yes',
      'no'
    ) AS evergreen_ad_indicator,
    IF(
      BITWISE_AND(COALESCE(ad.entity_flags, 0), BITWISE_SHIFT_LEFT(1, 2, 64)) > 0,
      'yes',
      'no'
    ) AS promo_ad_indicator,
    COALESCE(ad.effective_unified_priority.priority_tier, 'unknown') AS priority_tier,
    CASE
      WHEN COALESCE(t.external_network_id, -1) = -1
      THEN (
        CASE
          WHEN COALESCE(ad.effective_unified_priority.priority_tier, 'unknown') IN ('tier_1', 'tier_2')
          THEN COALESCE(ad.ad_priority_type, 'unknown')
          WHEN COALESCE(ad.effective_unified_priority.priority_tier, 'unknown') IN ('tier_3', 'tier_4')
          THEN IF(
            COALESCE(ad.ad_priority_type, 'unknown') = 'unknown',
            IF(BITWISE_AND(ad.entity_flags, 1) > 0, 'guaranteed', 'preemptible'),
            CONCAT(
              IF(BITWISE_AND(ad.entity_flags, 1) > 0, 'guaranteed', 'preemptible'),
              '_',
              COALESCE(ad.ad_priority_type, 'unknown')
            )
          )
          WHEN COALESCE(ad.effective_unified_priority.priority_tier, 'unknown') IN ('tier_6')
          THEN 'house_ads'
          ELSE COALESCE(ad.ad_priority_type, 'unknown')
        END
      )
      ELSE 'unknown'
    END AS priority_type,
    ad.effective_unified_priority.sub_priority_value AS priority_value,
    0 AS meet_schedule,
    CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 1 ELSE 0 END AS request_traffic_type,
    0 AS ack_traffic_type,
    COALESCE(network.inbound_order.order_id, -1) AS inbound_order_id,
    COALESCE(ad.ad_id, -1) AS ad_id,
    COALESCE(t.placement_id, -1) AS placement_id,
    COALESCE(ad.global_advertiser_ids, ARRAY[]) AS global_advertiser_ids,
    COALESCE(ad.global_brand_ids, ARRAY[]) AS global_brand_ids,
    COALESCE(ad.advertiser_id, -1) AS local_advertiser_id,
    'not applicable' AS primary_ad_indicator,
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
        AND COALESCE(ad.error, -1) = 105,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_not_allowed_upstream_network_for_rule,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 107,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_compliance_not_approved,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 109,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_data_visibility_banned,
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
        AND COALESCE(ad.error, -1) = 115,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_invalid_compliance_for_inventory_protection,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 117,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_rule_compliance_check_failed,
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
        AND COALESCE(ad.error, -1) = 140,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_clearcast_code_restricted,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 142,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_no_brand_for_inventory_protection,
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
        AND COALESCE(ad.error, -1) = 163,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_mkpl_order_floor_price_not_met,
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
        AND COALESCE(ad.error, -1) = 177,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_global_advertiser_restricted_by_listing,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 179,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_global_advertiser_restricted_by_domain,
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
        AND COALESCE(ad.error, -1) = 190,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_blocked_by_empty_advertiser_domain,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND (
          COALESCE(ad.error, -1) = 192 OR BITWISE_AND(COALESCE(ad.ad_info_flag, 0), 2) > 0
        ),
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
        AND COALESCE(ad.error, -1) = 198,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_lower_bidding_price_than_mkpl_order_price,
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
        AND COALESCE(ad.error, -1) = 230,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_no_valid_currency,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 254,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_mkpl_exchange_advertiser_floor_price_not_met,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 255,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_mkpl_exchange_brand_floor_price_not_met,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 256,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_mkpl_exchange_industry_floor_price_not_met,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 273,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_industry_restricted_by_sa,
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
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 5002,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_failed_sov_percent_check,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 5003,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_failed_sop_percent_check,
    SUM(
      IF(
        BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
        AND COALESCE(ad.error, -1) = 5004,
        COALESCE(magnifier, 1),
        0
      )
    ) AS tx_err_failed_soi_percent_check,
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
    CAST(0 AS BIGINT) AS slot_err_advertiser_frequency_cap_reaching,
    COALESCE(network.data_right.content_form_visibility.report_aggregate, 'full_visibility') AS content_form_visibility,
    DATE_TRUNC('HOUR', FROM_UNIXTIME(timestamp)) AS event_date,
    DATE_FORMAT(DATE_PARSE(dt, '%y-%m-%d-%h'), '%y%m%d%h0000') AS process_batch_id
  FROM db.troubleshooting_log.fw_ads_demand_troubleshooting_log
  CROSS JOIN UNNEST(ad_selection_info) AS t
  CROSS JOIN UNNEST(t.ad_infos) AS ad
  WHERE
    NOT (
      COALESCE(ad.selection_status, 0) < 7
      AND BITWISE_AND(COALESCE(ad.ad_info_flag, 0), 1) > 0
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
    153,
    154,
    155
  UNION ALL
  SELECT
    CAST(16 AS INTEGER) AS process_stage,
    COALESCE(network.network_id, -1) AS network_id,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(upstream_network.network_id, COALESCE(network.network_id, -1)),
      COALESCE(upstream_network.network_id, -1)
    ) AS content_owner_id,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.distributor_network_id, -1),
      -1
    ) AS distributor_id,
    CASE
      WHEN COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated'
      AND network.network_id = request.video_cro_network_id
      THEN 'cro'
    END AS transaction_type,
    COALESCE(t.external_network_id, COALESCE(network.network_id, -1)) AS reseller_id,
    'full_visibility' AS reseller_visibility,
    IF(COALESCE(t.external_network_id, -1) = -1, 'full', 'internal') AS reseller_network_type,
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
    IF(COALESCE(t.external_network_id, -1) = -1, 2, 3) AS sales_channel,
    IF(
      COALESCE(t.external_network_id, -1) = -1,
      'direct sold',
      'reseller sold - reseller tag'
    ) AS sales_strategy,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_id, -1),
      -1
    ) AS site_id,
    IF(
      COALESCE(network.supply_source_type, 'unknown') = 'owned_and_operated',
      COALESCE(request.video_cro_site_section_id, -1),
      -1
    ) AS site_section_id,
    COALESCE(request.standard_publisher_id, -1) AS standard_publisher_id,
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
      NOT network.data_right.content_form_visibility.report_aggregate IS NULL
      OR network.supply_source_type <> 'mrm_rule',
      COALESCE(request.content_form_id, -1),
      -1
    ) AS content_form_id,
    COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), -1) AS stream_mode_id,
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
      NOT network.data_right.standard_endpoint_visibility.report_aggregate IS NULL
      OR network.supply_source_type <> 'mrm_rule',
      COALESCE(request.standard_endpoint_id, -1),
      -1
    ) AS standard_endpoint_id,
    COALESCE(
      network.data_right.standard_endpoint_visibility.report_aggregate,
      'full_visibility'
    ) AS standard_endpoint_visibility,
    COALESCE(request.country_id, -1) AS user_country_id,
    COALESCE(network.data_right.geo_country_visibility.report_aggregate, 'full_visibility') AS geo_country_visibility,
    IF(
      CARDINALITY(request.standard_device_type_ids) > 0,
      COALESCE(ELEMENT_AT(request.standard_device_type_ids, -1), -1),
      -1
    ) AS standard_device_type_id,
    COALESCE(request.standard_app_id, -1) AS standard_app_id,
    COALESCE(request.standard_environment_id, -1) AS standard_environment_id,
    COALESCE(request.standard_os_id, -1) AS standard_os_id,
    COALESCE(network.data_right.user_agent_visibility.report_aggregate, 'full_visibility') AS user_agent_visibility,
    COALESCE(request.profile_id, -1) AS profile_id,
    'compound' AS profile_type,
    'unknown' AS request_fill_status,
    FALSE AS live_linear_indicator,
    IF(BITWISE_AND(COALESCE(request.extra_flags2, 0), 8) > 0, TRUE, FALSE) AS ssp_bidder_indicator,
    FALSE AS partner_tag_indicator,
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
    CASE
      WHEN slot.time_position_class = 'overlay' AND slot.num_ads = 0 AND slot.max_ads > 0
      THEN 'empty - slots with avails'
      WHEN slot.time_position_class = 'overlay' AND slot.num_ads = 0 AND slot.max_ads = 0
      THEN 'empty - slots without avails'
      WHEN slot.time_position_class = 'overlay' AND slot.num_ads = slot.max_ads
      THEN 'fully filled'
      WHEN slot.time_position_class = 'overlay'
      AND slot.num_ads > 0
      AND slot.num_ads < slot.max_ads
      THEN 'partially filled'
      WHEN slot.num_ads = 0 AND COALESCE(slot.unfilled_avails, 0) > 0
      THEN 'empty - slots with avails'
      WHEN slot.num_ads = 0 AND slot.unfilled_avails = 0
      THEN 'empty - slots without avails'
      WHEN slot.unfilled_avails = 0
      THEN 'fully filled'
      WHEN slot.num_ads > 0 AND slot.unfilled_avails > 0
      THEN 'partially filled'
      ELSE 'unknown'
    END AS slot_fill_status,
    IF(
      BITWISE_AND(COALESCE(ad.entity_flags, 0), BITWISE_SHIFT_LEFT(1, 35, 64)) > 0,
      'yes',
      'no'
    ) AS evergreen_ad_indicator,
    IF(
      BITWISE_AND(COALESCE(ad.entity_flags, 0), BITWISE_SHIFT_LEFT(1, 2, 64)) > 0,
      'yes',
      'no'
    ) AS promo_ad_indicator,
    COALESCE(ad.effective_unified_priority.priority_tier, 'unknown') AS priority_tier,
    CASE
      WHEN COALESCE(t.external_network_id, -1) = -1
      THEN (
        CASE
          WHEN COALESCE(ad.effective_unified_priority.priority_tier, 'unknown') IN ('tier_1', 'tier_2')
          THEN COALESCE(ad.ad_priority_type, 'unknown')
          WHEN COALESCE(ad.effective_unified_priority.priority_tier, 'unknown') IN ('tier_3', 'tier_4')
          THEN IF(
            COALESCE(ad.ad_priority_type, 'unknown') = 'unknown',
            IF(BITWISE_AND(ad.entity_flags, 1) > 0, 'guaranteed', 'preemptible'),
            CONCAT(
              IF(BITWISE_AND(ad.entity_flags, 1) > 0, 'guaranteed', 'preemptible'),
              '_',
              COALESCE(ad.ad_priority_type, 'unknown')
            )
          )
          WHEN COALESCE(ad.effective_unified_priority.priority_tier, 'unknown') IN ('tier_6')
          THEN 'house_ads'
          ELSE COALESCE(ad.ad_priority_type, 'unknown')
        END
      )
      ELSE 'unknown'
    END AS priority_type,
    ad.effective_unified_priority.sub_priority_value AS priority_value,
    IF(BITWISE_AND(COALESCE(slot_ad.flags, 0), 1024) > 0, 1, 0) AS meet_schedule,
    CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 1 ELSE 0 END AS request_traffic_type,
    0 AS ack_traffic_type,
    COALESCE(network.inbound_order.order_id, -1) AS inbound_order_id,
    COALESCE(ad.ad_id, -1) AS ad_id,
    COALESCE(t.placement_id, -1) AS placement_id,
    COALESCE(ad.global_advertiser_ids, ARRAY[]) AS global_advertiser_ids,
    COALESCE(ad.global_brand_ids, ARRAY[]) AS global_brand_ids,
    COALESCE(ad.advertiser_id, -1) AS local_advertiser_id,
    IF(
      BITWISE_AND(COALESCE(slot_ad.flags, 0), 32) = 0
      OR (
        BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 32) > 0
        AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 33554432) > 0
      ),
      'primary',
      'fallback'
    ) AS primary_ad_indicator,
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
    CAST(0 AS BIGINT) AS tx_err_not_allowed_upstream_network_for_rule,
    CAST(0 AS BIGINT) AS tx_err_compliance_not_approved,
    CAST(0 AS BIGINT) AS tx_err_data_visibility_banned,
    CAST(0 AS BIGINT) AS tx_err_reseller_whitelist_not_allowed,
    CAST(0 AS BIGINT) AS tx_err_reseller_blacklist_banned,
    CAST(0 AS BIGINT) AS tx_err_no_applicable_slot,
    CAST(0 AS BIGINT) AS tx_err_no_applicable_creative,
    CAST(0 AS BIGINT) AS tx_err_invalid_compliance_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_rule_compliance_check_failed,
    CAST(0 AS BIGINT) AS tx_err_exceed_max_slot_duration,
    CAST(0 AS BIGINT) AS tx_err_competition_failure,
    CAST(0 AS BIGINT) AS tx_err_exclusivity_by_stream,
    CAST(0 AS BIGINT) AS tx_err_creative_restriction_check_failed,
    CAST(0 AS BIGINT) AS tx_err_clearcast_code_restricted,
    CAST(0 AS BIGINT) AS tx_err_no_brand_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_ad_targeting_restricted,
    CAST(0 AS BIGINT) AS tx_err_budget_met,
    CAST(0 AS BIGINT) AS tx_err_listing_creative_duration_check,
    CAST(0 AS BIGINT) AS tx_err_advertiser_industry_restriction,
    CAST(0 AS BIGINT) AS tx_err_brand_blacklist_restriction,
    CAST(0 AS BIGINT) AS tx_err_advertiser_blacklist_restriction,
    CAST(0 AS BIGINT) AS tx_err_schedule_met,
    CAST(0 AS BIGINT) AS tx_err_slot_compatiblity_check,
    CAST(0 AS BIGINT) AS tx_err_rating_restriction,
    CAST(0 AS BIGINT) AS tx_err_mkpl_order_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_inventory,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_inventory,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_domain,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_inventory_source_optimization_imr,
    CAST(0 AS BIGINT) AS tx_err_inbound_rule_targeting_not_met,
    CAST(0 AS BIGINT) AS tx_err_inbound_rule_explicit_targeting_required,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_empty_advertiser_domain,
    CAST(0 AS BIGINT) AS tx_err_low_ranking_in_buyer,
    CAST(0 AS BIGINT) AS tx_err_industry_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_lower_bidding_price_than_mkpl_order_price,
    CAST(0 AS BIGINT) AS tx_err_wrapper_timeout,
    CAST(0 AS BIGINT) AS tx_err_wrapper_http_error,
    CAST(0 AS BIGINT) AS tx_err_no_valid_creative,
    CAST(0 AS BIGINT) AS tx_err_unsupported_vast_version,
    CAST(0 AS BIGINT) AS tx_err_floor_price_notmet,
    CAST(0 AS BIGINT) AS tx_err_no_valid_currency,
    CAST(0 AS BIGINT) AS tx_err_mkpl_exchange_advertiser_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_mkpl_exchange_brand_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_mkpl_exchange_industry_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_industry_restricted_by_sa,
    CAST(0 AS BIGINT) AS tx_err_targeted_schedule_met,
    CAST(0 AS BIGINT) AS tx_err_targeted_budget_met,
    CAST(0 AS BIGINT) AS tx_err_yield_opt_met,
    CAST(0 AS BIGINT) AS tx_err_inflight_bid_met,
    CAST(0 AS BIGINT) AS tx_err_inbound_order_competition_failure,
    CAST(0 AS BIGINT) AS tx_err_competition_failure_in_pick_many,
    CAST(0 AS BIGINT) AS tx_err_find_rule_path_failure,
    CAST(0 AS BIGINT) AS tx_err_failed_sov_percent_check,
    CAST(0 AS BIGINT) AS tx_err_failed_sop_percent_check,
    CAST(0 AS BIGINT) AS tx_err_failed_soi_percent_check,
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
    SUM(IF(slot_ad.error = 197, COALESCE(magnifier, 1), 0)) AS slot_err_advertiser_frequency_cap_reaching,
    COALESCE(network.data_right.content_form_visibility.report_aggregate, 'full_visibility') AS content_form_visibility,
    DATE_TRUNC('HOUR', FROM_UNIXTIME(timestamp)) AS event_date,
    DATE_FORMAT(DATE_PARSE(dt, '%y-%m-%d-%h'), '%y%m%d%h0000') AS process_batch_id
  FROM db.troubleshooting_log.fw_ads_demand_troubleshooting_log
  CROSS JOIN UNNEST(ad_selection_info) AS t
  CROSS JOIN UNNEST(t.ad_infos) AS ad
  CROSS JOIN UNNEST(ad.slot_ad_infos) AS slot_ad
  CROSS JOIN UNNEST(slots) AS slot
  WHERE
    slot_ad.slot_index = slot.index AND BITWISE_AND(slot.flags, 64) = 0
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
    55,
    56,
    57,
    58,
    153,
    154,
    155
  UNION ALL
  SELECT
    CAST(32 AS INTEGER) AS process_stage,
    COALESCE(nw.nw_id, -1) AS network_id,
    COALESCE(nw.co_id, -1) AS content_owner_id,
    COALESCE(nw.distributor_id, -1) AS distributor_id,
    COALESCE(nw.nw_role, '') AS transaction_type,
    COALESCE(nw.reseller_id, -1) AS reseller_id,
    IF(nw.sales_channel = 4, 'no_visibility', 'full_visibility') AS reseller_visibility,
    COALESCE(reseller.network_type, 'unknown') AS reseller_network_type,
    COALESCE(nw.supply_source, -1) AS supply_source,
    COALESCE(nw.sales_channel, -1) AS sales_channel,
    CASE
      WHEN COALESCE(nw.sales_channel, -1) = 2
      THEN 'direct sold'
      WHEN COALESCE(nw.sales_channel, -1) = 3 AND reseller.network_type = 'full'
      THEN 'mrm partner'
      WHEN COALESCE(nw.sales_channel, -1) = 3 AND reseller.network_type = 'internal'
      THEN 'reseller sold - reseller tag'
      WHEN COALESCE(nw.sales_channel, -1) = 4
      THEN 'programmatic'
      WHEN COALESCE(nw.sales_channel, -1) = 5
      THEN 'mrm partner'
      WHEN COALESCE(nw.sales_channel, -1) = 6
      THEN 'mrm partner'
      ELSE 'unknown'
    END AS sales_strategy,
    COALESCE(nw.site_id, -1) AS site_id,
    COALESCE(nw.site_section_id, -1) AS site_section_id,
    COALESCE(request__context__standard_publisher_id, -1) AS standard_publisher_id,
    IF(
      NOT nw.sa_brand_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_brand_id, -1),
      -1
    ) AS standard_brand_id,
    COALESCE(nw.sa_brand_visibility, 'full_visibility') AS standard_brand_visibility,
    IF(
      NOT nw.sa_programmer_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_programmer_id, -1),
      -1
    ) AS standard_programmer_id,
    COALESCE(nw.sa_programmer_visibility, 'full_visibility') AS standard_programmer_visibility,
    IF(
      NOT nw.content_form_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__content_form_id, -1),
      -1
    ) AS content_form_id,
    COALESCE(request__context__stream_mode_id, -1) AS stream_mode_id,
    IF(
      NOT nw.sa_endpoint_owner_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_endpoint_owner_id, -1),
      -1
    ) AS standard_endpoint_owner_id,
    COALESCE(nw.sa_endpoint_owner_visibility, 'full_visibility') AS standard_endpoint_owner_visibility,
    IF(
      NOT nw.sa_endpoint_visibility IS NULL OR nw.supply_source <> 3,
      COALESCE(request__context__standard_endpoint_id, -1),
      -1
    ) AS standard_endpoint_id,
    COALESCE(nw.sa_endpoint_visibility, 'full_visibility') AS standard_endpoint_visibility,
    COALESCE(visitor__country_id, -1) AS user_country_id,
    COALESCE(nw.country_visibility, 'full_visibility') AS geo_country_visibility,
    COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
    COALESCE(request__context__standard_app_id, -1) AS standard_app_id,
    COALESCE(visitor__standard_environment_id, -1) AS standard_environment_id,
    COALESCE(visitor__standard_os_id, -1) AS standard_os_id,
    COALESCE(nw.user_agent_visibility, 'full_visibility') AS user_agent_visibility,
    COALESCE(request__context__profile_id, -1) AS profile_id,
    COALESCE(request__context__profile_type, 'unknown') AS profile_type,
    CASE
      WHEN BITWISE_AND(request__flags, 32) > 0
      THEN 'no selection'
      WHEN COALESCE(request__advertisement_delivered_count, COALESCE(request__advertisement_count, 0)) = 0
      THEN 'empty'
      ELSE 'filled'
    END AS request_fill_status,
    IF(BITWISE_AND(COALESCE(request__extra_flags, 0), 1024) > 0, TRUE, FALSE) AS live_linear_indicator,
    IF(BITWISE_AND(COALESCE(request__extra_flags2, 0), 8) > 0, TRUE, FALSE) AS ssp_bidder_indicator,
    IF(BITWISE_AND(COALESCE(bit_flag, 0), BITWISE_SHIFT_LEFT(1, 40, 64)) > 0, TRUE, FALSE) AS partner_tag_indicator,
    ARRAY[COALESCE(slot__time_position_class, 'unknown')] AS time_position_classes,
    ARRAY[COALESCE(slot__normalized_ad_unit_id, -1)] AS slot_ad_unit_ids,
    CASE
      WHEN slot__sequence IS NULL
      THEN 'null'
      WHEN slot__sequence > 5
      THEN '5+'
      ELSE CAST(slot__sequence AS VARCHAR)
    END AS slot_sequence_normalized,
    'not applicable' AS slot_user_drop_off,
    IF(BITWISE_AND(COALESCE(slot__flags, 0), 8) > 0, 'yes', 'no') AS slot_removed_by_ux_indicator,
    CASE
      WHEN slot__time_position_class = 'overlay' AND slot__num_ads = 0 AND slot__max_ads > 0
      THEN 'empty - slots with avails'
      WHEN slot__time_position_class = 'overlay' AND slot__num_ads = 0 AND slot__max_ads = 0
      THEN 'empty - slots without avails'
      WHEN slot__time_position_class = 'overlay' AND slot__num_ads = slot__max_ads
      THEN 'fully filled'
      WHEN slot__time_position_class = 'overlay'
      AND slot__num_ads > 0
      AND slot__num_ads < slot__max_ads
      THEN 'partially filled'
      WHEN slot__num_ads = 0 AND COALESCE(slot__unfilled_avails, 0) > 0
      THEN 'empty - slots with avails'
      WHEN slot__num_ads = 0 AND slot__unfilled_avails = 0
      THEN 'empty - slots without avails'
      WHEN slot__unfilled_avails = 0
      THEN 'fully filled'
      WHEN slot__num_ads > 0 AND slot__unfilled_avails > 0
      THEN 'partially filled'
      ELSE 'unknown'
    END AS slot_fill_status,
    IF(
      is_extra_item_owner = TRUE,
      IF(
        BITWISE_AND(COALESCE(advertisement__entity_flags, 0), BITWISE_SHIFT_LEFT(1, 35, 64)) > 0,
        'yes',
        'no'
      ),
      'not applicable'
    ) AS evergreen_ad_indicator,
    IF(
      is_extra_item_owner = TRUE,
      IF(
        BITWISE_AND(COALESCE(advertisement__entity_flags, 0), BITWISE_SHIFT_LEFT(1, 2, 64)) > 0,
        'yes',
        'no'
      ),
      'not applicable'
    ) AS promo_ad_indicator,
    CASE
      WHEN nw.sales_channel = 2
      THEN IF(
        nw_role = 'cro',
        COALESCE(advertisement__effective_unified_priority__priority_tier, 'unknown'),
        COALESCE(advertisement__unified_priority__priority_tier, 'unknown')
      )
      WHEN nw.sales_channel = 3
      THEN COALESCE(rule_priority_tier, 'unknown')
      WHEN nw.sales_channel = 4
      THEN IF(
        nw_role = 'cro',
        COALESCE(advertisement__effective_unified_priority__priority_tier, 'unknown'),
        CASE
          WHEN COALESCE(candidate__internal_deal_id, -1) > 0
          THEN COALESCE(candidate__unified_deal_priority__priority_tier, 'unknown')
          WHEN COALESCE(candidate__buyer_group_id, -1) > 0
          THEN COALESCE(rule_priority_tier, 'unknown')
          ELSE 'unknown'
        END
      )
      WHEN nw.sales_channel IN (5, 6)
      THEN COALESCE(nw.order_priority_tier, 'unknown')
      ELSE 'unknown'
    END AS priority_tier,
    CASE
      WHEN sales_channel = 2
      THEN (
        CASE
          WHEN IF(
            nw_role = 'cro',
            COALESCE(advertisement__effective_unified_priority__priority_tier, 'unknown'),
            COALESCE(advertisement__unified_priority__priority_tier, 'unknown')
          ) IN ('tier_1', 'tier_2')
          THEN COALESCE(advertisement__ad_priority_type, 'unknown')
          WHEN IF(
            nw_role = 'cro',
            COALESCE(advertisement__effective_unified_priority__priority_tier, 'unknown'),
            COALESCE(advertisement__unified_priority__priority_tier, 'unknown')
          ) IN ('tier_3', 'tier_4')
          THEN IF(
            COALESCE(advertisement__ad_priority_type, 'unknown') = 'unknown',
            IF(BITWISE_AND(advertisement__entity_flags, 1) > 0, 'guaranteed', 'preemptible'),
            CONCAT(
              IF(BITWISE_AND(advertisement__entity_flags, 1) > 0, 'guaranteed', 'preemptible'),
              '_',
              COALESCE(advertisement__ad_priority_type, 'unknown')
            )
          )
          WHEN IF(
            nw_role = 'cro',
            COALESCE(advertisement__effective_unified_priority__priority_tier, 'unknown'),
            COALESCE(advertisement__unified_priority__priority_tier, 'unknown')
          ) IN ('tier_6')
          THEN 'house_ads'
          ELSE COALESCE(advertisement__ad_priority_type, 'unknown')
        END
      )
      WHEN sales_channel = 3
      THEN (
        CASE
          WHEN COALESCE(rule_priority, 'unknown') = 'you_first'
          THEN 'hard_guaranteed_with_passback'
          WHEN COALESCE(rule_priority, 'unknown') = 'me_first'
          THEN 'backfill_only'
          WHEN COALESCE(rule_priority, 'unknown') = 'hard_guaranteed'
          THEN 'hard_guaranteed_without_passback'
          ELSE COALESCE(rule_priority, 'unknown')
        END
      )
      WHEN sales_channel = 4
      THEN (
        CASE
          WHEN COALESCE(candidate__internal_deal_id, -1) > 0
          THEN (
            CASE
              WHEN COALESCE(candidate__deal_type, 'na') = 'programmatic_guaranteed_trading_desk_deal'
              THEN 'programmatic_guaranteed'
              WHEN COALESCE(candidate__deal_type, 'na') = 'biddable_guaranteed_deal'
              THEN 'biddable_guaranteed'
              WHEN COALESCE(candidate__deal_type, 'na') = 'first_look_deal'
              THEN 'first_look'
              ELSE COALESCE(candidate__deal_type, 'na')
            END
          )
          ELSE (
            CASE
              WHEN COALESCE(rule_priority, 'unknown') = 'me_first'
              THEN 'backfill_only'
              ELSE COALESCE(rule_priority, 'unknown')
            END
          )
        END
      )
      WHEN sales_channel IN (5, 6)
      THEN IF(
        COALESCE(order_priority, 'unknown') = 'priority_none',
        'inventory_split',
        REPLACE(COALESCE(order_priority, 'na'), 'priority_', '')
      )
      ELSE 'unknown'
    END AS priority_type,
    CASE
      WHEN sales_channel = 2
      THEN IF(
        nw_role = 'cro',
        advertisement__effective_unified_priority__sub_priority_value,
        advertisement__unified_priority__sub_priority_value
      )
      WHEN sales_channel = 3
      THEN rule_priority_value
      WHEN sales_channel = 4
      THEN IF(
        nw_role = 'cro',
        IF(
          COALESCE(advertisement__effective_unified_priority__priority_tier, 'unknown') = 'tier_1'
          AND advertisement__effective_unified_priority__sub_priority_value <= 5,
          advertisement__effective_unified_priority__sub_priority_value + 25,
          advertisement__effective_unified_priority__sub_priority_value
        ),
        CASE
          WHEN COALESCE(candidate__internal_deal_id, -1) > 0
          THEN candidate__unified_deal_priority__sub_priority_value
          WHEN COALESCE(candidate__buyer_group_id, -1) > 0
          THEN rule_priority_value
          ELSE NULL
        END
      )
      WHEN sales_channel IN (5, 6)
      THEN outbound_order_priority_value
      ELSE NULL
    END AS priority_value,
    IF(is_extra_item_owner = TRUE AND BITWISE_AND(advertisement__flags, 1024) > 0, 1, 0) AS meet_schedule,
    COALESCE(request__traffic_type, 0) AS request_traffic_type,
    COALESCE(ack__traffic_type, 0) AS ack_traffic_type,
    COALESCE(inbound_order_id, CAST(-1 AS BIGINT)) AS inbound_order_id,
    IF(network_is_ad_owner, COALESCE(advertisement__ad_id, -1), -1) AS ad_id,
    IF(network_is_ad_owner, COALESCE(advertisement__placement_id, -1), -1) AS placement_id,
    COALESCE(advertisement__global_advertiser_ids, ARRAY[]) AS global_advertiser_ids,
    COALESCE(advertisement__global_brand_ids, ARRAY[]) AS global_brand_ids,
    IF(network_is_ad_owner, COALESCE(advertisement__advertiser_id, -1), -1) AS local_advertiser_id,
    IF(advertisement__is_fallback = FALSE, 'primary', 'fallback') AS primary_ad_indicator,
    CAST(0 AS BIGINT) AS candidate_ads,
    CAST(0 AS BIGINT) AS tx_eligible_ads,
    CAST(0 AS BIGINT) AS slot_eligible_ads,
    CAST(0 AS BIGINT) AS placed_ads_sampled,
    CAST(0 AS BIGINT) AS placed_fallback_ads_sampled,
    CAST(0 AS BIGINT) AS filled_ads_sstf_fallback_sampled,
    CAST(0 AS BIGINT) AS selected_ads_sampled,
    SUM(
      COALESCE(ack__metrics__raw_ad_impression, 0) * COALESCE(request__demand_log_magnifier, 0)
    ) AS gross_ad_views_sampled,
    CAST(0 AS BIGINT) AS placement_err_total,
    CAST(0 AS BIGINT) AS ad_err_total,
    CAST(0 AS BIGINT) AS slot_err_total,
    CAST(0 AS BIGINT) AS tx_err_malformed_response,
    CAST(0 AS BIGINT) AS tx_err_empty_response,
    CAST(0 AS BIGINT) AS tx_err_price_hurdle_check_failed,
    CAST(0 AS BIGINT) AS tx_err_profile_check_failed,
    CAST(0 AS BIGINT) AS tx_err_frequency_cap_failed,
    CAST(0 AS BIGINT) AS tx_err_not_allowed_upstream_network_for_ad,
    CAST(0 AS BIGINT) AS tx_err_not_allowed_upstream_network_for_rule,
    CAST(0 AS BIGINT) AS tx_err_compliance_not_approved,
    CAST(0 AS BIGINT) AS tx_err_data_visibility_banned,
    CAST(0 AS BIGINT) AS tx_err_reseller_whitelist_not_allowed,
    CAST(0 AS BIGINT) AS tx_err_reseller_blacklist_banned,
    CAST(0 AS BIGINT) AS tx_err_no_applicable_slot,
    CAST(0 AS BIGINT) AS tx_err_no_applicable_creative,
    CAST(0 AS BIGINT) AS tx_err_invalid_compliance_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_rule_compliance_check_failed,
    CAST(0 AS BIGINT) AS tx_err_exceed_max_slot_duration,
    CAST(0 AS BIGINT) AS tx_err_competition_failure,
    CAST(0 AS BIGINT) AS tx_err_exclusivity_by_stream,
    CAST(0 AS BIGINT) AS tx_err_creative_restriction_check_failed,
    CAST(0 AS BIGINT) AS tx_err_clearcast_code_restricted,
    CAST(0 AS BIGINT) AS tx_err_no_brand_for_inventory_protection,
    CAST(0 AS BIGINT) AS tx_err_ad_targeting_restricted,
    CAST(0 AS BIGINT) AS tx_err_budget_met,
    CAST(0 AS BIGINT) AS tx_err_listing_creative_duration_check,
    CAST(0 AS BIGINT) AS tx_err_advertiser_industry_restriction,
    CAST(0 AS BIGINT) AS tx_err_brand_blacklist_restriction,
    CAST(0 AS BIGINT) AS tx_err_advertiser_blacklist_restriction,
    CAST(0 AS BIGINT) AS tx_err_schedule_met,
    CAST(0 AS BIGINT) AS tx_err_slot_compatiblity_check,
    CAST(0 AS BIGINT) AS tx_err_rating_restriction,
    CAST(0 AS BIGINT) AS tx_err_mkpl_order_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_inventory,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_inventory,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_global_advertiser_restricted_by_domain,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_inventory_source_optimization_imr,
    CAST(0 AS BIGINT) AS tx_err_inbound_rule_targeting_not_met,
    CAST(0 AS BIGINT) AS tx_err_inbound_rule_explicit_targeting_required,
    CAST(0 AS BIGINT) AS tx_err_global_brand_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_blocked_by_empty_advertiser_domain,
    CAST(0 AS BIGINT) AS tx_err_low_ranking_in_buyer,
    CAST(0 AS BIGINT) AS tx_err_industry_restricted_by_listing,
    CAST(0 AS BIGINT) AS tx_err_lower_bidding_price_than_mkpl_order_price,
    CAST(0 AS BIGINT) AS tx_err_wrapper_timeout,
    CAST(0 AS BIGINT) AS tx_err_wrapper_http_error,
    CAST(0 AS BIGINT) AS tx_err_no_valid_creative,
    CAST(0 AS BIGINT) AS tx_err_unsupported_vast_version,
    CAST(0 AS BIGINT) AS tx_err_floor_price_notmet,
    CAST(0 AS BIGINT) AS tx_err_no_valid_currency,
    CAST(0 AS BIGINT) AS tx_err_mkpl_exchange_advertiser_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_mkpl_exchange_brand_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_mkpl_exchange_industry_floor_price_not_met,
    CAST(0 AS BIGINT) AS tx_err_industry_restricted_by_sa,
    CAST(0 AS BIGINT) AS tx_err_targeted_schedule_met,
    CAST(0 AS BIGINT) AS tx_err_targeted_budget_met,
    CAST(0 AS BIGINT) AS tx_err_yield_opt_met,
    CAST(0 AS BIGINT) AS tx_err_inflight_bid_met,
    CAST(0 AS BIGINT) AS tx_err_inbound_order_competition_failure,
    CAST(0 AS BIGINT) AS tx_err_competition_failure_in_pick_many,
    CAST(0 AS BIGINT) AS tx_err_find_rule_path_failure,
    CAST(0 AS BIGINT) AS tx_err_failed_sov_percent_check,
    CAST(0 AS BIGINT) AS tx_err_failed_sop_percent_check,
    CAST(0 AS BIGINT) AS tx_err_failed_soi_percent_check,
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
    CAST(0 AS BIGINT) AS slot_err_advertiser_frequency_cap_reaching,
    COALESCE(nw.content_form_visibility, 'full_visibility') AS content_form_visibility,
    DATE_TRUNC('HOUR', ack__timestamp) AS event_date,
    process_batch_id AS process_batch_id
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(partners__network_id, partners__site_id, partners__site_section_id, partners__distributor_network_id, partners__content_owner_network_id, partners__reseller_network_id, partners__sales_channel, partners__role, partners__supply_source, partners__geo_country_visibility__report_aggregate, partners__standard_brand_visibility__report_aggregate, partners__standard_programmer_visibility__report_aggregate, partners__standard_endpoint_visibility__report_aggregate, partners__standard_endpoint_owner_visibility__report_aggregate, partners__user_agent_visibility__report_aggregate, partners__content_form_visibility__report_aggregate, partners__global_currency_id, partners__network_is_extra_item_owner, partners__demand_dim_awareability, partners__deal_awareability, partners__outbound_order_id, partners__outbound_exchange_order_id, partners__inbound_order_id, partners__unified_outbound_order_priority__priority_tier, partners__unified_outbound_order_priority__sub_priority_value, partners__outbound_order_priority_type, partners__unified_rule_priority__priority_tier, partners__unified_rule_priority__sub_priority_value, partners__rule_type_priority, partners__network_is_ad_owner, partners__revenue, partners__content_owner_revenue, partners__reseller_revenue, partners__distributor_revenue, partners__bit_flags) AS nw(nw_id, site_id, site_section_id, distributor_id, co_id, reseller_id, sales_channel, nw_role, supply_source, country_visibility, sa_brand_visibility, sa_programmer_visibility, sa_endpoint_visibility, sa_endpoint_owner_visibility, user_agent_visibility, content_form_visibility, global_currency_id, is_extra_item_owner, demand_dim_awareability, deal_awareability, outbound_order_id, outbound_exchange_order_id, inbound_order_id, order_priority_tier, outbound_order_priority_value, order_priority, rule_priority_tier, rule_priority_value, rule_priority, network_is_ad_owner, revenue, content_owner_revenue, reseller_revenue, distributor_revenue, bit_flag)
  LEFT JOIN db.default.d_network AS reseller
    ON reseller.id = COALESCE(nw.reseller_id, -1)
  WHERE
    (
      (
        (
          (
            (
              (
                (
                  BITWISE_AND(slot__flags, 64) = 0 AND COALESCE(nw.nw_role, '') IN ('cro', 'r')
                )
                AND COALESCE(advertisement__is_bumper, FALSE) = FALSE
              )
              AND supply_source <> 4
            )
            AND NOT (
              BITWISE_AND(COALESCE(request__extra_flags2, 0), 8) > 0
              AND COALESCE(nw.nw_role, '') = 'cro'
            )
          )
          AND BITWISE_AND(bit_flag, BITWISE_SHIFT_LEFT(1, 41, 64)) = 0
        )
        AND COALESCE(ack__ack_entity_type, '') = 'ad'
      )
      AND (
        ack__is_private_impression = FALSE
        OR network_is_ad_owner = TRUE
        OR is_extra_item_owner = TRUE
      )
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
    55,
    56,
    57,
    58,
    153,
    154,
    155
) AS f
LEFT JOIN ad_unit_map AS aum
  ON aum.network_id = f.network_id
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
  120,
  121,
  137,
  156
