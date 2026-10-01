-- account:    sa-presto-af-etl
-- skeleton:   f5adef25a9140bebd9f50f14230b02df
-- pattern:    8d938e84295d21a892c1f301f9e6d486  (2 execution(s))
-- in suite:   column coverage
-- hoover:     ack, ad, auction, candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CURRENT_DATE - INTERVAL ? DAY + INTERVAL ? HOUR
--   request__timestamp >= CURRENT_DATE - INTERVAL ? DAY

WITH deal_meta AS (
  SELECT
    d.id AS deal_id,
    CAST(d.pricing_model AS VARCHAR) AS price_model,
    CASE
      WHEN o.inherit_inbound_price = 1
      THEN 'floor price from sell-side floor'
      WHEN p.policy = 'use_inventory'
      THEN 'floor price from inventory'
      WHEN p.policy = 'use_max'
      THEN 'use highest floor price'
      ELSE 'enter a floor price'
    END AS price_policy,
    o.price AS price
  FROM oltp.fwmrm_oltp.ssp_deal AS d
  JOIN oltp.fwmrm_oltp.mkpl_order_deal_assignment AS a
    ON d.id = a.deal_id
  JOIN oltp.fwmrm_oltp.mkpl_order AS o
    ON o.id = a.mkpl_order_id
  LEFT JOIN oltp.fwmrm_oltp.ssp_floor_price_policy AS p
    ON d.id = p.deal_id
  WHERE
    d.network_id = 523319
), auction_table AS (
  SELECT
    IF(
      auction__network_id = 523319
      AND CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    ) AS seller_network_id,
    auction__network_id,
    auction__app_bundle AS app_bundle,
    visitor__country_id AS user_country_id,
    auction__dsp_id AS rtb_auction__dsp_id,
    d_info.deal_id AS deal_id,
    d_info.outbound_bid_floor AS outbound_bid_floor,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS bid_request,
    DATE_TRUNC('DAY', request__timestamp) AS event_date
  FROM ${bcv_auction}
  CROSS JOIN UNNEST(ZIP(
    COALESCE(TRY(auction__impression__deals__internal_deal_id[1]), ARRAY[]),
    COALESCE(TRY(auction__impression__deals__bid_floor[1]), ARRAY[])
  )) AS d_info(deal_id, outbound_bid_floor)
  WHERE
    (
      (
        NOT deal_id IS NULL AND auction__network_id = 523319
      )
      AND auction__integration_type IN ('normal')
    )
    AND COALESCE(request__traffic_type, -1) <= 0
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    9
), candidate_table AS (
  SELECT
    IF(
      auction__network_id = 523319
      AND CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    ) AS seller_network_id,
    auction__network_id,
    auction__app_bundle AS app_bundle,
    visitor__country_id AS user_country_id,
    auction__dsp_id AS rtb_auction__dsp_id,
    candidate__internal_deal_id AS deal_id,
    SUM(IF(BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0, 1, 0)) AS bid_response,
    DATE_TRUNC('DAY', request__timestamp) AS event_date
  FROM ${bcv_candidate}
  WHERE
    (
      auction__network_id = 523319 AND COALESCE(request__traffic_type, -1) <= 0
    )
    AND auction__integration_type IN ('normal')
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    8
), ad_table AS (
  SELECT
    IF(
      auction__network_id = 523319
      AND CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    ) AS seller_network_id,
    auction__network_id,
    auction__app_bundle AS app_bundle,
    visitor__country_id AS user_country_id,
    auction__dsp_id AS rtb_auction__dsp_id,
    candidate__internal_deal_id AS deal_id,
    COUNT(1) AS selected_ad,
    DATE_TRUNC('DAY', request__timestamp) AS event_date
  FROM ${bcv_ad}
  WHERE
    (
      auction__network_id = 523319 AND COALESCE(request__traffic_type, -1) <= 0
    )
    AND auction__integration_type IN ('normal')
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    8
), revenue_table AS (
  SELECT
    IF(
      auction__network_id = 523319 AND ARRAY_POSITION(partners__network_id, 523319) > 1,
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_id, 523319) - 1),
      -1
    ) AS seller_network_id,
    auction__network_id,
    auction__app_bundle AS app_bundle,
    visitor__country_id AS user_country_id,
    auction__dsp_id AS rtb_auction__dsp_id,
    candidate__internal_deal_id AS deal_id,
    SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS impression,
    SUM(
      COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000.0
    ) AS revenue,
    DATE_TRUNC('DAY', request__timestamp) AS event_date
  FROM ${bcv_ack}
  WHERE
    (
      (
        auction__network_id = 523319 AND auction__integration_type IN ('normal')
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
    6,
    9
)
SELECT
  a.seller_network_id,
  a.app_bundle,
  a.user_country_id,
  a.rtb_auction__dsp_id AS dsp_id,
  a.deal_id,
  m.price_model,
  m.price_policy,
  m.price,
  a.outbound_bid_floor,
  COALESCE(a.bid_request, 0) AS bid_request,
  COALESCE(c.bid_response, 0) AS bid_response,
  COALESCE(ad.selected_ad, 0) AS selected_ad,
  COALESCE(r.impression, 0) AS impression,
  COALESCE(r.revenue, 0) AS revenue,
  IF(
    COALESCE(a.bid_request, 0) > 0,
    COALESCE(c.bid_response, 0) * 1.0 / a.bid_request,
    NULL
  ) AS response_rate,
  a.event_date
FROM auction_table AS a
LEFT JOIN candidate_table AS c
  ON a.seller_network_id = c.seller_network_id
  AND a.auction__network_id = c.auction__network_id
  AND a.app_bundle IS NOT DISTINCT FROM c.app_bundle
  AND a.user_country_id IS NOT DISTINCT FROM c.user_country_id
  AND a.rtb_auction__dsp_id IS NOT DISTINCT FROM c.rtb_auction__dsp_id
  AND a.deal_id IS NOT DISTINCT FROM c.deal_id
  AND a.event_date = c.event_date
LEFT JOIN ad_table AS ad
  ON a.seller_network_id = ad.seller_network_id
  AND a.auction__network_id = ad.auction__network_id
  AND a.app_bundle IS NOT DISTINCT FROM ad.app_bundle
  AND a.user_country_id IS NOT DISTINCT FROM ad.user_country_id
  AND a.rtb_auction__dsp_id IS NOT DISTINCT FROM ad.rtb_auction__dsp_id
  AND a.deal_id IS NOT DISTINCT FROM ad.deal_id
  AND a.event_date = ad.event_date
LEFT JOIN revenue_table AS r
  ON a.seller_network_id = r.seller_network_id
  AND a.auction__network_id = r.auction__network_id
  AND a.app_bundle IS NOT DISTINCT FROM r.app_bundle
  AND a.user_country_id IS NOT DISTINCT FROM r.user_country_id
  AND a.rtb_auction__dsp_id IS NOT DISTINCT FROM r.rtb_auction__dsp_id
  AND a.deal_id IS NOT DISTINCT FROM r.deal_id
  AND a.event_date = r.event_date
LEFT JOIN deal_meta AS m
  ON a.deal_id = m.deal_id
