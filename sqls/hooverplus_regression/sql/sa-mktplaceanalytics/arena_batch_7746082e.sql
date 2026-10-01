-- account:    sa-mktplaceanalytics
-- skeleton:   1d9f760d45494cd3c8c380daeadb1f92
-- pattern:    7746082e91bc875710ae07805a4b62a5  (695 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE_ADD(?, -?, DATE_TRUNC(?, CAST(? AS TIMESTAMP)))
--   request__timestamp >= DATE_ADD(?, -?, DATE_TRUNC(?, CAST(? AS TIMESTAMP)))

SELECT
  *,
  time AS _arena_partition_time
FROM (
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS time,
    auction__network_id,
    auction__dsp_id,
    CASE
      WHEN BITWISE_AND(auction__extra_flags, 8192) = 0
      THEN 'others'
      WHEN BITWISE_AND(auction__extra_flags, 8192) > 0
      THEN 'pod bidding'
    END AS bid_type,
    COUNT(DISTINCT request__transaction_id) AS ad_request_count
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
    4
) AS arena_tmp
