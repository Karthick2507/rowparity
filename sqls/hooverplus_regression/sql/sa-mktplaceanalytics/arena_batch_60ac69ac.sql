-- account:    sa-mktplaceanalytics
-- skeleton:   1527f8369667859aea4988998aa634f3
-- pattern:    60ac69ac392c06b73e58f347d14f4a2c  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE_TRUNC(?, CAST(? AS TIMESTAMP))
--   request__timestamp >= DATE_ADD(?, -?, DATE_TRUNC(?, CAST(? AS TIMESTAMP)))

SELECT
  *,
  time AS _arena_partition_time
FROM (
  SELECT
    CAST(DATE_TRUNC('DAY', "time") AS DATE) AS "time",
    bid_type,
    network_id,
    dsp_id,
    total_bids,
    total_won_bids,
    all_bids_raw_price,
    raw_price,
    clearing_price
  FROM (
    SELECT
      DATE_TRUNC('DAY', request__timestamp) AS time,
      CASE
        WHEN BITWISE_AND(auction__extra_flags, 8192) = 0
        THEN 'others'
        WHEN BITWISE_AND(auction__extra_flags, 8192) > 0
        THEN 'pod bidding'
      END AS bid_type,
      auction__dsp_id AS dsp_id,
      auction__network_id AS network_id,
      COALESCE(COUNT(1), 0) AS total_bids,
      COALESCE(COUNT_IF(BITWISE_AND(candidate__bid_status, 8) > 0), 0) AS total_won_bids,
      SUM(candidate__raw_price) AS all_bids_raw_price,
      SUM(IF(BITWISE_AND(candidate__bid_status, 8) > 0, candidate__raw_price, 0)) AS raw_price,
      SUM(IF(BITWISE_AND(candidate__bid_status, 8) > 0, candidate__clearing_price, 0)) AS clearing_price
    FROM ${bcv_candidate}
    WHERE
      (
        TRUE AND BITWISE_AND(candidate__bid_status, 1) > 0
      )
      AND auction__integration_type = 'normal'
    GROUP BY
      1,
      2,
      3,
      4
  )
) AS arena_tmp
