-- account:    lrugar872
-- skeleton:   0a47007477c6aa78fbf61d0a52b2829d
-- pattern:    7f72bd2016386b3166f81fc1ed09854e  (44 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp BETWEEN CAST(? AS TIMESTAMP) AND CAST(? AS TIMESTAMP)

SELECT
  DATE_TRUNC('DAY', request__timestamp) AS event_date,
  DATE_TRUNC('HOUR', request__timestamp) AS event_hour,
  DATE_ADD(
    'MINUTE',
    CAST((
      MINUTE(request__timestamp) / 30
    ) * 30 AS BIGINT),
    DATE_TRUNC('HOUR', request__timestamp)
  ) AS event_half_hour,
  mpe_network_id,
  ots_network_id AS network_id,
  COALESCE(mpe_network_id, ots_network_id) AS auction_network_id,
  request__context__network_id AS request_context_network_id,
  request__context__distributor_network_id AS request_context_distributor_network_id,
  request__context__video_cro_network_id AS request_context_video_cro_network_id,
  request__context__site_section_cro_network_id AS request_context_site_section_cro_network_id,
  buyer_platform_id,
  bp.demand_side_platform_id AS dsp_id,
  error_code,
  CASE error_code
    WHEN 243
    THEN 'ots'
    WHEN 216
    THEN 'concurrent limit'
    WHEN 217
    THEN 'concurrent limit'
    WHEN 232
    THEN 'backoff manager'
    WHEN 278
    THEN 'qps cap'
    WHEN 279
    THEN 'qps cap'
    WHEN 280
    THEN 'qps cap'
    WHEN 286
    THEN 'random split'
    ELSE CONCAT('unknown_', CAST(error_code AS VARCHAR))
  END AS control_type,
  CASE error_code
    WHEN 243
    THEN 'ots'
    WHEN 216
    THEN 'concurrent limit - server'
    WHEN 217
    THEN 'concurrent limit - transaction'
    WHEN 232
    THEN 'backoff manager'
    WHEN 278
    THEN 'qps cap - coefficient-based hard cap'
    WHEN 279
    THEN 'qps cap - local std hard cap'
    WHEN 280
    THEN 'qps cap - soft cap'
    WHEN 286
    THEN 'random split'
    ELSE CONCAT('unknown_', CAST(error_code AS VARCHAR))
  END AS control_type_detailed,
  request__context__app__bundle AS app_bundle,
  request__visitor__country_id AS user_country_id,
  request__visitor__country AS user_country,
  request__server_pool AS server_pool,
  request__server_group AS server_group,
  request__visitor__standard_device_type_ids AS standard_device_ids,
  request__ifa_type AS ifa_type,
  request__visitor__standard_environment_id AS standard_environment_id,
  SUM(num * COALESCE(request__log_sampling__magnifier, 1)) AS throttled_requests,
  SUM(num) AS unmagnified_throttled_requests
FROM ${bcv_transaction} AS t
CROSS JOIN UNNEST(request__outbound_traffic_control_stats__auction_network_id, request__outbound_traffic_control_stats__error_code, request__outbound_traffic_control_stats__blocked_num, request__outbound_traffic_control_stats__buyer_platform_id, request__outbound_traffic_control_stats__mpe_seller_network_id) AS t(ots_network_id, error_code, num, buyer_platform_id, mpe_network_id)
LEFT JOIN db.default.d_ssp_buyer_platform AS bp
  ON bp.id = buyer_platform_id
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
  23
