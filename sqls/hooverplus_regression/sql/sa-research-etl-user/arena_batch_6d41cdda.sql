-- account:    sa-research-etl-user
-- skeleton:   bf2d2a7579ef161c10151e598ad5e1fc
-- pattern:    6d41cdda5d52b18e5948f49828079096  (697 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  IF(
    auction__network_id = 523319,
    auction__publisher_id,
    CAST(auction__network_id AS VARCHAR)
  ) AS network_id,
  CAST(d.collection_id AS BIGINT) AS collection_id,
  CAST(d.bucket_id AS BIGINT) AS bucket_id,
  auction__app_bundle AS app_bundle,
  visitor__country_id AS user_country_id,
  auction__dsp_id AS dsp_id,
  candidate__internal_deal_id AS deal_id,
  CASE
    WHEN SUM(ack__metrics__ad_impression) <= 0
    THEN 0.0
    ELSE SUM(
      candidate__raw_price * candidate__candidate_network_to_auction_network_exchange_rate
    ) / SUM(ack__metrics__ad_impression)
  END AS avg_bid_price,
  CASE
    WHEN SUM(ack__metrics__ad_impression) <= 0
    THEN 0.0
    ELSE SUM(
      candidate__clearing_price * candidate__candidate_network_to_auction_network_exchange_rate
    ) / SUM(ack__metrics__ad_impression)
  END AS avg_clear_price,
  CAST(0.0 AS DOUBLE) AS avg_imp_bid_floor,
  CASE
    WHEN SUM(ack__metrics__ad_impression) <= 0
    THEN 0.0
    ELSE SUM(candidate__auction_outbound_bid_floor) / SUM(ack__metrics__ad_impression)
  END AS avg_deals_bid_floor,
  SUM(
    candidate__raw_price * candidate__candidate_network_to_auction_network_exchange_rate
  ) AS sum_bid_price,
  SUM(
    candidate__clearing_price * candidate__candidate_network_to_auction_network_exchange_rate
  ) AS sum_clear_price,
  CAST(0.0 AS DOUBLE) AS sum_imp_bid_floor,
  SUM(candidate__auction_outbound_bid_floor) AS sum_deals_bid_floor,
  CAST(0 AS BIGINT) AS bid_count,
  SUM(ack__metrics__ad_impression) AS imp_count,
  SUM(
    COALESCE(ack__metrics__ad_impression, 0) * candidate__candidate_network_to_auction_network_exchange_rate * COALESCE(candidate__clearing_price, 0)
  ) AS revenue,
  DATE_FORMAT(request__timestamp, '%y-%m-%d-%h') AS event_date_hour
FROM ${bcv_ack} AS a1
JOIN oltp.fwmrm_oltp.ssp_deal AS a2
  ON a1.candidate__internal_deal_id = a2.id
CROSS JOIN UNNEST(request__context__ab_test_item__collection_id, request__context__ab_test_item__bucket_id) AS d(collection_id, bucket_id)
WHERE
  (
    (
      (
        (
          (
            candidate__integration_type = 'openrtb_normal'
            AND BITWISE_AND(candidate__bid_status, 2) > 0
          )
          AND d.collection_id IN (63, 74, 91, 114, 115)
        )
        AND ack__metrics__ad_impression > 0
      )
      AND auction__network_id = 523319
    )
    AND a2.dynamic_floor_pricing_opt_out = 0
  )
  AND candidate__auction_type <> 'fixed_price'
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  19
