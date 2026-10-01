-- account:    sa-dataapp-yield
-- skeleton:   02a2de2f594dab869bb8ff73cea2bc9d
-- pattern:    a1fbcb45a3ae397204b548515b5dd9a2  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH tmp AS (
  SELECT
    DATE_TRUNC('HOUR', ack__timestamp) AS timestamp,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(request__context__network_id, -1) AS distributor_network_id,
    COALESCE(request__context__profile_id, -1) AS profile_id,
    COALESCE(request__context__site_section_cro_asset_id, -1) AS root_section_id,
    COALESCE(request__server_group, 'na') AS server_group,
    COALESCE(visitor__user_agent_device_type, 'na') AS platform,
    CASE WHEN request__is_filtered THEN 'true' ELSE 'false' END AS is_filtered,
    CASE
      WHEN visitor__caller = 'resp-format:scte-130 custom-template:scte-p1'
      THEN 'comcast-ws2'
      WHEN visitor__caller = 'resp-format:scte-130 custom-template:comcast'
      THEN 'comcast-ws1'
      WHEN visitor__caller = 'resp-format:scte-130 custom-template:all-ip-vod'
      THEN 'comcast-ws3'
      WHEN visitor__caller = 'resp-format:vmap1 custom-template:sky'
      THEN 'sky'
      ELSE 'others'
    END AS work_stream,
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
    COALESCE(advertisement__ad_oo_network_id, -1) AS ad_oo_network_id,
    CASE
      WHEN advertisement__external_reseller__network_id <= 0
      THEN 'local'
      ELSE 'national'
    END AS opportunity_type,
    COALESCE(SPLIT_PART(request__context__custom_asset_id, '/', 2), 'na') AS provider_name,
    request__transaction_id AS tr_id,
    request__server_id,
    advertisement__ad_id AS ad_id,
    advertisement__ad_replica_id,
    SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS imp,
    SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS ack_ad_impression,
    SUM(COALESCE(ack__metrics__first_quartile, 0)) AS ack_ad_first_quartile,
    SUM(COALESCE(ack__metrics__middle_quartile, 0)) AS ack_ad_mid_point,
    SUM(COALESCE(ack__metrics__third_quartile, 0)) AS ack_ad_third_quartile,
    SUM(COALESCE(ack__metrics__complete_quartile, 0)) AS ack_ad_complete
  FROM ${bcv_ack}
  WHERE
    (
      (
        request__context__response_format = 18
        OR request__context__request_format = 3
        OR visitor__caller = 'resp-format:scte-130 custom-template:viper-csai-vod'
      )
      AND BITWISE_AND(request__extra_flags, 1024) = 0
    )
    AND NOT ack__event_name IN ('videoview', 'startplacement', 'slotimpression')
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
)
SELECT
  tmp.timestamp AS timestamp,
  tmp.video_cro_network_id AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  tmp.distributor_network_id AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  tmp.server_group,
  tmp.platform,
  tmp.profile_id AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  tmp.root_section_id AS distributor_site_section_id,
  COALESCE(ss.name, 'na') AS distributor_site_section_name,
  tmp.is_filtered AS is_filtered,
  tmp.work_stream AS work_stream,
  tmp.ad_unit_type AS ad_unit_type,
  tmp.ad_oo_network_id AS ad_network_id,
  COALESCE(ad_nw.name, 'na') AS ad_network_name,
  tmp.opportunity_type AS opportunity_type,
  tmp.provider_name AS provider_name,
  SUM(IF(imp > 1, imp - 1, 0)) AS ack_ad_duplicated_impression,
  SUM(ack_ad_impression) AS ack_ad_impression,
  SUM(ack_ad_first_quartile) AS ack_ad_first_quartile,
  SUM(ack_ad_mid_point) AS ack_ad_mid_point,
  SUM(ack_ad_third_quartile) AS ack_ad_third_quartile,
  SUM(ack_ad_complete) AS ack_ad_complete
FROM tmp
LEFT JOIN db.default.d_network AS nw
  ON nw.id = tmp.video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = tmp.distributor_network_id
LEFT JOIN db.default.d_network AS ad_nw
  ON ad_nw.id = tmp.ad_oo_network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = tmp.profile_id
LEFT JOIN db.default.d_site_section AS ss
  ON ss.id = tmp.root_section_id
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
  18
