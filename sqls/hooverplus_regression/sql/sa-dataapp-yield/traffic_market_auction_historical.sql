-- account:    sa-dataapp-yield
-- skeleton:   62a5f8042a67e773c1e32d433ec5eb1e
-- pattern:    7734137a0e4c2af77b3a17c2bb0168ae  (698 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  CASE
    WHEN auction__integration_type = 'normal'
    THEN 'fullstack_non_pg'
    WHEN auction__integration_type = 'pg_td'
    THEN 'fullstack_pg'
    WHEN auction__integration_type = 'sfx'
    THEN 'sfx_openrtb'
    WHEN auction__integration_type = 'mkpl_partner_tag'
    THEN 'mkpl_partner_tag'
    ELSE 'sfx_tag'
  END AS market_integration_type,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(auction__buyer_platform_id, -1) AS buyer_platform_id,
  COALESCE(d_ssp_buyer_platform.name, 'na') AS buyer_platform,
  COALESCE(auction__buyer_platform_url_id, -1) AS buyer_platform_url_id,
  COALESCE(auction__dsp_id, -1) AS dsp_id,
  COALESCE(d_dsp.name, 'na') AS dsp_name,
  COALESCE(auction__network_id, -1) AS auction_network_id,
  COALESCE(d_network.name, 'na') AS auction_network_name,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(cro.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(dis.name, 'na') AS distributor_network_name,
  IF(
    auction__network_id = 523319
    AND CONTAINS(partners__entity_source, 'auction_upstream'),
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
    -1
  ) AS auction_upstream_network_id,
  COALESCE(auc_upstream.name, 'na') AS auction_upstream_network_name,
  IF(
    auction__integration_type = 'mkpl_partner_tag'
    AND CONTAINS(partners__entity_source, 'order_buyer'),
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'order_buyer')),
    -1
  ) AS candidate_network_id,
  COALESCE(buyer_network.name, 'na') AS candidate_network_name,
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
    WHEN STRPOS(auction__time_position_class, 'preroll') > 0
    THEN 'preroll'
    WHEN STRPOS(auction__time_position_class, 'pause_midroll') > 0
    THEN 'pause'
    WHEN STRPOS(auction__time_position_class, 'midroll') > 0
    THEN 'midroll'
    WHEN STRPOS(auction__time_position_class, 'postroll') > 0
    THEN 'postroll'
    WHEN STRPOS(auction__time_position_class, 'overlay') > 0
    THEN 'overlay'
    WHEN STRPOS(auction__time_position_class, 'display') > 0
    THEN 'display'
    ELSE 'na'
  END AS ad_unit_type,
  CASE WHEN (
    NOT visitor__cookie_user_id IS NULL
  ) THEN 'true' ELSE 'false' END AS has_cookie_id,
  CASE WHEN BITWISE_AND(request__flags, 64) = 0 THEN 'false' ELSE 'true' END AS is_filtered,
  -1 AS video_cro_site_section_id,
  -1 AS auction_site_section_id,
  SUM(
    COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
  ) AS auction_request,
  SUM(1) AS auction_request_logged,
  SUM(IF(COALESCE(request__log_sampling__magnifier, 1) > 1, 1, 0)) AS auction_request_logged_binlog_sampling,
  SUM(IF(COALESCE(auction__auction_sampling__magnifier, 1) > 1, 1, 0)) AS auction_request_logged_auction_sampling,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_request_sent,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__flags, 0), 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_user_matched_request,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__flags, 0), 2) > 0
      AND BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_pii_blocked_by_gdpr,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__flags, 0), 4) > 0
      AND BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_pii_blocked_by_ccpa,
  SUM(
    IF(
      BITWISE_AND(COALESCE(auction__flags, 0), 16) > 0
      AND BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_pii_blocked_by_fw_opt_out,
  SUM(
    IF(
      COALESCE(auction__error, '') <> '',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_error,
  SUM(
    IF(
      auction__error = 'http_error',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_http_error,
  SUM(
    IF(
      auction__error = 'timeout',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_timeout,
  SUM(
    IF(
      auction__error = 'exceed_server_concurrent_limit',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_server_concurrent_limit,
  SUM(
    IF(
      auction__error = 'exceed_transaction_concurrent_limit',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_transaction_concurrent_limit,
  SUM(
    IF(
      auction__error = 'blocked_by_traffic_control',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_blocked_by_traffic_control,
  SUM(
    IF(
      auction__error = 'request_domain_blocked',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_request_domain_blocked,
  SUM(
    IF(
      auction__error = 'malformed_response',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_malformed_response,
  SUM(
    IF(
      auction__error = 'no_bids',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_no_bids,
  SUM(
    IF(
      auction__error = 'impression_no_bids',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_impression_no_bids,
  SUM(
    IF(
      auction__error = 'coppa_unsupported',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_coppa_unsupport,
  SUM(
    IF(
      auction__error = 'lat_unsupported',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_lat_unsupport,
  SUM(
    IF(
      auction__error = 'bid_response_id_nomatch',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_bid_response_id_nomatch,
  SUM(
    IF(
      auction__error = 'empty_response',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_empty_response,
  SUM(
    IF(
      auction__error = 'kv_opt_out',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_kv_opt_out,
  SUM(
    IF(
      auction__error = 'blocked_by_bid_throttling',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_blocked_by_bid_throttling,
  SUM(
    IF(
      auction__error = 'ccpa_unsupported',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_ccpa_unsupport,
  SUM(
    IF(
      auction__error = 'gdpr_unsupported',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_gdpr_unsupport,
  SUM(
    IF(
      auction__error = 'atts_unsupported',
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_err_atts_unsupport,
  SUM(
    IF(
      auction__integration_type IN ('normal', 'pg_td')
      AND CARDINALITY(COALESCE(auction__impression__index, ARRAY[])) > 0,
      CARDINALITY(auction__impression__index) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS impression_offered
FROM ${bcv_auction}
LEFT JOIN db.default.d_ssp_demand_side_platform AS d_dsp
  ON d_dsp.id = auction__dsp_id
LEFT JOIN db.default.d_ssp_buyer_platform
  ON d_ssp_buyer_platform.id = auction__buyer_platform_id
LEFT JOIN db.default.d_network AS d_network
  ON auction__network_id = d_network.id
LEFT JOIN db.default.d_network AS cro
  ON cro.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS dis
  ON dis.id = request__context__network_id
LEFT JOIN db.default.d_network AS auc_upstream
  ON auc_upstream.id = IF(
    auction__network_id = 523319
    AND CONTAINS(partners__entity_source, 'auction_upstream'),
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
    -1
  )
LEFT JOIN db.default.d_network AS buyer_network
  ON buyer_network.id = IF(
    auction__integration_type = 'mkpl_partner_tag'
    AND CONTAINS(partners__entity_source, 'order_buyer'),
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'order_buyer')),
    -1
  )
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  (
    auction__integration_type IN ('normal', 'pg_td', 'sfx', 'reseller_tag', 'mkpl_partner_tag')
    AND BITWISE_AND(auction__flags, 8) = 0
  )
  AND BITWISE_AND(auction__flags, 64) = 0
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
