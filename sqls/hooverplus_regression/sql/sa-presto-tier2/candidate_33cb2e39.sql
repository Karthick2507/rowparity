-- account:    sa-presto-tier2
-- skeleton:   bb6013b5c6486012ef3cfec013c5e7f0
-- pattern:    33cb2e392d8324d64fb0184ccd782cb2  (1 execution(s))
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
  candidate__max_ad_duration,
  COUNT(1) AS cnt
FROM ${bcv_candidate}
WHERE
  request__context__video_cro_network_id = 537323
GROUP BY
  1
