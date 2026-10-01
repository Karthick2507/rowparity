-- account:    sa-research-etl-user
-- skeleton:   cbfd5ab3aaf872cd454ecc06ee76290b
-- pattern:    92eb3790984aff8ee420be619dc39578  (575 execution(s))
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
WHERE
  (
    (
      (
        (
          candidate__integration_type = 'openrtb_normal'
          AND BITWISE_AND(candidate__bid_status, 2) > 0
        )
        AND ack__metrics__ad_impression > 0
      )
      AND auction__network_id IN (
        97753,
        393759,
        525754,
        529349,
        516283,
        171213,
        381963,
        535283,
        518586,
        525281,
        530362,
        510626,
        169843,
        506166,
        531859,
        384777,
        515123,
        515295,
        530700,
        536782,
        516429,
        535262,
        500763,
        524972,
        533599
      )
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
