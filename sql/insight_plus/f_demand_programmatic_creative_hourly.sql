/*
    - ONLY for Programmatic
*/

select
    reduce(set_agg(process_stage), 0, (acc, val) -> acc + val, val -> val) as process_stage

    , network_id
    , supply_source
    , sales_channel
    , content_owner_id
    , 'FULL_VISIBILITY' as content_owner_visibility
    , distributor_id
    , CAST(-1 as bigint) as reseller_id
    , 'FULL_VISIBILITY' as reseller_visibility
    , user_country_id
    , 'FULL_VISIBILITY' as geo_country_visibility
    , standard_device_type_id
    , standard_app_id
    , standard_environment_id
    , standard_os_id
    , 'FULL_VISIBILITY' as user_agent_visibility
    , standard_endpoint_owner_id
    , 'FULL_VISIBILITY' as standard_endpoint_owner_visibility
    , standard_endpoint_id
    , 'FULL_VISIBILITY' as standard_endpoint_visibility
    , standard_programmer_id
    , 'FULL_VISIBILITY' as standard_programmer_visibility
    , standard_brand_id
    , 'FULL_VISIBILITY' as standard_brand_visibility
    , standard_publisher_id
    , content_form_id
    , stream_mode_id
    , application_type
    , device_type
    , site_domain
    , app_bundle
    , app_storeurl
    , ifa_type
    , time_position_class
    , site_id
    , site_section_id
    , series_id
    , profile_id
    , 'COMPOUND' as profile_type
    , upstream_listing_ids
    , inbound_order_id
    , CAST(array[] as array<bigint>) as outbound_exchange_listing_ids
    , 'Programmatic' as demand_channel
    , demand_type
    , auction_type
    , primary_ad_indicator
    , dsp_id
    , buyer_platform_id
    , buyer_group_id
    , deal_ids
    , CAST(-1 as bigint) as outbound_order_id
    , bidding_buyer_id
    , bidding_external_seat_id
    , global_advertiser_ids
    , global_brand_ids
    , global_industry_ids
    , market_ad_id
    , external_ad_id
    , creative_duration

    , user_matched_indicator
    , ifa_auditing
    , app_bundle_auditing
    , app_storeurl_auditing
    , site_domain_auditing

    , error_stage
    , slot_user_drop_off
    , request_traffic_type
    , ack_traffic_type
    , process_batch_id
    , event_date

    , sum(bid_requests_error) as bid_requests_error
    , sum(bid_requests) as bid_requests
    , sum(bid_responses_error) as bid_responses_error
    , sum(bid_responses) as bid_responses
    , sum(opportunities_in_bid_request) as opportunities_in_bid_request
    , sum(received_bids) as received_bids
    , sum(failed_bids) as failed_bids
    , sum(resolved_bids) as resolved_bids
    , sum(filtered_bids) as filtered_bids
    , sum(selected_bids) as selected_bids
    , sum(filtered_bids_by_slot) as filtered_bids_by_slot
    , sum(gross_ad_views) as gross_ad_views
    , sum(clicks) as clicks
    , sum(first_quartile) as first_quartile
    , sum(middle_quartile) as middle_quartile
    , sum(third_quartile) as third_quartile
    , sum(complete_quartile) as complete_quartile
    , sum(can_quartile) as can_quartile
    , sum(revenue) as revenue
    , sum(co_revenue) as co_revenue
    , sum(r_revenue) as r_revenue

    , sum(tx_err_timeout) as tx_err_timeout
    , sum(tx_err_http_error) as tx_err_http_error
    , sum(tx_err_no_bids) as tx_err_no_bids
    , sum(tx_err_bid_response_id_nomatch) as tx_err_bid_response_id_nomatch
    , sum(tx_err_empty_response) as tx_err_empty_response
    , sum(tx_err_ad_duration_exceeded) as tx_err_ad_duration_exceeded
    , sum(tx_err_ad_pending_approval) as tx_err_ad_pending_approval
    , sum(tx_err_ad_rejected) as tx_err_ad_rejected
    , sum(tx_err_ad_targeting_restriction) as tx_err_ad_targeting_restriction
    , sum(tx_err_advertiser_frequency_cap_reached) as tx_err_advertiser_frequency_cap_reached
    , sum(tx_err_atts_unsupported) as tx_err_atts_unsupported
    , sum(tx_err_brand_frequency_cap_reached) as tx_err_brand_frequency_cap_reached
    , sum(tx_err_ccpa_opt_out) as tx_err_ccpa_opt_out
    , sum(tx_err_ccpa_gpp_us_privacy_opt_out) as tx_err_ccpa_gpp_us_privacy_opt_out
    , sum(tx_err_coppa_unsupported) as tx_err_coppa_unsupported
    , sum(tx_err_competition_failure) as tx_err_competition_failure
    , sum(tx_err_creative_duration_mismatched) as tx_err_creative_duration_mismatched
    , sum(tx_err_creative_not_applicable) as tx_err_creative_not_applicable
    , sum(tx_err_creative_restriction_failure) as tx_err_creative_restriction_failure
    , sum(tx_err_dsp_status_complete) as tx_err_dsp_status_complete
    , sum(tx_err_dsp_status_inactive) as tx_err_dsp_status_inactive
    , sum(tx_err_dsp_status_pause) as tx_err_dsp_status_pause
    , sum(tx_err_dsp_status_unknown) as tx_err_dsp_status_unknown
    , sum(tx_err_data_rights_restricted) as tx_err_data_rights_restricted
    , sum(tx_err_deal_advertiser_restriction) as tx_err_deal_advertiser_restriction
    , sum(tx_err_deal_brand_restriction) as tx_err_deal_brand_restriction
    , sum(tx_err_deal_floor_price_not_met) as tx_err_deal_floor_price_not_met
    , sum(tx_err_deal_frequency_cap_reached) as tx_err_deal_frequency_cap_reached
    , sum(tx_err_deal_industry_restriction) as tx_err_deal_industry_restriction
    , sum(tx_err_deal_seat_restriction) as tx_err_deal_seat_restriction
    , sum(tx_err_demand_partner_disallowed_by_profile) as tx_err_demand_partner_disallowed_by_profile
    , sum(tx_err_empty_bid_id) as tx_err_empty_bid_id
    , sum(tx_err_empty_deal_id) as tx_err_empty_deal_id
    , sum(tx_err_empty_vast) as tx_err_empty_vast
    , sum(tx_err_empty_vast_ad_markup) as tx_err_empty_vast_ad_markup
    , sum(tx_err_exclusivity) as tx_err_exclusivity
    , sum(tx_err_gpp_not_supported) as tx_err_gpp_not_supported
    , sum(tx_err_gpp_spi_opt_out) as tx_err_gpp_spi_opt_out
    , sum(tx_err_imr_inventory_source_optimization) as tx_err_imr_inventory_source_optimization
    , sum(tx_err_inbound_mrm_rule_targeting_failed) as tx_err_inbound_mrm_rule_targeting_failed
    , sum(tx_err_inbound_mrm_rule_targeting_scope_failed) as tx_err_inbound_mrm_rule_targeting_scope_failed
    , sum(tx_err_industry_restriction) as tx_err_industry_restriction
    , sum(tx_err_invalid_bid_currency) as tx_err_invalid_bid_currency
    , sum(tx_err_invalid_bid_price) as tx_err_invalid_bid_price
    , sum(tx_err_invalid_pg_creative) as tx_err_invalid_pg_creative
    , sum(tx_err_invalid_ad_id) as tx_err_invalid_ad_id
    , sum(tx_err_invalid_vast_wrapper_url) as tx_err_invalid_vast_wrapper_url
    , sum(tx_err_inventory_protection_advertiser) as tx_err_inventory_protection_advertiser
    , sum(tx_err_inventory_protection_brand) as tx_err_inventory_protection_brand
    , sum(tx_err_inventory_protection_industry) as tx_err_inventory_protection_industry
    , sum(tx_err_kv_unsupported) as tx_err_kv_unsupported
    , sum(tx_err_lat_unsupported) as tx_err_lat_unsupported
    , sum(tx_err_listing_advertiser_restriction) as tx_err_listing_advertiser_restriction
    , sum(tx_err_listing_brand_restriction) as tx_err_listing_brand_restriction
    , sum(tx_err_listing_industry_restriction) as tx_err_listing_industry_restriction
    , sum(tx_err_low_response_rate_limiter) as tx_err_low_response_rate_limiter
    , sum(tx_err_malformed_vast_xml) as tx_err_malformed_vast_xml
    , sum(tx_err_mismatched_ad_id) as tx_err_mismatched_ad_id
    , sum(tx_err_mismatched_deal_id) as tx_err_mismatched_deal_id
    , sum(tx_err_mismatched_impression_id) as tx_err_mismatched_impression_id
    , sum(tx_err_mismatched_seat_id) as tx_err_mismatched_seat_id
    , sum(tx_err_network_item_advertiser_restriction) as tx_err_network_item_advertiser_restriction
    , sum(tx_err_network_item_brand_restriction) as tx_err_network_item_brand_restriction
    , sum(tx_err_network_item_industry_restriction) as tx_err_network_item_industry_restriction
    , sum(tx_err_network_item_inventory_source_optimization) as tx_err_network_item_inventory_source_optimization
    , sum(tx_err_network_seat_restriction) as tx_err_network_seat_restriction
    , sum(tx_err_no_ad_in_vast) as tx_err_no_ad_in_vast
    , sum(tx_err_no_client_condition) as tx_err_no_client_condition
    , sum(tx_err_no_jitt_rendition) as tx_err_no_jitt_rendition
    , sum(tx_err_no_tcf_consent) as tx_err_no_tcf_consent
    , sum(tx_err_non_secure_ad) as tx_err_non_secure_ad
    , sum(tx_err_only_companion_ad_allowed) as tx_err_only_companion_ad_allowed
    , sum(tx_err_profile_check_failed) as tx_err_profile_check_failed
    , sum(tx_err_reseller_allowlist_restriction) as tx_err_reseller_allowlist_restriction
    , sum(tx_err_reseller_blocklist_restriction) as tx_err_reseller_blocklist_restriction
    , sum(tx_err_rule_price_hurdle_not_met) as tx_err_rule_price_hurdle_not_met
    , sum(tx_err_ssp_endpoint_invalid_configuration) as tx_err_ssp_endpoint_invalid_configuration
    , sum(tx_err_upstream_listing_advertiser_floor_price_not_met) as tx_err_upstream_listing_advertiser_floor_price_not_met
    , sum(tx_err_upstream_listing_brand_floor_price_not_met) as tx_err_upstream_listing_brand_floor_price_not_met
    , sum(tx_err_upstream_listing_creative_duration_restriction) as tx_err_upstream_listing_creative_duration_restriction
    , sum(tx_err_upstream_listing_industry_floor_price_not_met) as tx_err_upstream_listing_industry_floor_price_not_met
    , sum(tx_err_upstream_listing_seat_floor_price_not_met) as tx_err_upstream_listing_seat_floor_price_not_met
    , sum(tx_err_upstream_listing_seat_restriction) as tx_err_upstream_listing_seat_restriction
    , sum(tx_err_upstream_order_floor_price_not_met) as tx_err_upstream_order_floor_price_not_met
    , sum(tx_err_unsupported_vast_version) as tx_err_unsupported_vast_version
    , sum(tx_err_vast_wrapper_http_error) as tx_err_vast_wrapper_http_error
    , sum(tx_err_vast_wrapper_timeout) as tx_err_vast_wrapper_timeout
    , sum(tx_err_yield_optimization_cap_reached) as tx_err_yield_optimization_cap_reached
    , sum(tx_err_no_slot_selected) as tx_err_no_slot_selected
    , sum(tx_err_unknown) as tx_err_unknown


    , sum(slot_err_clearcast_code_restricted) as slot_err_clearcast_code_restricted
    , sum(slot_err_competition_failure) as slot_err_competition_failure
    , sum(slot_err_adjacent_ads_exclusivity) as slot_err_adjacent_ads_exclusivity
    , sum(slot_err_advertiser_frequency_cap_reached) as slot_err_advertiser_frequency_cap_reached
    , sum(slot_err_back_to_batch_exclusivity) as slot_err_back_to_batch_exclusivity
    , sum(slot_err_brand_frequency_cap_reached) as slot_err_brand_frequency_cap_reached
    , sum(slot_err_clearcast_restriction) as slot_err_clearcast_restriction
    , sum(slot_err_deal_frequency_cap_reached) as slot_err_deal_frequency_cap_reached
    , sum(slot_err_dsp_bid_cap_reached) as slot_err_dsp_bid_cap_reached
    , sum(slot_err_header_bidding_repeating_key_value_exclusivity) as slot_err_header_bidding_repeating_key_value_exclusivity
    , sum(slot_err_inventory_protection_advertiser) as slot_err_inventory_protection_advertiser
    , sum(slot_err_inventory_protection_brand) as slot_err_inventory_protection_brand
    , sum(slot_err_inventory_protection_industry) as slot_err_inventory_protection_industry
    , sum(slot_err_max_number_of_ads_exceeded) as slot_err_max_number_of_ads_exceeded
    , sum(slot_err_max_slot_duration_exceeded) as slot_err_max_slot_duration_exceeded
    , sum(slot_err_only_pod_ad_allowed) as slot_err_only_pod_ad_allowed
    , sum(slot_err_sequence_variant_targeting_failed) as slot_err_sequence_variant_targeting_failed
    , sum(slot_err_slot_exclusivity) as slot_err_slot_exclusivity
    , sum(slot_err_swap_out_of_slot) as slot_err_swap_out_of_slot
    , sum(slot_err_low_ranking_in_buyer) as slot_err_low_ranking_in_buyer
    , sum(slot_err_profile_check_failed) as slot_err_profile_check_failed
    , sum(slot_err_adstor_creative_unavailable) as slot_err_adstor_creative_unavailable
    , sum(slot_err_creative_ad_unit_duration_incompatible) as slot_err_creative_ad_unit_duration_incompatible
    , sum(slot_err_creative_profile_incompatible) as slot_err_creative_profile_incompatible
    , sum(slot_err_creative_vpaid_incompatible) as slot_err_creative_vpaid_incompatible
    , sum(slot_err_estimated_duration_disabled_for_live_inventory) as slot_err_estimated_duration_disabled_for_live_inventory
    , sum(slot_err_adstore_creative_bitrate_incompatible) as slot_err_adstore_creative_bitrate_incompatible
    , sum(slot_err_adstore_linear_creative_unavailable) as slot_err_adstore_linear_creative_unavailable
    , sum(slot_err_creative_dimension_incompatible) as slot_err_creative_dimension_incompatible
    , sum(slot_err_creative_file_size_incompatible) as slot_err_creative_file_size_incompatible

    , sum(no_clicks) as no_clicks
-- ADM Endpoint Errors (27)
    , sum(ack_err_adm_total) as ack_err_adm_total
    , sum(ack_err_adm_e_io) as ack_err_adm_e_io
    , sum(ack_err_adm_e_security) as ack_err_adm_e_security
    , sum(ack_err_adm_e_no_ad) as ack_err_adm_e_no_ad
    , sum(ack_err_adm_e_timeout) as ack_err_adm_e_timeout
    , sum(ack_err_adm_e_overflow_skipped) as ack_err_adm_e_overflow_skipped
    , sum(ack_err_adm_e_missing_param) as ack_err_adm_e_missing_param
    , sum(ack_err_adm_e_invalid_value) as ack_err_adm_e_invalid_value
    , sum(ack_err_adm_e_adinst_unavail) as ack_err_adm_e_adinst_unavail
    , sum(ack_err_adm_e_no_renderer) as ack_err_adm_e_no_renderer
    , sum(ack_err_adm_e_renderer_init) as ack_err_adm_e_renderer_init
    , sum(ack_err_adm_e_parse) as ack_err_adm_e_parse
    , sum(ack_err_adm_e_null_asset) as ack_err_adm_e_null_asset
    , sum(ack_err_adm_e_external_interface) as ack_err_adm_e_external_interface
    , sum(ack_err_adm_e_3p_comp) as ack_err_adm_e_3p_comp
    , sum(ack_err_adm_e_device_limit) as ack_err_adm_e_device_limit
    , sum(ack_err_adm_e_in_app_view) as ack_err_adm_e_in_app_view
    , sum(ack_err_adm_e_unknown) as ack_err_adm_e_unknown
    , sum(ack_err_adm_e_invalid_slot) as ack_err_adm_e_invalid_slot
    , sum(ack_err_adm_e_network) as ack_err_adm_e_network
    , sum(ack_err_adm_e_no_preload_in_translator) as ack_err_adm_e_no_preload_in_translator
    , sum(ack_err_adm_e_renderer_load) as ack_err_adm_e_renderer_load
    , sum(ack_err_adm_e_slot_size_unmatch) as ack_err_adm_e_slot_size_unmatch
    , sum(ack_err_adm_e_slot_unavail) as ack_err_adm_e_slot_unavail
    , sum(ack_err_adm_e_unsupp_3p_feature) as ack_err_adm_e_unsupp_3p_feature
    , sum(ack_err_adm_e_really_no_ad) as ack_err_adm_e_really_no_ad
    , sum(ack_err_adm_e_dashjs) as ack_err_adm_e_dashjs

-- VAST Endpoint Errors (38)
    , sum(ack_err_vast_total)  as ack_err_vast_total
    , sum(ack_err_vast_51)  as ack_err_vast_51
    , sum(ack_err_vast_52)  as ack_err_vast_52
    , sum(ack_err_vast_100)  as ack_err_vast_100
    , sum(ack_err_vast_101)  as ack_err_vast_101
    , sum(ack_err_vast_102)  as ack_err_vast_102
    , sum(ack_err_vast_200)  as ack_err_vast_200
    , sum(ack_err_vast_201)  as ack_err_vast_201
    , sum(ack_err_vast_202)  as ack_err_vast_202
    , sum(ack_err_vast_203)  as ack_err_vast_203
    , sum(ack_err_vast_204)  as ack_err_vast_204
    , sum(ack_err_vast_300)  as ack_err_vast_300
    , sum(ack_err_vast_301)  as ack_err_vast_301
    , sum(ack_err_vast_302)  as ack_err_vast_302
    , sum(ack_err_vast_303)  as ack_err_vast_303
    , sum(ack_err_vast_304)  as ack_err_vast_304
    , sum(ack_err_vast_400)  as ack_err_vast_400
    , sum(ack_err_vast_401)  as ack_err_vast_401
    , sum(ack_err_vast_402)  as ack_err_vast_402
    , sum(ack_err_vast_403)  as ack_err_vast_403
    , sum(ack_err_vast_405)  as ack_err_vast_405
    , sum(ack_err_vast_406)  as ack_err_vast_406
    , sum(ack_err_vast_407)  as ack_err_vast_407
    , sum(ack_err_vast_408)  as ack_err_vast_408
    , sum(ack_err_vast_409)  as ack_err_vast_409
    , sum(ack_err_vast_410)  as ack_err_vast_410
    , sum(ack_err_vast_411)  as ack_err_vast_411
    , sum(ack_err_vast_500)  as ack_err_vast_500
    , sum(ack_err_vast_501)  as ack_err_vast_501
    , sum(ack_err_vast_502)  as ack_err_vast_502
    , sum(ack_err_vast_503)  as ack_err_vast_503
    , sum(ack_err_vast_600)  as ack_err_vast_600
    , sum(ack_err_vast_601)  as ack_err_vast_601
    , sum(ack_err_vast_602)  as ack_err_vast_602
    , sum(ack_err_vast_603)  as ack_err_vast_603
    , sum(ack_err_vast_604)  as ack_err_vast_604
    , sum(ack_err_vast_900)  as ack_err_vast_900
    , sum(ack_err_vast_901)  as ack_err_vast_901
    , sum(ack_err_adm_e_custom_player)                              as ack_err_adm_e_custom_player
    , sum(ack_err_adm_e_hlsjs)                                      as ack_err_adm_e_hlsjs
    , sum(tx_err_inbound_order_competition_failure)                 as tx_err_inbound_order_competition_failure
    , dsp_creative_id                                               as dsp_creative_id
    , sum(tx_err_cro_advertiser_frequency_cap_reached)              as tx_err_cro_advertiser_frequency_cap_reached
    , sum(tx_err_cro_brand_frequency_cap_reached)                   as tx_err_cro_brand_frequency_cap_reached
    , sum(tx_err_demand_partner_unsupported_on_external_ssp_supply) as tx_err_demand_partner_unsupported_on_external_ssp_supply
    , sum(tx_err_marketplace_order_price_not_met_low_bid_price)     as tx_err_marketplace_order_price_not_met_low_bid_price
    , sum(tx_err_no_upstream_client_rendition)                      as tx_err_no_upstream_client_rendition
    , sum(tx_err_standard_attribute_advertiser_restriction)         as tx_err_standard_attribute_advertiser_restriction
    , sum(tx_err_standard_attribute_industry_restriction)           as tx_err_standard_attribute_industry_restriction
    , sum(slot_err_cro_advertiser_frequency_cap_reaching)           as slot_err_cro_advertiser_frequency_cap_reaching
    , sum(slot_err_cro_brand_frequency_cap_reaching)                as slot_err_cro_brand_frequency_cap_reaching
    , sum(tx_err_slot_mismatch)                                     as tx_err_slot_mismatch
    , 'FULL_VISIBILITY'                                             as content_form_visibility
    , sum(total_received_bid_price)                                 as total_received_bid_price
    , sum(total_resolved_bid_price)                                 as total_resolved_bid_price
    , sum(total_bid_won_price)                                      as total_bid_won_price

    , sum(tx_err_standard_attribute_reseller_allowlist_restriction)              as tx_err_standard_attribute_reseller_allowlist_restriction
    , sum(tx_err_standard_attribute_reseller_blocklist_restriction)              as tx_err_standard_attribute_reseller_blocklist_restriction
    , sum(tx_err_standard_attribute_ad_unit_restriction)                         as tx_err_standard_attribute_ad_unit_restriction
    , sum(tx_err_advertiser_domain_restricted)                                   as tx_err_advertiser_domain_restricted
    , IF(COALESCE(inbound_order_id, -1) <> -1, Array[inbound_order_id], Array[]) as inbound_order_ids
    , sum(tx_err_ad_pending_distributor_approval) as tx_err_ad_pending_distributor_approval
    , sum(tx_err_ad_rejected_by_distributor) as tx_err_ad_rejected_by_distributor
    , sum(tx_err_yield_optimization_rule_met) as tx_err_yield_optimization_rule_met
    , process_batch_id as partition_key
from (
/** Candidate **/

SELECT
   8                                                                                                                                            as process_stage

-- Network Chain (5)
, COALESCE(nw.network_id, -1)                                                                                                                   as network_id
, COALESCE(nw.supply_source, -1)                                                                                                                as supply_source
, COALESCE(nw.sales_channel, -1)                                                                                                                as sales_channel
, COALESCE(nw.co_id, -1)                                                                                                                        as content_owner_id
, cast(-1 as bigint)                                                                                                                            as distributor_id

-- Standard Attributes (12)
, IF(COALESCE(nw.country_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__country_id, -1))                               as user_country_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2 , COALESCE(visitor__standard_device_type_child_id, -1))        as standard_device_type_id
, COALESCE(request__context__standard_app_id, -1)                                                                                               as standard_app_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__standard_environment_id, -1))               as standard_environment_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__standard_os_id, -1))                        as standard_os_id
, IF(COALESCE(nw.endpoint_owner_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.endpoint_owner_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_endpoint_owner_id, -1), -1))   as standard_endpoint_owner_id
, IF(COALESCE(nw.endpoint_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.endpoint_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_endpoint_id, -1), -1))               as standard_endpoint_id
, IF(COALESCE(nw.programmer_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.programmer_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_programmer_id, -1), -1))           as standard_programmer_id
, IF(COALESCE(nw.brand_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.brand_visibility IS NOT NULL OR nw.supply_source != 3, COALESCE(request__context__standard_brand_id, -1), -1))                    as standard_brand_id
, COALESCE(request__context__standard_publisher_id, -1)                                                                                         as standard_publisher_id
, IF(COALESCE(nw.content_form_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.content_form_visibility IS NOT NULL OR nw.supply_source != 3, COALESCE(request__context__content_form_id, -1), -1))               as content_form_id
, COALESCE(request__context__stream_mode_id, -1)                                                                                                as stream_mode_id

-- Obj. Metadata (6)
, COALESCE(auction__application_type, 'Unknown')                                                                                                as application_type
, COALESCE(auction__device_type, 'Unknown')                                                                                                     as device_type
, COALESCE(auction__site_domain, 'Unknown')                                                                                                     as site_domain
, COALESCE(auction__app_bundle, 'Unknown')                                                                                                      as app_bundle
, ''                                                                                                                                            as app_storeurl  -- Only for auditing purpose
, COALESCE(auction__ifa_type, 'Unknown')                                                                                                        as ifa_type

-- Inventory (7)
, COALESCE(auction__time_position_class, 'Unknown')                                                                                             as time_position_class
, IF(nw.sales_channel IN (5,6), COALESCE(nw.site_id, -1), COALESCE(auction__site_id, -1))                                                       as site_id
, IF(nw.sales_channel IN (5,6), COALESCE(nw.site_section_id, -1),
    COALESCE(auction__site_section_id, -1))                                                                                                     as site_section_id
, IF(nw.sales_channel IN (5,6), COALESCE(nw.series_id, -1), COALESCE(auction__series_id, -1))                                                   as series_id
-- , IF(COALESCE(request__context__profile_type, 'UNKNOWN') = 'COMPOUND',
--         COALESCE( IF(BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0 AND COALESCE(nw.role, '') = 'CRO', -3,
--                 COALESCE(request__context__profile_id, -1)), -1), -1)                                                                           as profile_id
, IF(COALESCE(request__context__profile_type, 'UNKNOWN') = 'COMPOUND', COALESCE(request__context__profile_id, -1), -1)                          as profile_id
, IF(nw.supply_source=6, COALESCE(nw.inbound_listing_ids, array[]), array[])                                                                    as upstream_listing_ids
, COALESCE(nw.inbound_order_id, -1)                                                                                                             as inbound_order_id

-- Demand (16)
, CASE
        WHEN (auction__integration_type='PG_TD') THEN 'PG'
        WHEN (auction__integration_type='NORMAL') THEN 'Non-PG'
        ELSE COALESCE(auction__integration_type, 'Unknown')
  END                                                                                                                                           as demand_type
, COALESCE(candidate__auction_type, 'NOT_APPLICABLE')                                                                                           as auction_type
, CASE
    WHEN advertisement__is_fallback IS NULL THEN 'Not Applicable'
    WHEN advertisement__is_fallback = TRUE THEN 'Fallback'
    ELSE 'Primary'
  END                                                                                                                                           as primary_ad_indicator
, COALESCE(auction__dsp_id, -1)                                                                                                                 as dsp_id
, COALESCE(auction__buyer_platform_id, -1)                                                                                                      as buyer_platform_id
, IF(nw.deal_awareability=true, COALESCE(candidate__buyer_group_id, -1), -1)                                                                    as buyer_group_id
, Array[IF(nw.deal_awareability=true, COALESCE(candidate__internal_deal_id, -1), -1)]                                                           as deal_ids
, IF(nw.deal_awareability=true, COALESCE(candidate__bidding_buyer_id, -1), -1)                                                                  as bidding_buyer_id
, COALESCE(candidate__external_seat_id, 'Unknown')                                                                                              as bidding_external_seat_id
, COALESCE(candidate__global_advertiser_ids, Array[])                                                                                           as global_advertiser_ids
, COALESCE(candidate__global_brand_ids, Array[])                                                                                                as global_brand_ids
, COALESCE(candidate__global_industry_ids, Array[])                                                                                             as global_industry_ids
, COALESCE(candidate__market_ad_id, -1)                                                                                                         as market_ad_id
, COALESCE(candidate__external_ad_id, 'Unknown')                                                                                                as external_ad_id
, COALESCE(candidate__dsp_crid, 'Unknown')                                                                                                      as dsp_creative_id
, COALESCE(advertisement__duration, COALESCE(candidate__duration, 0))                                                                           as creative_duration

-- Auction (5)
, IF(BITWISE_AND(auction__flags, 1)>0, true, false)                                                                                             as user_matched_indicator
, 'Not Applicable'                                                                                                                              as ifa_auditing
, 'Not Applicable'                                                                                                                              as app_bundle_auditing
, 'Not Applicable'                                                                                                                              as app_storeurl_auditing
, 'Not Applicable'                                                                                                                              as site_domain_auditing

-- Others (6)
, CASE
    WHEN BITWISE_AND(candidate__flags, 131072)>0 THEN 'Not Sent'
    WHEN BITWISE_AND(candidate__bid_status, 1)>0 AND BITWISE_AND(candidate__bid_status, 2)=0 THEN 'Not Resolved'
    WHEN BITWISE_AND(candidate__bid_status, 2)>0 AND BITWISE_AND(candidate__bid_status, 8)=0 THEN 'Not Selected'
  ELSE 'Not Applicable'
  END                                                                                                                                           as error_stage
, 'Included'                                                                                                                                    as slot_user_drop_off
, COALESCE(request__traffic_type, 0)                                                                                                            as request_traffic_type
, 0                                                                                                                                             as ack_traffic_type
, process_batch_id                                                                                                                              as process_batch_id
, DATE_TRUNC('HOUR', request__timestamp)                                                                                                        as event_date

-- Performance Metrics (22)
, SUM(IF(BITWISE_AND(candidate__flags, 131072)>0, 1, 0))                                                        as bid_requests_error
, 0 as bid_requests
, 0 as bid_responses_error
, 0 as bid_responses
, 0 as opportunities_in_bid_request

, SUM(IF(BITWISE_AND(candidate__bid_status, 1)>0, 1, 0))                                                                    as received_bids
, SUM(IF(BITWISE_AND(candidate__bid_status, 1)>0 AND BITWISE_AND(candidate__bid_status, 2)=0, 1, 0))                        as failed_bids
, SUM(IF(BITWISE_AND(candidate__bid_status, 2)>0, 1, 0))                                                                    as resolved_bids
, SUM(IF(BITWISE_AND(candidate__bid_status, 2)>0 AND BITWISE_AND(candidate__bid_status, 8)=0, 1, 0))                        as filtered_bids
, SUM(IF(BITWISE_AND(candidate__bid_status, 8)>0, 1, 0))                                                                    as selected_bids
, 0 as filtered_bids_by_slot
, SUM(IF(BITWISE_AND(candidate__bid_status, 1)>0,
    COALESCE(candidate__raw_price, 0.0) * candidate__candidate_network_to_auction_network_exchange_rate,
    0.0))                                                                                                       as total_received_bid_price
, SUM(IF(BITWISE_AND(candidate__bid_status, 2)>0,
    COALESCE(candidate__raw_price, 0.0) * candidate__candidate_network_to_auction_network_exchange_rate,
    0.0))                                                                                                       as total_resolved_bid_price
, SUM(IF(BITWISE_AND(candidate__bid_status, 8)>0,
    COALESCE(candidate__clearing_price, 0.0) * candidate__candidate_network_to_auction_network_exchange_rate,
    0.0))                                                                                                       as total_bid_won_price

, 0 as gross_ad_views
, 0 as clicks
, 0 as no_clicks
, 0 as first_quartile
, 0 as middle_quartile
, 0 as third_quartile
, 0 as complete_quartile
, 0 as can_quartile
, (cast (0 as double)) as revenue
, (cast (0 as double)) as co_revenue
, (cast (0 as double)) as r_revenue

-- Tx Level Error Metrics (99)
, 0 as tx_err_timeout
, 0 as tx_err_http_error
, 0 as tx_err_no_bids
, 0 as tx_err_bid_response_id_nomatch
, 0 as tx_err_empty_response
, SUM(IF(candidate__error = 'AUCTION_MAX_AD_DURATION_EXCEEDED', 1, 0))                                                       as tx_err_ad_duration_exceeded
, SUM(IF(candidate__error = 'AD_PENDING_APPROVAL', 1, 0))                                                                    as tx_err_ad_pending_approval
, SUM(IF(candidate__error = 'COMPLIANCE_NOT_APPROVED', 1, 0))                                                                as tx_err_ad_rejected
, SUM(IF(candidate__error = 'AD_TARGETING_RESTRICTED', 1, 0))                                                                as tx_err_ad_targeting_restriction
, SUM(IF(candidate__error = 'ADVERTISER_FREQUENCY_CAP_REACHED', 1, 0))                                                       as tx_err_advertiser_frequency_cap_reached                    -- no data
, SUM(IF(candidate__error = 'ATTS_UNSUPPORTED', 1, 0))                                                                       as tx_err_atts_unsupported                                    -- no data
, SUM(IF(candidate__error = 'BRAND_FREQUENCY_CAP_REACHED', 1, 0))                                                            as tx_err_brand_frequency_cap_reached                         -- no data
, SUM(IF(candidate__error = 'CCPA_UNSUPPORTED', 1, 0))                                                                       as tx_err_ccpa_opt_out
, SUM(IF(candidate__error = 'US_PRIVACY_UNSUPPORTED', 1, 0))                                                                 as tx_err_ccpa_gpp_us_privacy_opt_out
, SUM(IF(candidate__error = 'COPPA_UNSUPPORTED', 1, 0))                                                                      as tx_err_coppa_unsupported
, SUM(IF(candidate__error = 'INBOUND_ORDER_COMPETITION_FAILURE', 1, 0))                                                      as tx_err_inbound_order_competition_failure
, SUM(IF(candidate__error = 'COMPETITION_FAILURE', 1, 0))                                                                    as tx_err_competition_failure
, SUM(IF(candidate__error = 'MISMATCHED_CREATIVE_DURATION_WITH_SCHEDULED', 1, 0))                                            as tx_err_creative_duration_mismatched
, SUM(IF(candidate__error = 'NO_APPLICABLE_CREATIVE', 1, 0))                                                                 as tx_err_creative_not_applicable
, SUM(IF(candidate__error = 'CREATIVE_RESTRICTION_CHECK_FAILED', 1, 0))                                                      as tx_err_creative_restriction_failure
, SUM(IF(candidate__error = 'DSP_STATUS_COMPLETE', 1, 0))                                                                    as tx_err_dsp_status_complete                     -- no data
, SUM(IF(candidate__error = 'DSP_STATUS_INACTIVE', 1, 0))                                                                    as tx_err_dsp_status_inactive
, SUM(IF(candidate__error = 'DSP_STATUS_PAUSE', 1, 0))                                                                       as tx_err_dsp_status_pause
, SUM(IF(candidate__error = 'DSP_STATUS_UNKNOWN', 1, 0))                                                                     as tx_err_dsp_status_unknown                      -- no data
, SUM(IF(candidate__error = 'DATA_VISIBILITY_BANNED', 1, 0))                                                                 as tx_err_data_rights_restricted                              -- no data
, SUM(IF(candidate__error IN ('ADVERTISER_RESTRICTED_BY_RULE', 'GLOBAL_ADVERTISER_RESTRICTED_BY_DEAL'), 1, 0))               as tx_err_deal_advertiser_restriction
, SUM(IF(candidate__error IN ('GLOBAL_BRAND_RESTRICTED_BY_DEAL', 'BRAND_RESTRICTED_BY_RULE'), 1, 0))                         as tx_err_deal_brand_restriction
, SUM(IF(candidate__error = 'FLOOR_PRICE_NOTMET', 1, 0))                                                                     as tx_err_deal_floor_price_not_met
, SUM(IF(candidate__error = 'FREQUENCY_CAP_REACHED', 1, 0))                                                                  as tx_err_deal_frequency_cap_reached
, SUM(IF(candidate__error = 'INDUSTRY_RESTRICTED_BY_DEAL', 1, 0))                                                            as tx_err_deal_industry_restriction
, SUM(IF(candidate__error IN ('RESTRICTED_SEAT_BY_DEAL', 'RESTRICTED_SEAT_BY_PROGMOD_DEAL'), 1, 0))                          as tx_err_deal_seat_restriction
, SUM(IF(candidate__error = 'DSP_BLOCKED_BY_PROFILE', 1, 0))                                                                 as tx_err_demand_partner_disallowed_by_profile
, SUM(IF(candidate__error = 'EMPTY_BID_ID', 1, 0))                                                                           as tx_err_empty_bid_id
, SUM(IF(candidate__error = 'EMPTY_BID_DEALID', 1, 0))                                                                       as tx_err_empty_deal_id
, SUM(IF(candidate__error = 'EMPTY_RESPONSE', 1, 0))                                                                         as tx_err_empty_vast
, SUM(IF(candidate__error = 'NO_AD_MARKUP', 1, 0))                                                                           as tx_err_empty_vast_ad_markup
, SUM(IF(candidate__error = 'EXCLUSIVITY_BY_STREAM', 1, 0))                                                                  as tx_err_exclusivity
, SUM(IF(candidate__error = 'GPP_UNSUPPORTED', 1, 0))                                                                        as tx_err_gpp_not_supported                        -- no data
, SUM(IF(candidate__error = 'GPP_SPI_UNSUPPORTED', 1, 0))                                                                    as tx_err_gpp_spi_opt_out                          -- no data
, SUM(IF(candidate__error = 'BLOCKED_BY_INVENTORY_SOURCE_OPTIMIZATION_IMR', 1, 0))                                           as tx_err_imr_inventory_source_optimization                   -- no data
, SUM(IF(candidate__error = 'INBOUND_RULE_TARGETING_NOT_MET', 1, 0))                                                         as tx_err_inbound_mrm_rule_targeting_failed
, SUM(IF(candidate__error = 'INBOUND_RULE_EXPLICIT_TARGETING_REQUIRED', 1, 0))                                               as tx_err_inbound_mrm_rule_targeting_scope_failed             -- no data
, SUM(IF(candidate__error IN ('RULE_COMPLIANCE_CHECK_FAILED', 'LISTING_INDUSTRY_RESTRICTION'), 1, 0))                        as tx_err_industry_restriction
, SUM(IF(candidate__error = 'NO_VALID_CURRENCY', 1, 0))                                                                      as tx_err_invalid_bid_currency      -- no data
, SUM(IF(candidate__error = 'NO_VALID_PRICE', 1, 0))                                                                         as tx_err_invalid_bid_price
, SUM(IF(candidate__error = 'NO_VALID_MARKET_AD', 1, 0))                                                                     as tx_err_invalid_pg_creative
, SUM(IF(candidate__error = 'NO_VALID_EXTERNAL_AD_ID', 1, 0))                                                                as tx_err_invalid_ad_id
, SUM(IF(candidate__error = 'INVALID_WRAPPER_URL', 1, 0))                                                                    as tx_err_invalid_vast_wrapper_url
, SUM(IF(candidate__error = 'NO_ADVERTISER_FOR_INVENTORY_PROTECTION', 1, 0))                                                 as tx_err_inventory_protection_advertiser
, SUM(IF(candidate__error = 'NO_BRAND_FOR_INVENTORY_PROTECTION', 1, 0))                                                      as tx_err_inventory_protection_brand
, SUM(IF(candidate__error = 'INVALID_COMPLIANCE_FOR_INVENTORY_PROTECTION', 1, 0))                                            as tx_err_inventory_protection_industry
, SUM(IF(candidate__error = 'KV_OPT_OUT', 1, 0))                                                                             as tx_err_kv_unsupported
, SUM(IF(candidate__error = 'LAT_UNSUPPORTED', 1, 0))                                                                        as tx_err_lat_unsupported
, SUM(IF(candidate__error = 'GLOBAL_ADVERTISER_RESTRICTED_BY_LISTING', 1, 0))                                                as tx_err_listing_advertiser_restriction
, SUM(IF(candidate__error = 'GLOBAL_BRAND_RESTRICTED_BY_LISTING', 1, 0))                                                     as tx_err_listing_brand_restriction
, SUM(IF(candidate__error = 'INDUSTRY_RESTRICTED_BY_LISTING', 1, 0))                                                         as tx_err_listing_industry_restriction
, SUM(IF(candidate__error = 'BLOCKED_BY_BID_THROTTLING', 1, 0))                                                              as tx_err_low_response_rate_limiter
, SUM(IF(candidate__error = 'MALFORMED_RESPONSE', 1, 0))                                                                     as tx_err_malformed_vast_xml
, SUM(IF(candidate__error = 'UNEXPECTED_EXTERNAL_AD_ID', 1, 0))                                                              as tx_err_mismatched_ad_id
, SUM(IF(candidate__error = 'UNEXPECTED_BID_DEALID', 1, 0))                                                                  as tx_err_mismatched_deal_id
, SUM(IF(candidate__error = 'BID_IMPRESSION_ID_NOMATCH', 1, 0))                                                              as tx_err_mismatched_impression_id  -- no data
, SUM(IF(candidate__error = 'UNKNOWN_SEAT', 1, 0))                                                                           as tx_err_mismatched_seat_id
, SUM(IF(candidate__error = 'GLOBAL_ADVERTISER_RESTRICTED_BY_INVENTORY', 1, 0))                                              as tx_err_network_item_advertiser_restriction
, SUM(IF(candidate__error = 'GLOBAL_BRAND_RESTRICTED_BY_INVENTORY', 1, 0))                                                   as tx_err_network_item_brand_restriction
, SUM(IF(candidate__error = 'COMPLIANCE_CHECK_FAILED', 1, 0))                                                                as tx_err_network_item_industry_restriction
, SUM(IF(candidate__error = 'BLOCKED_BY_INVENTORY_SOURCE_OPTIMIZATION', 1, 0))                                               as tx_err_network_item_inventory_source_optimization          -- no data
, SUM(IF(candidate__error IN ('RESTRICTED_SEAT_BY_AUCTION_NETWORK', 'RESTRICTED_SEAT_BY_PROGMOD_NETWORK'), 1, 0))            as tx_err_network_seat_restriction
, SUM(IF(candidate__error = 'NO_VALID_CREATIVE', 1, 0))                                                                      as tx_err_no_ad_in_vast
, SUM(IF(candidate__error = 'CLIENT_RENDITION_REQUIRED', 1, 0))                                                              as tx_err_no_client_condition
, SUM(IF(candidate__error = 'JITT_RENDITION_REQUIRED', 1, 0))                                                                as tx_err_no_jitt_rendition
, SUM(IF(candidate__error = 'GDPR_UNSUPPORTED', 1, 0))                                                                       as tx_err_no_tcf_consent
, SUM(IF(candidate__error = 'INAPPLICABLE_FOR_HTTPS', 1, 0))                                                                 as tx_err_non_secure_ad
, SUM(IF(candidate__error = 'SLOT_COMPANION_AD_ONLY', 1, 0))                                                                 as tx_err_only_companion_ad_allowed                           -- no data
, SUM(IF(candidate__error IN ('EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED', 'PROFILE_CHECK_FAILED'), 1, 0))                      as tx_err_profile_check_failed
, SUM(IF(candidate__error = 'RESELLER_WHITELIST_NOT_ALLOWED', 1, 0))                                                         as tx_err_reseller_allowlist_restriction
, SUM(IF(candidate__error = 'RESELLER_BLACKLIST_BANNED', 1, 0))                                                              as tx_err_reseller_blocklist_restriction
, SUM(IF(candidate__error = 'PRICE_HURDLE_CHECK_FAILED', 1, 0))                                                              as tx_err_rule_price_hurdle_not_met
, SUM(IF(candidate__error = 'ENDPOINT_INVALID', 1, 0))                                                                       as tx_err_ssp_endpoint_invalid_configuration
, SUM(IF(candidate__error = 'MKPL_EXCHANGE_ADVERTISER_FLOOR_PRICE_NOT_MET', 1, 0))                                           as tx_err_upstream_listing_advertiser_floor_price_not_met     -- no data
, SUM(IF(candidate__error = 'MKPL_EXCHANGE_BRAND_FLOOR_PRICE_NOT_MET', 1, 0))                                                as tx_err_upstream_listing_brand_floor_price_not_met          -- no data
, SUM(IF(candidate__error = 'LISTING_CREATIVE_DURATION_CHECK', 1, 0))                                                        as tx_err_upstream_listing_creative_duration_restriction
, SUM(IF(candidate__error = 'MKPL_EXCHANGE_INDUSTRY_FLOOR_PRICE_NOT_MET', 1, 0))                                             as tx_err_upstream_listing_industry_floor_price_not_met
, SUM(IF(candidate__error = 'MKPL_EXCHANGE_SEAT_FLOOR_PRICE_NOT_MET', 1, 0))                                                 as tx_err_upstream_listing_seat_floor_price_not_met           -- no data
, SUM(IF(candidate__error = 'RESTRICTED_SEAT_BY_MKPL_EXCHANGE', 1, 0))                                                       as tx_err_upstream_listing_seat_restriction                   -- no data
, SUM(IF(candidate__error = 'MKPL_ORDER_FLOOR_PRICE_NOT_MET', 1, 0))                                                         as tx_err_upstream_order_floor_price_not_met
, SUM(IF(candidate__error = 'UNSUPPORTED_VAST_VERSION', 1, 0))                                                               as tx_err_unsupported_vast_version
, SUM(IF(candidate__error = 'WRAPPER_HTTP_ERROR', 1, 0))                                                                     as tx_err_vast_wrapper_http_error
, SUM(IF(candidate__error = 'WRAPPER_TIMEOUT', 1, 0))                                                                        as tx_err_vast_wrapper_timeout                 -- no data
, SUM(IF(candidate__error = 'MET_YIELD_OPT_CAP', 1, 0))                                                                      as tx_err_yield_optimization_cap_reached                      -- no data
, SUM(IF(candidate__error = 'NO_SLOT_SELECTED', 1, 0))                                                                       as tx_err_no_slot_selected
, SUM(IF(BITWISE_AND(candidate__bid_status,8)=0 AND COALESCE(candidate__error, '') = '', 1, 0))                              as tx_err_unknown
, SUM(IF(candidate__error = 'CRO_ADVERTISER_FREQUENCY_CAP_REACHED', 1, 0))                                                   as tx_err_cro_advertiser_frequency_cap_reached
, SUM(IF(candidate__error = 'CRO_BRAND_FREQUENCY_CAP_REACHED', 1, 0))                                                        as tx_err_cro_brand_frequency_cap_reached
, SUM(IF(candidate__error = 'TWO_PHASE_TRANSLATION_UNSUPPORTED', 1, 0))                                                      as tx_err_demand_partner_unsupported_on_external_ssp_supply
, SUM(IF(candidate__error = 'LOWER_BIDDING_PRICE_THAN_MKPL_ORDER_PRICE', 1, 0))                                              as tx_err_marketplace_order_price_not_met_low_bid_price
, SUM(IF(candidate__error = 'UPSTREAM_CLIENT_RENDITION_REQUIRED', 1, 0))                                                     as tx_err_no_upstream_client_rendition
, SUM(IF(candidate__error = 'GLOBAL_ADVERTISER_RESTRICTED_BY_SA', 1, 0))                                                     as tx_err_standard_attribute_advertiser_restriction
, SUM(IF(candidate__error = 'INDUSTRY_RESTRICTED_BY_SA', 1, 0))                                                              as tx_err_standard_attribute_industry_restriction
, SUM(IF(candidate__error = 'SLOT_COMPATIBLITY_CHECK', 1, 0))                                                                as tx_err_slot_mismatch
, SUM(IF(candidate__error = 'RESTRICTION_RESELLER_WHITELIST_BY_SA', 1, 0))                                                   as tx_err_standard_attribute_reseller_allowlist_restriction
, SUM(IF(candidate__error = 'RESTRICTION_RESELLER_BLACKLIST_BY_SA', 1, 0))                                                   as tx_err_standard_attribute_reseller_blocklist_restriction
, SUM(IF(candidate__error = 'AD_UNIT_RESTRICTED_BY_SA', 1, 0))                                                               as tx_err_standard_attribute_ad_unit_restriction
, SUM(IF(candidate__error = 'GLOBAL_ADVERTISER_RESTRICTED_BY_DOMAIN', 1, 0))                                                 as tx_err_advertiser_domain_restricted
, SUM(IF(candidate__error = 'PENDING_APPROVAL_BY_DISTRIBUTOR', 1, 0))                                                        as tx_err_ad_pending_distributor_approval
, SUM(IF(candidate__error = 'NOT_APPROVED_BY_DISTRIBUTOR', 1, 0))                                                            as tx_err_ad_rejected_by_distributor
, SUM(IF(candidate__error = 'YIELD_OPT_MET', 1, 0))                                                                          as tx_err_yield_optimization_rule_met

-- Slot Level Error Metrics (32)
, 0 as slot_err_clearcast_code_restricted

, 0 as slot_err_competition_failure
, 0 as slot_err_adjacent_ads_exclusivity
, 0 as slot_err_advertiser_frequency_cap_reached
, 0 as slot_err_back_to_batch_exclusivity
, 0 as slot_err_brand_frequency_cap_reached
, 0 as slot_err_clearcast_restriction
, 0 as slot_err_deal_frequency_cap_reached
, 0 as slot_err_dsp_bid_cap_reached
, 0 as slot_err_header_bidding_repeating_key_value_exclusivity
, 0 as slot_err_inventory_protection_advertiser
, 0 as slot_err_inventory_protection_brand
, 0 as slot_err_inventory_protection_industry
, 0 as slot_err_max_number_of_ads_exceeded
, 0 as slot_err_max_slot_duration_exceeded
, 0 as slot_err_only_pod_ad_allowed
, 0 as slot_err_sequence_variant_targeting_failed
, 0 as slot_err_slot_exclusivity
, 0 as slot_err_swap_out_of_slot
, 0 as slot_err_low_ranking_in_buyer
, 0 as slot_err_cro_advertiser_frequency_cap_reaching
, 0 as slot_err_cro_brand_frequency_cap_reaching

, 0 as slot_err_profile_check_failed
, 0 as slot_err_adstor_creative_unavailable
, 0 as slot_err_creative_ad_unit_duration_incompatible
, 0 as slot_err_creative_profile_incompatible
, 0 as slot_err_creative_vpaid_incompatible
, 0 as slot_err_estimated_duration_disabled_for_live_inventory
, 0 as slot_err_adstore_creative_bitrate_incompatible
, 0 as slot_err_adstore_linear_creative_unavailable
, 0 as slot_err_creative_dimension_incompatible
, 0 as slot_err_creative_file_size_incompatible

-- ADM Endpoint Errors (29)
, cast(0 as bigint) as ack_err_adm_total
, cast(0 as bigint) as ack_err_adm_e_io
, cast(0 as bigint) as ack_err_adm_e_security
, cast(0 as bigint) as ack_err_adm_e_no_ad
, cast(0 as bigint) as ack_err_adm_e_timeout
, cast(0 as bigint) as ack_err_adm_e_overflow_skipped
, cast(0 as bigint) as ack_err_adm_e_missing_param
, cast(0 as bigint) as ack_err_adm_e_invalid_value
, cast(0 as bigint) as ack_err_adm_e_adinst_unavail
, cast(0 as bigint) as ack_err_adm_e_no_renderer
, cast(0 as bigint) as ack_err_adm_e_renderer_init
, cast(0 as bigint) as ack_err_adm_e_parse
, cast(0 as bigint) as ack_err_adm_e_null_asset
, cast(0 as bigint) as ack_err_adm_e_external_interface
, cast(0 as bigint) as ack_err_adm_e_3p_comp
, cast(0 as bigint) as ack_err_adm_e_device_limit
, cast(0 as bigint) as ack_err_adm_e_in_app_view
, cast(0 as bigint) as ack_err_adm_e_unknown
, cast(0 as bigint) as ack_err_adm_e_invalid_slot
, cast(0 as bigint) as ack_err_adm_e_network
, cast(0 as bigint) as ack_err_adm_e_no_preload_in_translator
, cast(0 as bigint) as ack_err_adm_e_renderer_load
, cast(0 as bigint) as ack_err_adm_e_slot_size_unmatch
, cast(0 as bigint) as ack_err_adm_e_slot_unavail
, cast(0 as bigint) as ack_err_adm_e_unsupp_3p_feature
, cast(0 as bigint) as ack_err_adm_e_really_no_ad
, cast(0 as bigint) as ack_err_adm_e_dashjs
, cast(0 as bigint) as ack_err_adm_e_custom_player
, cast(0 as bigint) as ack_err_adm_e_hlsjs

-- VAST Endpoint Errors (38)
, cast(0 as bigint) as ack_err_vast_total
, cast(0 as bigint) as ack_err_vast_51
, cast(0 as bigint) as ack_err_vast_52
, cast(0 as bigint) as ack_err_vast_100
, cast(0 as bigint) as ack_err_vast_101
, cast(0 as bigint) as ack_err_vast_102
, cast(0 as bigint) as ack_err_vast_200
, cast(0 as bigint) as ack_err_vast_201
, cast(0 as bigint) as ack_err_vast_202
, cast(0 as bigint) as ack_err_vast_203
, cast(0 as bigint) as ack_err_vast_204
, cast(0 as bigint) as ack_err_vast_300
, cast(0 as bigint) as ack_err_vast_301
, cast(0 as bigint) as ack_err_vast_302
, cast(0 as bigint) as ack_err_vast_303
, cast(0 as bigint) as ack_err_vast_304
, cast(0 as bigint) as ack_err_vast_400
, cast(0 as bigint) as ack_err_vast_401
, cast(0 as bigint) as ack_err_vast_402
, cast(0 as bigint) as ack_err_vast_403
, cast(0 as bigint) as ack_err_vast_405
, cast(0 as bigint) as ack_err_vast_406
, cast(0 as bigint) as ack_err_vast_407
, cast(0 as bigint) as ack_err_vast_408
, cast(0 as bigint) as ack_err_vast_409
, cast(0 as bigint) as ack_err_vast_410
, cast(0 as bigint) as ack_err_vast_411
, cast(0 as bigint) as ack_err_vast_500
, cast(0 as bigint) as ack_err_vast_501
, cast(0 as bigint) as ack_err_vast_502
, cast(0 as bigint) as ack_err_vast_503
, cast(0 as bigint) as ack_err_vast_600
, cast(0 as bigint) as ack_err_vast_601
, cast(0 as bigint) as ack_err_vast_602
, cast(0 as bigint) as ack_err_vast_603
, cast(0 as bigint) as ack_err_vast_604
, cast(0 as bigint) as ack_err_vast_900
, cast(0 as bigint) as ack_err_vast_901
FROM ${facts}.candidate
CROSS JOIN UNNEST(
    partners__network_id,
    partners__network_is_extra_item_owner,
    partners__supply_source,
    partners__sales_channel,
    partners__entity_source,
    partners__role,
    partners__content_owner_network_id,
    partners__distributor_network_id,
    partners__reseller_network_id,
    partners__site_id,
    partners__site_section_id,
    partners__series_id,
    partners__inbound_listing_id,
    partners__outbound_listing_id,
    partners__inbound_order_id,
    partners__deal_awareability,
    partners__content_form_visibility__report_aggregate,
    partners__geo_country_visibility__report_aggregate,
    partners__user_agent_visibility__report_aggregate,
    partners__standard_endpoint_owner_visibility__report_aggregate,
    partners__standard_endpoint_visibility__report_aggregate,
    partners__standard_programmer_visibility__report_aggregate,
    partners__standard_brand_visibility__report_aggregate)
nw (
  network_id,
  extra_item_owner,
  supply_source,
  sales_channel,
  entity_source,
  role,
  co_id,
  distributor_id,
  reseller_id,
  site_id,
  site_section_id,
  series_id,
  inbound_listing_ids,
  outbound_listing_ids,
  inbound_order_id,
  deal_awareability,
  content_form_visibility,
  country_visibility,
  user_agent_visibility,
  endpoint_owner_visibility,
  endpoint_visibility,
  programmer_visibility,
  brand_visibility)
WHERE process_batch_id = '${arena.presto.var.process_batch_id}'
  AND candidate__integration_type IN ('OPENRTB_NORMAL', 'OPENRTB_PG_TD')
  AND nw.entity_source = 'auction'
  AND (BITWISE_AND(candidate__flags, 131072)>0 OR BITWISE_AND(candidate__bid_status, 1)>0)
  AND nw.sales_channel = 4
  AND ${sampling_filter} --sampling filter
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58

UNION ALL

/** Selected Ads (Removed User Drop Off) **/

SELECT
   16                                                                                                                                           as process_stage

-- Network Chain (5)
, COALESCE(nw.network_id, -1)                                                                                                                   as network_id
, COALESCE(nw.supply_source, -1)                                                                                                                as supply_source
, COALESCE(nw.sales_channel, -1)                                                                                                                as sales_channel
, COALESCE(nw.co_id, -1)                                                                                                                        as content_owner_id
-- , IF(BITWISE_AND(request__extra_flags, 1073741824)>0 AND nw.role='CRO'
--     , -3, COALESCE(nw.distributor_id, -1))                                                                                                      as distributor_id
, COALESCE(nw.distributor_id, -1)                                                                                                               as distributor_id
-- Standard Attributes (12)
, IF(COALESCE(nw.country_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__country_id, -1))                               as user_country_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2 , COALESCE(visitor__standard_device_type_child_id, -1))        as standard_device_type_id
, COALESCE(request__context__standard_app_id, -1)                                                                                               as standard_app_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__standard_environment_id, -1))               as standard_environment_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__standard_os_id, -1))                        as standard_os_id

, IF(COALESCE(nw.endpoint_owner_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.endpoint_owner_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_endpoint_owner_id, -1), -1))   as standard_endpoint_owner_id

, IF(COALESCE(nw.endpoint_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.endpoint_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_endpoint_id, -1), -1))               as standard_endpoint_id

, IF(COALESCE(nw.programmer_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.programmer_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_programmer_id, -1), -1))           as standard_programmer_id

, IF(COALESCE(nw.brand_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.brand_visibility IS NOT NULL OR nw.supply_source != 3, COALESCE(request__context__standard_brand_id, -1), -1))                    as standard_brand_id

, COALESCE(request__context__standard_publisher_id, -1)                                                                                         as standard_publisher_id
, IF(COALESCE(nw.content_form_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.content_form_visibility IS NOT NULL OR nw.supply_source != 3, COALESCE(request__context__content_form_id, -1), -1))               as content_form_id
, COALESCE(request__context__stream_mode_id, -1)                                                                                                as stream_mode_id

-- Obj. Metadata (6)
, COALESCE(ads.auction__application_type, 'Unknown')                                                                                            as application_type
, COALESCE(ads.auction__device_type, 'Unknown')                                                                                                 as device_type
, COALESCE(ads.auction__site_domain, 'Unknown')                                                                                                 as site_domain
, COALESCE(ads.auction__app_bundle, 'Unknown')                                                                                                  as app_bundle
, ''                                                                                                                                            as app_storeurl  -- Only for auditing purpose
, COALESCE(ads.auction__ifa_type, 'Unknown')                                                                                                    as ifa_type

-- Inventory (7)
, COALESCE(ads.auction__time_position_class, '')                                                                                                as time_position_class
, IF(nw.sales_channel IN (5,6), COALESCE(nw.site_id, -1), COALESCE(ads.auction__site_id, -1))                                                                 as site_id
, IF(nw.sales_channel IN (5,6), COALESCE(nw.site_section_id, -1),
    COALESCE(ads.auction__site_section_id, -1))                                                                                                 as site_section_id
, IF(nw.sales_channel IN (5,6), COALESCE(nw.series_id, -1), COALESCE(ads.auction__series_id, -1))                                                             as series_id
-- , IF(COALESCE(request__context__profile_type, 'UNKNOWN') = 'COMPOUND',
--         COALESCE( IF(BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0 AND COALESCE(nw.role, '') = 'CRO', -3,
--                 COALESCE(request__context__profile_id, -1)), -1), -1)                                                                           as profile_id
, IF(COALESCE(request__context__profile_type, 'UNKNOWN') = 'COMPOUND', COALESCE(request__context__profile_id, -1), -1)                          as profile_id
, IF(nw.supply_source=6, COALESCE(nw.inbound_listing_ids, array[]), array[])                                                                    as upstream_listing_ids
, COALESCE(nw.inbound_order_id, -1)                                                                                                             as inbound_order_id

-- Demand (16)
, CASE
        WHEN (ads.auction__integration_type='PG_TD') THEN 'PG'
        WHEN (ads.auction__integration_type='NORMAL') THEN 'Non-PG'
        ELSE COALESCE(ads.auction__integration_type, 'Unknown')
  END                                                                                                                                           as demand_type
, COALESCE(ads.candidate__auction_type, 'NOT_APPLICABLE')                                                                                       as auction_type
, CASE
    WHEN ads.ad_is_fallback IS NULL THEN 'Not Applicable'
    WHEN ads.ad_is_fallback = TRUE THEN 'Fallback'
    ELSE 'Primary'
  END                                                                                                                                           as primary_ad_indicator
, COALESCE(ads.auction__dsp_id, -1)                                                                                                             as dsp_id
, COALESCE(ads.auction__buyer_platform_id, -1)                                                                                                  as buyer_platform_id
, IF(nw.deal_awareability=true, COALESCE(ads.candidate__buyer_group_id, -1), -1)                                                                as buyer_group_id
, Array[IF(nw.deal_awareability=true, COALESCE(ads.candidate__internal_deal_id, -1), -1)]                                                       as deal_ids
, IF(nw.deal_awareability=true, COALESCE(ads.candidate__bidding_buyer_id, -1), -1)                                                              as bidding_buyer_id
, COALESCE(ads.candidate__external_seat_id, 'Unknown')                                                                                          as bidding_external_seat_id
, COALESCE(ads.candidate__global_advertiser_ids, Array[])                                                                                       as global_advertiser_ids
, COALESCE(ads.candidate__global_brand_ids, Array[])                                                                                            as global_brand_ids
, COALESCE(ads.candidate__global_industry_ids, Array[])                                                                                         as global_industry_ids
, COALESCE(ads.candidate__market_ad_id, -1)                                                                                                     as market_ad_id
, COALESCE(ads.candidate__external_ad_id, 'Unknown')                                                                                            as external_ad_id
, COALESCE(ads.candidate__dsp_crid, 'Unknown')                                                                                                  as dsp_creative_id
, COALESCE(ads.ad_duration, COALESCE(ads.candidate__duration, 0))                                                                               as creative_duration

-- Auction (5)
, IF(BITWISE_AND(ads.auction__flags, 1)>0, true, false)                                                                                         as user_matched_indicator
, 'Not Applicable'                                                                                                                              as ifa_auditing
, 'Not Applicable'                                                                                                                              as app_bundle_auditing
, 'Not Applicable'                                                                                                                              as app_storeurl_auditing
, 'Not Applicable'                                                                                                                              as site_domain_auditing

-- Others (6)
, 'Not Applicable'                                                                                                                              as error_stage
, 'Removed'                                                                                                                                     as slot_user_drop_off
, COALESCE(request__traffic_type, 0)                                                                                                            as request_traffic_type
, COALESCE(ack__traffic_type, 0)                                                                                                                as ack_traffic_type
, process_batch_id                                                                                                                              as process_batch_id
, DATE_TRUNC('HOUR', ack__timestamp)                                                                                                            as event_date

-- Performance Metrics (22)
, 0 as bid_requests_error
, 0 as bid_requests
, 0 as bid_responses_error
, 0 as bid_responses
, 0 as opportunities_in_bid_request

, 0 as received_bids
, 0 as failed_bids
, 0 as resolved_bids
, 0 as filtered_bids
, SUM(IF(BITWISE_AND(ads.candidate__bid_status, 8)>0, 1, 0))                         as selected_bids
, 0 as filtered_bids_by_slot
, 0.0 as total_received_bid_price
, 0.0 as total_resolved_bid_price
, 0.0 as total_bid_won_price

, 0 as gross_ad_views
, 0 as clicks
, 0 as no_clicks
, 0 as first_quartile
, 0 as middle_quartile
, 0 as third_quartile
, 0 as complete_quartile
, 0 as can_quartile
, (cast (0 as double)) as revenue
, (cast (0 as double)) as co_revenue
, (cast (0 as double)) as r_revenue

-- Tx Level Error Metrics (99)
, 0 as tx_err_timeout
, 0 as tx_err_http_error
, 0 as tx_err_no_bids
, 0 as tx_err_bid_response_id_nomatch
, 0 as tx_err_empty_response
, 0 as tx_err_ad_duration_exceeded
, 0 as tx_err_ad_pending_approval
, 0 as tx_err_ad_rejected
, 0 as tx_err_ad_targeting_restriction
, 0 as tx_err_advertiser_frequency_cap_reached
, 0 as tx_err_atts_unsupported
, 0 as tx_err_brand_frequency_cap_reached
, 0 as tx_err_ccpa_opt_out
, 0 as tx_err_ccpa_gpp_us_privacy_opt_out
, 0 as tx_err_coppa_unsupported
, 0 as tx_err_inbound_order_competition_failure
, 0 as tx_err_competition_failure
, 0 as tx_err_creative_duration_mismatched
, 0 as tx_err_creative_not_applicable
, 0 as tx_err_creative_restriction_failure
, 0 as tx_err_dsp_status_complete
, 0 as tx_err_dsp_status_inactive
, 0 as tx_err_dsp_status_pause
, 0 as tx_err_dsp_status_unknown
, 0 as tx_err_data_rights_restricted
, 0 as tx_err_deal_advertiser_restriction
, 0 as tx_err_deal_brand_restriction
, 0 as tx_err_deal_floor_price_not_met
, 0 as tx_err_deal_frequency_cap_reached
, 0 as tx_err_deal_industry_restriction
, 0 as tx_err_deal_seat_restriction
, 0 as tx_err_demand_partner_disallowed_by_profile
, 0 as tx_err_empty_bid_id
, 0 as tx_err_empty_deal_id
, 0 as tx_err_empty_vast
, 0 as tx_err_empty_vast_ad_markup
, 0 as tx_err_exclusivity
, 0 as tx_err_gpp_not_supported
, 0 as tx_err_gpp_spi_opt_out
, 0 as tx_err_imr_inventory_source_optimization
, 0 as tx_err_inbound_mrm_rule_targeting_failed
, 0 as tx_err_inbound_mrm_rule_targeting_scope_failed
, 0 as tx_err_industry_restriction
, 0 as tx_err_invalid_bid_currency
, 0 as tx_err_invalid_bid_price
, 0 as tx_err_invalid_pg_creative
, 0 as tx_err_invalid_ad_id
, 0 as tx_err_invalid_vast_wrapper_url
, 0 as tx_err_inventory_protection_advertiser
, 0 as tx_err_inventory_protection_brand
, 0 as tx_err_inventory_protection_industry
, 0 as tx_err_kv_unsupported
, 0 as tx_err_lat_unsupported
, 0 as tx_err_listing_advertiser_restriction
, 0 as tx_err_listing_brand_restriction
, 0 as tx_err_listing_industry_restriction
, 0 as tx_err_low_response_rate_limiter
, 0 as tx_err_malformed_vast_xml
, 0 as tx_err_mismatched_ad_id
, 0 as tx_err_mismatched_deal_id
, 0 as tx_err_mismatched_impression_id
, 0 as tx_err_mismatched_seat_id
, 0 as tx_err_network_item_advertiser_restriction
, 0 as tx_err_network_item_brand_restriction
, 0 as tx_err_network_item_industry_restriction
, 0 as tx_err_network_item_inventory_source_optimization
, 0 as tx_err_network_seat_restriction
, 0 as tx_err_no_ad_in_vast
, 0 as tx_err_no_client_condition
, 0 as tx_err_no_jitt_rendition
, 0 as tx_err_no_tcf_consent
, 0 as tx_err_non_secure_ad
, 0 as tx_err_only_companion_ad_allowed
, 0 as tx_err_profile_check_failed
, 0 as tx_err_reseller_allowlist_restriction
, 0 as tx_err_reseller_blocklist_restriction
, 0 as tx_err_rule_price_hurdle_not_met
, 0 as tx_err_ssp_endpoint_invalid_configuration
, 0 as tx_err_upstream_listing_advertiser_floor_price_not_met
, 0 as tx_err_upstream_listing_brand_floor_price_not_met
, 0 as tx_err_upstream_listing_creative_duration_restriction
, 0 as tx_err_upstream_listing_industry_floor_price_not_met
, 0 as tx_err_upstream_listing_seat_floor_price_not_met
, 0 as tx_err_upstream_listing_seat_restriction
, 0 as tx_err_upstream_order_floor_price_not_met
, 0 as tx_err_unsupported_vast_version
, 0 as tx_err_vast_wrapper_http_error
, 0 as tx_err_vast_wrapper_timeout
, 0 as tx_err_yield_optimization_cap_reached
, 0 as tx_err_no_slot_selected
, 0 as tx_err_unknown
, 0 as tx_err_cro_advertiser_frequency_cap_reached
, 0 as tx_err_cro_brand_frequency_cap_reached
, 0 as tx_err_demand_partner_unsupported_on_external_ssp_supply
, 0 as tx_err_marketplace_order_price_not_met_low_bid_price
, 0 as tx_err_no_upstream_client_rendition
, 0 as tx_err_standard_attribute_advertiser_restriction
, 0 as tx_err_standard_attribute_industry_restriction
, 0 as tx_err_slot_mismatch
, 0 as tx_err_standard_attribute_reseller_allowlist_restriction
, 0 as tx_err_standard_attribute_reseller_blocklist_restriction
, 0 as tx_err_standard_attribute_ad_unit_restriction
, 0 as tx_err_advertiser_domain_restricted
, 0 as tx_err_ad_pending_distributor_approval
, 0 as tx_err_ad_rejected_by_distributor
, 0 as tx_err_yield_optimization_rule_met

-- Slot Level Error Metrics (32)
, 0 as slot_err_clearcast_code_restricted

, 0 as slot_err_competition_failure
, 0 as slot_err_adjacent_ads_exclusivity
, 0 as slot_err_advertiser_frequency_cap_reached
, 0 as slot_err_back_to_batch_exclusivity
, 0 as slot_err_brand_frequency_cap_reached
, 0 as slot_err_clearcast_restriction
, 0 as slot_err_deal_frequency_cap_reached
, 0 as slot_err_dsp_bid_cap_reached
, 0 as slot_err_header_bidding_repeating_key_value_exclusivity
, 0 as slot_err_inventory_protection_advertiser
, 0 as slot_err_inventory_protection_brand
, 0 as slot_err_inventory_protection_industry
, 0 as slot_err_max_number_of_ads_exceeded
, 0 as slot_err_max_slot_duration_exceeded
, 0 as slot_err_only_pod_ad_allowed
, 0 as slot_err_sequence_variant_targeting_failed
, 0 as slot_err_slot_exclusivity
, 0 as slot_err_swap_out_of_slot
, 0 as slot_err_low_ranking_in_buyer
, 0 as slot_err_cro_advertiser_frequency_cap_reaching
, 0 as slot_err_cro_brand_frequency_cap_reaching

, 0 as slot_err_profile_check_failed
, 0 as slot_err_adstor_creative_unavailable
, 0 as slot_err_creative_ad_unit_duration_incompatible
, 0 as slot_err_creative_profile_incompatible
, 0 as slot_err_creative_vpaid_incompatible
, 0 as slot_err_estimated_duration_disabled_for_live_inventory
, 0 as slot_err_adstore_creative_bitrate_incompatible
, 0 as slot_err_adstore_linear_creative_unavailable
, 0 as slot_err_creative_dimension_incompatible
, 0 as slot_err_creative_file_size_incompatible

-- ADM Endpoint Errors (29)
, cast(0 as bigint) as ack_err_adm_total
, cast(0 as bigint) as ack_err_adm_e_io
, cast(0 as bigint) as ack_err_adm_e_security
, cast(0 as bigint) as ack_err_adm_e_no_ad
, cast(0 as bigint) as ack_err_adm_e_timeout
, cast(0 as bigint) as ack_err_adm_e_overflow_skipped
, cast(0 as bigint) as ack_err_adm_e_missing_param
, cast(0 as bigint) as ack_err_adm_e_invalid_value
, cast(0 as bigint) as ack_err_adm_e_adinst_unavail
, cast(0 as bigint) as ack_err_adm_e_no_renderer
, cast(0 as bigint) as ack_err_adm_e_renderer_init
, cast(0 as bigint) as ack_err_adm_e_parse
, cast(0 as bigint) as ack_err_adm_e_null_asset
, cast(0 as bigint) as ack_err_adm_e_external_interface
, cast(0 as bigint) as ack_err_adm_e_3p_comp
, cast(0 as bigint) as ack_err_adm_e_device_limit
, cast(0 as bigint) as ack_err_adm_e_in_app_view
, cast(0 as bigint) as ack_err_adm_e_unknown
, cast(0 as bigint) as ack_err_adm_e_invalid_slot
, cast(0 as bigint) as ack_err_adm_e_network
, cast(0 as bigint) as ack_err_adm_e_no_preload_in_translator
, cast(0 as bigint) as ack_err_adm_e_renderer_load
, cast(0 as bigint) as ack_err_adm_e_slot_size_unmatch
, cast(0 as bigint) as ack_err_adm_e_slot_unavail
, cast(0 as bigint) as ack_err_adm_e_unsupp_3p_feature
, cast(0 as bigint) as ack_err_adm_e_really_no_ad
, cast(0 as bigint) as ack_err_adm_e_dashjs
, cast(0 as bigint) as ack_err_adm_e_custom_player
, cast(0 as bigint) as ack_err_adm_e_hlsjs

-- VAST Endpoint Errors (38)
, cast(0 as bigint) as ack_err_vast_total
, cast(0 as bigint) as ack_err_vast_51
, cast(0 as bigint) as ack_err_vast_52
, cast(0 as bigint) as ack_err_vast_100
, cast(0 as bigint) as ack_err_vast_101
, cast(0 as bigint) as ack_err_vast_102
, cast(0 as bigint) as ack_err_vast_200
, cast(0 as bigint) as ack_err_vast_201
, cast(0 as bigint) as ack_err_vast_202
, cast(0 as bigint) as ack_err_vast_203
, cast(0 as bigint) as ack_err_vast_204
, cast(0 as bigint) as ack_err_vast_300
, cast(0 as bigint) as ack_err_vast_301
, cast(0 as bigint) as ack_err_vast_302
, cast(0 as bigint) as ack_err_vast_303
, cast(0 as bigint) as ack_err_vast_304
, cast(0 as bigint) as ack_err_vast_400
, cast(0 as bigint) as ack_err_vast_401
, cast(0 as bigint) as ack_err_vast_402
, cast(0 as bigint) as ack_err_vast_403
, cast(0 as bigint) as ack_err_vast_405
, cast(0 as bigint) as ack_err_vast_406
, cast(0 as bigint) as ack_err_vast_407
, cast(0 as bigint) as ack_err_vast_408
, cast(0 as bigint) as ack_err_vast_409
, cast(0 as bigint) as ack_err_vast_410
, cast(0 as bigint) as ack_err_vast_411
, cast(0 as bigint) as ack_err_vast_500
, cast(0 as bigint) as ack_err_vast_501
, cast(0 as bigint) as ack_err_vast_502
, cast(0 as bigint) as ack_err_vast_503
, cast(0 as bigint) as ack_err_vast_600
, cast(0 as bigint) as ack_err_vast_601
, cast(0 as bigint) as ack_err_vast_602
, cast(0 as bigint) as ack_err_vast_603
, cast(0 as bigint) as ack_err_vast_604
, cast(0 as bigint) as ack_err_vast_900
, cast(0 as bigint) as ack_err_vast_901
FROM ${facts}.ack
CROSS JOIN UNNEST(
    ads_in_slot__advertisement__flags,
    ads_in_slot__advertisement__is_fallback,
    ads_in_slot__advertisement__duration,

    ads_in_slot__candidate__bid_status,
    ads_in_slot__candidate__auction_type,
    ads_in_slot__candidate__buyer_group_id,
    ads_in_slot__candidate__internal_deal_id,
    ads_in_slot__candidate__order_id,
    ads_in_slot__candidate__bidding_buyer_id,
    ads_in_slot__candidate__external_seat_id,
    ads_in_slot__candidate__global_advertiser_ids,
    ads_in_slot__candidate__global_brand_ids,
    ads_in_slot__candidate__global_industry_ids,
    ads_in_slot__candidate__market_ad_id,
    ads_in_slot__candidate__external_ad_id,
    ads_in_slot__candidate__duration,
    ads_in_slot__candidate__dsp_crid,

    ads_in_slot__auction__flags,
    ads_in_slot__auction__integration_type,
    ads_in_slot__auction__dsp_id,
    ads_in_slot__auction__buyer_platform_id,
    ads_in_slot__auction__application_type,
    ads_in_slot__auction__device_type,
    ads_in_slot__auction__site_domain,
    ads_in_slot__auction__app_bundle,
    ads_in_slot__auction__ifa_type,
    ads_in_slot__auction__time_position_class,
    ads_in_slot__auction__site_id,
    ads_in_slot__auction__site_section_id,
    ads_in_slot__auction__series_id,

    ads_in_slot__partners__network_id,
    ads_in_slot__partners__network_is_extra_item_owner,
    ads_in_slot__partners__supply_source,
    ads_in_slot__partners__sales_channel,
    ads_in_slot__partners__entity_source,
    ads_in_slot__partners__role,
    ads_in_slot__partners__content_owner_network_id,
    ads_in_slot__partners__distributor_network_id,
    ads_in_slot__partners__reseller_network_id,
    ads_in_slot__partners__site_id,
    ads_in_slot__partners__site_section_id,
    ads_in_slot__partners__series_id,
    ads_in_slot__partners__inbound_listing_id,
    ads_in_slot__partners__outbound_listing_id,
    ads_in_slot__partners__inbound_order_id,
    ads_in_slot__partners__deal_awareability,
    ads_in_slot__partners__content_form_visibility__report_aggregate,
    ads_in_slot__partners__geo_country_visibility__report_aggregate,
    ads_in_slot__partners__user_agent_visibility__report_aggregate,
    ads_in_slot__partners__standard_endpoint_owner_visibility__report_aggregate,
    ads_in_slot__partners__standard_endpoint_visibility__report_aggregate,
    ads_in_slot__partners__standard_programmer_visibility__report_aggregate,
    ads_in_slot__partners__standard_brand_visibility__report_aggregate)
as ads (
    ad_flags,
    ad_is_fallback,
    ad_duration,

    candidate__bid_status,
    candidate__auction_type,
    candidate__buyer_group_id,
    candidate__internal_deal_id,
    candidate__order_id,
    candidate__bidding_buyer_id,
    candidate__external_seat_id,
    candidate__global_advertiser_ids,
    candidate__global_brand_ids,
    candidate__global_industry_ids,
    candidate__market_ad_id,
    candidate__external_ad_id,
    candidate__duration,
    candidate__dsp_crid,

    auction__flags,
    auction__integration_type,
    auction__dsp_id,
    auction__buyer_platform_id,
    auction__application_type,
    auction__device_type,
    auction__site_domain,
    auction__app_bundle,
    auction__ifa_type,
    auction__time_position_class,
    auction__site_id,
    auction__site_section_id,
    auction__series_id,

    network_id,
    extra_item_owner,
    supply_source,
    sales_channel,
    entity_source,
    role,
    co_id,
    distributor_id,
    reseller_id,
    site_id,
    site_section_id,
    series_id,
    inbound_listing_ids,
    outbound_listing_ids,
    inbound_order_id,
    deal_awareability,
    content_form_visibility,
    country_visibility,
    user_agent_visibility,
    endpoint_owner_visibility,
    endpoint_visibility,
    programmer_visibility,
    brand_visibility)
CROSS JOIN UNNEST (
    ads.network_id,
    ads.extra_item_owner,
    ads.supply_source,
    ads.sales_channel,
    ads.entity_source,
    ads.role,
    ads.co_id,
    ads.distributor_id,
    ads.reseller_id,
    ads.site_id,
    ads.site_section_id,
    ads.series_id,
    ads.inbound_listing_ids,
    ads.outbound_listing_ids,
    ads.inbound_order_id,
    ads.deal_awareability,
    ads.content_form_visibility,
    ads.country_visibility,
    ads.user_agent_visibility,
    ads.endpoint_owner_visibility,
    ads.endpoint_visibility,
    ads.programmer_visibility,
    ads.brand_visibility)
as nw (
    network_id,
    extra_item_owner,
    supply_source,
    sales_channel,
    entity_source,
    role,
    co_id,
    distributor_id,
    reseller_id,
    site_id,
    site_section_id,
    series_id,
    inbound_listing_ids,
    outbound_listing_ids,
    inbound_order_id,
    deal_awareability,
    content_form_visibility,
    country_visibility,
    user_agent_visibility,
    endpoint_owner_visibility,
    endpoint_visibility,
    programmer_visibility,
    brand_visibility
)
WHERE process_batch_id = '${arena.presto.var.process_batch_id}'
  AND ads.auction__integration_type IN ('NORMAL', 'PG_TD', 'MKPL_PARTNER_TAG')
  AND BITWISE_AND(ads.candidate__bid_status, 8)>0
  AND nw.sales_channel = 4
  AND nw.supply_source != 4                                                      -- Remove DSP Rows
  AND COALESCE(advertisement__is_bumper, false) = false                          -- Remove Bumper Ad
  AND COALESCE(ack__ack_entity_type, '') = 'slot'
  AND COALESCE(ack__metrics__slot_impression, 0) > 0                             -- Has Slot Callback
  AND ${sampling_filter} --sampling filter
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58

UNION ALL

/** Candidate Per Slot **/

SELECT
   8                                                                                                                                            as process_stage

-- Network Chain (5)
, COALESCE(nw.network_id, -1)                                                                                                                   as network_id
, COALESCE(nw.supply_source, -1)                                                                                                                as supply_source
, COALESCE(nw.sales_channel, -1)                                                                                                                as sales_channel
, COALESCE(nw.co_id, -1)                                                                                                                        as content_owner_id
, cast(-1 as bigint)                                                                                                                            as distributor_id

-- Standard Attributes (12)
, IF(COALESCE(nw.country_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__country_id, -1))                               as user_country_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2 , COALESCE(visitor__standard_device_type_child_id, -1))        as standard_device_type_id
, COALESCE(request__context__standard_app_id, -1)                                                                                               as standard_app_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__standard_environment_id, -1))               as standard_environment_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__standard_os_id, -1))                        as standard_os_id

, IF(COALESCE(nw.endpoint_owner_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.endpoint_owner_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_endpoint_owner_id, -1), -1))   as standard_endpoint_owner_id

, IF(COALESCE(nw.endpoint_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.endpoint_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_endpoint_id, -1), -1))               as standard_endpoint_id

, IF(COALESCE(nw.programmer_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.programmer_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_programmer_id, -1), -1))           as standard_programmer_id

, IF(COALESCE(nw.brand_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.brand_visibility IS NOT NULL OR nw.supply_source != 3, COALESCE(request__context__standard_brand_id, -1), -1))                    as standard_brand_id

, COALESCE(request__context__standard_publisher_id, -1)                                                                                         as standard_publisher_id
, IF(COALESCE(nw.content_form_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.content_form_visibility IS NOT NULL OR nw.supply_source != 3, COALESCE(request__context__content_form_id, -1), -1))               as content_form_id
, COALESCE(request__context__stream_mode_id, -1)                                                                                                as stream_mode_id

-- Obj. Metadata (6)
, COALESCE(auction__application_type, 'Unknown')                                                                                                as application_type
, COALESCE(auction__device_type, 'Unknown')                                                                                                     as device_type
, COALESCE(auction__site_domain, 'Unknown')                                                                                                     as site_domain
, COALESCE(auction__app_bundle, 'Unknown')                                                                                                      as app_bundle
, ''                                                                                                                                            as app_storeurl  -- Only for auditing purpose
, COALESCE(auction__ifa_type, 'Unknown')                                                                                                        as ifa_type

-- Inventory (7)
, COALESCE(auction__time_position_class, 'Unknown')                                                                                             as time_position_class
, IF(nw.sales_channel IN (5,6), COALESCE(nw.site_id, -1), COALESCE(auction__site_id, -1))                                                                     as site_id
, IF(nw.sales_channel IN (5,6), COALESCE(nw.site_section_id, -1),
    COALESCE(auction__site_section_id, -1))                                                                                                     as site_section_id
, IF(nw.sales_channel IN (5,6), COALESCE(nw.series_id, -1), COALESCE(auction__series_id, -1))                                                                 as series_id
--, IF(COALESCE(request__context__profile_type, 'UNKNOWN') = 'COMPOUND',
--        COALESCE( IF(BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0 AND COALESCE(nw.role, '') = 'CRO', -3,
--                COALESCE(request__context__profile_id, -1)), -1), -1)                                                                           as profile_id
, IF(COALESCE(request__context__profile_type, 'UNKNOWN') = 'COMPOUND', COALESCE(request__context__profile_id, -1), -1)                          as profile_id
, IF(nw.supply_source=6, COALESCE(nw.inbound_listing_ids, array[]), array[])                                                                    as upstream_listing_ids
, COALESCE(nw.inbound_order_id, -1)                                                                                                             as inbound_order_id

-- Demand (16)
, CASE
        WHEN (auction__integration_type='PG_TD') THEN 'PG'
        WHEN (auction__integration_type='NORMAL') THEN 'Non-PG'
        ELSE COALESCE(auction__integration_type, 'Unknown')
  END                                                                                                                                           as demand_type
, COALESCE(candidate__auction_type, 'NOT_APPLICABLE')                                                                                           as auction_type
, CASE
    WHEN advertisement__is_fallback IS NULL THEN 'Not Applicable'
    WHEN advertisement__is_fallback = true THEN 'Fallback'
    ELSE 'Primary'
  END                                                                                                                                           as primary_ad_indicator
, COALESCE(auction__dsp_id, -1)                                                                                                                 as dsp_id
, COALESCE(auction__buyer_platform_id, -1)                                                                                                      as buyer_platform_id
, IF(nw.deal_awareability=true, COALESCE(candidate__buyer_group_id, -1), -1)                                                                    as buyer_group_id
, Array[IF(nw.deal_awareability=true, COALESCE(candidate__internal_deal_id, -1), -1)]                                                           as deal_ids
, IF(nw.deal_awareability=true, COALESCE(candidate__bidding_buyer_id, -1), -1)                                                                  as bidding_buyer_id
, COALESCE(candidate__external_seat_id, 'Unknown')                                                                                              as bidding_external_seat_id
, COALESCE(candidate__global_advertiser_ids, Array[])                                                                                           as global_advertiser_ids
, COALESCE(candidate__global_brand_ids, Array[])                                                                                                as global_brand_ids
, COALESCE(candidate__global_industry_ids, Array[])                                                                                             as global_industry_ids
, COALESCE(candidate__market_ad_id, -1)                                                                                                         as market_ad_id
, COALESCE(candidate__external_ad_id, 'Unknown')                                                                                                as external_ad_id
, COALESCE(candidate__dsp_crid, 'Unknown')                                                                                                      as dsp_creative_id
, COALESCE(advertisement__duration, COALESCE(candidate__duration, 0))                                                                           as creative_duration

-- Auction (5)
, IF(BITWISE_AND(auction__flags, 1)>0, true, false)                                                                                             as user_matched_indicator
, 'Not Applicable'                                                                                                                              as ifa_auditing
, 'Not Applicable'                                                                                                                              as app_bundle_auditing
, 'Not Applicable'                                                                                                                              as app_storeurl_auditing
, 'Not Applicable'                                                                                                                              as site_domain_auditing

-- Others (6)
, CASE
    WHEN BITWISE_AND(candidate__flags, 131072)>0 THEN 'Not Sent'
    WHEN BITWISE_AND(candidate__bid_status, 1)>0 AND BITWISE_AND(candidate__bid_status, 2)=0 THEN 'Not Resolved'
    WHEN BITWISE_AND(candidate__bid_status, 2)>0 AND BITWISE_AND(candidate__bid_status, 8)=0 THEN 'Not Selected'
  ELSE 'Not Applicable'
  END                                                                                                                                           as error_stage
, 'Included'                                                                                                                                    as slot_user_drop_off
, COALESCE(request__traffic_type, 0)                                                                                                            as request_traffic_type
, 0                                                                                                                                             as ack_traffic_type
, process_batch_id                                                                                                                              as process_batch_id
, DATE_TRUNC('HOUR', request__timestamp)                                                                                                        as event_date

-- Performance Metrics (22)
, 0 as bid_requests_error
, 0 as bid_requests
, 0 as bid_responses_error
, 0 as bid_responses
, 0 as opportunities_in_bid_request

, 0 as received_bids
, 0 as failed_bids
, 0 as resolved_bids
, 0 as filtered_bids
, 0 as selected_bids
, SUM(1) as filtered_bids_by_slot
, 0.0 as total_received_bid_price
, 0.0 as total_resolved_bid_price
, 0.0 as total_bid_won_price

, 0 as gross_ad_views
, 0 as clicks
, 0 as no_clicks
, 0 as first_quartile
, 0 as middle_quartile
, 0 as third_quartile
, 0 as complete_quartile
, 0 as can_quartile
, (cast (0 as double)) as revenue
, (cast (0 as double)) as co_revenue
, (cast (0 as double)) as r_revenue


-- Tx Level Error Metrics (99)
, 0 as tx_err_timeout
, 0 as tx_err_http_error
, 0 as tx_err_no_bids
, 0 as tx_err_bid_response_id_nomatch
, 0 as tx_err_empty_response
, 0 as tx_err_ad_duration_exceeded
, 0 as tx_err_ad_pending_approval
, 0 as tx_err_ad_rejected
, 0 as tx_err_ad_targeting_restriction
, 0 as tx_err_advertiser_frequency_cap_reached
, 0 as tx_err_atts_unsupported
, 0 as tx_err_brand_frequency_cap_reached
, 0 as tx_err_ccpa_opt_out
, 0 as tx_err_ccpa_gpp_us_privacy_opt_out
, 0 as tx_err_coppa_unsupported
, 0 as tx_err_inbound_order_competition_failure
, 0 as tx_err_competition_failure
, 0 as tx_err_creative_duration_mismatched
, 0 as tx_err_creative_not_applicable
, 0 as tx_err_creative_restriction_failure
, 0 as tx_err_dsp_status_complete
, 0 as tx_err_dsp_status_inactive
, 0 as tx_err_dsp_status_pause
, 0 as tx_err_dsp_status_unknown
, 0 as tx_err_data_rights_restricted
, 0 as tx_err_deal_advertiser_restriction
, 0 as tx_err_deal_brand_restriction
, 0 as tx_err_deal_floor_price_not_met
, 0 as tx_err_deal_frequency_cap_reached
, 0 as tx_err_deal_industry_restriction
, 0 as tx_err_deal_seat_restriction
, 0 as tx_err_demand_partner_disallowed_by_profile
, 0 as tx_err_empty_bid_id
, 0 as tx_err_empty_deal_id
, 0 as tx_err_empty_vast
, 0 as tx_err_empty_vast_ad_markup
, 0 as tx_err_exclusivity
, 0 as tx_err_gpp_not_supported
, 0 as tx_err_gpp_spi_opt_out
, 0 as tx_err_imr_inventory_source_optimization
, 0 as tx_err_inbound_mrm_rule_targeting_failed
, 0 as tx_err_inbound_mrm_rule_targeting_scope_failed
, 0 as tx_err_industry_restriction
, 0 as tx_err_invalid_bid_currency
, 0 as tx_err_invalid_bid_price
, 0 as tx_err_invalid_pg_creative
, 0 as tx_err_invalid_ad_id
, 0 as tx_err_invalid_vast_wrapper_url
, 0 as tx_err_inventory_protection_advertiser
, 0 as tx_err_inventory_protection_brand
, 0 as tx_err_inventory_protection_industry
, 0 as tx_err_kv_unsupported
, 0 as tx_err_lat_unsupported
, 0 as tx_err_listing_advertiser_restriction
, 0 as tx_err_listing_brand_restriction
, 0 as tx_err_listing_industry_restriction
, 0 as tx_err_low_response_rate_limiter
, 0 as tx_err_malformed_vast_xml
, 0 as tx_err_mismatched_ad_id
, 0 as tx_err_mismatched_deal_id
, 0 as tx_err_mismatched_impression_id
, 0 as tx_err_mismatched_seat_id
, 0 as tx_err_network_item_advertiser_restriction
, 0 as tx_err_network_item_brand_restriction
, 0 as tx_err_network_item_industry_restriction
, 0 as tx_err_network_item_inventory_source_optimization
, 0 as tx_err_network_seat_restriction
, 0 as tx_err_no_ad_in_vast
, 0 as tx_err_no_client_condition
, 0 as tx_err_no_jitt_rendition
, 0 as tx_err_no_tcf_consent
, 0 as tx_err_non_secure_ad
, 0 as tx_err_only_companion_ad_allowed
, 0 as tx_err_profile_check_failed
, 0 as tx_err_reseller_allowlist_restriction
, 0 as tx_err_reseller_blocklist_restriction
, 0 as tx_err_rule_price_hurdle_not_met
, 0 as tx_err_ssp_endpoint_invalid_configuration
, 0 as tx_err_upstream_listing_advertiser_floor_price_not_met
, 0 as tx_err_upstream_listing_brand_floor_price_not_met
, 0 as tx_err_upstream_listing_creative_duration_restriction
, 0 as tx_err_upstream_listing_industry_floor_price_not_met
, 0 as tx_err_upstream_listing_seat_floor_price_not_met
, 0 as tx_err_upstream_listing_seat_restriction
, 0 as tx_err_upstream_order_floor_price_not_met
, 0 as tx_err_unsupported_vast_version
, 0 as tx_err_vast_wrapper_http_error
, 0 as tx_err_vast_wrapper_timeout
, 0 as tx_err_yield_optimization_cap_reached
, 0 as tx_err_no_slot_selected
, 0 as tx_err_unknown
, 0 as tx_err_cro_advertiser_frequency_cap_reached
, 0 as tx_err_cro_brand_frequency_cap_reached
, 0 as tx_err_demand_partner_unsupported_on_external_ssp_supply
, 0 as tx_err_marketplace_order_price_not_met_low_bid_price
, 0 as tx_err_no_upstream_client_rendition
, 0 as tx_err_standard_attribute_advertiser_restriction
, 0 as tx_err_standard_attribute_industry_restriction
, 0 as tx_err_slot_mismatch
, 0 as tx_err_standard_attribute_reseller_allowlist_restriction
, 0 as tx_err_standard_attribute_reseller_blocklist_restriction
, 0 as tx_err_standard_attribute_ad_unit_restriction
, 0 as tx_err_advertiser_domain_restricted
, 0 as tx_err_ad_pending_distributor_approval
, 0 as tx_err_ad_rejected_by_distributor
, 0 as tx_err_yield_optimization_rule_met

-- Slot Level Error Metrics (32)
, SUM(IF(sub_err.error_category = 'CREATIVE_RESTRICTION_CHECK_FAILED' AND sub_err.error_code = 'CLEARCAST_CODE_RESTRICTED', 1, 0))                                                                             as slot_err_clearcast_code_restricted

, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE', 1, 0))                                                                                                                                                as slot_err_competition_failure
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'ADJACENT_EXCLUSIVITY', 1, 0))                                                                                                as slot_err_adjacent_ads_exclusivity
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'ADVERTISER_FREQUENCY_CAP_REACHING', 1, 0))                                                                                   as slot_err_advertiser_frequency_cap_reached
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'BACK2BACK_EXCLUDED', 1, 0))                                                                                                  as slot_err_back_to_batch_exclusivity
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'BRAND_FREQUENCY_CAP_REACHING', 1, 0))                                                                                        as slot_err_brand_frequency_cap_reached
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'CLEARCAST_NO_APPLICABLE_POSITION_IN_SLOT', 1, 0))                                                                            as slot_err_clearcast_restriction
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'FREQUENCY_CAP_REACHING', 1, 0))                                                                                              as slot_err_deal_frequency_cap_reached
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'RESTRICTED_BY_OPENRTB_IMPRESSION_BID_CAPPING', 1, 0))                                                                        as slot_err_dsp_bid_cap_reached
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'FROM_SAME_HEADER_BIDDING', 1, 0))                                                                                            as slot_err_header_bidding_repeating_key_value_exclusivity
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'ADVERTISER_SEPARATION_EXCLUDED', 1, 0))                                                                                      as slot_err_inventory_protection_advertiser
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'BRAND_SEPARATION_EXCLUDED', 1, 0))                                                                                           as slot_err_inventory_protection_brand
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'INDUSTRY_SEPARATION_EXCLUDED', 1, 0))                                                                                        as slot_err_inventory_protection_industry
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'EXCEED_MAX_NUM_ADVERTISEMENTS', 1, 0))                                                                                       as slot_err_max_number_of_ads_exceeded
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'EXCEED_MAX_SLOT_DURATION', 1, 0))                                                                                            as slot_err_max_slot_duration_exceeded
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'SLOT_FILLED_BY_MULTI_ADS', 1, 0))                                                                                            as slot_err_only_pod_ad_allowed
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'POSITION_OCCUPIED', 1, 0))                                                                                                   as slot_err_sequence_variant_targeting_failed
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'EXCLUSIVITY_BY_SLOT', 1, 0))                                                                                                 as slot_err_slot_exclusivity
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'SWAPPED_OUT_OF_SLOT', 1, 0))                                                                                                 as slot_err_swap_out_of_slot
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'LOW_RANKING_IN_BUYER', 1, 0))                                                                                                as slot_err_low_ranking_in_buyer
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'CRO_ADVERTISER_FREQUENCY_CAP_REACHING', 1, 0))                                                                               as slot_err_cro_advertiser_frequency_cap_reaching
, SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'CRO_BRAND_FREQUENCY_CAP_REACHING', 1, 0))                                                                                    as slot_err_cro_brand_frequency_cap_reaching

, SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED'), 1, 0))                                                                                                  as slot_err_profile_check_failed
, SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'AD_ASSET_STORE_NOT_AVAILABLE', 1, 0))                                          as slot_err_adstor_creative_unavailable
, SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'LARGE_RENDITION_DURATION', 1, 0))                                              as slot_err_creative_ad_unit_duration_incompatible
, SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code IN ('INCOMPATIBLE_FLASH_VERSION', 'NO_APPLICABLE_PROFILES_FOR_RENDITION'), 1, 0)) as slot_err_creative_profile_incompatible
, SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'CREATIVE_API_BANNED', 1, 0))                                                   as slot_err_creative_vpaid_incompatible
, SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'ESTIMATE_RENDITION_DURATION_FOR_LIVE', 1, 0))                                  as slot_err_estimated_duration_disabled_for_live_inventory
, SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'AD_ASSET_STORE_INAPPLICABLE_BITRATE', 1, 0))                                   as slot_err_adstore_creative_bitrate_incompatible
, SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'CREATIVE_NOT_AVAILABLE_FOR_LINEAR', 1, 0))                                     as slot_err_adstore_linear_creative_unavailable
, SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'INCOMPATIBLE_RENDITION_DIMENSION', 1, 0))                                      as slot_err_creative_dimension_incompatible
, SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'INCOMPATIBLE_RENDITION_FILE_SIZE', 1, 0))                                      as slot_err_creative_file_size_incompatible

-- ADM Endpoint Errors (29)
, cast(0 as bigint) as ack_err_adm_total
, cast(0 as bigint) as ack_err_adm_e_io
, cast(0 as bigint) as ack_err_adm_e_security
, cast(0 as bigint) as ack_err_adm_e_no_ad
, cast(0 as bigint) as ack_err_adm_e_timeout
, cast(0 as bigint) as ack_err_adm_e_overflow_skipped
, cast(0 as bigint) as ack_err_adm_e_missing_param
, cast(0 as bigint) as ack_err_adm_e_invalid_value
, cast(0 as bigint) as ack_err_adm_e_adinst_unavail
, cast(0 as bigint) as ack_err_adm_e_no_renderer
, cast(0 as bigint) as ack_err_adm_e_renderer_init
, cast(0 as bigint) as ack_err_adm_e_parse
, cast(0 as bigint) as ack_err_adm_e_null_asset
, cast(0 as bigint) as ack_err_adm_e_external_interface
, cast(0 as bigint) as ack_err_adm_e_3p_comp
, cast(0 as bigint) as ack_err_adm_e_device_limit
, cast(0 as bigint) as ack_err_adm_e_in_app_view
, cast(0 as bigint) as ack_err_adm_e_unknown
, cast(0 as bigint) as ack_err_adm_e_invalid_slot
, cast(0 as bigint) as ack_err_adm_e_network
, cast(0 as bigint) as ack_err_adm_e_no_preload_in_translator
, cast(0 as bigint) as ack_err_adm_e_renderer_load
, cast(0 as bigint) as ack_err_adm_e_slot_size_unmatch
, cast(0 as bigint) as ack_err_adm_e_slot_unavail
, cast(0 as bigint) as ack_err_adm_e_unsupp_3p_feature
, cast(0 as bigint) as ack_err_adm_e_really_no_ad
, cast(0 as bigint) as ack_err_adm_e_dashjs
, cast(0 as bigint) as ack_err_adm_e_custom_player
, cast(0 as bigint) as ack_err_adm_e_hlsjs

-- VAST Endpoint Errors (38)
, cast(0 as bigint) as ack_err_vast_total
, cast(0 as bigint) as ack_err_vast_51
, cast(0 as bigint) as ack_err_vast_52
, cast(0 as bigint) as ack_err_vast_100
, cast(0 as bigint) as ack_err_vast_101
, cast(0 as bigint) as ack_err_vast_102
, cast(0 as bigint) as ack_err_vast_200
, cast(0 as bigint) as ack_err_vast_201
, cast(0 as bigint) as ack_err_vast_202
, cast(0 as bigint) as ack_err_vast_203
, cast(0 as bigint) as ack_err_vast_204
, cast(0 as bigint) as ack_err_vast_300
, cast(0 as bigint) as ack_err_vast_301
, cast(0 as bigint) as ack_err_vast_302
, cast(0 as bigint) as ack_err_vast_303
, cast(0 as bigint) as ack_err_vast_304
, cast(0 as bigint) as ack_err_vast_400
, cast(0 as bigint) as ack_err_vast_401
, cast(0 as bigint) as ack_err_vast_402
, cast(0 as bigint) as ack_err_vast_403
, cast(0 as bigint) as ack_err_vast_405
, cast(0 as bigint) as ack_err_vast_406
, cast(0 as bigint) as ack_err_vast_407
, cast(0 as bigint) as ack_err_vast_408
, cast(0 as bigint) as ack_err_vast_409
, cast(0 as bigint) as ack_err_vast_410
, cast(0 as bigint) as ack_err_vast_411
, cast(0 as bigint) as ack_err_vast_500
, cast(0 as bigint) as ack_err_vast_501
, cast(0 as bigint) as ack_err_vast_502
, cast(0 as bigint) as ack_err_vast_503
, cast(0 as bigint) as ack_err_vast_600
, cast(0 as bigint) as ack_err_vast_601
, cast(0 as bigint) as ack_err_vast_602
, cast(0 as bigint) as ack_err_vast_603
, cast(0 as bigint) as ack_err_vast_604
, cast(0 as bigint) as ack_err_vast_900
, cast(0 as bigint) as ack_err_vast_901
FROM ${facts}.candidate
CROSS JOIN UNNEST(
    partners__network_id,
    partners__network_is_extra_item_owner,
    partners__supply_source,
    partners__sales_channel,
    partners__entity_source,
    partners__role,
    partners__content_owner_network_id,
    partners__distributor_network_id,
    partners__reseller_network_id,
    partners__site_id,
    partners__site_section_id,
    partners__series_id,
    partners__inbound_listing_id,
    partners__outbound_listing_id,
    partners__inbound_order_id,
    partners__deal_awareability,
    partners__content_form_visibility__report_aggregate,
    partners__geo_country_visibility__report_aggregate,
    partners__user_agent_visibility__report_aggregate,
    partners__standard_endpoint_owner_visibility__report_aggregate,
    partners__standard_endpoint_visibility__report_aggregate,
    partners__standard_programmer_visibility__report_aggregate,
    partners__standard_brand_visibility__report_aggregate)
nw (
  network_id,
  extra_item_owner,
  supply_source,
  sales_channel,
  entity_source,
  role,
  co_id,
  distributor_id,
  reseller_id,
  site_id,
  site_section_id,
  series_id,
  inbound_listing_ids,
  outbound_listing_ids,
  inbound_order_id,
  deal_awareability,
  content_form_visibility,
  country_visibility,
  user_agent_visibility,
  endpoint_owner_visibility,
  endpoint_visibility,
  programmer_visibility,
  brand_visibility)
CROSS JOIN UNNEST(
    candidate__filter_reason__error,
    candidate__filter_reason__error_category
)
sub_err (
    error_code,
    error_category)
WHERE process_batch_id = '${arena.presto.var.process_batch_id}'
  AND candidate__integration_type IN ('OPENRTB_NORMAL', 'OPENRTB_PG_TD')
  AND nw.entity_source = 'auction'
  AND sub_err.error_category = candidate__error
  AND nw.sales_channel = 4
  AND ${sampling_filter} --sampling filter
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58

UNION ALL
/** ACK **/

SELECT
   32                                                                                                                                           as process_stage

-- Network Chain (5)
, COALESCE(nw.network_id, -1)                                                                                                                   as network_id
, COALESCE(nw.supply_source, -1)                                                                                                                as supply_source
, COALESCE(nw.sales_channel, -1)                                                                                                                as sales_channel
, COALESCE(nw.co_id, -1)                                                                                                                        as content_owner_id
-- , IF(BITWISE_AND(request__extra_flags, 1073741824)>0 AND nw.role='CRO'
--     , -3, COALESCE(nw.distributor_id, -1))                                                                                                      as distributor_id
, COALESCE(nw.distributor_id, -1)                                                                                                               as distributor_id
-- Standard Attributes (12)
, IF(COALESCE(nw.country_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__country_id, -1))                               as user_country_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2 , COALESCE(visitor__standard_device_type_child_id, -1))        as standard_device_type_id
, COALESCE(request__context__standard_app_id, -1)                                                                                               as standard_app_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__standard_environment_id, -1))               as standard_environment_id
, IF(COALESCE(nw.user_agent_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2, COALESCE(visitor__standard_os_id, -1))                        as standard_os_id

, IF(COALESCE(nw.endpoint_owner_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.endpoint_owner_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_endpoint_owner_id, -1), -1))   as standard_endpoint_owner_id

, IF(COALESCE(nw.endpoint_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.endpoint_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_endpoint_id, -1), -1))               as standard_endpoint_id

, IF(COALESCE(nw.programmer_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.programmer_visibility IS NOT NULL OR nw.supply_source != 3,COALESCE(request__context__standard_programmer_id, -1), -1))           as standard_programmer_id

, IF(COALESCE(nw.brand_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.brand_visibility IS NOT NULL OR nw.supply_source != 3, COALESCE(request__context__standard_brand_id, -1), -1))                    as standard_brand_id

, COALESCE(request__context__standard_publisher_id, -1)                                                                                         as standard_publisher_id
, IF(COALESCE(nw.content_form_visibility, 'FULL_VISIBILITY') = 'NO_VISIBILITY', -2,
        IF(nw.content_form_visibility IS NOT NULL OR nw.supply_source != 3, COALESCE(request__context__content_form_id, -1), -1))               as content_form_id
, COALESCE(request__context__stream_mode_id, -1)                                                                                                as stream_mode_id

-- Obj. Metadata (6)
, COALESCE(auction__application_type, 'Unknown')                                                                                                as application_type
, COALESCE(auction__device_type, 'Unknown')                                                                                                     as device_type
, COALESCE(auction__site_domain, 'Unknown')                                                                                                     as site_domain
, COALESCE(auction__app_bundle, 'Unknown')                                                                                                      as app_bundle
, ''                                                                                                                                            as app_storeurl  -- Only for auditing purpose
, COALESCE(auction__ifa_type, 'Unknown')                                                                                                        as ifa_type

-- Inventory (7)
, COALESCE(slot__time_position_class, 'Unknown')                                                                                                as time_position_class
, COALESCE(nw.site_id, -1)                                                                                                                      as site_id
, COALESCE(nw.site_section_id, -1)                                                                                                              as site_section_id
, COALESCE(nw.series_id, -1)                                                                                                                    as series_id
-- , IF(COALESCE(request__context__profile_type, 'UNKNOWN') = 'COMPOUND',
--         COALESCE( IF(BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0 AND COALESCE(nw.role, '') = 'CRO', -3,
--                 COALESCE(request__context__profile_id, -1)), -1), -1)                                                                           as profile_id
, IF(COALESCE(request__context__profile_type, 'UNKNOWN') = 'COMPOUND', COALESCE(request__context__profile_id, -1), -1)                          as profile_id
, IF(nw.supply_source=6, COALESCE(nw.inbound_listing_ids, array[]), array[])                                                                    as upstream_listing_ids
, COALESCE(nw.inbound_order_id, -1)                                                                                                             as inbound_order_id

-- Demand (16)
, CASE
        WHEN (auction__integration_type='PG_TD') THEN 'PG'
        WHEN (auction__integration_type='NORMAL') THEN 'Non-PG'
        ELSE COALESCE(auction__integration_type, 'Unknown')
  END                                                                                                                                           as demand_type
, COALESCE(candidate__auction_type, 'NOT_APPLICABLE')                                                                                           as auction_type
, CASE
    WHEN advertisement__is_fallback IS NULL THEN 'Not Applicable'
    WHEN advertisement__is_fallback = true THEN 'Fallback'
    ELSE 'Primary'
  END                                                                                                                                           as primary_ad_indicator
, COALESCE(auction__dsp_id, -1)                                                                                                                 as dsp_id
, COALESCE(auction__buyer_platform_id, -1)                                                                                                      as buyer_platform_id
, IF(nw.deal_awareability=true, COALESCE(candidate__buyer_group_id, -1), -1)                                                                    as buyer_group_id
, Array[IF(nw.deal_awareability=true, COALESCE(candidate__internal_deal_id, -1), -1)]                                                           as deal_ids
, IF(nw.deal_awareability=true, COALESCE(candidate__bidding_buyer_id, -1), -1)                                                                  as bidding_buyer_id
, COALESCE(candidate__external_seat_id, 'Unknown')                                                                                              as bidding_external_seat_id
, COALESCE(candidate__global_advertiser_ids, Array[])                                                                                           as global_advertiser_ids
, COALESCE(candidate__global_brand_ids, Array[])                                                                                                as global_brand_ids
, COALESCE(candidate__global_industry_ids, Array[])                                                                                             as global_industry_ids
, COALESCE(candidate__market_ad_id, -1)                                                                                                         as market_ad_id
, COALESCE(candidate__external_ad_id, 'Unknown')                                                                                                as external_ad_id
, COALESCE(candidate__dsp_crid, 'Unknown')                                                                                                      as dsp_creative_id
, COALESCE(advertisement__duration, COALESCE(candidate__duration, 0))                                                                           as creative_duration

-- Auction (5)
, IF(BITWISE_AND(auction__flags, 1)>0, true, false)                                                                                             as user_matched_indicator
, 'Not Applicable'                                                                                                                              as ifa_auditing
, 'Not Applicable'                                                                                                                              as app_bundle_auditing
, 'Not Applicable'                                                                                                                              as app_storeurl_auditing
, 'Not Applicable'                                                                                                                              as site_domain_auditing

-- Others (6)
, 'Not Applicable'                                                                                                                              as error_stage
, 'Not Applicable'                                                                                                                              as slot_user_drop_off
, COALESCE(request__traffic_type, 0)                                                                                                            as request_traffic_type
, COALESCE(ack__traffic_type, 0)                                                                                                                as ack_traffic_type
, process_batch_id                                                                                                                              as process_batch_id
, DATE_TRUNC('HOUR', ack__timestamp)                                                                                                            as event_date

-- Performance Metrics (22)
, 0 as bid_requests_error
, 0 as bid_requests
, 0 as bid_responses_error
, 0 as bid_responses
, 0 as opportunities_in_bid_request

, 0 as received_bids
, 0 as failed_bids
, 0 as resolved_bids
, 0 as filtered_bids
, 0 as selected_bids
, 0 as filtered_bids_by_slot
, 0.0 as total_received_bid_price
, 0.0 as total_resolved_bid_price
, 0.0 as total_bid_won_price

, sum(COALESCE(ack__metrics__raw_ad_impression, 0))                                             as gross_ad_views
, sum(COALESCE(ack__metrics__click, 0))                                                         as clicks
, sum(COALESCE(ack__metrics__no_click, 0))                                                      as no_clicks
, sum(COALESCE(ack__metrics__first_quartile, 0))                                                as first_quartile
, sum(COALESCE(ack__metrics__middle_quartile, 0))                                               as middle_quartile
, sum(COALESCE(ack__metrics__third_quartile, 0))                                                as third_quartile
, sum(COALESCE(ack__metrics__complete_quartile, 0))                                             as complete_quartile
, sum(COALESCE(ack__metrics__can_quartile, 0))                                                  as can_quartile
, sum((COALESCE(nw.revenue, 0) * COALESCE(ack__metrics__fire_event_revenue_ratio, 0)))          as revenue
, sum((COALESCE(nw.co_revenue, 0) * COALESCE(ack__metrics__fire_event_revenue_ratio, 0)))       as co_revenue
, sum((COALESCE(nw.r_revenue, 0) * COALESCE(ack__metrics__fire_event_revenue_ratio, 0)))        as r_revenue

-- Tx Level Error Metrics (99)
, 0 as tx_err_timeout
, 0 as tx_err_http_error
, 0 as tx_err_no_bids
, 0 as tx_err_bid_response_id_nomatch
, 0 as tx_err_empty_response
, 0 as tx_err_ad_duration_exceeded
, 0 as tx_err_ad_pending_approval
, 0 as tx_err_ad_rejected
, 0 as tx_err_ad_targeting_restriction
, 0 as tx_err_advertiser_frequency_cap_reached
, 0 as tx_err_atts_unsupported
, 0 as tx_err_brand_frequency_cap_reached
, 0 as tx_err_ccpa_opt_out
, 0 as tx_err_ccpa_gpp_us_privacy_opt_out
, 0 as tx_err_coppa_unsupported
, 0 as tx_err_inbound_order_competition_failure
, 0 as tx_err_competition_failure
, 0 as tx_err_creative_duration_mismatched
, 0 as tx_err_creative_not_applicable
, 0 as tx_err_creative_restriction_failure
, 0 as tx_err_dsp_status_complete
, 0 as tx_err_dsp_status_inactive
, 0 as tx_err_dsp_status_pause
, 0 as tx_err_dsp_status_unknown
, 0 as tx_err_data_rights_restricted
, 0 as tx_err_deal_advertiser_restriction
, 0 as tx_err_deal_brand_restriction
, 0 as tx_err_deal_floor_price_not_met
, 0 as tx_err_deal_frequency_cap_reached
, 0 as tx_err_deal_industry_restriction
, 0 as tx_err_deal_seat_restriction
, 0 as tx_err_demand_partner_disallowed_by_profile
, 0 as tx_err_empty_bid_id
, 0 as tx_err_empty_deal_id
, 0 as tx_err_empty_vast
, 0 as tx_err_empty_vast_ad_markup
, 0 as tx_err_exclusivity
, 0 as tx_err_gpp_not_supported
, 0 as tx_err_gpp_spi_opt_out
, 0 as tx_err_imr_inventory_source_optimization
, 0 as tx_err_inbound_mrm_rule_targeting_failed
, 0 as tx_err_inbound_mrm_rule_targeting_scope_failed
, 0 as tx_err_industry_restriction
, 0 as tx_err_invalid_bid_currency
, 0 as tx_err_invalid_bid_price
, 0 as tx_err_invalid_pg_creative
, 0 as tx_err_invalid_ad_id
, 0 as tx_err_invalid_vast_wrapper_url
, 0 as tx_err_inventory_protection_advertiser
, 0 as tx_err_inventory_protection_brand
, 0 as tx_err_inventory_protection_industry
, 0 as tx_err_kv_unsupported
, 0 as tx_err_lat_unsupported
, 0 as tx_err_listing_advertiser_restriction
, 0 as tx_err_listing_brand_restriction
, 0 as tx_err_listing_industry_restriction
, 0 as tx_err_low_response_rate_limiter
, 0 as tx_err_malformed_vast_xml
, 0 as tx_err_mismatched_ad_id
, 0 as tx_err_mismatched_deal_id
, 0 as tx_err_mismatched_impression_id
, 0 as tx_err_mismatched_seat_id
, 0 as tx_err_network_item_advertiser_restriction
, 0 as tx_err_network_item_brand_restriction
, 0 as tx_err_network_item_industry_restriction
, 0 as tx_err_network_item_inventory_source_optimization
, 0 as tx_err_network_seat_restriction
, 0 as tx_err_no_ad_in_vast
, 0 as tx_err_no_client_condition
, 0 as tx_err_no_jitt_rendition
, 0 as tx_err_no_tcf_consent
, 0 as tx_err_non_secure_ad
, 0 as tx_err_only_companion_ad_allowed
, 0 as tx_err_profile_check_failed
, 0 as tx_err_reseller_allowlist_restriction
, 0 as tx_err_reseller_blocklist_restriction
, 0 as tx_err_rule_price_hurdle_not_met
, 0 as tx_err_ssp_endpoint_invalid_configuration
, 0 as tx_err_upstream_listing_advertiser_floor_price_not_met
, 0 as tx_err_upstream_listing_brand_floor_price_not_met
, 0 as tx_err_upstream_listing_creative_duration_restriction
, 0 as tx_err_upstream_listing_industry_floor_price_not_met
, 0 as tx_err_upstream_listing_seat_floor_price_not_met
, 0 as tx_err_upstream_listing_seat_restriction
, 0 as tx_err_upstream_order_floor_price_not_met
, 0 as tx_err_unsupported_vast_version
, 0 as tx_err_vast_wrapper_http_error
, 0 as tx_err_vast_wrapper_timeout
, 0 as tx_err_yield_optimization_cap_reached
, 0 as tx_err_no_slot_selected
, 0 as tx_err_unknown
, 0 as tx_err_cro_advertiser_frequency_cap_reached
, 0 as tx_err_cro_brand_frequency_cap_reached
, 0 as tx_err_demand_partner_unsupported_on_external_ssp_supply
, 0 as tx_err_marketplace_order_price_not_met_low_bid_price
, 0 as tx_err_no_upstream_client_rendition
, 0 as tx_err_standard_attribute_advertiser_restriction
, 0 as tx_err_standard_attribute_industry_restriction
, 0 as tx_err_slot_mismatch
, 0 as tx_err_standard_attribute_reseller_allowlist_restriction
, 0 as tx_err_standard_attribute_reseller_blocklist_restriction
, 0 as tx_err_standard_attribute_ad_unit_restriction
, 0 as tx_err_advertiser_domain_restricted
, 0 as tx_err_ad_pending_distributor_approval
, 0 as tx_err_ad_rejected_by_distributor
, 0 as tx_err_yield_optimization_rule_met

-- Slot Level Error Metrics (32)
, 0 as slot_err_clearcast_code_restricted

, 0 as slot_err_competition_failure
, 0 as slot_err_adjacent_ads_exclusivity
, 0 as slot_err_advertiser_frequency_cap_reached
, 0 as slot_err_back_to_batch_exclusivity
, 0 as slot_err_brand_frequency_cap_reached
, 0 as slot_err_clearcast_restriction
, 0 as slot_err_deal_frequency_cap_reached
, 0 as slot_err_dsp_bid_cap_reached
, 0 as slot_err_header_bidding_repeating_key_value_exclusivity
, 0 as slot_err_inventory_protection_advertiser
, 0 as slot_err_inventory_protection_brand
, 0 as slot_err_inventory_protection_industry
, 0 as slot_err_max_number_of_ads_exceeded
, 0 as slot_err_max_slot_duration_exceeded
, 0 as slot_err_only_pod_ad_allowed
, 0 as slot_err_sequence_variant_targeting_failed
, 0 as slot_err_slot_exclusivity
, 0 as slot_err_swap_out_of_slot
, 0 as slot_err_low_ranking_in_buyer
, 0 as slot_err_cro_advertiser_frequency_cap_reaching
, 0 as slot_err_cro_brand_frequency_cap_reaching

, 0 as slot_err_profile_check_failed
, 0 as slot_err_adstor_creative_unavailable
, 0 as slot_err_creative_ad_unit_duration_incompatible
, 0 as slot_err_creative_profile_incompatible
, 0 as slot_err_creative_vpaid_incompatible
, 0 as slot_err_estimated_duration_disabled_for_live_inventory
, 0 as slot_err_adstore_creative_bitrate_incompatible
, 0 as slot_err_adstore_linear_creative_unavailable
, 0 as slot_err_creative_dimension_incompatible
, 0 as slot_err_creative_file_size_incompatible

-- ADM Endpoint Errors (29)
    , sum(if(ack__event_type = 'e' and ack__event_category = 'ad_manager_error', ack__metrics__ad_error, 0)) as ack_err_adm_total
    , sum(if(ack__event_name='_e_io', ack__metrics__ad_error, 0)) as ack_err_adm_e_io
    , sum(if(ack__event_name='_e_security', ack__metrics__ad_error, 0)) as ack_err_adm_e_security
    , sum(if(ack__event_name='_e_no-ad', ack__metrics__ad_error, 0)) as ack_err_adm_e_no_ad
    , sum(if(ack__event_name='_e_timeout', ack__metrics__ad_error, 0)) as ack_err_adm_e_timeout
    , sum(if(ack__event_name='_e_overflow-skipped', ack__metrics__ad_error, 0)) as ack_err_adm_e_overflow_skipped
    , sum(if(ack__event_name='_e_missing-param', ack__metrics__ad_error, 0)) as ack_err_adm_e_missing_param
    , sum(if(ack__event_name='_e_invalid-value', ack__metrics__ad_error, 0)) as ack_err_adm_e_invalid_value
    , sum(if(ack__event_name='_e_adinst-unavail', ack__metrics__ad_error, 0)) as ack_err_adm_e_adinst_unavail
    , sum(if(ack__event_name='_e_no-renderer', ack__metrics__ad_error, 0)) as ack_err_adm_e_no_renderer
    , sum(if(ack__event_name='_e_renderer-init', ack__metrics__ad_error, 0)) as ack_err_adm_e_renderer_init
    , sum(if(ack__event_name='_e_parse', ack__metrics__ad_error, 0)) as ack_err_adm_e_parse
    , sum(if(ack__event_name='_e_null-asset', ack__metrics__ad_error, 0)) as ack_err_adm_e_null_asset
    , sum(if(ack__event_name='_e_external-interface', ack__metrics__ad_error, 0)) as ack_err_adm_e_external_interface
    , sum(if(ack__event_name='_e_3p-comp', ack__metrics__ad_error, 0)) as ack_err_adm_e_3p_comp
    , sum(if(ack__event_name='_e_device-limit', ack__metrics__ad_error, 0)) as ack_err_adm_e_device_limit
    , sum(if(ack__event_name='_e_in-app-view', ack__metrics__ad_error, 0)) as ack_err_adm_e_in_app_view
    , sum(if(ack__event_name='_e_unknown', ack__metrics__ad_error, 0)) as ack_err_adm_e_unknown
    , sum(if(ack__event_name='_e_invalid-slot', ack__metrics__ad_error, 0)) as ack_err_adm_e_invalid_slot
    , sum(if(ack__event_name='_e_network', ack__metrics__ad_error, 0)) as ack_err_adm_e_network
    , sum(if(ack__event_name='_e_no-preload-in-translator', ack__metrics__ad_error, 0)) as ack_err_adm_e_no_preload_in_translator
    , sum(if(ack__event_name='_e_renderer-load', ack__metrics__ad_error, 0)) as ack_err_adm_e_renderer_load
    , sum(if(ack__event_name='_e_slot-size-unmatch', ack__metrics__ad_error, 0)) as ack_err_adm_e_slot_size_unmatch
    , sum(if(ack__event_name='_e_slot-unavail', ack__metrics__ad_error, 0)) as ack_err_adm_e_slot_unavail
    , sum(if(ack__event_name='_e_unsupp-3p-feature', ack__metrics__ad_error, 0)) as ack_err_adm_e_unsupp_3p_feature
    , sum(if(ack__event_name='_e_really-no-ad', ack__metrics__ad_error, 0)) as ack_err_adm_e_really_no_ad
    , sum(if(ack__event_name='_e_dashjs', ack__metrics__ad_error, 0)) as ack_err_adm_e_dashjs
    , sum(if(ack__event_name='_e_custom_player', ack__metrics__ad_error, 0)) as ack_err_adm_e_custom_player
    , sum(if(ack__event_name='_e_hlsjs', ack__metrics__ad_error, 0)) as ack_err_adm_e_hlsjs

-- VAST Endpoint Errors (38)
    , sum(if(ack__event_type = 'e' and ack__event_category = 'vast_error', ack__metrics__ad_error, 0))       as ack_err_vast_total
    , sum(if(ack__event_name='51', ack__metrics__ad_error, 0)) as ack_err_vast_51
    , sum(if(ack__event_name='52', ack__metrics__ad_error, 0)) as ack_err_vast_52
    , sum(if(ack__event_name='100', ack__metrics__ad_error, 0)) as ack_err_vast_100
    , sum(if(ack__event_name='101', ack__metrics__ad_error, 0)) as ack_err_vast_101
    , sum(if(ack__event_name='102', ack__metrics__ad_error, 0)) as ack_err_vast_102
    , sum(if(ack__event_name='200', ack__metrics__ad_error, 0)) as ack_err_vast_200
    , sum(if(ack__event_name='201', ack__metrics__ad_error, 0)) as ack_err_vast_201
    , sum(if(ack__event_name='202', ack__metrics__ad_error, 0)) as ack_err_vast_202
    , sum(if(ack__event_name='203', ack__metrics__ad_error, 0)) as ack_err_vast_203
    , sum(if(ack__event_name='204', ack__metrics__ad_error, 0)) as ack_err_vast_204
    , sum(if(ack__event_name='300', ack__metrics__ad_error, 0)) as ack_err_vast_300
    , sum(if(ack__event_name='301', ack__metrics__ad_error, 0)) as ack_err_vast_301
    , sum(if(ack__event_name='302', ack__metrics__ad_error, 0)) as ack_err_vast_302
    , sum(if(ack__event_name='303', ack__metrics__ad_error, 0)) as ack_err_vast_303
    , sum(if(ack__event_name='304', ack__metrics__ad_error, 0)) as ack_err_vast_304
    , sum(if(ack__event_name='400', ack__metrics__ad_error, 0)) as ack_err_vast_400
    , sum(if(ack__event_name='401', ack__metrics__ad_error, 0)) as ack_err_vast_401
    , sum(if(ack__event_name='402', ack__metrics__ad_error, 0)) as ack_err_vast_402
    , sum(if(ack__event_name='403', ack__metrics__ad_error, 0)) as ack_err_vast_403
    , sum(if(ack__event_name='405', ack__metrics__ad_error, 0)) as ack_err_vast_405
    , sum(if(ack__event_name='406', ack__metrics__ad_error, 0)) as ack_err_vast_406
    , sum(if(ack__event_name='407', ack__metrics__ad_error, 0)) as ack_err_vast_407
    , sum(if(ack__event_name='408', ack__metrics__ad_error, 0)) as ack_err_vast_408
    , sum(if(ack__event_name='409', ack__metrics__ad_error, 0)) as ack_err_vast_409
    , sum(if(ack__event_name='410', ack__metrics__ad_error, 0)) as ack_err_vast_410
    , sum(if(ack__event_name='411', ack__metrics__ad_error, 0)) as ack_err_vast_411
    , sum(if(ack__event_name='500', ack__metrics__ad_error, 0)) as ack_err_vast_500
    , sum(if(ack__event_name='501', ack__metrics__ad_error, 0)) as ack_err_vast_501
    , sum(if(ack__event_name='502', ack__metrics__ad_error, 0)) as ack_err_vast_502
    , sum(if(ack__event_name='503', ack__metrics__ad_error, 0)) as ack_err_vast_503
    , sum(if(ack__event_name='600', ack__metrics__ad_error, 0)) as ack_err_vast_600
    , sum(if(ack__event_name='601', ack__metrics__ad_error, 0)) as ack_err_vast_601
    , sum(if(ack__event_name='602', ack__metrics__ad_error, 0)) as ack_err_vast_602
    , sum(if(ack__event_name='603', ack__metrics__ad_error, 0)) as ack_err_vast_603
    , sum(if(ack__event_name='604', ack__metrics__ad_error, 0)) as ack_err_vast_604
    , sum(if(ack__event_name='900', ack__metrics__ad_error, 0)) as ack_err_vast_900
    , sum(if(ack__event_name='901', ack__metrics__ad_error, 0)) as ack_err_vast_901

FROM ${facts}.ack
CROSS JOIN UNNEST(
    partners__network_id,
    partners__network_is_extra_item_owner,
    partners__supply_source,
    partners__sales_channel,
    partners__role,
    partners__content_owner_network_id,
    partners__distributor_network_id,
    partners__reseller_network_id,
    partners__inbound_listing_id,
    partners__outbound_listing_id,
    partners__inbound_order_id,
    partners__deal_awareability,
    partners__content_form_visibility__report_aggregate,
    partners__geo_country_visibility__report_aggregate,
    partners__user_agent_visibility__report_aggregate,
    partners__standard_endpoint_owner_visibility__report_aggregate,
    partners__standard_endpoint_visibility__report_aggregate,
    partners__standard_programmer_visibility__report_aggregate,
    partners__standard_brand_visibility__report_aggregate,
    partners__site_id,
    partners__site_section_id,
    partners__series_id,
    partners__revenue,
    partners__content_owner_revenue,
    partners__reseller_revenue)
nw (
  network_id,
  extra_item_owner,
  supply_source,
  sales_channel,
  role,
  co_id,
  distributor_id,
  reseller_id,
  inbound_listing_ids,
  outbound_listing_ids,
  inbound_order_id,
  deal_awareability,
  content_form_visibility,
  country_visibility,
  user_agent_visibility,
  endpoint_owner_visibility,
  endpoint_visibility,
  programmer_visibility,
  brand_visibility,
  site_id,
  site_section_id,
  series_id,
  revenue,
  co_revenue,
  r_revenue)
WHERE process_batch_id = '${arena.presto.var.process_batch_id}'
  AND candidate__integration_type IN ('OPENRTB_NORMAL', 'OPENRTB_PG_TD')
  AND (coalesce(ack__ack_entity_type, '') = 'ad'
        OR (ack__event_type = 'e' and ack__event_category in ('ad_manager_error', 'vast_error')))
  AND nw.sales_channel = 4
  AND nw.supply_source != 4                                  -- Remove DSP Rows
  AND COALESCE(advertisement__is_bumper, false) = false      -- Remove Bumper Ad
  AND (
    COALESCE(ack__metrics__raw_ad_impression, 0) != 0
    OR COALESCE(ack__metrics__click, 0) != 0
    OR COALESCE(ack__metrics__no_click, 0) != 0
    OR COALESCE(ack__metrics__can_quartile, 0) != 0
    OR COALESCE(ack__metrics__first_quartile, 0) != 0
    OR COALESCE(ack__metrics__middle_quartile, 0) != 0
    OR COALESCE(ack__metrics__third_quartile, 0) != 0
    OR COALESCE(ack__metrics__complete_quartile, 0) != 0
    OR COALESCE(ack__metrics__fire_event_revenue_ratio, 0) != 0
    OR COALESCE(ack__metrics__ad_error, 0) != 0
    )
  AND ${sampling_filter} --sampling filter
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58
)
GROUP BY 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 281, 292, 300, 304
