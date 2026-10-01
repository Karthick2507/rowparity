/* only include transction_type in ('CRO', 'R') */
 with
 global_brand_map as (
     select MAP_AGG(id,name) as brand_application_map
     from db.default.d_global_brand_advertiser
     where type = 'BRAND'
 ),
 global_adv_map as (
     select MAP_AGG(id,name) as adv_application_map
     from db.default.d_global_brand_advertiser
     where type = 'STANDARD'
 ),
 global_industry_map as (
    select MAP_AGG(id,name) as industry_map
    from db.default.d_lu_advertiser_industry
 )
-- ad_unit_map as (
--     select MAP_AGG(id,name) as ad_unit_application_map
--     from db.default.d_ad_unit
-- )

select
    event_date as timestamp
    , t.network_id
    , coalesce(network.name,'NA') as network_name
    , t.video_cro_network_id
    , coalesce(vcro.name, 'NA') as video_cro_network_name
    , content_owner_id
    , coalesce(co.name,'NA') as content_owner_name
   -- , content_owner_visibility
    , distributor_id
    , coalesce(dis.name,'NA') as distributor_name
    , t.transaction_type
    , reseller_id
    , coalesce(reseller.name,'NA') as reseller_name
   -- , reseller_visibility
    , reseller_network_type
    , case
        WHEN t.supply_source = 1 then 'O&O'
        when t.supply_source = 3 and network.network_type = 'FULL' then 'MRM2MRM'
        when t.supply_source = 3 and network.network_type = 'INTERNAL' then 'Reseller Tag'
        when t.supply_source = 4 then 'Programmatic'
        when t.supply_source = 5 then 'Partner Trading(MPP)'
        when t.supply_source = 6 then 'Marketplace Platform Exchange(MPE)'
     else 'Unkown Supply Source' end as supply_source
    , case
        WHEN t.sales_channel = 2 then 'Direct Sold'
        when t.sales_channel = 3 and reseller.network_type = 'FULL' then 'MRM2MRM'
        when t.sales_channel = 3 and reseller.network_type = 'INTERNAL' then 'Reseller Tag'
        when t.sales_channel = 4 then 'Programmatic'
        when t.sales_channel = 5 and partner_tag_indicator = 'true' then 'Partner Tag'
        when t.sales_channel = 5 then 'Partner Trading(MPP)'
        when t.sales_channel = 6 then 'Marketplace Platform Exchange(MPE)'
     else 'NA' end as sales_channel
    , sales_strategy
    , t.site_id
    , coalesce(s.site_name,'NA') as site_name
    , site_section_id
    , coalesce(ss.name,'NA') as site_section_name
    , standard_publisher_id
    , coalesce(publisher.name,'NA') as standard_publisher_name
    , standard_brand_id
    , coalesce(brand.name, 'NA') as standard_brand_name
    --, standard_brand_visibility
    , standard_programmer_id
    , coalesce(pg.name,'NA') as standard_programmer_name
    --, standard_programmer_visibility
    , content_form_id
    , coalesce(cf.name,'NA') as content_form_name
    , stream_mode_id
    , coalesce(sm.name,'NA') as stream_mode_name
    , standard_endpoint_owner_id
    , coalesce(eo.name,'NA') as standard_endpoint_owner_name
    --, standard_endpoint_owner_visibility
    , standard_endpoint_id
    , coalesce(ep.name,'NA') as standard_endpoint_name
    --, standard_endpoint_visibility
    , user_country_id
    , coalesce(country.name,'NA') as user_country_name
    --, geo_country_visibility
    , standard_device_type_id
    , coalesce(device.name,'NA') as standard_device_type_name
   -- , standard_app_id
   -- , coalesce(app.name,'NA') as standard_app_name
   -- , standard_environment_id
   -- , coalesce(env.name,'NA') as standard_environment_name
   -- , standard_os_id
   -- , coalesce(os.name,'NA') as standard_os_name
   -- , delivered_platform_device_id
   -- , coalesce(platform_device.display_name,'NA') as delivered_platform_device_name
    --, user_agent_visibility
    , profile_id
    , coalesce(p.name,'NA') as profile_name
    , profile_type
    , request_fill_status
    , live_linear_indicator
    , ssp_bidder_indicator
    , partner_tag_indicator
    , time_position_classes
    , slot_ad_unit_ids
    , slot_ad_unit_names
    , slot_sequence_normalized
    , slot_user_drop_off
    , slot_removed_by_ux_indicator
    , slot_fill_status
    , evergreen_ad_indicator
    , promo_ad_indicator
    , priority_tier
    , case
        -- fix SPONSORSHIP logic
        when priority_tier = 'TIER_1' and priority_type = 'SPONSORSHIP' then coalesce(ad_meta_priority_value, 25)
        when priority_tier = 'TIER_1' and priority_value is null then 25
        when priority_tier = 'TIER_2' and priority_value is null then 11
        when priority_tier in ('TIER_3','TIER_4','TIER_5') and priority_type like '%SPONSORSHIP%' then coalesce(priority_value, 0)
        when priority_tier in ('TIER_3','TIER_4','TIER_5') and (priority_value is null or priority_value<0 or priority_value>10) then 0
        when priority_tier = 'TIER_6' and (priority_value is null or priority_value = -65535) then 0
        else if(priority_value is null, 0, priority_value)
    end as priority_value
    , priority_type
    , request_traffic_type
    , ack_traffic_type
    , inbound_order_id
    , coalesce(in_order.name,'NA') as inbound_order_name
    , coalesce(in_order.order_type,'NA') as inbound_order_type
    , coalesce(in_order.internal_module,'NA') as inbound_internal_module
    , outbound_order_id
    , coalesce(out_order.name,'NA') as outbound_order_name
    , coalesce(out_order.order_type,'NA') as outbound_order_type
    , coalesce(out_order.internal_module,'NA') as outbound_internal_module
    , outbound_exchange_order_id
    , dsp_id
    , coalesce(dsp.name,'NA') as dsp_name
    , buyer_platform_id
    , coalesce(bp.name,'NA') as buyer_platform_name
    , deal_id
    , coalesce(d_ssp_deal_metadata.external_id,'NA') as public_deal_id
    , buyer_group_id
    , coalesce(bg.name,'NA') as buyer_group_name
    , buyer_id
   -- , market_ad_id
   --, site_domain as auction_site_domain

    , ad_id
    , placement_id
   -- , creative_id
    , global_currency_id
    , global_currency_version
    , if(cardinality(global_advertiser_ids) >3, slice(array_sort(global_advertiser_ids),1,3), array_sort(global_advertiser_ids)) as global_advertiser_ids
    , if(cardinality(global_advertiser_names) >3, slice(array_sort(global_advertiser_names),1,3), array_sort(global_advertiser_names)) as global_advertiser_names
    , if(cardinality(global_brand_ids) >3, slice(array_sort(global_brand_ids),1,3),array_sort(global_brand_ids) ) as global_brand_ids
    , if(cardinality(global_brand_names) >3, slice(array_sort(global_brand_names),1,3), array_sort(global_brand_names)) as global_brand_names
    , if(cardinality(global_industry_ids) >3, slice(array_sort(global_industry_ids),1,3), array_sort(global_industry_ids)) as global_industry_ids
    , if(cardinality(global_industry_names) >3, slice(array_sort(global_industry_names),1,3),array_sort(global_industry_names) ) as global_industry_names
    , local_advertiser_id
    , coalesce(adv.name,'NA') as local_advertiser_name
    , process_batch_id
    , cbp_id
    , outbound_exchange_listing_id as outbound_exchange_listing_ids
    , case
        WHEN t.sales_channel = 2 then 'AD/Placement'
        when t.sales_channel = 4 then 'Programmatic'
        else 'Others'
      end as demand_type
    , primary_ad_indicator
    --, audience_item_ids
    , reduce(set_agg(process_stage), 0, (acc, val) -> acc + val, val -> val) as process_stage
    , sum(placed_ads)                                       as placed_ads
    , sum(placed_fallback_ads)                              as placed_fallback_ads
    , sum(filled_ads)                                       as filled_ads
    , sum(filled_ads_duration)                              as filled_ads_duration
    , sum(filled_ads_sstf_fallback)                         as filled_ads_sstf_fallback
    , sum(raw_selected_primary_ads)                         as raw_selected_primary_ads
    , sum(placed_ads_sstf_failed)                           as placed_ads_sstf_failed
    , sum(placed_ads_sstf_failed_no_fallback)               as placed_ads_sstf_failed_no_fallback
    , sum(placed_ads_sstf_failed_with_fallback)             as placed_ads_sstf_failed_with_fallback

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
    , sum(ad_err_warpper_timeout)                           as ad_err_warpper_timeout
    , sum(ad_err_warpper_timeout_no_fallback)               as ad_err_warpper_timeout_no_fallback
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
    , sum(ad_err_warpper_http_error)                        as ad_err_warpper_http_error
    , sum(ad_err_warpper_http_error_no_fallback)            as ad_err_warpper_http_error_no_fallback
    , sum(ad_err_timeout)                                   as ad_err_timeout
    , sum(ad_err_timeout_no_fallback)                       as ad_err_timeout_no_fallback
    , sum(ad_err_no_content)                                as ad_err_no_content
    , sum(ad_err_no_content_no_fallback)                    as ad_err_no_content_no_fallback
    , sum(ad_err_max_warpper_redirect)                      as ad_err_max_warpper_redirect
    , sum(ad_err_max_warpper_redirect_no_fallback)          as ad_err_max_warpper_redirect_no_fallback
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



from (
-- Ads (Not Removed User Drop Off)
select
    cast(16 as int)                                                                                                       as process_stage

-- Network Chain (10)
    , coalesce(nw.nw_id, -1)                                                                                              as network_id
    , coalesce(request__context__video_cro_network_id, -1)                                                                as video_cro_network_id
    , coalesce(nw.co_id, -1)                                                                                              as content_owner_id
    , if(nw.supply_source = 6 and bitwise_and(coalesce(request__extra_flags2, 0), 8) = 0 and nw.nw_id != 523319, 'NO_VISIBILITY', 'FULL_VISIBILITY') as content_owner_visibility -- MPE:supply_source = 6, Bidder Traffic: SSP_BIDDER_TRAFFIC = 8, FW Marketplace Bundled Deals: network_id=523319
    , if(bitwise_and(coalesce(request__extra_flags, 0), 1073741824) > 0 and coalesce(nw.nw_role, '') = 'CRO', -3, coalesce(nw.distributor_id, -1))   as distributor_id -- mark CANOE_PROGRAMMER_LINEAR with -3
    , coalesce(nw.nw_role, '')                                                                                            as transaction_type
    , coalesce(nw.reseller_id, -1)                                                                                        as reseller_id
    , if(nw.sales_channel in (4, 6), 'NO_VISIBILITY', 'FULL_VISIBILITY')                                                  as reseller_visibility
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


-- SA Content (18)
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


-- Request Attribution (6)
    , if(bitwise_and(coalesce(request__extra_flags, 0), 1073741824) > 0 and coalesce(nw.nw_role, '') = 'CRO', -3, coalesce(request__context__profile_id, -1))  as profile_id -- mark CANOE_PROGRAMMER_LINEAR with -3
    , coalesce(request__context__profile_type, 'UNKNOWN')                                                                 as profile_type
    , case
        when bitwise_and(request__flags, 32)>0           then  'No Selection'      /* No Selection */
        when coalesce(request__advertisement_delivered_count, coalesce(request__advertisement_count, 0))=0 then 'Empty'           /* Selection without Ads in Response */
        else                                                   'Filled'            /* Selection with Ads in Response */
    end                                                                                                                   as request_fill_status
    , if(bitwise_and(coalesce(request__extra_flags,0), 1024)>0, 'true', 'false')                                              as live_linear_indicator
    , if(bitwise_and(coalesce(request__extra_flags2,0), 8)>0, 'true', 'false')                                                as ssp_bidder_indicator
    , if(bitwise_and(coalesce(bit_flag, 0), bitwise_shift_left(1, 40,64))>0, 'true', 'false')                                 as partner_tag_indicator

-- Slot Attribution (6)
    , array[coalesce(slot__time_position_class, 'Unknown')]                                                               as time_position_classes
    , array[coalesce(slot__normalized_ad_unit_id, -1)]                                                                               as slot_ad_unit_ids
    , array[coalesce(au.name,'NA')]                                                                                       as slot_ad_unit_names
    , case
        when slot__sequence is null then 'Null'
        when slot__sequence > 5 then '5+'
        else cast(slot__sequence as varchar)
    end                                                                                                                   as slot_sequence_normalized
    , 'Included'                                                                                                          as slot_user_drop_off
    , if(bitwise_and(coalesce(slot__flags, 0), 8)>0, 'Yes', 'No')                                                         as slot_removed_by_ux_indicator
    , case
        when slot__num_ads=0 then 'Empty'
        when slot__time_position_class='overlay' and slot__num_ads>0 and slot__num_ads=slot__max_ads then 'Fully Filled'
        when slot__time_position_class='overlay' and slot__num_ads>0 and slot__num_ads<slot__max_ads then 'Partially Filled'
        when slot__num_ads>0 and slot__unfilled_avails=0  then 'Fully Filled'
        when slot__num_ads>0 and slot__unfilled_avails>0  then 'Partially Filled'
        else 'Unknown'
    end                                                                                                                  as slot_fill_status

-- Ad Attribution (6)
    , if(
        bitwise_and(coalesce(advertisement__entity_flags, 0), bitwise_shift_left(1, 35, 64))>0, 'Yes', 'No')             as evergreen_ad_indicator
    , if(
        bitwise_and(coalesce(advertisement__entity_flags, 0), bitwise_shift_left(1, 2 , 64))>0, 'Yes', 'No')             as promo_ad_indicator
    , case
        -- 'Direct Sold'
        when nw.sales_channel = 2 then if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier, 'UNKNOWN'), coalesce(advertisement__unified_priority__priority_tier,'UNKNOWN'))
        -- 'Reseller Sold'
        when nw.sales_channel = 3 then coalesce(rule_priority_tier, 'UNKNOWN')
        -- 'Programmatic'
        when nw.sales_channel = 4 then if(is_extra_item_owner = true, coalesce(candidate__unified_deal_priority__priority_tier,coalesce(rule_priority_tier,'UNKNOWN')), 'UNKNOWN')
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
        when sales_channel = 4 then if(is_extra_item_owner = true, candidate__unified_deal_priority__sub_priority_value, rule_priority_value)
        -- 'Partner Trading(MPP) / Partner Tag / Marketplace Platform Exchange(MPE)'
        when sales_channel in (5,6) then outbound_order_priority_value
    else null end                                                                                                          as priority_value
    , if(is_extra_item_owner = true, advertisement__unified_priority__sub_priority_value, null)                            as ad_meta_priority_value -- ad owner
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
                            when coalesce(rule_priority,'UNKNOWN') = 'YOU_FIRST' then 'HARD_GUARANTEED_WITH_PASS_BACK'
                            when coalesce(rule_priority,'UNKNOWN') = 'ME_FIRST' then 'BACKFILL_ONLY'
                            when coalesce(rule_priority,'UNKNOWN') = 'HARD_GUARANTEED' then 'HARD_GUARANTEED_WITH_PASS_BACK'
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

-- Ad Level Dimensions(17)
    , coalesce(inbound_order_id, cast(-1 as bigint))                                                                    as inbound_order_id
    , coalesce(outbound_order_id, cast(-1 as bigint))                                                                   as outbound_order_id
    , coalesce(outbound_exchange_order_id, cast(-1 as bigint))                                                          as outbound_exchange_order_id
    , if(demand_dim_awareability , coalesce(candidate__dsp_id, -1), -1)                                                 as dsp_id
    , if(demand_dim_awareability , coalesce(candidate__buyer_platform_id, -1), -1)                                      as buyer_platform_id
    , if(deal_awareability , coalesce(candidate__internal_deal_id, -1), -1)                                             as deal_id
    , if(deal_awareability , coalesce(candidate__buyer_group_id, -1), -1)                                               as buyer_group_id
    , if(deal_awareability , coalesce(candidate__buyer_id, -1), -1)                                                     as buyer_id
    --, if(demand_dim_awareability , coalesce(candidate__market_ad_id, -1), -1)                                           as market_ad_id
    , coalesce(auction__site_domain,'NA')                                                                                    as site_domain
    , if(network_is_ad_owner,coalesce(advertisement__ad_id, -1),-1)                                                     as ad_id
    , if(network_is_ad_owner,coalesce(advertisement__placement_id, -1),-1)                                              as placement_id
   -- , if(network_is_ad_owner,coalesce(advertisement__creative_id, -1),-1)                                               as creative_id

    , coalesce(nw.global_currency_id, -1)                                                                               as global_currency_id
    , coalesce(request__global_currency_version, '')                                                                    as global_currency_version
    , coalesce(advertisement__global_advertiser_ids, array[])                                                           as global_advertiser_ids
    , coalesce(advertisement__global_brand_ids, array[])                                                                as global_brand_ids
    , coalesce(transform(coalesce(advertisement__global_advertiser_ids, array[]), x -> coalesce(element_at(adv_application_map, x), null)),array[]) as global_advertiser_names
    , coalesce(transform(coalesce(advertisement__global_brand_ids, array[]), x -> coalesce(element_at(brand_application_map, x), null)),array[]) as global_brand_names
    , coalesce(advertisement__advertiser_id, -1)                                                                        as local_advertiser_id
    , coalesce(advertisement__global_industry_ids,array[])                                                              as global_industry_ids
    , coalesce(transform(coalesce(advertisement__global_industry_ids, array[]), x -> coalesce(element_at(industry_map, x), null)),array[]) as global_industry_names
-- Process Time
    , process_batch_id                                                                                                  as process_batch_id
    , coalesce(request__cbp__slot_template_id ,-1)                                                                      as cbp_id
    , case when sales_channel = 6 then outbound_listing_id else array[] end as outbound_exchange_listing_id
    , case when advertisement__is_fallback then 'Fallback' else 'Primary' end as primary_ad_indicator
    --, coalesce(visitor__tracked_audience_item_ids , array[])                                                                               as audience_item_ids
-- Ad Metrics (5)
    , sum(1
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as placed_ads
    , sum(if(advertisement__is_fallback = true or advertisement__is_sstf_fallback = true, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as placed_fallback_ads
    , sum(if(advertisement__is_undeliverable = false , 1, 0)
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
    , sum(if(advertisement__is_undeliverable = false, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as raw_selected_primary_ads
    , sum(if(advertisement__is_fallback = false and advertisement__is_sstf_fallback = false and bitwise_and(advertisement__flags, 67108864) > 0, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as placed_ads_sstf_failed
    , sum(if(advertisement__is_fallback = false and advertisement__is_sstf_fallback = false and bitwise_and(advertisement__flags, 67108864) > 0 and bitwise_and(advertisement__flags, 512) = 0, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as placed_ads_sstf_failed_no_fallback
    , sum(if(advertisement__is_fallback = false and advertisement__is_sstf_fallback = false and bitwise_and(advertisement__flags, 67108864) > 0 and bitwise_and(advertisement__flags, 512) > 0, 1, 0)
        * coalesce(request__multiplier, 1)
        * coalesce(request__magnifier, 1)
        * coalesce(request__log_sampling__magnifier, 1))                                                                as placed_ads_sstf_failed_with_fallback

 -- ad error metrics(48)
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'FLOOR_PRICE_NOTMET' then 1 else 0 end) as  ad_err_floor_price_notmet
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'FLOOR_PRICE_NOTMET' then 1 else 0 end) as  ad_err_floor_price_notmet_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'UNEXPECTED_EXTERNAL_AD_ID' then 1 else 0 end) as  ad_err_unexpected_external_ad_id
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'UNEXPECTED_EXTERNAL_AD_ID' then 1 else 0 end) as  ad_err_unexpected_external_ad_id_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'NO_VALID_CREATIVE' then 1 else 0 end) as  ad_err_no_valid_creative
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'NO_VALID_CREATIVE' then 1 else 0 end) as  ad_err_no_valid_creative_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'MALFORMED_RESPONSE' then 1 else 0 end) as  ad_err_malformed_response
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'MALFORMED_RESPONSE' then 1 else 0 end) as  ad_err_malformed_response_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'COMPETITION_FAILURE' then 1 else 0 end) as  ad_err_competition_failure
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'COMPETITION_FAILURE' then 1 else 0 end) as  ad_err_competition_failure_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'JITT_RENDITION_REQUIRED' then 1 else 0 end) as  ad_err_jitt_rendition_required
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'JITT_RENDITION_REQUIRED' then 1 else 0 end) as  ad_err_jitt_rendition_required_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'NO_SLOT_SELECTED' then 1 else 0 end) as  ad_err_no_slot_selected
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'NO_SLOT_SELECTED' then 1 else 0 end) as  ad_err_no_slot_selected_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'EMPTY_RESPONSE' then 1 else 0 end) as  ad_err_empty_response
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'EMPTY_RESPONSE' then 1 else 0 end) as  ad_err_empty_response_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'INAPPLICABLE_FOR_HTTPS' then 1 else 0 end) as  ad_err_inapplicable_for_https
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'INAPPLICABLE_FOR_HTTPS' then 1 else 0 end) as  ad_err_inapplicable_for_https_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'AD_PENDING_APPROVAL' then 1 else 0 end) as  ad_err_ad_pending_approval
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'AD_PENDING_APPROVAL' then 1 else 0 end) as  ad_err_ad_pending_approval_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'BID_RESPONSE_ID_NOMATCH' then 1 else 0 end) as  ad_err_bid_response_id_nomatch
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'BID_RESPONSE_ID_NOMATCH' then 1 else 0 end) as  ad_err_bid_response_id_nomatch_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'WRAPPER_TIMEOUT' then 1 else 0 end) as  ad_err_warpper_timeout
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'WRAPPER_TIMEOUT' then 1 else 0 end) as  ad_err_warpper_timeout_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'COMPLIANCE_NOT_APPROVED' then 1 else 0 end) as  ad_err_compliance_not_approved
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'COMPLIANCE_NOT_APPROVED' then 1 else 0 end) as  ad_err_compliance_not_approved_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'HTTP_ERROR' then 1 else 0 end) as  ad_err_http_error
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'HTTP_ERROR' then 1 else 0 end) as  ad_err_http_error_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'NO_BIDS' then 1 else 0 end) as  ad_err_no_bids
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'NO_BIDS' then 1 else 0 end) as  ad_err_no_bids_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED' then 1 else 0 end) as  ad_err_external_creative_profile_check_failed
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'EXTERNAL_CREATIVE_PROFILE_CHECK_FAILED' then 1 else 0 end) as  ad_err_external_creative_profile_check_failed_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'AUCTION_MAX_AD_DURATION_EXCEEDED' then 1 else 0 end) as  ad_err_auction_max_ad_duration_exceeded
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'AUCTION_MAX_AD_DURATION_EXCEEDED' then 1 else 0 end) as  ad_err_auction_max_ad_duration_exceeded_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'WRAPPER_HTTP_ERROR' then 1 else 0 end) as  ad_err_warpper_http_error
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'WRAPPER_HTTP_ERROR' then 1 else 0 end) as  ad_err_warpper_http_error_no_fallback
    , sum(case when advertisement__is_undeliverable = true and coalesce(candidate__error,advertisement__error) = 'TIMEOUT' then 1 else 0 end) as  ad_err_timeout
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and coalesce(candidate__error,advertisement__error) = 'TIMEOUT' then 1 else 0 end) as  ad_err_timeout_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__error = 'NO_CONTENT' then 1 else 0 end) as  ad_err_no_content
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and advertisement__error = 'NO_CONTENT' then 1 else 0 end) as  ad_err_no_content_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__error = 'MAX_WRAPPER_REDIRECT' then 1 else 0 end) as  ad_err_max_warpper_redirect
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and advertisement__error = 'MAX_WRAPPER_REDIRECT' then 1 else 0 end) as  ad_err_max_warpper_redirect_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__error = 'EMPTY_BID_DEALID' then 1 else 0 end) as  ad_err_empty_bid_dealid
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and advertisement__error = 'EMPTY_BID_DEALID' then 1 else 0 end) as  ad_err_empty_bid_dealid_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__error = 'INVALID_WRAPPER_URL' then 1 else 0 end) as  ad_err_invalid_wrapper_url
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and advertisement__error = 'INVALID_WRAPPER_URL' then 1 else 0 end) as  ad_err_invalid_wrapper_url_no_fallback
    , sum(case when advertisement__is_undeliverable = true and advertisement__error = 'PROFILE_CHECK_FAILED' then 1 else 0 end) as  ad_err_profile_check_failed
    , sum(case when advertisement__is_undeliverable = true and advertisement__is_fallback = false and bitwise_and(advertisement__flags, 512) = 0 and advertisement__error = 'PROFILE_CHECK_FAILED' then 1 else 0 end) as  ad_err_profile_check_failed_no_fallback

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

    ,date_trunc('HOUR', request__timestamp) as event_date

from ${facts}.ad
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
    partners__inbound_order_id,
    partners__unified_outbound_order_priority__priority_tier,
    partners__unified_outbound_order_priority__sub_priority_value,
    partners__outbound_order_priority_type,
    partners__unified_rule_priority__priority_tier,
    partners__unified_rule_priority__sub_priority_value,
    partners__rule_type_priority,
    partners__bit_flags,
    partners__outbound_listing_id
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
    inbound_order_id,
    order_priority_tier,
    outbound_order_priority_value,
    order_priority,
    rule_priority_tier,
    rule_priority_value,
    rule_priority,
    bit_flag,
    outbound_listing_id
)
left join db.default.d_network reseller on reseller.id = coalesce(nw.reseller_id, -1)
left join db.default.d_ad_unit au on au.id = coalesce(slot__normalized_ad_unit_id,-1)
join global_brand_map on 1=1
join global_adv_map on 1=1
join global_industry_map on 1=1
where
    process_batch_id = '${arena.presto.var.process_batch_id}'
    and ${sampling_filter} --sampling filter
    and bitwise_and(slot__flags, 64) = 0                                                    -- No Parent Slot
    and coalesce(nw.nw_role, '') in ('CRO', 'R')
    and coalesce(advertisement__is_bumper, false) = false                                   -- Remove Bumper Ad
    and supply_source != 4                                                                          -- filter out DSP shell networks
    and not(bitwise_and(bit_flag, bitwise_shift_left(1, 34, 64)) > 0 and coalesce(nw.nw_role, '') = 'CRO')  -- filter out SSP shell networks
    and bitwise_and(bit_flag, bitwise_shift_left(1, 41, 64)) = 0                                    -- filter out partner tag buyer
group by 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,date_trunc('HOUR', request__timestamp)

union all

-- Ack
select
    cast(32 as int) as process_stage

-- Network Chain (10)
    , coalesce(nw.nw_id, -1)                                                                                              as network_id
    , coalesce(request__context__video_cro_network_id, -1)                                                                as video_cro_network_id
    , coalesce(nw.co_id, -1)                                                                                              as content_owner_id
    , if(nw.supply_source = 6 and bitwise_and(coalesce(request__extra_flags2, 0), 8) = 0 and nw.nw_id != 523319, 'NO_VISIBILITY', 'FULL_VISIBILITY') as content_owner_visibility -- MPE:supply_source = 6, Bidder Traffic: SSP_BIDDER_TRAFFIC = 8, FW Marketplace Bundled Deals: network_id=523319
    , if(bitwise_and(coalesce(request__extra_flags, 0), 1073741824) > 0 and coalesce(nw.nw_role, '') = 'CRO', -3, coalesce(nw.distributor_id, -1))   as distributor_id -- mark CANOE_PROGRAMMER_LINEAR with -3
    , coalesce(nw.nw_role, '')                                                                                            as transaction_type
    , coalesce(nw.reseller_id, -1)                                                                                        as reseller_id
    , if(nw.sales_channel in (4, 6), 'NO_VISIBILITY', 'FULL_VISIBILITY')                                                  as reseller_visibility
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


-- SA Content (18)
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


-- Request Attribution (6)
    , if(bitwise_and(coalesce(request__extra_flags, 0), 1073741824) > 0 and coalesce(nw.nw_role, '') = 'CRO', -3, coalesce(request__context__profile_id, -1))  as profile_id -- mark CANOE_PROGRAMMER_LINEAR with -3
    , coalesce(request__context__profile_type, 'UNKNOWN')                                                                 as profile_type
    , case
        when bitwise_and(request__flags, 32)>0           then  'No Selection'      /* No Selection */
        when coalesce(request__advertisement_delivered_count, coalesce(request__advertisement_count, 0))=0 then 'Empty'             /* Selection without Ads in Response */
        else                                                   'Filled'            /* Selection with Ads in Response */
    end                                                                                                                   as request_fill_status
    , if(bitwise_and(coalesce(request__extra_flags,0), 1024)>0, 'true', 'false')                                              as live_linear_indicator
    , if(bitwise_and(coalesce(request__extra_flags2,0), 8)>0, 'true', 'false')                                                as ssp_bidder_indicator
    , if(bitwise_and(coalesce(bit_flag, 0), bitwise_shift_left(1, 40,64))>0, 'true', 'false')                                   as partner_tag_indicator

-- Slot Attribution (6)
    , array[coalesce(slot__time_position_class, 'Unknown')]                                                               as time_position_classes
    , array[coalesce(slot__normalized_ad_unit_id, -1)]                                                                               as slot_ad_unit_ids
    , array[coalesce(au.name,'NA')]                                                                                       as slot_ad_unit_names
    , case
        when slot__sequence is null then 'Null'
        when slot__sequence > 5 then '5+'
        else cast(slot__sequence as varchar)
    end                                                                                                                   as slot_sequence_normalized
    , 'Not Applicable'                                                                                                    as slot_user_drop_off
    , if(bitwise_and(coalesce(slot__flags, 0), 8)>0, 'Yes', 'No')                                                         as slot_removed_by_ux_indicator
    , case
        when slot__num_ads=0 then 'Empty'
        when slot__time_position_class='overlay' and slot__num_ads>0 and slot__num_ads=slot__max_ads then 'Fully Filled'
        when slot__time_position_class='overlay' and slot__num_ads>0 and slot__num_ads<slot__max_ads then 'Partially Filled'
        when slot__num_ads>0 and slot__unfilled_avails=0  then 'Fully Filled'
        when slot__num_ads>0 and slot__unfilled_avails>0  then 'Partially Filled'
        else 'Unknown'
    end                                                                                                                   as slot_fill_status

-- Ad Attribution (6)
    , if(
        bitwise_and(coalesce(advertisement__entity_flags, 0), bitwise_shift_left(1, 35, 64))>0, 'Yes', 'No')             as evergreen_ad_indicator
    , if(
        bitwise_and(coalesce(advertisement__entity_flags, 0), bitwise_shift_left(1, 2 , 64))>0, 'Yes', 'No')             as promo_ad_indicator
    , case
        -- 'Direct Sold'
        when nw.sales_channel = 2 then if(nw_role = 'CRO', coalesce(advertisement__effective_unified_priority__priority_tier, 'UNKNOWN'), coalesce(advertisement__unified_priority__priority_tier,'UNKNOWN'))
        -- 'Reseller Sold'
        when nw.sales_channel = 3 then coalesce(rule_priority_tier, 'UNKNOWN')
        -- 'Programmatic'
        when nw.sales_channel = 4 then if(is_extra_item_owner = true, coalesce(candidate__unified_deal_priority__priority_tier,coalesce(rule_priority_tier,'UNKNOWN')), 'UNKNOWN')
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
        when sales_channel = 4 then if(is_extra_item_owner = true, candidate__unified_deal_priority__sub_priority_value, rule_priority_value)
        -- 'Partner Trading(MPP) / Partner Tag / Marketplace Platform Exchange(MPE)'
        when sales_channel in (5,6) then outbound_order_priority_value
    else null end                                                                                                          as priority_value
    , if(is_extra_item_owner = true, advertisement__unified_priority__sub_priority_value, null)                            as ad_meta_priority_value -- ad owner
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
                            when coalesce(rule_priority,'UNKNOWN') = 'YOU_FIRST' then 'HARD_GUARANTEED_WITH_PASS_BACK'
                            when coalesce(rule_priority,'UNKNOWN') = 'ME_FIRST' then 'BACKFILL_ONLY'
                            when coalesce(rule_priority,'UNKNOWN') = 'HARD_GUARANTEED' then 'HARD_GUARANTEED_WITH_PASS_BACK'
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

-- Ad Level Dimensions(17)
    , coalesce(inbound_order_id, cast(-1 as bigint)) as inbound_order_id
    , coalesce(outbound_order_id, cast(-1 as bigint)) as outbound_order_id
    , coalesce(outbound_exchange_order_id, cast(-1 as bigint)) as outbound_exchange_order_id
    , if(demand_dim_awareability , coalesce(candidate__dsp_id, -1), -1) as dsp_id
    , if(demand_dim_awareability , coalesce(candidate__buyer_platform_id, -1), -1) as buyer_platform_id
    , if(deal_awareability , coalesce(candidate__internal_deal_id, -1), -1) as deal_id
    , if(deal_awareability , coalesce(candidate__buyer_group_id, -1), -1) as buyer_group_id
    , if(deal_awareability , coalesce(candidate__buyer_id, -1), -1) as buyer_id
   -- , if(demand_dim_awareability , coalesce(candidate__market_ad_id, -1), -1) as market_ad_id
    , coalesce(auction__site_domain,'NA')                                                                                    as site_domain
    , if(network_is_ad_owner,coalesce(advertisement__ad_id, -1),-1) as ad_id
    , if(network_is_ad_owner,coalesce(advertisement__placement_id, -1),-1) as placement_id
    --, if(network_is_ad_owner,coalesce(advertisement__creative_id, -1),-1) as creative_id

    , coalesce(nw.global_currency_id, -1) as global_currency_id
    , coalesce(request__global_currency_version, '') as global_currency_version
    , coalesce(advertisement__global_advertiser_ids, array[])                                                           as global_advertiser_ids
    , coalesce(advertisement__global_brand_ids, array[])                                                                as global_brand_ids
    , coalesce(transform(coalesce(advertisement__global_advertiser_ids, array[]), x -> coalesce(element_at(adv_application_map, x), null)),array[]) as global_advertiser_names
    , coalesce(transform(coalesce(advertisement__global_brand_ids, array[]), x -> coalesce(element_at(brand_application_map, x), null)),array[]) as global_brand_names
    , coalesce(advertisement__advertiser_id, -1)                                                                        as local_advertiser_id
    , coalesce(advertisement__global_industry_ids,array[])                                                              as global_industry_ids
    , coalesce(transform(coalesce(advertisement__global_industry_ids, array[]), x -> coalesce(element_at(industry_map, x), null)),array[]) as global_industry_names
-- Process Time
    , process_batch_id                                                 as process_batch_id

    , coalesce(request__cbp__slot_template_id ,-1)                                                                      as cbp_id
    , case when sales_channel = 6 then outbound_listing_id else array[] end as outbound_exchange_listing_id
    , case when advertisement__is_fallback then 'Fallback' else 'Primary' end as primary_ad_indicator
    --, coalesce(visitor__tracked_audience_item_ids , array[])                                                            as audience_item_ids

-- Ad Metrics (5)
    , cast(0 as bigint)                                                                as placed_ads
    , cast(0 as bigint)                                                                as placed_fallback_ads
    , cast(0 as bigint)                                                                as filled_ads
    , cast(0 as bigint)                                                                as filled_ads_duration
    , cast(0 as bigint)                                                                as filled_ads_sstf_fallback
    , cast(0 as bigint)                                                                as raw_selected_primary_ads
    , cast(0 as bigint)                                                                as placed_ads_sstf_failed
    , cast(0 as bigint)                                                                as placed_ads_sstf_failed_no_fallback
    , cast(0 as bigint)                                                                as placed_ads_sstf_failed_with_fallback

 -- ad error metrics(48)
    , cast(0 as bigint) as ad_err_floor_price_notmet
    , cast(0 as bigint) as ad_err_floor_price_notmet_no_fallback
    , cast(0 as bigint) as ad_err_unexpected_external_ad_id
    , cast(0 as bigint) as ad_err_unexpected_external_ad_id_no_fallback
    , cast(0 as bigint) as ad_err_no_valid_creative
    , cast(0 as bigint) as ad_err_no_valid_creative_no_fallback
    , cast(0 as bigint) as ad_err_malformed_response
    , cast(0 as bigint) as ad_err_malformed_response_no_fallback
    , cast(0 as bigint) as ad_err_competition_failure
    , cast(0 as bigint) as ad_err_competition_failure_no_fallback
    , cast(0 as bigint) as ad_err_jitt_rendition_required
    , cast(0 as bigint) as ad_err_jitt_rendition_required_no_fallback
    , cast(0 as bigint) as ad_err_no_slot_selected
    , cast(0 as bigint) as ad_err_no_slot_selected_no_fallback
    , cast(0 as bigint) as ad_err_empty_response
    , cast(0 as bigint) as ad_err_empty_response_no_fallback
    , cast(0 as bigint) as ad_err_inapplicable_for_https
    , cast(0 as bigint) as ad_err_inapplicable_for_https_no_fallback
    , cast(0 as bigint) as ad_err_ad_pending_approval
    , cast(0 as bigint) as ad_err_ad_pending_approval_no_fallback
    , cast(0 as bigint) as ad_err_bid_response_id_nomatch
    , cast(0 as bigint) as ad_err_bid_response_id_nomatch_no_fallback
    , cast(0 as bigint) as ad_err_warpper_timeout
    , cast(0 as bigint) as ad_err_warpper_timeout_no_fallback
    , cast(0 as bigint) as ad_err_compliance_not_approved
    , cast(0 as bigint) as ad_err_compliance_not_approved_no_fallback
    , cast(0 as bigint) as ad_err_http_error
    , cast(0 as bigint) as ad_err_http_error_no_fallback
    , cast(0 as bigint) as ad_err_no_bids
    , cast(0 as bigint) as ad_err_no_bids_no_fallback
    , cast(0 as bigint) as ad_err_external_creative_profile_check_failed
    , cast(0 as bigint) as ad_err_external_creative_profile_check_failed_no_fallback
    , cast(0 as bigint) as ad_err_auction_max_ad_duration_exceeded
    , cast(0 as bigint) as ad_err_auction_max_ad_duration_exceeded_no_fallback
    , cast(0 as bigint) as ad_err_warpper_http_error
    , cast(0 as bigint) as ad_err_warpper_http_error_no_fallback
    , cast(0 as bigint) as ad_err_timeout
    , cast(0 as bigint) as ad_err_timeout_no_fallback
    , cast(0 as bigint) as ad_err_no_content
    , cast(0 as bigint) as ad_err_no_content_no_fallback
    , cast(0 as bigint) as ad_err_max_warpper_redirect
    , cast(0 as bigint) as ad_err_max_warpper_redirect_no_fallback
    , cast(0 as bigint) as ad_err_empty_bid_dealid
    , cast(0 as bigint) as ad_err_empty_bid_dealid_no_fallback
    , cast(0 as bigint) as ad_err_invalid_wrapper_url
    , cast(0 as bigint) as ad_err_invalid_wrapper_url_no_fallback
    , cast(0 as bigint) as ad_err_profile_check_failed
    , cast(0 as bigint) as ad_err_profile_check_failed_no_fallback

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

    ,date_trunc('HOUR', ack__timestamp) as event_date

from ${facts}.ack
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
    partners__inbound_order_id,
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
    partners__bit_flags,
    partners__outbound_listing_id
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
    inbound_order_id,
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
    bit_flag,
    outbound_listing_id
)
left join db.default.d_network reseller on reseller.id = coalesce(nw.reseller_id, -1)
left join db.default.d_ad_unit au on au.id = coalesce(slot__normalized_ad_unit_id,-1)
join global_brand_map on 1=1
join global_adv_map on 1=1
join global_industry_map on 1=1
where
    process_batch_id = '${arena.presto.var.process_batch_id}'
    and ${sampling_filter} --sampling filter
    and bitwise_and(slot__flags, 64) = 0                                                    -- No Parent Slot
    and coalesce(nw.nw_role, '') in ('CRO', 'R')
    and coalesce(advertisement__is_bumper, false) = false                                   -- Remove Bumper Ad
    and supply_source != 4                                                                          -- filter out DSP shell networks
    and not(bitwise_and(bit_flag, bitwise_shift_left(1, 34, 64)) > 0 and coalesce(nw.nw_role, '') = 'CRO')  -- filter out SSP shell networks
    and bitwise_and(bit_flag, bitwise_shift_left(1, 41, 64)) = 0                                    -- filter out partner tag buyer
    and coalesce(ack__ack_entity_type, '') = 'ad'
    and (ack__is_private_impression = false or network_is_ad_owner = true or is_extra_item_owner = true)
group by 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,76,77,78,79,date_trunc('HOUR', ack__timestamp)
) t
left join db.default.d_network reseller on reseller.id = coalesce(reseller_id, -1)
left join db.default.d_network dis on dis.id = distributor_id
left join db.default.d_network network on network.id = t.network_id
left join db.default.d_network vcro on vcro.id = t.video_cro_network_id
left join db.default.d_network co on co.id = content_owner_id
left join db.default.d_ad_environment_compound_profile p on p.id = profile_id
left join db.default.d_lu_mkpl_endpoint as ep on ep.id = coalesce(standard_endpoint_id,-1)
left join db.default.d_lu_mkpl_endpoint_owner eo on eo.id = coalesce(standard_endpoint_owner_id,-1)
left join db.default.d_ssp_demand_side_platform ssp on ssp.network_id = reseller_id
left join db.default.d_lu_mkpl_standard_programmer pg on pg.id = coalesce(standard_programmer_id, -1)
left join db.default.d_lu_mkpl_standard_publisher publisher on publisher.id = coalesce(standard_publisher_id, -1)
left join db.default.d_lu_mkpl_standard_app app on app.id = coalesce(standard_app_id, -1)
left join db.default.d_lu_mkpl_standard_brand brand on brand.id = coalesce(standard_brand_id, -1)
left join db.default.d_advertiser adv on adv.id = coalesce(local_advertiser_id,-1)
left join (select site_id,site_name from db.default.d_site_section group by 1,2) as s on s.site_id = coalesce(t.site_id,-1)
left join (select id,name from db.default.d_site_section group by 1,2) as ss on ss.id = coalesce(site_section_id,-1)
left join db.default.d_lu_mkpl_standard_content_form cf on cf.id = content_form_id
left join db.default.d_lu_mkpl_stream_mode sm on sm.id = stream_mode_id
left join db.default.d_country country on country.id = user_country_id
left join db.default.d_lu_mkpl_standard_device_type device on device.id = standard_device_type_id
left join db.default.d_lu_mkpl_standard_environment env on env.id = standard_environment_id
left join db.default.d_lu_mkpl_standard_os os on os.id = standard_os_id
left join (select distinct id,display_name from db.default.d_lu_user_agent_platform where type = 'DEVICE') platform_device on platform_device.id = delivered_platform_device_id
left join db.default.d_ssp_demand_side_platform dsp on dsp.id=dsp_id
left join db.default.d_ssp_buyer_platform bp on bp.id = buyer_platform_id
left join db.default.d_ssp_buyer_group bg on bg.id = buyer_group_id
left join (select id,name,order_type,internal_module from db.default.d_mkpl_order) in_order on in_order.id = inbound_order_id
left join (select id,name,order_type,internal_module from db.default.d_mkpl_order) out_order on out_order.id = outbound_order_id
left join db.default.d_ssp_deal_metadata d_ssp_deal_metadata on d_ssp_deal_metadata.id = deal_id
--left join db.default.d_lu_mkpl_standard_site_domain domain on domain.id = site_domain_id
group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94