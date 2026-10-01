-- account:    sa-presto-tier2
-- skeleton:   4cf9b667cb20b6fdc91fb7aeeb490cbc
-- pattern:    1085f63f4a720e09440b464af6d02a3e  (1 execution(s))
-- in suite:   column coverage
-- hoover:     auction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  auction__extra_flags,
  BITWISE_AND(auction__extra_flags, 1) AS bit0,
  BITWISE_AND(auction__extra_flags, 2) AS bit1,
  BITWISE_AND(auction__extra_flags, 4) AS bit2,
  BITWISE_AND(auction__extra_flags, 8) AS bit3,
  BITWISE_AND(auction__extra_flags, 16) AS bit4,
  BITWISE_AND(auction__extra_flags, 32) AS bit5,
  BITWISE_AND(auction__extra_flags, 64) AS bit6,
  BITWISE_AND(auction__extra_flags, 128) AS bit7,
  BITWISE_AND(auction__extra_flags, 256) AS bit8,
  BITWISE_AND(auction__extra_flags, 512) AS bit9,
  BITWISE_AND(auction__extra_flags, 1024) AS bit10,
  BITWISE_AND(auction__extra_flags, 2048) AS bit11,
  BITWISE_AND(auction__extra_flags, 4096) AS bit12,
  BITWISE_AND(auction__extra_flags, 8192) AS bit13,
  BITWISE_AND(auction__extra_flags, 16384) AS bit14,
  BITWISE_AND(auction__extra_flags, 32768) AS bit15,
  BITWISE_AND(auction__extra_flags, 65536) AS bit16,
  BITWISE_AND(auction__extra_flags, 131072) AS bit17,
  BITWISE_AND(auction__extra_flags, 262144) AS bit18,
  BITWISE_AND(auction__extra_flags, 524288) AS bit19,
  BITWISE_AND(auction__extra_flags, 1048576) AS bit20,
  BITWISE_AND(auction__extra_flags, 2097152) AS bit21,
  BITWISE_AND(auction__extra_flags, 4194304) AS bit22,
  COUNT(*) AS cnt
FROM ${bcv_auction}
WHERE
  request__context__video_cro_network_id = 376521
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23
