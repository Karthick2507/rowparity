/* only include transction_type in ('CRO', 'R') */
with ad_unit_map as (
select network_id,array_union(array_agg(id), array[1,2,3,4,5,6]) as ids
from db.public_test1.d_ad_unit
where network_id > 0
group by 1
)

select 
    reduce(set_agg(process_stage), 0, (acc, val) -> acc + val, val -> val) as process_stage
    , f.network_id
    , content_owner_id
    , 'FULL_VISIBILITY' as content_owner_visibility
    , distributor_id
    , transaction_type
    , reseller_id
    , reseller_visibility

    -- no used
    , reseller_network_type

    , supply_source
    , sales_channel
    , sales_strategy
    , site_id
    , site_section_id
    , standard_publisher_id
    , standard_brand_id
    , standard_brand_visibility
    , standard_programmer_id
    , standard_programmer_visibility
    , content_form_id
    , stream_mode_id
    , standard_endpoint_owner_id
    , standard_endpoint_owner_visibility
    , standard_endpoint_id
    , standard_endpoint_visibility
    , user_country_id
    , geo_country_visibility
    , standard_device_type_id
    , standard_app_id
    , standard_environment_id
    , standard_os_id
    , delivered_platform_device_id
    , user_agent_visibility
    , profile_id
    , profile_type
    , request_fill_status
    , live_linear_indicator        
    , ssp_bidder_indicator
    , partner_tag_indicator

    -- be replaced by time_position_class
    , time_position_classes
    -- be replaced by slot_ad_unit_id
    , array[if(contains(aum.ids, slot_ad_unit_id), slot_ad_unit_id, -1)]  as slot_ad_unit_ids

    , slot_sequence_normalized     
    , slot_user_drop_off           
    , slot_removed_by_ux_indicator
    , slot_fill_status
    , evergreen_ad_indicator
    , promo_ad_indicator

    -- move complex logic of priority_tier/priority_value/priority_type to hoover
    , priority_tier
    , case 
        -- fix SPONSORSHIP logic
        when priority_tier = 'TIER_1' and priority_type = 'SPONSORSHIP' then coalesce(ad_meta_priority_value, 25)
        when priority_tier = 'TIER_1' and priority_value is null then 25
        when priority_tier = 'TIER_2' and priority_value is null then 11
        when priority_tier = 'TIER_3' and priority_type not like '%SPONSORSHIP%' and (priority_value is null or priority_value<0 or priority_value>10) then 0
        when priority_tier = 'TIER_4' then if(meet_schedule = 1, -65536, coalesce(priority_value, -65535))
        when priority_tier = 'TIER_5' then 0
        when priority_tier = 'TIER_6' and (priority_value is null or priority_value = -65535) then 0
        else if(priority_value is null, 0, priority_value)
    end as priority_value
    , priority_type

    , request_traffic_type
    , ack_traffic_type
    , inbound_order_id
    , outbound_order_id

    -- no use, could be removed
    , outbound_exchange_order_id

    , dsp_id
    , buyer_platform_id
    , deal_id
    , buyer_group_id

    -- no use, could be removed
    , buyer_id

    , market_ad_id
    , ad_id
    , placement_id
    , creative_id
    , global_currency_id
    , global_currency_version
    , global_advertiser_ids
    , global_brand_ids
    , local_advertiser_id
    , process_batch_id

    -- to be added
    --,ivt_indicator
    --,partner_module
    --,ad_with_fallback_indicator


    , sum(placed_ads)                                       as placed_ads
    , sum(placed_fallback_ads)                              as placed_fallback_ads
    , sum(filled_ads)                                       as filled_ads
    , sum(filled_ads_duration)                              as filled_ads_duration
    , sum(filled_ads_sstf_fallback)                         as filled_ads_sstf_fallback

    -- error metrics will be pivoted in downstream table
    , sum(ad_err_floor_price_notmet)                        as ad_err_floor_price_notmet
    , sum(ad_err_floor_price_notmet_no_fallback)            as ad_err_floor_price_notmet_no_fallback
    , sum(ad_err_unexpected_external_ad_id)                 as ad_err_unexpected_external_ad_id
    , sum(ad_err_unexpected_external_ad_id_no_fallback)     as ad_err_unexpected_external_ad_id_no_fallback
    , sum(ad_err_no_valid_creative)                         as ad_err_no_valid_creative
    , sum(ad_err_no_valid_creative_no_fallback)             as ad_err_no_valid_creative_no_fallback
    , sum(ad_err_malformed_response)                        as ad_err_malformed_response
    , sum(ad_err_malformed_response_no_fallback)            as ad_err_malformed_response_no_fallback
    , sum(ad_err_competition_failure)                       as ad_err_competition_failure
    , sum(ad_err_competition_failure_no_fallback)           as ad_err_competition_failure_no_fallback
    , sum(ad_err_jitt_rendition_required)                   as ad_err_jitt_rendition_required
    , sum(ad_err_jitt_rendition_required_no_fallback)       as ad_err_jitt_rendition_required_no_fallback
    , sum(ad_err_no_slot_selected)                          as ad_err_no_slot_selected
    , sum(ad_err_no_slot_selected_no_fallback)              as ad_err_no_slot_selected_no_fallback
    , sum(ad_err_empty_response)                            as ad_err_empty_response
    , sum(ad_err_empty_response_no_fallback)                as ad_err_empty_response_no_fallback
    , sum(ad_err_inapplicable_for_https)                    as ad_err_inapplicable_for_https
    , sum(ad_err_inapplicable_for_https_no_fallback)        as ad_err_inapplicable_for_https_no_fallback
    , sum(ad_err_ad_pending_approval)                       as ad_err_ad_pending_approval
    , sum(ad_err_ad_pending_approval_no_fallback)           as ad_err_ad_pending_approval_no_fallback
    , sum(ad_err_bid_response_id_nomatch)                   as ad_err_bid_response_id_nomatch
    , sum(ad_err_bid_response_id_nomatch_no_fallback)       as ad_err_bid_response_id_nomatch_no_fallback
    , sum(ad_err_wrapper_timeout)                           as ad_err_wrapper_timeout
    , sum(ad_err_wrapper_timeout_no_fallback)               as ad_err_wrapper_timeout_no_fallback
    , sum(ad_err_compliance_not_approved)                   as ad_err_compliance_not_approved
    , sum(ad_err_compliance_not_approved_no_fallback)       as ad_err_compliance_not_approved_no_fallback
    , sum(ad_err_http_error)                                as ad_err_http_error
    , sum(ad_err_http_error_no_fallback)                    as ad_err_http_error_no_fallback
    , sum(ad_err_no_bids)                                   as ad_err_no_bids
    , sum(ad_err_no_bids_no_fallback)                       as ad_err_no_bids_no_fallback
    , sum(ad_err_external_creative_profile_check_failed)    as ad_err_external_creative_profile_check_failed
    , sum(ad_err_external_creative_profile_check_failed_no_fallback)    as ad_err_external_creative_profile_check_failed_no_fallback
    , sum(ad_err_auction_max_ad_duration_exceeded)          as ad_err_auction_max_ad_duration_exceeded
    , sum(ad_err_auction_max_ad_duration_exceeded_no_fallback) as ad_err_auction_max_ad_duration_exceeded_no_fallback
    , sum(ad_err_wrapper_http_error)                        as ad_err_wrapper_http_error
    , sum(ad_err_wrapper_http_error_no_fallback)            as ad_err_wrapper_http_error_no_fallback
    , sum(ad_err_timeout)                                   as ad_err_timeout
    , sum(ad_err_timeout_no_fallback)                       as ad_err_timeout_no_fallback
    , sum(ad_err_no_content)                                as ad_err_no_content
    , sum(ad_err_no_content_no_fallback)                    as ad_err_no_content_no_fallback
    , sum(ad_err_max_wrapper_redirect)                      as ad_err_max_wrapper_redirect
    , sum(ad_err_max_wrapper_redirect_no_fallback)          as ad_err_max_wrapper_redirect_no_fallback
    , sum(ad_err_empty_bid_dealid)                          as ad_err_empty_bid_dealid
    , sum(ad_err_empty_bid_dealid_no_fallback)              as ad_err_empty_bid_dealid_no_fallback
    , sum(ad_err_invalid_wrapper_url)                       as ad_err_invalid_wrapper_url
    , sum(ad_err_invalid_wrapper_url_no_fallback)           as ad_err_invalid_wrapper_url_no_fallback
    , sum(ad_err_profile_check_failed)                      as ad_err_profile_check_failed
    , sum(ad_err_profile_check_failed_no_fallback)          as ad_err_profile_check_failed_no_fallback
    , sum(gross_ad_views)                                   as gross_ad_views
    , sum(gross_ad_views_primary)                           as gross_ad_views_primary
    , sum(gross_ad_views_fallback)                          as gross_ad_views_fallback
    , sum(revenue)                                          as revenue
    , sum(co_revenue)                                       as co_revenue
    , sum(d_revenue)                                        as d_revenue
    , sum(r_revenue)                                        as r_revenue
    , sum(no_ad_views)                                      as no_ad_views
    , sum(clicks)                                           as clicks
    , sum(no_clicks)                                        as no_clicks
    , sum(first_quartile)                                   as first_quartile
    , sum(middle_quartile)                                  as middle_quartile
    , sum(third_quartile)                                   as third_quartile
    , sum(complete_quartile)                                as complete_quartile
    , sum(can_quartile)                                     as can_quartile
    , event_date

    , bidding_buyer_id
    , sum(undeliverable_placed_ads)                                           as undeliverable_placed_ads
    , sum(undeliverable_placed_ads_floor_price_notmet)                        as undeliverable_placed_ads_floor_price_notmet
    , sum(undeliverable_placed_ads_unexpected_external_ad_id)                 as undeliverable_placed_ads_unexpected_external_ad_id
    , sum(undeliverable_placed_ads_no_valid_creative)                         as undeliverable_placed_ads_no_valid_creative
    , sum(undeliverable_placed_ads_malformed_response)                        as undeliverable_placed_ads_malformed_response
    , sum(undeliverable_placed_ads_competition_failure)                       as undeliverable_placed_ads_competition_failure
    , sum(undeliverable_placed_ads_jitt_rendition_required)                   as undeliverable_placed_ads_jitt_rendition_required
    , sum(undeliverable_placed_ads_no_slot_selected)                          as undeliverable_placed_ads_no_slot_selected
    , sum(undeliverable_placed_ads_empty_response)                            as undeliverable_placed_ads_empty_response
    , sum(undeliverable_placed_ads_inapplicable_for_https)                    as undeliverable_placed_ads_inapplicable_for_https
    , sum(undeliverable_placed_ads_ad_pending_approval)                       as undeliverable_placed_ads_ad_pending_approval
    , sum(undeliverable_placed_ads_bid_response_id_nomatch)                   as undeliverable_placed_ads_bid_response_id_nomatch
    , sum(undeliverable_placed_ads_wrapper_timeout)                           as undeliverable_placed_ads_wrapper_timeout
    , sum(undeliverable_placed_ads_compliance_not_approved)                   as undeliverable_placed_ads_compliance_not_approved
    , sum(undeliverable_placed_ads_http_error)                                as undeliverable_placed_ads_http_error
    , sum(undeliverable_placed_ads_no_bids)                                   as undeliverable_placed_ads_no_bids
    , sum(undeliverable_placed_ads_external_creative_profile_check_failed)    as undeliverable_placed_ads_external_creative_profile_check_failed
    , sum(undeliverable_placed_ads_auction_max_ad_duration_exceeded)          as undeliverable_placed_ads_auction_max_ad_duration_exceeded
    , sum(undeliverable_placed_ads_wrapper_http_error)                        as undeliverable_placed_ads_wrapper_http_error
    , sum(undeliverable_placed_ads_timeout)                                   as undeliverable_placed_ads_timeout
    , sum(undeliverable_placed_ads_no_content)                                as undeliverable_placed_ads_no_content
    , sum(undeliverable_placed_ads_max_wrapper_redirect)                      as undeliverable_placed_ads_max_wrapper_redirect
    , sum(undeliverable_placed_ads_empty_bid_dealid)                          as undeliverable_placed_ads_empty_bid_dealid
    , sum(undeliverable_placed_ads_invalid_wrapper_url)                       as undeliverable_placed_ads_invalid_wrapper_url
    , sum(undeliverable_placed_ads_profile_check_failed)                      as undeliverable_placed_ads_profile_check_failed

    , sum(placed_ads_has_fallback)                                            as placed_ads_has_fallback
    , sum(ad_err_no_fallback)                                                 as ad_err_no_fallback
    , sum(selected_ads) as selected_ads
    , primary_ad_indicator as primary_ad_indicator
    , outbound_exchange_listing_id as outbound_exchange_listing_ids
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
    , sum(ack_err_vast_51) as ack_err_vast_51
    , sum(ack_err_vast_52) as ack_err_vast_52
    , sum(ack_err_vast_100) as ack_err_vast_100
    , sum(ack_err_vast_101) as ack_err_vast_101
    , sum(ack_err_vast_102) as ack_err_vast_102
    , sum(ack_err_vast_200) as ack_err_vast_200
    , sum(ack_err_vast_201) as ack_err_vast_201
    , sum(ack_err_vast_202) as ack_err_vast_202
    , sum(ack_err_vast_203) as ack_err_vast_203
    , sum(ack_err_vast_204) as ack_err_vast_204
    , sum(ack_err_vast_300) as ack_err_vast_300
    , sum(ack_err_vast_301) as ack_err_vast_301
    , sum(ack_err_vast_302) as ack_err_vast_302
    , sum(ack_err_vast_303) as ack_err_vast_303
    , sum(ack_err_vast_304) as ack_err_vast_304
    , sum(ack_err_vast_400) as ack_err_vast_400
    , sum(ack_err_vast_401) as ack_err_vast_401
    , sum(ack_err_vast_402) as ack_err_vast_402
    , sum(ack_err_vast_403) as ack_err_vast_403
    , sum(ack_err_vast_405) as ack_err_vast_405
    , sum(ack_err_vast_406) as ack_err_vast_406
    , sum(ack_err_vast_407) as ack_err_vast_407
    , sum(ack_err_vast_408) as ack_err_vast_408
    , sum(ack_err_vast_409) as ack_err_vast_409
    , sum(ack_err_vast_410) as ack_err_vast_410
    , sum(ack_err_vast_411) as ack_err_vast_411
    , sum(ack_err_vast_500) as ack_err_vast_500
    , sum(ack_err_vast_501) as ack_err_vast_501
    , sum(ack_err_vast_502) as ack_err_vast_502
    , sum(ack_err_vast_503) as ack_err_vast_503
    , sum(ack_err_vast_600) as ack_err_vast_600
    , sum(ack_err_vast_601) as ack_err_vast_601
    , sum(ack_err_vast_602) as ack_err_vast_602
    , sum(ack_err_vast_603) as ack_err_vast_603
    , sum(ack_err_vast_604) as ack_err_vast_604
    , sum(ack_err_vast_900) as ack_err_vast_900
    , sum(ack_err_vast_901) as ack_err_vast_901
    , sum(ack_err_vast_total) as ack_err_vast_total
    , sum(ack_err_adm_total) as ack_err_adm_total
-- add new error code existing on PRD
    , sum(ad_err_no_valid_currency) as ad_err_no_valid_currency
    , sum(ad_err_no_valid_currency_no_fallback) as ad_err_no_valid_currency_no_fallback
    , sum(undeliverable_placed_ads_no_valid_currency) as undeliverable_placed_ads_no_valid_currency
    , sum(ad_err_client_rendition_required) as ad_err_client_rendition_required
    , sum(ad_err_client_rendition_required_no_fallback) as ad_err_client_rendition_required_no_fallback
    , sum(undeliverable_placed_ads_client_rendition_required) as undeliverable_placed_ads_client_rendition_required
    , sum(ad_err_unknown_seat) as ad_err_unknown_seat
    , sum(ad_err_unknown_seat_no_fallback) as ad_err_unknown_seat_no_fallback
    , sum(undeliverable_placed_ads_unknown_seat) as undeliverable_placed_ads_unknown_seat
    , sum(ad_err_playlist_timeout) as ad_err_playlist_timeout
    , sum(ad_err_playlist_timeout_no_fallback) as ad_err_playlist_timeout_no_fallback
    , sum(undeliverable_placed_ads_playlist_timeout) as undeliverable_placed_ads_playlist_timeout
    , sum(ad_err_no_ad_markup) as ad_err_no_ad_markup
    , sum(ad_err_no_ad_markup_no_fallback) as ad_err_no_ad_markup_no_fallback
    , sum(undeliverable_placed_ads_no_ad_markup) as undeliverable_placed_ads_no_ad_markup
     -- FIX: the reason why there's inconsistency between column name and error code name
     -- is that the error code name is typed as typo(1 added to the end by mistake).
    , sum(ack_err_adm_e_hlsjs) as ack_err_adm_e_hlsjs1
    , sum(ack_err_adm_e_custom_player) as ack_err_adm_e_custom_player

    -- ad_err is total number for sstf error, not consider if with fallback
    , sum(ad_err) as ad_err

    , content_form_visibility
    , case
        WHEN supply_source = 1                                                                                                                                  then 'O&O'
        when supply_source = 3                                                                                                                                  then 'MRM Rule'
        when supply_source = 4                                                                                                                                  then 'Programmatic'
        when supply_source = 5 and coalesce(inbound_order_type, '') = 'CARRIAGE_ORDER'                                                                          then 'Marketplace Platform Private - Inventory Split Order'
        when supply_source = 5 and coalesce(inbound_order_type, '') = 'MARKETPLACE_ORDER' and coalesce(inbound_order_transaction_type, '') = 'GUARANTEED'       then 'Marketplace Platform Private - Guaranteed Order'
        when supply_source = 5                                                                                                                                  then 'Marketplace Platform Private - Non-Guaranteed Order'
        when supply_source = 6                                                                                                                                  then 'Marketplace Platform Exchange'
        else 'Unknown'
    end as supply_source_detail
    , coalesce(inbound_order_transaction_type, 'NOT_APPLICABLE') as inbound_order_transaction_type
    , standard_app_bundle_id
    , standard_site_domain_id
    , standard_channel_id
    , standard_channel_visibility
    , slot_removed_by_constrained_indicator
    , process_batch_id as partition_key
from (
-- Ads (Not Removed User Drop Off)
select
    cast(16 as int)                                                                                                       as process_stage
 
-- Network Chain (10)
    , coalesce(nw.nw_id, -1)                                                                                              as network_id
    , coalesce(nw.co_id, -1)                                                                                              as content_owner_id
    -- , if(bitwise_and(coalesce(request__extra_flags, 0), 1073741824) > 0 and coalesce(nw.nw_role, '') = 'CRO', -3, coalesce(nw.distributor_id, -1))   as distributor_id -- mark CANOE_PROGRAMMER_LINEAR with -3
    , coalesce(nw.distributor_id, -1)                                                                                     as distributor_id
    , coalesce(nw.nw_role, '')                                                                                            as transaction_type
    , coalesce(nw.reseller_id, -1)                                                                                        as reseller_id
    , if(nw.sales_channel = 4, 'NO_VISIBILITY', 'FULL_VISIBILITY')                                                        as reseller_visibility
    , coalesce(reseller.network_type, 'UNKNOWN')                                                                          as reseller_network_type
    , coalesce(nw.supply_source, -1)                                                                                      as supply_source
    , coalesce(nw.sales_channel, -1)                                                                                      as sales_channel
    , case
      when coalesce(nw.sales_channel, -1) = 2 then 'Direct Sold'
      when coalesce(nw.sales_channel, -1) = 3 and reseller.network_type = 'FULL' then 'MRM Partner'
      when coalesce(nw.sales_channel, -1) = 3 and reseller.network_type = 'INTERNAL' then 'Reseller Sold - Reseller Tag'
      when coalesce(nw.sales_channel, -1) = 4 then 'Programmatic'
      when coalesce(nw.sales_channel, -1) = 5 then 'MRM Partner'
      when coalesce(nw.sales_channel, -1) = 6 then 'MRM Partner'
      else 'Unknown'
    end                                                                                                                   as sales_strategy 

-- Raw Inventory (2)
    , coalesce(nw.site_id, -1)                                                                                            as site_id
    , coalesce(nw.site_section_id, -1)                                                                                    as site_section_id
 
 
-- SA Content (21)
    , coalesce(request__context__standard_publisher_id, -1)                                                               as standard_publisher_id
    , if(nw.sa_brand_visibility is not null or nw.supply_source != 3, 
        coalesce(request__context__standard_brand_id, -1), -1)                                                            as standard_brand_id
    , coalesce(nw.sa_brand_visibility, 'FULL_VISIBILITY')                                                                 as standard_brand_visibility
    , if(nw.sa_programmer_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_programmer_id, -1), -1)                                                       as standard_programmer_id
    , coalesce(nw.sa_programmer_visibility, 'FULL_VISIBILITY')                                                            as standard_programmer_visibility
    , if(nw.content_form_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__content_form_id, -1), -1)                                                              as content_form_id
    , coalesce(request__context__stream_mode_id, -1)                                                                      as stream_mode_id
    , if(nw.sa_endpoint_owner_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_endpoint_owner_id, -1), -1)                                                   as standard_endpoint_owner_id
    , coalesce(nw.sa_endpoint_owner_visibility, 'FULL_VISIBILITY')                                                        as standard_endpoint_owner_visibility
    , if(nw.sa_endpoint_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_endpoint_id, -1), -1)                                                         as standard_endpoint_id
    , coalesce(nw.sa_endpoint_visibility, 'FULL_VISIBILITY')                                                              as standard_endpoint_visibility
    , coalesce(visitor__country_id, -1)                                                                                   as user_country_id
    , coalesce(nw.country_visibility, 'FULL_VISIBILITY')                                                                  as geo_country_visibility
    , coalesce(visitor__standard_device_type_child_id, -1)                                                                as standard_device_type_id
    , coalesce(request__context__standard_app_id, -1)                                                                     as standard_app_id
    , coalesce(visitor__standard_environment_id, -1)                                                                      as standard_environment_id
    , coalesce(visitor__standard_os_id, -1)                                                                               as standard_os_id
    , coalesce(visitor__platform_device_id, -1)                                                                           as delivered_platform_device_id
    , coalesce(nw.user_agent_visibility, 'FULL_VISIBILITY')                                                               as user_agent_visibility
    , coalesce(request__context__standard_app_bundle_id, -1)                                                              as standard_app_bundle_id
    , coalesce(request__context__standard_site_domain_id, -1)                                                             as standard_site_domain_id
    , if(nw.sa_channel_visibility is not null or nw.supply_source != 3, 
      coalesce(request__context__standard_channel_id, -1), -1)                                                            as standard_channel_id
    , coalesce(nw.sa_channel_visibility, 'FULL_VISIBILITY')                                                               as standard_channel_visibility
 
 
-- Request Attribution (6)
    -- , if(bitwise_and(coalesce(request__extra_flags, 0), 1073741824) > 0 and coalesce(nw.nw_role, '') = 'CRO', -3, coalesce(request__context__profile_id, -1))  as profile_id -- mark CANOE_PROGRAMMER_LINEAR with -3
    , coalesce(request__context__profile_id, -1)                                                                          as profile_id
    , coalesce(request__context__profile_type, 'UNKNOWN')                                                                 as profile_type
    , case
        when bitwise_and(request__flags, 32)>0           then  'No Selection'      /* No Selection */
        when coalesce(request__advertisement_delivered_count, coalesce(request__advertisement_count, 0))=0 then 'Empty'           /* Selection without Ads in Response */
        else                                                   'Filled'            /* Selection with Ads in Response */
    end                                                                                                                   as request_fill_status
    , if(bitwise_and(coalesce(request__extra_flags,0), 1024)>0, true, false)                                              as live_linear_indicator          
    , if(bitwise_and(coalesce(request__extra_flags2,0), 8)>0, true, false)                                                as ssp_bidder_indicator
    , if(bitwise_and(coalesce(bit_flag, 0), bitwise_shift_left(1, 40,64))>0, true, false)                                 as partner_tag_indicator
 
-- Slot Attribution (6)
    , array[coalesce(slot__time_position_class, 'Unknown')]                                                               as time_position_classes
    , coalesce(slot__normalized_ad_unit_id, -1)                                                                           as slot_ad_unit_id
    , case
        when slot__sequence is null then 'Null'
        when slot__sequence > 5 then '5+'
        else cast(slot__sequence as varchar)
    end                                                                                                                   as slot_sequence_normalized     
    , 'Included'                                                                                                          as slot_user_drop_off            
    , if(bitwise_and(coalesce(slot__flags, 0), 8)>0, 'Yes', 'No')                                                         as slot_removed_by_ux_indicator
    , if(bitwise_and(coalesce(nw.bit_flag, 0), bitwise_shift_left(1, 60, 64))>0, 'Yes', 'No')                             as slot_removed_by_constrained_indicator      
    , case
        when slot__time_position_class='overlay' and slot__num_ads=0 and slot__max_ads>0 then 'Empty - Slots with Avails'
        when slot__time_position_class='overlay' and slot__num_ads=0 and slot__max_ads=0 then 'Empty - Slots without Avails'
        when slot__time_position_class='overlay' and slot__num_ads=slot__max_ads then 'Fully Filled'
        when slot__time_position_class='overlay' and slot__num_ads>0 and slot__num_ads<slot__max_ads then 'Partially Filled' 
        when slot__num_ads=0 and coalesce(slot__unfilled_avails , 0)>0 then 'Empty - Slots with Avails'
        when slot__num_ads=0 and slot__unfilled_avails=0 then 'Empty - Slots without Avails'
        when slot__unfilled_avails=0  then 'Fully Filled'
        when slot__num_ads>0 and slot__unfilled_avails>0  then 'Partially Filled'
        else 'Unknown'
    end                                                                                                                  as slot_fill_status
-- Ad Attribution (7)
    , if(is_extra_item_owner = true,
        if(bitwise_and(coalesce(advertisement__entity_flags, 0), bitwise_shift_left(1, 35, 64))>0, 'Yes', 'No'),
        'Not Applicable')                                                                                                as evergreen_ad_indicator
    , if(is_extra_item_owner = true,
        if(bitwise_and(coalesce(advertisement__entity_flags, 0), bitwise_shift_left(1, 2 , 64))>0, 'Yes', 'No'),
        'Not Applicable')                                                                                                as promo_ad_indicator
    , case
        -- 'Direct Sold'
        when nw.sales_channel = 2 then if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier, 'UNKNOWN'), coalesce(advertisement__unified_priority__priority_tier,'UNKNOWN'))
        -- 'Reseller Sold'
        when nw.sales_channel = 3 then coalesce(rule_priority_tier, 'UNKNOWN')
        -- 'Programmatic'
        when nw.sales_channel = 4 then if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier, 'UNKNOWN'), 
            case 
                when coalesce(candidate__internal_deal_id, -1)>0 then coalesce(candidate__unified_deal_priority__priority_tier,'UNKNOWN')   
                when coalesce(candidate__buyer_group_id, -1)>0 then coalesce(rule_priority_tier,'UNKNOWN')
                else 'UNKNOWN'
            end)
         -- 'Partner Tag / Partner Trading(MPP) /Marketplace Platform Exchange(MPE)'     
        when nw.sales_channel in (5,6) then coalesce(nw.order_priority_tier, 'UNKNOWN')
        else 'UNKNOWN'
    end                                                                                                                  as priority_tier
    , case
        -- 'Direct Sold'
        WHEN sales_channel = 2 then if(nw_role = 'CRO', advertisement__effective_unified_priority__sub_priority_value, advertisement__unified_priority__sub_priority_value)
        -- 'MRM2MRM'
        when sales_channel = 3 then rule_priority_value
        -- 'Programmatic'
        when sales_channel = 4 then if(nw_role = 'CRO', 
            if(coalesce(advertisement__effective_unified_priority__priority_tier, 'UNKNOWN')= 'TIER_1'
                and advertisement__effective_unified_priority__sub_priority_value <= 5, advertisement__effective_unified_priority__sub_priority_value+25, advertisement__effective_unified_priority__sub_priority_value),  -- First Look Deal sub_priority_value is transformed to -5~5 
            case 
                when coalesce(candidate__internal_deal_id, -1)>0 then candidate__unified_deal_priority__sub_priority_value   
                when coalesce(candidate__buyer_group_id, -1)>0 then rule_priority_value
                else null
            end)
        -- 'Partner Trading(MPP) / Partner Tag / Marketplace Platform Exchange(MPE)'
        when sales_channel in (5,6) then outbound_order_priority_value
    else null end                                                                                                          as priority_value
    , if(is_extra_item_owner = true, advertisement__unified_priority__sub_priority_value, null)                            as ad_meta_priority_value -- ad owner 
    , if(is_extra_item_owner = true and bitwise_and(advertisement__flags, 1024) > 0, 1, 0)                                 as meet_schedule
    , case
        -- 'Direct Sold'
        WHEN sales_channel = 2
            then (
                case
                    when if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier,'UNKNOWN'), coalesce(advertisement__unified_priority__priority_tier,'UNKNOWN')) in ('TIER_1','TIER_2') then coalesce(advertisement__ad_priority_type,'UNKNOWN')
                    when if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier,'UNKNOWN'), coalesce(advertisement__unified_priority__priority_tier,'UNKNOWN')) in ('TIER_3','TIER_4') then if(coalesce(advertisement__ad_priority_type,'UNKNOWN')='UNKNOWN',if(bitwise_and(advertisement__entity_flags, 1) > 0 , 'GUARANTEED','PREEMPTIBLE'),concat(if(bitwise_and(advertisement__entity_flags, 1) > 0 , 'GUARANTEED','PREEMPTIBLE'),'_',coalesce(advertisement__ad_priority_type,'UNKNOWN')))
                    when if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier,'UNKNOWN'), coalesce(advertisement__unified_priority__priority_tier,'UNKNOWN')) in ('TIER_6') then 'HOUSE_ADS'
                else coalesce(advertisement__ad_priority_type,'UNKNOWN') end
            )
        -- 'MRM2MRM/Reseller Tag'
        when sales_channel = 3  then (
                case
                    when coalesce(rule_priority,'UNKNOWN') = 'YOU_FIRST' then 'HARD_GUARANTEED_WITH_PASSBACK'
                    when coalesce(rule_priority,'UNKNOWN') = 'ME_FIRST' then 'BACKFILL_ONLY'
                    when coalesce(rule_priority,'UNKNOWN') = 'HARD_GUARANTEED' then 'HARD_GUARANTEED_WITHOUT_PASSBACK'
                else coalesce(rule_priority,'UNKNOWN') end
            )
        -- 'Programmatic'
        when sales_channel = 4 then (
                case when coalesce(candidate__internal_deal_id,-1)>0 then (
                    case when coalesce(candidate__deal_type,'NA') = 'PROGRAMMATIC_GUARANTEED_TRADING_DESK_DEAL' then 'PROGRAMMATIC_GUARANTEED'
                            when coalesce(candidate__deal_type,'NA') = 'BIDDABLE_GUARANTEED_DEAL' then 'BIDDABLE_GUARANTEED'
                            when coalesce(candidate__deal_type,'NA') = 'FIRST_LOOK_DEAL' then 'FIRST_LOOK'
                        else coalesce(candidate__deal_type,'NA') end)
                    else (
                        case
                            when coalesce(rule_priority,'UNKNOWN') = 'ME_FIRST' then 'BACKFILL_ONLY'
                        else coalesce(rule_priority,'UNKNOWN') end
                        )
                end
            )
        -- 'Partner Tag / Partner Trading(MPP) /Marketplace Platform Exchange(MPE)'
        when sales_channel in (5,6) then if(coalesce(order_priority,'UNKNOWN') = 'PRIORITY_NONE','INVENTORY_SPLIT',replace(coalesce(order_priority,'NA'),'PRIORITY_',''))
        else 'UNKNOWN' end as priority_type
 
    -- Traffic Type
    , coalesce(request__traffic_type, 0)                                as request_traffic_type
    , 0                                                                 as ack_traffic_type
 
-- Ad Level Dimensions(18)
    , coalesce(inbound_order_id, cast(-1 as bigint))                                                                    as inbound_order_id
    , coalesce(outbound_order_id, cast(-1 as bigint))                                                                   as outbound_order_id
    , coalesce(outbound_exchange_order_id, cast(-1 as bigint))                                                          as outbound_exchange_order_id
    , if(demand_dim_awareability , coalesce(candidate__dsp_id, -1), -1)                                                 as dsp_id
    , if(demand_dim_awareability , coalesce(candidate__buyer_platform_id, -1), -1)                                      as buyer_platform_id
    , if(deal_awareability , coalesce(candidate__internal_deal_id, -1), -1)                                             as deal_id
    , if(deal_awareability , coalesce(candidate__buyer_group_id, -1), -1)                                               as buyer_group_id
    , if(deal_awareability , coalesce(candidate__buyer_id, -1), -1)                                                     as buyer_id
    , if(deal_awareability , coalesce(candidate__bidding_buyer_id, -1), -1)                                             as bidding_buyer_id
    , if(demand_dim_awareability , coalesce(advertisement__market_ad_id, coalesce(candidate__market_ad_id, -1)), -1)    as market_ad_id
    , if(network_is_ad_owner,coalesce(advertisement__ad_id, -1),-1)                                                     as ad_id
    , if(network_is_ad_owner,coalesce(advertisement__placement_id, -1),-1)                                              as placement_id
    , if(network_is_ad_owner,coalesce(advertisement__creative_id, -1),-1)                                               as creative_id
  
    , coalesce(nw.global_currency_id, -1)                                                                               as global_currency_id
    , coalesce(request__global_currency_version, '')                                                                    as global_currency_version
    , coalesce(advertisement__global_advertiser_ids, array[])                                                           as global_advertiser_ids
    , coalesce(advertisement__global_brand_ids, array[])                                                                as global_brand_ids
    , if(network_is_ad_owner, coalesce(advertisement__advertiser_id, -1), -1)                                           as local_advertiser_id

-- Process Time
    , process_batch_id                                                                                                  as process_batch_id
 
-- Ad Metrics (6)
    , sum(if(advertisement__is_fallback = false and advertisement__is_sstf_fallback = false, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as placed_ads
    , sum(if(advertisement__is_fallback = false and advertisement__is_undeliverable = true, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as undeliverable_placed_ads
    , sum(if(advertisement__is_fallback = true or advertisement__is_sstf_fallback = true, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as placed_fallback_ads
    , sum(if(advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512)>0 and advertisement__is_sstf_fallback = false, 1, 0)
        * coalesce(request__multiplier, 1) 
        * coalesce(request__magnifier, 1) 
        * coalesce(request__log_sampling__magnifier, 1))                                                                as placed_ads_has_fallback
    , sum(if(advertisement__is_undeliverable = false and (bitwise_and(coalesce(advertisement__flags, 0), 33554432)>0 or advertisement__is_fallback = false), 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                 as filled_ads
    , sum(if(advertisement__is_undeliverable = false and (bitwise_and(coalesce(advertisement__flags, 0), 33554432)>0 or advertisement__is_fallback = false), coalesce(advertisement__duration, 0), 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                 as filled_ads_duration
    , sum(if(advertisement__is_undeliverable = false and bitwise_and(coalesce(advertisement__flags, 0), 33554432)>0, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as filled_ads_sstf_fallback

 -- ad error metrics(73)
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'FLOOR_PRICE_NOTMET' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_floor_price_notmet
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'FLOOR_PRICE_NOTMET' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_floor_price_notmet_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'FLOOR_PRICE_NOTMET' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_floor_price_notmet
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'UNEXPECTED_EXTERNAL_AD_ID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_unexpected_external_ad_id
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'UNEXPECTED_EXTERNAL_AD_ID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_unexpected_external_ad_id_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'UNEXPECTED_EXTERNAL_AD_ID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_unexpected_external_ad_id
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'NO_VALID_CREATIVE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_valid_creative
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'NO_VALID_CREATIVE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_valid_creative_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'NO_VALID_CREATIVE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_valid_creative
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'MALFORMED_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_malformed_response
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'MALFORMED_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_malformed_response_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'MALFORMED_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_malformed_response
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'COMPETITION_FAILURE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_competition_failure
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'COMPETITION_FAILURE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_competition_failure_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'COMPETITION_FAILURE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_competition_failure
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'JITT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_jitt_rendition_required
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'JITT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_jitt_rendition_required_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'JITT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_jitt_rendition_required
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'NO_SLOT_SELECTED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_slot_selected
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'NO_SLOT_SELECTED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_slot_selected_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'NO_SLOT_SELECTED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_slot_selected
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'EMPTY_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_empty_response
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'EMPTY_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_empty_response_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'EMPTY_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_empty_response
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'INAPPLICABLE_FOR_HTTPS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_inapplicable_for_https
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'INAPPLICABLE_FOR_HTTPS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_inapplicable_for_https_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'INAPPLICABLE_FOR_HTTPS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_inapplicable_for_https
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'AD_PENDING_APPROVAL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_ad_pending_approval
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'AD_PENDING_APPROVAL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_ad_pending_approval_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'AD_PENDING_APPROVAL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_ad_pending_approval
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'BID_RESPONSE_ID_NOMATCH' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_bid_response_id_nomatch
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'BID_RESPONSE_ID_NOMATCH' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_bid_response_id_nomatch_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'BID_RESPONSE_ID_NOMATCH' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_bid_response_id_nomatch
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'WRAPPER_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_wrapper_timeout
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'WRAPPER_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_wrapper_timeout_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'WRAPPER_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_wrapper_timeout
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'COMPLIANCE_NOT_APPROVED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_compliance_not_approved
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'COMPLIANCE_NOT_APPROVED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_compliance_not_approved_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'COMPLIANCE_NOT_APPROVED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_compliance_not_approved
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_http_error
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_http_error_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_http_error
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'NO_BIDS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_bids
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'NO_BIDS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_bids_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'NO_BIDS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_bids
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_external_creative_profile_check_failed
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_external_creative_profile_check_failed_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_external_creative_profile_check_failed
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'AUCTION_MAX_AD_DURATION_EXCEEDED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_auction_max_ad_duration_exceeded
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'AUCTION_MAX_AD_DURATION_EXCEEDED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_auction_max_ad_duration_exceeded_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'AUCTION_MAX_AD_DURATION_EXCEEDED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_auction_max_ad_duration_exceeded
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'WRAPPER_HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_wrapper_http_error
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'WRAPPER_HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_wrapper_http_error_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'WRAPPER_HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_wrapper_http_error
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_timeout
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_timeout_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_timeout
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'NO_CONTENT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_content
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'NO_CONTENT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_content_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'NO_CONTENT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_content
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'MAX_WRAPPER_REDIRECT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_max_wrapper_redirect
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'MAX_WRAPPER_REDIRECT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_max_wrapper_redirect_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'MAX_WRAPPER_REDIRECT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_max_wrapper_redirect
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'EMPTY_BID_DEALID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_empty_bid_dealid
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'EMPTY_BID_DEALID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_empty_bid_dealid_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'EMPTY_BID_DEALID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_empty_bid_dealid
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'INVALID_WRAPPER_URL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_invalid_wrapper_url
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'INVALID_WRAPPER_URL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_invalid_wrapper_url_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'INVALID_WRAPPER_URL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_invalid_wrapper_url
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_profile_check_failed
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_profile_check_failed_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_profile_check_failed
-- add new errors existing on PRD
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'NO_VALID_CURRENCY' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_valid_currency
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'NO_VALID_CURRENCY' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_valid_currency_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'NO_VALID_CURRENCY' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_valid_currency
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'CLIENT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_client_rendition_required
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'CLIENT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_client_rendition_required_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'CLIENT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_client_rendition_required
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'UNKNOWN_SEAT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_unknown_seat
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'UNKNOWN_SEAT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_unknown_seat_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'UNKNOWN_SEAT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_unknown_seat
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'PLAYLIST_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_playlist_timeout
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'PLAYLIST_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_playlist_timeout_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'PLAYLIST_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_playlist_timeout
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'NO_AD_MARKUP' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_ad_markup
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'NO_AD_MARKUP' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_ad_markup_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and coalesce(candidate__error,advertisement__error) = 'NO_AD_MARKUP' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_ad_markup

-- delivery metrics(15)
    , cast(0 as bigint) as gross_ad_views
    , cast(0 as bigint) as gross_ad_views_primary
    , cast(0 as bigint) as gross_ad_views_fallback
    , cast(0 as bigint) as revenue
    , cast(0 as bigint) as co_revenue
    , cast(0 as bigint) as d_revenue
    , cast(0 as bigint) as r_revenue
    , cast(0 as bigint) as no_ad_views
    , cast(0 as bigint) as clicks
    , cast(0 as bigint) as no_clicks
    , cast(0 as bigint) as first_quartile
    , cast(0 as bigint) as middle_quartile
    , cast(0 as bigint) as third_quartile
    , cast(0 as bigint) as complete_quartile
    , cast(0 as bigint) as can_quartile

    , sum(if(advertisement__is_undeliverable = false, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                            as selected_ads
    , if(advertisement__is_fallback = false or (advertisement__is_undeliverable = false and bitwise_and(coalesce(advertisement__flags, 0), 33554432)>0), 'Primary', 'Fallback')   as primary_ad_indicator
    , if(nw.sales_channel=6, nw.outbound_listing_id, array[])                                                                       as outbound_exchange_listing_id
     -- 26 adm errors
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

    -- 37 vast errors
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

    , cast(0 as bigint) as ack_err_adm_total
    , cast(0 as bigint) as ack_err_vast_total

    , sum(case when advertisement__is_undeliverable = true then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err

    , coalesce(nw.content_form_visibility, 'FULL_VISIBILITY') as content_form_visibility
    , nw.inbound_order_type             as inbound_order_type
    , nw.inbound_order_transaction_type as inbound_order_transaction_type
    , date_trunc('HOUR', request__timestamp) as event_date
from etl.public_test1.ad
cross join unnest (
    partners__network_id,
    partners__site_id,
    partners__site_section_id,
    partners__distributor_network_id,
    partners__content_owner_network_id,
    partners__reseller_network_id,
    partners__sales_channel,
    partners__role,
    partners__supply_source,
    partners__geo_country_visibility__report_aggregate,
    partners__standard_brand_visibility__report_aggregate,
    partners__standard_channel_visibility__report_aggregate,
    partners__standard_programmer_visibility__report_aggregate,
    partners__standard_endpoint_visibility__report_aggregate,
    partners__standard_endpoint_owner_visibility__report_aggregate,
    partners__user_agent_visibility__report_aggregate,
    partners__content_form_visibility__report_aggregate,
    partners__global_currency_id,
    partners__network_is_extra_item_owner,
    partners__network_is_ad_owner,
    partners__demand_dim_awareability,
    partners__deal_awareability,
    partners__outbound_order_id, 
    partners__outbound_exchange_order_id,
    partners__outbound_listing_id,
    partners__inbound_order_id,
    partners__inbound_order_type,
    partners__inbound_order_transaction_type,
    partners__unified_outbound_order_priority__priority_tier,
    partners__unified_outbound_order_priority__sub_priority_value,
    partners__outbound_order_priority_type,
    partners__unified_rule_priority__priority_tier,
    partners__unified_rule_priority__sub_priority_value,
    partners__rule_type_priority,
    partners__bit_flags
) as nw (
    nw_id,
    site_id,
    site_section_id,
    distributor_id,
    co_id,
    reseller_id,
    sales_channel,
    nw_role,
    supply_source,
    country_visibility,
    sa_brand_visibility,
    sa_channel_visibility,
    sa_programmer_visibility,
    sa_endpoint_visibility,
    sa_endpoint_owner_visibility,
    user_agent_visibility,
    content_form_visibility,
    global_currency_id,
    is_extra_item_owner,
    network_is_ad_owner,
    demand_dim_awareability,
    deal_awareability,
    outbound_order_id, 
    outbound_exchange_order_id,
    outbound_listing_id,
    inbound_order_id,
    inbound_order_type,
    inbound_order_transaction_type,
    order_priority_tier,
    outbound_order_priority_value,
    order_priority,
    rule_priority_tier,
    rule_priority_value,
    rule_priority,
    bit_flag
)
left join db.default.d_network reseller on reseller.id = coalesce(nw.reseller_id, -1)
where  
    process_batch_id = '${arena.presto.var.process_batch_id}'
    and bitwise_and(slot__flags, 64) = 0                                                    -- No Parent Slot
    and coalesce(nw.nw_role, '') in ('CRO', 'R')                                           
    and coalesce(advertisement__is_bumper, false) = false                                   -- Remove Bumper Ad
    and supply_source != 4                                                                          -- filter out DSP shell networks                     
    and not(bitwise_and(coalesce(request__extra_flags2,0), 8) > 0 and coalesce(nw.nw_role, '') = 'CRO')  -- filter out SSP shell networks
    and bitwise_and(bit_flag, bitwise_shift_left(1, 41, 64)) = 0                                    -- filter out partner tag buyer

group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,189,190,259,260,261,262
 
union all
 
-- Ads (Removed User Drop Off)
select
    cast(16 as int) as process_stage
 
-- Network Chain (10)
    , coalesce(nw.nw_id, -1)                                                                                              as network_id
    , coalesce(nw.co_id, -1)                                                                                              as content_owner_id
    -- , if(bitwise_and(coalesce(request__extra_flags, 0), 1073741824) > 0 and coalesce(nw.nw_role, '') = 'CRO', -3, coalesce(nw.distributor_id, -1))   as distributor_id -- mark CANOE_PROGRAMMER_LINEAR with -3
    , coalesce(nw.distributor_id, -1)                                                                                     as distributor_id
    , coalesce(nw.nw_role, '')                                                                                            as transaction_type
    , coalesce(nw.reseller_id, -1)                                                                                        as reseller_id
    , if(nw.sales_channel = 4, 'NO_VISIBILITY', 'FULL_VISIBILITY')                                                        as reseller_visibility
    , coalesce(reseller.network_type, 'UNKNOWN')                                                                          as reseller_network_type
    , coalesce(nw.supply_source, -1)                                                                                      as supply_source
    , coalesce(nw.sales_channel, -1)                                                                                      as sales_channel
    , case
      when coalesce(nw.sales_channel, -1) = 2 then 'Direct Sold'
      when coalesce(nw.sales_channel, -1) = 3 and reseller.network_type = 'FULL' then 'MRM Partner'
      when coalesce(nw.sales_channel, -1) = 3 and reseller.network_type = 'INTERNAL' then 'Reseller Sold - Reseller Tag'
      when coalesce(nw.sales_channel, -1) = 4 then 'Programmatic'
      when coalesce(nw.sales_channel, -1) = 5 then 'MRM Partner'
      when coalesce(nw.sales_channel, -1) = 6 then 'MRM Partner'
      else 'Unknown'
    end                                                                                                                   as sales_strategy

-- Raw Inventory (2)
    , coalesce(nw.site_id, -1)                                                                                            as site_id
    , coalesce(nw.site_section_id, -1)                                                                                    as site_section_id
 
 
-- SA Content (21)
    , coalesce(request__context__standard_publisher_id, -1)                                                               as standard_publisher_id
    , if(nw.sa_brand_visibility is not null or nw.supply_source != 3, 
        coalesce(request__context__standard_brand_id, -1), -1)                                                            as standard_brand_id
    , coalesce(nw.sa_brand_visibility, 'FULL_VISIBILITY')                                                                 as standard_brand_visibility
    , if(nw.sa_programmer_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_programmer_id, -1), -1)                                                       as standard_programmer_id
    , coalesce(nw.sa_programmer_visibility, 'FULL_VISIBILITY')                                                            as standard_programmer_visibility
    , if(nw.content_form_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__content_form_id, -1), -1)                                                              as content_form_id
    , coalesce(request__context__stream_mode_id, -1)                                                                      as stream_mode_id
    , if(nw.sa_endpoint_owner_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_endpoint_owner_id, -1), -1)                                                   as standard_endpoint_owner_id
    , coalesce(nw.sa_endpoint_owner_visibility, 'FULL_VISIBILITY')                                                        as standard_endpoint_owner_visibility
    , if(nw.sa_endpoint_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_endpoint_id, -1), -1)                                                         as standard_endpoint_id
    , coalesce(nw.sa_endpoint_visibility, 'FULL_VISIBILITY')                                                              as standard_endpoint_visibility
    , coalesce(visitor__country_id, -1)                                                                                   as user_country_id
    , coalesce(nw.country_visibility, 'FULL_VISIBILITY')                                                                  as geo_country_visibility
    , coalesce(visitor__standard_device_type_child_id, -1)                                                                as standard_device_type_id
    , coalesce(request__context__standard_app_id, -1)                                                                     as standard_app_id
    , coalesce(visitor__standard_environment_id, -1)                                                                      as standard_environment_id
    , coalesce(visitor__standard_os_id, -1)                                                                               as standard_os_id
    , coalesce(visitor__platform_device_id, -1)                                                                           as delivered_platform_device_id
    , coalesce(nw.user_agent_visibility, 'FULL_VISIBILITY')                                                               as user_agent_visibility
    , coalesce(request__context__standard_app_bundle_id, -1)                                                              as standard_app_bundle_id
    , coalesce(request__context__standard_site_domain_id, -1)                                                             as standard_site_domain_id
    , if(nw.sa_channel_visibility is not null or nw.supply_source != 3,
      coalesce(request__context__standard_channel_id, -1), -1)                                                            as standard_channel_id
    , coalesce(nw.sa_channel_visibility, 'FULL_VISIBILITY')                                                               as standard_channel_visibility
 
 
-- Request Attribution (6)
    -- , if(bitwise_and(coalesce(request__extra_flags, 0), 1073741824) > 0 and coalesce(nw.nw_role, '') = 'CRO', -3, coalesce(request__context__profile_id, -1))  as profile_id -- mark CANOE_PROGRAMMER_LINEAR with -3
    , coalesce(request__context__profile_id, -1)                                                                          as profile_id
    , coalesce(request__context__profile_type, 'UNKNOWN')                                                                 as profile_type
    , case
        when bitwise_and(request__flags, 32)>0           then  'No Selection'      /* No Selection */
        when coalesce(request__advertisement_delivered_count, coalesce(request__advertisement_count, 0))=0 then 'Empty'             /* Selection without Ads in Response */
        else                                                   'Filled'            /* Selection with Ads in Response */
    end                                                                                                                   as request_fill_status 
    , if(bitwise_and(coalesce(request__extra_flags,0), 1024)>0, true, false)                                              as live_linear_indicator          
    , if(bitwise_and(coalesce(request__extra_flags2,0), 8)>0, true, false)                                                as ssp_bidder_indicator
    , if(bitwise_and(coalesce(bit_flag, 0), bitwise_shift_left(1, 40,64))>0, true, false)                                 as partner_tag_indicator -- seller
 
-- Slot Attribution (6)
    , array[coalesce(slot__time_position_class, 'Unknown')]                                                               as time_position_classes
    , coalesce(slot__normalized_ad_unit_id, -1)                                                                           as slot_ad_unit_id
    , case
        when slot__sequence is null then 'Null'
        when slot__sequence > 5 then '5+'
        else cast(slot__sequence as varchar)
    end                                                                                                                   as slot_sequence_normalized     
    , 'Removed'                                                                                                           as slot_user_drop_off            
    , if(bitwise_and(coalesce(slot__flags, 0), 8)>0, 'Yes', 'No')                                                         as slot_removed_by_ux_indicator
    , if(bitwise_and(coalesce(nw.bit_flag, 0), bitwise_shift_left(1, 60, 64))>0, 'Yes', 'No')                             as slot_removed_by_constrained_indicator      
    , case
        when slot__time_position_class='overlay' and slot__num_ads=0 and slot__max_ads>0 then 'Empty - Slots with Avails'
        when slot__time_position_class='overlay' and slot__num_ads=0 and slot__max_ads=0 then 'Empty - Slots without Avails'
        when slot__time_position_class='overlay' and slot__num_ads=slot__max_ads then 'Fully Filled'
        when slot__time_position_class='overlay' and slot__num_ads>0 and slot__num_ads<slot__max_ads then 'Partially Filled'
        when slot__num_ads=0 and coalesce(slot__unfilled_avails , 0)>0 then 'Empty - Slots with Avails'
        when slot__num_ads=0 and slot__unfilled_avails=0 then 'Empty - Slots without Avails'
        when slot__unfilled_avails=0  then 'Fully Filled'
        when slot__num_ads>0 and slot__unfilled_avails>0  then 'Partially Filled'
        else 'Unknown'
    end                                                                                                                   as slot_fill_status
 
-- Ad Attribution (6)
    , if(is_extra_item_owner = true,
        if(bitwise_and(coalesce(a.advertisement__entity_flags, 0), bitwise_shift_left(1, 35, 64))>0, 'Yes', 'No'),
        'Not Applicable')                                                                                                 as evergreen_ad_indicator
    , if(is_extra_item_owner = true,
        if(bitwise_and(coalesce(a.advertisement__entity_flags, 0), bitwise_shift_left(1, 2 , 64))>0, 'Yes', 'No'),
        'Not Applicable')                                                                                                 as promo_ad_indicator
    , case
        -- 'Direct Sold'
        when nw.sales_channel = 2 then if(nw.nw_role = 'CRO', coalesce(a.advertisement__effective_unified_priority__priority_tier, 'UNKNOWN'), coalesce(a.advertisement__unified_priority__priority_tier,'UNKNOWN'))
        -- 'Reseller Sold'
        when nw.sales_channel = 3 then coalesce(rule_priority_tier, 'UNKNOWN')
        -- 'Programmatic'
        when nw.sales_channel = 4 then if(nw.nw_role = 'CRO', coalesce(a.advertisement__effective_unified_priority__priority_tier, 'UNKNOWN'), 
            case 
                when coalesce(a.candidate__internal_deal_id, -1)>0 then coalesce(a.candidate__unified_deal_priority__priority_tier,'UNKNOWN')   
                when coalesce(a.candidate__buyer_group_id, -1)>0 then coalesce(rule_priority_tier,'UNKNOWN')
                else 'UNKNOWN'
            end)
        -- 'Partner Tag / Partner Trading(MPP) /Marketplace Platform Exchange(MPE)'     
        when nw.sales_channel in (5,6) then coalesce(nw.outbound_order_priority_tier, 'UNKNOWN')
        else 'UNKNOWN'
    end                                                                                                                     as priority_tier                                                                                                               
    , case
        -- 'Direct Sold'
        WHEN sales_channel = 2 then if(nw_role = 'CRO', a.advertisement__effective_unified_priority__sub_priority_value, a.advertisement__unified_priority__sub_priority_value)
        -- 'MRM2MRM'
        when sales_channel = 3 then nw.rule_priority_value
        -- 'Programmatic'
        when sales_channel = 4 then if(nw_role = 'CRO',
            if(coalesce(a.advertisement__effective_unified_priority__priority_tier, 'UNKNOWN')= 'TIER_1'
                and a.advertisement__effective_unified_priority__sub_priority_value <= 5, a.advertisement__effective_unified_priority__sub_priority_value+25, a.advertisement__effective_unified_priority__sub_priority_value),  -- First Look Deal sub_priority_value is transformed to -5~5
            case 
                when coalesce(a.candidate__internal_deal_id, -1)>0 then a.candidate__unified_deal_priority__sub_priority_value   
                when coalesce(a.candidate__buyer_group_id, -1)>0 then nw.rule_priority_value
                else null
            end)
        -- 'Partner Trading(MPP) / Partner Tag / Marketplace Platform Exchange(MPE)'
        when sales_channel in (5,6) then outbound_order_priority_value
    else null end                                                                                                          as priority_value
    , if(nw.is_extra_item_owner = true, a.advertisement__unified_priority__sub_priority_value, null)                       as ad_meta_priority_value -- ad owner 
    , if(is_extra_item_owner = true and bitwise_and(a.advertisement__flags, 1024) > 0, 1, 0)                               as meet_schedule
    , case
        -- 'Direct Sold'
        WHEN sales_channel = 2
            then (
                case
                    when if(nw_role = 'CRO', coalesce(a.advertisement__effective_unified_priority__priority_tier,'UNKNOWN'), coalesce(a.advertisement__unified_priority__priority_tier,'UNKNOWN')) in ('TIER_1','TIER_2') then coalesce(a.advertisement__ad_priority_type,'UNKNOWN')
                    when if(nw_role = 'CRO', coalesce(a.advertisement__effective_unified_priority__priority_tier,'UNKNOWN'), coalesce(a.advertisement__unified_priority__priority_tier,'UNKNOWN')) in ('TIER_3','TIER_4') then if(coalesce(a.advertisement__ad_priority_type,'UNKNOWN')='UNKNOWN',if(bitwise_and(a.advertisement__entity_flags, 1) > 0 , 'GUARANTEED','PREEMPTIBLE'),concat(if(bitwise_and(a.advertisement__entity_flags, 1) > 0 , 'GUARANTEED','PREEMPTIBLE'),'_',coalesce(a.advertisement__ad_priority_type,'UNKNOWN')))
                    when if(nw_role = 'CRO', coalesce(a.advertisement__effective_unified_priority__priority_tier,'UNKNOWN'), coalesce(a.advertisement__unified_priority__priority_tier,'UNKNOWN')) in ('TIER_6') then 'HOUSE_ADS'
                else coalesce(a.advertisement__ad_priority_type,'UNKNOWN') end
            )
        -- 'MRM2MRM/Reseller Tag'
        when sales_channel = 3  then (
                case
                    when coalesce(rule_priority,'UNKNOWN') = 'YOU_FIRST' then 'HARD_GUARANTEED_WITH_PASSBACK'
                    when coalesce(rule_priority,'UNKNOWN') = 'ME_FIRST' then 'BACKFILL_ONLY'
                    when coalesce(rule_priority,'UNKNOWN') = 'HARD_GUARANTEED' then 'HARD_GUARANTEED_WITHOUT_PASSBACK'
                else coalesce(rule_priority,'UNKNOWN') end
            )
        -- 'Programmatic'
        when sales_channel = 4 then (
                case when coalesce(a.candidate__internal_deal_id,-1)>0 then (
                    case when coalesce(a.candidate__deal_type,'NA') = 'PROGRAMMATIC_GUARANTEED_TRADING_DESK_DEAL' then 'PROGRAMMATIC_GUARANTEED'
                            when coalesce(a.candidate__deal_type,'NA') = 'BIDDABLE_GUARANTEED_DEAL' then 'BIDDABLE_GUARANTEED'
                            when coalesce(a.candidate__deal_type,'NA') = 'FIRST_LOOK_DEAL' then 'FIRST_LOOK'
                        else coalesce(a.candidate__deal_type,'NA') end)
                    else (
                        case
                            when coalesce(rule_priority,'UNKNOWN') = 'ME_FIRST' then 'BACKFILL_ONLY'
                        else coalesce(rule_priority,'UNKNOWN') end
                        )
                end
            )
        -- 'Partner Tag / Partner Trading(MPP) /Marketplace Platform Exchange(MPE)'
        when sales_channel in (5,6) then if(coalesce(order_priority,'UNKNOWN') = 'PRIORITY_NONE','INVENTORY_SPLIT',replace(coalesce(order_priority,'NA'),'PRIORITY_',''))
        else 'UNKNOWN' end as priority_type
 
    -- Traffic Type
    , coalesce(request__traffic_type, 0)                               as request_traffic_type
    , coalesce(ack__traffic_type, 0)                                   as ack_traffic_type
 
-- Ad Level Dimensions(18)
    , coalesce(inbound_order_id, cast(-1 as bigint)) as inbound_order_id
    , coalesce(outbound_order_id, cast(-1 as bigint)) as outbound_order_id
    , coalesce(outbound_exchange_order_id, cast(-1 as bigint)) as outbound_exchange_order_id
    , if(demand_dim_awareability , coalesce(a.candidate__dsp_id, -1), -1) as dsp_id
    , if(demand_dim_awareability , coalesce(a.candidate__buyer_platform_id, -1), -1) as buyer_platform_id
    , if(deal_awareability , coalesce(a.candidate__internal_deal_id, -1), -1) as deal_id
    , if(deal_awareability , coalesce(a.candidate__buyer_group_id, -1), -1) as buyer_group_id
    , if(deal_awareability , coalesce(a.candidate__buyer_id, -1), -1) as buyer_id
    , if(deal_awareability , coalesce(a.candidate__bidding_buyer_id, -1), -1) as bidding_buyer_id
    , if(demand_dim_awareability , coalesce(a.advertisement__market_ad_id, coalesce(a.candidate__market_ad_id, -1)), -1) as market_ad_id
    , if(network_is_ad_owner,coalesce(a.advertisement__ad_id, -1),-1) as ad_id
    , if(network_is_ad_owner,coalesce(a.advertisement__placement_id, -1),-1) as placement_id
    , if(network_is_ad_owner,coalesce(a.advertisement__creative_id, -1),-1) as creative_id
  
    , coalesce(nw.global_currency_id, -1) as global_currency_id
    , coalesce(request__global_currency_version, '') as global_currency_version
    , coalesce(a.advertisement__global_advertiser_ids, array[])                                                           as global_advertiser_ids
    , coalesce(a.advertisement__global_brand_ids, array[])                                                                as global_brand_ids
    , if(network_is_ad_owner, coalesce(a.advertisement__advertiser_id, -1), -1)                                           as local_advertiser_id

-- Process Time
    , process_batch_id                                                 as process_batch_id
 
 
-- Ad Metrics (6)
    , sum(if(a.advertisement__is_fallback = false and a.advertisement__is_sstf_fallback = false, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as placed_ads
    , sum(if(a.advertisement__is_fallback = false and a.advertisement__is_undeliverable = true, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as undeliverable_placed_ads
    , sum(if(a.advertisement__is_fallback = true or a.advertisement__is_sstf_fallback = true, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as placed_fallback_ads
    , sum(if(a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512)>0 and a.advertisement__is_sstf_fallback = false, 1, 0)
        * coalesce(request__multiplier, 1) 
        * coalesce(request__magnifier, 1) 
        * coalesce(request__log_sampling__magnifier, 1))                                                                as placed_ads_has_fallback
    , sum(if(a.advertisement__is_undeliverable = false and (bitwise_and(coalesce(a.advertisement__flags, 0), 33554432)>0 or a.advertisement__is_fallback = false), 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                 as filled_ads
    , sum(if(a.advertisement__is_undeliverable = false and (bitwise_and(coalesce(a.advertisement__flags, 0), 33554432)>0 or a.advertisement__is_fallback = false), coalesce(a.advertisement__duration, 0), 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                 as filled_ads_duration
    , sum(if(a.advertisement__is_undeliverable = false and bitwise_and(coalesce(a.advertisement__flags, 0), 33554432)>0, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as filled_ads_sstf_fallback

  -- ad error metrics(73)
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'FLOOR_PRICE_NOTMET' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_floor_price_notmet
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'FLOOR_PRICE_NOTMET' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_floor_price_notmet_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'FLOOR_PRICE_NOTMET' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_floor_price_notmet
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'UNEXPECTED_EXTERNAL_AD_ID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_unexpected_external_ad_id
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'UNEXPECTED_EXTERNAL_AD_ID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_unexpected_external_ad_id_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'UNEXPECTED_EXTERNAL_AD_ID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_unexpected_external_ad_id
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'NO_VALID_CREATIVE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_valid_creative
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'NO_VALID_CREATIVE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_valid_creative_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'NO_VALID_CREATIVE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_valid_creative
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'MALFORMED_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_malformed_response
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'MALFORMED_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_malformed_response_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'MALFORMED_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_malformed_response
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'COMPETITION_FAILURE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_competition_failure
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'COMPETITION_FAILURE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_competition_failure_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'COMPETITION_FAILURE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_competition_failure
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'JITT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_jitt_rendition_required
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'JITT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_jitt_rendition_required_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'JITT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_jitt_rendition_required
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'NO_SLOT_SELECTED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_slot_selected
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'NO_SLOT_SELECTED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_slot_selected_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'NO_SLOT_SELECTED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_slot_selected
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'EMPTY_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_empty_response
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'EMPTY_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_empty_response_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'EMPTY_RESPONSE' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_empty_response
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'INAPPLICABLE_FOR_HTTPS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_inapplicable_for_https
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'INAPPLICABLE_FOR_HTTPS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_inapplicable_for_https_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'INAPPLICABLE_FOR_HTTPS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_inapplicable_for_https
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'AD_PENDING_APPROVAL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_ad_pending_approval
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'AD_PENDING_APPROVAL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_ad_pending_approval_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'AD_PENDING_APPROVAL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_ad_pending_approval
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'BID_RESPONSE_ID_NOMATCH' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_bid_response_id_nomatch
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'BID_RESPONSE_ID_NOMATCH' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_bid_response_id_nomatch_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'BID_RESPONSE_ID_NOMATCH' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_bid_response_id_nomatch
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'WRAPPER_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_wrapper_timeout
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'WRAPPER_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_wrapper_timeout_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'WRAPPER_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_wrapper_timeout
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'COMPLIANCE_NOT_APPROVED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_compliance_not_approved
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'COMPLIANCE_NOT_APPROVED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_compliance_not_approved_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'COMPLIANCE_NOT_APPROVED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_compliance_not_approved
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_http_error
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_http_error_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_http_error
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'NO_BIDS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_bids
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'NO_BIDS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_bids_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'NO_BIDS' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_bids
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_external_creative_profile_check_failed
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_external_creative_profile_check_failed_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_external_creative_profile_check_failed
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'AUCTION_MAX_AD_DURATION_EXCEEDED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_auction_max_ad_duration_exceeded
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'AUCTION_MAX_AD_DURATION_EXCEEDED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_auction_max_ad_duration_exceeded_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'AUCTION_MAX_AD_DURATION_EXCEEDED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_auction_max_ad_duration_exceeded
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'WRAPPER_HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_wrapper_http_error
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'WRAPPER_HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_wrapper_http_error_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'WRAPPER_HTTP_ERROR' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_wrapper_http_error
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_timeout
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_timeout_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_timeout
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'NO_CONTENT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_content
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'NO_CONTENT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_content_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'NO_CONTENT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_content
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'MAX_WRAPPER_REDIRECT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_max_wrapper_redirect
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'MAX_WRAPPER_REDIRECT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_max_wrapper_redirect_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'MAX_WRAPPER_REDIRECT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_max_wrapper_redirect
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'EMPTY_BID_DEALID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_empty_bid_dealid
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'EMPTY_BID_DEALID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_empty_bid_dealid_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'EMPTY_BID_DEALID' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_empty_bid_dealid
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'INVALID_WRAPPER_URL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_invalid_wrapper_url
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'INVALID_WRAPPER_URL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_invalid_wrapper_url_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'INVALID_WRAPPER_URL' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_invalid_wrapper_url
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_profile_check_failed
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_profile_check_failed_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'PROFILE_CHECK_FAILED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_profile_check_failed
-- add new errors existing on PRD
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'NO_VALID_CURRENCY' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_valid_currency
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'NO_VALID_CURRENCY' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_valid_currency_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'NO_VALID_CURRENCY' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_valid_currency
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'CLIENT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_client_rendition_required
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'CLIENT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_client_rendition_required_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'CLIENT_RENDITION_REQUIRED' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_client_rendition_required
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'UNKNOWN_SEAT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_unknown_seat
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'UNKNOWN_SEAT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_unknown_seat_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'UNKNOWN_SEAT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_unknown_seat
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'PLAYLIST_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_playlist_timeout
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'PLAYLIST_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_playlist_timeout_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'PLAYLIST_TIMEOUT' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_playlist_timeout
    , sum(case when a.advertisement__is_undeliverable = true and coalesce(a.candidate__error,a.advertisement__error) = 'NO_AD_MARKUP' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_ad_markup
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and bitwise_and(a.advertisement__flags, 512) = 0 and coalesce(a.candidate__error,a.advertisement__error) = 'NO_AD_MARKUP' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err_no_ad_markup_no_fallback
    , sum(case when a.advertisement__is_undeliverable = true and a.advertisement__is_fallback = false and coalesce(a.candidate__error,a.advertisement__error) = 'NO_AD_MARKUP' then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  undeliverable_placed_ads_no_ad_markup

-- delivery metrics(15)
    , cast(0 as bigint) as gross_ad_views
    , cast(0 as bigint) as gross_ad_views_primary
    , cast(0 as bigint) as gross_ad_views_fallback
    , cast(0 as bigint) as revenue
    , cast(0 as bigint) as co_revenue
    , cast(0 as bigint) as d_revenue
    , cast(0 as bigint) as r_revenue
    , cast(0 as bigint) as no_ad_views
    , cast(0 as bigint) as clicks
    , cast(0 as bigint) as no_clicks
    , cast(0 as bigint) as first_quartile
    , cast(0 as bigint) as middle_quartile
    , cast(0 as bigint) as third_quartile
    , cast(0 as bigint) as complete_quartile
    , cast(0 as bigint) as can_quartile
 
    , sum(if(a.advertisement__is_undeliverable = false, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                                as selected_ads
    , if(a.advertisement__is_fallback = false or (a.advertisement__is_undeliverable = false and bitwise_and(coalesce(a.advertisement__flags, 0), 33554432)>0), 'Primary', 'Fallback')   as primary_ad_indicator
    , if(nw.sales_channel=6, nw.outbound_listing_id, array[])                                                                           as outbound_exchange_listing_id

    -- 26 adm errors
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

    -- 37 vast errors
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

    , cast(0 as bigint) as ack_err_adm_total
    , cast(0 as bigint) as ack_err_vast_total

    , sum(case when a.advertisement__is_undeliverable = true then coalesce(request__multiplier, 1) * coalesce(request__magnifier, 1) * coalesce(request__log_sampling__magnifier, 1) else 0 end) as  ad_err

    , coalesce(nw.content_form_visibility, 'FULL_VISIBILITY') as content_form_visibility
    , nw.inbound_order_type              as inbound_order_type
    , nw.inbound_order_transaction_type  as inbound_order_transaction_type
    , date_trunc('HOUR', ack__timestamp) as event_date
from etl.public_test1.ack
cross join unnest (
    ads_in_slot__partners__network_id,
    ads_in_slot__partners__site_id,
    ads_in_slot__partners__site_section_id,
    ads_in_slot__partners__distributor_network_id,
    ads_in_slot__partners__content_owner_network_id,
    ads_in_slot__partners__reseller_network_id,
    ads_in_slot__partners__sales_channel,
    ads_in_slot__partners__role,
    ads_in_slot__partners__supply_source,
    ads_in_slot__partners__geo_country_visibility__report_aggregate,
    ads_in_slot__partners__standard_brand_visibility__report_aggregate,
    ads_in_slot__partners__standard_channel_visibility__report_aggregate,
    ads_in_slot__partners__standard_programmer_visibility__report_aggregate,
    ads_in_slot__partners__standard_endpoint_visibility__report_aggregate,
    ads_in_slot__partners__standard_endpoint_owner_visibility__report_aggregate,
    ads_in_slot__partners__user_agent_visibility__report_aggregate,
    ads_in_slot__partners__content_form_visibility__report_aggregate,
    ads_in_slot__partners__global_currency_id,
    ads_in_slot__partners__network_is_extra_item_owner,
    ads_in_slot__partners__network_is_ad_owner,
    ads_in_slot__partners__demand_dim_awareability,
    ads_in_slot__partners__deal_awareability,
    ads_in_slot__partners__outbound_order_id, 
    ads_in_slot__partners__outbound_exchange_order_id,
    ads_in_slot__partners__outbound_listing_id,
    ads_in_slot__partners__inbound_order_id,
    ads_in_slot__partners__inbound_order_type,
    ads_in_slot__partners__inbound_order_transaction_type,
    ads_in_slot__partners__unified_outbound_order_priority__priority_tier,
    ads_in_slot__partners__unified_outbound_order_priority__sub_priority_value,
    ads_in_slot__partners__outbound_order_priority_type,
    ads_in_slot__partners__unified_rule_priority__priority_tier,
    ads_in_slot__partners__unified_rule_priority__sub_priority_value,
    ads_in_slot__partners__rule_type_priority,
    ads_in_slot__partners__bit_flags,
    ads_in_slot__advertisement__flags,
    ads_in_slot__advertisement__entity_flags,
    ads_in_slot__advertisement__effective_unified_priority__priority_tier,
    ads_in_slot__advertisement__unified_priority__priority_tier,
    ads_in_slot__advertisement__effective_unified_priority__sub_priority_value,
    ads_in_slot__advertisement__unified_priority__sub_priority_value,
    ads_in_slot__advertisement__ad_priority_type,
    ads_in_slot__advertisement__ad_id,
    ads_in_slot__advertisement__placement_id,
    ads_in_slot__advertisement__creative_id,
    ads_in_slot__advertisement__advertiser_id,
    ads_in_slot__advertisement__global_advertiser_ids,
    ads_in_slot__advertisement__global_brand_ids,
    ads_in_slot__advertisement__is_fallback,
    ads_in_slot__advertisement__is_sstf_fallback,
    ads_in_slot__advertisement__is_undeliverable,
    ads_in_slot__advertisement__is_bumper,
    ads_in_slot__advertisement__duration,
    ads_in_slot__candidate__internal_deal_id,
    ads_in_slot__candidate__deal_type,
    ads_in_slot__candidate__unified_deal_priority__sub_priority_value,
    ads_in_slot__candidate__unified_deal_priority__priority_tier,
    ads_in_slot__candidate__market_ad_id,
    ads_in_slot__advertisement__market_ad_id,
    ads_in_slot__candidate__buyer_id,
    ads_in_slot__candidate__bidding_buyer_id,
    ads_in_slot__candidate__buyer_group_id,
    ads_in_slot__candidate__buyer_platform_id,
    ads_in_slot__candidate__dsp_id,
    ads_in_slot__candidate__error,
    ads_in_slot__advertisement__error
) as a (
    network_ids,
    site_ids,
    site_section_ids,
    distributor_ids,
    co_ids,
    reseller_ids,
    sales_channels,
    nw_roles,
    supply_sources,
    country_visibilities,
    sa_brand_visibilities,
    sa_channel_visibilities,
    sa_programmer_visibilities,
    sa_endpoint_visibilities,
    sa_endpoint_owner_visibilities,
    user_agent_visibilities,
    content_form_visibilites,
    global_currency_ids,
    is_extra_item_owners,
    network_is_ad_owners,
    demand_dim_awareabilities,
    deal_awareabilities,
    outbound_order_ids, 
    outbound_exchange_order_ids,
    outbound_listing_ids,
    inbound_order_ids,
    inbound_order_types,
    inbound_order_transaction_types,
    outbound_order_priority_tiers,
    outbound_order_priority_values,
    order_priorities,
    rule_priority_tiers,
    rule_priority_values,
    rule_priorities,
    bit_flags,
    advertisement__flags,
    advertisement__entity_flags,
    advertisement__effective_unified_priority__priority_tier,
    advertisement__unified_priority__priority_tier,
    advertisement__effective_unified_priority__sub_priority_value,
    advertisement__unified_priority__sub_priority_value,
    advertisement__ad_priority_type,
    advertisement__ad_id,
    advertisement__placement_id,
    advertisement__creative_id,
    advertisement__advertiser_id,
    advertisement__global_advertiser_ids,
    advertisement__global_brand_ids,
    advertisement__is_fallback,
    advertisement__is_sstf_fallback,
    advertisement__is_undeliverable,
    advertisement__is_bumper,
    advertisement__duration,
    candidate__internal_deal_id,
    candidate__deal_type,
    candidate__unified_deal_priority__sub_priority_value,
    candidate__unified_deal_priority__priority_tier,
    candidate__market_ad_id,
    advertisement__market_ad_id,
    candidate__buyer_id,
    candidate__bidding_buyer_id,
    candidate__buyer_group_id,
    candidate__buyer_platform_id,
    candidate__dsp_id,
    candidate__error,
    advertisement__error
) cross join unnest (
    a.network_ids,
    a.site_ids,
    a.site_section_ids,
    a.distributor_ids,
    a.co_ids,
    a.reseller_ids,
    a.sales_channels,
    a.nw_roles,
    a.supply_sources,
    a.country_visibilities,
    a.sa_brand_visibilities,
    a.sa_channel_visibilities,
    a.sa_programmer_visibilities,
    a.sa_endpoint_visibilities,
    a.sa_endpoint_owner_visibilities,
    a.user_agent_visibilities,
    a.content_form_visibilites,
    a.global_currency_ids,
    a.is_extra_item_owners,
    a.network_is_ad_owners,
    a.demand_dim_awareabilities,
    a.deal_awareabilities,
    a.outbound_order_ids, 
    a.outbound_exchange_order_ids,
    a.outbound_listing_ids,
    a.inbound_order_ids,
    a.inbound_order_types,
    a.inbound_order_transaction_types,
    a.outbound_order_priority_tiers,
    a.outbound_order_priority_values,
    a.order_priorities,
    a.rule_priority_tiers,
    a.rule_priority_values,
    a.rule_priorities,
    a.bit_flags
) as nw (
    nw_id,
    site_id,
    site_section_id,
    distributor_id,
    co_id,
    reseller_id,
    sales_channel,
    nw_role,
    supply_source,
    country_visibility,
    sa_brand_visibility,
    sa_channel_visibility,
    sa_programmer_visibility,
    sa_endpoint_visibility,
    sa_endpoint_owner_visibility,
    user_agent_visibility,
    content_form_visibility,
    global_currency_id,
    is_extra_item_owner,
    network_is_ad_owner,
    demand_dim_awareability,
    deal_awareability,
    outbound_order_id, 
    outbound_exchange_order_id,
    outbound_listing_id,
    inbound_order_id,
    inbound_order_type,
    inbound_order_transaction_type,
    outbound_order_priority_tier,
    outbound_order_priority_value,
    order_priority,
    rule_priority_tier,
    rule_priority_value,
    rule_priority,
    bit_flag
)
left join db.default.d_network reseller on reseller.id = coalesce(nw.reseller_id, -1)
where  
    process_batch_id = '${arena.presto.var.process_batch_id}'
    and bitwise_and(slot__flags, 64) = 0                                                    -- No Parent Slot
    and coalesce(nw.nw_role, '') in ('CRO', 'R')                                           
    and coalesce(a.advertisement__is_bumper, false) = false                                 -- Remove Bumper Ad
    and coalesce(ack__ack_entity_type, '') = 'slot'
    and coalesce(ack__metrics__slot_impression, 0) > 0                                      -- Has Slot Callback
    and supply_source != 4                                                                          -- filter out DSP shell networks                     
    and not(bitwise_and(coalesce(request__extra_flags2,0), 8) > 0 and coalesce(nw.nw_role, '') = 'CRO')  -- filter out SSP shell networks
    and bitwise_and(bit_flag, bitwise_shift_left(1, 41, 64)) = 0                                    -- filter out partner tag buyer
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,189,190,259,260,261,262
union all

-- Ack
select
    cast(32 as int) as process_stage
 
-- Network Chain (10)
    , coalesce(nw.nw_id, -1)                                                                                              as network_id
    , coalesce(nw.co_id, -1)                                                                                              as content_owner_id
    -- , if(bitwise_and(coalesce(request__extra_flags, 0), 1073741824) > 0 and coalesce(nw.nw_role, '') = 'CRO', -3, coalesce(nw.distributor_id, -1))   as distributor_id -- mark CANOE_PROGRAMMER_LINEAR with -3
    , coalesce(nw.distributor_id, -1)                                                                                     as distributor_id
    , coalesce(nw.nw_role, '')                                                                                            as transaction_type
    , coalesce(nw.reseller_id, -1)                                                                                        as reseller_id
    , if(nw.sales_channel = 4, 'NO_VISIBILITY', 'FULL_VISIBILITY')                                                        as reseller_visibility
    , coalesce(reseller.network_type, 'UNKNOWN')                                                                          as reseller_network_type
    , coalesce(nw.supply_source, -1)                                                                                      as supply_source
    , coalesce(nw.sales_channel, -1)                                                                                      as sales_channel
    , case
      when coalesce(nw.sales_channel, -1) = 2 then 'Direct Sold'
      when coalesce(nw.sales_channel, -1) = 3 and reseller.network_type = 'FULL' then 'MRM Partner'
      when coalesce(nw.sales_channel, -1) = 3 and reseller.network_type = 'INTERNAL' then 'Reseller Sold - Reseller Tag'
      when coalesce(nw.sales_channel, -1) = 4 then 'Programmatic'
      when coalesce(nw.sales_channel, -1) = 5 then 'MRM Partner'
      when coalesce(nw.sales_channel, -1) = 6 then 'MRM Partner'
      else 'Unknown'
    end                                                                                                                   as sales_strategy
 
-- Raw Inventory (2)
    , coalesce(nw.site_id, -1)                                                                                            as site_id
    , coalesce(nw.site_section_id, -1)                                                                                    as site_section_id
 
 
-- SA Content (21)
    , coalesce(request__context__standard_publisher_id, -1)                                                               as standard_publisher_id
    , if(nw.sa_brand_visibility is not null or nw.supply_source != 3, 
        coalesce(request__context__standard_brand_id, -1), -1)                                                            as standard_brand_id
    , coalesce(nw.sa_brand_visibility, 'FULL_VISIBILITY')                                                                 as standard_brand_visibility
    , if(nw.sa_programmer_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_programmer_id, -1), -1)                                                       as standard_programmer_id
    , coalesce(nw.sa_programmer_visibility, 'FULL_VISIBILITY')                                                            as standard_programmer_visibility
    , if(nw.content_form_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__content_form_id, -1), -1)                                                              as content_form_id
    , coalesce(request__context__stream_mode_id, -1)                                                                      as stream_mode_id
    , if(nw.sa_endpoint_owner_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_endpoint_owner_id, -1), -1)                                                   as standard_endpoint_owner_id
    , coalesce(nw.sa_endpoint_owner_visibility, 'FULL_VISIBILITY')                                                        as standard_endpoint_owner_visibility
    , if(nw.sa_endpoint_visibility is not null or nw.supply_source != 3,
        coalesce(request__context__standard_endpoint_id, -1), -1)                                                         as standard_endpoint_id
    , coalesce(nw.sa_endpoint_visibility, 'FULL_VISIBILITY')                                                              as standard_endpoint_visibility
    , coalesce(visitor__country_id, -1)                                                                                   as user_country_id
    , coalesce(nw.country_visibility, 'FULL_VISIBILITY')                                                                  as geo_country_visibility
    , coalesce(visitor__standard_device_type_child_id, -1)                                                                as standard_device_type_id
    , coalesce(request__context__standard_app_id, -1)                                                                     as standard_app_id
    , coalesce(visitor__standard_environment_id, -1)                                                                      as standard_environment_id
    , coalesce(visitor__standard_os_id, -1)                                                                               as standard_os_id
    , coalesce(visitor__platform_device_id, -1)                                                                           as delivered_platform_device_id
    , coalesce(nw.user_agent_visibility, 'FULL_VISIBILITY')                                                               as user_agent_visibility
    , coalesce(request__context__standard_app_bundle_id, -1)                                                              as standard_app_bundle_id
    , coalesce(request__context__standard_site_domain_id, -1)                                                             as standard_site_domain_id
    , if(nw.sa_channel_visibility is not null or nw.supply_source != 3,
      coalesce(request__context__standard_channel_id, -1), -1)                                                            as standard_channel_id
    , coalesce(nw.sa_channel_visibility, 'FULL_VISIBILITY')                                                               as standard_channel_visibility
 
 
-- Request Attribution (6)
    -- , if(bitwise_and(coalesce(request__extra_flags, 0), 1073741824) > 0 and coalesce(nw.nw_role, '') = 'CRO', -3, coalesce(request__context__profile_id, -1))  as profile_id -- mark CANOE_PROGRAMMER_LINEAR with -3
    , coalesce(request__context__profile_id, -1)                                                                          as profile_id
    , coalesce(request__context__profile_type, 'UNKNOWN')                                                                 as profile_type
    , case
        when bitwise_and(request__flags, 32)>0           then  'No Selection'      /* No Selection */
        when coalesce(request__advertisement_delivered_count, coalesce(request__advertisement_count, 0))=0 then 'Empty'             /* Selection without Ads in Response */
        else                                                   'Filled'            /* Selection with Ads in Response */
    end                                                                                                                   as request_fill_status
    , if(bitwise_and(coalesce(request__extra_flags,0), 1024)>0, true, false)                                              as live_linear_indicator          
    , if(bitwise_and(coalesce(request__extra_flags2,0), 8)>0, true, false)                                                as ssp_bidder_indicator
    , if(bitwise_and(coalesce(bit_flag, 0), bitwise_shift_left(1, 40,64))>0, true, false)                                   as partner_tag_indicator
 
-- Slot Attribution (6)
    , array[coalesce(slot__time_position_class, 'Unknown')]                                                               as time_position_classes
    , coalesce(slot__normalized_ad_unit_id, -1)                                                                           as slot_ad_unit_id
    , case
        when slot__sequence is null then 'Null'
        when slot__sequence > 5 then '5+'
        else cast(slot__sequence as varchar)
    end                                                                                                                   as slot_sequence_normalized     
    , 'Not Applicable'                                                                                                    as slot_user_drop_off            
    , if(bitwise_and(coalesce(slot__flags, 0), 8)>0, 'Yes', 'No')                                                         as slot_removed_by_ux_indicator
    , if(bitwise_and(coalesce(nw.bit_flag, 0), bitwise_shift_left(1, 60, 64))>0, 'Yes', 'No')                             as slot_removed_by_constrained_indicator      
    , case
        when slot__time_position_class='overlay' and slot__num_ads=0 and slot__max_ads>0 then 'Empty - Slots with Avails'
        when slot__time_position_class='overlay' and slot__num_ads=0 and slot__max_ads=0 then 'Empty - Slots without Avails'
        when slot__time_position_class='overlay' and slot__num_ads=slot__max_ads then 'Fully Filled'
        when slot__time_position_class='overlay' and slot__num_ads>0 and slot__num_ads<slot__max_ads then 'Partially Filled'
        when slot__num_ads=0 and coalesce(slot__unfilled_avails , 0)>0 then 'Empty - Slots with Avails'
        when slot__num_ads=0 and slot__unfilled_avails=0 then 'Empty - Slots without Avails'
        when slot__unfilled_avails=0  then 'Fully Filled'
        when slot__num_ads>0 and slot__unfilled_avails>0  then 'Partially Filled'
        else 'Unknown'
    end                                                                                                                   as slot_fill_status
 
-- Ad Attribution (6)
    , if(is_extra_item_owner = true,
        if(bitwise_and(coalesce(advertisement__entity_flags, 0), bitwise_shift_left(1, 35, 64))>0, 'Yes', 'No'),
        'Not Applicable')                                                                                                 as evergreen_ad_indicator
    , if(is_extra_item_owner = true,
        if(bitwise_and(coalesce(advertisement__entity_flags, 0), bitwise_shift_left(1, 2 , 64))>0, 'Yes', 'No'),
        'Not Applicable')                                                                                                 as promo_ad_indicator
    , case
        -- 'Direct Sold'
        when nw.sales_channel = 2 then if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier, 'UNKNOWN'), coalesce(advertisement__unified_priority__priority_tier,'UNKNOWN'))
        -- 'Reseller Sold'
        when nw.sales_channel = 3 then coalesce(rule_priority_tier, 'UNKNOWN')
        -- 'Programmatic'
        when nw.sales_channel = 4 then if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier, 'UNKNOWN'), 
            case 
                when coalesce(candidate__internal_deal_id, -1)>0 then coalesce(candidate__unified_deal_priority__priority_tier,'UNKNOWN')   
                when coalesce(candidate__buyer_group_id, -1)>0 then coalesce(rule_priority_tier,'UNKNOWN')
                else 'UNKNOWN'
            end)
         -- 'Partner Tag / Partner Trading(MPP) /Marketplace Platform Exchange(MPE)'     
        when nw.sales_channel in (5,6) then coalesce(nw.order_priority_tier, 'UNKNOWN')
        else 'UNKNOWN'
    end                                                                                                                   as priority_tier
    , case
        -- 'Direct Sold'
        WHEN sales_channel = 2 then if(nw_role = 'CRO', advertisement__effective_unified_priority__sub_priority_value, advertisement__unified_priority__sub_priority_value)
        -- 'MRM2MRM'
        when sales_channel = 3 then rule_priority_value
        -- 'Programmatic'
        when sales_channel = 4 then if(nw_role = 'CRO', 
            if(coalesce(advertisement__effective_unified_priority__priority_tier, 'UNKNOWN')= 'TIER_1'
                and advertisement__effective_unified_priority__sub_priority_value <= 5, advertisement__effective_unified_priority__sub_priority_value+25, advertisement__effective_unified_priority__sub_priority_value),  -- First Look Deal sub_priority_value is transformed to -5~5
            case 
                when coalesce(candidate__internal_deal_id, -1)>0 then candidate__unified_deal_priority__sub_priority_value   
                when coalesce(candidate__buyer_group_id, -1)>0 then rule_priority_value
                else null
            end)
        -- 'Partner Trading(MPP) / Partner Tag / Marketplace Platform Exchange(MPE)'
        when sales_channel in (5,6) then outbound_order_priority_value
    else null end                                                                                                          as priority_value
    , if(is_extra_item_owner = true, advertisement__unified_priority__sub_priority_value, null)                            as ad_meta_priority_value -- ad owner
    , if(is_extra_item_owner = true and bitwise_and(advertisement__flags, 1024) > 0, 1, 0)                                 as meet_schedule 
    , case
        -- 'Direct Sold'
        WHEN sales_channel = 2
            then (
                case
                    when if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier,'UNKNOWN'), coalesce(advertisement__unified_priority__priority_tier,'UNKNOWN')) in ('TIER_1','TIER_2') then coalesce(advertisement__ad_priority_type,'UNKNOWN')
                    when if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier,'UNKNOWN'), coalesce(advertisement__unified_priority__priority_tier,'UNKNOWN')) in ('TIER_3','TIER_4') then if(coalesce(advertisement__ad_priority_type,'UNKNOWN')='UNKNOWN',if(bitwise_and(advertisement__entity_flags, 1) > 0 , 'GUARANTEED','PREEMPTIBLE'),concat(if(bitwise_and(advertisement__entity_flags, 1) > 0 , 'GUARANTEED','PREEMPTIBLE'),'_',coalesce(advertisement__ad_priority_type,'UNKNOWN')))
                    when if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier,'UNKNOWN'), coalesce(advertisement__unified_priority__priority_tier,'UNKNOWN')) in ('TIER_6') then 'HOUSE_ADS'
                else coalesce(advertisement__ad_priority_type,'UNKNOWN') end
            )
        -- 'MRM2MRM/Reseller Tag'
        when sales_channel = 3  then (
                case
                    when coalesce(rule_priority,'UNKNOWN') = 'YOU_FIRST' then 'HARD_GUARANTEED_WITH_PASSBACK'
                    when coalesce(rule_priority,'UNKNOWN') = 'ME_FIRST' then 'BACKFILL_ONLY'
                    when coalesce(rule_priority,'UNKNOWN') = 'HARD_GUARANTEED' then 'HARD_GUARANTEED_WITHOUT_PASSBACK'
                else coalesce(rule_priority,'UNKNOWN') end
            )
        -- 'Programmatic'
        when sales_channel = 4 then (
                case when coalesce(candidate__internal_deal_id,-1)>0 then (
                    case when coalesce(candidate__deal_type,'NA') = 'PROGRAMMATIC_GUARANTEED_TRADING_DESK_DEAL' then 'PROGRAMMATIC_GUARANTEED'
                            when coalesce(candidate__deal_type,'NA') = 'BIDDABLE_GUARANTEED_DEAL' then 'BIDDABLE_GUARANTEED'
                            when coalesce(candidate__deal_type,'NA') = 'FIRST_LOOK_DEAL' then 'FIRST_LOOK'
                        else coalesce(candidate__deal_type,'NA') end)
                    else (
                        case
                            when coalesce(rule_priority,'UNKNOWN') = 'ME_FIRST' then 'BACKFILL_ONLY'
                        else coalesce(rule_priority,'UNKNOWN') end
                        )
                end
            )
        -- 'Partner Tag / Partner Trading(MPP) /Marketplace Platform Exchange(MPE)'
        when sales_channel in (5,6) then if(coalesce(order_priority,'UNKNOWN') = 'PRIORITY_NONE','INVENTORY_SPLIT',replace(coalesce(order_priority,'NA'),'PRIORITY_',''))
        else 'UNKNOWN' end as priority_type
 
    -- Traffic Type
    , coalesce(request__traffic_type, 0)                                                as request_traffic_type
    , coalesce(ack__traffic_type, 0)                                                    as ack_traffic_type
 
-- Ad Level Dimensions(18)
    , coalesce(inbound_order_id, cast(-1 as bigint)) as inbound_order_id
    , coalesce(outbound_order_id, cast(-1 as bigint)) as outbound_order_id
    , coalesce(outbound_exchange_order_id, cast(-1 as bigint)) as outbound_exchange_order_id
    , if(demand_dim_awareability , coalesce(candidate__dsp_id, -1), -1) as dsp_id
    , if(demand_dim_awareability , coalesce(candidate__buyer_platform_id, -1), -1) as buyer_platform_id
    , if(deal_awareability , coalesce(candidate__internal_deal_id, -1), -1) as deal_id
    , if(deal_awareability , coalesce(candidate__buyer_group_id, -1), -1) as buyer_group_id
    , if(deal_awareability , coalesce(candidate__buyer_id, -1), -1) as buyer_id
    , if(deal_awareability , coalesce(candidate__bidding_buyer_id, -1), -1) as bidding_buyer_id
    , if(demand_dim_awareability , coalesce(advertisement__market_ad_id, coalesce(candidate__market_ad_id, -1)), -1) as market_ad_id
    , if(network_is_ad_owner,coalesce(advertisement__ad_id, -1),-1) as ad_id
    , if(network_is_ad_owner,coalesce(advertisement__placement_id, -1),-1) as placement_id
    , if(network_is_ad_owner,coalesce(advertisement__creative_id, -1),-1) as creative_id
 
    , coalesce(nw.global_currency_id, -1) as global_currency_id
    , coalesce(request__global_currency_version, '') as global_currency_version
    , coalesce(advertisement__global_advertiser_ids, array[])                                                           as global_advertiser_ids
    , coalesce(advertisement__global_brand_ids, array[])                                                                as global_brand_ids
    , if(network_is_ad_owner, coalesce(advertisement__advertiser_id, -1), -1)                                           as local_advertiser_id

-- Process Time
    , process_batch_id                                                 as process_batch_id
 
 
-- Ad Metrics (6)
    , cast(0 as bigint)                                                                as placed_ads
    , cast(0 as bigint)                                                                as undeliverable_placed_ads
    , cast(0 as bigint)                                                                as placed_fallback_ads
    , cast(0 as bigint)                                                                as placed_ads_has_fallback
    , cast(0 as bigint)                                                                as filled_ads
    , cast(0 as bigint)                                                                as filled_ads_duration
    , cast(0 as bigint)                                                                as filled_ads_sstf_fallback
 
 -- ad error metrics(73)
    , cast(0 as bigint) as ad_err_no_fallback
    , cast(0 as bigint) as ad_err_floor_price_notmet
    , cast(0 as bigint) as ad_err_floor_price_notmet_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_floor_price_notmet
    , cast(0 as bigint) as ad_err_unexpected_external_ad_id
    , cast(0 as bigint) as ad_err_unexpected_external_ad_id_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_unexpected_external_ad_id
    , cast(0 as bigint) as ad_err_no_valid_creative
    , cast(0 as bigint) as ad_err_no_valid_creative_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_no_valid_creative
    , cast(0 as bigint) as ad_err_malformed_response
    , cast(0 as bigint) as ad_err_malformed_response_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_malformed_response
    , cast(0 as bigint) as ad_err_competition_failure
    , cast(0 as bigint) as ad_err_competition_failure_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_competition_failure
    , cast(0 as bigint) as ad_err_jitt_rendition_required
    , cast(0 as bigint) as ad_err_jitt_rendition_required_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_jitt_rendition_required
    , cast(0 as bigint) as ad_err_no_slot_selected
    , cast(0 as bigint) as ad_err_no_slot_selected_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_no_slot_selected
    , cast(0 as bigint) as ad_err_empty_response
    , cast(0 as bigint) as ad_err_empty_response_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_empty_response
    , cast(0 as bigint) as ad_err_inapplicable_for_https
    , cast(0 as bigint) as ad_err_inapplicable_for_https_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_inapplicable_for_https
    , cast(0 as bigint) as ad_err_ad_pending_approval
    , cast(0 as bigint) as ad_err_ad_pending_approval_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_ad_pending_approval
    , cast(0 as bigint) as ad_err_bid_response_id_nomatch
    , cast(0 as bigint) as ad_err_bid_response_id_nomatch_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_bid_response_id_nomatch
    , cast(0 as bigint) as ad_err_wrapper_timeout
    , cast(0 as bigint) as ad_err_wrapper_timeout_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_wrapper_timeout
    , cast(0 as bigint) as ad_err_compliance_not_approved
    , cast(0 as bigint) as ad_err_compliance_not_approved_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_compliance_not_approved
    , cast(0 as bigint) as ad_err_http_error
    , cast(0 as bigint) as ad_err_http_error_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_http_error
    , cast(0 as bigint) as ad_err_no_bids
    , cast(0 as bigint) as ad_err_no_bids_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_no_bids
    , cast(0 as bigint) as ad_err_external_creative_profile_check_failed
    , cast(0 as bigint) as ad_err_external_creative_profile_check_failed_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_external_creative_profile_check_failed
    , cast(0 as bigint) as ad_err_auction_max_ad_duration_exceeded
    , cast(0 as bigint) as ad_err_auction_max_ad_duration_exceeded_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_auction_max_ad_duration_exceeded
    , cast(0 as bigint) as ad_err_wrapper_http_error
    , cast(0 as bigint) as ad_err_wrapper_http_error_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_wrapper_http_error
    , cast(0 as bigint) as ad_err_timeout
    , cast(0 as bigint) as ad_err_timeout_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_timeout
    , cast(0 as bigint) as ad_err_no_content
    , cast(0 as bigint) as ad_err_no_content_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_no_content
    , cast(0 as bigint) as ad_err_max_wrapper_redirect
    , cast(0 as bigint) as ad_err_max_wrapper_redirect_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_max_wrapper_redirect
    , cast(0 as bigint) as ad_err_empty_bid_dealid
    , cast(0 as bigint) as ad_err_empty_bid_dealid_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_empty_bid_dealid
    , cast(0 as bigint) as ad_err_invalid_wrapper_url
    , cast(0 as bigint) as ad_err_invalid_wrapper_url_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_invalid_wrapper_url
    , cast(0 as bigint) as ad_err_profile_check_failed
    , cast(0 as bigint) as ad_err_profile_check_failed_no_fallback
    , cast(0 as bigint) as undeliverable_placed_ads_profile_check_failed
-- add new errors existing on PRD
    , cast(0 as bigint) as  ad_err_no_valid_currency
    , cast(0 as bigint) as  ad_err_no_valid_currency_no_fallback
    , cast(0 as bigint) as  undeliverable_placed_ads_no_valid_currency
    , cast(0 as bigint) as  ad_err_client_rendition_required
    , cast(0 as bigint) as  ad_err_client_rendition_required_no_fallback
    , cast(0 as bigint) as  undeliverable_placed_ads_client_rendition_required
    , cast(0 as bigint) as  ad_err_unknown_seat
    , cast(0 as bigint) as  ad_err_unknown_seat_no_fallback
    , cast(0 as bigint) as  undeliverable_placed_ads_unknown_seat
    , cast(0 as bigint) as  ad_err_playlist_timeout
    , cast(0 as bigint) as  ad_err_playlist_timeout_no_fallback
    , cast(0 as bigint) as  undeliverable_placed_ads_playlist_timeout
    , cast(0 as bigint) as  ad_err_no_ad_markup
    , cast(0 as bigint) as  ad_err_no_ad_markup_no_fallback
    , cast(0 as bigint) as  undeliverable_placed_ads_no_ad_markup

-- delivery metrics(15)
    , sum(coalesce(ack__metrics__raw_ad_impression, 0))                         as gross_ad_views
    , sum(if(
        advertisement__is_fallback=false,
        coalesce(ack__metrics__raw_ad_impression,0),0)
    )                                                                           as gross_ad_views_primary
    , sum(if(
        advertisement__is_fallback=true,
        coalesce(ack__metrics__raw_ad_impression,0),0)
    )                                                                           as gross_ad_views_fallback
    , sum(coalesce(revenue, cast(0 as double)) * coalesce(ack__metrics__fire_event_revenue_ratio, cast(0 as bigint))) as revenue
    , sum(coalesce(content_owner_revenue, cast(0 as double)) * coalesce(ack__metrics__fire_event_revenue_ratio, cast(0 as bigint))) as co_revenue
    , sum(coalesce(distributor_revenue, cast(0 as double)) * coalesce(ack__metrics__fire_event_revenue_ratio, cast(0 as bigint))) as d_revenue
    , sum(coalesce(reseller_revenue, cast(0 as double)) * coalesce(ack__metrics__fire_event_revenue_ratio, cast(0 as bigint))) as r_revenue
    , sum(if(nw.network_is_ad_owner, coalesce(ack__metrics__no_ad_impression, cast(0 as bigint)), cast(0 as bigint)))   as no_ad_views
    , sum(coalesce(ack__metrics__click, cast(0 as bigint))) as clicks
    , sum(coalesce(ack__metrics__no_click, cast(0 as bigint))) as no_clicks
    , sum(coalesce(ack__metrics__first_quartile, cast(0 as bigint))) as first_quartile
    , sum(coalesce(ack__metrics__middle_quartile, cast(0 as bigint))) as middle_quartile
    , sum(coalesce(ack__metrics__third_quartile, cast(0 as bigint))) as third_quartile
    , sum(coalesce(ack__metrics__complete_quartile, cast(0 as bigint))) as complete_quartile
    , sum(coalesce(ack__metrics__can_quartile, cast(0 as bigint))) as can_quartile
 
    , cast(0 as bigint)                                                                                                             as selected_ads
    , if(advertisement__is_fallback = false or bitwise_and(coalesce(advertisement__flags, 0), 33554432)>0, 'Primary', 'Fallback')   as primary_ad_indicator
    , if(nw.sales_channel=6, nw.outbound_listing_id, array[]) as outbound_exchange_listing_id

    -- 26 adm errors
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

    -- 37 vast errors
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

    , sum(if(ack__event_type = 'e' and ack__event_category = 'ad_manager_error', ack__metrics__ad_error, 0)) as ack_err_adm_total
    , sum(if(ack__event_type = 'e' and ack__event_category = 'vast_error', ack__metrics__ad_error, 0))       as ack_err_vast_total

    , cast(0 as bigint) as ad_err

    , coalesce(nw.content_form_visibility, 'FULL_VISIBILITY') as content_form_visibility
    , nw.inbound_order_type             as inbound_order_type
    , nw.inbound_order_transaction_type as inbound_order_transaction_type
    , date_trunc('HOUR', ack__timestamp) as event_date
from etl.public_test1.ack
cross join unnest (
    partners__network_id,
    partners__site_id,
    partners__site_section_id,
    partners__distributor_network_id,
    partners__content_owner_network_id,
    partners__reseller_network_id,
    partners__sales_channel,
    partners__role,
    partners__supply_source,
    partners__geo_country_visibility__report_aggregate,
    partners__standard_brand_visibility__report_aggregate,
    partners__standard_channel_visibility__report_aggregate,
    partners__standard_programmer_visibility__report_aggregate,
    partners__standard_endpoint_visibility__report_aggregate,
    partners__standard_endpoint_owner_visibility__report_aggregate,
    partners__user_agent_visibility__report_aggregate,
    partners__content_form_visibility__report_aggregate,
    partners__global_currency_id,
    partners__network_is_extra_item_owner,
    partners__demand_dim_awareability,
    partners__deal_awareability,
    partners__outbound_order_id, 
    partners__outbound_exchange_order_id,
    partners__outbound_listing_id,
    partners__inbound_order_id,
    partners__inbound_order_type,
    partners__inbound_order_transaction_type,
    partners__unified_outbound_order_priority__priority_tier,
    partners__unified_outbound_order_priority__sub_priority_value,
    partners__outbound_order_priority_type,
    partners__unified_rule_priority__priority_tier,
    partners__unified_rule_priority__sub_priority_value,
    partners__rule_type_priority,
    partners__network_is_ad_owner,
    partners__revenue,
    partners__content_owner_revenue,
    partners__reseller_revenue,
    partners__distributor_revenue,
    partners__bit_flags
) as nw (
    nw_id,
    site_id,
    site_section_id,
    distributor_id,
    co_id,
    reseller_id,
    sales_channel,
    nw_role,
    supply_source,
    country_visibility,
    sa_brand_visibility,
    sa_channel_visibility,
    sa_programmer_visibility,
    sa_endpoint_visibility,
    sa_endpoint_owner_visibility,
    user_agent_visibility,
    content_form_visibility,
    global_currency_id,
    is_extra_item_owner,
    demand_dim_awareability,
    deal_awareability,
    outbound_order_id, 
    outbound_exchange_order_id,
    outbound_listing_id,
    inbound_order_id,
    inbound_order_type,
    inbound_order_transaction_type,
    order_priority_tier,
    outbound_order_priority_value,
    order_priority,
    rule_priority_tier,
    rule_priority_value,
    rule_priority,
    network_is_ad_owner,
    revenue,
    content_owner_revenue,
    reseller_revenue,
    distributor_revenue,
    bit_flag
)
left join db.default.d_network reseller on reseller.id = coalesce(nw.reseller_id, -1)
where  
    process_batch_id = '${arena.presto.var.process_batch_id}'
    and bitwise_and(slot__flags, 64) = 0                                                    -- No Parent Slot
    and coalesce(nw.nw_role, '') in ('CRO', 'R')                                           
    and coalesce(advertisement__is_bumper, false) = false                                   -- Remove Bumper Ad
    and supply_source != 4                                                                          -- filter out DSP shell networks                     
    and not(bitwise_and(coalesce(request__extra_flags2,0), 8)>0 and coalesce(nw.nw_role, '') = 'CRO')  -- filter out SSP shell networks
    and bitwise_and(bit_flag, bitwise_shift_left(1, 41, 64)) = 0                                    -- filter out partner tag buyer
    and (coalesce(ack__ack_entity_type, '') = 'ad'
        or (ack__event_type = 'e' and ack__event_category in ('ad_manager_error', 'vast_error')))
    and (ack__is_private_impression = false or network_is_ad_owner = true or is_extra_item_owner = true)
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,189,190,259,260,261,262
) as f
left join ad_unit_map aum on aum.network_id = f.network_id
group by 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,139,140,169,170,254,255,256,257,258,259,260,261,262