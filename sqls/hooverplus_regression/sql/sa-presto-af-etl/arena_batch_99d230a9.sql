-- account:    sa-presto-af-etl
-- skeleton:   1996c5dba3ffbf88937c08b144b3c455
-- pattern:    99d230a9b59d2237a9c68d6bcaa2ac3f  (30 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  visitor__user_id,
  network_id,
  COUNT(*) AS req_cnt,
  DATE_FORMAT(time_bucket_id, '%y%m%d%h%i') AS event_time
FROM (
  SELECT
    request__visitor__user_id AS visitor__user_id,
    request__context__video_cro_network_id AS network_id,
    DATE_TRUNC('HOUR', CAST(request__timestamp AS TIMESTAMP)) + FLOOR(EXTRACT(MINUTE FROM CAST(request__timestamp AS TIMESTAMP)) / 30) * INTERVAL '30' MINUTE AS time_bucket_id
  FROM ${bcv_transaction}
  WHERE
    (
      NOT request__visitor__user_id IS NULL
      AND FROM_BIG_ENDIAN_64(XXHASH64(CAST(request__visitor__user_id AS VARBINARY))) % 100 = 3
    )
    AND (
      request__extra_flags2 IS NULL OR BITWISE_AND(65536, request__extra_flags2) = 0
    )
)
GROUP BY
  1,
  2,
  4
