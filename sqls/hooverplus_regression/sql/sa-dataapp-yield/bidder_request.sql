-- account:    sa-dataapp-yield
-- skeleton:   5a94c12db78caf05f6089b9f98538831
-- pattern:    1eaa6f7b2ab618d6f2711069fa52a470  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH language_map AS (
  SELECT
    MAP_AGG(id, name) AS language_map
  FROM db.default.d_lu_mkpl_standard_language
)
SELECT
  COALESCE(nw.name, 'na') AS ssp_shell_network_name,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(pub.name, 'na') AS publisher_name,
  COALESCE(app.name, 'na') AS app_name,
  COALESCE(ctry.name, 'na') AS country_name,
  COALESCE(device.name, 'na') AS device_type_name,
  TRANSFORM(language_ids, x -> COALESCE(ELEMENT_AT(language_map, x), 'na')) AS language_names,
  COALESCE(channel.name, 'na') AS ssp_channel_name,
  COALESCE(site_domain.name, 'na') AS site_domain_name,
  tmp.*
FROM (
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    COALESCE(request__context__video_cro_network_id, -1) AS ssp_shell_network_id,
    COALESCE(request__context__network_id, -1) AS distributor_network_id,
    CASE WHEN request__is_filtered THEN 'true' ELSE 'false' END AS is_filtered,
    COALESCE(request__global_currency_version, 'na') AS global_currency_version,
    COALESCE(request__context__standard_publisher_id, -1) AS publisher_id,
    COALESCE(request__context__standard_app_id, -1) AS app_id,
    COALESCE(request__context__standard_site_domain_id, -1) AS site_domain_id,
    COALESCE(request__context__standard_ssp_channel_id, -1) AS ssp_channel_id,
    COALESCE(visitor__country_id, -1) AS country_id,
    COALESCE(visitor__standard_device_type_child_id, -1) AS device_type_id,
    COALESCE(request__context__standard_language_ids, ARRAY[]) AS language_ids,
    COALESCE(request__context__response_format, -1) AS response_format,
    CASE
      WHEN CARDINALITY(
        FILTER(request__bid_request__impression__deal__public_id, x -> CARDINALITY(x) > 0)
      ) = 0
      THEN 'mpe'
      WHEN CARDINALITY(
        FILTER(request__bid_request__impression__deal__public_id, x -> CARDINALITY(x) > 0)
      ) > 0
      AND CONTAINS(request__bid_request__impression__private_auction, FALSE) = FALSE
      THEN 'mpp'
      ELSE 'overlap'
    END AS request_type,
    COALESCE(request__server_group, 'na') AS server_group,
    COALESCE(request__server_pool, 'na') AS server_pool,
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
    SUM(IF(BITWISE_AND(request__decision_info__value7 / 256, 255) > 0, 1, 0)) AS empty_advertiser_domain,
    COUNT(1) AS req_ad_request_logged,
    SUM(COALESCE(request__log_sampling__magnifier, 1)) AS req_ad_request,
    COALESCE(
      SUM(
        REDUCE(request__bid_request__impression__floor, 0, (s, x) -> s + COALESCE(x, 0), s -> s) * COALESCE(request__log_sampling__magnifier, 1)
      ),
      0
    ) AS ssp_floor_price
  FROM ${bcv_request} AS a
  WHERE
    (
      request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
    )
    AND BITWISE_AND(request__extra_flags2, 8) > 0
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
    17
) AS tmp
LEFT JOIN db.default.d_network AS nw
  ON nw.id = ssp_shell_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = distributor_network_id
LEFT JOIN db.default.d_lu_mkpl_standard_publisher AS pub
  ON pub.id = publisher_id
LEFT JOIN db.default.d_lu_mkpl_standard_app AS app
  ON app.id = app_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = country_id
LEFT JOIN db.default.d_lu_mkpl_standard_device_type AS device
  ON device.id = device_type_id
LEFT JOIN db.default.d_lu_mkpl_standard_channel AS channel
  ON channel.id = ssp_channel_id
LEFT JOIN oltp.fwmrm_oltp.lu_mkpl_standard_site_domain AS site_domain
  ON site_domain.id = site_domain_id
JOIN language_map
  ON 1 = 1
