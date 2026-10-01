-- account:    sa-dataapp-yield
-- skeleton:   f714f2799a39ab1a1ec0f8f0e5fbc38b
-- pattern:    e959608f9d0f0d4cdf79f7cfb3caec89  (697 execution(s))
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
  'mkpl_partner_tag' AS market_integration_type,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(auction__network_id, -1) AS auction_network_id,
  COALESCE(d_network.name, 'na') AS auction_network_name,
  COALESCE(d_buyer.id, -1) AS candidate_network_id,
  COALESCE(d_buyer.name, 'na') AS candidate_network_name,
  COALESCE(d_mkpl_order.id, -1) AS order_id,
  COALESCE(d_mkpl_order.name, 'na') AS order_name,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(cro.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(dis.name, 'na') AS distributor_network_name,
  COALESCE(request__server_group, 'na') AS server_group,
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
  CASE WHEN request__is_filtered = FALSE THEN 'false' ELSE 'true' END AS is_filtered,
  SUM(
    COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
  ) AS auction_deal_request,
  SUM(
    COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
  ) AS auction_request,
  SUM(
    IF(
      BITWISE_AND(auction__auction_status, 2) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_deal_request_sent,
  SUM(
    IF(
      BITWISE_AND(auction__flags, 1) > 0,
      COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
      0
    )
  ) AS auction_user_matched_request,
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
  ) AS auction_err_atts_unsupport
FROM ${bcv_auction}
CROSS JOIN UNNEST(partners__network_id, partners__entity_source, partners__inbound_order_id) AS partner(nw_id, entity_source, inbound_order_id)
LEFT JOIN db.default.d_network AS d_network
  ON auction__network_id = d_network.id
LEFT JOIN db.default.d_mkpl_order AS d_mkpl_order
  ON partner.inbound_order_id = d_mkpl_order.id
LEFT JOIN db.default.d_network AS d_buyer
  ON partner.nw_id = d_buyer.id
LEFT JOIN db.default.d_network AS cro
  ON cro.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS dis
  ON dis.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  (
    (
      auction__integration_type IN ('mkpl_partner_tag')
      AND partner.entity_source = 'order_buyer'
    )
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
  21
