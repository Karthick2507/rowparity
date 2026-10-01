-- account:    sa-dataapp-yield
-- skeleton:   1f21505275868c9185acd9a408e4c21a
-- pattern:    4d5f1b3fa2e84bad81c876c408178927  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     request
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
  CASE WHEN request__is_filtered THEN 'true' ELSE 'false' END AS is_filtered,
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
  COALESCE(visitor__user_agent_device_type, 'na') AS platform,
  COALESCE(request__server_group, 'na') AS server_group,
  COUNT(1) AS req_ad_request,
  SUM(IF(COALESCE(request__context__standard_brand_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_brand,
  SUM(IF(COALESCE(request__context__content_rating_id, -1) > 0, 1, 0)) AS req_ad_request_has_content_rating,
  SUM(IF(COALESCE(request__context__standard_channel_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_channel,
  SUM(IF(COALESCE(request__context__standard_programmer_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_programmer,
  SUM(IF(COALESCE(request__context__standard_endpoint_owner_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_endpoint_owner,
  SUM(IF(COALESCE(request__context__standard_endpoint_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_endpoint,
  SUM(IF(COALESCE(request__context__standard_content_daypart_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_daypart,
  SUM(IF(COALESCE(request__context__standard_content_series_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_series,
  SUM(IF(COALESCE(request__context__stream_mode_id, -1) > 0, 1, 0)) AS req_ad_request_has_stream_mode_id,
  SUM(IF(COALESCE(request__context__ip_enabled_audience_id, -1) > 0, 1, 0)) AS req_ad_request_has_ip_enabled_audience_id,
  SUM(IF(COALESCE(request__context__inventory_location_id, -1) > 0, 1, 0)) AS req_ad_request_has_inventory_location_id,
  SUM(IF(COALESCE(request__context__site_section_cro_asset_id, -1) > 0, 1, 0)) AS req_ad_request_has_site_section,
  SUM(IF(COALESCE(request__context__content_form_id, -1) > 0, 1, 0)) AS req_ad_request_has_content_form,
  SUM(
    IF(COALESCE(request__context__standard_content_subscription_model_id, -1) > 0, 1, 0)
  ) AS req_ad_request_has_subscription_model,
  SUM(
    IF(COALESCE(request__context__standard_content_credential_status_id, -1) > 0, 1, 0)
  ) AS req_ad_request_has_credential_status,
  SUM(IF(COALESCE(request__context__standard_publisher_id, -1) > 0, 1, 0)) AS req_ad_request_has_publisher,
  SUM(IF(COALESCE(request__context__standard_app_bundle_id, -1) > 0, 1, 0)) AS req_ad_request_has_app_bundle,
  SUM(IF(COALESCE(request__context__standard_app_id, -1) > 0, 1, 0)) AS req_ad_request_has_app,
  SUM(IF(COALESCE(request__context__standard_site_domain_id, -1) > 0, 1, 0)) AS req_ad_request_has_site_domain,
  SUM(IF(COALESCE(request__context__standard_ssp_channel_id, -1) > 0, 1, 0)) AS req_ad_request_has_ssp_channel,
  SUM(IF(COALESCE(request__context__standard_content_territory_id, -1) > 0, 1, 0)) AS req_ad_request_has_content_territory,
  SUM(IF(COALESCE(request__context__standard_privacy_id, -1) > 0, 1, 0)) AS req_ad_request_has_privacy,
  SUM(IF(COALESCE(visitor__standard_environment_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_enviorment,
  SUM(IF(COALESCE(visitor__standard_os_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_os,
  SUM(IF(COALESCE(visitor__standard_operator_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_operator,
  SUM(IF(COALESCE(visitor__standard_retailer_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_retailer,
  SUM(IF(COALESCE(visitor__standard_manufacturer_id, -1) > 0, 1, 0)) AS req_ad_request_has_standard_manufacturer,
  SUM(IF(COALESCE(visitor__country_id, -1) > 0, 1, 0)) AS req_ad_request_has_country,
  SUM(IF(COALESCE(visitor__dma_code_id, -1) > 0, 1, 0)) AS req_ad_request_has_dma,
  SUM(IF(COALESCE(visitor__city_id, -1) > 0, 1, 0)) AS req_ad_request_has_city,
  SUM(IF(COALESCE(visitor__postal_code, 'na') <> 'na', 1, 0)) AS req_ad_request_has_postal_code,
  SUM(IF(SUBSTR(COALESCE(visitor__user_agent, 'na'), 1, 128) <> 'na', 1, 0)) AS req_ad_request_has_user_agent,
  SUM(IF(SUBSTR(COALESCE(visitor__universal_hhid, 'na'), 1, 128) <> 'na', 1, 0)) AS req_ad_request_has_hhid,
  SUM(
    IF(CARDINALITY(COALESCE(request__context__standard_language_ids, ARRAY[])) > 0, 1, 0)
  ) AS req_ad_request_has_standard_language,
  SUM(
    IF(CARDINALITY(COALESCE(request__context__standard_genre_ids, ARRAY[])) > 0, 1, 0)
  ) AS req_ad_request_has_standard_genre,
  SUM(IF(CARDINALITY(COALESCE(visitor__standard_device_type_ids, ARRAY[])) > 0, 1, 0)) AS req_ad_request_has_standard_device,
  SUM(
    IF(
      CARDINALITY(COALESCE(request__context__standard_iab_category_ids, ARRAY[])) > 0,
      1,
      0
    )
  ) AS req_ad_request_has_standard_iab_category,
  SUM(
    IF(
      CARDINALITY(COALESCE(request__context__standard_addressability_ids, ARRAY[])) > 0,
      1,
      0
    )
  ) AS req_ad_request_has_standard_addressability,
  SUM(
    IF(
      CARDINALITY(COALESCE(request__context__standard_content_viewership_profile_ids, ARRAY[])) > 0,
      1,
      0
    )
  ) AS req_ad_request_has_content_viewership_profile
FROM ${bcv_request}
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  (
    request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
  )
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
  11
