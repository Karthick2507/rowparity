-- account:    sa-dataapp-yield
-- skeleton:   e206f3ae33839c83b57f8000c922026c
-- pattern:    3dad7a89f3409928a29d0c8c15ab2632  (696 execution(s))
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
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(request__context__standard_programmer_id, -1) AS programmer_id,
  COALESCE(programmer.name, 'na') AS programmer_name,
  COALESCE(request__context__standard_brand_id, -1) AS brand_id,
  COALESCE(brand.name, 'na') AS brand_name,
  COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
  COALESCE(endpoint.name, 'na') AS endpoint_name,
  COALESCE(request__context__standard_endpoint_owner_id, -1) AS endpoint_owner_id,
  COALESCE(endpoint_owner.name, 'na') AS endpoint_owner_name,
  COALESCE(visitor__standard_environment_id, -1) AS environment_id,
  COALESCE(env.name, 'na') AS environment_name,
  COALESCE(visitor__standard_os_id, -1) AS os_id,
  COALESCE(os.name, 'na') AS os_name,
  COALESCE(visitor__standard_device_type_child_id, -1) AS device_type_child_id,
  COALESCE(device_type.name, 'na') AS device_type_child_name,
  nw_id AS managed_exchange_network_id,
  COALESCE(buyer_nw.name, 'na') AS managed_exchange_network_name,
  COALESCE(co_id, -1) AS seller_network_id,
  COALESCE(seller_nw.name, 'na') AS seller_network_name,
  IF(CARDINALITY(inbound_listing_ids) > 0, ELEMENT_AT(inbound_listing_ids, 1), -1) AS listing_id,
  COALESCE(listing.name, 'na') AS listing_name,
  COALESCE(candidate__dsp_id, -1) AS dsp_id,
  COALESCE(dsp.name, 'na') AS dsp_name,
  COALESCE(candidate__advertiser_id, -1) AS advertiser_id,
  COALESCE(adv.name, 'na') AS advertiser_name,
  -1 AS deal_id,
  -1 AS buyer_group_id,
  'na' AS deal_type,
  'na' AS public_deal_id,
  'na' AS buyer_group_name,
  COALESCE(request__server_pool, 'na') AS server_pool,
  SUM(IF(slot_error = 'exceed_max_num_advertisements', 1, 0)) AS competition_failure_exceed_max_num_advertisements,
  SUM(IF(slot_error = 'back2back_excluded', 1, 0)) AS competition_failure_back2back_excluded,
  SUM(IF(slot_error = 'exceed_max_slot_duration', 1, 0)) AS competition_failure_exceed_max_slot_duration,
  SUM(IF(slot_error = 'brand_separation_excluded', 1, 0)) AS competition_failure_brand_separation_excluded,
  SUM(IF(slot_error = 'frequency_cap_reaching', 1, 0)) AS competition_failure_frequency_cap_reaching,
  SUM(IF(slot_error = 'exclusivity_by_slot', 1, 0)) AS competition_failure_exclusivity_by_slot,
  SUM(IF(slot_error = 'industry_separation_excluded', 1, 0)) AS competition_failure_industry_separation_excluded,
  SUM(IF(slot_error = 'advertiser_separation_excluded', 1, 0)) AS competition_failure_advertiser_separation_excluded,
  SUM(IF(slot_error = 'adjacent_exclusivity', 1, 0)) AS competition_failure_adjacent_exclusivity,
  SUM(IF(slot_error = 'slot_filled_by_multi_ads', 1, 0)) AS competition_failure_slot_filled_by_multi_ads,
  SUM(IF(slot_error = 'restricted_by_openrtb_impression_bid_capping', 1, 0)) AS competition_failure_restricted_by_openrtb_imp_bid_cap,
  SUM(IF(slot_error = 'clearcast_no_applicable_position_in_slot', 1, 0)) AS competition_failure_clearcast_no_applicable_position_in_slot,
  SUM(IF(slot_error = 'position_occupied', 1, 0)) AS competition_failure_position_occupied,
  SUM(IF(slot_error = 'brand_frequency_cap_reaching', 1, 0)) AS competition_failure_brand_frequency_cap_reaching,
  SUM(
    IF(
      slot_error_category = 'competition_failure'
      AND NOT slot_error IN (
        'exceed_max_num_advertisements',
        'back2back_excluded',
        'exceed_max_slot_duration',
        'brand_separation_excluded',
        'frequency_cap_reaching',
        'exclusivity_by_slot',
        'industry_separation_excluded',
        'advertiser_separation_excluded',
        'adjacent_exclusivity',
        'slot_filled_by_multi_ads',
        'restricted_by_openrtb_impression_bid_capping',
        'clearcast_no_applicable_position_in_slot',
        'position_occupied',
        'brand_frequency_cap_reaching'
      ),
      1,
      0
    )
  ) AS competition_failure_others,
  SUM(IF(slot_error_category = 'competition_failure', 1, 0)) AS competition_failure_total,
  SUM(IF(slot_error = 'large_rendition_duration', 1, 0)) AS profile_check_failed_large_rendition_duration,
  SUM(IF(slot_error = 'estimate_rendition_duration_for_live', 1, 0)) AS profile_check_failed_estimate_rendition_duration_for_live,
  SUM(IF(slot_error = 'no_applicable_profiles_for_rendition', 1, 0)) AS profile_check_failed_no_applicable_profiles_for_rendition,
  SUM(IF(slot_error = 'creative_api_banned', 1, 0)) AS profile_check_failed_creative_api_banned,
  SUM(IF(slot_error = 'ad_asset_store_not_available', 1, 0)) AS profile_check_failed_ad_asset_store_not_available,
  SUM(IF(slot_error = 'incompatible_rendition_dimension', 1, 0)) AS profile_check_failed_incompatible_rendition_dimension,
  SUM(IF(slot_error = 'incompatible_rendition_file_size', 1, 0)) AS profile_check_failed_incompatible_rendition_file_size,
  SUM(IF(slot_error = 'incompatible_flash_version', 1, 0)) AS profile_check_failed_incompatible_flash_version,
  SUM(IF(slot_error = 'ad_asset_store_inapplicable_bitrate', 1, 0)) AS profile_check_failed_ad_asset_store_inapplicable_bitrate,
  SUM(
    IF(
      slot_error_category IN ('profile_check_failed', 'external_creative_profile_check_failed')
      AND NOT slot_error IN (
        'large_rendition_duration',
        'estimate_rendition_duration_for_live',
        'no_applicable_profiles_for_rendition',
        'creative_api_banned',
        'ad_asset_store_not_available',
        'incompatible_rendition_dimension',
        'incompatible_rendition_file_size',
        'incompatible_flash_version',
        'ad_asset_store_inapplicable_bitrate'
      ),
      1,
      0
    )
  ) AS profile_check_failed_others,
  SUM(
    IF(
      slot_error_category IN ('profile_check_failed', 'external_creative_profile_check_failed'),
      1,
      0
    )
  ) AS profile_check_failed_total
FROM ${bcv_candidate}
CROSS JOIN UNNEST(partners__network_id, partners__content_owner_network_id, partners__supply_source, partners__inbound_listing_id) AS t(nw_id, co_id, supply_source, inbound_listing_ids)
CROSS JOIN UNNEST(candidate__filter_reason__error, candidate__filter_reason__error_category) AS err(slot_error, slot_error_category)
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_lu_mkpl_standard_programmer AS programmer
  ON programmer.id = request__context__standard_programmer_id
LEFT JOIN db.default.d_lu_mkpl_standard_brand AS brand
  ON brand.id = request__context__standard_brand_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS endpoint
  ON endpoint.id = request__context__standard_endpoint_id
LEFT JOIN db.default.d_lu_mkpl_endpoint_owner AS endpoint_owner
  ON endpoint_owner.id = request__context__standard_endpoint_owner_id
LEFT JOIN db.default.d_lu_mkpl_standard_environment AS env
  ON env.id = visitor__standard_environment_id
LEFT JOIN db.default.d_lu_mkpl_standard_os AS os
  ON os.id = visitor__standard_os_id
LEFT JOIN db.default.d_lu_mkpl_standard_device_type AS device_type
  ON device_type.id = visitor__standard_device_type_child_id
LEFT JOIN db.default.d_network AS buyer_nw
  ON buyer_nw.id = nw_id
LEFT JOIN db.default.d_network AS seller_nw
  ON seller_nw.id = co_id
LEFT JOIN db.default.d_mkpl_listing AS listing
  ON listing.id = IF(CARDINALITY(inbound_listing_ids) > 0, ELEMENT_AT(inbound_listing_ids, 1), -1)
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = candidate__dsp_id
LEFT JOIN db.default.d_global_brand_advertiser AS adv
  ON adv.id = candidate__advertiser_id
WHERE
  t.supply_source = 6
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
  37
