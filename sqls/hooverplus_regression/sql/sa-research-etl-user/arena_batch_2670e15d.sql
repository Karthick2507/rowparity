-- account:    sa-research-etl-user
-- skeleton:   c72216be8dfe4851cb34da947be910b6
-- pattern:    2670e15d79b70937f3b22186388f034c  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     auction, candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH candidate_table AS (
  SELECT
    ARRAY_JOIN(
      IF(
        auction__network_id = 523319,
        ARRAY[IF(
          CONTAINS(partners__entity_source, 'auction_upstream'),
          ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
          -1
        ), auction__network_id],
        ARRAY[auction__network_id]
      ),
      '-'
    ) AS network_id,
    c.auction__app_bundle AS app_bundle,
    c.visitor__country_id AS user_country_id,
    c.auction__dsp_id AS rtb_auction__dsp_id,
    DATE_FORMAT(request__timestamp, '%y-%m-%d-%h') AS event_date_hour,
    SUM(candidate__clearing_price) AS revenue,
    COUNT(1) AS response_num
  FROM ${bcv_candidate} AS c
  WHERE
    (
      (
        candidate__integration_type = 'openrtb_normal' AND auction__network_id = 523319
      )
      AND BITWISE_AND(candidate__bid_status, 2) > 0
    )
    AND CARDINALITY(ARRAY_INTERSECT(request__context__ab_test_item__bucket_id, ARRAY[248, 249])) > 0
  GROUP BY
    1,
    2,
    3,
    4,
    5
), auction_table AS (
  SELECT
    ARRAY_JOIN(
      IF(
        auction__network_id = 523319,
        ARRAY[IF(
          CONTAINS(partners__entity_source, 'auction_upstream'),
          ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
          -1
        ), auction__network_id],
        ARRAY[auction__network_id]
      ),
      '-'
    ) AS network_id,
    a.auction__app_bundle AS app_bundle,
    a.visitor__country_id AS user_country_id,
    a.auction__dsp_id AS rtb_auction__dsp_id,
    DATE_FORMAT(request__timestamp, '%y-%m-%d-%h') AS event_date_hour,
    COUNT(1) AS request_num
  FROM ${bcv_auction} AS a
  WHERE
    (
      (
        auction__market_integration_type = 'fullstack_non_pg'
        AND auction__network_id = 523319
      )
      AND BITWISE_AND(auction__auction_status, 2) > 0
    )
    AND CARDINALITY(ARRAY_INTERSECT(request__context__ab_test_item__bucket_id, ARRAY[248, 249])) > 0
  GROUP BY
    1,
    2,
    3,
    4,
    5
)
SELECT
  auction_table.network_id,
  auction_table.app_bundle AS app_bundle,
  CAST(auction_table.user_country_id AS BIGINT) AS user_country_id,
  auction_table.rtb_auction__dsp_id AS dsp_id,
  candidate_table.response_num,
  auction_table.request_num,
  CAST(response_num * 1.00000 / request_num AS DOUBLE) AS ratio,
  revenue,
  auction_table.event_date_hour
FROM auction_table
INNER JOIN candidate_table
  ON auction_table.network_id = candidate_table.network_id
  AND auction_table.app_bundle = candidate_table.app_bundle
  AND auction_table.user_country_id = candidate_table.user_country_id
  AND auction_table.rtb_auction__dsp_id = candidate_table.rtb_auction__dsp_id
  AND auction_table.event_date_hour = candidate_table.event_date_hour
