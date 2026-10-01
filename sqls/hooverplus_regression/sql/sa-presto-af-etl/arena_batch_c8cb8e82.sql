-- account:    sa-presto-af-etl
-- skeleton:   07d3168c7d6a1c62bc92576454e8825d
-- pattern:    c8cb8e82bee15b6dc55fa2bd76d8d4d7  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack, auction, candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH auction_table AS (
  SELECT
    IF(
      auction__network_id = 523319
      AND CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    ) AS seller_network_id,
    auction__network_id AS auction__network_id,
    COALESCE(auction__app_bundle, '-3') AS app_bundle,
    COALESCE(visitor__country_id, -3) AS user_country_id,
    COALESCE(auction__dsp_id, -3) AS rtb_auction__dsp_id,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request,
    DATE_TRUNC('DAY', request__timestamp) AS event_date
  FROM ${bcv_auction}
  WHERE
    (
      auction__network_id = 523319 AND auction__integration_type IN ('normal')
    )
    AND COALESCE(request__traffic_type, -1) <= 0
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    7
), candidate_table AS (
  SELECT
    IF(
      auction__network_id = 523319
      AND CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    ) AS seller_network_id,
    auction__network_id AS auction__network_id,
    COALESCE(auction__app_bundle, '-3') AS app_bundle,
    COALESCE(visitor__country_id, -3) AS user_country_id,
    COALESCE(auction__dsp_id, -3) AS rtb_auction__dsp_id,
    SUM(IF(BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0, 1, 0)) AS bids_resolved,
    DATE_TRUNC('DAY', request__timestamp) AS event_date
  FROM ${bcv_candidate}
  WHERE
    (
      auction__network_id = 523319 AND COALESCE(request__traffic_type, -1) <= 0
    )
    AND candidate__integration_type IN ('openrtb_normal')
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    7
), revenue_table AS (
  SELECT
    IF(
      auction__network_id = 523319 AND ARRAY_POSITION(partners__network_id, 523319) > 1,
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_id, 523319) - 1),
      -1
    ) AS seller_network_id,
    auction__network_id AS auction__network_id,
    COALESCE(auction__app_bundle, '-3') AS app_bundle,
    COALESCE(visitor__country_id, -3) AS user_country_id,
    COALESCE(auction__dsp_id, -3) AS rtb_auction__dsp_id,
    SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS ack_ad_impression,
    SUM(
      COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000
    ) AS ack_ad_revenue,
    DATE_TRUNC('DAY', request__timestamp) AS event_date
  FROM ${bcv_ack}
  WHERE
    (
      (
        auction__network_id = 523319
        AND candidate__integration_type IN ('openrtb_normal')
      )
      AND COALESCE(ack__traffic_type, -1) <= 0
    )
    AND ack__ack_entity_type = 'ad'
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    8
)
SELECT
  auction_table.seller_network_id AS seller_network_id,
  auction_table.auction__network_id,
  auction_table.user_country_id AS user_country_id,
  auction_table.rtb_auction__dsp_id AS rtb_auction__dsp_id,
  COALESCE(auction_request, 0) AS auction_request,
  COALESCE(bids_resolved, 0) AS bids_resolved,
  COALESCE(revenue_table.ack_ad_impression, 0) AS ack_ad_impression,
  COALESCE(revenue_table.ack_ad_revenue, 0) AS ack_ad_revenue,
  IF(
    COALESCE(auction_request, 0) > 0,
    COALESCE(bids_resolved, 0) * 1.0 / auction_request,
    NULL
  ) AS response_rate,
  IF(
    COALESCE(bids_resolved, 0) > 0,
    COALESCE(revenue_table.ack_ad_impression, 0) * 1.0 / bids_resolved,
    NULL
  ) AS impression_rate,
  IF(
    COALESCE(revenue_table.ack_ad_impression, 0) > 0,
    COALESCE(revenue_table.ack_ad_revenue, 0) / revenue_table.ack_ad_impression * 1000,
    NULL
  ) AS avg_clearing_price_cpm,
  auction_table.event_date AS event_date
FROM auction_table
LEFT OUTER JOIN candidate_table
  ON auction_table.seller_network_id = candidate_table.seller_network_id
  AND auction_table.auction__network_id = candidate_table.auction__network_id
  AND auction_table.app_bundle = candidate_table.app_bundle
  AND auction_table.user_country_id = candidate_table.user_country_id
  AND auction_table.rtb_auction__dsp_id = candidate_table.rtb_auction__dsp_id
  AND auction_table.event_date = candidate_table.event_date
LEFT OUTER JOIN revenue_table
  ON auction_table.seller_network_id = revenue_table.seller_network_id
  AND auction_table.auction__network_id = revenue_table.auction__network_id
  AND auction_table.app_bundle = revenue_table.app_bundle
  AND auction_table.user_country_id = revenue_table.user_country_id
  AND auction_table.rtb_auction__dsp_id = revenue_table.rtb_auction__dsp_id
  AND auction_table.event_date = revenue_table.event_date
