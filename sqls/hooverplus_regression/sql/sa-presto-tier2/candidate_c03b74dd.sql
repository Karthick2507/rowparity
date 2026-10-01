-- account:    sa-presto-tier2
-- skeleton:   a952016459c71e0dec4f00362ecbaddd
-- pattern:    c03b74ddde8fbbed9852f69d0e66c86b  (1 execution(s))
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
  request__context__video_cro_network_id AS cro_network,
  candidate__integration_type,
  CASE
    WHEN candidate__internal_deal_id IS NULL
    THEN 'ox (no deal)'
    WHEN candidate__internal_deal_id = 250652
    THEN 'political deal'
    ELSE 'other deal'
  END AS candidate_type,
  COUNT(*) AS cnt
FROM ${bcv_candidate}
WHERE
  request__context__video_cro_network_id IN (530362, 520311)
  AND candidate__integration_type = 'openrtb_normal'
GROUP BY
  1,
  2,
  3
