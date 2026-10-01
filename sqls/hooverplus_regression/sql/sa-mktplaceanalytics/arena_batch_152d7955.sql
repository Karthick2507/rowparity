-- account:    sa-mktplaceanalytics
-- skeleton:   385936ee9ef4db24cdc231ef527139c2
-- pattern:    152d795584db89e7eda24db9adeac530  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
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
  WITH sample AS (
    SELECT
      DATE_TRUNC('DAY', request__timestamp) AS time,
      auction__network_id AS network_id,
      auction__dsp_id AS dsp_id,
      CASE
        WHEN BITWISE_AND(auction__extra_flags, 8192) = 0
        THEN 'others'
        WHEN BITWISE_AND(auction__extra_flags, 8192) > 0
        THEN 'pod bidding'
      END AS bid_type,
      auction__auction_sampling__magnifier AS magnifier,
      COUNT(1) AS auction_requests,
      SUM(auction__impression__equivalent_opportunity_number[1]) AS auction_oppurtunities,
      COUNT_IF(BITWISE_AND(auction__auction_status, 8) > 0) AS responses_with_bids
    FROM ${bcv_auction}
    WHERE
      (
        TRUE AND BITWISE_AND(auction__auction_status, 2) > 0
      )
      AND auction__integration_type = 'normal'
    GROUP BY
      1,
      2,
      3,
      4,
      5
  )
  SELECT
    time,
    network_id,
    dsp_id,
    bid_type,
    SUM(COALESCE(magnifier, 1) * auction_requests) AS auction_requests,
    SUM(COALESCE(magnifier, 1) * auction_oppurtunities) AS auction_oppurtunities,
    SUM(COALESCE(magnifier, 1) * responses_with_bids) AS responses_with_bids
  FROM sample
  GROUP BY
    1,
    2,
    3,
    4
) AS arena_tmp
