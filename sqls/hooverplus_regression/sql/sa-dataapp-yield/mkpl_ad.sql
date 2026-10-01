-- account:    sa-dataapp-yield
-- skeleton:   b893b627884f8092d0b3f1ddf3261263
-- pattern:    031e3e354db2365fcd6cfc59186bdd93  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     ad
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
  COALESCE(candidate__dsp_id, -1) AS dsp_id,
  COALESCE(dsp.name, 'na') AS dsp_name,
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
  COALESCE(advertisement__placement_id, -1) AS placement_id,
  COALESCE(candidate__internal_deal_id, -1) AS deal_id,
  COALESCE(d_ssp_deal_metadata.external_id, 'na') AS public_deal_id,
  COUNT(1) AS ad_delivered_ad,
  SUM(IF(BITWISE_AND(advertisement__flags, 32) = 0, 1, 0)) AS ad_delivered_ad_primary,
  SUM(IF(BITWISE_AND(advertisement__flags, 32) > 0, 1, 0)) AS ad_delivered_ad_fallback,
  SUM(
    IF(
      advertisement__is_undeliverable = FALSE
      AND BITWISE_AND(advertisement__flags, 32) = 0,
      1,
      0
    )
  ) AS ad_selected_ad_primary,
  SUM(
    IF(
      advertisement__is_undeliverable = FALSE
      AND BITWISE_AND(advertisement__flags, 32) > 0,
      1,
      0
    )
  ) AS ad_selected_ad_fallback,
  SUM(IF(BITWISE_AND(advertisement__extra_flags2, 32) > 0, 1, 0)) AS ad_delivered_vast_tag_with_multiple_ad,
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
  SUM(
    IF(
      BITWISE_AND(advertisement__extra_flags, 16777216) = 0
      AND BITWISE_AND(advertisement__flags, 33554432) > 0,
      advertisement__duration,
      0
    )
  ) AS ad_duration_fallback_ad_of_sstf_ad,
  SUM(
    IF(
      advertisement__is_undeliverable = FALSE
      AND (
        BITWISE_AND(advertisement__flags, 33554432) > 0
        OR advertisement__is_fallback = FALSE
      ),
      1,
      0
    )
  ) AS ad_filled_ads
FROM ${bcv_ad}
CROSS JOIN UNNEST(partners__network_id, partners__role, partners__bit_flags, partners__content_owner_network_id, partners__supply_source, partners__inbound_order_id, partners__inbound_order_type, partners__inbound_listing_id, partners__content_owner_bidding_revenue, partners__network_is_ad_owner) AS t(network_id, network_role, bit_flag, content_owner_network_id, supply_source, inbound_order_id, order_type, listing_id, content_owner_bidding_revenue, is_ad_owner)
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
LEFT JOIN db.default.d_ssp_demand_side_platform AS dsp
  ON dsp.id = candidate__dsp_id
LEFT JOIN db.default.d_mkpl_order AS orders
  ON orders.id = inbound_order_id
LEFT JOIN db.default.d_ssp_deal_metadata AS d_ssp_deal_metadata
  ON d_ssp_deal_metadata.id = COALESCE(candidate__internal_deal_id, -1)
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
  42,
  43,
  44,
  45,
  46,
  47
