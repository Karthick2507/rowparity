-- account:    yjgou
-- skeleton:   9bab521972e41ccb57349364a315b558
-- pattern:    e1d9e9a27e2e14cb359a1bafe91c6405  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id < DATE_FORMAT(CAST(? AS TIMESTAMP), ?)
--   process_batch_id >= DATE_FORMAT(DATE_ADD(?, -?, CAST(? AS TIMESTAMP)), ?)

SELECT
  nw.name AS network_name,
  auction__auction_sampling__mode,
  auction__auction_sampling__magnifier,
  COUNT(1) AS total_auction,
  SUM(auction__bid_request_count) AS restored_total_auction,
  auction__network_id AS network_id,
  DATE_TRUNC('DAY', DATE_PARSE(process_batch_id, '%y%m%d%h%i%s')) AS process_date
FROM ${bcv_auction}
JOIN oltp.fwmrm_oltp.network AS nw
  ON auction__network_id = nw.id
GROUP BY
  1,
  2,
  3,
  6,
  7
ORDER BY
  7,
  6
