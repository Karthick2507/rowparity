-- account:    sa-dataapp-yield
-- skeleton:   019d91c118779f9a63a077226fcd7459
-- pattern:    bad8b59555abdd01a48b89809e324275  (695 execution(s))
-- in suite:   daily commitment
-- hoover:     ad
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH rule_map AS (
  SELECT
    MAP_AGG(id, rule_id) AS rule_application_map
  FROM db.default.d_mrm_access_rule
)
SELECT
  tmp.*,
  COALESCE(cro.name, 'na') AS video_cro_network_name,
  COALESCE(dis.name, 'na') AS distributor_network_name,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(ctry.description, 'unknown country') AS country_name,
  COALESCE(eo.name, 'unknown endpoint owner') AS endpoint_owner_name,
  COALESCE(ep.name, 'unknown endpoint') AS endpoint_name,
  COALESCE(network.name, 'na') AS network_name,
  COALESCE(ssp.name, reseller.name) AS reseller_name,
  CASE
    WHEN tmp_sales_channel = 2
    THEN 'direct sold'
    WHEN tmp_sales_channel = 3 AND reseller.network_type = 'full'
    THEN 'mrm2mrm'
    WHEN tmp_sales_channel = 3 AND reseller.network_type = 'internal'
    THEN 'reseller tag'
    WHEN tmp_sales_channel = 4
    THEN 'programmatic'
    WHEN tmp_sales_channel = 5 AND is_reseller_tag
    THEN 'partner tag'
    WHEN tmp_sales_channel = 5
    THEN 'partner trading(mpp)'
    WHEN tmp_sales_channel = 6
    THEN 'marketplace platform exchange(mpe)'
    ELSE 'na'
  END AS sales_channel,
  'slot' AS data_perspective,
  COALESCE(site.site_name, 'na') AS distributor_site_name,
  COALESCE(env.name, 'na') AS environment_name,
  COALESCE(os.name, 'na') AS os_name,
  COALESCE(device_type.name, 'na') AS device_type_child_name,
  COALESCE(co.name, 'na') AS content_owner_network_name,
  CASE
    WHEN tmp_supply_source = 1
    THEN 'o&o'
    WHEN tmp_supply_source = 3 AND network.network_type = 'full'
    THEN 'mrm2mrm'
    WHEN tmp_supply_source = 3 AND network.network_type = 'internal'
    THEN 'reseller tag'
    WHEN tmp_supply_source = 4
    THEN 'programmatic'
    WHEN tmp_supply_source = 5
    THEN 'partner trading(mpp)'
    WHEN tmp_supply_source = 6
    THEN 'marketplace platform exchange(mpe)'
    ELSE 'unkown supply source'
  END AS supply_source,
  COALESCE(imr.upstream_mrm_rule_id, -1) AS in_rule_id,
  COALESCE(ELEMENT_AT(rule_application_map, outbound_rule_id), -1) AS out_rule_id,
  COALESCE(d_ssp_deal_metadata.name, 'na') AS deal_name,
  COALESCE(d_ssp_deal_metadata.external_id, 'na') AS public_deal_id,
  COALESCE(d_ssp_deal_metadata.type, 'na') AS deal_priority_type,
  COALESCE(d_ssp_deal_metadata.priority_bucket, 'na') AS deal_priority_bucket,
  COALESCE(d_ssp_deal_metadata.override, 'na') AS deal_override_priority,
  COALESCE(mo.priority_type, 'na') AS deal_maped_order_priority,
  COALESCE(mo.priority_value, 0) AS deal_priority_value,
  COALESCE(in_order.priority_type, 'na') AS inbound_order_priority_type,
  COALESCE(in_order.priority_value, 0) AS inbound_order_priority_value,
  COALESCE(in_order.freewheel_clearing, 0) AS inbound_order_freewheel_clearing,
  COALESCE(in_order.transaction_type, 'na') AS inbound_order_transaction_type,
  COALESCE(in_order.order_type, 'na') AS inbound_order_type,
  COALESCE(in_order.internal_module, 'na') AS inbound_internal_module,
  COALESCE(out_order.priority_type, 'na') AS outbound_order_priority_type,
  COALESCE(out_order.priority_value, 0) AS outbound_order_priority_value,
  COALESCE(out_order.freewheel_clearing, 0) AS outbound_order_freewheel_clearing,
  COALESCE(out_order.transaction_type, 'na') AS outbound_order_transaction_type,
  COALESCE(out_order.order_type, 'na') AS outbound_order_type,
  COALESCE(out_order.internal_module, 'na') AS outbound_internal_module,
  COALESCE(in_rule.priority_setting, 'na') AS inbound_rule_priority_type,
  COALESCE(out_rule.priority_setting, 'na') AS outbound_rule_priority_type,
  COALESCE(listing.transaction_type, 'na') AS inbound_listing_transaction_type,
  COALESCE(listing.priority, 'na') AS inbound_listing_priority,
  COALESCE(listing.price_mode, 'na') AS inbound_listing_price_mode,
  COALESCE(listing.price, 0) AS inbound_listing_price
FROM (
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(request__context__network_id, -1) AS distributor_network_id,
    COALESCE(request__context__profile_id, -1) AS profile_id,
    CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
    COALESCE(visitor__country_id, -1) AS country_id,
    COALESCE(request__context__standard_endpoint_owner_id, -1) AS endpoint_owner_id,
    COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
    COALESCE(t.seller_network_id, -1) AS network_id,
    COALESCE(t.buyer_network_id, -1) AS reseller_id,
    sales_channel AS tmp_sales_channel,
    COALESCE(t.network_role, 'na') AS network_role,
    COALESCE(request__context__site_section_cro_site_id, -1) AS distributor_site_id,
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
    COALESCE(
      IF(
        (
          request__context__response_format = 18 OR request__context__request_format = 3
        )
        AND BITWISE_AND(request__extra_flags, 1024) = 0,
        SPLIT_PART(request__context__custom_asset_id, '/', 2),
        'na'
      ),
      'na'
    ) AS stb_vod_provider_name,
    CASE
      WHEN (
        request__context__response_format = 18 OR request__context__request_format = 3
      )
      THEN 'true'
      ELSE 'false'
    END AS is_scte_130,
    COALESCE(visitor__standard_environment_id, -1) AS environment_id,
    COALESCE(visitor__standard_os_id, -1) AS os_id,
    COALESCE(visitor__standard_device_type_child_id, -1) AS device_type_child_id,
    CASE
      WHEN (
        request__context__response_format = 18 OR request__context__request_format = 3
      )
      AND BITWISE_AND(request__extra_flags, 1024) = 0
      AND advertisement__is_owned_by_cro
      THEN 'local'
      WHEN (
        request__context__response_format = 18 OR request__context__request_format = 3
      )
      AND BITWISE_AND(request__extra_flags, 1024) = 0
      THEN 'national'
      ELSE 'na'
    END AS opportunity_type,
    CASE
      WHEN candidate__integration_type = 'openrtb_pg_td'
      THEN 'fullstack_pg'
      WHEN candidate__integration_type = 'openrtb_normal'
      THEN 'fullstack_non_pg'
      WHEN candidate__integration_type = 'openrtb_sfx'
      THEN 'sfx_openrtb'
      WHEN candidate__integration_type = 'reseller_tag'
      AND advertisement__external_reseller__network_id = 127719
      THEN 'sfx_tag'
      WHEN candidate__integration_type = 'reseller_tag'
      THEN 'ssp_others'
      WHEN NOT advertisement__external_reseller__network_id IS NULL
      AND BITWISE_AND(advertisement__inventory_protection_flags, 8) > 0
      THEN 'reseller_tag_sstf'
      WHEN NOT advertisement__external_reseller__network_id IS NULL
      THEN 'reseller_tag_non_sstf'
      WHEN advertisement__external_reseller__network_id IS NULL
      AND BITWISE_AND(advertisement__inventory_protection_flags, 8) > 0
      THEN 'direct_sold_sstf'
      ELSE 'direct_sold_non_sstf'
    END AS ad_delivery_type,
    COALESCE(t.content_owner_network_id, -1) AS content_owner_network_id,
    supply_source AS tmp_supply_source,
    IF(
      COALESCE(outbound_order_id, -1) = -1,
      COALESCE(outbound_exchange_order_id, -1),
      COALESCE(outbound_order_id, -1)
    ) AS outbound_order_id,
    COALESCE(inbound_order_id, -1) AS inbound_order_id,
    COALESCE(inbound_rule_id, -1) AS inbound_rule_id,
    COALESCE(outbound_rule_id, -1) AS outbound_rule_id,
    COALESCE(candidate__internal_deal_id, -1) AS deal_id,
    IF(is_extra_item_owner, 'true', 'false') AS network_is_extra_item_owner,
    CASE
      WHEN plc.budget_model IN ('all_impression', 'sov', 'sop', 'soi')
      THEN 'sponsorship'
      WHEN plc.budget_model IN ('demographic_impression_target', 'demographic_currency_target')
      THEN 'rbp'
      WHEN plc.budget_model IN ('custom_event_target', 'custom_currency_target')
      THEN 'cpx'
      WHEN plc.budget_model = 'evergreen'
      THEN 'evergreen'
      WHEN plc.budget_model IN ('currency_target', 'impression_target')
      THEN 'standard'
      WHEN io.event_goal = -2
      THEN 'evergreen'
      WHEN NOT io.event_goal IS NULL OR NOT io.currency_goal IS NULL
      THEN 'standard'
      ELSE 'na'
    END AS plc_budget_model,
    COALESCE(plc.gurantee_mode, 'na') AS plc_guarantee_mode,
    COALESCE(plc.priority_type, 'na') AS plc_priority_type,
    COALESCE(plc.priority_value, 0) AS plc_priority_value,
    BITWISE_AND(bit_flag, BITWISE_SHIFT_LEFT(1, 40, 64)) > 0 AS is_reseller_tag,
    IF(CARDINALITY(inbound_listing_id) > 0, inbound_listing_id[1], -1) AS inbound_listing_id,
    COALESCE(advertisement__placement_id, -1) AS placement_id,
    COUNT(1) AS ad_delivered_ad,
    SUM(IF(BITWISE_AND(advertisement__flags, 32) = 0, 1, 0)) AS ad_delivered_ad_primary,
    SUM(IF(BITWISE_AND(advertisement__flags, 32) > 0, 1, 0)) AS ad_delivered_ad_fallback,
    SUM(IF(BITWISE_AND(advertisement__flags, 67108864) > 0, 1, 0)) AS ad_delivered_ad_sstf_failed_total,
    SUM(
      IF(
        BITWISE_AND(advertisement__flags, 67108864) > 0
        AND BITWISE_AND(advertisement__flags, 32) = 0,
        1,
        0
      )
    ) AS ad_primary_ad_sstf_failed,
    SUM(
      IF(
        BITWISE_AND(advertisement__flags, 67108864) > 0
        AND BITWISE_AND(advertisement__flags, 32) > 0,
        1,
        0
      )
    ) AS ad_fallback_ad_sstf_failed,
    SUM(
      IF(
        BITWISE_AND(advertisement__flags, 67108864) > 0
        AND BITWISE_AND(advertisement__flags, 512) > 0,
        1,
        0
      )
    ) AS ad_sstf_failed_has_fallback,
    SUM(
      IF(
        BITWISE_AND(advertisement__flags, 67108864) > 0
        AND BITWISE_AND(advertisement__flags, 512) = 0,
        1,
        0
      )
    ) AS ad_sstf_failed_no_fallback,
    SUM(
      IF(
        BITWISE_AND(advertisement__extra_flags, 16777216) = 0
        AND BITWISE_AND(advertisement__flags, 33554432) > 0,
        1,
        0
      )
    ) AS ad_fallback_ad_of_sstf_ad,
    SUM(IF(advertisement__is_undeliverable = FALSE, 1, 0)) AS ad_selected_ad,
    SUM(
      IF(
        BITWISE_AND(advertisement__flags, 32) = 0
        AND advertisement__is_undeliverable = FALSE,
        1,
        0
      )
    ) AS ad_selected_ad_primary,
    SUM(
      IF(
        BITWISE_AND(advertisement__flags, 32) > 0
        AND advertisement__is_undeliverable = FALSE,
        1,
        0
      )
    ) AS ad_selected_ad_fallback
  FROM ${bcv_ad}
  CROSS JOIN UNNEST(partners__network_id, partners__role, partners__reseller_network_id, partners__sales_channel, partners__bit_flags, partners__content_owner_network_id, partners__supply_source, partners__outbound_order_id, partners__outbound_exchange_order_id, partners__inbound_order_id, partners__inbound_rule_id, partners__rule_id, partners__network_is_extra_item_owner, partners__inbound_listing_id) AS t(seller_network_id, network_role, buyer_network_id, sales_channel, bit_flag, content_owner_network_id, supply_source, outbound_order_id, outbound_exchange_order_id, inbound_order_id, inbound_rule_id, outbound_rule_id, is_extra_item_owner, inbound_listing_id)
  LEFT JOIN db.default.d_placement AS plc
    ON plc.id = advertisement__placement_id
  LEFT JOIN db.default.d_io AS io
    ON io.ad_group_id = advertisement__io_id
  WHERE
    (
      (
        (
          request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
        )
        AND NOT slot__time_position_class IN ('display', 'in-player-display', '')
      )
      AND network_role IN ('cro', 'r')
    )
    AND supply_source <> 4
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
    36
) AS tmp
LEFT JOIN db.default.d_network AS cro
  ON cro.id = video_cro_network_id
LEFT JOIN db.default.d_network AS dis
  ON dis.id = distributor_network_id
LEFT JOIN db.default.d_network AS network
  ON network.id = network_id
LEFT JOIN db.default.d_network AS reseller
  ON reseller.id = reseller_id
LEFT JOIN db.default.d_network AS co
  ON co.id = content_owner_network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = profile_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = country_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS ep
  ON ep.id = endpoint_id
LEFT JOIN db.default.d_lu_mkpl_endpoint_owner AS eo
  ON eo.id = endpoint_owner_id
LEFT JOIN (
  SELECT
    site_id,
    site_name
  FROM db.default.d_site_section
  GROUP BY
    1,
    2
) AS site
  ON site.site_id = distributor_site_id
LEFT JOIN db.default.d_lu_mkpl_standard_environment AS env
  ON env.id = environment_id
LEFT JOIN db.default.d_lu_mkpl_standard_os AS os
  ON os.id = os_id
LEFT JOIN db.default.d_lu_mkpl_standard_device_type AS device_type
  ON device_type.id = device_type_child_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS ssp
  ON ssp.network_id = reseller_id
JOIN rule_map
  ON 1 = 1
LEFT JOIN db.default.d_inbound_mrm_rule AS imr
  ON imr.id = inbound_rule_id
LEFT JOIN db.default.d_mrm_access_rule AS in_rule
  ON in_rule.rule_id = imr.upstream_mrm_rule_id
LEFT JOIN db.default.d_mrm_access_rule AS out_rule
  ON out_rule.rule_id = COALESCE(ELEMENT_AT(rule_application_map, outbound_rule_id), -1)
LEFT JOIN db.default.d_ssp_deal_metadata AS d_ssp_deal_metadata
  ON tmp.deal_id = d_ssp_deal_metadata.id
LEFT JOIN db.default.d_deal_order_info AS d_deal_order_info
  ON d_deal_order_info.deal_id = tmp.deal_id
LEFT JOIN db.default.d_mkpl_order AS mo
  ON mo.id = d_deal_order_info.mkpl_order_id
LEFT JOIN db.default.d_mkpl_order AS in_order
  ON COALESCE(inbound_order_id, -1) = in_order.id
LEFT JOIN db.default.d_mkpl_order AS out_order
  ON outbound_order_id = out_order.id
LEFT JOIN db.default.d_mkpl_listing_allowed_business_rule AS listing
  ON inbound_listing_id = listing.listing_id
