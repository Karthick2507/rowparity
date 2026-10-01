-- account:    sa-dataapp-yield
-- skeleton:   06c60c9b78213f42ec7602ff02dcdd83
-- pattern:    ffb603c9ffcb7e0a7e15bede9b13d6f4  (1 execution(s))
-- in suite:   column coverage
-- hoover:     auction, candidate, slot
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   dt < DATE_FORMAT(CAST(? AS TIMESTAMP) + INTERVAL ? HOUR, ?)
--   dt >= DATE_FORMAT(CAST(? AS TIMESTAMP) - INTERVAL ? HOUR, ?)
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  COALESCE(request.video_cro_network_id, CAST(-1 AS BIGINT)) AS video_cro_network_id,
  COALESCE(request.distributor_network_id, CAST(-1 AS BIGINT)) AS distributor_network_id,
  COALESCE(request.profile_id, CAST(-1 AS BIGINT)) AS profile_id,
  COALESCE(request.standard_endpoint_id, CAST(-1 AS BIGINT)) AS standard_endpoint_id,
  COALESCE(request.standard_endpoint_owner_id, CAST(-1 AS BIGINT)) AS standard_endpoint_owner_id,
  COALESCE(request.standard_brand_id, CAST(-1 AS BIGINT)) AS standard_brand_id,
  COALESCE(request.standard_programmer_id, CAST(-1 AS BIGINT)) AS standard_programmer_id,
  COALESCE(request.content_form_id, CAST(-1 AS BIGINT)) AS content_form_id,
  COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), CAST(-1 AS BIGINT)) AS stream_mode_id,
  COALESCE(request.standard_publisher_id, CAST(-1 AS BIGINT)) AS standard_publisher_id,
  COALESCE(request.country_id, CAST(-1 AS BIGINT)) AS country_id,
  COALESCE(request.slot_template_id, CAST(-1 AS BIGINT)) AS cbp_id,
  CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 'true' ELSE 'false' END AS request_is_filtered,
  COALESCE(request.video_cro_site_section_id, CAST(-1 AS BIGINT)) AS site_section_id,
  COALESCE(request.series_id, CAST(-1 AS BIGINT)) AS video_series_id,
  COALESCE(network.network_id, CAST(-1 AS BIGINT)) AS network_id,
  COALESCE(network.inbound_order.order_id, network.inbound_order_id, CAST(-1 AS BIGINT)) AS inbound_order_id,
  COALESCE(network.inbound_order.order_type, 'na') AS inbound_order_type,
  COALESCE(network.inbound_order.order_priority, 'na') AS inbound_order_priority,
  COALESCE(network.inbound_order.unified_priority.priority_tier, 'na') AS inbound_order_priority_tier,
  COALESCE(network.inbound_order.unified_priority.sub_priority_value, -1) AS inbound_order_priority_value,
  CASE
    WHEN in_order.order_type = 'carriage_order'
    THEN 'inventory split'
    WHEN COALESCE(network.supply_source_type, 'na') = 'owned_and_operated'
    THEN 'o&o'
    WHEN COALESCE(network.supply_source_type, 'na') = 'mpp'
    AND in_order.transaction_type = 'guaranteed'
    THEN 'mpp guaranteed'
    WHEN COALESCE(network.supply_source_type, 'na') = 'mpp'
    AND in_order.transaction_type = 'non_guaranteed'
    THEN 'mpp non-guaranteed'
    ELSE COALESCE(network.supply_source_type, 'na')
  END AS supply_source_detail,
  COALESCE(upstream_network.network_id, CAST(-1 AS BIGINT)) AS upstream_network_id,
  COALESCE(
    upstream_network.inbound_order.order_id,
    upstream_network.inbound_order_id,
    CAST(-1 AS BIGINT)
  ) AS upstream_network_inbound_order_id,
  COALESCE(upstream_network.inbound_order.order_type, 'na') AS upstream_network_inbound_order_type,
  COALESCE(upstream_network.inbound_order.order_priority, 'na') AS upstream_network_inbound_order_priority,
  COALESCE(upstream_network.inbound_order.unified_priority.priority_tier, 'na') AS upstream_network_inbound_order_priority_tier,
  COALESCE(upstream_network.inbound_order.unified_priority.sub_priority_value, -1) AS upstream_network_inbound_order_priority_value,
  COALESCE(upstream_network.supply_source_type, 'na') AS upstream_network_supply_source_type,
  COALESCE(t.external_network_id, CAST(-1 AS BIGINT)) AS external_network_id,
  CAST(-1 AS BIGINT) AS slot_ad_unit_id,
  -1 AS slot_sequence,
  'na' AS time_position_class,
  'na' AS slot_placed_status,
  'na' AS slot_fill_status,
  'direct sold' AS sales_channel,
  'ad_unit' AS node_type,
  COALESCE(t.placement_id, CAST(-1 AS BIGINT)) AS placement_id,
  COALESCE(ad.ad_id, CAST(-1 AS BIGINT)) AS ad_id,
  COALESCE(ad.advertiser_id, CAST(-1 AS BIGINT)) AS local_advertiser_id,
  COALESCE(ARRAY_DISTINCT(ARRAY_SORT(ad.global_advertiser_ids)), ARRAY[]) AS global_advertiser_ids,
  COALESCE(ARRAY_DISTINCT(ARRAY_SORT(ad.global_brand_ids)), ARRAY[]) AS global_brand_ids,
  COALESCE(ARRAY_DISTINCT(ARRAY_SORT(ad.global_industry_ids)), ARRAY[]) AS global_industry_ids,
  COALESCE(ad.ad_priority_type, 'na') AS ad_priority_type,
  COALESCE(ad.effective_unified_priority.priority_tier, 'na') AS ad_priority_tier,
  COALESCE(ad.effective_unified_priority.sub_priority_value, CAST(-1 AS BIGINT)) AS ad_priority_value,
  COALESCE(ad.error, 0) AS error_code,
  COALESCE(err.display_name, 'na') AS error_display_name,
  CAST(-1 AS BIGINT) AS outbound_order_id,
  CAST(-1 AS BIGINT) AS buyer_network_id,
  'na' AS outbound_order_type,
  'na' AS outbound_order_priority,
  'na' AS outbound_order_priority_tier,
  CAST(-1 AS BIGINT) AS outbound_order_priority_value,
  CAST(-1 AS BIGINT) AS internal_deal_id,
  -1 AS buyer_group_id,
  'placement' AS demand_type,
  COALESCE(t.placement_id, CAST(-1 AS BIGINT)) AS demand_id,
  COALESCE(plc.priority_type, 'na') AS demand_priority_type,
  COALESCE(plc.priority_value, CAST(-1 AS BIGINT)) AS demand_priority_value,
  COALESCE(
    ELEMENT_AT(request.standard_device_type_ids, CAST(-1 AS BIGINT)),
    CAST(-1 AS BIGINT)
  ) AS standard_device_type_id,
  CAST(DATE_TRUNC('HOUR', FROM_UNIXTIME(timestamp)) AS TIMESTAMP) AS timestamp,
  SUM(COALESCE(magnifier, 1)) AS ad_error_frequency,
  SUM(
    IF(BITWISE_AND(COALESCE(ad.selection_status, 0), 1) > 0, COALESCE(magnifier, 1), 0)
  ) AS targeted_ads,
  SUM(
    IF(BITWISE_AND(COALESCE(ad.selection_status, 0), 2) > 0, COALESCE(magnifier, 1), 0)
  ) AS flattened_ads,
  SUM(
    IF(BITWISE_AND(COALESCE(ad.selection_status, 0), 4) > 0, COALESCE(magnifier, 1), 0)
  ) AS available_ads,
  SUM(
    IF(BITWISE_AND(COALESCE(ad.selection_status, 0), 8) > 0, COALESCE(magnifier, 1), 0)
  ) AS eligible_ads,
  SUM(
    IF(BITWISE_AND(COALESCE(ad.selection_status, 0), 16) > 0, COALESCE(magnifier, 1), 0)
  ) AS distinct_selected_ads,
  SUM(
    IF(BITWISE_AND(COALESCE(ad.selection_status, 0), 32) > 0, COALESCE(magnifier, 1), 0)
  ) AS distinct_filled_ads,
  0 AS plc_error_frequency,
  0 AS targeted_plcs,
  0 AS flattened_plcs,
  0 AS ad_in_slot_error_frequency,
  0 AS eligible_ads_in_slot,
  0 AS ad_filled_ads,
  0 AS ad_raw_selected_ad,
  0 AS ad_raw_selected_ad_primary,
  0 AS ad_raw_selected_ad_primary_sstf_failed,
  0 AS ad_sstf_failed_has_fallback,
  0 AS ad_sstf_failed_no_fallback,
  0 AS order_error_frequency,
  0 AS targeted_orders,
  0 AS candidated_orders,
  0 AS executed_orders,
  SUM(COALESCE(network.order_opportunity, 0) * COALESCE(magnifier, 1)) AS inbound_order_opportunity,
  0 AS ad_selected_ad_primary,
  0 AS ad_selected_ad_fallback,
  SUM(COALESCE(upstream_network.order_opportunity, 0) * COALESCE(magnifier, 1)) AS upstream_network_order_opportunity,
  0 AS outbound_order_opportunity,
  0 AS ad_selected_ad,
  0 AS slot_opportunity,
  0 AS distinct_inventory_avails,
  0 AS deal_opportunity,
  0 AS demand_opportunity,
  SUM(
    IF(BITWISE_AND(COALESCE(ad.selection_status, 0), 1) > 0, COALESCE(magnifier, 1), 0)
  ) AS tx_candidates,
  SUM(
    IF(BITWISE_AND(COALESCE(ad.selection_status, 0), 8) > 0, COALESCE(magnifier, 1), 0)
  ) AS tx_eligibles,
  0 AS slot_eligibles,
  0 AS slot_placed_ads,
  0 AS selected_ads_sampled,
  0 AS impression,
  SUM(
    CASE
      WHEN BITWISE_AND(COALESCE(ad.selection_status, 0), 1) > 0
      AND BITWISE_AND(COALESCE(ad.selection_status, 0), 8) = 0
      THEN COALESCE(magnifier, 1)
      ELSE 0
    END
  ) AS tx_error_frequency,
  0 AS slot_error_frequency,
  0 AS sstf_err_frequency
FROM db.troubleshooting_log."fw_ads_demand_troubleshooting_log"
CROSS JOIN UNNEST(ad_selection_info) AS t
CROSS JOIN UNNEST(t.ad_infos) AS ad
LEFT JOIN db.default.d_mkpl_order AS in_order
  ON COALESCE(network.inbound_order.order_id, network.inbound_order_id, CAST(-1 AS BIGINT)) = in_order.id
LEFT JOIN oltp.fwmrm_oltp.lu_mkpl_selection_error AS err
  ON COALESCE(ad.error, 0) = err.id
LEFT JOIN db.default.d_placement AS plc
  ON plc.id = COALESCE(t.placement_id, CAST(-1 AS BIGINT))
WHERE
  FROM_UNIXTIME(timestamp) >= CAST('2026-08-01 12:00:00' AS TIMESTAMP)
  AND FROM_UNIXTIME(timestamp) < CAST('2026-08-01 13:00:00' AS TIMESTAMP)
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
  62
UNION ALL
SELECT
  COALESCE(request.video_cro_network_id, CAST(-1 AS BIGINT)) AS video_cro_network_id,
  COALESCE(request.distributor_network_id, CAST(-1 AS BIGINT)) AS distributor_network_id,
  COALESCE(request.profile_id, CAST(-1 AS BIGINT)) AS profile_id,
  COALESCE(request.standard_endpoint_id, CAST(-1 AS BIGINT)) AS standard_endpoint_id,
  COALESCE(request.standard_endpoint_owner_id, CAST(-1 AS BIGINT)) AS standard_endpoint_owner_id,
  COALESCE(request.standard_brand_id, CAST(-1 AS BIGINT)) AS standard_brand_id,
  COALESCE(request.standard_programmer_id, CAST(-1 AS BIGINT)) AS standard_programmer_id,
  COALESCE(request.content_form_id, CAST(-1 AS BIGINT)) AS content_form_id,
  COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), CAST(-1 AS BIGINT)) AS stream_mode_id,
  COALESCE(request.standard_publisher_id, CAST(-1 AS BIGINT)) AS standard_publisher_id,
  COALESCE(request.country_id, CAST(-1 AS BIGINT)) AS country_id,
  COALESCE(request.slot_template_id, CAST(-1 AS BIGINT)) AS cbp_id,
  CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 'true' ELSE 'false' END AS request_is_filtered,
  COALESCE(request.video_cro_site_section_id, CAST(-1 AS BIGINT)) AS site_section_id,
  COALESCE(request.series_id, CAST(-1 AS BIGINT)) AS video_series_id,
  COALESCE(network.network_id, CAST(-1 AS BIGINT)) AS network_id,
  COALESCE(network.inbound_order.order_id, network.inbound_order_id, CAST(-1 AS BIGINT)) AS inbound_order_id,
  COALESCE(network.inbound_order.order_type, 'na') AS inbound_order_type,
  COALESCE(network.inbound_order.order_priority, 'na') AS inbound_order_priority,
  COALESCE(network.inbound_order.unified_priority.priority_tier, 'na') AS inbound_order_priority_tier,
  COALESCE(network.inbound_order.unified_priority.sub_priority_value, -1) AS inbound_order_priority_value,
  CASE
    WHEN in_order.order_type = 'carriage_order'
    THEN 'inventory split'
    WHEN COALESCE(network.supply_source_type, 'na') = 'owned_and_operated'
    THEN 'o&o'
    WHEN COALESCE(network.supply_source_type, 'na') = 'mpp'
    AND in_order.transaction_type = 'guaranteed'
    THEN 'mpp guaranteed'
    WHEN COALESCE(network.supply_source_type, 'na') = 'mpp'
    AND in_order.transaction_type = 'non_guaranteed'
    THEN 'mpp non-guaranteed'
    ELSE COALESCE(network.supply_source_type, 'na')
  END AS supply_source_detail,
  COALESCE(upstream_network.network_id, CAST(-1 AS BIGINT)) AS upstream_network_id,
  COALESCE(
    upstream_network.inbound_order.order_id,
    upstream_network.inbound_order_id,
    CAST(-1 AS BIGINT)
  ) AS upstream_network_inbound_order_id,
  COALESCE(upstream_network.inbound_order.order_type, 'na') AS upstream_network_inbound_order_type,
  COALESCE(upstream_network.inbound_order.order_priority, 'na') AS upstream_network_inbound_order_priority,
  COALESCE(upstream_network.inbound_order.unified_priority.priority_tier, 'na') AS upstream_network_inbound_order_priority_tier,
  COALESCE(upstream_network.inbound_order.unified_priority.sub_priority_value, -1) AS upstream_network_inbound_order_priority_value,
  COALESCE(upstream_network.supply_source_type, 'na') AS upstream_network_supply_source_type,
  COALESCE(t.external_network_id, CAST(-1 AS BIGINT)) AS external_network_id,
  CAST(-1 AS BIGINT) AS slot_ad_unit_id,
  -1 AS slot_sequence,
  'na' AS time_position_class,
  'na' AS slot_placed_status,
  'na' AS slot_fill_status,
  'direct sold' AS sales_channel,
  'placement' AS node_type,
  COALESCE(t.placement_id, CAST(-1 AS BIGINT)) AS placement_id,
  CAST(-1 AS BIGINT) AS ad_id,
  CAST(-1 AS BIGINT) AS local_advertiser_id,
  ARRAY[] AS global_advertiser_ids,
  ARRAY[] AS global_brand_ids,
  ARRAY[] AS global_industry_ids,
  'na' AS ad_priority_type,
  'na' AS ad_priority_tier,
  CAST(-1 AS BIGINT) AS ad_priority_value,
  COALESCE(t.error, 0) AS error_code,
  COALESCE(err.display_name, 'na') AS error_display_name,
  CAST(-1 AS BIGINT) AS outbound_order_id,
  CAST(-1 AS BIGINT) AS buyer_network_id,
  'na' AS outbound_order_type,
  'na' AS outbound_order_priority,
  'na' AS outbound_order_priority_tier,
  CAST(-1 AS BIGINT) AS outbound_order_priority_value,
  CAST(-1 AS BIGINT) AS internal_deal_id,
  -1 AS buyer_group_id,
  'placement' AS demand_type,
  COALESCE(t.placement_id, CAST(-1 AS BIGINT)) AS demand_id,
  COALESCE(plc.priority_type, 'na') AS demand_priority_type,
  COALESCE(plc.priority_value, CAST(-1 AS BIGINT)) AS demand_priority_value,
  COALESCE(
    ELEMENT_AT(request.standard_device_type_ids, CAST(-1 AS BIGINT)),
    CAST(-1 AS BIGINT)
  ) AS standard_device_type_id,
  CAST(DATE_TRUNC('HOUR', FROM_UNIXTIME(timestamp)) AS TIMESTAMP) AS timestamp,
  0 AS ad_error_frequency,
  0 AS targeted_ads,
  0 AS flattened_ads,
  0 AS available_ads,
  0 AS eligible_ads,
  0 AS distinct_selected_ads,
  0 AS distinct_filled_ads,
  SUM(COALESCE(magnifier, 1)) AS plc_error_frequency,
  SUM(
    IF(BITWISE_AND(COALESCE(t.selection_status, 0), 1) > 0, COALESCE(magnifier, 1), 0)
  ) AS targeted_plcs,
  SUM(
    IF(BITWISE_AND(COALESCE(t.selection_status, 0), 2) > 0, COALESCE(magnifier, 1), 0)
  ) AS flattened_plcs,
  0 AS ad_in_slot_error_frequency,
  0 AS eligible_ads_in_slot,
  0 AS ad_filled_ads,
  0 AS ad_raw_selected_ad,
  0 AS ad_raw_selected_ad_primary,
  0 AS ad_raw_selected_ad_primary_sstf_failed,
  0 AS ad_sstf_failed_has_fallback,
  0 AS ad_sstf_failed_no_fallback,
  0 AS order_error_frequency,
  0 AS targeted_orders,
  0 AS candidated_orders,
  0 AS executed_orders,
  SUM(COALESCE(network.order_opportunity, 0) * COALESCE(magnifier, 1)) AS inbound_order_opportunity,
  0 AS ad_selected_ad_primary,
  0 AS ad_selected_ad_fallback,
  SUM(COALESCE(upstream_network.order_opportunity, 0) * COALESCE(magnifier, 1)) AS upstream_network_order_opportunity,
  0 AS outbound_order_opportunity,
  0 AS ad_selected_ad,
  0 AS slot_opportunity,
  0 AS distinct_inventory_avails,
  0 AS deal_opportunity,
  0 AS demand_opportunity,
  SUM(
    IF(
      BITWISE_AND(COALESCE(t.selection_status, 0), 1) > 0
      AND BITWISE_AND(COALESCE(t.selection_status, 0), 2) = 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS tx_candidates,
  0 AS tx_eligibles,
  0 AS slot_eligibles,
  0 AS slot_placed_ads,
  0 AS selected_ads_sampled,
  0 AS impression,
  SUM(
    CASE
      WHEN BITWISE_AND(COALESCE(t.selection_status, 0), 1) > 0
      AND BITWISE_AND(COALESCE(t.selection_status, 0), 2) = 0
      THEN COALESCE(magnifier, 1)
      ELSE 0
    END
  ) AS tx_error_frequency,
  0 AS slot_error_frequency,
  0 AS sstf_err_frequency
FROM db.troubleshooting_log."fw_ads_demand_troubleshooting_log"
CROSS JOIN UNNEST(ad_selection_info) AS t
LEFT JOIN db.default.d_mkpl_order AS in_order
  ON COALESCE(network.inbound_order.order_id, network.inbound_order_id, CAST(-1 AS BIGINT)) = in_order.id
LEFT JOIN db.default.d_placement AS plc
  ON COALESCE(t.placement_id, CAST(-1 AS BIGINT)) = plc.id
LEFT JOIN oltp.fwmrm_oltp.lu_mkpl_selection_error AS err
  ON COALESCE(t.error, 0) = err.id
WHERE
  FROM_UNIXTIME(timestamp) >= CAST('2026-08-01 12:00:00' AS TIMESTAMP)
  AND FROM_UNIXTIME(timestamp) < CAST('2026-08-01 13:00:00' AS TIMESTAMP)
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
  62
UNION ALL
SELECT
  COALESCE(request.video_cro_network_id, CAST(-1 AS BIGINT)) AS video_cro_network_id,
  COALESCE(request.distributor_network_id, CAST(-1 AS BIGINT)) AS distributor_network_id,
  COALESCE(request.profile_id, CAST(-1 AS BIGINT)) AS profile_id,
  COALESCE(request.standard_endpoint_id, CAST(-1 AS BIGINT)) AS standard_endpoint_id,
  COALESCE(request.standard_endpoint_owner_id, CAST(-1 AS BIGINT)) AS standard_endpoint_owner_id,
  COALESCE(request.standard_brand_id, CAST(-1 AS BIGINT)) AS standard_brand_id,
  COALESCE(request.standard_programmer_id, CAST(-1 AS BIGINT)) AS standard_programmer_id,
  COALESCE(request.content_form_id, CAST(-1 AS BIGINT)) AS content_form_id,
  COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), CAST(-1 AS BIGINT)) AS stream_mode_id,
  COALESCE(request.standard_publisher_id, CAST(-1 AS BIGINT)) AS standard_publisher_id,
  COALESCE(request.country_id, CAST(-1 AS BIGINT)) AS country_id,
  COALESCE(request.slot_template_id, CAST(-1 AS BIGINT)) AS cbp_id,
  CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 'true' ELSE 'false' END AS request_is_filtered,
  COALESCE(request.video_cro_site_section_id, CAST(-1 AS BIGINT)) AS site_section_id,
  COALESCE(request.series_id, CAST(-1 AS BIGINT)) AS video_series_id,
  COALESCE(network.network_id, CAST(-1 AS BIGINT)) AS network_id,
  COALESCE(network.inbound_order.order_id, network.inbound_order_id, CAST(-1 AS BIGINT)) AS inbound_order_id,
  COALESCE(network.inbound_order.order_type, 'na') AS inbound_order_type,
  COALESCE(network.inbound_order.order_priority, 'na') AS inbound_order_priority,
  COALESCE(network.inbound_order.unified_priority.priority_tier, 'na') AS inbound_order_priority_tier,
  COALESCE(network.inbound_order.unified_priority.sub_priority_value, -1) AS inbound_order_priority_value,
  CASE
    WHEN in_order.order_type = 'carriage_order'
    THEN 'inventory split'
    WHEN COALESCE(network.supply_source_type, 'na') = 'owned_and_operated'
    THEN 'o&o'
    WHEN COALESCE(network.supply_source_type, 'na') = 'mpp'
    AND in_order.transaction_type = 'guaranteed'
    THEN 'mpp guaranteed'
    WHEN COALESCE(network.supply_source_type, 'na') = 'mpp'
    AND in_order.transaction_type = 'non_guaranteed'
    THEN 'mpp non-guaranteed'
    ELSE COALESCE(network.supply_source_type, 'na')
  END AS supply_source_detail,
  COALESCE(upstream_network.network_id, CAST(-1 AS BIGINT)) AS upstream_network_id,
  COALESCE(
    upstream_network.inbound_order.order_id,
    upstream_network.inbound_order_id,
    CAST(-1 AS BIGINT)
  ) AS upstream_network_inbound_order_id,
  COALESCE(upstream_network.inbound_order.order_type, 'na') AS upstream_network_inbound_order_type,
  COALESCE(upstream_network.inbound_order.order_priority, 'na') AS upstream_network_inbound_order_priority,
  COALESCE(upstream_network.inbound_order.unified_priority.priority_tier, 'na') AS upstream_network_inbound_order_priority_tier,
  COALESCE(upstream_network.inbound_order.unified_priority.sub_priority_value, -1) AS upstream_network_inbound_order_priority_value,
  COALESCE(upstream_network.supply_source_type, 'na') AS upstream_network_supply_source_type,
  COALESCE(t.external_network_id, CAST(-1 AS BIGINT)) AS external_network_id,
  COALESCE(slot.ad_unit_id, CAST(-1 AS BIGINT)) AS slot_ad_unit_id,
  COALESCE(slot.sequence, -1) AS slot_sequence,
  COALESCE(slot.time_position_class, 'na') AS time_position_class,
  CASE
    WHEN slot.time_position_class = 'overlay'
    AND slot.initial_num_ads = 0
    AND slot.max_ads > 0
    THEN 'empty'
    WHEN slot.time_position_class = 'overlay'
    AND slot.initial_num_ads = 0
    AND slot.max_ads = 0
    THEN 'unfillable'
    WHEN slot.time_position_class = 'overlay' AND slot.initial_num_ads = slot.max_ads
    THEN 'fully filled'
    WHEN slot.time_position_class = 'overlay'
    AND slot.initial_num_ads > 0
    AND slot.initial_num_ads < slot.max_ads
    THEN 'partially filled'
    WHEN slot.time_position_class <> 'overlay'
    AND slot.initial_num_ads = 0
    AND COALESCE(slot.initial_unfilled_avails, 0) > 0
    THEN 'empty'
    WHEN slot.time_position_class <> 'overlay'
    AND slot.initial_num_ads = 0
    AND COALESCE(slot.initial_unfilled_avails, 0) = 0
    THEN 'unfillable'
    WHEN slot.time_position_class <> 'overlay'
    AND COALESCE(slot.initial_unfilled_avails, 0) = 0
    THEN 'fully filled'
    WHEN slot.time_position_class <> 'overlay'
    AND slot.initial_num_ads > 0
    AND COALESCE(slot.initial_unfilled_avails, 0) > 0
    THEN 'partially filled'
    ELSE 'unknown'
  END AS slot_placed_status,
  CASE
    WHEN slot.time_position_class = 'overlay' AND slot.num_ads = 0 AND slot.max_ads > 0
    THEN 'empty'
    WHEN slot.time_position_class = 'overlay' AND slot.num_ads = 0 AND slot.max_ads = 0
    THEN 'unfillable'
    WHEN slot.time_position_class = 'overlay' AND slot.num_ads = slot.max_ads
    THEN 'fully filled'
    WHEN slot.time_position_class = 'overlay'
    AND slot.num_ads > 0
    AND slot.num_ads < slot.max_ads
    THEN 'partially filled'
    WHEN slot.num_ads = 0 AND COALESCE(slot.unfilled_avails, 0) > 0
    THEN 'empty'
    WHEN slot.num_ads = 0 AND COALESCE(slot.unfilled_avails, 0) = 0
    THEN 'unfillable'
    WHEN slot.unfilled_avails = 0
    THEN 'fully filled'
    WHEN slot.num_ads > 0 AND slot.unfilled_avails > 0
    THEN 'partially filled'
    ELSE 'unknown'
  END AS slot_fill_status,
  'direct sold' AS sales_channel,
  'ad_in_slot' AS node_type,
  COALESCE(t.placement_id, CAST(-1 AS BIGINT)) AS placement_id,
  COALESCE(ad.ad_id, CAST(-1 AS BIGINT)) AS ad_id,
  COALESCE(ad.advertiser_id, CAST(-1 AS BIGINT)) AS local_advertiser_id,
  COALESCE(ARRAY_DISTINCT(ARRAY_SORT(ad.global_advertiser_ids)), ARRAY[]) AS global_advertiser_ids,
  COALESCE(ARRAY_DISTINCT(ARRAY_SORT(ad.global_brand_ids)), ARRAY[]) AS global_brand_ids,
  COALESCE(ARRAY_DISTINCT(ARRAY_SORT(ad.global_industry_ids)), ARRAY[]) AS global_industry_ids,
  COALESCE(ad.ad_priority_type, 'na') AS ad_priority_type,
  COALESCE(ad.effective_unified_priority.priority_tier, 'na') AS ad_priority_tier,
  COALESCE(ad.effective_unified_priority.sub_priority_value, CAST(-1 AS BIGINT)) AS ad_priority_value,
  COALESCE(slot_ad.error, 0) AS error_code,
  COALESCE(err.display_name, 'na') AS error_display_name,
  CAST(-1 AS BIGINT) AS outbound_order_id,
  CAST(-1 AS BIGINT) AS buyer_network_id,
  'na' AS outbound_order_type,
  'na' AS outbound_order_priority,
  'na' AS outbound_order_priority_tier,
  CAST(-1 AS BIGINT) AS outbound_order_priority_value,
  CAST(-1 AS BIGINT) AS internal_deal_id,
  -1 AS buyer_group_id,
  'placement' AS demand_type,
  COALESCE(t.placement_id, CAST(-1 AS BIGINT)) AS demand_id,
  COALESCE(plc.priority_type, 'na') AS demand_priority_type,
  COALESCE(plc.priority_value, CAST(-1 AS BIGINT)) AS demand_priority_value,
  COALESCE(
    ELEMENT_AT(request.standard_device_type_ids, CAST(-1 AS BIGINT)),
    CAST(-1 AS BIGINT)
  ) AS standard_device_type_id,
  CAST(DATE_TRUNC('HOUR', FROM_UNIXTIME(timestamp)) AS TIMESTAMP) AS timestamp,
  0 AS ad_error_frequency,
  0 AS targeted_ads,
  0 AS flattened_ads,
  0 AS available_ads,
  0 AS eligible_ads,
  0 AS distinct_selected_ads,
  0 AS distinct_filled_ads,
  0 AS plc_error_frequency,
  0 AS targeted_plcs,
  0 AS flattened_plcs,
  SUM(COALESCE(magnifier, 1)) AS ad_in_slot_error_frequency,
  SUM(
    IF(BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 8) > 0, COALESCE(magnifier, 1), 0)
  ) AS eligible_ads_in_slot,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 32) > 0
      AND (
        BITWISE_AND(slot_ad.flags, 33554432) > 0 OR BITWISE_AND(slot_ad.flags, 32) = 0
      ),
      COALESCE(magnifier, 1),
      0
    )
  ) AS ad_filled_ads,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 16) > 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS ad_raw_selected_ad,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 16) > 0
      AND BITWISE_AND(slot_ad.flags, 32) = 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS ad_raw_selected_ad_primary,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 16) > 0
      AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 32) = 0
      AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 67108864) > 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS ad_raw_selected_ad_primary_sstf_failed,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 16) > 0
      AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 32) = 0
      AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 67108864) > 0
      AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 512) > 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS ad_sstf_failed_has_fallback,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 16) > 0
      AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 32) = 0
      AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 67108864) > 0
      AND BITWISE_AND(COALESCE(slot_ad.flags, 0), 512) = 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS ad_sstf_failed_no_fallback,
  0 AS order_error_frequency,
  0 AS targeted_orders,
  0 AS candidated_orders,
  0 AS executed_orders,
  SUM(COALESCE(network.order_opportunity, 0) * COALESCE(magnifier, 1)) AS inbound_order_opportunity,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 32) > 0
      AND BITWISE_AND(slot_ad.flags, 32) = 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS ad_selected_ad_primary,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 32) > 0
      AND BITWISE_AND(slot_ad.flags, 32) > 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS ad_selected_ad_fallback,
  SUM(COALESCE(upstream_network.order_opportunity, 0) * COALESCE(magnifier, 1)) AS upstream_network_order_opportunity,
  0 AS outbound_order_opportunity,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 32) > 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS ad_selected_ad,
  0 AS slot_opportunity,
  0 AS distinct_inventory_avails,
  0 AS deal_opportunity,
  SUM(
    IF(BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 8) > 0, COALESCE(magnifier, 1), 0)
  ) AS demand_opportunity,
  0 AS tx_candidates,
  0 AS tx_eligibles,
  SUM(
    IF(BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 8) > 0, COALESCE(magnifier, 1), 0)
  ) AS slot_eligibles,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 16) > 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS slot_placed_ads,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 32) > 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS selected_ads_sampled,
  0 AS impression,
  0 AS tx_error_frequency,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 8) > 0
      AND BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 16) = 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS slot_error_frequency,
  SUM(
    IF(
      BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 16) > 0
      AND BITWISE_AND(COALESCE(slot_ad.selection_status, 0), 32) = 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS sstf_err_frequency
FROM db.troubleshooting_log."fw_ads_demand_troubleshooting_log"
CROSS JOIN UNNEST(ad_selection_info) AS t
CROSS JOIN UNNEST(t.ad_infos) AS ad
CROSS JOIN UNNEST(ad.slot_ad_infos) AS slot_ad
CROSS JOIN UNNEST(slots) AS slot
LEFT JOIN db.default.d_mkpl_order AS in_order
  ON COALESCE(network.inbound_order.order_id, network.inbound_order_id, CAST(-1 AS BIGINT)) = in_order.id
LEFT JOIN oltp.fwmrm_oltp.lu_mkpl_selection_error AS err
  ON COALESCE(slot_ad.error, 0) = err.id
LEFT JOIN db.default.d_placement AS plc
  ON plc.id = COALESCE(t.placement_id, CAST(-1 AS BIGINT))
WHERE
  (
    FROM_UNIXTIME(timestamp) >= CAST('2026-08-01 12:00:00' AS TIMESTAMP)
    AND FROM_UNIXTIME(timestamp) < CAST('2026-08-01 13:00:00' AS TIMESTAMP)
  )
  AND slot_ad.slot_index = slot.index
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
  62
UNION ALL
SELECT
  COALESCE(request.video_cro_network_id, CAST(-1 AS BIGINT)) AS video_cro_network_id,
  COALESCE(request.distributor_network_id, CAST(-1 AS BIGINT)) AS distributor_network_id,
  COALESCE(request.profile_id, CAST(-1 AS BIGINT)) AS profile_id,
  COALESCE(request.standard_endpoint_id, CAST(-1 AS BIGINT)) AS standard_endpoint_id,
  COALESCE(request.standard_endpoint_owner_id, CAST(-1 AS BIGINT)) AS standard_endpoint_owner_id,
  COALESCE(request.standard_brand_id, CAST(-1 AS BIGINT)) AS standard_brand_id,
  COALESCE(request.standard_programmer_id, CAST(-1 AS BIGINT)) AS standard_programmer_id,
  COALESCE(request.content_form_id, CAST(-1 AS BIGINT)) AS content_form_id,
  COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), CAST(-1 AS BIGINT)) AS stream_mode_id,
  COALESCE(request.standard_publisher_id, CAST(-1 AS BIGINT)) AS standard_publisher_id,
  COALESCE(request.country_id, CAST(-1 AS BIGINT)) AS country_id,
  COALESCE(request.slot_template_id, CAST(-1 AS BIGINT)) AS cbp_id,
  CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 'true' ELSE 'false' END AS request_is_filtered,
  COALESCE(request.video_cro_site_section_id, CAST(-1 AS BIGINT)) AS site_section_id,
  COALESCE(request.series_id, CAST(-1 AS BIGINT)) AS video_series_id,
  COALESCE(network.network_id, CAST(-1 AS BIGINT)) AS network_id,
  COALESCE(network.inbound_order.order_id, network.inbound_order_id, CAST(-1 AS BIGINT)) AS inbound_order_id,
  COALESCE(network.inbound_order.order_type, 'na') AS inbound_order_type,
  COALESCE(network.inbound_order.order_priority, 'na') AS inbound_order_priority,
  COALESCE(network.inbound_order.unified_priority.priority_tier, 'na') AS inbound_order_priority_tier,
  COALESCE(network.inbound_order.unified_priority.sub_priority_value, -1) AS inbound_order_priority_value,
  CASE
    WHEN in_order.order_type = 'carriage_order'
    THEN 'inventory split'
    WHEN COALESCE(network.supply_source_type, 'na') = 'owned_and_operated'
    THEN 'o&o'
    WHEN COALESCE(network.supply_source_type, 'na') = 'mpp'
    AND in_order.transaction_type = 'guaranteed'
    THEN 'mpp guaranteed'
    WHEN COALESCE(network.supply_source_type, 'na') = 'mpp'
    AND in_order.transaction_type = 'non_guaranteed'
    THEN 'mpp non-guaranteed'
    ELSE COALESCE(network.supply_source_type, 'na')
  END AS supply_source_detail,
  COALESCE(upstream_network.network_id, CAST(-1 AS BIGINT)) AS upstream_network_id,
  COALESCE(
    upstream_network.inbound_order.order_id,
    upstream_network.inbound_order_id,
    CAST(-1 AS BIGINT)
  ) AS upstream_network_inbound_order_id,
  COALESCE(upstream_network.inbound_order.order_type, 'na') AS upstream_network_inbound_order_type,
  COALESCE(upstream_network.inbound_order.order_priority, 'na') AS upstream_network_inbound_order_priority,
  COALESCE(upstream_network.inbound_order.unified_priority.priority_tier, 'na') AS upstream_network_inbound_order_priority_tier,
  COALESCE(upstream_network.inbound_order.unified_priority.sub_priority_value, -1) AS upstream_network_inbound_order_priority_value,
  COALESCE(upstream_network.supply_source_type, 'na') AS upstream_network_supply_source_type,
  CAST(-1 AS BIGINT) AS external_network_id,
  CAST(-1 AS BIGINT) AS slot_ad_unit_id,
  -1 AS slot_sequence,
  'na' AS time_position_class,
  'na' AS slot_placed_status,
  'na' AS slot_fill_status,
  CASE
    WHEN TRIM(orders.order_type) = 'marketplace_order'
    THEN 'partner trading'
    WHEN TRIM(orders.order_type) = 'exchange_order'
    THEN 'marketplace platform exchange'
    ELSE 'partner trading'
  END AS sales_channel,
  'order' AS node_type,
  CAST(-1 AS BIGINT) AS placement_id,
  CAST(-1 AS BIGINT) AS ad_id,
  CAST(-1 AS BIGINT) AS local_advertiser_id,
  ARRAY[] AS global_advertiser_ids,
  ARRAY[] AS global_brand_ids,
  ARRAY[] AS global_industry_ids,
  'na' AS ad_priority_type,
  'na' AS ad_priority_tier,
  -1 AS ad_priority_value,
  COALESCE(t.error, 0) AS error_code,
  COALESCE(err.display_name, 'na') AS error_display_name,
  COALESCE(orders.order_id, CAST(-1 AS BIGINT)) AS outbound_order_id,
  COALESCE(t.buyer_network_id, CAST(-1 AS BIGINT)) AS buyer_network_id,
  COALESCE(orders.order_type, 'na') AS outbound_order_type,
  COALESCE(orders.unified_priority.priority_tier, 'na') AS outbound_order_priority_tier,
  COALESCE(orders.order_priority, 'na') AS outbound_order_priority,
  COALESCE(orders.unified_priority.sub_priority_value, CAST(-1 AS BIGINT)) AS outbound_order_priority_value,
  CAST(-1 AS BIGINT) AS internal_deal_id,
  -1 AS buyer_group_id,
  CASE
    WHEN TRIM(orders.order_type) = 'marketplace_order'
    THEN 'partner trading'
    WHEN TRIM(orders.order_type) = 'exchange_order'
    THEN 'marketplace platform exchange'
    ELSE 'partner trading'
  END AS demand_type,
  COALESCE(orders.order_id, CAST(-1 AS BIGINT)) AS demand_id,
  COALESCE(orders.order_priority, 'na') AS demand_priority_type,
  COALESCE(orders.unified_priority.sub_priority_value, CAST(-1 AS BIGINT)) AS demand_priority_value,
  COALESCE(
    ELEMENT_AT(request.standard_device_type_ids, CAST(-1 AS BIGINT)),
    CAST(-1 AS BIGINT)
  ) AS standard_device_type_id,
  CAST(DATE_TRUNC('HOUR', FROM_UNIXTIME(timestamp)) AS TIMESTAMP) AS timestamp,
  0 AS ad_error_frequency,
  0 AS targeted_ads,
  0 AS flattened_ads,
  0 AS available_ads,
  0 AS eligible_ads,
  0 AS distinct_selected_ads,
  0 AS distinct_filled_ads,
  0 AS plc_error_frequency,
  0 AS targeted_plcs,
  0 AS flattened_plcs,
  0 AS ad_in_slot_error_frequency,
  0 AS eligible_ads_in_slot,
  0 AS ad_filled_ads,
  0 AS ad_raw_selected_ad,
  0 AS ad_raw_selected_ad_primary,
  0 AS ad_raw_selected_ad_primary_sstf_failed,
  0 AS ad_sstf_failed_has_fallback,
  0 AS ad_sstf_failed_no_fallback,
  SUM(COALESCE(magnifier, 1)) AS order_error_frequency,
  SUM(
    IF(BITWISE_AND(COALESCE(t.selection_status, 0), 1) > 0, COALESCE(magnifier, 1), 0)
  ) AS targeted_orders,
  SUM(
    IF(BITWISE_AND(COALESCE(t.selection_status, 0), 2) > 0, COALESCE(magnifier, 1), 0)
  ) AS candidated_orders,
  SUM(
    IF(BITWISE_AND(COALESCE(t.selection_status, 0), 4) > 0, COALESCE(magnifier, 1), 0)
  ) AS executed_orders,
  SUM(COALESCE(network.order_opportunity, 0) * COALESCE(magnifier, 1)) AS inbound_order_opportunity,
  0 AS ad_selected_ad_primary,
  0 AS ad_selected_ad_fallback,
  SUM(COALESCE(upstream_network.order_opportunity, 0) * COALESCE(magnifier, 1)) AS upstream_network_order_opportunity,
  0 AS outbound_order_opportunity,
  0 AS ad_selected_ad,
  0 AS slot_opportunity,
  0 AS distinct_inventory_avails,
  0 AS deal_opportunity,
  0 AS demand_opportunity,
  SUM(
    IF(BITWISE_AND(COALESCE(t.selection_status, 0), 1) > 0, COALESCE(magnifier, 1), 0)
  ) AS tx_candidates,
  SUM(
    IF(BITWISE_AND(COALESCE(t.selection_status, 0), 4) > 0, COALESCE(magnifier, 1), 0)
  ) AS tx_eligibles,
  0 AS slot_eligibles,
  0 AS slot_placed_ads,
  0 AS selected_ads_sampled,
  0 AS impression,
  SUM(
    IF(
      BITWISE_AND(COALESCE(t.selection_status, 0), 1) > 0
      AND BITWISE_AND(COALESCE(t.selection_status, 0), 4) = 0,
      COALESCE(magnifier, 1),
      0
    )
  ) AS tx_error_frequency,
  0 AS slot_error_frequency,
  0 AS sstf_err_frequency
FROM db.troubleshooting_log."fw_ads_demand_troubleshooting_log"
CROSS JOIN UNNEST(outbound_order_selection_info) AS t(order_id, buyer_network_id, selection_status, error, orders)
LEFT JOIN db.default.d_mkpl_order AS in_order
  ON COALESCE(network.inbound_order.order_id, network.inbound_order_id, CAST(-1 AS BIGINT)) = in_order.id
LEFT JOIN db.default.d_mkpl_order AS out_order
  ON COALESCE(orders.order_id, CAST(-1 AS BIGINT)) = out_order.id
LEFT JOIN oltp.fwmrm_oltp.lu_mkpl_selection_error AS err
  ON COALESCE(t.error, 0) = err.id
WHERE
  FROM_UNIXTIME(timestamp) >= CAST('2026-08-01 12:00:00' AS TIMESTAMP)
  AND FROM_UNIXTIME(timestamp) < CAST('2026-08-01 13:00:00' AS TIMESTAMP)
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
  62
UNION ALL
SELECT
  COALESCE(request.video_cro_network_id, CAST(-1 AS BIGINT)) AS video_cro_network_id,
  COALESCE(request.distributor_network_id, CAST(-1 AS BIGINT)) AS distributor_network_id,
  COALESCE(request.profile_id, CAST(-1 AS BIGINT)) AS profile_id,
  COALESCE(request.standard_endpoint_id, CAST(-1 AS BIGINT)) AS standard_endpoint_id,
  COALESCE(request.standard_endpoint_owner_id, CAST(-1 AS BIGINT)) AS standard_endpoint_owner_id,
  COALESCE(request.standard_brand_id, CAST(-1 AS BIGINT)) AS standard_brand_id,
  COALESCE(request.standard_programmer_id, CAST(-1 AS BIGINT)) AS standard_programmer_id,
  COALESCE(request.content_form_id, CAST(-1 AS BIGINT)) AS content_form_id,
  COALESCE(ELEMENT_AT(request.stream_mode_ids, 1), CAST(-1 AS BIGINT)) AS stream_mode_id,
  COALESCE(request.standard_publisher_id, CAST(-1 AS BIGINT)) AS standard_publisher_id,
  COALESCE(request.country_id, CAST(-1 AS BIGINT)) AS country_id,
  COALESCE(request.slot_template_id, CAST(-1 AS BIGINT)) AS cbp_id,
  CASE WHEN BITWISE_AND(request.flags, 64) > 0 THEN 'true' ELSE 'false' END AS request_is_filtered,
  COALESCE(request.video_cro_site_section_id, CAST(-1 AS BIGINT)) AS site_section_id,
  COALESCE(request.series_id, CAST(-1 AS BIGINT)) AS video_series_id,
  COALESCE(upstream_network.network_id, CAST(-1 AS BIGINT)) AS network_id,
  COALESCE(
    upstream_network.inbound_order.order_id,
    upstream_network.inbound_order_id,
    CAST(-1 AS BIGINT)
  ) AS inbound_order_id,
  COALESCE(upstream_network.inbound_order.order_type, 'na') AS inbound_order_type,
  COALESCE(upstream_network.inbound_order.order_priority, 'na') AS inbound_order_priority,
  COALESCE(upstream_network.inbound_order.unified_priority.priority_tier, 'na') AS inbound_order_priority_tier,
  COALESCE(upstream_network.inbound_order.unified_priority.sub_priority_value, -1) AS inbound_order_priority_value,
  CASE
    WHEN in_order.order_type = 'carriage_order'
    THEN 'inventory split'
    WHEN COALESCE(upstream_network.supply_source_type, 'na') = 'owned_and_operated'
    THEN 'o&o'
    WHEN COALESCE(upstream_network.supply_source_type, 'na') = 'mpp'
    AND in_order.transaction_type = 'guaranteed'
    THEN 'mpp guaranteed'
    WHEN COALESCE(upstream_network.supply_source_type, 'na') = 'mpp'
    AND in_order.transaction_type = 'non_guaranteed'
    THEN 'mpp non-guaranteed'
    ELSE COALESCE(upstream_network.supply_source_type, 'na')
  END AS supply_source_detail,
  CAST(-1 AS BIGINT) AS upstream_network_id,
  CAST(-1 AS BIGINT) AS upstream_network_inbound_order_id,
  'na' AS upstream_network_inbound_order_type,
  'na' AS upstream_network_inbound_order_priority,
  'na' AS upstream_network_inbound_order_priority_tier,
  -1 AS upstream_network_inbound_order_priority_value,
  'na' AS upstream_network_supply_source_type,
  CAST(-1 AS BIGINT) AS external_network_id,
  CAST(-1 AS BIGINT) AS slot_ad_unit_id,
  -1 AS slot_sequence,
  'na' AS time_position_class,
  'na' AS slot_placed_status,
  'na' AS slot_fill_status,
  CASE
    WHEN TRIM(network.inbound_order.order_type) = 'marketplace_order'
    THEN 'partner trading'
    WHEN TRIM(network.inbound_order.order_type) = 'exchange_order'
    THEN 'marketplace platform exchange'
    ELSE 'partner trading'
  END AS sales_channel,
  'order' AS node_type,
  CAST(-1 AS BIGINT) AS placement_id,
  CAST(-1 AS BIGINT) AS ad_id,
  CAST(-1 AS BIGINT) AS local_advertiser_id,
  ARRAY[] AS global_advertiser_ids,
  ARRAY[] AS global_brand_ids,
  ARRAY[] AS global_industry_ids,
  'na' AS ad_priority_type,
  'na' AS ad_priority_tier,
  CAST(-1 AS BIGINT) AS ad_priority_value,
  0 AS error_code,
  'na' AS error_display_name,
  COALESCE(network.inbound_order.order_id, network.inbound_order_id, CAST(-1 AS BIGINT)) AS outbound_order_id,
  COALESCE(network.network_id, CAST(-1 AS BIGINT)) AS buyer_network_id,
  COALESCE(network.inbound_order.order_type, 'na') AS outbound_order_type,
  COALESCE(network.inbound_order.order_priority, 'na') AS outbound_order_priority,
  COALESCE(network.inbound_order.unified_priority.priority_tier, 'na') AS outbound_order_priority_tier,
  COALESCE(network.inbound_order.unified_priority.sub_priority_value, -1) AS outbound_order_priority_value,
  -1 AS internal_deal_id,
  -1 AS buyer_group_id,
  CASE
    WHEN TRIM(network.inbound_order.order_type) = 'marketplace_order'
    THEN 'partner trading'
    WHEN TRIM(network.inbound_order.order_type) = 'exchange_order'
    THEN 'marketplace platform exchange'
    ELSE 'partner trading'
  END AS demand_type,
  COALESCE(network.inbound_order.order_id, network.inbound_order_id, CAST(-1 AS BIGINT)) AS demand_id,
  COALESCE(network.inbound_order.unified_priority.priority_tier, 'na') AS demand_priority_type,
  COALESCE(network.inbound_order.unified_priority.sub_priority_value, -1) AS demand_priority_value,
  COALESCE(
    ELEMENT_AT(request.standard_device_type_ids, CAST(-1 AS BIGINT)),
    CAST(-1 AS BIGINT)
  ) AS standard_device_type_id,
  CAST(DATE_TRUNC('HOUR', FROM_UNIXTIME(timestamp)) AS TIMESTAMP) AS timestamp,
  0 AS ad_error_frequency,
  0 AS targeted_ads,
  0 AS flattened_ads,
  0 AS available_ads,
  0 AS eligible_ads,
  0 AS distinct_selected_ads,
  0 AS distinct_filled_ads,
  0 AS plc_error_frequency,
  0 AS targeted_plcs,
  0 AS flattened_plcs,
  0 AS ad_in_slot_error_frequency,
  0 AS eligible_ads_in_slot,
  0 AS ad_filled_ads,
  0 AS ad_raw_selected_ad,
  0 AS ad_raw_selected_ad_primary,
  0 AS ad_raw_selected_ad_primary_sstf_failed,
  0 AS ad_sstf_failed_has_fallback,
  0 AS ad_sstf_failed_no_fallback,
  0 AS order_error_frequency,
  0 AS targeted_orders,
  0 AS candidated_orders,
  0 AS executed_orders,
  SUM(COALESCE(upstream_network.order_opportunity, 0) * COALESCE(magnifier, 1)) AS inbound_order_opportunity,
  0 AS ad_selected_ad_primary,
  0 AS ad_selected_ad_fallback,
  0 AS upstream_network_order_opportunity,
  SUM(COALESCE(network.order_opportunity, 0) * COALESCE(magnifier, 1)) AS outbound_order_opportunity,
  0 AS ad_selected_ad,
  0 AS slot_opportunity,
  0 AS distinct_inventory_avails,
  0 AS deal_opportunity,
  SUM(COALESCE(network.order_opportunity, 0) * COALESCE(magnifier, 1)) AS demand_opportunity,
  0 AS tx_candidates,
  0 AS tx_eligibles,
  0 AS slot_eligibles,
  0 AS slot_placed_ads,
  0 AS selected_ads_sampled,
  0 AS impression,
  0 AS tx_error_frequency,
  0 AS slot_error_frequency,
  0 AS sstf_err_frequency
FROM db.troubleshooting_log."fw_ads_demand_troubleshooting_log"
LEFT JOIN db.default.d_mkpl_order AS in_order
  ON COALESCE(
    upstream_network.inbound_order.order_id,
    upstream_network.inbound_order_id,
    CAST(-1 AS BIGINT)
  ) = in_order.id
LEFT JOIN db.default.d_mkpl_order AS out_order
  ON COALESCE(network.inbound_order.order_id, network.inbound_order_id, CAST(-1 AS BIGINT)) = out_order.id
WHERE
  FROM_UNIXTIME(timestamp) >= CAST('2026-08-01 12:00:00' AS TIMESTAMP)
  AND FROM_UNIXTIME(timestamp) < CAST('2026-08-01 13:00:00' AS TIMESTAMP)
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
  62
UNION ALL
SELECT
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  IF(
    BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
    -3,
    COALESCE(nw.distributor_id, -1)
  ) AS distributor_network_id,
  IF(
    BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
    -3,
    COALESCE(request__context__profile_id, -1)
  ) AS profile_id,
  COALESCE(request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
  COALESCE(request__context__standard_endpoint_owner_id, -1) AS standard_endpoint_owner_id,
  COALESCE(request__context__standard_brand_id, -1) AS standard_brand_id,
  COALESCE(request__context__standard_programmer_id, -1) AS standard_programmer_id,
  COALESCE(request__context__content_form_id, -1) AS content_form_id,
  COALESCE(request__context__stream_mode_id, -1) AS stream_mode_id,
  COALESCE(request__context__standard_publisher_id, -1) AS standard_publisher_id,
  COALESCE(visitor__country_id, -1) AS country_id,
  COALESCE(request__cbp__slot_template_id, -1) AS cbp_id,
  'false' AS request_is_filtered,
  COALESCE(nw.site_section_id, -1) AS site_section_id,
  COALESCE(nw.series_id, -1) AS video_series_id,
  COALESCE(nw.nw_id, -1) AS network_id,
  COALESCE(inbound_order_id, -1) AS inbound_order_id,
  COALESCE(inbound_order_type, 'not applicable') AS inbound_order_type,
  'na' AS inbound_order_priority,
  'na' AS inbound_order_priority_tier,
  COALESCE(inbound_order.priority_value, -1) AS inbound_order_priority_value,
  CASE
    WHEN supply_source = 1
    THEN 'o&o'
    WHEN supply_source = 3
    THEN 'mrm2mrm'
    WHEN supply_source = 4
    THEN 'programmatic'
    WHEN supply_source = 5 AND COALESCE(inbound_order_type, 'na') = 'carriage_order'
    THEN 'inventory split'
    WHEN supply_source = 5
    AND COALESCE(inbound_order_type, 'na') = 'marketplace_order'
    AND COALESCE(inbound_order.transaction_type, 'na') = 'guaranteed'
    THEN 'mpp guaranteed'
    WHEN supply_source = 5
    THEN 'mpp non-guaranteed'
    WHEN supply_source = 6
    THEN 'mpe'
    ELSE 'unknown'
  END AS supply_source_detail,
  COALESCE(co_id, -1) AS upstream_network_id,
  CAST(-1 AS BIGINT) AS upstream_network_inbound_order_id,
  'na' AS upstream_network_inbound_order_type,
  'na' AS upstream_network_inbound_order_priority,
  'na' AS upstream_network_inbound_order_priority_tier,
  -1 AS upstream_network_inbound_order_priority_value,
  'na' AS upstream_network_supply_source_type,
  CAST(-1 AS BIGINT) AS external_network_id,
  COALESCE(slot__normalized_ad_unit_id, -1) AS slot_ad_unit_id,
  COALESCE(slot__slot_sequence, -1) AS slot_sequence,
  COALESCE(slot__time_position_class, 'na') AS time_position_class,
  'na' AS slot_placed_status,
  'na' AS slot_fill_status,
  'na' AS sales_channel,
  'na' AS node_type,
  CAST(-1 AS BIGINT) AS placement_id,
  CAST(-1 AS BIGINT) AS ad_id,
  CAST(-1 AS BIGINT) AS local_advertiser_id,
  ARRAY[] AS global_advertiser_ids,
  ARRAY[] AS global_brand_ids,
  ARRAY[] AS global_industry_ids,
  'na' AS ad_priority_type,
  'na' AS ad_priority_tier,
  CAST(-1 AS BIGINT) AS ad_priority_value,
  0 AS error_code,
  'na' AS error_display_name,
  -1 AS outbound_order_id,
  -1 AS buyer_network_id,
  'na' AS outbound_order_type,
  'na' AS outbound_order_priority,
  'na' AS outbound_order_priority_tier,
  -1 AS outbound_order_priority_value,
  -1 AS internal_deal_id,
  -1 AS buyer_group_id,
  'na' AS demand_type,
  CAST(-1 AS BIGINT) AS demand_id,
  'na' AS demand_priority_type,
  CAST(-1 AS BIGINT) AS demand_priority_value,
  COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  0 AS ad_error_frequency,
  0 AS targeted_ads,
  0 AS flattened_ads,
  0 AS available_ads,
  0 AS eligible_ads,
  0 AS distinct_selected_ads,
  0 AS distinct_filled_ads,
  0 AS plc_error_frequency,
  0 AS targeted_plcs,
  0 AS flattened_plcs,
  0 AS ad_in_slot_error_frequency,
  0 AS eligible_ads_in_slot,
  0 AS ad_filled_ads,
  0 AS ad_raw_selected_ad,
  0 AS ad_raw_selected_ad_primary,
  0 AS ad_raw_selected_ad_primary_sstf_failed,
  0 AS ad_sstf_failed_has_fallback,
  0 AS ad_sstf_failed_no_fallback,
  0 AS order_error_frequency,
  0 AS targeted_orders,
  0 AS candidated_orders,
  0 AS executed_orders,
  0 AS inbound_order_opportunity,
  0 AS ad_selected_ad_primary,
  0 AS ad_selected_ad_fallback,
  0 AS upstream_network_order_opportunity,
  0 AS outbound_order_opportunity,
  0 AS ad_selected_ad,
  SUM(inventory_avails * COALESCE(request__demand_log_magnifier, 1)) AS slot_opportunity,
  SUM(distinct_inventory_avails * COALESCE(request__demand_log_magnifier, 1)) AS distinct_inventory_avails,
  0 AS deal_opportunity,
  0 AS demand_opportunity,
  0 AS tx_candidates,
  0 AS tx_eligibles,
  0 AS slot_eligibles,
  0 AS slot_placed_ads,
  0 AS selected_ads_sampled,
  0 AS impression,
  0 AS tx_error_frequency,
  0 AS slot_error_frequency,
  0 AS sstf_err_frequency
FROM ${bcv_slot} AS s
CROSS JOIN UNNEST(partners__network_id, partners__site_id, partners__site_section_id, partners__distributor_network_id, partners__content_owner_network_id, partners__role, partners__supply_source, partners__inbound_order_id, partners__inbound_order_type, partners__avails_category__avails, partners__avails_category__unfilled_avails, partners__avails_category__total_avails, partners__avails_category__total_unfilled_avails, partners__avails_category__opportunity, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__input_ad_number, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__output_ad_number, partners__network_selection_info__candidate_ad_funnel_metrics__demand_type, partners__network_selection_info__candidate_ad_funnel_metrics__network_id, partners__ad_filling_status__filled_ad_num, partners__ad_filling_status__unified_unfilled_opp, partners__ad_filling_status__initial_filled_ad_num, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__output_fallback_ad_number, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__slot_max_num_ads, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__slot_max_duration, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__time_based_freq_cap, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__no_creative, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__companion_check_failed, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__pod_position_targeting_check_failed, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__slot_exclusivity_check_failed, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__slot_sponsorship_check_failed, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__slot_filled_by_multi_ad, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__slot_not_found, partners__network_selection_info__candidate_ad_funnel_metrics__ad_filling_metrics__do_not_repeat, partners__avails_category__distinct_inventory_avails, partners__avails_category__inventory_avails, partners__series_id) AS nw(nw_id, site_id, site_section_id, distributor_id, co_id, nw_role, supply_source, inbound_order_id, inbound_order_type, avails, unfilled_avails, total_avails, unfilled_total_avails, opportunity, phase9_input_ad_number, phase9_output_ad_number, sales_channel_normalized, reseller_ids, order_filled_ad_num, order_unfilled_opp, order_initial_filled_ad_num, output_fallback_ad_number, phase9_slot_max_num_ads, phase9_slot_max_duration, phase9_time_based_freq_cap, phase9_no_creative, phase9_companion_check_failed, phase9_pod_position_targeting_check_failed, phase9_slot_exclusivity_check_failed, phase9_slot_sponsorship_check_failed, phase9_slot_filled_by_multi_ad, phase9_slot_not_found, phase9_do_not_repeat, distinct_inventory_avails, inventory_avails, series_id)
LEFT JOIN db.default.d_mkpl_order AS inbound_order
  ON inbound_order.id = inbound_order_id
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
      AND nw.supply_source <> 4
    )
    AND NOT request__context__video_cro_network_id IN (519455, 520038, 516424, 520491, 516474, 523569)
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
  59,
  60,
  61,
  62
UNION ALL
SELECT
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  IF(
    BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
    -3,
    COALESCE(nw.distributor_id, -1)
  ) AS distributor_network_id,
  IF(
    BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
    -3,
    COALESCE(request__context__profile_id, -1)
  ) AS profile_id,
  COALESCE(request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
  COALESCE(request__context__standard_endpoint_owner_id, -1) AS standard_endpoint_owner_id,
  COALESCE(request__context__standard_brand_id, -1) AS standard_brand_id,
  COALESCE(request__context__standard_programmer_id, -1) AS standard_programmer_id,
  COALESCE(request__context__content_form_id, -1) AS content_form_id,
  COALESCE(request__context__stream_mode_id, -1) AS stream_mode_id,
  COALESCE(request__context__standard_publisher_id, -1) AS standard_publisher_id,
  COALESCE(visitor__country_id, -1) AS country_id,
  COALESCE(request__cbp__slot_template_id, -1) AS cbp_id,
  'false' AS request_is_filtered,
  COALESCE(nw.site_section_id, -1) AS site_section_id,
  COALESCE(nw.series_id, -1) AS video_series_id,
  COALESCE(nw.nw_id, -1) AS network_id,
  COALESCE(inbound_order_id, -1) AS inbound_order_id,
  COALESCE(inbound_order_type, 'not applicable') AS inbound_order_type,
  'na' AS inbound_order_priority,
  'na' AS inbound_order_priority_tier,
  COALESCE(inbound_order.priority_value, -1) AS inbound_order_priority_value,
  CASE
    WHEN supply_source = 1
    THEN 'o&o'
    WHEN supply_source = 3
    THEN 'mrm2mrm'
    WHEN supply_source = 4
    THEN 'programmatic'
    WHEN supply_source = 5 AND COALESCE(inbound_order_type, 'na') = 'carriage_order'
    THEN 'inventory split'
    WHEN supply_source = 5
    AND COALESCE(inbound_order_type, 'na') = 'marketplace_order'
    AND COALESCE(inbound_order.transaction_type, 'na') = 'guaranteed'
    THEN 'mpp guaranteed'
    WHEN supply_source = 5
    THEN 'mpp non-guaranteed'
    WHEN supply_source = 6
    THEN 'mpe'
    ELSE 'unknown'
  END AS supply_source_detail,
  COALESCE(co_id, -1) AS upstream_network_id,
  CAST(-1 AS BIGINT) AS upstream_network_inbound_order_id,
  'na' AS upstream_network_inbound_order_type,
  'na' AS upstream_network_inbound_order_priority,
  'na' AS upstream_network_inbound_order_priority_tier,
  -1 AS upstream_network_inbound_order_priority_value,
  'na' AS upstream_network_supply_source_type,
  CAST(-1 AS BIGINT) AS external_network_id,
  -1 AS slot_ad_unit_id,
  -1 AS slot_sequence,
  COALESCE(auction__time_position_class, 'na') AS time_position_class,
  'na' AS slot_placed_status,
  'na' AS slot_fill_status,
  'programmatic' AS sales_channel,
  'na' AS node_type,
  CAST(-1 AS BIGINT) AS placement_id,
  CAST(-1 AS BIGINT) AS ad_id,
  CAST(-1 AS BIGINT) AS local_advertiser_id,
  ARRAY[] AS global_advertiser_ids,
  ARRAY[] AS global_brand_ids,
  ARRAY[] AS global_industry_ids,
  'na' AS ad_priority_type,
  'na' AS ad_priority_tier,
  CAST(-1 AS BIGINT) AS ad_priority_value,
  0 AS error_code,
  'na' AS error_display_name,
  -1 AS outbound_order_id,
  -1 AS buyer_network_id,
  'na' AS outbound_order_type,
  'na' AS outbound_order_priority,
  'na' AS outbound_order_priority_tier,
  -1 AS outbound_order_priority_value,
  COALESCE(deal_id, -1) AS internal_deal_id,
  COALESCE(auction__buyer_group_id, -1) AS buyer_group_id,
  CASE WHEN COALESCE(deal_id, -1) > 0 THEN 'deal' ELSE 'buyer group' END AS demand_type,
  CASE
    WHEN COALESCE(deal_id, -1) > 0
    THEN deal_id
    ELSE COALESCE(auction__buyer_group_id, -1)
  END AS demand_id,
  COALESCE(deal.priority_bucket, 'na') AS demand_priority_type,
  CAST(-1 AS BIGINT) AS demand_priority_value,
  COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  0 AS ad_error_frequency,
  0 AS targeted_ads,
  0 AS flattened_ads,
  0 AS available_ads,
  0 AS eligible_ads,
  0 AS distinct_selected_ads,
  0 AS distinct_filled_ads,
  0 AS plc_error_frequency,
  0 AS targeted_plcs,
  0 AS flattened_plcs,
  0 AS ad_in_slot_error_frequency,
  0 AS eligible_ads_in_slot,
  0 AS ad_filled_ads,
  0 AS ad_raw_selected_ad,
  0 AS ad_raw_selected_ad_primary,
  0 AS ad_raw_selected_ad_primary_sstf_failed,
  0 AS ad_sstf_failed_has_fallback,
  0 AS ad_sstf_failed_no_fallback,
  0 AS order_error_frequency,
  0 AS targeted_orders,
  0 AS candidated_orders,
  0 AS executed_orders,
  0 AS inbound_order_opportunity,
  0 AS ad_selected_ad_primary,
  0 AS ad_selected_ad_fallback,
  0 AS upstream_network_order_opportunity,
  0 AS outbound_order_opportunity,
  0 AS ad_selected_ad,
  0 AS slot_opportunity,
  0 AS distinct_inventory_avails,
  SUM(
    IF(BITWISE_AND(auction__auction_status, 2) > 0, imp.imp_opp, 0) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(request__demand_log_magnifier, 0)
  ) AS deal_opportunity,
  SUM(
    IF(BITWISE_AND(auction__auction_status, 2) > 0, imp.imp_opp, 0) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(request__demand_log_magnifier, 0)
  ) AS demand_opportunity,
  0 AS tx_candidates,
  0 AS tx_eligibles,
  0 AS slot_eligibles,
  0 AS slot_placed_ads,
  0 AS selected_ads_sampled,
  0 AS impression,
  0 AS tx_error_frequency,
  0 AS slot_error_frequency,
  0 AS sstf_err_frequency
FROM ${bcv_auction}
CROSS JOIN UNNEST(auction__impression__index, auction__impression__equivalent_opportunity_number) AS imp(imp_index, imp_opp)
CROSS JOIN UNNEST(partners__network_id, partners__supply_source, partners__sales_channel, partners__entity_source, partners__internal_deal_ids, partners__deal_awareability, partners__inbound_order_id, partners__inbound_order_type, partners__content_owner_network_id, partners__distributor_network_id, partners__site_id, partners__site_section_id, partners__series_id) AS nw(nw_id, supply_source, sales_channel, entity_source, deal_ids, deal_awareability, inbound_order_id, inbound_order_type, co_id, distributor_id, site_id, site_section_id, series_id)
CROSS JOIN UNNEST(nw.deal_ids) AS deal(deal_id)
LEFT JOIN db.default.d_mkpl_order AS inbound_order
  ON inbound_order.id = inbound_order_id
LEFT JOIN db.default.d_ssp_deal AS deal
  ON deal.id = COALESCE(deal_id, -1)
WHERE
  (
    (
      (
        auction__is_faked_auction = FALSE
        AND auction__integration_type IN ('normal', 'pg_td')
      )
      AND nw.entity_source IN ('auction')
    )
    AND nw.sales_channel = 4
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
  59,
  60,
  61,
  62
UNION ALL
SELECT
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  IF(
    BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
    -3,
    COALESCE(nw.distributor_id, -1)
  ) AS distributor_network_id,
  IF(
    BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
    -3,
    COALESCE(request__context__profile_id, -1)
  ) AS profile_id,
  COALESCE(request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
  COALESCE(request__context__standard_endpoint_owner_id, -1) AS standard_endpoint_owner_id,
  COALESCE(request__context__standard_brand_id, -1) AS standard_brand_id,
  COALESCE(request__context__standard_programmer_id, -1) AS standard_programmer_id,
  COALESCE(request__context__content_form_id, -1) AS content_form_id,
  COALESCE(request__context__stream_mode_id, -1) AS stream_mode_id,
  COALESCE(request__context__standard_publisher_id, -1) AS standard_publisher_id,
  COALESCE(visitor__country_id, -1) AS country_id,
  COALESCE(request__cbp__slot_template_id, -1) AS cbp_id,
  'false' AS request_is_filtered,
  COALESCE(nw.site_section_id, -1) AS site_section_id,
  COALESCE(nw.series_id, -1) AS video_series_id,
  COALESCE(nw.nw_id, -1) AS network_id,
  COALESCE(inbound_order_id, -1) AS inbound_order_id,
  COALESCE(inbound_order_type, 'not applicable') AS inbound_order_type,
  'na' AS inbound_order_priority,
  'na' AS inbound_order_priority_tier,
  COALESCE(inbound_order.priority_value, -1) AS inbound_order_priority_value,
  CASE
    WHEN supply_source = 1
    THEN 'o&o'
    WHEN supply_source = 3
    THEN 'mrm2mrm'
    WHEN supply_source = 4
    THEN 'programmatic'
    WHEN supply_source = 5 AND COALESCE(inbound_order_type, 'na') = 'carriage_order'
    THEN 'inventory split'
    WHEN supply_source = 5
    AND COALESCE(inbound_order_type, 'na') = 'marketplace_order'
    AND COALESCE(inbound_order.transaction_type, 'na') = 'guaranteed'
    THEN 'mpp guaranteed'
    WHEN supply_source = 5
    THEN 'mpp non-guaranteed'
    WHEN supply_source = 6
    THEN 'mpe'
    ELSE 'unknown'
  END AS supply_source_detail,
  COALESCE(co_id, -1) AS upstream_network_id,
  CAST(-1 AS BIGINT) AS upstream_network_inbound_order_id,
  'na' AS upstream_network_inbound_order_type,
  'na' AS upstream_network_inbound_order_priority,
  'na' AS upstream_network_inbound_order_priority_tier,
  -1 AS upstream_network_inbound_order_priority_value,
  'na' AS upstream_network_supply_source_type,
  CAST(-1 AS BIGINT) AS external_network_id,
  -1 AS slot_ad_unit_id,
  -1 AS slot_sequence,
  COALESCE(auction__time_position_class, 'na') AS time_position_class,
  'na' AS slot_placed_status,
  'na' AS slot_fill_status,
  'programmatic' AS sales_channel,
  'na' AS node_type,
  CAST(-1 AS BIGINT) AS placement_id,
  CAST(-1 AS BIGINT) AS ad_id,
  CAST(-1 AS BIGINT) AS local_advertiser_id,
  ARRAY[] AS global_advertiser_ids,
  ARRAY[] AS global_brand_ids,
  ARRAY[] AS global_industry_ids,
  'na' AS ad_priority_type,
  'na' AS ad_priority_tier,
  CAST(-1 AS BIGINT) AS ad_priority_value,
  COALESCE(err.id, 0) AS error_code,
  COALESCE(err.display_name, 'na') AS error_display_name,
  -1 AS outbound_order_id,
  -1 AS buyer_network_id,
  'na' AS outbound_order_type,
  'na' AS outbound_order_priority,
  'na' AS outbound_order_priority_tier,
  -1 AS outbound_order_priority_value,
  COALESCE(deal_id, -1) AS internal_deal_id,
  COALESCE(auction__buyer_group_id, -1) AS buyer_group_id,
  CASE WHEN COALESCE(deal_id, -1) > 0 THEN 'deal' ELSE 'buyer group' END AS demand_type,
  CASE
    WHEN COALESCE(deal_id, -1) > 0
    THEN deal_id
    ELSE COALESCE(auction__buyer_group_id, -1)
  END AS demand_id,
  COALESCE(deal.priority_bucket, 'na') AS demand_priority_type,
  CAST(-1 AS BIGINT) AS demand_priority_value,
  COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  0 AS ad_error_frequency,
  0 AS targeted_ads,
  0 AS flattened_ads,
  0 AS available_ads,
  0 AS eligible_ads,
  0 AS distinct_selected_ads,
  0 AS distinct_filled_ads,
  0 AS plc_error_frequency,
  0 AS targeted_plcs,
  0 AS flattened_plcs,
  0 AS ad_in_slot_error_frequency,
  0 AS eligible_ads_in_slot,
  0 AS ad_filled_ads,
  0 AS ad_raw_selected_ad,
  0 AS ad_raw_selected_ad_primary,
  0 AS ad_raw_selected_ad_primary_sstf_failed,
  0 AS ad_sstf_failed_has_fallback,
  0 AS ad_sstf_failed_no_fallback,
  0 AS order_error_frequency,
  0 AS targeted_orders,
  0 AS candidated_orders,
  0 AS executed_orders,
  0 AS inbound_order_opportunity,
  0 AS ad_selected_ad_primary,
  0 AS ad_selected_ad_fallback,
  0 AS upstream_network_order_opportunity,
  0 AS outbound_order_opportunity,
  0 AS ad_selected_ad,
  0 AS slot_opportunity,
  0 AS distinct_inventory_avails,
  0 AS deal_opportunity,
  0 AS demand_opportunity,
  SUM(
    1 * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
  ) AS tx_candidates,
  SUM(
    IF(BITWISE_AND(auction__auction_status, 8) > 0, 1, 0) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
  ) AS tx_eligibles,
  0 AS slot_eligibles,
  0 AS slot_placed_ads,
  0 AS selected_ads_sampled,
  0 AS impression,
  0 AS tx_error_frequency,
  0 AS slot_error_frequency,
  0 AS sstf_err_frequency
FROM ${bcv_auction}
CROSS JOIN UNNEST(partners__network_id, partners__supply_source, partners__sales_channel, partners__entity_source, partners__internal_deal_ids, partners__deal_awareability, partners__inbound_order_id, partners__inbound_order_type, partners__content_owner_network_id, partners__distributor_network_id, partners__site_id, partners__site_section_id, partners__series_id) AS nw(nw_id, supply_source, sales_channel, entity_source, deal_ids, deal_awareability, inbound_order_id, inbound_order_type, co_id, distributor_id, site_id, site_section_id, series_id)
CROSS JOIN UNNEST(nw.deal_ids) AS deal(deal_id)
LEFT JOIN db.default.d_mkpl_order AS inbound_order
  ON inbound_order.id = inbound_order_id
LEFT JOIN db.default.d_ssp_deal AS deal
  ON deal.id = COALESCE(deal_id, -1)
LEFT JOIN oltp.fwmrm_oltp.lu_mkpl_selection_error AS err
  ON COALESCE(auction__error, 'na') = err.error_code
WHERE
  (
    (
      (
        auction__is_faked_auction = FALSE
        AND auction__integration_type IN ('normal', 'pg_td')
      )
      AND nw.entity_source IN ('auction')
    )
    AND nw.sales_channel = 4
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
  59,
  60,
  61,
  62
UNION ALL
SELECT
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  IF(
    BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
    -3,
    COALESCE(nw.distributor_id, -1)
  ) AS distributor_network_id,
  IF(
    BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
    -3,
    COALESCE(request__context__profile_id, -1)
  ) AS profile_id,
  COALESCE(request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
  COALESCE(request__context__standard_endpoint_owner_id, -1) AS standard_endpoint_owner_id,
  COALESCE(request__context__standard_brand_id, -1) AS standard_brand_id,
  COALESCE(request__context__standard_programmer_id, -1) AS standard_programmer_id,
  COALESCE(request__context__content_form_id, -1) AS content_form_id,
  COALESCE(request__context__stream_mode_id, -1) AS stream_mode_id,
  COALESCE(request__context__standard_publisher_id, -1) AS standard_publisher_id,
  COALESCE(visitor__country_id, -1) AS country_id,
  COALESCE(request__cbp__slot_template_id, -1) AS cbp_id,
  'false' AS request_is_filtered,
  COALESCE(nw.site_section_id, -1) AS site_section_id,
  COALESCE(nw.series_id, -1) AS video_series_id,
  COALESCE(nw.nw_id, -1) AS network_id,
  COALESCE(inbound_order_id, -1) AS inbound_order_id,
  COALESCE(inbound_order_type, 'not applicable') AS inbound_order_type,
  'na' AS inbound_order_priority,
  'na' AS inbound_order_priority_tier,
  COALESCE(inbound_order.priority_value, -1) AS inbound_order_priority_value,
  CASE
    WHEN supply_source = 1
    THEN 'o&o'
    WHEN supply_source = 3
    THEN 'mrm2mrm'
    WHEN supply_source = 4
    THEN 'programmatic'
    WHEN supply_source = 5 AND COALESCE(inbound_order_type, 'na') = 'carriage_order'
    THEN 'inventory split'
    WHEN supply_source = 5
    AND COALESCE(inbound_order_type, 'na') = 'marketplace_order'
    AND COALESCE(inbound_order.transaction_type, 'na') = 'guaranteed'
    THEN 'mpp guaranteed'
    WHEN supply_source = 5
    THEN 'mpp non-guaranteed'
    WHEN supply_source = 6
    THEN 'mpe'
    ELSE 'unknown'
  END AS supply_source_detail,
  COALESCE(co_id, -1) AS upstream_network_id,
  CAST(-1 AS BIGINT) AS upstream_network_inbound_order_id,
  'na' AS upstream_network_inbound_order_type,
  'na' AS upstream_network_inbound_order_priority,
  'na' AS upstream_network_inbound_order_priority_tier,
  -1 AS upstream_network_inbound_order_priority_value,
  'na' AS upstream_network_supply_source_type,
  CAST(-1 AS BIGINT) AS external_network_id,
  -1 AS slot_ad_unit_id,
  -1 AS slot_sequence,
  'na' AS time_position_class,
  'na' AS slot_placed_status,
  'na' AS slot_fill_status,
  'programmatic' AS sales_channel,
  'na' AS node_type,
  CAST(-1 AS BIGINT) AS placement_id,
  CAST(-1 AS BIGINT) AS ad_id,
  CAST(-1 AS BIGINT) AS local_advertiser_id,
  ARRAY[] AS global_advertiser_ids,
  ARRAY[] AS global_brand_ids,
  ARRAY[] AS global_industry_ids,
  'na' AS ad_priority_type,
  'na' AS ad_priority_tier,
  CAST(-1 AS BIGINT) AS ad_priority_value,
  COALESCE(err.id, 0) AS error_code,
  CASE
    WHEN COALESCE(advertisement__slot_index, -1) > -1
    THEN COALESCE(candidate__error, 'na')
    ELSE COALESCE(err.display_name, 'na')
  END AS error_display_name,
  -1 AS outbound_order_id,
  -1 AS buyer_network_id,
  'na' AS outbound_order_type,
  'na' AS outbound_order_priority,
  'na' AS outbound_order_priority_tier,
  -1 AS outbound_order_priority_value,
  COALESCE(candidate__internal_deal_id, -1) AS internal_deal_id,
  COALESCE(candidate__buyer_group_id, -1) AS buyer_group_id,
  CASE
    WHEN COALESCE(candidate__internal_deal_id, -1) > 0
    THEN 'deal'
    ELSE 'buyer group'
  END AS demand_type,
  CASE
    WHEN COALESCE(candidate__internal_deal_id, -1) > 0
    THEN candidate__internal_deal_id
    ELSE COALESCE(candidate__buyer_group_id, -1)
  END AS demand_id,
  COALESCE(deal.priority_bucket, 'na') AS demand_priority_type,
  CAST(-1 AS BIGINT) AS demand_priority_value,
  COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_id,
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  0 AS ad_error_frequency,
  0 AS targeted_ads,
  0 AS flattened_ads,
  0 AS available_ads,
  0 AS eligible_ads,
  0 AS distinct_selected_ads,
  0 AS distinct_filled_ads,
  0 AS plc_error_frequency,
  0 AS targeted_plcs,
  0 AS flattened_plcs,
  0 AS ad_in_slot_error_frequency,
  0 AS eligible_ads_in_slot,
  0 AS ad_filled_ads,
  0 AS ad_raw_selected_ad,
  0 AS ad_raw_selected_ad_primary,
  0 AS ad_raw_selected_ad_primary_sstf_failed,
  0 AS ad_sstf_failed_has_fallback,
  0 AS ad_sstf_failed_no_fallback,
  0 AS order_error_frequency,
  0 AS targeted_orders,
  0 AS candidated_orders,
  0 AS executed_orders,
  0 AS inbound_order_opportunity,
  0 AS ad_selected_ad_primary,
  0 AS ad_selected_ad_fallback,
  0 AS upstream_network_order_opportunity,
  0 AS outbound_order_opportunity,
  0 AS ad_selected_ad,
  0 AS slot_opportunity,
  0 AS distinct_inventory_avails,
  0 AS deal_opportunity,
  0 AS demand_opportunity,
  0 AS tx_candidates,
  0 AS tx_eligibles,
  SUM(
    IF(BITWISE_AND(candidate__bid_status, 1) > 0, 1, 0) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(request__demand_log_magnifier, 1)
  ) AS slot_eligibles,
  SUM(
    IF(
      BITWISE_AND(candidate__bid_status, 4) > 0
      AND COALESCE(advertisement__slot_index, -1) > -1,
      1,
      0
    ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(request__demand_log_magnifier, 1)
  ) AS slot_placed_ads,
  SUM(
    IF(
      BITWISE_AND(candidate__bid_status, 8) > 0
      AND COALESCE(advertisement__slot_index, -1) > -1,
      1,
      0
    ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(request__demand_log_magnifier, 1)
  ) AS selected_ads_sampled,
  0 AS impression,
  0 AS tx_error_frequency,
  SUM(
    IF(BITWISE_AND(candidate__bid_status, 4) = 0, 1, 0) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(request__demand_log_magnifier, 1)
  ) AS slot_error_frequency,
  SUM(
    IF(
      BITWISE_AND(candidate__bid_status, 4) > 0
      AND BITWISE_AND(candidate__bid_status, 8) = 0,
      1,
      0
    ) * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(request__demand_log_magnifier, 1)
  ) AS sstf_err_frequency
FROM ${bcv_candidate} AS c
CROSS JOIN UNNEST(partners__network_id, partners__supply_source, partners__sales_channel, partners__entity_source, partners__inbound_order_id, partners__inbound_order_type, partners__content_owner_network_id, partners__distributor_network_id, partners__site_id, partners__site_section_id, partners__series_id) AS nw(nw_id, supply_source, sales_channel, entity_source, inbound_order_id, inbound_order_type, co_id, distributor_id, site_id, site_section_id, series_id)
CROSS JOIN UNNEST(CONCAT(
  candidate__filter_reason__slot_index,
  ARRAY[COALESCE(advertisement__slot_index, -1)]
), CONCAT(candidate__filter_reason__error, ARRAY['no_error'])) AS e(slot_index, error)
LEFT JOIN db.default.d_mkpl_order AS inbound_order
  ON inbound_order.id = inbound_order_id
LEFT JOIN db.default.d_ssp_deal AS deal
  ON deal.id = COALESCE(candidate__internal_deal_id, -1)
LEFT JOIN oltp.fwmrm_oltp.lu_mkpl_selection_error AS err
  ON (
    CASE
      WHEN COALESCE(advertisement__slot_index, -1) > -1
      THEN COALESCE(candidate__error, 'na')
      ELSE COALESCE(e.error, 'na')
    END
  ) = err.error_code
WHERE
  (
    (
      (
        (
          (
            auction__integration_type IN ('normal', 'pg_td') AND nw.supply_source <> 4
          )
          AND COALESCE(advertisement__is_bumper, FALSE) = FALSE
        )
        AND nw.sales_channel = 4
      )
      AND (
        c.request__delivery_method IS NULL OR c.request__delivery_method <> 'casucpsu'
      )
    )
    AND COALESCE(e.slot_index, -1) > -1
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
  59,
  60,
  61,
  62
