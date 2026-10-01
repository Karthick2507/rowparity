-- account:    sa-dataapp-yield
-- skeleton:   f6552dd26bfd15ef79d5c53dd115f1f8
-- pattern:    e083eb6516e75a3ba645130003642ebc  (608 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?
--   request__timestamp < DATE_PARSE(?, ?) + INTERVAL ? HOUR
--   request__timestamp >= DATE_PARSE(?, ?)

SELECT
  timestamp,
  COALESCE(video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(distributor_network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  is_filtered,
  service_type,
  platform,
  server_group,
  server_pool,
  mrs_request_type,
  ad_unit_type,
  COALESCE(visitor__country, 'unknown country') AS country,
  COALESCE(ctry.description, 'unknown country') AS country_name,
  COALESCE(visitor__state, 'unknown state') AS state,
  COALESCE(st.description, 'unknown state') AS state_name,
  IF(visitor__country_id = 165, COALESCE(lud.code, -1), -1) AS dma,
  IF(visitor__country_id = 165, COALESCE(lud.description, 'unknown dma'), 'unknown dma') AS dma_name,
  SUM(ack_ad_duplicated_impression) AS ack_ad_duplicated_impression
FROM (
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    request__context__video_cro_network_id AS video_cro_network_id,
    request__context__network_id AS distributor_network_id,
    request__context__profile_id,
    CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
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
    COALESCE(request__server_pool, 'na') AS server_pool,
    CASE
      WHEN BITWISE_AND(request__extra_flags2, 4194304) > 0
      THEN 'mrs_1st_request'
      WHEN BITWISE_AND(request__extra_flags2, 8388608) > 0
      THEN 'mrs_2nd_request'
      ELSE 'non_mrs_request'
    END AS mrs_request_type,
    CASE
      WHEN STRPOS(slot__time_position_class, 'preroll') > 0
      THEN 'preroll'
      WHEN STRPOS(slot__time_position_class, 'midroll') > 0
      THEN 'midroll'
      WHEN STRPOS(slot__time_position_class, 'postroll') > 0
      THEN 'postroll'
      WHEN STRPOS(slot__time_position_class, 'overlay') > 0
      THEN 'overlay'
      WHEN STRPOS(slot__time_position_class, 'display') > 0
      THEN 'display'
      ELSE 'na'
    END AS ad_unit_type,
    visitor__country,
    visitor__country_id,
    visitor__state,
    visitor__state_id,
    visitor__dma_code_id,
    SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) - 1 AS ack_ad_duplicated_impression
  FROM ${bcv_ack}
  WHERE
    ack__ack_entity_type = 'ad'
    AND (
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
    11,
    12,
    13,
    14,
    15,
    16,
    request__server_id,
    request__transaction_id,
    ack__ad_id,
    ack__ad_replica_id
  HAVING
    SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) > 1
)
LEFT JOIN db.default.d_network AS nw
  ON nw.id = video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = distributor_network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
LEFT JOIN db.default.d_lu_dma AS lud
  ON lud.id = visitor__dma_code_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = visitor__country_id
LEFT JOIN db.default.d_lu_state AS st
  ON st.id = visitor__state_id
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
  20
