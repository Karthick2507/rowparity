-- account:    sa-trust_standards
-- skeleton:   e63fe332c5bac04d8be38a48da7602df
-- pattern:    67a537e069662a31608a9a06082edb39  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  auction__publisher_id AS publisher_id,
  d.name AS publisher_name,
  COUNT(1) AS auction_request_count
FROM ${bcv_auction}
JOIN oltp.fwmrm_oltp.network AS d
  ON d.id = auction__network_id AND d.test_mode = 0
WHERE
  auction__integration_type IN ('normal', 'pg_td') AND auction__auction_status > 1
GROUP BY
  1,
  2
ORDER BY
  3 DESC
