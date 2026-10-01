-- account:    sa-dataapp-yield
-- skeleton:   fd68e1ebead8763e4ab085f329a99748
-- pattern:    c314cf3793cbb37d6ff5cc1751636079  (609 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH device_type AS (
  SELECT
    MAP_AGG(id, name) AS device_name_map
  FROM db.default.d_lu_mkpl_standard_device_type
)
SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(cro.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(dis.name, 'na') AS distributor_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
  COALESCE(visitor__country_id, -1) AS country_id,
  COALESCE(ctry.description, 'unknown country') AS country_name,
  COALESCE(request__context__standard_endpoint_owner_id, -1) AS endpoint_owner_id,
  COALESCE(eo.name, 'unknown endpoint owner') AS endpoint_owner_name,
  COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
  COALESCE(ep.name, 'unknown endpoint') AS endpoint_name,
  COALESCE(t.content_owner_network_id, -1) AS seller_network_id,
  COALESCE(co.name, 'na') AS seller_network_name,
  COALESCE(t.network_id, -1) AS buyer_network_id,
  COALESCE(ssp.name, network.name) AS buyer_network_name,
  COALESCE(t.network_role, 'na') AS buyer_network_role,
  COALESCE(request__context__site_section_id, -1) AS distributor_site_section_id,
  COALESCE(request__context__site_section_cro_site_id, -1) AS distributor_site_id,
  COALESCE(site.site_name, 'na') AS distributor_site_name,
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
  COALESCE(visitor__standard_environment_id, -1) AS environment_id,
  COALESCE(env.name, 'na') AS environment_name,
  COALESCE(visitor__standard_os_id, -1) AS os_id,
  COALESCE(os.name, 'na') AS os_name,
  COALESCE(visitor__standard_device_type_ids, ARRAY[]) AS device_type_ids,
  TRANSFORM(
    visitor__standard_device_type_ids,
    x -> COALESCE(ELEMENT_AT(device_name_map, x), 'na')
  ) AS device_type_names,
  CASE
    WHEN supply_source = 1
    THEN 'o&o'
    WHEN supply_source = 3 AND network.network_type = 'full'
    THEN 'mrm2mrm'
    WHEN supply_source = 3 AND network.network_type = 'internal'
    THEN 'reseller tag'
    WHEN supply_source = 4
    THEN 'programmatic'
    WHEN supply_source = 5
    THEN 'partner trading(mpp)'
    WHEN supply_source = 6
    THEN 'marketplace platform exchange(mpe)'
    ELSE 'unknown supply source'
  END AS supply_source,
  COALESCE(inbound_order_id, -1) AS order_id,
  COALESCE(orders.name, 'na') AS order_name,
  COALESCE(orders.transaction_type, 'na') AS order_transaction_type,
  COALESCE(orders.priority_type, 'na') AS order_priority_type,
  COALESCE(orders.priority_value, -1) AS order_priority_value,
  COALESCE(t.order_type, 'na') AS order_type,
  COALESCE(listing_id[1], -1) AS listing_id,
  COALESCE(listing.name, 'na') AS listing_name,
  CASE
    WHEN BITWISE_AND(request__extra_flags2, 8) > 0
    AND is_ad_owner
    AND COALESCE(content_owner_bidding_revenue, 0) * 1000 <= 15
    THEN '0-15'
    WHEN BITWISE_AND(request__extra_flags2, 8) > 0
    AND is_ad_owner
    AND COALESCE(content_owner_bidding_revenue, 0) * 1000 > 15
    AND COALESCE(content_owner_bidding_revenue, 0) * 1000 <= 20
    THEN '15-20'
    WHEN BITWISE_AND(request__extra_flags2, 8) > 0
    AND is_ad_owner
    AND COALESCE(content_owner_bidding_revenue, 0) * 1000 > 20
    AND COALESCE(content_owner_bidding_revenue, 0) * 1000 <= 25
    THEN '20-25'
    WHEN BITWISE_AND(request__extra_flags2, 8) > 0
    AND is_ad_owner
    AND COALESCE(content_owner_bidding_revenue, 0) * 1000 > 25
    AND COALESCE(content_owner_bidding_revenue, 0) * 1000 <= 30
    THEN '25-30'
    WHEN BITWISE_AND(request__extra_flags2, 8) > 0
    AND is_ad_owner
    AND COALESCE(content_owner_bidding_revenue, 0) * 1000 > 30
    THEN '30+'
    ELSE 'na'
  END AS bid_price,
  IF(BITWISE_AND(request__extra_flags2, 8) > 0, 'bidder', 'mrm') AS is_bidder_traffic,
  COALESCE(request__context__standard_programmer_id, -1) AS programmer_id,
  COALESCE(pg.name, 'na') AS programmer_name,
  SUM(
    REDUCE(COALESCE(t.p6_input_ad_number, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase6_input_ad_number,
  SUM(
    REDUCE(COALESCE(t.p6_output_ad_number, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase6_output_ad_number,
  SUM(
    REDUCE(COALESCE(t.p6_data_privacy, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase6_data_privacy,
  SUM(
    REDUCE(COALESCE(t.p6_restriction, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase6_restriction,
  SUM(
    REDUCE(COALESCE(t.p7_input_ad_number, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase7_input_ad_number,
  SUM(
    REDUCE(COALESCE(t.p7_output_ad_number, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase7_output_ad_number,
  SUM(
    REDUCE(COALESCE(t.p7_no_ad_domain, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase7_no_ad_domain,
  SUM(
    REDUCE(
      COALESCE(t.p7_no_slot_assigned_through_mrm_rule, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase7_no_slot_assigned_through_mrm_rule,
  SUM(
    REDUCE(COALESCE(t.p7_frequency_cap, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase7_frequency_cap,
  SUM(
    REDUCE(COALESCE(t.p7_cpx_check_failed, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase7_cpx_check_failed,
  SUM(
    REDUCE(COALESCE(t.p7_met_schedule, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase7_met_schedule,
  SUM(
    REDUCE(COALESCE(t.p7_rbp_check_failed, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase7_rbp_check_failed,
  SUM(
    REDUCE(
      COALESCE(t.p7_no_applicable_slot, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase7_no_applicable_slot,
  SUM(
    REDUCE(
      COALESCE(t.p7_sponsorship_check_failed, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase7_sponsorship_check_failed,
  SUM(
    REDUCE(
      COALESCE(t.p7_exclusivity_check_failed, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase7_exclusivity_check_failed,
  SUM(
    REDUCE(
      COALESCE(t.p7_no_applicable_slot_user_experience, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase7_no_applicable_slot_user_experience,
  SUM(
    REDUCE(
      COALESCE(t.p7_no_applicable_slot_no_external_rule, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase7_no_applicable_slot_no_external_rule,
  SUM(
    REDUCE(
      COALESCE(t.p7_no_applicable_slot_not_resellable, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase7_no_applicable_slot_not_resellable,
  SUM(
    REDUCE(
      COALESCE(t.p7_no_applicable_slot_promo_only, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase7_no_applicable_slot_promo_only,
  SUM(
    REDUCE(
      COALESCE(t.p7_no_applicable_slot_not_compatible, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase7_no_applicable_slot_not_compatible,
  SUM(
    REDUCE(COALESCE(t.p7_met_budget, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase7_met_budget,
  SUM(
    REDUCE(
      COALESCE(t.p7_met_yield_optimization, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase7_met_yield_optimization,
  SUM(
    REDUCE(COALESCE(t.p8_input_ad_number, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase8_input_ad_number,
  SUM(
    REDUCE(COALESCE(t.p8_output_ad_number, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase8_output_ad_number,
  SUM(
    REDUCE(COALESCE(t.p8_frequency_cap, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase8_frequency_cap,
  SUM(
    REDUCE(
      COALESCE(t.p8_no_applicable_slot, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_no_applicable_slot,
  SUM(
    REDUCE(
      COALESCE(t.p8_compliance_check_failed, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_compliance_check_failed,
  SUM(
    REDUCE(COALESCE(t.p8_no_creative, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase8_no_creative,
  SUM(
    REDUCE(
      COALESCE(t.p8_no_suitable_rule_path, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_no_suitable_rule_path,
  SUM(
    REDUCE(
      COALESCE(t.p8_profile_check_failed, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_profile_check_failed,
  SUM(
    REDUCE(
      COALESCE(t.p8_floor_price_not_met, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_floor_price_not_met,
  SUM(
    REDUCE(COALESCE(t.p8_restriction, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase8_restriction,
  SUM(
    REDUCE(COALESCE(t.p8_exclusivity, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS phase8_exclusivity,
  SUM(
    REDUCE(
      COALESCE(t.p8_pg_deal_bid_throttling, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_pg_deal_bid_throttling,
  SUM(
    REDUCE(
      COALESCE(t.p8_auction_max_ad_duration, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_auction_max_ad_duration,
  SUM(
    REDUCE(
      COALESCE(t.p8_reseller_restriction, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_reseller_restriction,
  SUM(
    REDUCE(
      COALESCE(t.p8_market_ad_not_approved, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_market_ad_not_approved,
  SUM(
    REDUCE(
      COALESCE(t.p8_listing_creative_duration_check_failed, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_listing_creative_duration_check_failed,
  SUM(
    REDUCE(
      COALESCE(t.p8_no_creative_ad_asset_store_availability, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_no_creative_ad_asset_store_availability,
  SUM(
    REDUCE(
      COALESCE(t.p8_no_creative_bitrate_check_failed, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_no_creative_bitrate_check_failed,
  SUM(
    REDUCE(
      COALESCE(t.p8_no_creative_creative_targeting_check_failed, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_no_creative_creative_targeting_check_failed,
  SUM(
    REDUCE(
      COALESCE(t.p8_no_creative_date_range_check_failed, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_no_creative_date_range_check_failed,
  SUM(
    REDUCE(
      COALESCE(t.p8_no_creative_slot_max_ad_duration_check_failed, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_no_creative_slot_max_ad_duration_check_failed,
  SUM(
    REDUCE(
      COALESCE(t.p8_no_creative_slot_compatible_dimension_check_failed, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_no_creative_slot_compatible_dimension_check_failed,
  SUM(
    REDUCE(
      COALESCE(t.p8_inventory_source_restriction, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_inventory_source_restriction,
  SUM(
    REDUCE(
      COALESCE(t.p8_no_applicable_slot_not_compatible, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_no_applicable_slot_not_compatible,
  SUM(
    REDUCE(
      COALESCE(t.p8_no_applicable_slot_excluded_by_sponsor, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_no_applicable_slot_excluded_by_sponsor,
  SUM(
    REDUCE(
      COALESCE(t.p8_met_yield_optimization, ARRAY[]),
      0,
      (s, x) -> IF(x IS NULL, s, s + x),
      s -> s
    )
  ) AS phase8_met_yield_optimization,
  SUM(
    REDUCE(COALESCE(t.p9_input_ad_number, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS tx_phase9_input_ad_number,
  SUM(
    REDUCE(COALESCE(t.p9_output_ad_number, ARRAY[]), 0, (s, x) -> IF(x IS NULL, s, s + x), s -> s)
  ) AS tx_phase9_output_ad_number
FROM ${bcv_request}
CROSS JOIN UNNEST(execution_networks__network_id, execution_networks__role, execution_networks__content_owner_network_id, execution_networks__supply_source, execution_networks__inbound_order_id, execution_networks__inbound_order_type, execution_networks__inbound_listing_id, execution_networks__content_owner_bidding_revenue, execution_networks__network_is_ad_owner, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_targeting_metrics__input_ad_number, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_targeting_metrics__output_ad_number, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_targeting_metrics__data_privacy, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_targeting_metrics__restriction, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__input_ad_number, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__output_ad_number, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__no_ad_domain, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__no_slot_assigned_through_mrm_rule, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__frequency_cap, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__cpx_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__met_schedule, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__rbp_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__no_applicable_slot, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__sponsorship_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__exclusivity_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__no_applicable_slot_user_experience, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__no_applicable_slot_no_external_rule, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__no_applicable_slot_not_resellable, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__no_applicable_slot_promo_only, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__no_applicable_slot_not_compatible, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__met_budget, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filtering_metrics__met_yield_optimization, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__input_ad_number, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__output_ad_number, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__frequency_cap, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__no_applicable_slot, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__compliance_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__no_creative, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__no_suitable_rule_path, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__profile_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__floor_price_not_met, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__restriction, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__exclusivity, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__pg_deal_bid_throttling, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__auction_max_ad_duration, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__reseller_restriction, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__market_ad_not_approved, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__listing_creative_duration_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__inventory_source_restriction, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__no_creative_ad_asset_store_availability, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__no_creative_bitrate_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__no_creative_creative_targeting_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__no_creative_date_range_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__no_creative_slot_max_ad_duration_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__no_creative_slot_compatible_dimension_check_failed, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__no_applicable_slot_not_compatible, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__no_applicable_slot_excluded_by_sponsor, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_creative_checking_metrics__met_yield_optimization, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__input_ad_number, execution_networks__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__output_ad_number) AS t(network_id, network_role, content_owner_network_id, supply_source, inbound_order_id, order_type, listing_id, content_owner_bidding_revenue, is_ad_owner, p6_input_ad_number, p6_output_ad_number, p6_data_privacy, p6_restriction, p7_input_ad_number, p7_output_ad_number, p7_no_ad_domain, p7_no_slot_assigned_through_mrm_rule, p7_frequency_cap, p7_cpx_check_failed, p7_met_schedule, p7_rbp_check_failed, p7_no_applicable_slot, p7_sponsorship_check_failed, p7_exclusivity_check_failed, p7_no_applicable_slot_user_experience, p7_no_applicable_slot_no_external_rule, p7_no_applicable_slot_not_resellable, p7_no_applicable_slot_promo_only, p7_no_applicable_slot_not_compatible, p7_met_budget, p7_met_yield_optimization, p8_input_ad_number, p8_output_ad_number, p8_frequency_cap, p8_no_applicable_slot, p8_compliance_check_failed, p8_no_creative, p8_no_suitable_rule_path, p8_profile_check_failed, p8_floor_price_not_met, p8_restriction, p8_exclusivity, p8_pg_deal_bid_throttling, p8_auction_max_ad_duration, p8_reseller_restriction, p8_market_ad_not_approved, p8_listing_creative_duration_check_failed, p8_inventory_source_restriction, p8_no_creative_ad_asset_store_availability, p8_no_creative_bitrate_check_failed, p8_no_creative_creative_targeting_check_failed, p8_no_creative_date_range_check_failed, p8_no_creative_slot_max_ad_duration_check_failed, p8_no_creative_slot_compatible_dimension_check_failed, p8_no_applicable_slot_not_compatible, p8_no_applicable_slot_excluded_by_sponsor, p8_met_yield_optimization, p9_input_ad_number, p9_output_ad_number)
LEFT JOIN db.default.d_network AS cro
  ON cro.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS dis
  ON dis.id = request__context__network_id
LEFT JOIN db.default.d_network AS network
  ON network.id = COALESCE(t.network_id, -1)
LEFT JOIN db.default.d_network AS co
  ON co.id = COALESCE(t.content_owner_network_id, -1)
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = visitor__country_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS ep
  ON ep.id = request__context__standard_endpoint_id
LEFT JOIN db.default.d_lu_mkpl_endpoint_owner AS eo
  ON eo.id = COALESCE(request__context__standard_endpoint_owner_id, -1)
LEFT JOIN (
  SELECT
    site_id,
    site_name
  FROM db.default.d_site_section
  GROUP BY
    1,
    2
) AS site
  ON site.site_id = COALESCE(request__context__site_section_cro_site_id, -1)
LEFT JOIN db.default.d_lu_mkpl_standard_environment AS env
  ON env.id = COALESCE(visitor__standard_environment_id, -1)
LEFT JOIN db.default.d_lu_mkpl_standard_os AS os
  ON os.id = COALESCE(visitor__standard_os_id, -1)
JOIN device_type
  ON 1 = 1
LEFT JOIN db.default.d_ssp_demand_side_platform AS ssp
  ON ssp.network_id = COALESCE(t.network_id, -1)
LEFT JOIN db.default.d_lu_mkpl_standard_programmer AS pg
  ON pg.id = COALESCE(request__context__standard_programmer_id, -1)
LEFT JOIN db.default.d_mkpl_listing AS listing
  ON listing.id = COALESCE(listing_id[1], -1)
LEFT JOIN db.default.d_mkpl_order AS orders
  ON orders.id = inbound_order_id
WHERE
  (
    (
      (
        request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
      )
      AND COALESCE(inbound_order_id, -1) > 0
    )
    AND t.order_type <> 'programmatic_order'
  )
  AND network_role IN ('cro', 'r')
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
  42
