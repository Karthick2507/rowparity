-- account:    sa-research-etl-user
-- skeleton:   484f40adb525dd3443c76e249fa35ca7
-- pattern:    fff35ed74197cd16cb9b659dfecb456a  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack, auction, candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   event_date < CAST(? AS TIMESTAMP)
--   event_date >= CAST(? AS TIMESTAMP)
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH take_rate_hour_table AS (
  SELECT
    network_id,
    dsp_id,
    take_rate
  FROM etl.mkpl_operations.f_smart_bidding_take_rates
), base_table AS (
  SELECT
    '2026080409' AS job_id,
    auction__network_id AS auction_network_id,
    IF(
      CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    ) AS auction_upstream_network_id,
    CASE
      WHEN BITWISE_AND(auction__extra_flags, 16384) > 0
      THEN 'baseline'
      WHEN BITWISE_AND(auction__extra_flags, 32768) > 0
      THEN 'probe'
      WHEN BITWISE_AND(auction__extra_flags, 65536) > 0
      THEN 'feedback'
      ELSE 'unknown'
    END AS traffic_type,
    auction__dynamic_floor_price_algorithm AS dynamic_floor_price_algorithm,
    deal_id,
    auction__buyer_group_id AS buyer_group_id,
    COUNT(1) AS deal_request_cnt,
    0 AS deal_response_cnt,
    COUNT_IF(t2.seq = 1) AS buyer_group_request_cnt,
    0 AS buyer_group_response_cnt,
    SUM(
      CASE
        WHEN t2.seq = 1
        THEN COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
        ELSE 0
      END
    ) AS bucket_request_cnt,
    0 AS bucket_response_cnt,
    0 AS deal_imp,
    0 AS deal_revenue,
    0 AS buyer_group_imp,
    0 AS buyer_group_revenue,
    0 AS bucket_imp,
    0 AS bucket_revenue,
    0 AS deal_sum_bid_floor_price,
    0 AS deal_row_bid_floor_price,
    0 AS buyer_group_sum_imp_floor_price,
    0 AS buyer_group_row_imp_floor_price,
    0 AS bucket_sum_floor_price,
    0 AS bucket_row_floor_price,
    0 AS deal_sum_raw_price,
    0 AS deal_row_raw_price,
    0 AS buyer_group_sum_raw_price,
    0 AS buyer_group_row_raw_price,
    0 AS bucket_sum_raw_price,
    0 AS bucket_row_raw_price,
    0 AS deal_sum_clear_price,
    0 AS deal_row_clear_price,
    0 AS buyer_group_sum_clear_price,
    0 AS buyer_group_row_clear_price,
    0 AS bucket_sum_clear_price,
    0 AS bucket_row_clear_price,
    auction__dsp_id AS dsp_id,
    CAST(CASE
      WHEN auction__network_id = 523319
      THEN 0.135
      ELSE COALESCE(take_rate_hour_table.take_rate, 0.05)
    END AS DOUBLE) AS take_rate,
    DATE_FORMAT(request__timestamp, '%y-%m-%d-%h') AS event_date_hour
  FROM ${bcv_auction} AS t1
  LEFT JOIN take_rate_hour_table
    ON t1.auction__network_id = take_rate_hour_table.network_id
    AND t1.auction__dsp_id = take_rate_hour_table.dsp_id
  CROSS JOIN UNNEST(FLATTEN(auction__impression__deals__internal_deal_id)) WITH ORDINALITY AS t2(deal_id, seq)
  WHERE
    auction__market_integration_type = 'fullstack_non_pg'
    AND BITWISE_AND(auction__auction_status, 2) > 0
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    38,
    39,
    40
  UNION ALL
  SELECT
    '2026080409' AS job_id,
    auction__network_id AS auction_network_id,
    IF(
      CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    ) AS auction_upstream_network_id,
    CASE
      WHEN BITWISE_AND(auction__extra_flags, 16384) > 0
      THEN 'baseline'
      WHEN BITWISE_AND(auction__extra_flags, 32768) > 0
      THEN 'probe'
      WHEN BITWISE_AND(auction__extra_flags, 65536) > 0
      THEN 'feedback'
      ELSE 'unknown'
    END AS traffic_type,
    auction__dynamic_floor_price_algorithm AS dynamic_floor_price_algorithm,
    deal_id,
    auction__buyer_group_id AS buyer_group_id,
    0 AS deal_request_cnt,
    COUNT_IF(candidate__internal_deal_id = deal_id) AS deal_response_cnt,
    0 AS buyer_group_request_cnt,
    COUNT_IF(t2.seq = 1 AND candidate__internal_deal_id IS NULL) AS buyer_group_response_cnt,
    0 AS bucket_request_cnt,
    COUNT_IF(t2.seq = 1) AS bucket_response_cnt,
    0 AS deal_imp,
    0 AS deal_revenue,
    0 AS buyer_group_imp,
    0 AS buyer_group_revenue,
    0 AS bucket_imp,
    0 AS bucket_revenue,
    0 AS deal_sum_bid_floor_price,
    0 AS deal_row_bid_floor_price,
    0 AS buyer_group_sum_imp_floor_price,
    0 AS buyer_group_row_imp_floor_price,
    0 AS bucket_sum_floor_price,
    0 AS bucket_row_floor_price,
    0 AS deal_sum_raw_price,
    0 AS deal_row_raw_price,
    0 AS buyer_group_sum_raw_price,
    0 AS buyer_group_row_raw_price,
    0 AS bucket_sum_raw_price,
    0 AS bucket_row_raw_price,
    0 AS deal_sum_clear_price,
    0 AS deal_row_clear_price,
    0 AS buyer_group_sum_clear_price,
    0 AS buyer_group_row_clear_price,
    0 AS bucket_sum_clear_price,
    0 AS bucket_row_clear_price,
    auction__dsp_id AS dsp_id,
    CAST(CASE
      WHEN auction__network_id = 523319
      THEN 0.135
      ELSE COALESCE(take_rate_hour_table.take_rate, 0.05)
    END AS DOUBLE) AS take_rate,
    DATE_FORMAT(request__timestamp, '%y-%m-%d-%h') AS event_date_hour
  FROM ${bcv_candidate} AS t1
  LEFT JOIN take_rate_hour_table
    ON t1.auction__network_id = take_rate_hour_table.network_id
    AND t1.auction__dsp_id = take_rate_hour_table.dsp_id
  CROSS JOIN UNNEST(FLATTEN(auction__impression__deals__internal_deal_id), FLATTEN(auction__impression__deals__bid_floor), FLATTEN(auction__impression__deals__bid_floor_uplift)) WITH ORDINALITY AS t2(deal_id, deal_bid_floor, deal_bid_floor_uplift, seq)
  WHERE
    auction__market_integration_type = 'fullstack_non_pg'
    AND BITWISE_AND(candidate__bid_status, 2) > 0
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    38,
    39,
    40
  UNION ALL
  SELECT
    '2026080409' AS job_id,
    auction__network_id AS auction_network_id,
    IF(
      auction__network_id = 523319 AND ARRAY_POSITION(partners__network_id, 523319) > 1,
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_id, 523319) - 1),
      -1
    ) AS auction_upstream_network_id,
    CASE
      WHEN BITWISE_AND(auction__extra_flags, 16384) > 0
      THEN 'baseline'
      WHEN BITWISE_AND(auction__extra_flags, 32768) > 0
      THEN 'probe'
      WHEN BITWISE_AND(auction__extra_flags, 65536) > 0
      THEN 'feedback'
      ELSE 'unknown'
    END AS traffic_type,
    auction__dynamic_floor_price_algorithm AS dynamic_floor_price_algorithm,
    candidate__internal_deal_id AS deal_id,
    auction__buyer_group_id AS buyer_group_id,
    0 AS deal_request_cnt,
    0 AS deal_response_cnt,
    0 AS buyer_group_request_cnt,
    0 AS buyer_group_response_cnt,
    0 AS bucket_request_cnt,
    0 AS bucket_response_cnt,
    SUM(IF(NOT candidate__internal_deal_id IS NULL, ack__metrics__ad_impression, 0)) AS deal_imp,
    SUM(
      IF(NOT candidate__internal_deal_id IS NULL, ack__metrics__ad_impression, 0) * candidate__clearing_price * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate
    ) / 1000 AS deal_revenue,
    SUM(IF(candidate__internal_deal_id IS NULL, ack__metrics__ad_impression, 0)) AS buyer_group_imp,
    SUM(
      IF(candidate__internal_deal_id IS NULL, ack__metrics__ad_impression, 0) * candidate__clearing_price * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate
    ) / 1000 AS buyer_group_revenue,
    SUM(COALESCE(ack__metrics__ad_impression, 0)) AS bucket_imp,
    SUM(
      COALESCE(ack__metrics__ad_impression, 0) * candidate__clearing_price * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate
    ) / 1000 AS bucket_revenue,
    SUM(
      IF(
        NOT candidate__internal_deal_id IS NULL,
        ELEMENT_AT(
          FLATTEN(auction__impression__deals__bid_floor),
          ARRAY_POSITION(FLATTEN(auction__impression__deals__internal_deal_id), candidate__internal_deal_id)
        ),
        0
      )
    ) AS deal_sum_bid_floor_price,
    COUNT_IF(NOT candidate__internal_deal_id IS NULL) AS deal_row_bid_floor_price,
    SUM(IF(candidate__internal_deal_id IS NULL, auction__impression__bid_floor[1], 0)) AS buyer_group_sum_imp_floor_price,
    COUNT_IF(candidate__internal_deal_id IS NULL) AS buyer_group_row_imp_floor_price,
    SUM(
      CASE
        WHEN NOT candidate__internal_deal_id IS NULL
        THEN ELEMENT_AT(
          FLATTEN(auction__impression__deals__bid_floor),
          ARRAY_POSITION(FLATTEN(auction__impression__deals__internal_deal_id), candidate__internal_deal_id)
        )
        WHEN candidate__internal_deal_id IS NULL
        THEN auction__impression__bid_floor[1]
        ELSE 0
      END
    ) AS bucket_sum_floor_price,
    COUNT(1) AS bucket_row_floor_price,
    SUM(IF(NOT candidate__internal_deal_id IS NULL, candidate__raw_price, 0)) AS deal_sum_raw_price,
    COUNT_IF(NOT candidate__internal_deal_id IS NULL) AS deal_row_raw_price,
    SUM(IF(candidate__internal_deal_id IS NULL, candidate__raw_price, 0)) AS buyer_group_sum_raw_price,
    COUNT_IF(candidate__internal_deal_id IS NULL) AS buyer_group_row_raw_price,
    SUM(candidate__raw_price) AS bucket_sum_raw_price,
    COUNT(1) AS bucket_row_raw_price,
    SUM(IF(NOT candidate__internal_deal_id IS NULL, candidate__clearing_price, 0)) AS deal_sum_clear_price,
    COUNT_IF(NOT candidate__internal_deal_id IS NULL) AS deal_row_clear_price,
    SUM(IF(candidate__internal_deal_id IS NULL, candidate__clearing_price, 0)) AS buyer_group_sum_clear_price,
    COUNT_IF(candidate__internal_deal_id IS NULL) AS buyer_group_row_clear_price,
    SUM(COALESCE(candidate__clearing_price, 0)) AS bucket_sum_clear_price,
    COUNT_IF(NOT candidate__clearing_price IS NULL) AS bucket_row_clear_price,
    auction__dsp_id AS dsp_id,
    CAST(CASE
      WHEN auction__network_id = 523319
      THEN 0.135
      ELSE COALESCE(take_rate_hour_table.take_rate, 0.05)
    END AS DOUBLE) AS take_rate,
    DATE_FORMAT(request__timestamp, '%y-%m-%d-%h') AS event_date_hour
  FROM ${bcv_ack} AS t1
  LEFT JOIN take_rate_hour_table
    ON t1.auction__network_id = take_rate_hour_table.network_id
    AND t1.auction__dsp_id = take_rate_hour_table.dsp_id
  WHERE
    (
      auction__market_integration_type = 'fullstack_non_pg'
      AND BITWISE_AND(candidate__bid_status, 2) > 0
    )
    AND ack__metrics__ad_impression > 0
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    38,
    39,
    40
)
SELECT
  job_id,
  auction_network_id,
  auction_upstream_network_id,
  traffic_type,
  dynamic_floor_price_algorithm,
  deal_id,
  buyer_group_id,
  deal_request_cnt,
  deal_response_cnt,
  buyer_group_request_cnt,
  buyer_group_response_cnt,
  bucket_request_cnt,
  bucket_response_cnt,
  deal_imp,
  deal_revenue,
  buyer_group_imp,
  buyer_group_revenue,
  bucket_imp,
  bucket_revenue,
  deal_sum_bid_floor_price,
  deal_row_bid_floor_price,
  buyer_group_sum_imp_floor_price,
  buyer_group_row_imp_floor_price,
  bucket_sum_floor_price,
  bucket_row_floor_price,
  deal_sum_raw_price,
  deal_row_raw_price,
  buyer_group_sum_raw_price,
  buyer_group_row_raw_price,
  bucket_sum_raw_price,
  bucket_row_raw_price,
  deal_sum_clear_price,
  deal_row_clear_price,
  buyer_group_sum_clear_price,
  buyer_group_row_clear_price,
  bucket_sum_clear_price,
  bucket_row_clear_price,
  dsp_id,
  take_rate,
  CAST(take_rate * bucket_revenue AS DOUBLE) AS net_revenue,
  event_date_hour
FROM base_table
