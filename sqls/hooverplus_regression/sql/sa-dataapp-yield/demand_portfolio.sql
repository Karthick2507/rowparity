-- account:    sa-dataapp-yield
-- skeleton:   ba608175e3ca40ec66bd09e4f4fd2d85
-- pattern:    1f4d399759b0e382247427f2ea80d54f  (704 execution(s))
-- in suite:   daily commitment
-- hoover:     ack, ad
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH global_brand_map AS (
  SELECT
    MAP_AGG(id, name) AS brand_application_map
  FROM db.default.d_global_brand_advertiser
  WHERE
    type = 'brand'
), global_adv_map AS (
  SELECT
    MAP_AGG(id, name) AS adv_application_map
  FROM db.default.d_global_brand_advertiser
  WHERE
    type = 'standard'
), global_industry_map AS (
  SELECT
    MAP_AGG(id, name) AS industry_map
  FROM db.default.d_lu_advertiser_industry
)
SELECT
  event_date AS timestamp,
  t.network_id,
  COALESCE(network.name, 'na') AS network_name,
  t.video_cro_network_id,
  COALESCE(vcro.name, 'na') AS video_cro_network_name,
  content_owner_id,
  COALESCE(co.name, 'na') AS content_owner_name,
  distributor_id,
  COALESCE(dis.name, 'na') AS distributor_name,
  t.transaction_type,
  reseller_id,
  COALESCE(reseller.name, 'na') AS reseller_name,
  reseller_network_type,
  CASE
    WHEN t.supply_source = 1
    THEN 'o&o'
    WHEN t.supply_source = 3 AND network.network_type = 'full'
    THEN 'mrm2mrm'
    WHEN t.supply_source = 3 AND network.network_type = 'internal'
    THEN 'reseller tag'
    WHEN t.supply_source = 4
    THEN 'programmatic'
    WHEN t.supply_source = 5
    THEN 'partner trading(mpp)'
    WHEN t.supply_source = 6
    THEN 'marketplace platform exchange(mpe)'
    ELSE 'unkown supply source'
  END AS supply_source,
  CASE
    WHEN t.sales_channel = 2
    THEN 'direct sold'
    WHEN t.sales_channel = 3 AND reseller.network_type = 'full'
    THEN 'mrm2mrm'
    WHEN t.sales_channel = 3 AND reseller.network_type = 'internal'
    THEN 'reseller tag'
    WHEN t.sales_channel = 4
    THEN 'programmatic'
    WHEN t.sales_channel = 5 AND partner_tag_indicator = 'true'
    THEN 'partner tag'
    WHEN t.sales_channel = 5
    THEN 'partner trading(mpp)'
    WHEN t.sales_channel = 6
    THEN 'marketplace platform exchange(mpe)'
    ELSE 'na'
  END AS sales_channel,
  sales_strategy,
  t.site_id,
  COALESCE(s.site_name, 'na') AS site_name,
  site_section_id,
  COALESCE(ss.name, 'na') AS site_section_name,
  standard_publisher_id,
  COALESCE(publisher.name, 'na') AS standard_publisher_name,
  standard_brand_id,
  COALESCE(brand.name, 'na') AS standard_brand_name,
  standard_programmer_id,
  COALESCE(pg.name, 'na') AS standard_programmer_name,
  content_form_id,
  COALESCE(cf.name, 'na') AS content_form_name,
  stream_mode_id,
  COALESCE(sm.name, 'na') AS stream_mode_name,
  standard_endpoint_owner_id,
  COALESCE(eo.name, 'na') AS standard_endpoint_owner_name,
  standard_endpoint_id,
  COALESCE(ep.name, 'na') AS standard_endpoint_name,
  user_country_id,
  COALESCE(country.name, 'na') AS user_country_name,
  standard_device_type_id,
  COALESCE(device.name, 'na') AS standard_device_type_name,
  profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  profile_type,
  request_fill_status,
  live_linear_indicator,
  ssp_bidder_indicator,
  partner_tag_indicator,
  time_position_classes,
  slot_ad_unit_ids,
  slot_ad_unit_names,
  slot_sequence_normalized,
  slot_user_drop_off,
  slot_removed_by_ux_indicator,
  slot_fill_status,
  evergreen_ad_indicator,
  promo_ad_indicator,
  priority_tier,
  CASE
    WHEN priority_tier = 'tier_1' AND priority_type = 'sponsorship'
    THEN COALESCE(ad_meta_priority_value, 25)
    WHEN priority_tier = 'tier_1' AND priority_value IS NULL
    THEN 25
    WHEN priority_tier = 'tier_2' AND priority_value IS NULL
    THEN 11
    WHEN priority_tier IN ('tier_3', 'tier_4', 'tier_5')
    AND priority_type LIKE '%sponsorship%'
    THEN COALESCE(priority_value, 0)
    WHEN priority_tier IN ('tier_3', 'tier_4', 'tier_5')
    AND (
      priority_value IS NULL OR priority_value < 0 OR priority_value > 10
    )
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
  COALESCE(in_order.name, 'na') AS inbound_order_name,
  COALESCE(in_order.order_type, 'na') AS inbound_order_type,
  COALESCE(in_order.internal_module, 'na') AS inbound_internal_module,
  outbound_order_id,
  COALESCE(out_order.name, 'na') AS outbound_order_name,
  COALESCE(out_order.order_type, 'na') AS outbound_order_type,
  COALESCE(out_order.internal_module, 'na') AS outbound_internal_module,
  outbound_exchange_order_id,
  dsp_id,
  COALESCE(dsp.name, 'na') AS dsp_name,
  buyer_platform_id,
  COALESCE(bp.name, 'na') AS buyer_platform_name,
  deal_id,
  COALESCE(d_ssp_deal_metadata.external_id, 'na') AS public_deal_id,
  buyer_group_id,
  COALESCE(bg.name, 'na') AS buyer_group_name,
  buyer_id,
  ad_id,
  placement_id,
  global_currency_id,
  global_currency_version,
  IF(
    CARDINALITY(global_advertiser_ids) > 3,
    SLICE(ARRAY_SORT(global_advertiser_ids), 1, 3),
    ARRAY_SORT(global_advertiser_ids)
  ) AS global_advertiser_ids,
  IF(
    CARDINALITY(global_advertiser_names) > 3,
    SLICE(ARRAY_SORT(global_advertiser_names), 1, 3),
    ARRAY_SORT(global_advertiser_names)
  ) AS global_advertiser_names,
  IF(
    CARDINALITY(global_brand_ids) > 3,
    SLICE(ARRAY_SORT(global_brand_ids), 1, 3),
    ARRAY_SORT(global_brand_ids)
  ) AS global_brand_ids,
  IF(
    CARDINALITY(global_brand_names) > 3,
    SLICE(ARRAY_SORT(global_brand_names), 1, 3),
    ARRAY_SORT(global_brand_names)
  ) AS global_brand_names,
  IF(
    CARDINALITY(global_industry_ids) > 3,
    SLICE(ARRAY_SORT(global_industry_ids), 1, 3),
    ARRAY_SORT(global_industry_ids)
  ) AS global_industry_ids,
  IF(
    CARDINALITY(global_industry_names) > 3,
    SLICE(ARRAY_SORT(global_industry_names), 1, 3),
    ARRAY_SORT(global_industry_names)
  ) AS global_industry_names,
  local_advertiser_id,
  COALESCE(adv.name, 'na') AS local_advertiser_name,
  process_batch_id,
  cbp_id,
  outbound_exchange_listing_id AS outbound_exchange_listing_ids,
  CASE
    WHEN t.sales_channel = 2
    THEN 'ad/placement'
    WHEN t.sales_channel = 4
    THEN 'programmatic'
    ELSE 'others'
  END AS demand_type,
  primary_ad_indicator,
  service_type,
  REDUCE(SET_AGG(process_stage), 0, (acc, val) -> acc + val, val -> val) AS process_stage,
  SUM(placed_ads) AS placed_ads,
  SUM(placed_fallback_ads) AS placed_fallback_ads,
  SUM(filled_ads) AS filled_ads,
  SUM(filled_ads_duration) AS filled_ads_duration,
  SUM(filled_ads_sstf_fallback) AS filled_ads_sstf_fallback,
  SUM(raw_selected_primary_ads) AS raw_selected_primary_ads,
  SUM(placed_ads_sstf_failed) AS placed_ads_sstf_failed,
  SUM(placed_ads_sstf_failed_no_fallback) AS placed_ads_sstf_failed_no_fallback,
  SUM(placed_ads_sstf_failed_with_fallback) AS placed_ads_sstf_failed_with_fallback,
  SUM(ad_err_floor_price_notmet) AS ad_err_floor_price_notmet,
  SUM(ad_err_floor_price_notmet_no_fallback) AS ad_err_floor_price_notmet_no_fallback,
  SUM(ad_err_unexpected_external_ad_id) AS ad_err_unexpected_external_ad_id,
  SUM(ad_err_unexpected_external_ad_id_no_fallback) AS ad_err_unexpected_external_ad_id_no_fallback,
  SUM(ad_err_no_valid_creative) AS ad_err_no_valid_creative,
  SUM(ad_err_no_valid_creative_no_fallback) AS ad_err_no_valid_creative_no_fallback,
  SUM(ad_err_malformed_response) AS ad_err_malformed_response,
  SUM(ad_err_malformed_response_no_fallback) AS ad_err_malformed_response_no_fallback,
  SUM(ad_err_competition_failure) AS ad_err_competition_failure,
  SUM(ad_err_competition_failure_no_fallback) AS ad_err_competition_failure_no_fallback,
  SUM(ad_err_jitt_rendition_required) AS ad_err_jitt_rendition_required,
  SUM(ad_err_jitt_rendition_required_no_fallback) AS ad_err_jitt_rendition_required_no_fallback,
  SUM(ad_err_no_slot_selected) AS ad_err_no_slot_selected,
  SUM(ad_err_no_slot_selected_no_fallback) AS ad_err_no_slot_selected_no_fallback,
  SUM(ad_err_empty_response) AS ad_err_empty_response,
  SUM(ad_err_empty_response_no_fallback) AS ad_err_empty_response_no_fallback,
  SUM(ad_err_inapplicable_for_https) AS ad_err_inapplicable_for_https,
  SUM(ad_err_inapplicable_for_https_no_fallback) AS ad_err_inapplicable_for_https_no_fallback,
  SUM(ad_err_ad_pending_approval) AS ad_err_ad_pending_approval,
  SUM(ad_err_ad_pending_approval_no_fallback) AS ad_err_ad_pending_approval_no_fallback,
  SUM(ad_err_bid_response_id_nomatch) AS ad_err_bid_response_id_nomatch,
  SUM(ad_err_bid_response_id_nomatch_no_fallback) AS ad_err_bid_response_id_nomatch_no_fallback,
  SUM(ad_err_warpper_timeout) AS ad_err_warpper_timeout,
  SUM(ad_err_warpper_timeout_no_fallback) AS ad_err_warpper_timeout_no_fallback,
  SUM(ad_err_compliance_not_approved) AS ad_err_compliance_not_approved,
  SUM(ad_err_compliance_not_approved_no_fallback) AS ad_err_compliance_not_approved_no_fallback,
  SUM(ad_err_http_error) AS ad_err_http_error,
  SUM(ad_err_http_error_no_fallback) AS ad_err_http_error_no_fallback,
  SUM(ad_err_no_bids) AS ad_err_no_bids,
  SUM(ad_err_no_bids_no_fallback) AS ad_err_no_bids_no_fallback,
  SUM(ad_err_external_creative_profile_check_failed) AS ad_err_external_creative_profile_check_failed,
  SUM(ad_err_external_creative_profile_check_failed_no_fallback) AS ad_err_external_creative_profile_check_failed_no_fallback,
  SUM(ad_err_auction_max_ad_duration_exceeded) AS ad_err_auction_max_ad_duration_exceeded,
  SUM(ad_err_auction_max_ad_duration_exceeded_no_fallback) AS ad_err_auction_max_ad_duration_exceeded_no_fallback,
  SUM(ad_err_warpper_http_error) AS ad_err_warpper_http_error,
  SUM(ad_err_warpper_http_error_no_fallback) AS ad_err_warpper_http_error_no_fallback,
  SUM(ad_err_timeout) AS ad_err_timeout,
  SUM(ad_err_timeout_no_fallback) AS ad_err_timeout_no_fallback,
  SUM(ad_err_no_content) AS ad_err_no_content,
  SUM(ad_err_no_content_no_fallback) AS ad_err_no_content_no_fallback,
  SUM(ad_err_max_warpper_redirect) AS ad_err_max_warpper_redirect,
  SUM(ad_err_max_warpper_redirect_no_fallback) AS ad_err_max_warpper_redirect_no_fallback,
  SUM(ad_err_empty_bid_dealid) AS ad_err_empty_bid_dealid,
  SUM(ad_err_empty_bid_dealid_no_fallback) AS ad_err_empty_bid_dealid_no_fallback,
  SUM(ad_err_invalid_wrapper_url) AS ad_err_invalid_wrapper_url,
  SUM(ad_err_invalid_wrapper_url_no_fallback) AS ad_err_invalid_wrapper_url_no_fallback,
  SUM(ad_err_profile_check_failed) AS ad_err_profile_check_failed,
  SUM(ad_err_profile_check_failed_no_fallback) AS ad_err_profile_check_failed_no_fallback,
  SUM(gross_ad_views) AS gross_ad_views,
  SUM(gross_ad_views_primary) AS gross_ad_views_primary,
  SUM(gross_ad_views_fallback) AS gross_ad_views_fallback,
  SUM(revenue) AS revenue,
  SUM(co_revenue) AS co_revenue,
  SUM(d_revenue) AS d_revenue,
  SUM(r_revenue) AS r_revenue,
  SUM(no_ad_views) AS no_ad_views,
  SUM(clicks) AS clicks,
  SUM(no_clicks) AS no_clicks,
  SUM(first_quartile) AS first_quartile,
  SUM(middle_quartile) AS middle_quartile,
  SUM(third_quartile) AS third_quartile,
  SUM(complete_quartile) AS complete_quartile,
  SUM(can_quartile) AS can_quartile
FROM (
  SELECT
    CAST(16 AS INTEGER) AS process_stage,
    COALESCE(nw.nw_id, -1) AS network_id,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(nw.co_id, -1) AS content_owner_id,
    IF(
      nw.supply_source = 6
      AND BITWISE_AND(COALESCE(request__extra_flags2, 0), 8) = 0
      AND nw.nw_id <> 523319,
      'no_visibility',
      'full_visibility'
    ) AS content_owner_visibility,
    IF(
      BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0
      AND COALESCE(nw.nw_role, '') = 'cro',
      -3,
      COALESCE(nw.distributor_id, -1)
    ) AS distributor_id,
    COALESCE(nw.nw_role, '') AS transaction_type,
    COALESCE(nw.reseller_id, -1) AS reseller_id,
    IF(nw.sales_channel IN (4, 6), 'no_visibility', 'full_visibility') AS reseller_visibility,
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
    COALESCE(visitor__platform_device_id, -1) AS delivered_platform_device_id,
    COALESCE(nw.user_agent_visibility, 'full_visibility') AS user_agent_visibility,
    IF(
      BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0
      AND COALESCE(nw.nw_role, '') = 'cro',
      -3,
      COALESCE(request__context__profile_id, -1)
    ) AS profile_id,
    COALESCE(request__context__profile_type, 'unknown') AS profile_type,
    CASE
      WHEN BITWISE_AND(request__flags, 32) > 0
      THEN 'no selection'
      WHEN COALESCE(request__advertisement_delivered_count, COALESCE(request__advertisement_count, 0)) = 0
      THEN 'empty'
      ELSE 'filled'
    END AS request_fill_status,
    IF(BITWISE_AND(COALESCE(request__extra_flags, 0), 1024) > 0, 'true', 'false') AS live_linear_indicator,
    IF(BITWISE_AND(COALESCE(request__extra_flags2, 0), 8) > 0, 'true', 'false') AS ssp_bidder_indicator,
    IF(
      BITWISE_AND(COALESCE(bit_flag, 0), BITWISE_SHIFT_LEFT(1, 40, 64)) > 0,
      'true',
      'false'
    ) AS partner_tag_indicator,
    ARRAY[COALESCE(slot__time_position_class, 'unknown')] AS time_position_classes,
    ARRAY[COALESCE(slot__normalized_ad_unit_id, -1)] AS slot_ad_unit_ids,
    ARRAY[COALESCE(au.name, 'na')] AS slot_ad_unit_names,
    CASE
      WHEN slot__sequence IS NULL
      THEN 'null'
      WHEN slot__sequence > 5
      THEN '5+'
      ELSE CAST(slot__sequence AS VARCHAR)
    END AS slot_sequence_normalized,
    'included' AS slot_user_drop_off,
    IF(BITWISE_AND(COALESCE(slot__flags, 0), 8) > 0, 'yes', 'no') AS slot_removed_by_ux_indicator,
    CASE
      WHEN slot__num_ads = 0
      THEN 'empty'
      WHEN slot__time_position_class = 'overlay'
      AND slot__num_ads > 0
      AND slot__num_ads = slot__max_ads
      THEN 'fully filled'
      WHEN slot__time_position_class = 'overlay'
      AND slot__num_ads > 0
      AND slot__num_ads < slot__max_ads
      THEN 'partially filled'
      WHEN slot__num_ads > 0 AND slot__unfilled_avails = 0
      THEN 'fully filled'
      WHEN slot__num_ads > 0 AND slot__unfilled_avails > 0
      THEN 'partially filled'
      ELSE 'unknown'
    END AS slot_fill_status,
    IF(
      BITWISE_AND(COALESCE(advertisement__entity_flags, 0), BITWISE_SHIFT_LEFT(1, 35, 64)) > 0,
      'yes',
      'no'
    ) AS evergreen_ad_indicator,
    IF(
      BITWISE_AND(COALESCE(advertisement__entity_flags, 0), BITWISE_SHIFT_LEFT(1, 2, 64)) > 0,
      'yes',
      'no'
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
        is_extra_item_owner = TRUE,
        COALESCE(
          candidate__unified_deal_priority__priority_tier,
          COALESCE(rule_priority_tier, 'unknown')
        ),
        'unknown'
      )
      WHEN nw.sales_channel IN (5, 6)
      THEN COALESCE(nw.order_priority_tier, 'unknown')
      ELSE 'unknown'
    END AS priority_tier,
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
        is_extra_item_owner = TRUE,
        candidate__unified_deal_priority__sub_priority_value,
        rule_priority_value
      )
      WHEN sales_channel IN (5, 6)
      THEN outbound_order_priority_value
      ELSE NULL
    END AS priority_value,
    IF(
      is_extra_item_owner = TRUE,
      advertisement__unified_priority__sub_priority_value,
      NULL
    ) AS ad_meta_priority_value,
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
              WHEN COALESCE(rule_priority, 'unknown') = 'you_first'
              THEN 'hard_guaranteed_with_pass_back'
              WHEN COALESCE(rule_priority, 'unknown') = 'me_first'
              THEN 'backfill_only'
              WHEN COALESCE(rule_priority, 'unknown') = 'hard_guaranteed'
              THEN 'hard_guaranteed_with_pass_back'
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
    COALESCE(request__traffic_type, 0) AS request_traffic_type,
    0 AS ack_traffic_type,
    COALESCE(inbound_order_id, CAST(-1 AS BIGINT)) AS inbound_order_id,
    COALESCE(outbound_order_id, CAST(-1 AS BIGINT)) AS outbound_order_id,
    COALESCE(outbound_exchange_order_id, CAST(-1 AS BIGINT)) AS outbound_exchange_order_id,
    IF(demand_dim_awareability, COALESCE(candidate__dsp_id, -1), -1) AS dsp_id,
    IF(demand_dim_awareability, COALESCE(candidate__buyer_platform_id, -1), -1) AS buyer_platform_id,
    IF(deal_awareability, COALESCE(candidate__internal_deal_id, -1), -1) AS deal_id,
    IF(deal_awareability, COALESCE(candidate__buyer_group_id, -1), -1) AS buyer_group_id,
    IF(deal_awareability, COALESCE(candidate__buyer_id, -1), -1) AS buyer_id,
    COALESCE(auction__site_domain, 'na') AS site_domain,
    IF(network_is_ad_owner, COALESCE(advertisement__ad_id, -1), -1) AS ad_id,
    IF(network_is_ad_owner, COALESCE(advertisement__placement_id, -1), -1) AS placement_id,
    COALESCE(nw.global_currency_id, -1) AS global_currency_id,
    COALESCE(request__global_currency_version, '') AS global_currency_version,
    COALESCE(advertisement__global_advertiser_ids, ARRAY[]) AS global_advertiser_ids,
    COALESCE(advertisement__global_brand_ids, ARRAY[]) AS global_brand_ids,
    COALESCE(
      TRANSFORM(
        COALESCE(advertisement__global_advertiser_ids, ARRAY[]),
        x -> COALESCE(ELEMENT_AT(adv_application_map, x), NULL)
      ),
      ARRAY[]
    ) AS global_advertiser_names,
    COALESCE(
      TRANSFORM(
        COALESCE(advertisement__global_brand_ids, ARRAY[]),
        x -> COALESCE(ELEMENT_AT(brand_application_map, x), NULL)
      ),
      ARRAY[]
    ) AS global_brand_names,
    COALESCE(advertisement__advertiser_id, -1) AS local_advertiser_id,
    COALESCE(advertisement__global_industry_ids, ARRAY[]) AS global_industry_ids,
    COALESCE(
      TRANSFORM(
        COALESCE(advertisement__global_industry_ids, ARRAY[]),
        x -> COALESCE(ELEMENT_AT(industry_map, x), NULL)
      ),
      ARRAY[]
    ) AS global_industry_names,
    process_batch_id AS process_batch_id,
    COALESCE(request__cbp__slot_template_id, -1) AS cbp_id,
    CASE WHEN sales_channel = 6 THEN outbound_listing_id ELSE ARRAY[] END AS outbound_exchange_listing_id,
    CASE WHEN advertisement__is_fallback THEN 'fallback' ELSE 'primary' END AS primary_ad_indicator,
    CASE
      WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
      AND request__context__request_format = 1
      THEN 'sspu vast'
      WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
      AND request__context__request_format = 7
      THEN 'sspu ortb'
      WHEN BITWISE_AND(request__extra_flags2, 8) > 0
      THEN 'mrm bidder'
      WHEN BITWISE_AND(request__extra_flags3, 1) > 0
      THEN 'streaminghub openrtb'
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
    SUM(
      1 * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS placed_ads,
    SUM(
      IF(advertisement__is_fallback = TRUE OR advertisement__is_sstf_fallback = TRUE, 1, 0) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS placed_fallback_ads,
    SUM(
      IF(advertisement__is_undeliverable = FALSE, 1, 0) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS filled_ads,
    SUM(
      IF(
        advertisement__is_undeliverable = FALSE
        AND (
          BITWISE_AND(COALESCE(advertisement__flags, 0), 33554432) > 0
          OR advertisement__is_fallback = FALSE
        ),
        COALESCE(advertisement__duration, 0),
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS filled_ads_duration,
    SUM(
      IF(
        advertisement__is_undeliverable = FALSE
        AND BITWISE_AND(COALESCE(advertisement__flags, 0), 33554432) > 0,
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS filled_ads_sstf_fallback,
    SUM(
      IF(advertisement__is_undeliverable = FALSE, 1, 0) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS raw_selected_primary_ads,
    SUM(
      IF(
        advertisement__is_fallback = FALSE
        AND advertisement__is_sstf_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 67108864) > 0,
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS placed_ads_sstf_failed,
    SUM(
      IF(
        advertisement__is_fallback = FALSE
        AND advertisement__is_sstf_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 67108864) > 0
        AND BITWISE_AND(advertisement__flags, 512) = 0,
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS placed_ads_sstf_failed_no_fallback,
    SUM(
      IF(
        advertisement__is_fallback = FALSE
        AND advertisement__is_sstf_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 67108864) > 0
        AND BITWISE_AND(advertisement__flags, 512) > 0,
        1,
        0
      ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS placed_ads_sstf_failed_with_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'floor_price_notmet'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_floor_price_notmet,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'floor_price_notmet'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_floor_price_notmet_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'unexpected_external_ad_id'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_unexpected_external_ad_id,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'unexpected_external_ad_id'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_unexpected_external_ad_id_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'no_valid_creative'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_no_valid_creative,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'no_valid_creative'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_no_valid_creative_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'malformed_response'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_malformed_response,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'malformed_response'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_malformed_response_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'competition_failure'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_competition_failure,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'competition_failure'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_competition_failure_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'jitt_rendition_required'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_jitt_rendition_required,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'jitt_rendition_required'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_jitt_rendition_required_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'no_slot_selected'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_no_slot_selected,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'no_slot_selected'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_no_slot_selected_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'empty_response'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_empty_response,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'empty_response'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_empty_response_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'inapplicable_for_https'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_inapplicable_for_https,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'inapplicable_for_https'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_inapplicable_for_https_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'ad_pending_approval'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_ad_pending_approval,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'ad_pending_approval'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_ad_pending_approval_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'bid_response_id_nomatch'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_bid_response_id_nomatch,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'bid_response_id_nomatch'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_bid_response_id_nomatch_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'wrapper_timeout'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_warpper_timeout,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'wrapper_timeout'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_warpper_timeout_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'compliance_not_approved'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_compliance_not_approved,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'compliance_not_approved'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_compliance_not_approved_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'http_error'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_http_error,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'http_error'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_http_error_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'no_bids'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_no_bids,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'no_bids'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_no_bids_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'external_creative_profile_check_failed'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_external_creative_profile_check_failed,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'external_creative_profile_check_failed'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_external_creative_profile_check_failed_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'auction_max_ad_duration_exceeded'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_auction_max_ad_duration_exceeded,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'auction_max_ad_duration_exceeded'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_auction_max_ad_duration_exceeded_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'wrapper_http_error'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_warpper_http_error,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'wrapper_http_error'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_warpper_http_error_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND COALESCE(candidate__error, advertisement__error) = 'timeout'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_timeout,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND COALESCE(candidate__error, advertisement__error) = 'timeout'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_timeout_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE AND advertisement__error = 'no_content'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_no_content,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND advertisement__error = 'no_content'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_no_content_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__error = 'max_wrapper_redirect'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_max_warpper_redirect,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND advertisement__error = 'max_wrapper_redirect'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_max_warpper_redirect_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__error = 'empty_bid_dealid'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_empty_bid_dealid,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND advertisement__error = 'empty_bid_dealid'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_empty_bid_dealid_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__error = 'invalid_wrapper_url'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_invalid_wrapper_url,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND advertisement__error = 'invalid_wrapper_url'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_invalid_wrapper_url_no_fallback,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__error = 'profile_check_failed'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_profile_check_failed,
    SUM(
      CASE
        WHEN advertisement__is_undeliverable = TRUE
        AND advertisement__is_fallback = FALSE
        AND BITWISE_AND(advertisement__flags, 512) = 0
        AND advertisement__error = 'profile_check_failed'
        THEN 1
        ELSE 0
      END
    ) AS ad_err_profile_check_failed_no_fallback,
    CAST(0 AS BIGINT) AS gross_ad_views,
    CAST(0 AS BIGINT) AS gross_ad_views_primary,
    CAST(0 AS BIGINT) AS gross_ad_views_fallback,
    CAST(0 AS BIGINT) AS revenue,
    CAST(0 AS BIGINT) AS co_revenue,
    CAST(0 AS BIGINT) AS d_revenue,
    CAST(0 AS BIGINT) AS r_revenue,
    CAST(0 AS BIGINT) AS no_ad_views,
    CAST(0 AS BIGINT) AS clicks,
    CAST(0 AS BIGINT) AS no_clicks,
    CAST(0 AS BIGINT) AS first_quartile,
    CAST(0 AS BIGINT) AS middle_quartile,
    CAST(0 AS BIGINT) AS third_quartile,
    CAST(0 AS BIGINT) AS complete_quartile,
    CAST(0 AS BIGINT) AS can_quartile,
    DATE_TRUNC('HOUR', request__timestamp) AS event_date
  FROM ${bcv_ad}
  CROSS JOIN UNNEST(partners__network_id, partners__site_id, partners__site_section_id, partners__distributor_network_id, partners__content_owner_network_id, partners__reseller_network_id, partners__sales_channel, partners__role, partners__supply_source, partners__geo_country_visibility__report_aggregate, partners__standard_brand_visibility__report_aggregate, partners__standard_programmer_visibility__report_aggregate, partners__standard_endpoint_visibility__report_aggregate, partners__standard_endpoint_owner_visibility__report_aggregate, partners__user_agent_visibility__report_aggregate, partners__content_form_visibility__report_aggregate, partners__global_currency_id, partners__network_is_extra_item_owner, partners__network_is_ad_owner, partners__demand_dim_awareability, partners__deal_awareability, partners__outbound_order_id, partners__outbound_exchange_order_id, partners__inbound_order_id, partners__unified_outbound_order_priority__priority_tier, partners__unified_outbound_order_priority__sub_priority_value, partners__outbound_order_priority_type, partners__unified_rule_priority__priority_tier, partners__unified_rule_priority__sub_priority_value, partners__rule_type_priority, partners__bit_flags, partners__outbound_listing_id) AS nw(nw_id, site_id, site_section_id, distributor_id, co_id, reseller_id, sales_channel, nw_role, supply_source, country_visibility, sa_brand_visibility, sa_programmer_visibility, sa_endpoint_visibility, sa_endpoint_owner_visibility, user_agent_visibility, content_form_visibility, global_currency_id, is_extra_item_owner, network_is_ad_owner, demand_dim_awareability, deal_awareability, outbound_order_id, outbound_exchange_order_id, inbound_order_id, order_priority_tier, outbound_order_priority_value, order_priority, rule_priority_tier, rule_priority_value, rule_priority, bit_flag, outbound_listing_id)
  LEFT JOIN db.default.d_network AS reseller
    ON reseller.id = COALESCE(nw.reseller_id, -1)
  LEFT JOIN db.default.d_ad_unit AS au
    ON au.id = COALESCE(slot__normalized_ad_unit_id, -1)
  JOIN global_brand_map
    ON 1 = 1
  JOIN global_adv_map
    ON 1 = 1
  JOIN global_industry_map
    ON 1 = 1
  WHERE
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
        BITWISE_AND(bit_flag, BITWISE_SHIFT_LEFT(1, 34, 64)) > 0
        AND COALESCE(nw.nw_role, '') = 'cro'
      )
    )
    AND BITWISE_AND(bit_flag, BITWISE_SHIFT_LEFT(1, 41, 64)) = 0
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
    66,
    67,
    68,
    69,
    70,
    71,
    72,
    73,
    74,
    75,
    76,
    77,
    78,
    79,
    80,
    DATE_TRUNC('HOUR', request__timestamp)
  UNION ALL
  SELECT
    CAST(32 AS INTEGER) AS process_stage,
    COALESCE(nw.nw_id, -1) AS network_id,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(nw.co_id, -1) AS content_owner_id,
    IF(
      nw.supply_source = 6
      AND BITWISE_AND(COALESCE(request__extra_flags2, 0), 8) = 0
      AND nw.nw_id <> 523319,
      'no_visibility',
      'full_visibility'
    ) AS content_owner_visibility,
    IF(
      BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0
      AND COALESCE(nw.nw_role, '') = 'cro',
      -3,
      COALESCE(nw.distributor_id, -1)
    ) AS distributor_id,
    COALESCE(nw.nw_role, '') AS transaction_type,
    COALESCE(nw.reseller_id, -1) AS reseller_id,
    IF(nw.sales_channel IN (4, 6), 'no_visibility', 'full_visibility') AS reseller_visibility,
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
    COALESCE(visitor__platform_device_id, -1) AS delivered_platform_device_id,
    COALESCE(nw.user_agent_visibility, 'full_visibility') AS user_agent_visibility,
    IF(
      BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0
      AND COALESCE(nw.nw_role, '') = 'cro',
      -3,
      COALESCE(request__context__profile_id, -1)
    ) AS profile_id,
    COALESCE(request__context__profile_type, 'unknown') AS profile_type,
    CASE
      WHEN BITWISE_AND(request__flags, 32) > 0
      THEN 'no selection'
      WHEN COALESCE(request__advertisement_delivered_count, COALESCE(request__advertisement_count, 0)) = 0
      THEN 'empty'
      ELSE 'filled'
    END AS request_fill_status,
    IF(BITWISE_AND(COALESCE(request__extra_flags, 0), 1024) > 0, 'true', 'false') AS live_linear_indicator,
    IF(BITWISE_AND(COALESCE(request__extra_flags2, 0), 8) > 0, 'true', 'false') AS ssp_bidder_indicator,
    IF(
      BITWISE_AND(COALESCE(bit_flag, 0), BITWISE_SHIFT_LEFT(1, 40, 64)) > 0,
      'true',
      'false'
    ) AS partner_tag_indicator,
    ARRAY[COALESCE(slot__time_position_class, 'unknown')] AS time_position_classes,
    ARRAY[COALESCE(slot__normalized_ad_unit_id, -1)] AS slot_ad_unit_ids,
    ARRAY[COALESCE(au.name, 'na')] AS slot_ad_unit_names,
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
      WHEN slot__num_ads = 0
      THEN 'empty'
      WHEN slot__time_position_class = 'overlay'
      AND slot__num_ads > 0
      AND slot__num_ads = slot__max_ads
      THEN 'fully filled'
      WHEN slot__time_position_class = 'overlay'
      AND slot__num_ads > 0
      AND slot__num_ads < slot__max_ads
      THEN 'partially filled'
      WHEN slot__num_ads > 0 AND slot__unfilled_avails = 0
      THEN 'fully filled'
      WHEN slot__num_ads > 0 AND slot__unfilled_avails > 0
      THEN 'partially filled'
      ELSE 'unknown'
    END AS slot_fill_status,
    IF(
      BITWISE_AND(COALESCE(advertisement__entity_flags, 0), BITWISE_SHIFT_LEFT(1, 35, 64)) > 0,
      'yes',
      'no'
    ) AS evergreen_ad_indicator,
    IF(
      BITWISE_AND(COALESCE(advertisement__entity_flags, 0), BITWISE_SHIFT_LEFT(1, 2, 64)) > 0,
      'yes',
      'no'
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
        is_extra_item_owner = TRUE,
        COALESCE(
          candidate__unified_deal_priority__priority_tier,
          COALESCE(rule_priority_tier, 'unknown')
        ),
        'unknown'
      )
      WHEN nw.sales_channel IN (5, 6)
      THEN COALESCE(nw.order_priority_tier, 'unknown')
      ELSE 'unknown'
    END AS priority_tier,
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
        is_extra_item_owner = TRUE,
        candidate__unified_deal_priority__sub_priority_value,
        rule_priority_value
      )
      WHEN sales_channel IN (5, 6)
      THEN outbound_order_priority_value
      ELSE NULL
    END AS priority_value,
    IF(
      is_extra_item_owner = TRUE,
      advertisement__unified_priority__sub_priority_value,
      NULL
    ) AS ad_meta_priority_value,
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
              WHEN COALESCE(rule_priority, 'unknown') = 'you_first'
              THEN 'hard_guaranteed_with_pass_back'
              WHEN COALESCE(rule_priority, 'unknown') = 'me_first'
              THEN 'backfill_only'
              WHEN COALESCE(rule_priority, 'unknown') = 'hard_guaranteed'
              THEN 'hard_guaranteed_with_pass_back'
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
    COALESCE(request__traffic_type, 0) AS request_traffic_type,
    COALESCE(ack__traffic_type, 0) AS ack_traffic_type,
    COALESCE(inbound_order_id, CAST(-1 AS BIGINT)) AS inbound_order_id,
    COALESCE(outbound_order_id, CAST(-1 AS BIGINT)) AS outbound_order_id,
    COALESCE(outbound_exchange_order_id, CAST(-1 AS BIGINT)) AS outbound_exchange_order_id,
    IF(demand_dim_awareability, COALESCE(candidate__dsp_id, -1), -1) AS dsp_id,
    IF(demand_dim_awareability, COALESCE(candidate__buyer_platform_id, -1), -1) AS buyer_platform_id,
    IF(deal_awareability, COALESCE(candidate__internal_deal_id, -1), -1) AS deal_id,
    IF(deal_awareability, COALESCE(candidate__buyer_group_id, -1), -1) AS buyer_group_id,
    IF(deal_awareability, COALESCE(candidate__buyer_id, -1), -1) AS buyer_id,
    COALESCE(auction__site_domain, 'na') AS site_domain,
    IF(network_is_ad_owner, COALESCE(advertisement__ad_id, -1), -1) AS ad_id,
    IF(network_is_ad_owner, COALESCE(advertisement__placement_id, -1), -1) AS placement_id,
    COALESCE(nw.global_currency_id, -1) AS global_currency_id,
    COALESCE(request__global_currency_version, '') AS global_currency_version,
    COALESCE(advertisement__global_advertiser_ids, ARRAY[]) AS global_advertiser_ids,
    COALESCE(advertisement__global_brand_ids, ARRAY[]) AS global_brand_ids,
    COALESCE(
      TRANSFORM(
        COALESCE(advertisement__global_advertiser_ids, ARRAY[]),
        x -> COALESCE(ELEMENT_AT(adv_application_map, x), NULL)
      ),
      ARRAY[]
    ) AS global_advertiser_names,
    COALESCE(
      TRANSFORM(
        COALESCE(advertisement__global_brand_ids, ARRAY[]),
        x -> COALESCE(ELEMENT_AT(brand_application_map, x), NULL)
      ),
      ARRAY[]
    ) AS global_brand_names,
    COALESCE(advertisement__advertiser_id, -1) AS local_advertiser_id,
    COALESCE(advertisement__global_industry_ids, ARRAY[]) AS global_industry_ids,
    COALESCE(
      TRANSFORM(
        COALESCE(advertisement__global_industry_ids, ARRAY[]),
        x -> COALESCE(ELEMENT_AT(industry_map, x), NULL)
      ),
      ARRAY[]
    ) AS global_industry_names,
    process_batch_id AS process_batch_id,
    COALESCE(request__cbp__slot_template_id, -1) AS cbp_id,
    CASE WHEN sales_channel = 6 THEN outbound_listing_id ELSE ARRAY[] END AS outbound_exchange_listing_id,
    CASE WHEN advertisement__is_fallback THEN 'fallback' ELSE 'primary' END AS primary_ad_indicator,
    CASE
      WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
      AND request__context__request_format = 1
      THEN 'sspu vast'
      WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
      AND request__context__request_format = 7
      THEN 'sspu ortb'
      WHEN BITWISE_AND(request__extra_flags2, 8) > 0
      THEN 'mrm bidder'
      WHEN BITWISE_AND(request__extra_flags3, 1) > 0
      THEN 'streaminghub openrtb'
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
    CAST(0 AS BIGINT) AS placed_ads,
    CAST(0 AS BIGINT) AS placed_fallback_ads,
    CAST(0 AS BIGINT) AS filled_ads,
    CAST(0 AS BIGINT) AS filled_ads_duration,
    CAST(0 AS BIGINT) AS filled_ads_sstf_fallback,
    CAST(0 AS BIGINT) AS raw_selected_primary_ads,
    CAST(0 AS BIGINT) AS placed_ads_sstf_failed,
    CAST(0 AS BIGINT) AS placed_ads_sstf_failed_no_fallback,
    CAST(0 AS BIGINT) AS placed_ads_sstf_failed_with_fallback,
    CAST(0 AS BIGINT) AS ad_err_floor_price_notmet,
    CAST(0 AS BIGINT) AS ad_err_floor_price_notmet_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_unexpected_external_ad_id,
    CAST(0 AS BIGINT) AS ad_err_unexpected_external_ad_id_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_no_valid_creative,
    CAST(0 AS BIGINT) AS ad_err_no_valid_creative_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_malformed_response,
    CAST(0 AS BIGINT) AS ad_err_malformed_response_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_competition_failure,
    CAST(0 AS BIGINT) AS ad_err_competition_failure_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_jitt_rendition_required,
    CAST(0 AS BIGINT) AS ad_err_jitt_rendition_required_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_no_slot_selected,
    CAST(0 AS BIGINT) AS ad_err_no_slot_selected_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_empty_response,
    CAST(0 AS BIGINT) AS ad_err_empty_response_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_inapplicable_for_https,
    CAST(0 AS BIGINT) AS ad_err_inapplicable_for_https_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_ad_pending_approval,
    CAST(0 AS BIGINT) AS ad_err_ad_pending_approval_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_bid_response_id_nomatch,
    CAST(0 AS BIGINT) AS ad_err_bid_response_id_nomatch_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_warpper_timeout,
    CAST(0 AS BIGINT) AS ad_err_warpper_timeout_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_compliance_not_approved,
    CAST(0 AS BIGINT) AS ad_err_compliance_not_approved_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_http_error,
    CAST(0 AS BIGINT) AS ad_err_http_error_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_no_bids,
    CAST(0 AS BIGINT) AS ad_err_no_bids_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_external_creative_profile_check_failed,
    CAST(0 AS BIGINT) AS ad_err_external_creative_profile_check_failed_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_auction_max_ad_duration_exceeded,
    CAST(0 AS BIGINT) AS ad_err_auction_max_ad_duration_exceeded_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_warpper_http_error,
    CAST(0 AS BIGINT) AS ad_err_warpper_http_error_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_timeout,
    CAST(0 AS BIGINT) AS ad_err_timeout_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_no_content,
    CAST(0 AS BIGINT) AS ad_err_no_content_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_max_warpper_redirect,
    CAST(0 AS BIGINT) AS ad_err_max_warpper_redirect_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_empty_bid_dealid,
    CAST(0 AS BIGINT) AS ad_err_empty_bid_dealid_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_invalid_wrapper_url,
    CAST(0 AS BIGINT) AS ad_err_invalid_wrapper_url_no_fallback,
    CAST(0 AS BIGINT) AS ad_err_profile_check_failed,
    CAST(0 AS BIGINT) AS ad_err_profile_check_failed_no_fallback,
    SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS gross_ad_views,
    SUM(
      IF(advertisement__is_fallback = FALSE, COALESCE(ack__metrics__raw_ad_impression, 0), 0)
    ) AS gross_ad_views_primary,
    SUM(
      IF(advertisement__is_fallback = TRUE, COALESCE(ack__metrics__raw_ad_impression, 0), 0)
    ) AS gross_ad_views_fallback,
    SUM(
      COALESCE(revenue, CAST(0 AS DOUBLE)) * COALESCE(ack__metrics__fire_event_revenue_ratio, CAST(0 AS BIGINT))
    ) AS revenue,
    SUM(
      COALESCE(content_owner_revenue, CAST(0 AS DOUBLE)) * COALESCE(ack__metrics__fire_event_revenue_ratio, CAST(0 AS BIGINT))
    ) AS co_revenue,
    SUM(
      COALESCE(distributor_revenue, CAST(0 AS DOUBLE)) * COALESCE(ack__metrics__fire_event_revenue_ratio, CAST(0 AS BIGINT))
    ) AS d_revenue,
    SUM(
      COALESCE(reseller_revenue, CAST(0 AS DOUBLE)) * COALESCE(ack__metrics__fire_event_revenue_ratio, CAST(0 AS BIGINT))
    ) AS r_revenue,
    SUM(
      IF(
        nw.network_is_ad_owner,
        COALESCE(ack__metrics__no_ad_impression, CAST(0 AS BIGINT)),
        CAST(0 AS BIGINT)
      )
    ) AS no_ad_views,
    SUM(COALESCE(ack__metrics__click, CAST(0 AS BIGINT))) AS clicks,
    SUM(COALESCE(ack__metrics__no_click, CAST(0 AS BIGINT))) AS no_clicks,
    SUM(COALESCE(ack__metrics__first_quartile, CAST(0 AS BIGINT))) AS first_quartile,
    SUM(COALESCE(ack__metrics__middle_quartile, CAST(0 AS BIGINT))) AS middle_quartile,
    SUM(COALESCE(ack__metrics__third_quartile, CAST(0 AS BIGINT))) AS third_quartile,
    SUM(COALESCE(ack__metrics__complete_quartile, CAST(0 AS BIGINT))) AS complete_quartile,
    SUM(COALESCE(ack__metrics__can_quartile, CAST(0 AS BIGINT))) AS can_quartile,
    DATE_TRUNC('HOUR', ack__timestamp) AS event_date
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(partners__network_id, partners__site_id, partners__site_section_id, partners__distributor_network_id, partners__content_owner_network_id, partners__reseller_network_id, partners__sales_channel, partners__role, partners__supply_source, partners__geo_country_visibility__report_aggregate, partners__standard_brand_visibility__report_aggregate, partners__standard_programmer_visibility__report_aggregate, partners__standard_endpoint_visibility__report_aggregate, partners__standard_endpoint_owner_visibility__report_aggregate, partners__user_agent_visibility__report_aggregate, partners__content_form_visibility__report_aggregate, partners__global_currency_id, partners__network_is_extra_item_owner, partners__demand_dim_awareability, partners__deal_awareability, partners__outbound_order_id, partners__outbound_exchange_order_id, partners__inbound_order_id, partners__unified_outbound_order_priority__priority_tier, partners__unified_outbound_order_priority__sub_priority_value, partners__outbound_order_priority_type, partners__unified_rule_priority__priority_tier, partners__unified_rule_priority__sub_priority_value, partners__rule_type_priority, partners__network_is_ad_owner, partners__revenue, partners__content_owner_revenue, partners__reseller_revenue, partners__distributor_revenue, partners__bit_flags, partners__outbound_listing_id) AS nw(nw_id, site_id, site_section_id, distributor_id, co_id, reseller_id, sales_channel, nw_role, supply_source, country_visibility, sa_brand_visibility, sa_programmer_visibility, sa_endpoint_visibility, sa_endpoint_owner_visibility, user_agent_visibility, content_form_visibility, global_currency_id, is_extra_item_owner, demand_dim_awareability, deal_awareability, outbound_order_id, outbound_exchange_order_id, inbound_order_id, order_priority_tier, outbound_order_priority_value, order_priority, rule_priority_tier, rule_priority_value, rule_priority, network_is_ad_owner, revenue, content_owner_revenue, reseller_revenue, distributor_revenue, bit_flag, outbound_listing_id)
  LEFT JOIN db.default.d_network AS reseller
    ON reseller.id = COALESCE(nw.reseller_id, -1)
  LEFT JOIN db.default.d_ad_unit AS au
    ON au.id = COALESCE(slot__normalized_ad_unit_id, -1)
  JOIN global_brand_map
    ON 1 = 1
  JOIN global_adv_map
    ON 1 = 1
  JOIN global_industry_map
    ON 1 = 1
  WHERE
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
            BITWISE_AND(bit_flag, BITWISE_SHIFT_LEFT(1, 34, 64)) > 0
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
    66,
    67,
    68,
    69,
    70,
    71,
    72,
    73,
    74,
    75,
    76,
    76,
    77,
    78,
    79,
    80,
    DATE_TRUNC('HOUR', ack__timestamp)
) AS t
LEFT JOIN db.default.d_network AS reseller
  ON reseller.id = COALESCE(reseller_id, -1)
LEFT JOIN db.default.d_network AS dis
  ON dis.id = distributor_id
LEFT JOIN db.default.d_network AS network
  ON network.id = t.network_id
LEFT JOIN db.default.d_network AS vcro
  ON vcro.id = t.video_cro_network_id
LEFT JOIN db.default.d_network AS co
  ON co.id = content_owner_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = profile_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS ep
  ON ep.id = COALESCE(standard_endpoint_id, -1)
LEFT JOIN db.default.d_lu_mkpl_endpoint_owner AS eo
  ON eo.id = COALESCE(standard_endpoint_owner_id, -1)
LEFT JOIN db.default.d_ssp_demand_side_platform AS ssp
  ON ssp.network_id = reseller_id
LEFT JOIN db.default.d_lu_mkpl_standard_programmer AS pg
  ON pg.id = COALESCE(standard_programmer_id, -1)
LEFT JOIN db.default.d_lu_mkpl_standard_publisher AS publisher
  ON publisher.id = COALESCE(standard_publisher_id, -1)
LEFT JOIN db.default.d_lu_mkpl_standard_app AS app
  ON app.id = COALESCE(standard_app_id, -1)
LEFT JOIN db.default.d_lu_mkpl_standard_brand AS brand
  ON brand.id = COALESCE(standard_brand_id, -1)
LEFT JOIN db.default.d_advertiser AS adv
  ON adv.id = COALESCE(local_advertiser_id, -1)
LEFT JOIN (
  SELECT
    site_id,
    site_name
  FROM db.default.d_site_section
  GROUP BY
    1,
    2
) AS s
  ON s.site_id = COALESCE(t.site_id, -1)
LEFT JOIN (
  SELECT
    id,
    name
  FROM db.default.d_site_section
  GROUP BY
    1,
    2
) AS ss
  ON ss.id = COALESCE(site_section_id, -1)
LEFT JOIN db.default.d_lu_mkpl_standard_content_form AS cf
  ON cf.id = content_form_id
LEFT JOIN db.default.d_lu_mkpl_stream_mode AS sm
  ON sm.id = stream_mode_id
LEFT JOIN db.default.d_country AS country
  ON country.id = user_country_id
LEFT JOIN db.default.d_lu_mkpl_standard_device_type AS device
  ON device.id = standard_device_type_id
LEFT JOIN db.default.d_lu_mkpl_standard_environment AS env
  ON env.id = standard_environment_id
LEFT JOIN db.default.d_lu_mkpl_standard_os AS os
  ON os.id = standard_os_id
LEFT JOIN (
  SELECT DISTINCT
    id,
    display_name
  FROM db.default.d_lu_user_agent_platform
  WHERE
    type = 'device'
) AS platform_device
  ON platform_device.id = delivered_platform_device_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = dsp_id
LEFT JOIN db.default.d_ssp_buyer_platform AS bp
  ON bp.id = buyer_platform_id
LEFT JOIN db.default.d_ssp_buyer_group AS bg
  ON bg.id = buyer_group_id
LEFT JOIN (
  SELECT
    id,
    name,
    order_type,
    internal_module
  FROM db.default.d_mkpl_order
) AS in_order
  ON in_order.id = inbound_order_id
LEFT JOIN (
  SELECT
    id,
    name,
    order_type,
    internal_module
  FROM db.default.d_mkpl_order
) AS out_order
  ON out_order.id = outbound_order_id
LEFT JOIN db.default.d_ssp_deal_metadata AS d_ssp_deal_metadata
  ON d_ssp_deal_metadata.id = deal_id
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
  59,
  60,
  61,
  62,
  63,
  64,
  65,
  66,
  67,
  68,
  69,
  70,
  71,
  72,
  73,
  74,
  75,
  76,
  77,
  78,
  79,
  80,
  81,
  82,
  83,
  84,
  85,
  86,
  87,
  88,
  89,
  90,
  91,
  92,
  93,
  94,
  95
