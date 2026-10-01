-- account:    sa-dataapp-yield
-- skeleton:   bf85fe07ebe9e85f65106a712163e72b
-- pattern:    408d57bc391e28642f42b8113ae19b0c  (611 execution(s))
-- in suite:   daily commitment
-- hoover:     slot
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH base AS (
  SELECT
    request__timestamp,
    request__context__video_cro_network_id,
    request__context__network_id,
    request__context__profile_id,
    request__context__request_format,
    request__context__site_section_id,
    request__context__standard_programmer_id,
    request__context__standard_brand_id,
    request__context__standard_channel_id,
    request__context__standard_endpoint_id,
    request__context__standard_endpoint_owner_id,
    request__context__standard_language_ids,
    request__context__standard_app_bundle_id,
    request__context__standard_iab_category_ids,
    request__context__standard_genre_ids,
    request__flags,
    request__extra_flags,
    request__extra_flags2,
    request__extra_flags3,
    request__delivery_method,
    request__server_group,
    request__server_pool,
    visitor__country_id,
    visitor__user_agent_device_type,
    visitor__standard_device_type_child_id,
    visitor__standard_environment_id,
    visitor__standard_os_id,
    slot__time_position_class,
    slot__num_ads,
    slot__unfilled_avails,
    slot__max_ads,
    slot__max_duration,
    request__log_sampling__magnifier,
    partners__content_owner_network_id,
    partners__network_id,
    partners__role,
    partners__supply_source,
    partners__inbound_order_id,
    partners__avails_category__distinct_inventory_avails
  FROM ${bcv_slot}
  WHERE
    BITWISE_AND(request__extra_flags, 1024) = 0
    AND (
      request__delivery_method IS NULL
      OR NOT request__delivery_method IN ('casucpsu', 'gateway')
    )
)
SELECT
  tmp.*,
  COALESCE(cro_nw.name, 'na') AS video_cro_network_name,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(ctry.description, 'na') AS country_name,
  COALESCE(section.name, 'na') AS site_section_name,
  COALESCE(programmer.name, 'na') AS standard_programmer_name,
  COALESCE(brand.name, 'na') AS standard_brand_name,
  COALESCE(channel.name, 'na') AS standard_channel_name,
  COALESCE(sub_device_type.name, 'na') AS standard_device_type_child_name,
  COALESCE(environment.name, 'na') AS standard_environment_name,
  COALESCE(os.name, 'na') AS standard_os_name,
  COALESCE(endpoint.name, 'na') AS standard_endpoint_name,
  COALESCE(endpoint_owner.name, 'na') AS standard_endpoint_owner_name,
  COALESCE(network.name, 'na') AS network_name,
  COALESCE(content_owner_network.name, 'na') AS content_owner_network_name,
  CASE
    WHEN tmp.supply_source_tmp = 1
    THEN 'o&o'
    WHEN tmp.supply_source_tmp = 3 AND network.network_type = 'full'
    THEN 'mrm2mrm'
    WHEN tmp.supply_source_tmp = 3 AND network.network_type = 'internal'
    THEN 'reseller tag'
    WHEN tmp.supply_source_tmp = 4
    THEN 'programmatic'
    WHEN tmp.supply_source_tmp = 5
    THEN 'partner trading(mpp)'
    WHEN tmp.supply_source_tmp = 6
    THEN 'marketplace platform exchange(mpe)'
    ELSE 'unkown supply source'
  END AS supply_source
FROM (
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(request__context__network_id, -1) AS distributor_network_id,
    COALESCE(request__context__profile_id, -1) AS profile_id,
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
    CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
    CASE
      WHEN BITWISE_AND(request__extra_flags2, 2097152) > 0
      THEN 'true'
      ELSE 'false'
    END AS is_dynamic_pod_request,
    CASE
      WHEN BITWISE_AND(request__extra_flags2, 33554432) > 0
      THEN 'true'
      ELSE 'false'
    END AS is_ortb_multi_imp_request,
    CASE WHEN BITWISE_AND(request__extra_flags2, 32768) > 0 THEN 'true' ELSE 'false' END AS is_net_price_enabled,
    CASE
      WHEN BITWISE_AND(request__extra_flags2, 536870912) > 0
      THEN 'true'
      ELSE 'false'
    END AS is_prebid_js_request,
    CASE
      WHEN BITWISE_AND(request__extra_flags2, 1073741824) > 0
      THEN 'true'
      ELSE 'false'
    END AS is_prebid_server_request,
    CASE WHEN BITWISE_AND(request__extra_flags3, 256) > 0 THEN 'true' ELSE 'false' END AS is_ortb_multi_bid_applied,
    CASE
      WHEN BITWISE_AND(request__extra_flags3, 64) > 0
      THEN 'dynamic pod'
      WHEN BITWISE_AND(request__extra_flags3, 128) > 0
      THEN 'multi imp'
      ELSE 'others'
    END AS ortb_applied_mode,
    COALESCE(request__server_group, 'na') AS server_group,
    COALESCE(request__server_pool, 'na') AS server_pool,
    COALESCE(visitor__country_id, -1) AS country_id,
    COALESCE(request__context__site_section_id, -1) AS site_section_id,
    COALESCE(request__context__standard_programmer_id, -1) AS standard_programmer_id,
    COALESCE(request__context__standard_brand_id, -1) AS standard_brand_id,
    COALESCE(request__context__standard_channel_id, -1) AS standard_channel_id,
    COALESCE(visitor__standard_device_type_child_id, -1) AS standard_device_type_child_id,
    COALESCE(visitor__standard_environment_id, -1) AS standard_environment_id,
    COALESCE(visitor__standard_os_id, -1) AS standard_os_id,
    COALESCE(request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
    COALESCE(request__context__standard_endpoint_owner_id, -1) AS standard_endpoint_owner_id,
    COALESCE(NULLIF(request__context__standard_language_ids, ARRAY[]), ARRAY[-1]) AS standard_language_ids,
    COALESCE(request__context__standard_app_bundle_id, -1) AS standard_app_bundle_id,
    COALESCE(NULLIF(request__context__standard_iab_category_ids, ARRAY[]), ARRAY[-1]) AS standard_iab_category_ids,
    COALESCE(NULLIF(request__context__standard_genre_ids, ARRAY[]), ARRAY[-1]) AS standard_genre_ids,
    COALESCE(slot__time_position_class, 'na') AS time_position_class,
    COALESCE(partner.content_owner_network_id, -1) AS content_owner_network_id,
    COALESCE(partner.network_id, -1) AS network_id,
    COALESCE(partner.role, 'na') AS role,
    COALESCE(partner.supply_source, -1) AS supply_source_tmp,
    COALESCE(partner.inbound_order_id, -1) AS inbound_order_id,
    SUM(IF(role = 'cro', COALESCE(request__log_sampling__magnifier, 1), 0)) AS slots,
    SUM(
      IF(
        role = 'cro',
        (
          COALESCE(slot__num_ads, 0) + COALESCE(slot__unfilled_avails, COALESCE(slot__max_ads, 0) - COALESCE(slot__num_ads, 0))
        ) * COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS slot_avails,
    SUM(
      IF(
        role = 'cro',
        COALESCE(
          slot__unfilled_avails,
          IF(
            NOT COALESCE(slot__time_position_class, 'unknown') IN ('display', 'in-player-display'),
            COALESCE(slot__max_ads, 0) - COALESCE(slot__num_ads, 0),
            0
          )
        ) * COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS slot_unfilled_avails,
    SUM(
      IF(
        role = 'cro',
        CAST(COALESCE(slot__max_duration, 0) AS BIGINT) * COALESCE(request__log_sampling__magnifier, 1),
        0
      )
    ) AS slot_max_duration,
    SUM(COALESCE(partner.distinct_inventory_avails, 0)) AS distinct_inventory_avails
  FROM base
  CROSS JOIN UNNEST(partners__content_owner_network_id, partners__network_id, partners__role, partners__supply_source, partners__inbound_order_id, partners__avails_category__distinct_inventory_avails) AS partner(content_owner_network_id, network_id, role, supply_source, inbound_order_id, distinct_inventory_avails)
  WHERE
    role IN ('cro', 'r') AND supply_source <> 4
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
    35
) AS tmp
LEFT JOIN db.default.d_network AS cro_nw
  ON cro_nw.id = video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = distributor_network_id
LEFT JOIN db.default.d_network AS network
  ON network.id = network_id
LEFT JOIN db.default.d_network AS content_owner_network
  ON content_owner_network.id = content_owner_network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = profile_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = country_id
LEFT JOIN db.default.d_site_section AS section
  ON section.id = site_section_id
LEFT JOIN db.default.d_lu_mkpl_standard_programmer AS programmer
  ON programmer.id = standard_programmer_id
LEFT JOIN db.default.d_lu_mkpl_standard_brand AS brand
  ON brand.id = standard_brand_id
LEFT JOIN db.default.d_lu_mkpl_standard_channel AS channel
  ON channel.id = standard_channel_id
LEFT JOIN db.default.d_lu_mkpl_standard_sub_device_type AS sub_device_type
  ON sub_device_type.id = standard_device_type_child_id
LEFT JOIN db.default.d_lu_mkpl_standard_environment AS environment
  ON environment.id = standard_environment_id
LEFT JOIN db.default.d_lu_mkpl_standard_os AS os
  ON os.id = standard_os_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS endpoint
  ON endpoint.id = standard_endpoint_id
LEFT JOIN db.default.d_lu_mkpl_endpoint_owner AS endpoint_owner
  ON endpoint_owner.id = standard_endpoint_owner_id
