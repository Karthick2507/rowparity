-- account:    sa-presto-tier2
-- skeleton:   8cbcccea3656feaffcd347ba289f5096
-- pattern:    a87849c5754e5321ed82b2fb2d340b0c  (1 execution(s))
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
  auction__third_party_identifier_ids,
  auction__extra_flags,
  COUNT(*) AS cnt
FROM ${bcv_auction}
WHERE
  (
    request__context__video_cro_network_id = 376521
    AND NOT auction__third_party_identifier_ids IS NULL
  )
  AND CARDINALITY(auction__third_party_identifier_ids) > 0
GROUP BY
  1,
  2
