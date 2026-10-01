-- account:    sa-presto-tier2
-- skeleton:   10ea2933b03e5d7d8b2bf6536dc0c900
-- pattern:    fd364e202585a80430aa8cfc1218bb8f  (1 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__context__distributor_network_id AS network_id,
  request__context__cname AS cname,
  COUNT(*) AS request_count
FROM ${bcv_transaction}
WHERE
  request__context__cname = '817ba.v.fwmrm.net'
  AND request__is_first_request = TRUE
GROUP BY
  1,
  2
