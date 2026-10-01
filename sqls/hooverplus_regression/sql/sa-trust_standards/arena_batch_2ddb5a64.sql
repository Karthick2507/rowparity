-- account:    sa-trust_standards
-- skeleton:   3fefdfa6f4d89e3b4342918f58fc4968
-- pattern:    2ddb5a646f5c097bd95c442f599b639f  (1 execution(s))
-- in suite:   column coverage
-- hoover:     none
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__context__network_id AS network_id,
  request__context__profile_id AS profile_id,
  IF(BITWISE_AND(request__extra_flags2, 8) > 0, visitor__address, visitor__peer_address) AS ip,
  0 AS ip_int,
  0 AS profile_id_hex,
  COUNT(1) AS total_count
FROM ${bcv_request}
WHERE
  IF(BITWISE_AND(request__extra_flags2, 8) > 0, visitor__address, visitor__peer_address) LIKE '%.%'
GROUP BY
  1,
  2,
  3,
  4,
  5
