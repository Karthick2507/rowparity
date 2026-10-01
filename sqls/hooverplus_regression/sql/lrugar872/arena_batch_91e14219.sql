-- account:    lrugar872
-- skeleton:   cb50ac89b0a4bcbf3a7bb2478d3d9730
-- pattern:    91e142198b8888ddecbaa91e0fcdc18d  (24 execution(s))
-- in suite:   column coverage
-- hoover:     ack, auction, transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp BETWEEN CAST(? AS TIMESTAMP) AND CAST(? AS TIMESTAMP)
--   request__timestamp BETWEEN CAST(? AS TIMESTAMP) AND CAST(? AS TIMESTAMP)

WITH cte AS (
  SELECT
    'transaction' AS stage,
    DATE_TRUNC('DAY', request__timestamp) AS event_date,
    DATE_TRUNC('HOUR', request__timestamp) AS event_hour,
    ots_network_id AS network_id,
    COALESCE(mpe_network_id, ots_network_id) AS auction_network_id,
    IF(NOT mpe_network_id IS NULL, 6, 4) AS sales_channel,
    request__context__network_id AS request_context_network_id,
    buyer_platform_id,
    bp.demand_side_platform_id AS dsp_id,
    error_code AS throttled_error_code,
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
    request__visitor__app_bundle_id AS request_visitor_app_bundle,
    request__bidding_context__bid_request__app__bundle AS request_ortbs_app_bundle,
    NULL AS auction_app_bundle,
    request__visitor__country_id AS user_country_id,
    request__server_pool AS server_pool,
    request__server_group AS server_group,
    request__visitor__standard_device_type_ids AS standard_device_ids,
    request__ifa_type AS request_ifa_type,
    NULL AS auction_ifa_type,
    request__visitor__standard_environment_id AS standard_environment_id,
    SUM(num * COALESCE(request__log_sampling__magnifier, 1)) AS throttled_requests,
    0 AS outbound_requests,
    NULL AS run_revenue,
    NULL AS run_revenue_usd,
    NULL AS net_counted_ads
  FROM ${bcv_transaction} AS t
  CROSS JOIN UNNEST(request__outbound_traffic_control_stats__auction_network_id, request__outbound_traffic_control_stats__error_code, request__outbound_traffic_control_stats__blocked_num, request__outbound_traffic_control_stats__buyer_platform_id, request__outbound_traffic_control_stats__mpe_seller_network_id) AS t(ots_network_id, error_code, num, buyer_platform_id, mpe_network_id)
  LEFT JOIN db.default.d_ssp_buyer_platform AS bp
    ON bp.id = buyer_platform_id
  WHERE
    request__is_first_request
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
    22
  UNION ALL
  SELECT
    'auction' AS stage,
    DATE_TRUNC('DAY', request__timestamp) AS event_date,
    DATE_TRUNC('HOUR', request__timestamp) AS event_hour,
    network_id AS network_id,
    IF(supply_source = 6, content_owner_network_id, network_id) AS auction_network_id,
    IF(supply_source = 6, supply_source, sales_channel) AS sales_channel,
    request__context__network_id AS request_context_network_id,
    auction__buyer_platform_id AS buyer_platform_id,
    auction__dsp_id AS dsp_id,
    -2 AS throttled_error_code,
    'pre-filtered' AS control_type,
    'pre-filtered' AS control_type_detailed,
    visitor__app_bundle_id AS request_visitor_app_bundle,
    request__bid_request__app_bundle AS request_ortbs_app_bundle,
    IF(deal_awareability = TRUE, COALESCE(auction__app_bundle, NULL), NULL) AS auction_app_bundle,
    visitor__country_id AS user_country_id,
    request__server_pool AS server_pool,
    request__server_group AS server_group,
    visitor__standard_device_type_ids AS standard_device_ids,
    request__ifa_type AS request_ifa_type,
    auction__ifa_type AS auction_ifa_type,
    visitor__standard_environment_id AS standard_environment_id,
    COALESCE(
      SUM(
        IF(
          BITWISE_AND(auction__flags, 262144) > 0,
          CAST(1 AS BIGINT),
          IF(
            BITWISE_AND(auction__auction_status, 1) > 0
            AND COALESCE(auction__error, '') IN (
              'lat_unsupported',
              'gdpr_unsupported',
              'coppa_unsupported',
              'ccpa_unsupported',
              'atts_unsupported',
              'gpp_unsupported'
            ),
            CAST(1 AS BIGINT),
            CAST(0 AS BIGINT)
          )
        ) * COALESCE(request__log_sampling__magnifier, CAST(1 AS BIGINT)) * COALESCE(auction__auction_sampling__magnifier, CAST(1 AS BIGINT))
      ),
      CAST(0 AS BIGINT)
    ) AS throttled_requests,
    COALESCE(
      SUM(
        IF(
          BITWISE_AND(auction__auction_status, 2) > 0,
          CAST(1 AS BIGINT) * COALESCE(request__log_sampling__magnifier, CAST(1 AS BIGINT)) * COALESCE(auction__auction_sampling__magnifier, CAST(1 AS BIGINT)),
          CAST(0 AS BIGINT)
        )
      ),
      0.0
    ) AS outbound_requests,
    NULL AS run_revenue,
    NULL AS run_revenue_usd,
    NULL AS net_counted_ads
  FROM ${bcv_auction}
  CROSS JOIN UNNEST(partners__sales_channel, partners__network_id, partners__entity_source, partners__supply_source, partners__content_owner_network_id, partners__deal_awareability) AS t(sales_channel, network_id, entity_source, supply_source, content_owner_network_id, deal_awareability)
  WHERE
    (
      (
        COALESCE(auction__integration_type, '') IN ('normal', 'pg_td')
        AND auction__is_faked_auction = FALSE
      )
      AND entity_source IN ('auction')
    )
    AND sales_channel = 4
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
    22
  UNION ALL
  SELECT
    'ack' AS stage,
    DATE_TRUNC('DAY', ack__timestamp) AS event_date,
    DATE_TRUNC('HOUR', ack__timestamp) AS event_hour,
    network_id AS network_id,
    IF(supply_source = 6, content_owner_network_id, network_id) AS auction_network_id,
    IF(supply_source = 6, supply_source, sales_channel) AS sales_channel,
    request__context__network_id AS request_context_network_id,
    auction__buyer_platform_id AS buyer_platform_id,
    auction__dsp_id AS dsp_id,
    -2 AS throttled_error_code,
    NULL AS control_type,
    NULL AS control_type_detailed,
    visitor__app_bundle_id AS request_visitor_app_bundle,
    request__bid_request__app_bundle AS request_ortbs_app_bundle,
    IF(deal_awareability = TRUE, COALESCE(auction__app_bundle, NULL), NULL) AS auction_app_bundle,
    visitor__country_id AS user_country_id,
    request__server_pool AS server_pool,
    request__server_group AS server_group,
    visitor__standard_device_type_ids AS standard_device_ids,
    request__ifa_type AS request_ifa_type,
    auction__ifa_type AS auction_ifa_type,
    visitor__standard_environment_id AS standard_environment_id,
    NULL AS throttled_requests,
    NULL AS outbound_requests,
    SUM(revenue) AS run_revenue,
    SUM(revenue * programmatic_exchange_rate_to_usd) AS run_revenue_usd,
    SUM(ack__metrics__ad_impression) AS net_counted_ads
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(partners__network_id, partners__network_is_ad_owner, partners__network_is_extra_item_owner, partners__revenue, partners__programmatic_exchange_rate_to_usd, partners__supply_source, partners__sales_channel, partners__content_owner_network_id, partners__deal_awareability, partners__role) AS t(network_id, network_is_ad_owner, network_is_extra_item_owner, revenue, programmatic_exchange_rate_to_usd, supply_source, sales_channel, content_owner_network_id, deal_awareability, transaction_type)
  WHERE
    (
      (
        (
          (
            (
              (
                TRUE AND ack__ack_entity_type = 'ad'
              ) AND advertisement__is_bumper = FALSE
            )
            AND (
              ack__is_private_impression = FALSE
              OR network_is_ad_owner
              OR network_is_extra_item_owner
            )
          )
          AND sales_channel = 4
        )
        AND supply_source <> 4
      )
      AND transaction_type IN ('cro', 'r')
    )
    AND COALESCE(ack__traffic_type, CAST(0 AS BIGINT)) = 0
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
    22
)
SELECT
  stage,
  event_date,
  event_hour,
  network_id,
  auction_network_id,
  sales_channel,
  request_context_network_id,
  buyer_platform_id,
  dsp_id,
  throttled_error_code,
  control_type,
  control_type_detailed,
  request_visitor_app_bundle,
  request_ortbs_app_bundle,
  auction_app_bundle,
  user_country_id,
  server_pool,
  server_group,
  standard_device_ids,
  request_ifa_type,
  auction_ifa_type,
  standard_environment_id,
  throttled_requests,
  outbound_requests,
  run_revenue,
  run_revenue_usd,
  net_counted_ads
FROM cte AS s
