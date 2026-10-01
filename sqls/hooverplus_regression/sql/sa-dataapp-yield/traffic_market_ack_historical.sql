-- account:    sa-dataapp-yield
-- skeleton:   ef0accc095ee4a081ec2fec0e171bd4f
-- pattern:    721070f5469c3208e5b653ab5ed171b9  (697 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', ack__timestamp) AS timestamp,
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
    WHEN candidate__integration_type = 'mkpl_partner_tag'
    THEN 'mkpl_partner_tag'
    ELSE 'na'
  END AS market_integration_type,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(candidate__buyer_platform_id, -1) AS buyer_platform_id,
  COALESCE(ssp_buyer_platform.name, 'na') AS buyer_platform,
  COALESCE(auction__buyer_platform_url_id, -1) AS buyer_platform_url_id,
  COALESCE(candidate__dsp_id, -1) AS dsp_id,
  COALESCE(d_dsp.name, 'na') AS dsp_name,
  COALESCE(auction__network_id, -1) AS auction_network_id,
  COALESCE(auc_network.name, 'na') AS auction_network_name,
  COALESCE(candidate__network_id, -1) AS candidate_network_id,
  COALESCE(cand_network.name, 'na') AS candidate_network_name,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(cro.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(dis.name, 'na') AS distributor_network_name,
  IF(
    auction__network_id = 523319 AND ARRAY_POSITION(partners__network_id, 523319) > 1,
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_id, 523319) - 1),
    -1
  ) AS auction_upstream_network_id,
  COALESCE(auc_upstream.name, 'na') AS auction_upstream_network_name,
  COALESCE(request__server_group, 'na') AS server_group,
  COALESCE(request__server_pool, 'na') AS server_pool,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(auction__device_type, 'na') AS auction_device_type,
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
  CASE
    WHEN STRPOS(slot__time_position_class, 'preroll') > 0
    THEN 'preroll'
    WHEN STRPOS(slot__time_position_class, 'pause_midroll') > 0
    THEN 'pause'
    WHEN STRPOS(slot__time_position_class, 'midroll') > 0
    THEN 'midroll'
    WHEN STRPOS(slot__time_position_class, 'postroll') > 0
    THEN 'postroll'
    WHEN STRPOS(slot__time_position_class, 'overlay') > 0
    THEN 'overlay'
    WHEN STRPOS(slot__time_position_class, 'display') > 0
    THEN 'display'
    ELSE 'others'
  END AS ad_unit_type,
  CASE WHEN (
    NOT visitor__cookie_user_id IS NULL
  ) THEN 'true' ELSE 'false' END AS has_cookie_id,
  CASE WHEN request__is_filtered = FALSE THEN 'false' ELSE 'true' END AS is_filtered,
  -1 AS video_cro_site_section_id,
  -1 AS auction_site_section_id,
  SUM(
    IF(
      BITWISE_AND(advertisement__flags, 32) = 0,
      COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_ad_impression_primary,
  SUM(
    IF(
      BITWISE_AND(advertisement__flags, 32) > 0,
      COALESCE(ack__metrics__raw_ad_impression, 0),
      0
    )
  ) AS ack_ad_impression_fallback,
  SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS ack_ad_impression,
  SUM(
    IF(
      partners__revenue IS NULL OR ARRAY_POSITION(partners__role, 'cro') = 0,
      0,
      ELEMENT_AT(partners__revenue, ARRAY_POSITION(partners__role, 'cro')) * COALESCE(
        ELEMENT_AT(
          MAP_FROM_ENTRIES(ARRAY[(62, 1.0), (49, 1.1421), (44, 1.3196), (21, 0.1097)]),
          cro.default_currency_id
        ),
        1
      ) * COALESCE(ack__metrics__raw_ad_impression, 0)
    )
  ) AS ack_ad_cro_revenue,
  SUM(
    CASE
      WHEN candidate__integration_type IN ('reseller_tag', 'openrtb_sfx')
      AND NOT advertisement__external_reseller__up_revenue IS NULL
      THEN advertisement__external_reseller__up_revenue * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0)
      WHEN candidate__integration_type IN ('openrtb_normal', 'openrtb_pg_td')
      THEN COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000
      WHEN candidate__integration_type IN ('mkpl_partner_tag')
      THEN COALESCE(
        ELEMENT_AT(
          REVERSE(partners__revenue),
          ARRAY_POSITION(REVERSE(partners__network_id), auction__network_id)
        ),
        0
      ) * COALESCE(
        ELEMENT_AT(
          MAP_FROM_ENTRIES(ARRAY[(62, 1.0), (49, 1.1421), (44, 1.3196), (21, 0.1097)]),
          auc_network.default_currency_id
        ),
        1
      ) * COALESCE(ack__metrics__raw_ad_impression, 0)
      ELSE 0
    END
  ) AS ack_ad_revenue
FROM ${bcv_ack} AS t1
LEFT JOIN db.default.d_ssp_demand_side_platform AS d_dsp
  ON d_dsp.id = candidate__dsp_id
LEFT JOIN db.default.d_ssp_buyer_platform AS ssp_buyer_platform
  ON ssp_buyer_platform.id = candidate__buyer_platform_id
LEFT JOIN db.default.d_network AS cand_network
  ON candidate__network_id = cand_network.id
LEFT JOIN db.default.d_network AS auc_network
  ON auction__network_id = auc_network.id
LEFT JOIN db.default.d_network AS cro
  ON cro.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS dis
  ON dis.id = request__context__network_id
LEFT JOIN db.default.d_network AS auc_upstream
  ON auc_upstream.id = IF(
    auction__network_id = 523319 AND ARRAY_POSITION(partners__network_id, 523319) > 1,
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_id, 523319) - 1),
    -1
  )
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  (
    candidate__integration_type IN (
      'openrtb_normal',
      'openrtb_pg_td',
      'reseller_tag',
      'openrtb_sfx',
      'mkpl_partner_tag'
    )
    AND BITWISE_AND(auction__flags, 8) = 0
  )
  AND ack__ack_entity_type = 'ad'
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
  29
