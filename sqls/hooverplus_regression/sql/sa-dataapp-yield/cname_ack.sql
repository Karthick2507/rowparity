-- account:    sa-dataapp-yield
-- skeleton:   e118b46bdcf92583724440eb0d731e82
-- pattern:    313544a49497025412cae33c74e2f71f  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  timestamp,
  video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  distributor_network_id,
  COALESCE(dnw.name, 'na') AS distributor_network_name,
  profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  a.host_name AS host_name,
  COALESCE(cname.target, 'na') AS target,
  country,
  COALESCE(ctry.description, 'unknown country') AS country_name,
  state,
  COALESCE(st.description, 'unknown state') AS state_name,
  dma,
  COALESCE(lud.description, 'unknown dma') AS dma_name,
  is_filtered,
  is_https,
  service_type,
  address_ip_version,
  peer_address_ip_version,
  platform,
  server_pool,
  server_group,
  ack_ad_impression,
  ack_ack
FROM (
  SELECT
    DATE_TRUNC('HOUR', ack__timestamp) AS timestamp,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(request__context__network_id, -1) AS distributor_network_id,
    COALESCE(request__context__profile_id, -1) AS profile_id,
    COALESCE(request__context__host_name, 'na') AS host_name,
    CASE
      WHEN request__context__host_name = 'bea4.cnn.com'
      THEN 'bea4c.v.fwmrm.net'
      WHEN request__context__host_name = 'fwlive.crackle.com'
      THEN '2517d.s.fwmrm.net'
      WHEN request__context__host_name = 'bea4.adultswim.com'
      THEN 'bea4as.v.fwmrm.net'
      WHEN request__context__host_name = 'freewheel-live.fuse.tv'
      THEN '2e6f8.v.fwmrm.net'
      WHEN request__context__host_name = 'ad2.fw.msggo.com'
      THEN '7cead.v.fwmrm.net'
      WHEN request__context__host_name = 'freewheel-live.fm.tv'
      THEN '7cecc.v.fwmrm.net'
      WHEN request__context__host_name = 'fwtest.crackle.com'
      THEN '2517d.s.fwmrm.net'
      WHEN request__context__host_name = 'freewheel-test.fuse.tv'
      THEN '2e6f7.v.fwmrm.net'
      WHEN request__context__host_name = 'fwlive.sonycrackle.com'
      THEN '2517d.s.fwmrm.net'
      WHEN request__context__host_name = 'mrm.channel4.com'
      THEN '2a7e9.v.fwmrm.net'
      WHEN request__context__host_name = 'freewheel-test.fm.tv'
      THEN '7cecb.v.fwmrm.net'
      WHEN NOT request__context__host_name IS NULL
      THEN request__context__host_name
      ELSE 'na'
    END AS middle_host_name,
    COALESCE(visitor__country_id, -1) AS visitor__country_id,
    COALESCE(visitor__country, 'unknown country') AS country,
    COALESCE(visitor__state_id, -1) AS visitor__state_id,
    COALESCE(visitor__state, 'unknown state') AS state,
    COALESCE(visitor__dma_code, -1) AS dma,
    CASE WHEN BITWISE_AND(request__flags, 64) > 0 THEN 'true' ELSE 'false' END AS is_filtered,
    CASE WHEN BITWISE_AND(request__flags, 512) > 0 THEN 'true' ELSE 'false' END AS is_https,
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
    CASE
      WHEN visitor__address IS NULL
      THEN 'na'
      WHEN visitor__address LIKE '%:%'
      THEN 'ipv6'
      WHEN visitor__address LIKE '%.%'
      THEN 'ipv4'
      ELSE 'unknown'
    END AS address_ip_version,
    CASE
      WHEN visitor__peer_address IS NULL
      THEN 'na'
      WHEN visitor__peer_address LIKE '%:%'
      THEN 'ipv6'
      WHEN visitor__peer_address LIKE '%.%'
      THEN 'ipv4'
      ELSE 'unknown'
    END AS peer_address_ip_version,
    COALESCE(visitor__user_agent_device_type, 'na') AS platform,
    COALESCE(request__server_pool, 'na') AS server_pool,
    COALESCE(request__server_group, 'na') AS server_group,
    SUM(
      IF(
        BITWISE_AND(request__extra_flags, 16384) > 0,
        IF(ack__event_type = 'n' AND ack__event_name = 'defaultinsertion', 1, 0),
        COALESCE(ack__metrics__raw_ad_impression, 0)
      )
    ) AS ack_ad_impression,
    COUNT(1) AS ack_ack
  FROM ${bcv_ack}
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
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19
) AS a
LEFT JOIN db.default.d_network AS nw
  ON nw.id = video_cro_network_id
LEFT JOIN db.default.d_network AS dnw
  ON dnw.id = distributor_network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = profile_id
LEFT JOIN db.default.d_lu_state AS st
  ON st.id = visitor__state_id
LEFT JOIN db.default.d_country AS ctry
  ON ctry.id = visitor__country_id
LEFT JOIN db.default.d_lu_dma AS lud
  ON lud.code = dma
LEFT JOIN db.pqm.dim_delivery_report_cname_full AS cname
  ON LOWER(cname.host_name) = LOWER(middle_host_name)
