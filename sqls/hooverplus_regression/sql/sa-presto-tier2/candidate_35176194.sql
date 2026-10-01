-- account:    sa-presto-tier2
-- skeleton:   3e67b2c961a22738476e30357db6125a
-- pattern:    35176194ddf6f342247649e6be19f708  (1 execution(s))
-- in suite:   column coverage
-- hoover:     candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  candidate__slot__time_position_class AS tpc,
  candidate__slot__time_position_sequence AS tps,
  candidate__slot__break_id AS break_id,
  candidate__slot__slot_sequence AS slot_seq,
  candidate__slot__custom_id AS slot_custom_id,
  COUNT(*) AS cnt
FROM ${bcv_candidate}
GROUP BY
  1,
  2,
  3,
  4,
  5
