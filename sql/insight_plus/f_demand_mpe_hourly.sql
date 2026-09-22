
select
    reduce(set_agg(process_stage), 0, (acc, val) -> acc + val, val -> val) as process_stage
    , f.network_id
    , f.stream_mode_id
    , f.standard_brand_id
    , f.standard_brand_visibility
    , f.standard_programmer_id
    , f.standard_programmer_visibility
    , f.standard_endpoint_id
    , f.standard_endpoint_visibility
    , f.standard_endpoint_owner_id
    , f.standard_endpoint_owner_visibility
    , f.standard_device_type_id
    , f.user_agent_visibility
    , f.user_country_id
    , f.geo_country_visibility
    , f.global_advertiser_ids
    , f.global_brand_ids
    , f.outbound_exchange_listing_ids
    , 6 as sales_channel
    , f.slot_user_drop_off
    , f.request_traffic_type
    , f.ack_traffic_type
    , f.process_batch_id
    , f.event_date

-- Listing Level Metrics (14)
    , sum(f.outbound_exchange_opportunity)                                              as outbound_exchange_opportunity
    , sum(f.targeted_listings)                                                          as targeted_listings
    , sum(f.effective_listings)                                                         as effective_listings
    , sum(f.candidated_listings)                                                        as candidated_listings
    , sum(f.expanded_listings)                                                          as expanded_listings
    , sum(f.listing_err_total)                                                          as listing_err_total
    , sum(f.listing_err_unknown)                                                        as listing_err_unknown
    , sum(f.listing_err_out_of_schedule)                                                as listing_err_out_of_schedule
    , sum(f.listing_err_split_source_target_not_met)                                    as listing_err_split_source_target_not_met
    , sum(f.listing_err_supply_source_target_not_met)                                   as listing_err_supply_source_target_not_met
    , sum(f.listing_err_programmatic_banned)                                            as listing_err_programmatic_banned
    , sum(f.listing_err_exchange_banned)                                                as listing_err_exchange_banned
    , sum(f.listing_err_met_volume_cap)                                                 as listing_err_met_volume_cap
    , sum(f.listing_err_no_applicable_slots)                                            as listing_err_no_applicable_slots

-- Ad Level Metrics (23)
    , sum(f.ad_err_total)                                                               as ad_err_total
    , sum(f.ad_err_ad_pending_approval)                                                 as ad_err_ad_pending_approval
    , sum(f.ad_err_ad_rejected)                                                         as ad_err_ad_rejected
    , sum(f.ad_err_competition_failure)                                                 as ad_err_competition_failure
    , sum(f.ad_err_listing_advertiser_restriction)                                      as ad_err_listing_advertiser_restriction
    , sum(f.ad_err_listing_brand_restriction)                                           as ad_err_listing_brand_restriction
    , sum(f.ad_err_listing_industry_restriction)                                        as ad_err_listing_industry_restriction
    , sum(f.ad_err_listing_seat_restriction)                                            as ad_err_listing_seat_restriction
    , sum(f.ad_err_listing_creative_duration_restriction)                               as ad_err_listing_creative_duration_restriction
    , sum(f.ad_err_profile_check_failed)                                                as ad_err_profile_check_failed
    , sum(f.ad_err_listing_advertiser_floor_price_not_met)                              as ad_err_listing_advertiser_floor_price_not_met
    , sum(f.ad_err_listing_brand_floor_price_not_met)                                   as ad_err_listing_brand_floor_price_not_met
    , sum(f.ad_err_listing_industry_floor_price_not_met)                                as ad_err_listing_industry_floor_price_not_met
    , sum(f.ad_err_listing_seat_floor_price_not_met)                                    as ad_err_listing_seat_floor_price_not_met
    , sum(f.ad_err_demand_partner_disallowed_by_profile)                                as ad_err_demand_partner_disallowed_by_profile
    , sum(f.ad_err_lat_unsupported)                                                     as ad_err_lat_unsupported
    , sum(f.ad_err_ccpa_gpp_us_privacy_opt_out)                                         as ad_err_ccpa_gpp_us_privacy_opt_out
    , sum(f.ad_err_coppa_unsupported)                                                   as ad_err_coppa_unsupported
    , sum(f.ad_err_apple_app_tracking_transparency_unsupported)                         as ad_err_apple_app_tracking_transparency_unsupported
    , sum(f.ad_err_kv_unsupported)                                                      as ad_err_kv_unsupported
    , sum(f.ad_err_no_tcp_consent)                                                      as ad_err_no_tcp_consent
    , sum(f.ad_err_gpp_not_supported)                                                   as ad_err_gpp_not_supported
    , sum(f.ad_err_gpp_spi_opt_out)                                                     as ad_err_gpp_spi_opt_out

-- Slot Level Metrics (20)
    , sum(f.slot_err_competition_failure)                                               as slot_err_competition_failure
    , sum(f.slot_err_adjacent_ads_exclusivity)                                          as slot_err_adjacent_ads_exclusivity
    , sum(f.slot_err_adjacent_same_4a_id)                                               as slot_err_adjacent_same_4a_id
    , sum(f.slot_err_advertiser_frequency_cap_reaching)                                 as slot_err_advertiser_frequency_cap_reaching
    , sum(f.slot_err_inventory_protection_advertiser)                                   as slot_err_inventory_protection_advertiser
    , sum(f.slot_err_back_to_back_exclusivity)                                          as slot_err_back_to_back_exclusivity
    , sum(f.slot_err_brand_frequency_cap_reaching)                                      as slot_err_brand_frequency_cap_reaching
    , sum(f.slot_err_inventory_protection_brand)                                        as slot_err_inventory_protection_brand
    , sum(f.slot_err_clearcast_restriction)                                             as slot_err_clearcast_restriction
    , sum(f.slot_err_cro_advertiser_frequency_cap_reaching)                             as slot_err_cro_advertiser_frequency_cap_reaching
    , sum(f.slot_err_cro_brand_frequency_cap_reaching)                                  as slot_err_cro_brand_frequency_cap_reaching
    , sum(f.slot_err_max_number_of_ads_exceeded)                                        as slot_err_max_number_of_ads_exceeded
    , sum(f.slot_err_max_slot_duration_exceeded)                                        as slot_err_max_slot_duration_exceeded
    , sum(f.slot_err_slot_exclusivity)                                                  as slot_err_slot_exclusivity
    , sum(f.slot_err_frequency_cap_reaching)                                            as slot_err_frequency_cap_reaching
    , sum(f.slot_err_header_bidding_repeating_key_value_exclusivity)                    as slot_err_header_bidding_repeating_key_value_exclusivity
    , sum(f.slot_err_inventory_protection_industry)                                     as slot_err_inventory_protection_industry
    , sum(f.slot_err_sequency_variat_targeting_failed)                                  as slot_err_sequency_variat_targeting_failed
    , sum(f.slot_err_dsp_bid_cap_reaching)                                              as slot_err_dsp_bid_cap_reaching
    , sum(f.slot_err_excluded_by_pod_ads)                                               as slot_err_excluded_by_pod_ads
    , sum(f.slot_err_other)                                                             as slot_err_other

-- Listing Level Metrics (1)
    , sum(f.listing_err_no_compatible_slots)                                            as listing_err_no_compatible_slots

    , f.supply_source
    , f.content_owner_id
    , f.inbound_order_id
    , f.standard_app_bundle_id
    , f.standard_site_domain_id
    , 'FULL_VISIBILITY' as content_owner_visibility
    , sum(f.listing_err_blocked_by_bidder_private_auction)                              as listing_err_blocked_by_bidder_private_auction
    , sum(f.listing_err_blocked_by_pg_only_ad_request)                                  as listing_err_blocked_by_pg_only_ad_request
    , sum(f.listing_err_restricted_by_pick_one_logic)                                   as listing_err_restricted_by_pick_one_logic
    , sum(f.listing_err_no_available_exchange_buyer)                                    as listing_err_no_available_exchange_buyer
    , sum(f.listing_err_blocked_by_buyer_exclusion)                                     as listing_err_blocked_by_buyer_exclusion
    , sum(f.listing_err_blocked_by_exchange_filter)                                     as listing_err_blocked_by_exchange_filter

    ,f.market_ad_id
    ,f.primary_ad_indicator

-- Programmatic Metrics (7)
   , sum(f.bid_requests)                                                                as bid_requests
   , sum(f.opportunities_in_bid_request)                                                as opportunities_in_bid_request
   , sum(f.received_bids)                                                               as received_bids
   , sum(f.failed_bids)                                                                 as failed_bids
   , sum(f.resolved_bids)                                                               as resolved_bids
   , sum(f.filtered_bids)                                                               as filtered_bids
   , sum(f.selected_bids)                                                               as selected_bids

   , sum(ad_err_creative_not_applicable)                               as ad_err_creative_not_applicable
   , sum(ad_err_deal_floor_price_not_met)                              as ad_err_deal_floor_price_not_met
   , sum(ad_err_empty_deal_id)                                         as ad_err_empty_deal_id
   , sum(ad_err_empty_vast)                                            as ad_err_empty_vast
   , sum(ad_err_invalid_vast_wrapper_url)                              as ad_err_invalid_vast_wrapper_url
   , sum(ad_err_malformed_vast_xml)                                    as ad_err_malformed_vast_xml
   , sum(ad_err_mismatched_seat_id)                                    as ad_err_mismatched_seat_id
   , sum(ad_err_network_item_advertiser_restriction)                   as ad_err_network_item_advertiser_restriction
   , sum(ad_err_network_item_brand_restriction)                        as ad_err_network_item_brand_restriction
   , sum(ad_err_network_item_industry_restriction)                     as ad_err_network_item_industry_restriction
   , sum(ad_err_no_ad_in_vast)                                         as ad_err_no_ad_in_vast
   , sum(ad_err_no_jitt_rendition)                                     as ad_err_no_jitt_rendition
   , sum(ad_err_non_secure_ad)                                         as ad_err_non_secure_ad
   , sum(ad_err_yield_optimization_cap_reached)                        as ad_err_yield_optimization_cap_reached
   , sum(ad_err_exclusivity)                                           as ad_err_exclusivity
   , sum(ad_err_standard_attribute_industry_restriction)               as ad_err_standard_attribute_industry_restriction
   , sum(ad_err_upstream_order_floor_price_not_met)                    as ad_err_upstream_order_floor_price_not_met
   , sum(ad_err_vast_wrapper_http_error)                               as ad_err_vast_wrapper_http_error
   , sum(ad_err_vast_wrapper_timeout)                                  as ad_err_vast_wrapper_timeout
   , sum(ad_err_empty_bid_id)                                          as ad_err_empty_bid_id
   , sum(ad_err_unsupported_vast_version)                              as ad_err_unsupported_vast_version
   , sum(ad_err_empty_vast_ad_markup)                                  as ad_err_empty_vast_ad_markup
   , sum(ad_err_mismatched_deal_id)                                    as ad_err_mismatched_deal_id
   , sum(ad_err_demand_partner_unsupported_on_external_ssp_supply)     as ad_err_demand_partner_unsupported_on_external_ssp_supply
   , sum(ad_err_mismatched_ad_id)                                      as ad_err_mismatched_ad_id
   , sum(ad_err_creative_restriction_failure)                          as ad_err_creative_restriction_failure
   , sum(ad_err_inbound_order_competition_failure)                     as ad_err_inbound_order_competition_failure
   , sum(ad_err_advertiser_domain_restricted)                          as ad_err_advertiser_domain_restricted
   , sum(ad_err_ad_duration_exceeded)                                  as ad_err_ad_duration_exceeded
   , sum(ad_err_creative_duration_mismatched)                          as ad_err_creative_duration_mismatched
   , sum(ad_err_no_slot_selected)                                      as ad_err_no_slot_selected
   , sum(ad_err_unknown)                                               as ad_err_unknown

   , sum(slot_err_profile_check_failed)                                as slot_err_profile_check_failed
   , sum(slot_err_adstor_creative_unavailable)                         as slot_err_adstor_creative_unavailable
   , sum(slot_err_creative_ad_unit_duration_incompatible)              as slot_err_creative_ad_unit_duration_incompatible
   , sum(slot_err_creative_profile_incompatible)                       as slot_err_creative_profile_incompatible
   , sum(slot_err_estimated_duration_disabled_for_live_inventory)      as slot_err_estimated_duration_disabled_for_live_inventory
   , sum(slot_err_adstor_linear_creative_unavailable)                  as slot_err_adstor_linear_creative_unavailable
   , f.standard_channel_id
   , f.standard_channel_visibility
   , f.site_section_id
   , sum(ad_err_yield_optimization_rule_met)                           as ad_err_yield_optimization_rule_met
   , f.process_batch_id as partition_key
from (
-- #0 Listing Level Metrics - Demand Troubleshooting Log
select
    2                                                                                                                                   as process_stage
    , date_format(date_parse(dt, '%Y-%m-%d-%H'), '%Y%m%d%H0000')                                                                        as process_batch_id
    , date_trunc('HOUR',from_unixtime(timestamp))                                                                                       as event_date
    , coalesce(network.network_id, -1)                                                                                                  as network_id
    , 'Included'                                                                                                                        as slot_user_drop_off

    -- Supply (5)
        , case
            when coalesce(network.supply_source_type, 'UNKNOWN') = 'Owned_and_Operated' then 1
            when coalesce(network.supply_source_type, 'UNKNOWN') = 'MRM_Rule' then 3
            when coalesce(network.supply_source_type, 'UNKNOWN') = 'MPP' then 5
            when coalesce(network.supply_source_type, 'UNKNOWN') = 'MPE' then 6
            else -1
        end                                                                                                                                 as supply_source
        , case
            when coalesce(network.supply_source_type, 'UNKNOWN') = 'Owned_and_Operated' then coalesce(network.upstream_network_id, coalesce(network.network_id, -1))
            when coalesce(network.supply_source_type, 'UNKNOWN') = 'MRM_Rule' then -1
            else coalesce(network.upstream_network_id, -1)
        end                                                                                                                                 as content_owner_id
        , coalesce(network.inbound_order.order_id, -1)                                                                                      as inbound_order_id
        , case
            when bitwise_and(request.flags, 64) > 0 then 1
            else 0
        end                                                                                                                                 as request_traffic_type
        , 0                                                                                                                                 as ack_traffic_type
        , coalesce(network.site_section_id, -1)                                                                                             as site_section_id

    -- SA (15)
        , coalesce(element_at(request.stream_mode_ids, 1), -1)                                                                              as stream_mode_id
        , if(network.data_right.standard_brand_visibility.report_aggregate is not null or network.supply_source_type != 'MRM_Rule',
            coalesce(request.standard_brand_id, -1), -1)                                                                                    as standard_brand_id
        , coalesce(network.data_right.standard_brand_visibility.report_aggregate, 'FULL_VISIBILITY')                                        as standard_brand_visibility
        , if(network.data_right.standard_programmer_visibility.report_aggregate is not null or network.supply_source_type != 'MRM_Rule',
            coalesce(request.standard_programmer_id, -1), -1)                                                                               as standard_programmer_id
        , coalesce(network.data_right.standard_programmer_visibility.report_aggregate, 'FULL_VISIBILITY')                                   as standard_programmer_visibility
        , if(network.data_right.standard_endpoint_visibility.report_aggregate is not null or network.supply_source_type != 'MRM_Rule',
            coalesce(request.standard_endpoint_id, -1), -1)                                                                                 as standard_endpoint_id
        , coalesce(network.data_right.standard_endpoint_visibility.report_aggregate, 'FULL_VISIBILITY')                                     as standard_endpoint_visibility
        , if(network.data_right.standard_endpoint_owner_visibility.report_aggregate is not null or network.supply_source_type != 'MRM_Rule',
            coalesce(request.standard_endpoint_owner_id, -1), -1)                                                                           as standard_endpoint_owner_id
        , coalesce(network.data_right.standard_endpoint_owner_visibility.report_aggregate, 'FULL_VISIBILITY')                               as standard_endpoint_owner_visibility
        , if(cardinality(request.standard_device_type_ids)>0, coalesce(element_at(request.standard_device_type_ids, -1), -1), -1)           as standard_device_type_id
        , coalesce(network.data_right.user_agent_visibility.report_aggregate, 'FULL_VISIBILITY')                                            as user_agent_visibility
        , coalesce(request.country_id, -1)                                                                                                  as user_country_id
        , coalesce(network.data_right.geo_country_visibility.report_aggregate, 'FULL_VISIBILITY')                                           as geo_country_visibility
        , coalesce(request.standard_app_bundle_id, -1)                                                                                      as standard_app_bundle_id
        , coalesce(request.standard_site_domain_id, -1)                                                                                     as standard_site_domain_id
        , if(network.data_right.standard_channel_visibility.report_aggregate is not null or network.supply_source_type != 'MRM_Rule',
           coalesce(request.standard_channel_id, -1), -1)                                                                                   as standard_channel_id
        , coalesce(network.data_right.standard_channel_visibility.report_aggregate, 'FULL_VISIBILITY')                                      as standard_channel_visibility

    -- Demand (3)
        , array[]                                                                                                                           as global_advertiser_ids
        , array[]                                                                                                                           as global_brand_ids
        , array[coalesce(t.listing_id, -1)]                                                                                                 as outbound_exchange_listing_ids
        , -1                                                                                                                                as market_ad_id
        , 'Not Applicable'                                                                                                                  as primary_ad_indicator

-- Programmatic Metrics (7)
    , 0                                                                                                   as bid_requests
    , 0                                                                                                   as opportunities_in_bid_request
    , 0                                                                                                   as received_bids
    , 0                                                                                                   as failed_bids
    , 0                                                                                                   as resolved_bids
    , 0                                                                                                   as filtered_bids
    , 0                                                                                                   as selected_bids

-- Listing Level Metrics (15)
    , 0 as outbound_exchange_opportunity
    , sum(if(bitwise_and(coalesce(t.selection_status, 0), 1)>0, coalesce(magnifier, 1), 0))             as targeted_listings
    , sum(if(bitwise_and(coalesce(t.selection_status, 0), 2)>0, coalesce(magnifier, 1), 0))             as effective_listings
    , sum(if(bitwise_and(coalesce(t.selection_status, 0), 4)>0, coalesce(magnifier, 1), 0))             as candidated_listings
    , sum(if(bitwise_and(coalesce(t.selection_status, 0), 8)>0, coalesce(magnifier, 1), 0))             as expanded_listings
    , sum(if(coalesce(t.error, 0)<>0, coalesce(magnifier, 1), 0))                                       as listing_err_total
    , sum(if(coalesce(t.error, 0)=-1, coalesce(magnifier, 1), 0))                                       as listing_err_unknown
    , sum(if(coalesce(t.error, 0)=1601, coalesce(magnifier, 1), 0))                                     as listing_err_out_of_schedule
    , sum(if(coalesce(t.error, 0)=1602, coalesce(magnifier, 1), 0))                                     as listing_err_split_source_target_not_met
    , sum(if(coalesce(t.error, 0)=1603, coalesce(magnifier, 1), 0))                                     as listing_err_supply_source_target_not_met
    , sum(if(coalesce(t.error, 0)=1604, coalesce(magnifier, 1), 0))                                     as listing_err_programmatic_banned
    , sum(if(coalesce(t.error, 0)=1605, coalesce(magnifier, 1), 0))                                     as listing_err_exchange_banned
    , sum(if(coalesce(t.error, 0)=1606, coalesce(magnifier, 1), 0))                                     as listing_err_met_volume_cap
    , sum(if(coalesce(t.error, 0)=1607, coalesce(magnifier, 1), 0))                                     as listing_err_no_applicable_slots
    , sum(if(coalesce(t.error, 0)=1608, coalesce(magnifier, 1), 0))                                     as listing_err_no_compatible_slots
    , sum(if(coalesce(t.error, 0)=1610, coalesce(magnifier, 1), 0))                                     as listing_err_blocked_by_bidder_private_auction
    , sum(if(coalesce(t.error, 0)=1611, coalesce(magnifier, 1), 0))                                     as listing_err_blocked_by_pg_only_ad_request
    , sum(if(coalesce(t.error, 0)=1612, coalesce(magnifier, 1), 0))                                     as listing_err_restricted_by_pick_one_logic
    , sum(if(coalesce(t.error, 0)=1613, coalesce(magnifier, 1), 0))                                     as listing_err_no_available_exchange_buyer
    , sum(if(coalesce(t.error, 0)=1614, coalesce(magnifier, 1), 0))                                     as listing_err_blocked_by_buyer_exclusion
    , sum(if(coalesce(t.error, 0)=1615, coalesce(magnifier, 1), 0))                                     as listing_err_blocked_by_exchange_filter

-- Ad Level Metrics (23)
    , 0 as ad_err_total
    , 0 as ad_err_ad_pending_approval
    , 0 as ad_err_ad_rejected
    , 0 as ad_err_competition_failure
    , 0 as ad_err_listing_advertiser_restriction
    , 0 as ad_err_listing_brand_restriction
    , 0 as ad_err_listing_industry_restriction
    , 0 as ad_err_listing_seat_restriction
    , 0 as ad_err_listing_creative_duration_restriction
    , 0 as ad_err_profile_check_failed
    , 0 as ad_err_listing_advertiser_floor_price_not_met
    , 0 as ad_err_listing_brand_floor_price_not_met
    , 0 as ad_err_listing_industry_floor_price_not_met
    , 0 as ad_err_listing_seat_floor_price_not_met
    , 0 as ad_err_demand_partner_disallowed_by_profile
    , 0 as ad_err_lat_unsupported
    , 0 as ad_err_ccpa_gpp_us_privacy_opt_out
    , 0 as ad_err_coppa_unsupported
    , 0 as ad_err_apple_app_tracking_transparency_unsupported
    , 0 as ad_err_kv_unsupported
    , 0 as ad_err_no_tcp_consent
    , 0 as ad_err_gpp_not_supported
    , 0 as ad_err_gpp_spi_opt_out

    , 0 as ad_err_creative_not_applicable
    , 0 as ad_err_deal_floor_price_not_met
    , 0 as ad_err_empty_deal_id
    , 0 as ad_err_empty_vast
    , 0 as ad_err_invalid_vast_wrapper_url
    , 0 as ad_err_malformed_vast_xml
    , 0 as ad_err_mismatched_seat_id
    , 0 as ad_err_network_item_advertiser_restriction
    , 0 as ad_err_network_item_brand_restriction
    , 0 as ad_err_network_item_industry_restriction
    , 0 as ad_err_no_ad_in_vast
    , 0 as ad_err_no_jitt_rendition
    , 0 as ad_err_non_secure_ad
    , 0 as ad_err_yield_optimization_cap_reached
    , 0 as ad_err_exclusivity
    , 0 as ad_err_standard_attribute_industry_restriction
    , 0 as ad_err_upstream_order_floor_price_not_met
    , 0 as ad_err_vast_wrapper_http_error
    , 0 as ad_err_vast_wrapper_timeout
    , 0 as ad_err_empty_bid_id
    , 0 as ad_err_unsupported_vast_version
    , 0 as ad_err_empty_vast_ad_markup
    , 0 as ad_err_mismatched_deal_id
    , 0 as ad_err_demand_partner_unsupported_on_external_ssp_supply
    , 0 as ad_err_mismatched_ad_id
    , 0 as ad_err_creative_restriction_failure
    , 0 as ad_err_inbound_order_competition_failure
    , 0 as ad_err_advertiser_domain_restricted
    , 0 as ad_err_ad_duration_exceeded
    , 0 as ad_err_creative_duration_mismatched
    , 0 as ad_err_yield_optimization_rule_met
    , 0 as ad_err_no_slot_selected
    , 0 as ad_err_unknown

-- Slot Level Metrics (20)
    , 0 as slot_err_competition_failure
    , 0 as slot_err_adjacent_ads_exclusivity
    , 0 as slot_err_adjacent_same_4a_id
    , 0 as slot_err_advertiser_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_advertiser
    , 0 as slot_err_back_to_back_exclusivity
    , 0 as slot_err_brand_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_brand
    , 0 as slot_err_clearcast_restriction
    , 0 as slot_err_cro_advertiser_frequency_cap_reaching
    , 0 as slot_err_cro_brand_frequency_cap_reaching
    , 0 as slot_err_max_number_of_ads_exceeded
    , 0 as slot_err_max_slot_duration_exceeded
    , 0 as slot_err_slot_exclusivity
    , 0 as slot_err_frequency_cap_reaching
    , 0 as slot_err_header_bidding_repeating_key_value_exclusivity
    , 0 as slot_err_inventory_protection_industry
    , 0 as slot_err_sequency_variat_targeting_failed
    , 0 as slot_err_dsp_bid_cap_reaching
    , 0 as slot_err_excluded_by_pod_ads
    , 0 as slot_err_other

    , 0 as slot_err_profile_check_failed
    , 0 as slot_err_adstor_creative_unavailable
    , 0 as slot_err_creative_ad_unit_duration_incompatible
    , 0 as slot_err_creative_profile_incompatible
    , 0 as slot_err_estimated_duration_disabled_for_live_inventory
    , 0 as slot_err_adstor_linear_creative_unavailable
FROM db.troubleshooting_log.fw_ads_demand_troubleshooting_log
cross join unnest (outbound_exchange_listing_selection_info) as t
-- This table is partitioned on dt, not process_batch_id -- process_batch_id
-- above (line 4) is DERIVED from dt via date_format(date_parse(dt, ...)),
-- so it cannot be filtered on directly here (an output alias is not visible
-- to its own SELECT's WHERE clause). This predicate runs the same
-- date_format/date_parse round trip in reverse: it scopes dt to the same
-- batch hour every other branch filters process_batch_id to, it is just
-- expressed against this table's own partition column instead.
where
    dt = date_format(date_parse('${arena.presto.var.process_batch_id}', '%Y%m%d%H0000'), '%Y-%m-%d-%H')
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33

union all

-- #2 Ad Level Error Metrics - Binary Log (Candidate)
select
        8                                                                               as process_stage
        , process_batch_id                                                              as process_batch_id
        , date_trunc('HOUR', request__timestamp)                                        as event_date
        , coalesce(nw.network_id, -1)                                                   as network_id
        , 'Included'                                                                    as slot_user_drop_off

    -- Supply (5)
        , coalesce(nw.supply_source, -1)                                                as supply_source
        , coalesce(nw.content_owner_network_id, -1)                                     as content_owner_network_id
        , coalesce(nw.inbound_order_id, -1)                                             as inbound_order_id
        , coalesce(request__traffic_type, 0)                                            as request_traffic_type
        , 0                                                                             as ack_traffic_type
        , coalesce(nw.site_section_id, -1)                                              as site_section_id

    -- SA (15)
        , coalesce(request__context__stream_mode_id, -1)                                as stream_mode_id
        , coalesce(request__context__standard_brand_id, -1)                             as standard_brand_id
        , coalesce(nw.brand_visibility, 'FULL_VISIBILITY')                              as standard_brand_visibility
        , coalesce(request__context__standard_programmer_id, -1)                        as standard_programmer_id
        , coalesce(nw.programmer_visibility, 'FULL_VISIBILITY')                         as standard_programmer_visibility
        , coalesce(request__context__standard_endpoint_id, -1)                          as standard_endpoint_id
        , coalesce(nw.endpoint_visibility, 'FULL_VISIBILITY')                           as standard_endpoint_visibility
        , coalesce(request__context__standard_endpoint_owner_id, -1)                    as standard_endpoint_owner_id
        , coalesce(nw.endpoint_owner_visibility, 'FULL_VISIBILITY')                     as standard_endpoint_owner_visibility
        , coalesce(visitor__standard_device_type_child_id, -1)                          as standard_device_type_id
        , coalesce(nw.user_agent_visibility, 'FULL_VISIBILITY')                         as user_agent_visibility
        , coalesce(visitor__country_id, -1)                                             as user_country_id
        , coalesce(nw.country_visibility, 'FULL_VISIBILITY')                            as geo_country_visibility
        , coalesce(request__context__standard_app_bundle_id, -1)                        as standard_app_bundle_id
        , coalesce(request__context__standard_site_domain_id, -1)                       as standard_site_domain_id
        , coalesce(request__context__standard_channel_id, -1)                           as standard_channel_id
        , coalesce(nw.sa_channel_visibility, 'FULL_VISIBILITY')                         as standard_channel_visibility

    -- Demand (3)
        , coalesce(candidate__global_advertiser_ids, ARRAY[])                           as global_advertiser_ids
        , coalesce(candidate__global_brand_ids, ARRAY[])                                as global_brand_ids
        , coalesce(nw.outbound_listing_id, array[])                                     as outbound_exchange_listing_ids
        , coalesce(candidate__market_ad_id, -1)                                         as market_ad_id
        , CASE
            WHEN advertisement__is_fallback IS NULL THEN 'Not Applicable'
            WHEN advertisement__is_fallback = TRUE THEN 'Fallback'
            ELSE 'Primary'
          END                                                                           as primary_ad_indicator

-- Programmatic Metrics (7)
    , 0 as bid_requests
    , 0 as opportunities_in_bid_request
    , SUM(IF(BITWISE_AND(candidate__bid_status, 1)>0, 1, 0))                                                        as received_bids
    , SUM(IF(BITWISE_AND(candidate__bid_status, 1)>0 AND BITWISE_AND(candidate__bid_status, 2)=0, 1, 0))            as failed_bids
    , SUM(IF(BITWISE_AND(candidate__bid_status, 2)>0, 1, 0))                                                        as resolved_bids
    , SUM(IF(BITWISE_AND(candidate__bid_status, 2)>0 AND BITWISE_AND(candidate__bid_status, 8)=0, 1, 0))            as filtered_bids
    , SUM(IF(BITWISE_AND(candidate__bid_status, 8)>0, 1, 0))                                                        as selected_bids

-- Listing Level Metrics (15)
        , 0 as outbound_exchange_opportunity
        , 0 as targeted_listings
        , 0 as effective_listings
        , 0 as candidated_listings
        , 0 as expanded_listings
        , 0 as listing_err_total
        , 0 as listing_err_unknown
        , 0 as listing_err_out_of_schedule
        , 0 as listing_err_split_source_target_not_met
        , 0 as listing_err_supply_source_target_not_met
        , 0 as listing_err_programmatic_banned
        , 0 as listing_err_exchange_banned
        , 0 as listing_err_met_volume_cap
        , 0 as listing_err_no_applicable_slots
        , 0 as listing_err_no_compatible_slots
        , 0 as listing_err_blocked_by_bidder_private_auction
        , 0 as listing_err_blocked_by_pg_only_ad_request
        , 0 as listing_err_restricted_by_pick_one_logic
        , 0 as listing_err_no_available_exchange_buyer
        , 0 as listing_err_blocked_by_buyer_exclusion
        , 0 as listing_err_blocked_by_exchange_filter

-- Ad Level Metrics (23)
    , sum(1)                                                                                                        as ad_err_total
    , sum(if(candidate__error = 'AD_PENDING_APPROVAL', 1, 0))                                                       as ad_err_ad_pending_approval
    , sum(if(candidate__error = 'COMPLIANCE_NOT_APPROVED', 1, 0))                                                   as ad_err_ad_rejected
    , sum(if(candidate__error = 'COMPETITION_FAILURE', 1, 0))                                                       as ad_err_competition_failure
    , sum(if(candidate__error = 'GLOBAL_ADVERTISER_RESTRICTED_BY_LISTING', 1, 0))                                   as ad_err_listing_advertiser_restriction
    , sum(if(candidate__error = 'GLOBAL_BRAND_RESTRICTED_BY_LISTING', 1, 0))                                        as ad_err_listing_brand_restriction
    , sum(if(candidate__error = 'INDUSTRY_RESTRICTED_BY_LISTING', 1, 0))                                            as ad_err_listing_industry_restriction
    , sum(if(candidate__error = 'RESTRICTED_SEAT_BY_MKPL_EXCHANGE', 1, 0))                                          as ad_err_listing_seat_restriction
    , sum(if(candidate__error = 'LISTING_CREATIVE_DURATION_CHECK', 1, 0))                                           as ad_err_listing_creative_duration_restriction
    , sum(if(candidate__error in ('EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED', 'PROFILE_CHECK_FAILED'), 1, 0))         as ad_err_profile_check_failed
    , sum(if(candidate__error = 'MKPL_EXCHANGE_ADVERTISER_FLOOR_PRICE_NOT_MET', 1, 0))                              as ad_err_listing_advertiser_floor_price_not_met
    , sum(if(candidate__error = 'MKPL_EXCHANGE_BRAND_FLOOR_PRICE_NOT_MET', 1, 0))                                   as ad_err_listing_brand_floor_price_not_met
    , sum(if(candidate__error = 'MKPL_EXCHANGE_INDUSTRY_FLOOR_PRICE_NOT_MET', 1, 0))                                as ad_err_listing_industry_floor_price_not_met
    , sum(if(candidate__error = 'MKPL_EXCHANGE_SEAT_FLOOR_PRICE_NOT_MET', 1, 0))                                    as ad_err_listing_seat_floor_price_not_met
    , sum(if(candidate__error = 'DSP_BLOCKED_BY_PROFILE', 1, 0))                                                    as ad_err_demand_partner_disallowed_by_profile
    , sum(if(candidate__error = 'LAT_UNSUPPORTED', 1, 0))                                                           as ad_err_lat_unsupported
    , sum(if(candidate__error = 'US_PRIVACY_UNSUPPORTED', 1, 0))                                                    as ad_err_ccpa_gpp_us_privacy_opt_out
    , sum(if(candidate__error = 'COPPA_UNSUPPORTED', 1, 0))                                                         as ad_err_coppa_unsupported
    , sum(if(candidate__error = 'ATTS_UNSUPPORTED', 1, 0))                                                          as ad_err_apple_app_tracking_transparency_unsupported
    , sum(if(candidate__error = 'KV_OPT_OUT', 1, 0))                                                                as ad_err_kv_unsupported
    , sum(if(candidate__error = 'GDPR_UNSUPPORTED', 1, 0))                                                          as ad_err_no_tcp_consent
    , sum(if(candidate__error = 'GPP_UNSUPPORTED', 1, 0))                                                           as ad_err_gpp_not_supported
    , sum(if(candidate__error = 'GPP_SPI_UNSUPPORTED', 1, 0))                                                       as ad_err_gpp_spi_opt_out

    , sum(if(candidate__error = 'NO_APPLICABLE_CREATIVE', 1, 0))                                                    as ad_err_creative_not_applicable
    , sum(if(candidate__error = 'FLOOR_PRICE_NOTMET', 1, 0))                                                        as ad_err_deal_floor_price_not_met
    , sum(if(candidate__error = 'EMPTY_BID_DEALID', 1, 0))                                                          as ad_err_empty_deal_id
    , sum(if(candidate__error = 'EMPTY_RESPONSE', 1, 0))                                                            as ad_err_empty_vast
    , sum(if(candidate__error = 'INVALID_WRAPPER_URL', 1, 0))                                                       as ad_err_invalid_vast_wrapper_url
    , sum(if(candidate__error = 'MALFORMED_RESPONSE', 1, 0))                                                        as ad_err_malformed_vast_xml
    , sum(if(candidate__error = 'UNKNOWN_SEAT', 1, 0))                                                              as ad_err_mismatched_seat_id
    , sum(if(candidate__error = 'GLOBAL_ADVERTISER_RESTRICTED_BY_INVENTORY', 1, 0))                                 as ad_err_network_item_advertiser_restriction
    , sum(if(candidate__error = 'GLOBAL_BRAND_RESTRICTED_BY_INVENTORY', 1, 0))                                      as ad_err_network_item_brand_restriction
    , sum(if(candidate__error = 'COMPLIANCE_CHECK_FAILED', 1, 0))                                                   as ad_err_network_item_industry_restriction
    , sum(if(candidate__error = 'NO_VALID_CREATIVE', 1, 0))                                                         as ad_err_no_ad_in_vast
    , sum(if(candidate__error = 'JITT_RENDITION_REQUIRED', 1, 0))                                                   as ad_err_no_jitt_rendition
    , sum(if(candidate__error = 'INAPPLICABLE_FOR_HTTPS', 1, 0))                                                    as ad_err_non_secure_ad
    , sum(if(candidate__error = 'MET_YIELD_OPT_CAP', 1, 0))                                                         as ad_err_yield_optimization_cap_reached
    , sum(if(candidate__error = 'EXCLUSIVITY_BY_STREAM', 1, 0))                                                     as ad_err_exclusivity
    , sum(if(candidate__error = 'INDUSTRY_RESTRICTED_BY_SA', 1, 0))                                                 as ad_err_standard_attribute_industry_restriction
    , sum(if(candidate__error = 'MKPL_ORDER_FLOOR_PRICE_NOT_MET', 1, 0))                                            as ad_err_upstream_order_floor_price_not_met
    , sum(if(candidate__error = 'WRAPPER_HTTP_ERROR', 1, 0))                                                        as ad_err_vast_wrapper_http_error
    , sum(if(candidate__error = 'WRAPPER_TIMEOUT', 1, 0))                                                           as ad_err_vast_wrapper_timeout
    , sum(if(candidate__error = 'EMPTY_BID_ID', 1, 0))                                                              as ad_err_empty_bid_id
    , sum(if(candidate__error = 'UNSUPPORTED_VAST_VERSION', 1, 0))                                                  as ad_err_unsupported_vast_version
    , sum(if(candidate__error = 'NO_AD_MARKUP', 1, 0))                                                              as ad_err_empty_vast_ad_markup
    , sum(if(candidate__error = 'UNEXPECTED_BID_DEALID', 1, 0))                                                     as ad_err_mismatched_deal_id
    , sum(if(candidate__error = 'TWO_PHASE_TRANSLATION_UNSUPPORTED', 1, 0))                                         as ad_err_demand_partner_unsupported_on_external_ssp_supply
    , sum(if(candidate__error = 'UNEXPECTED_EXTERNAL_AD_ID', 1, 0))                                                 as ad_err_mismatched_ad_id
    , sum(if(candidate__error = 'CREATIVE_RESTRICTION_CHECK_FAILED', 1, 0))                                         as ad_err_creative_restriction_failure
    , sum(if(candidate__error = 'INBOUND_ORDER_COMPETITION_FAILURE', 1, 0))                                         as ad_err_inbound_order_competition_failure
    , sum(if(candidate__error = 'GLOBAL_ADVERTISER_RESTRICTED_BY_DOMAIN', 1, 0))                                    as ad_err_advertiser_domain_restricted
    , sum(if(candidate__error = 'AUCTION_MAX_AD_DURATION_EXCEEDED', 1, 0))                                          as ad_err_ad_duration_exceeded
    , sum(if(candidate__error = 'MISMATCHED_CREATIVE_DURATION_WITH_SCHEDULED', 1, 0))                               as ad_err_creative_duration_mismatched
    , sum(IF(candidate__error = 'YIELD_OPT_MET', 1, 0))                                                             as ad_err_yield_optimization_rule_met
    , sum(IF(candidate__error = 'NO_SLOT_SELECTED', 1, 0))                                                          as ad_err_no_slot_selected --others
    , sum(IF(BITWISE_AND(candidate__bid_status,8)=0 AND COALESCE(candidate__error, '') = '', 1, 0))                 as ad_err_unknown --others

-- Slot Level Metrics (20)
    , 0 as slot_err_competition_failure
    , 0 as slot_err_adjacent_ads_exclusivity
    , 0 as slot_err_adjacent_same_4a_id
    , 0 as slot_err_advertiser_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_advertiser
    , 0 as slot_err_back_to_back_exclusivity
    , 0 as slot_err_brand_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_brand
    , 0 as slot_err_clearcast_restriction
    , 0 as slot_err_cro_advertiser_frequency_cap_reaching
    , 0 as slot_err_cro_brand_frequency_cap_reaching
    , 0 as slot_err_max_number_of_ads_exceeded
    , 0 as slot_err_max_slot_duration_exceeded
    , 0 as slot_err_slot_exclusivity
    , 0 as slot_err_frequency_cap_reaching
    , 0 as slot_err_header_bidding_repeating_key_value_exclusivity
    , 0 as slot_err_inventory_protection_industry
    , 0 as slot_err_sequency_variat_targeting_failed
    , 0 as slot_err_dsp_bid_cap_reaching
    , 0 as slot_err_excluded_by_pod_ads
    , 0 as slot_err_other

    , 0 as slot_err_profile_check_failed
    , 0 as slot_err_adstor_creative_unavailable
    , 0 as slot_err_creative_ad_unit_duration_incompatible
    , 0 as slot_err_creative_profile_incompatible
    , 0 as slot_err_estimated_duration_disabled_for_live_inventory
    , 0 as slot_err_adstor_linear_creative_unavailable
FROM ${facts}.candidate
cross join unnest(
    partners__network_id,
    partners__network_is_extra_item_owner,
    partners__supply_source,
    partners__sales_channel,
    partners__entity_source,
    partners__role,
    partners__content_owner_network_id,
    partners__inbound_order_id,
    partners__site_section_id,
    partners__outbound_listing_id,
    partners__geo_country_visibility__report_aggregate,
    partners__user_agent_visibility__report_aggregate,
    partners__standard_endpoint_owner_visibility__report_aggregate,
    partners__standard_endpoint_visibility__report_aggregate,
    partners__standard_programmer_visibility__report_aggregate,
    partners__standard_brand_visibility__report_aggregate,
    partners__standard_channel_visibility__report_aggregate)
nw (
  network_id,
  extra_item_owner,
  supply_source,
  sales_channel,
  entity_source,
  role,
  content_owner_network_id,
  inbound_order_id,
  site_section_id,
  outbound_listing_id,
  country_visibility,
  user_agent_visibility,
  endpoint_owner_visibility,
  endpoint_visibility,
  programmer_visibility,
  brand_visibility,
  sa_channel_visibility)
where process_batch_id = '${arena.presto.var.process_batch_id}'
  and nw.entity_source = 'auction_upstream'
  and nw.sales_channel = 6
  and (BITWISE_AND(candidate__flags, 131072)>0 OR BITWISE_AND(candidate__bid_status, 1)>0) -- PRE_BID_FILTERED OR RECEIVED_BID
  and coalesce(request__demand_log_magnifier, 0) > 0  -- Sampled by Demand Log
  --and coalesce(candidate__error, '') in ('AD_PENDING_APPROVAL','COMPLIANCE_NOT_APPROVED','COMPETITION_FAILURE','GLOBAL_ADVERTISER_RESTRICTED_BY_LISTING','GLOBAL_BRAND_RESTRICTED_BY_LISTING','INDUSTRY_RESTRICTED_BY_LISTING','RESTRICTED_SEAT_BY_MKPL_EXCHANGE','LISTING_CREATIVE_DURATION_CHECK','EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED','PROFILE_CHECK_FAILED','MKPL_EXCHANGE_ADVERTISER_FLOOR_PRICE_NOT_MET','MKPL_EXCHANGE_BRAND_FLOOR_PRICE_NOT_MET','MKPL_EXCHANGE_INDUSTRY_FLOOR_PRICE_NOT_MET','MKPL_EXCHANGE_SEAT_FLOOR_PRICE_NOT_MET','DSP_BLOCKED_BY_PROFILE', 'LAT_UNSUPPORTED', 'US_PRIVACY_UNSUPPORTED', 'COPPA_UNSUPPORTED', 'ATTS_UNSUPPORTED', 'KV_OPT_OUT', 'GDPR_UNSUPPORTED', 'GPP_UNSUPPORTED', 'GPP_SPI_UNSUPPORTED')
  and ${sampling_filter} --sampling filter
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33

union all

-- #3 Ad Level Error Metrics - Binary Log (Auction)
select
        4                                                                               as process_stage
        , process_batch_id                                                              as process_batch_id
        , date_trunc('HOUR', request__timestamp)                                        as event_date
        , coalesce(nw.network_id, -1)                                                   as network_id
        , 'Included'                                                                    as slot_user_drop_off

    -- Supply (5)
        , coalesce(nw.supply_source, -1)                                                as supply_source
        , coalesce(nw.content_owner_network_id, -1)                                     as content_owner_network_id
        , coalesce(nw.inbound_order_id, -1)                                             as inbound_order_id
        , coalesce(request__traffic_type, 0)                                            as request_traffic_type
        , 0                                                                             as ack_traffic_type
        , coalesce(nw.site_section_id, -1)                                              as site_section_id

    -- SA (15)
        , coalesce(request__context__stream_mode_id, -1)                                as stream_mode_id
        , coalesce(request__context__standard_brand_id, -1)                             as standard_brand_id
        , coalesce(nw.brand_visibility, 'FULL_VISIBILITY')                              as standard_brand_visibility
        , coalesce(request__context__standard_programmer_id, -1)                        as standard_programmer_id
        , coalesce(nw.programmer_visibility, 'FULL_VISIBILITY')                         as standard_programmer_visibility
        , coalesce(request__context__standard_endpoint_id, -1)                          as standard_endpoint_id
        , coalesce(nw.endpoint_visibility, 'FULL_VISIBILITY')                           as standard_endpoint_visibility
        , coalesce(request__context__standard_endpoint_owner_id, -1)                    as standard_endpoint_owner_id
        , coalesce(nw.endpoint_owner_visibility, 'FULL_VISIBILITY')                     as standard_endpoint_owner_visibility
        , coalesce(visitor__standard_device_type_child_id, -1)                          as standard_device_type_id
        , coalesce(nw.user_agent_visibility, 'FULL_VISIBILITY')                         as user_agent_visibility
        , coalesce(visitor__country_id, -1)                                             as user_country_id
        , coalesce(nw.country_visibility, 'FULL_VISIBILITY')                            as geo_country_visibility
        , coalesce(request__context__standard_app_bundle_id, -1)                        as standard_app_bundle_id
        , coalesce(request__context__standard_site_domain_id, -1)                       as standard_site_domain_id
        , coalesce(request__context__standard_channel_id, -1)                           as standard_channel_id
        , coalesce(nw.sa_channel_visibility, 'FULL_VISIBILITY')                         as standard_channel_visibility

    -- Demand (3)
        , array[] as global_advertiser_ids
        , array[] as global_brand_ids
        , coalesce(nw.outbound_listing_id, array[])                                     as outbound_exchange_listing_ids
        , -1                                                                            as market_ad_id
        , 'Not Applicable'                                                              as primary_ad_indicator


-- Programmatic Metrics (7)
    , SUM(IF(BITWISE_AND(auction__auction_status, 2)>0, 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1))                        as bid_requests
    , SUM(IF(BITWISE_AND(auction__auction_status, 2)>0, imp.imp_opp, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1))                        as opportunities_in_bid_request
    , 0 as received_bids
    , 0 as failed_bids
    , 0 as resolved_bids
    , 0 as filtered_bids
    , 0 as selected_bids

-- Listing Level Metrics (15)
        , 0 as outbound_exchange_opportunity
        , 0 as targeted_listings
        , 0 as effective_listings
        , 0 as candidated_listings
        , 0 as expanded_listings
        , 0 as listing_err_total
        , 0 as listing_err_unknown
        , 0 as listing_err_out_of_schedule
        , 0 as listing_err_split_source_target_not_met
        , 0 as listing_err_supply_source_target_not_met
        , 0 as listing_err_programmatic_banned
        , 0 as listing_err_exchange_banned
        , 0 as listing_err_met_volume_cap
        , 0 as listing_err_no_applicable_slots
        , 0 as listing_err_no_compatible_slots
        , 0 as listing_err_blocked_by_bidder_private_auction
        , 0 as listing_err_blocked_by_pg_only_ad_request
        , 0 as listing_err_restricted_by_pick_one_logic
        , 0 as listing_err_no_available_exchange_buyer
        , 0 as listing_err_blocked_by_buyer_exclusion
        , 0 as listing_err_blocked_by_exchange_filter

-- Ad Level Metrics (23)
        , sum(1)                                                                                                        as ad_err_total
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'AD_PENDING_APPROVAL', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                       as ad_err_ad_pending_approval
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'COMPLIANCE_NOT_APPROVED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                   as ad_err_ad_rejected
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'COMPETITION_FAILURE', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                       as ad_err_competition_failure
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'GLOBAL_ADVERTISER_RESTRICTED_BY_LISTING', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                   as ad_err_listing_advertiser_restriction
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'GLOBAL_BRAND_RESTRICTED_BY_LISTING', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                        as ad_err_listing_brand_restriction
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'INDUSTRY_RESTRICTED_BY_LISTING', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                            as ad_err_listing_industry_restriction
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'RESTRICTED_SEAT_BY_MKPL_EXCHANGE', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                          as ad_err_listing_seat_restriction
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'LISTING_CREATIVE_DURATION_CHECK', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                           as ad_err_listing_creative_duration_restriction
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error in ('EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED', 'PROFILE_CHECK_FAILED'), 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))         as ad_err_profile_check_failed
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'MKPL_EXCHANGE_ADVERTISER_FLOOR_PRICE_NOT_MET', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                              as ad_err_listing_advertiser_floor_price_not_met
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'MKPL_EXCHANGE_BRAND_FLOOR_PRICE_NOT_MET', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                   as ad_err_listing_brand_floor_price_not_met
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'MKPL_EXCHANGE_INDUSTRY_FLOOR_PRICE_NOT_MET', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                as ad_err_listing_industry_floor_price_not_met
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'MKPL_EXCHANGE_SEAT_FLOOR_PRICE_NOT_MET', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                    as ad_err_listing_seat_floor_price_not_met
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'DSP_BLOCKED_BY_PROFILE', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                    as ad_err_demand_partner_disallowed_by_profile
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'LAT_UNSUPPORTED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                           as ad_err_lat_unsupported
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'US_PRIVACY_UNSUPPORTED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                    as ad_err_ccpa_gpp_us_privacy_opt_out
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'COPPA_UNSUPPORTED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                         as ad_err_coppa_unsupported
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'ATTS_UNSUPPORTED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                          as ad_err_apple_app_tracking_transparency_unsupported
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'KV_OPT_OUT', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                                as ad_err_kv_unsupported
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'GDPR_UNSUPPORTED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                          as ad_err_no_tcp_consent
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'GPP_UNSUPPORTED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                           as ad_err_gpp_not_supported
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'GPP_SPI_UNSUPPORTED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                       as ad_err_gpp_spi_opt_out


        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'NO_APPLICABLE_CREATIVE', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                    as ad_err_creative_not_applicable
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'FLOOR_PRICE_NOTMET', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                        as ad_err_deal_floor_price_not_met
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'EMPTY_BID_DEALID', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                          as ad_err_empty_deal_id
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'EMPTY_RESPONSE', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                            as ad_err_empty_vast
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'INVALID_WRAPPER_URL', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                       as ad_err_invalid_vast_wrapper_url
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'MALFORMED_RESPONSE', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                        as ad_err_malformed_vast_xml
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'UNKNOWN_SEAT', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                              as ad_err_mismatched_seat_id
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'GLOBAL_ADVERTISER_RESTRICTED_BY_INVENTORY', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                 as ad_err_network_item_advertiser_restriction
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'GLOBAL_BRAND_RESTRICTED_BY_INVENTORY', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                      as ad_err_network_item_brand_restriction
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'COMPLIANCE_CHECK_FAILED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                   as ad_err_network_item_industry_restriction
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'NO_VALID_CREATIVE', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                         as ad_err_no_ad_in_vast
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'JITT_RENDITION_REQUIRED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                   as ad_err_no_jitt_rendition
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'INAPPLICABLE_FOR_HTTPS', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                    as ad_err_non_secure_ad
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'MET_YIELD_OPT_CAP', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                         as ad_err_yield_optimization_cap_reached
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'EXCLUSIVITY_BY_STREAM', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                     as ad_err_exclusivity
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'INDUSTRY_RESTRICTED_BY_SA', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                 as ad_err_standard_attribute_industry_restriction
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'MKPL_ORDER_FLOOR_PRICE_NOT_MET', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                            as ad_err_upstream_order_floor_price_not_met
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'WRAPPER_HTTP_ERROR', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                        as ad_err_vast_wrapper_http_error
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'WRAPPER_TIMEOUT', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                           as ad_err_vast_wrapper_timeout
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'EMPTY_BID_ID', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                              as ad_err_empty_bid_id
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'UNSUPPORTED_VAST_VERSION', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                  as ad_err_unsupported_vast_version
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'NO_AD_MARKUP', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                              as ad_err_empty_vast_ad_markup
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'UNEXPECTED_BID_DEALID', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                     as ad_err_mismatched_deal_id
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'TWO_PHASE_TRANSLATION_UNSUPPORTED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                         as ad_err_demand_partner_unsupported_on_external_ssp_supply
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'UNEXPECTED_EXTERNAL_AD_ID', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                 as ad_err_mismatched_ad_id
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'CREATIVE_RESTRICTION_CHECK_FAILED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                         as ad_err_creative_restriction_failure
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'INBOUND_ORDER_COMPETITION_FAILURE', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                         as ad_err_inbound_order_competition_failure
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'GLOBAL_ADVERTISER_RESTRICTED_BY_DOMAIN', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                    as ad_err_advertiser_domain_restricted
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'AUCTION_MAX_AD_DURATION_EXCEEDED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                          as ad_err_ad_duration_exceeded
        , sum(if(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'MISMATCHED_CREATIVE_DURATION_WITH_SCHEDULED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                               as ad_err_creative_duration_mismatched
        , SUM(IF(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'YIELD_OPT_MET', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                     as ad_err_yield_optimization_rule_met
        , SUM(IF(bitwise_and(auction__auction_status, 1) > 0 and auction__error = 'NO_SLOT_SELECTED', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                     as ad_err_no_slot_selected
        , SUM(IF(BITWISE_AND(auction__auction_status,8)=0 AND COALESCE(auction__error, '') = '', 1, 0)
                * coalesce(request__multiplier, 1)
                * coalesce(request__magnifier, 1)
                * coalesce(auction__auction_sampling__magnifier, 1)
                * coalesce(request__log_sampling__magnifier, 1)
                * coalesce(auction__invite_deal_size, 1))                                                     as ad_err_unknown

-- Slot Level Metrics (20)
    , 0 as slot_err_competition_failure
    , 0 as slot_err_adjacent_ads_exclusivity
    , 0 as slot_err_adjacent_same_4a_id
    , 0 as slot_err_advertiser_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_advertiser
    , 0 as slot_err_back_to_back_exclusivity
    , 0 as slot_err_brand_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_brand
    , 0 as slot_err_clearcast_restriction
    , 0 as slot_err_cro_advertiser_frequency_cap_reaching
    , 0 as slot_err_cro_brand_frequency_cap_reaching
    , 0 as slot_err_max_number_of_ads_exceeded
    , 0 as slot_err_max_slot_duration_exceeded
    , 0 as slot_err_slot_exclusivity
    , 0 as slot_err_frequency_cap_reaching
    , 0 as slot_err_header_bidding_repeating_key_value_exclusivity
    , 0 as slot_err_inventory_protection_industry
    , 0 as slot_err_sequency_variat_targeting_failed
    , 0 as slot_err_dsp_bid_cap_reaching
    , 0 as slot_err_excluded_by_pod_ads
    , 0 as slot_err_other

    , 0 as slot_err_profile_check_failed
    , 0 as slot_err_adstor_creative_unavailable
    , 0 as slot_err_creative_ad_unit_duration_incompatible
    , 0 as slot_err_creative_profile_incompatible
    , 0 as slot_err_estimated_duration_disabled_for_live_inventory
    , 0 as slot_err_adstor_linear_creative_unavailable
FROM ${facts}.auction
CROSS JOIN UNNEST(
    auction__impression__index,
    auction__impression__equivalent_opportunity_number
)
imp (
    imp_index,
    imp_opp
)
cross join unnest(
    partners__network_id,
    partners__network_is_extra_item_owner,
    partners__supply_source,
    partners__content_owner_network_id,
    partners__inbound_order_id,
    partners__site_section_id,
    partners__sales_channel,
    partners__entity_source,
    partners__role,
    partners__outbound_listing_id,
    partners__geo_country_visibility__report_aggregate,
    partners__user_agent_visibility__report_aggregate,
    partners__standard_endpoint_owner_visibility__report_aggregate,
    partners__standard_endpoint_visibility__report_aggregate,
    partners__standard_programmer_visibility__report_aggregate,
    partners__standard_brand_visibility__report_aggregate,
    partners__standard_channel_visibility__report_aggregate)
nw (
  network_id,
  extra_item_owner,
  supply_source,
  content_owner_network_id,
  inbound_order_id,
  site_section_id,
  sales_channel,
  entity_source,
  role,
  outbound_listing_id,
  country_visibility,
  user_agent_visibility,
  endpoint_owner_visibility,
  endpoint_visibility,
  programmer_visibility,
  brand_visibility,
  sa_channel_visibility)
where process_batch_id = '${arena.presto.var.process_batch_id}'
  and auction__is_faked_auction = false
  and nw.entity_source = 'auction_upstream'
  and auction__integration_type IN ('NORMAL', 'PG_TD')
  and nw.sales_channel = 6
  --and bitwise_and(auction__auction_status, 1) > 0     -- Pre-filtered stage
  and coalesce(request__demand_log_magnifier, 0) > 0  -- Sampled by Demand Log
  and ${sampling_filter} --sampling filter
  --and coalesce(auction__error, '') in ('AD_PENDING_APPROVAL','COMPLIANCE_NOT_APPROVED','COMPETITION_FAILURE','GLOBAL_ADVERTISER_RESTRICTED_BY_LISTING','GLOBAL_BRAND_RESTRICTED_BY_LISTING','INDUSTRY_RESTRICTED_BY_LISTING','RESTRICTED_SEAT_BY_MKPL_EXCHANGE','LISTING_CREATIVE_DURATION_CHECK','EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED','PROFILE_CHECK_FAILED','MKPL_EXCHANGE_ADVERTISER_FLOOR_PRICE_NOT_MET','MKPL_EXCHANGE_BRAND_FLOOR_PRICE_NOT_MET','MKPL_EXCHANGE_INDUSTRY_FLOOR_PRICE_NOT_MET','MKPL_EXCHANGE_SEAT_FLOOR_PRICE_NOT_MET','DSP_BLOCKED_BY_PROFILE', 'LAT_UNSUPPORTED', 'US_PRIVACY_UNSUPPORTED', 'COPPA_UNSUPPORTED', 'ATTS_UNSUPPORTED', 'KV_OPT_OUT', 'GDPR_UNSUPPORTED', 'GPP_UNSUPPORTED', 'GPP_SPI_UNSUPPORTED')
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33

union all

-- #4 Slot Level Error Metrics - Binary Log (Programmatic + Partner Tag)
select
        16                                                                              as process_stage
        , process_batch_id                                                              as process_batch_id
        , date_trunc('HOUR', request__timestamp)                                        as event_date
        , coalesce(nw.network_id, -1)                                                   as network_id
        , 'Included'                                                                    as slot_user_drop_off

    -- Supply (5)
        , coalesce(nw.supply_source, -1)                                                as supply_source
        , coalesce(nw.content_owner_network_id, -1)                                     as content_owner_network_id
        , coalesce(nw.inbound_order_id, -1)                                             as inbound_order_id
        , coalesce(request__traffic_type, 0)                                            as request_traffic_type
        , 0                                                                             as ack_traffic_type
        , coalesce(nw.site_section_id, -1)                                              as site_section_id

    -- SA (15)
        , coalesce(request__context__stream_mode_id, -1)                                as stream_mode_id
        , coalesce(request__context__standard_brand_id, -1)                             as standard_brand_id
        , coalesce(nw.brand_visibility, 'FULL_VISIBILITY')                              as standard_brand_visibility
        , coalesce(request__context__standard_programmer_id, -1)                        as standard_programmer_id
        , coalesce(nw.programmer_visibility, 'FULL_VISIBILITY')                         as standard_programmer_visibility
        , coalesce(request__context__standard_endpoint_id, -1)                          as standard_endpoint_id
        , coalesce(nw.endpoint_visibility, 'FULL_VISIBILITY')                           as standard_endpoint_visibility
        , coalesce(request__context__standard_endpoint_owner_id, -1)                    as standard_endpoint_owner_id
        , coalesce(nw.endpoint_owner_visibility, 'FULL_VISIBILITY')                     as standard_endpoint_owner_visibility
        , coalesce(visitor__standard_device_type_child_id, -1)                          as standard_device_type_id
        , coalesce(nw.user_agent_visibility, 'FULL_VISIBILITY')                         as user_agent_visibility
        , coalesce(visitor__country_id, -1)                                             as user_country_id
        , coalesce(nw.country_visibility, 'FULL_VISIBILITY')                            as geo_country_visibility
        , coalesce(request__context__standard_app_bundle_id, -1)                        as standard_app_bundle_id
        , coalesce(request__context__standard_site_domain_id, -1)                       as standard_site_domain_id
        , coalesce(request__context__standard_channel_id, -1)                           as standard_channel_id
        , coalesce(nw.sa_channel_visibility, 'FULL_VISIBILITY')                         as standard_channel_visibility

    -- Demand (3)
        , coalesce(candidate__global_advertiser_ids, ARRAY[])                           as global_advertiser_ids
        , coalesce(candidate__global_brand_ids, ARRAY[])                                as global_brand_ids
        , coalesce(nw.outbound_listing_id, array[])                                     as outbound_exchange_listing_ids
        , coalesce(candidate__market_ad_id, -1)                                         as market_ad_id
        , CASE
            WHEN advertisement__is_fallback IS NULL THEN 'Not Applicable'
            WHEN advertisement__is_fallback = TRUE THEN 'Fallback'
            ELSE 'Primary'
          END                                                                           as primary_ad_indicator

-- Programmatic Metrics (7)
    , 0 as bid_requests
    , 0 as opportunities_in_bid_request
    , 0 as received_bids
    , 0 as failed_bids
    , 0 as resolved_bids
    , 0 as filtered_bids
    , 0 as selected_bids

-- Listing Level Metrics (15)
        , 0 as outbound_exchange_opportunity
        , 0 as targeted_listings
        , 0 as effective_listings
        , 0 as candidated_listings
        , 0 as expanded_listings
        , 0 as listing_err_total
        , 0 as listing_err_unknown
        , 0 as listing_err_out_of_schedule
        , 0 as listing_err_split_source_target_not_met
        , 0 as listing_err_supply_source_target_not_met
        , 0 as listing_err_programmatic_banned
        , 0 as listing_err_exchange_banned
        , 0 as listing_err_met_volume_cap
        , 0 as listing_err_no_applicable_slots
        , 0 as listing_err_no_compatible_slots
        , 0 as listing_err_blocked_by_bidder_private_auction
        , 0 as listing_err_blocked_by_pg_only_ad_request
        , 0 as listing_err_restricted_by_pick_one_logic
        , 0 as listing_err_no_available_exchange_buyer
        , 0 as listing_err_blocked_by_buyer_exclusion
        , 0 as listing_err_blocked_by_exchange_filter

-- Ad Level Metrics (23)
        , 0 as ad_err_total
        , 0 as ad_err_ad_pending_approval
        , 0 as ad_err_ad_rejected
        , 0 as ad_err_competition_failure
        , 0 as ad_err_listing_advertiser_restriction
        , 0 as ad_err_listing_brand_restriction
        , 0 as ad_err_listing_industry_restriction
        , 0 as ad_err_listing_seat_restriction
        , 0 as ad_err_listing_creative_duration_restriction
        , 0 as ad_err_profile_check_failed
        , 0 as ad_err_listing_advertiser_floor_price_not_met
        , 0 as ad_err_listing_brand_floor_price_not_met
        , 0 as ad_err_listing_industry_floor_price_not_met
        , 0 as ad_err_listing_seat_floor_price_not_met
        , 0 as ad_err_demand_partner_disallowed_by_profile
        , 0 as ad_err_lat_unsupported
        , 0 as ad_err_ccpa_gpp_us_privacy_opt_out
        , 0 as ad_err_coppa_unsupported
        , 0 as ad_err_apple_app_tracking_transparency_unsupported
        , 0 as ad_err_kv_unsupported
        , 0 as ad_err_no_tcp_consent
        , 0 as ad_err_gpp_not_supported
        , 0 as ad_err_gpp_spi_opt_out

        , 0 as ad_err_creative_not_applicable
        , 0 as ad_err_deal_floor_price_not_met
        , 0 as ad_err_empty_deal_id
        , 0 as ad_err_empty_vast
        , 0 as ad_err_invalid_vast_wrapper_url
        , 0 as ad_err_malformed_vast_xml
        , 0 as ad_err_mismatched_seat_id
        , 0 as ad_err_network_item_advertiser_restriction
        , 0 as ad_err_network_item_brand_restriction
        , 0 as ad_err_network_item_industry_restriction
        , 0 as ad_err_no_ad_in_vast
        , 0 as ad_err_no_jitt_rendition
        , 0 as ad_err_non_secure_ad
        , 0 as ad_err_yield_optimization_cap_reached
        , 0 as ad_err_exclusivity
        , 0 as ad_err_standard_attribute_industry_restriction
        , 0 as ad_err_upstream_order_floor_price_not_met
        , 0 as ad_err_vast_wrapper_http_error
        , 0 as ad_err_vast_wrapper_timeout
        , 0 as ad_err_empty_bid_id
        , 0 as ad_err_unsupported_vast_version
        , 0 as ad_err_empty_vast_ad_markup
        , 0 as ad_err_mismatched_deal_id
        , 0 as ad_err_demand_partner_unsupported_on_external_ssp_supply
        , 0 as ad_err_mismatched_ad_id
        , 0 as ad_err_creative_restriction_failure
        , 0 as ad_err_inbound_order_competition_failure
        , 0 as ad_err_advertiser_domain_restricted
        , 0 as ad_err_ad_duration_exceeded
        , 0 as ad_err_creative_duration_mismatched
        , 0 as ad_err_yield_optimization_rule_met
        , 0 as ad_err_no_slot_selected
        , 0 as ad_err_unknown

-- Slot Level Metrics (20)
    , SUM(IF(sub_err.error_category = 'COMPETITION_FAILURE', 1, 0))                                                                                   as slot_err_competition_failure
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'ADJACENT_EXCLUSIVITY', 1, 0))                                   as slot_err_adjacent_ads_exclusivity
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'ADJACENT_SAME_4A_ID', 1, 0))                                    as slot_err_adjacent_same_4a_id
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'ADVERTISER_FREQUENCY_CAP_REACHING', 1, 0))                      as slot_err_advertiser_frequency_cap_reaching
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'ADVERTISER_SEPARATION_EXCLUDED', 1, 0))                         as slot_err_inventory_protection_advertiser
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'BACK2BACK_EXCLUDED', 1, 0))                                     as slot_err_back_to_back_exclusivity
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'BRAND_FREQUENCY_CAP_REACHING', 1, 0))                           as slot_err_brand_frequency_cap_reaching
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'BRAND_SEPARATION_EXCLUDED', 1, 0))                              as slot_err_inventory_protection_brand
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'CLEARCAST_NO_APPLICABLE_POSITION_IN_SLOT', 1, 0))               as slot_err_clearcast_restriction
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'CRO_ADVERTISER_FREQUENCY_CAP_REACHING', 1, 0))                  as slot_err_cro_advertiser_frequency_cap_reaching
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'CRO_BRAND_FREQUENCY_CAP_REACHING', 1, 0))                       as slot_err_cro_brand_frequency_cap_reaching
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'EXCEED_MAX_NUM_ADVERTISEMENTS', 1, 0))                          as slot_err_max_number_of_ads_exceeded
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'EXCEED_MAX_SLOT_DURATION', 1, 0))                               as slot_err_max_slot_duration_exceeded
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'EXCLUSIVITY_BY_SLOT', 1, 0))                                    as slot_err_slot_exclusivity
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'FREQUENCY_CAP_REACHING', 1, 0))                                 as slot_err_frequency_cap_reaching
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'FROM_SAME_HEADER_BIDDING', 1, 0))                               as slot_err_header_bidding_repeating_key_value_exclusivity
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'INDUSTRY_SEPARATION_EXCLUDED', 1, 0))                           as slot_err_inventory_protection_industry
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'POSITION_OCCUPIED', 1, 0))                                      as slot_err_sequency_variat_targeting_failed
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'RESTRICTED_BY_OPENRTB_IMPRESSION_BID_CAPPING', 1, 0))           as slot_err_dsp_bid_cap_reaching
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code = 'SLOT_FILLED_BY_MULTI_ADS', 1, 0))                               as slot_err_excluded_by_pod_ads
    , SUM(if(sub_err.error_category = 'COMPETITION_FAILURE' AND sub_err.error_code in ('LOW_RANKING_IN_BUYER', 'SWAPPED_OUT_OF_SLOT'), 1, 0))         as slot_err_other

    , SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED'), 1, 0))                                                                                                  as slot_err_profile_check_failed
    , SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'AD_ASSET_STORE_NOT_AVAILABLE', 1, 0))                                          as slot_err_adstor_creative_unavailable
    , SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'LARGE_RENDITION_DURATION', 1, 0))                                              as slot_err_creative_ad_unit_duration_incompatible
    , SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code IN ('INCOMPATIBLE_FLASH_VERSION', 'NO_APPLICABLE_PROFILES_FOR_RENDITION'), 1, 0)) as slot_err_creative_profile_incompatible
    , SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'ESTIMATE_RENDITION_DURATION_FOR_LIVE', 1, 0))                                  as slot_err_estimated_duration_disabled_for_live_inventory
    , SUM(IF(sub_err.error_category IN ('PROFILE_CHECK_FAILED', 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED') AND sub_err.error_code = 'CREATIVE_NOT_AVAILABLE_FOR_LINEAR', 1, 0))                                     as slot_err_adstor_linear_creative_unavailable
FROM ${facts}.candidate
cross join unnest(
    partners__network_id,
    partners__network_is_extra_item_owner,
    partners__supply_source,
    partners__content_owner_network_id,
    partners__inbound_order_id,
    partners__site_section_id,
    partners__sales_channel,
    partners__entity_source,
    partners__role,
    partners__outbound_listing_id,
    partners__geo_country_visibility__report_aggregate,
    partners__user_agent_visibility__report_aggregate,
    partners__standard_endpoint_owner_visibility__report_aggregate,
    partners__standard_endpoint_visibility__report_aggregate,
    partners__standard_programmer_visibility__report_aggregate,
    partners__standard_brand_visibility__report_aggregate,
    partners__standard_channel_visibility__report_aggregate)
nw (
  network_id,
  extra_item_owner,
  supply_source,
  content_owner_network_id,
  inbound_order_id,
  site_section_id,
  sales_channel,
  entity_source,
  role,
  outbound_listing_id,
  country_visibility,
  user_agent_visibility,
  endpoint_owner_visibility,
  endpoint_visibility,
  programmer_visibility,
  brand_visibility,
  sa_channel_visibility)
cross join unnest(
    candidate__filter_reason__error,
    candidate__filter_reason__error_category
)
sub_err (
    error_code,
    error_category)
where process_batch_id = '${arena.presto.var.process_batch_id}'
  and nw.entity_source = 'auction_upstream'
  and nw.sales_channel = 6
  and coalesce(request__demand_log_magnifier, 0) > 0  -- Sampled by Demand Log
  and sub_err.error_category = candidate__error
  and ${sampling_filter} --sampling filter
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33

union all

-- #6 Listing Outbound Opportunity (Included User Drop Off) - Binary Log (Slot)
select
    2                                                                                                                   as process_stage,
    process_batch_id                                                                                                    as process_batch_id,
    request__timestamp                                                                                                  as event_date,
    coalesce(nw.nw_id, -1)                                                                                              as network_id,
    'Included'                                                                                                          as slot_user_drop_off,

    -- Supply (5)
        coalesce(nw.supply_source, -1)                                                                                      as supply_source,
        coalesce(nw.content_owner_network_id, -1)                                                                           as content_owner_network_id,
        coalesce(nw.inbound_order_id, -1)                                                                                   as inbound_order_id,
        coalesce(request__traffic_type, 0)                                                                                  as request_traffic_type,
        0                                                                                                                   as ack_traffic_type,
        coalesce(nw.site_section_id, -1)                                                                                    as site_section_id,

    -- SA (15)
        coalesce(request__context__stream_mode_id, -1)                                                                      as stream_mode_id,
        if(nw.standard_brand_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_brand_id, -1), -1)                                                          as standard_brand_id,
        coalesce(nw.standard_brand_visibility, 'FULL_VISIBILITY')                                                           as standard_brand_visibility,
        if(nw.standard_programmer_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_programmer_id, -1), -1)                                                     as standard_programmer_id,
        coalesce(nw.standard_programmer_visibility, 'FULL_VISIBILITY')                                                      as standard_programmer_visibility,
        if(nw.standard_endpoint_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_endpoint_id, -1), -1)                                                       as standard_endpoint_id,
        coalesce(nw.standard_endpoint_visibility, 'FULL_VISIBILITY')                                                        as standard_endpoint_visibility,
        if(nw.standard_endpoint_owner_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_endpoint_owner_id, -1), -1)                                                 as standard_endpoint_owner_id,
        coalesce(nw.standard_endpoint_owner_visibility, 'FULL_VISIBILITY')                                                  as standard_endpoint_owner_visibility,
        coalesce(visitor__standard_device_type_child_id, -1)                                                                as standard_device_type_id,
        coalesce(nw.user_agent_visibility, 'FULL_VISIBILITY')                                                               as user_agent_visibility,
        coalesce(visitor__country_id, -1)                                                                                   as user_country_id,
        coalesce(nw.geo_country_visibility, 'FULL_VISIBILITY')                                                              as geo_country_visibility,
        coalesce(request__context__standard_app_bundle_id, -1)                                                              as standard_app_bundle_id,
        coalesce(request__context__standard_site_domain_id, -1)                                                             as standard_site_domain_id,
        if(nw.sa_channel_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_channel_id, -1), -1)                                                            as standard_channel_id,
        coalesce(nw.sa_channel_visibility, 'FULL_VISIBILITY')                                                               as standard_channel_visibility,

    -- Demand (3)
        array[]                                                                                                             as global_advertiser_ids,
        array[]                                                                                                             as global_brand_ids,
        coalesce(outbound.listing_ids, array[])                                                                             as outbound_exchange_listing_ids,
        -1                                                                                                                  as market_ad_id,
        'Not Applicable'                                                                                                    as primary_ad_indicator

-- Programmatic Metrics (7)
    , 0 as bid_requests
    , 0 as opportunities_in_bid_request
    , 0 as received_bids
    , 0 as failed_bids
    , 0 as resolved_bids
    , 0 as filtered_bids
    , 0 as selected_bids

-- Listing Level Metrics (15)
    , sum(coalesce(outbound.opportunity, 0))                                                                              as outbound_exchange_opportunity
    , 0 as targeted_listings
    , 0 as effective_listings
    , 0 as candidated_listings
    , 0 as expanded_listings
    , 0 as listing_err_total
    , 0 as listing_err_unknown
    , 0 as listing_err_out_of_schedule
    , 0 as listing_err_split_source_target_not_met
    , 0 as listing_err_supply_source_target_not_met
    , 0 as listing_err_programmatic_banned
    , 0 as listing_err_exchange_banned
    , 0 as listing_err_met_volume_cap
    , 0 as listing_err_no_applicable_slots
    , 0 as listing_err_no_compatible_slots
    , 0 as listing_err_blocked_by_bidder_private_auction
    , 0 as listing_err_blocked_by_pg_only_ad_request
    , 0 as listing_err_restricted_by_pick_one_logic
    , 0 as listing_err_no_available_exchange_buyer
    , 0 as listing_err_blocked_by_buyer_exclusion
    , 0 as listing_err_blocked_by_exchange_filter

-- Ad Level Metrics (23)
    , 0 as ad_err_total
    , 0 as ad_err_ad_pending_approval
    , 0 as ad_err_ad_rejected
    , 0 as ad_err_competition_failure
    , 0 as ad_err_listing_advertiser_restriction
    , 0 as ad_err_listing_brand_restriction
    , 0 as ad_err_listing_industry_restriction
    , 0 as ad_err_listing_seat_restriction
    , 0 as ad_err_listing_creative_duration_restriction
    , 0 as ad_err_profile_check_failed
    , 0 as ad_err_listing_advertiser_floor_price_not_met
    , 0 as ad_err_listing_brand_floor_price_not_met
    , 0 as ad_err_listing_industry_floor_price_not_met
    , 0 as ad_err_listing_seat_floor_price_not_met
    , 0 as ad_err_demand_partner_disallowed_by_profile
    , 0 as ad_err_lat_unsupported
    , 0 as ad_err_ccpa_gpp_us_privacy_opt_out
    , 0 as ad_err_coppa_unsupported
    , 0 as ad_err_apple_app_tracking_transparency_unsupported
    , 0 as ad_err_kv_unsupported
    , 0 as ad_err_no_tcp_consent
    , 0 as ad_err_gpp_not_supported
    , 0 as ad_err_gpp_spi_opt_out

    , 0 as ad_err_creative_not_applicable
    , 0 as ad_err_deal_floor_price_not_met
    , 0 as ad_err_empty_deal_id
    , 0 as ad_err_empty_vast
    , 0 as ad_err_invalid_vast_wrapper_url
    , 0 as ad_err_malformed_vast_xml
    , 0 as ad_err_mismatched_seat_id
    , 0 as ad_err_network_item_advertiser_restriction
    , 0 as ad_err_network_item_brand_restriction
    , 0 as ad_err_network_item_industry_restriction
    , 0 as ad_err_no_ad_in_vast
    , 0 as ad_err_no_jitt_rendition
    , 0 as ad_err_non_secure_ad
    , 0 as ad_err_yield_optimization_cap_reached
    , 0 as ad_err_exclusivity
    , 0 as ad_err_standard_attribute_industry_restriction
    , 0 as ad_err_upstream_order_floor_price_not_met
    , 0 as ad_err_vast_wrapper_http_error
    , 0 as ad_err_vast_wrapper_timeout
    , 0 as ad_err_empty_bid_id
    , 0 as ad_err_unsupported_vast_version
    , 0 as ad_err_empty_vast_ad_markup
    , 0 as ad_err_mismatched_deal_id
    , 0 as ad_err_demand_partner_unsupported_on_external_ssp_supply
    , 0 as ad_err_mismatched_ad_id
    , 0 as ad_err_creative_restriction_failure
    , 0 as ad_err_inbound_order_competition_failure
    , 0 as ad_err_advertiser_domain_restricted
    , 0 as ad_err_ad_duration_exceeded
    , 0 as ad_err_creative_duration_mismatched
    , 0 as ad_err_yield_optimization_rule_met
    , 0 as ad_err_no_slot_selected
    , 0 as ad_err_unknown

-- Slot Level Metrics (20)
    , 0 as slot_err_competition_failure
    , 0 as slot_err_adjacent_ads_exclusivity
    , 0 as slot_err_adjacent_same_4a_id
    , 0 as slot_err_advertiser_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_advertiser
    , 0 as slot_err_back_to_back_exclusivity
    , 0 as slot_err_brand_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_brand
    , 0 as slot_err_clearcast_restriction
    , 0 as slot_err_cro_advertiser_frequency_cap_reaching
    , 0 as slot_err_cro_brand_frequency_cap_reaching
    , 0 as slot_err_max_number_of_ads_exceeded
    , 0 as slot_err_max_slot_duration_exceeded
    , 0 as slot_err_slot_exclusivity
    , 0 as slot_err_frequency_cap_reaching
    , 0 as slot_err_header_bidding_repeating_key_value_exclusivity
    , 0 as slot_err_inventory_protection_industry
    , 0 as slot_err_sequency_variat_targeting_failed
    , 0 as slot_err_dsp_bid_cap_reaching
    , 0 as slot_err_excluded_by_pod_ads
    , 0 as slot_err_other

    , 0 as slot_err_profile_check_failed
    , 0 as slot_err_adstor_creative_unavailable
    , 0 as slot_err_creative_ad_unit_duration_incompatible
    , 0 as slot_err_creative_profile_incompatible
    , 0 as slot_err_estimated_duration_disabled_for_live_inventory
    , 0 as slot_err_adstor_linear_creative_unavailable
FROM ${facts}.slot
cross join unnest (
        partners__network_id,
        partners__bit_flags,
        partners__role,
        partners__supply_source,
        partners__content_owner_network_id,
        partners__inbound_order_id,
        partners__site_section_id,

        partners__outbound_exchange_listings__listing_ids,
        partners__outbound_exchange_listings__avails_metrics__opportunity,

        partners__standard_endpoint_visibility__report_aggregate,
        partners__standard_endpoint_owner_visibility__report_aggregate,
        partners__standard_programmer_visibility__report_aggregate,
        partners__standard_brand_visibility__report_aggregate,
        partners__geo_country_visibility__report_aggregate,
        partners__user_agent_visibility__report_aggregate,
        partners__standard_channel_visibility__report_aggregate
    ) as nw (
        nw_id,
        bit_flags,
        nw_role,
        supply_source,
        content_owner_network_id,
        inbound_order_id,
        site_section_id,
        outbound_exchange_listings__listing_ids,
        outbound_exchange_listings__opportunity,

        standard_endpoint_visibility,
        standard_endpoint_owner_visibility,
        standard_programmer_visibility,
        standard_brand_visibility,
        geo_country_visibility,
        user_agent_visibility,
        sa_channel_visibility
    )
cross join unnest (
    nw.outbound_exchange_listings__listing_ids,
    nw.outbound_exchange_listings__opportunity
) as outbound (
    listing_ids,
    opportunity
)
where
    process_batch_id = '${arena.presto.var.process_batch_id}'
    and (request__delivery_method is null or request__delivery_method != 'CASUCPSU')        -- Remove Log Translator Traffic
    and bitwise_and(slot__flags, 64) = 0                                                    -- No Parent Slot
    and coalesce(nw.nw_role, '') in ('CRO', 'R')                                            -- Only for Reseller
    and coalesce(outbound.opportunity, 0) > 0
    and ${sampling_filter} --sampling filter
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33

union all

-- #7 Listing Outbound Opportunity (Removed User Drop Off) - Binary Log (Ack)
select
    2                                                                                                                   as process_stage,
    process_batch_id                                                                                                    as process_batch_id,
    request__timestamp                                                                                                  as event_date,
    coalesce(nw.nw_id, -1)                                                                                              as network_id,
    'Removed'                                                                                                           as slot_user_drop_off,

    -- Supply (5)
        coalesce(nw.supply_source, -1)                                                                                      as supply_source,
        coalesce(nw.content_owner_network_id, -1)                                                                           as content_owner_network_id,
        coalesce(nw.inbound_order_id, -1)                                                                                   as inbound_order_id,
        coalesce(request__traffic_type, 0)                                                                                  as request_traffic_type,
        coalesce(ack__traffic_type, 0)                                                                                      as ack_traffic_type,
        coalesce(nw.site_section_id, -1)                                                                                    as site_section_id,

    -- SA (15)
        coalesce(request__context__stream_mode_id, -1)                                                                      as stream_mode_id,
        if(nw.standard_brand_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_brand_id, -1), -1)                                                          as standard_brand_id,
        coalesce(nw.standard_brand_visibility, 'FULL_VISIBILITY')                                                           as standard_brand_visibility,
        if(nw.standard_programmer_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_programmer_id, -1), -1)                                                     as standard_programmer_id,
        coalesce(nw.standard_programmer_visibility, 'FULL_VISIBILITY')                                                      as standard_programmer_visibility,
        if(nw.standard_endpoint_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_endpoint_id, -1), -1)                                                       as standard_endpoint_id,
        coalesce(nw.standard_endpoint_visibility, 'FULL_VISIBILITY')                                                        as standard_endpoint_visibility,
        if(nw.standard_endpoint_owner_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_endpoint_owner_id, -1), -1)                                                 as standard_endpoint_owner_id,
        coalesce(nw.standard_endpoint_owner_visibility, 'FULL_VISIBILITY')                                                  as standard_endpoint_owner_visibility,
        coalesce(visitor__standard_device_type_child_id, -1)                                                                as standard_device_type_id,
        coalesce(nw.user_agent_visibility, 'FULL_VISIBILITY')                                                               as user_agent_visibility,
        coalesce(visitor__country_id, -1)                                                                                   as user_country_id,
        coalesce(nw.geo_country_visibility, 'FULL_VISIBILITY')                                                              as geo_country_visibility,
        coalesce(request__context__standard_app_bundle_id, -1)                                                              as standard_app_bundle_id,
        coalesce(request__context__standard_site_domain_id, -1)                                                             as standard_site_domain_id,
        if(nw.sa_channel_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_channel_id, -1), -1)                                                            as standard_channel_id,
        coalesce(nw.sa_channel_visibility, 'FULL_VISIBILITY')                                                               as standard_channel_visibility,

    -- Demand (3)
        array[]                                                                                                             as global_advertiser_ids,
        array[]                                                                                                             as global_brand_ids,
        coalesce(outbound.listing_ids, array[])                                                                             as outbound_exchange_listing_ids,
        if(demand_dim_awareability , coalesce(advertisement__market_ad_id, coalesce(candidate__market_ad_id, -1)), -1)      as market_ad_id,
        if(advertisement__is_fallback = false or (advertisement__is_undeliverable = false and bitwise_and(coalesce(advertisement__flags, 0), 33554432)>0), 'Primary', 'Fallback')   as primary_ad_indicator

-- Programmatic Metrics (7)
    , 0 as bid_requests
    , 0 as opportunities_in_bid_request
    , 0 as received_bids
    , 0 as failed_bids
    , 0 as resolved_bids
    , 0 as filtered_bids
    , 0 as selected_bids

-- Listing Level Metrics (15)
    , sum(coalesce(outbound.opportunity, 0))                                                                                as outbound_exchange_opportunity
    , 0 as targeted_listings
    , 0 as effective_listings
    , 0 as candidated_listings
    , 0 as expanded_listings
    , 0 as listing_err_total
    , 0 as listing_err_unknown
    , 0 as listing_err_out_of_schedule
    , 0 as listing_err_split_source_target_not_met
    , 0 as listing_err_supply_source_target_not_met
    , 0 as listing_err_programmatic_banned
    , 0 as listing_err_exchange_banned
    , 0 as listing_err_met_volume_cap
    , 0 as listing_err_no_applicable_slots
    , 0 as listing_err_no_compatible_slots
    , 0 as listing_err_blocked_by_bidder_private_auction
    , 0 as listing_err_blocked_by_pg_only_ad_request
    , 0 as listing_err_restricted_by_pick_one_logic
    , 0 as listing_err_no_available_exchange_buyer
    , 0 as listing_err_blocked_by_buyer_exclusion
    , 0 as listing_err_blocked_by_exchange_filter

-- Ad Level Metrics (23)
    , 0 as ad_err_total
    , 0 as ad_err_ad_pending_approval
    , 0 as ad_err_ad_rejected
    , 0 as ad_err_competition_failure
    , 0 as ad_err_listing_advertiser_restriction
    , 0 as ad_err_listing_brand_restriction
    , 0 as ad_err_listing_industry_restriction
    , 0 as ad_err_listing_seat_restriction
    , 0 as ad_err_listing_creative_duration_restriction
    , 0 as ad_err_profile_check_failed
    , 0 as ad_err_listing_advertiser_floor_price_not_met
    , 0 as ad_err_listing_brand_floor_price_not_met
    , 0 as ad_err_listing_industry_floor_price_not_met
    , 0 as ad_err_listing_seat_floor_price_not_met
    , 0 as ad_err_demand_partner_disallowed_by_profile
    , 0 as ad_err_lat_unsupported
    , 0 as ad_err_ccpa_gpp_us_privacy_opt_out
    , 0 as ad_err_coppa_unsupported
    , 0 as ad_err_apple_app_tracking_transparency_unsupported
    , 0 as ad_err_kv_unsupported
    , 0 as ad_err_no_tcp_consent
    , 0 as ad_err_gpp_not_supported
    , 0 as ad_err_gpp_spi_opt_out


    , 0 as ad_err_creative_not_applicable
    , 0 as ad_err_deal_floor_price_not_met
    , 0 as ad_err_empty_deal_id
    , 0 as ad_err_empty_vast
    , 0 as ad_err_invalid_vast_wrapper_url
    , 0 as ad_err_malformed_vast_xml
    , 0 as ad_err_mismatched_seat_id
    , 0 as ad_err_network_item_advertiser_restriction
    , 0 as ad_err_network_item_brand_restriction
    , 0 as ad_err_network_item_industry_restriction
    , 0 as ad_err_no_ad_in_vast
    , 0 as ad_err_no_jitt_rendition
    , 0 as ad_err_non_secure_ad
    , 0 as ad_err_yield_optimization_cap_reached
    , 0 as ad_err_exclusivity
    , 0 as ad_err_standard_attribute_industry_restriction
    , 0 as ad_err_upstream_order_floor_price_not_met
    , 0 as ad_err_vast_wrapper_http_error
    , 0 as ad_err_vast_wrapper_timeout
    , 0 as ad_err_empty_bid_id
    , 0 as ad_err_unsupported_vast_version
    , 0 as ad_err_empty_vast_ad_markup
    , 0 as ad_err_mismatched_deal_id
    , 0 as ad_err_demand_partner_unsupported_on_external_ssp_supply
    , 0 as ad_err_mismatched_ad_id
    , 0 as ad_err_creative_restriction_failure
    , 0 as ad_err_inbound_order_competition_failure
    , 0 as ad_err_advertiser_domain_restricted
    , 0 as ad_err_ad_duration_exceeded
    , 0 as ad_err_creative_duration_mismatched
    , 0 as ad_err_yield_optimization_rule_met
    , 0 as ad_err_no_slot_selected
    , 0 as ad_err_unknown

-- Slot Level Metrics (20)
    , 0 as slot_err_competition_failure
    , 0 as slot_err_adjacent_ads_exclusivity
    , 0 as slot_err_adjacent_same_4a_id
    , 0 as slot_err_advertiser_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_advertiser
    , 0 as slot_err_back_to_back_exclusivity
    , 0 as slot_err_brand_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_brand
    , 0 as slot_err_clearcast_restriction
    , 0 as slot_err_cro_advertiser_frequency_cap_reaching
    , 0 as slot_err_cro_brand_frequency_cap_reaching
    , 0 as slot_err_max_number_of_ads_exceeded
    , 0 as slot_err_max_slot_duration_exceeded
    , 0 as slot_err_slot_exclusivity
    , 0 as slot_err_frequency_cap_reaching
    , 0 as slot_err_header_bidding_repeating_key_value_exclusivity
    , 0 as slot_err_inventory_protection_industry
    , 0 as slot_err_sequency_variat_targeting_failed
    , 0 as slot_err_dsp_bid_cap_reaching
    , 0 as slot_err_excluded_by_pod_ads
    , 0 as slot_err_other

    , 0 as slot_err_profile_check_failed
    , 0 as slot_err_adstor_creative_unavailable
    , 0 as slot_err_creative_ad_unit_duration_incompatible
    , 0 as slot_err_creative_profile_incompatible
    , 0 as slot_err_estimated_duration_disabled_for_live_inventory
    , 0 as slot_err_adstor_linear_creative_unavailable
FROM ${facts}.ack
cross join unnest (
        partners__network_id,
        partners__bit_flags,
        partners__role,
        partners__supply_source,
        partners__content_owner_network_id,
        partners__inbound_order_id,
        partners__site_section_id,

        partners__outbound_exchange_listings__listing_ids,
        partners__outbound_exchange_listings__avails_metrics__opportunity,

        partners__standard_endpoint_visibility__report_aggregate,
        partners__standard_endpoint_owner_visibility__report_aggregate,
        partners__standard_programmer_visibility__report_aggregate,
        partners__standard_brand_visibility__report_aggregate,
        partners__geo_country_visibility__report_aggregate,
        partners__user_agent_visibility__report_aggregate,
        partners__demand_dim_awareability,
        partners__standard_channel_visibility__report_aggregate
    ) as nw (
        nw_id,
        bit_flags,
        nw_role,
        supply_source,
        content_owner_network_id,
        inbound_order_id,
        site_section_id,

        outbound_exchange_listings__listing_ids,
        outbound_exchange_listings__opportunity,

        standard_endpoint_visibility,
        standard_endpoint_owner_visibility,
        standard_programmer_visibility,
        standard_brand_visibility,
        geo_country_visibility,
        user_agent_visibility,
        demand_dim_awareability,
        sa_channel_visibility
    )
cross join unnest (
    nw.outbound_exchange_listings__listing_ids,
    nw.outbound_exchange_listings__opportunity
) as outbound (
    listing_ids,
    opportunity
)
where
    process_batch_id = '${arena.presto.var.process_batch_id}'
    and (request__delivery_method is null or request__delivery_method != 'CASUCPSU')        -- Remove Log Translator Traffic
    and bitwise_and(slot__flags, 64) = 0                                                    -- No Parent Slot
    and coalesce(nw.nw_role, '') in ('CRO', 'R')                                            -- Only for Reseller
    and coalesce(ack__ack_entity_type, '') = 'slot'
    and coalesce(ack__metrics__slot_impression, 0) > 0                                      -- Has Slot Callback
    and coalesce(outbound.opportunity, 0) > 0
    and ${sampling_filter} --sampling filter
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33

union all

-- #8 Selected Ads (Removed User Drop Off) - Binary Log (Ack)
select
    16                                                                                  as process_stage,
    process_batch_id                                                                    as process_batch_id,
    ack__timestamp                                                                      as event_date,
   coalesce(nw.network_id, -1)                                                          as network_id,
    'Removed'                                                                           as slot_user_drop_off,

    -- Supply (5)
        coalesce(nw.supply_source, -1)                                                  as supply_source,
        coalesce(nw.co_id, -1)                                                          as content_owner_network_id,
        coalesce(nw.inbound_order_id, -1)                                               as inbound_order_id,
        coalesce(request__traffic_type, 0)                                              as request_traffic_type,
        coalesce(ack__traffic_type, 0)                                                  as ack_traffic_type,
        coalesce(nw.site_section_id, -1)                                                as site_section_id,

    -- SA (15)
        coalesce(request__context__stream_mode_id, -1)                                  as stream_mode_id,
        if(nw.brand_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_brand_id, -1), -1)                      as standard_brand_id,
        coalesce(nw.brand_visibility, 'FULL_VISIBILITY')                                as standard_brand_visibility,
        if(nw.programmer_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_programmer_id, -1), -1)                 as standard_programmer_id,
        coalesce(nw.programmer_visibility, 'FULL_VISIBILITY')                           as standard_programmer_visibility,
        if(nw.endpoint_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_endpoint_id, -1), -1)                   as standard_endpoint_id,
        coalesce(nw.endpoint_visibility, 'FULL_VISIBILITY')                             as standard_endpoint_visibility,
        if(nw.endpoint_owner_visibility is not null or nw.supply_source != 3,
            coalesce(request__context__standard_endpoint_owner_id, -1), -1)             as standard_endpoint_owner_id,
        coalesce(nw.endpoint_owner_visibility, 'FULL_VISIBILITY')                       as standard_endpoint_owner_visibility,
        coalesce(visitor__standard_device_type_child_id, -1)                            as standard_device_type_id,
        coalesce(nw.user_agent_visibility, 'FULL_VISIBILITY')                           as user_agent_visibility,
        coalesce(visitor__country_id, -1)                                               as user_country_id,
        coalesce(nw.country_visibility, 'FULL_VISIBILITY')                              as geo_country_visibility,
        coalesce(request__context__standard_app_bundle_id, -1)                          as standard_app_bundle_id,
        coalesce(request__context__standard_site_domain_id, -1)                         as standard_site_domain_id,
        if(nw.sa_channel_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_channel_id, -1), -1)                        as standard_channel_id,
        coalesce(nw.sa_channel_visibility, 'FULL_VISIBILITY')                           as standard_channel_visibility,

    -- Demand (3)
        array[]                                                                         as global_advertiser_ids,
        array[]                                                                         as global_brand_ids,
        coalesce(nw.outbound_listing_id, array[])                                       as outbound_exchange_listing_ids,
        if(demand_dim_awareability , coalesce(ads.advertisement__market_ad_id, coalesce(ads.candidate__market_ad_id, -1)), -1) as market_ad_id,
        if(ads.advertisement__is_fallback = false or (ads.advertisement__is_undeliverable = false and bitwise_and(coalesce(ads.advertisement__flags, 0), 33554432)>0), 'Primary', 'Fallback') as primary_ad_indicator

-- Programmatic Metrics(7)
        , 0 as bid_requests
        , 0 as opportunities_in_bid_request
        , 0 as received_bids
        , 0 as failed_bids
        , 0 as resolved_bids
        , 0 as filtered_bids
        , sum(IF(BITWISE_AND(ads.candidate__bid_status, 8)>0, 1, 0))                    as selected_bids

-- Listing Level Metrics (15)
        , 0 as outbound_exchange_opportunity
        , 0 as targeted_listings
        , 0 as effective_listings
        , 0 as candidated_listings
        , 0 as expanded_listings
        , 0 as listing_err_total
        , 0 as listing_err_unknown
        , 0 as listing_err_out_of_schedule
        , 0 as listing_err_split_source_target_not_met
        , 0 as listing_err_supply_source_target_not_met
        , 0 as listing_err_programmatic_banned
        , 0 as listing_err_exchange_banned
        , 0 as listing_err_met_volume_cap
        , 0 as listing_err_no_applicable_slots
        , 0 as listing_err_no_compatible_slots
        , 0 as listing_err_blocked_by_bidder_private_auction
        , 0 as listing_err_blocked_by_pg_only_ad_request
        , 0 as listing_err_restricted_by_pick_one_logic
        , 0 as listing_err_no_available_exchange_buyer
        , 0 as listing_err_blocked_by_buyer_exclusion
        , 0 as listing_err_blocked_by_exchange_filter

-- Ad Level Metrics (23)
    , 0 as ad_err_total
    , 0 as ad_err_ad_pending_approval
    , 0 as ad_err_ad_rejected
    , 0 as ad_err_competition_failure
    , 0 as ad_err_listing_advertiser_restriction
    , 0 as ad_err_listing_brand_restriction
    , 0 as ad_err_listing_industry_restriction
    , 0 as ad_err_listing_seat_restriction
    , 0 as ad_err_listing_creative_duration_restriction
    , 0 as ad_err_profile_check_failed
    , 0 as ad_err_listing_advertiser_floor_price_not_met
    , 0 as ad_err_listing_brand_floor_price_not_met
    , 0 as ad_err_listing_industry_floor_price_not_met
    , 0 as ad_err_listing_seat_floor_price_not_met
    , 0 as ad_err_demand_partner_disallowed_by_profile
    , 0 as ad_err_lat_unsupported
    , 0 as ad_err_ccpa_gpp_us_privacy_opt_out
    , 0 as ad_err_coppa_unsupported
    , 0 as ad_err_apple_app_tracking_transparency_unsupported
    , 0 as ad_err_kv_unsupported
    , 0 as ad_err_no_tcp_consent
    , 0 as ad_err_gpp_not_supported
    , 0 as ad_err_gpp_spi_opt_out

    , 0 as ad_err_creative_not_applicable
    , 0 as ad_err_deal_floor_price_not_met
    , 0 as ad_err_empty_deal_id
    , 0 as ad_err_empty_vast
    , 0 as ad_err_invalid_vast_wrapper_url
    , 0 as ad_err_malformed_vast_xml
    , 0 as ad_err_mismatched_seat_id
    , 0 as ad_err_network_item_advertiser_restriction
    , 0 as ad_err_network_item_brand_restriction
    , 0 as ad_err_network_item_industry_restriction
    , 0 as ad_err_no_ad_in_vast
    , 0 as ad_err_no_jitt_rendition
    , 0 as ad_err_non_secure_ad
    , 0 as ad_err_yield_optimization_cap_reached
    , 0 as ad_err_exclusivity
    , 0 as ad_err_standard_attribute_industry_restriction
    , 0 as ad_err_upstream_order_floor_price_not_met
    , 0 as ad_err_vast_wrapper_http_error
    , 0 as ad_err_vast_wrapper_timeout
    , 0 as ad_err_empty_bid_id
    , 0 as ad_err_unsupported_vast_version
    , 0 as ad_err_empty_vast_ad_markup
    , 0 as ad_err_mismatched_deal_id
    , 0 as ad_err_demand_partner_unsupported_on_external_ssp_supply
    , 0 as ad_err_mismatched_ad_id
    , 0 as ad_err_creative_restriction_failure
    , 0 as ad_err_inbound_order_competition_failure
    , 0 as ad_err_advertiser_domain_restricted
    , 0 as ad_err_ad_duration_exceeded
    , 0 as ad_err_creative_duration_mismatched
    , 0 as ad_err_yield_optimization_rule_met
    , 0 as ad_err_no_slot_selected
    , 0 as ad_err_unknown

-- Slot Level Metrics (20)
    , 0 as slot_err_competition_failure
    , 0 as slot_err_adjacent_ads_exclusivity
    , 0 as slot_err_adjacent_same_4a_id
    , 0 as slot_err_advertiser_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_advertiser
    , 0 as slot_err_back_to_back_exclusivity
    , 0 as slot_err_brand_frequency_cap_reaching
    , 0 as slot_err_inventory_protection_brand
    , 0 as slot_err_clearcast_restriction
    , 0 as slot_err_cro_advertiser_frequency_cap_reaching
    , 0 as slot_err_cro_brand_frequency_cap_reaching
    , 0 as slot_err_max_number_of_ads_exceeded
    , 0 as slot_err_max_slot_duration_exceeded
    , 0 as slot_err_slot_exclusivity
    , 0 as slot_err_frequency_cap_reaching
    , 0 as slot_err_header_bidding_repeating_key_value_exclusivity
    , 0 as slot_err_inventory_protection_industry
    , 0 as slot_err_sequency_variat_targeting_failed
    , 0 as slot_err_dsp_bid_cap_reaching
    , 0 as slot_err_excluded_by_pod_ads
    , 0 as slot_err_other

    , 0 as slot_err_profile_check_failed
    , 0 as slot_err_adstor_creative_unavailable
    , 0 as slot_err_creative_ad_unit_duration_incompatible
    , 0 as slot_err_creative_profile_incompatible
    , 0 as slot_err_estimated_duration_disabled_for_live_inventory
    , 0 as slot_err_adstor_linear_creative_unavailable

FROM ${facts}.ack
CROSS JOIN UNNEST(
    ads_in_slot__candidate__bid_status,
    ads_in_slot__auction__integration_type,

    ads_in_slot__partners__network_id,
    ads_in_slot__partners__supply_source,
    ads_in_slot__partners__sales_channel,
    ads_in_slot__partners__entity_source,
    ads_in_slot__partners__content_owner_network_id,
    ads_in_slot__partners__outbound_listing_id,
    ads_in_slot__partners__inbound_order_id,
    ads_in_slot__partners__site_section_id,
    ads_in_slot__partners__geo_country_visibility__report_aggregate,
    ads_in_slot__partners__user_agent_visibility__report_aggregate,
    ads_in_slot__partners__standard_endpoint_owner_visibility__report_aggregate,
    ads_in_slot__partners__standard_endpoint_visibility__report_aggregate,
    ads_in_slot__partners__standard_programmer_visibility__report_aggregate,
    ads_in_slot__partners__standard_brand_visibility__report_aggregate,
    ads_in_slot__partners__demand_dim_awareability,
    ads_in_slot__advertisement__market_ad_id,
    ads_in_slot__candidate__market_ad_id,
    ads_in_slot__advertisement__flags,
    ads_in_slot__advertisement__is_undeliverable,
    ads_in_slot__advertisement__is_fallback,
    ads_in_slot__partners__standard_channel_visibility__report_aggregate
    )
as ads (
    candidate__bid_status,
    auction__integration_type,

    network_id,
    supply_source,
    sales_channel,
    entity_source,
    co_id,
    outbound_listing_id,
    inbound_order_id,
    site_section_id,
    country_visibility,
    user_agent_visibility,
    endpoint_owner_visibility,
    endpoint_visibility,
    programmer_visibility,
    brand_visibility,
    demand_dim_awareabilities,
    advertisement__market_ad_id,
    candidate__market_ad_id,
    advertisement__flags,
    advertisement__is_undeliverable,
    advertisement__is_fallback,
    sa_channel_visibility
    )
CROSS JOIN UNNEST (
    ads.network_id,
    ads.supply_source,
    ads.sales_channel,
    ads.entity_source,
    ads.co_id,
    ads.outbound_listing_id,
    ads.inbound_order_id,
    ads.site_section_id,
    ads.country_visibility,
    ads.user_agent_visibility,
    ads.endpoint_owner_visibility,
    ads.endpoint_visibility,
    ads.programmer_visibility,
    ads.brand_visibility,
    ads.demand_dim_awareabilities,
    ads.sa_channel_visibility
    )
as nw (
    network_id,
    supply_source,
    sales_channel,
    entity_source,
    co_id,
    outbound_listing_id,
    inbound_order_id,
    site_section_id,
    country_visibility,
    user_agent_visibility,
    endpoint_owner_visibility,
    endpoint_visibility,
    programmer_visibility,
    brand_visibility,
    demand_dim_awareability,
    sa_channel_visibility
)
where
    process_batch_id = '${arena.presto.var.process_batch_id}'
    and ads.auction__integration_type IN ('NORMAL', 'PG_TD')
    and BITWISE_AND(ads.candidate__bid_status, 8)>0
  --  and nw.entity_source = 'auction_upstream'
    and nw.sales_channel = 6
    and nw.supply_source != 4                                                      -- Remove DSP Rows
    and COALESCE(advertisement__is_bumper, false) = false                          -- Remove Bumper Ad
    and COALESCE(ack__ack_entity_type, '') = 'slot'
    and COALESCE(ack__metrics__slot_impression, 0) > 0                             -- Has Slot Callback
    and ${sampling_filter} --sampling filter
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33) f
GROUP BY 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,84,85,86,87,88,89,96,97,143,144,145,147
