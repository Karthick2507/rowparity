-- account:    sa-presto-tier2
-- skeleton:   2c9d97b97d5e939d7a465551e44e26f7
-- pattern:    6970107c6f2a2310c8022e334664fa7f  (1 execution(s))
-- in suite:   column coverage
-- hoover:     request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS hr,
  COUNT(*) AS requests,
  SUM(COALESCE(request__log_sampling__magnifier, 1)) AS magnified_requests
FROM ${bcv_request}
WHERE
  request__context__network_id = 534985
  AND BITWISE_AND(request__extra_flags2, 65536) > 0
GROUP BY
  1
