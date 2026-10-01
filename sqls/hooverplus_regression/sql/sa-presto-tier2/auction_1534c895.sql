-- account:    sa-presto-tier2
-- skeleton:   37f4c8c1f5b34bae8364f035253d13be
-- pattern:    1534c89522d74902b6c440d551291c27  (1 execution(s))
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
  BITWISE_AND(auction__extra_flags, 4194304) AS bit22_check,
  COUNT(*) AS cnt
FROM ${bcv_auction}
WHERE
  request__context__video_cro_network_id = 376521
GROUP BY
  1,
  2
