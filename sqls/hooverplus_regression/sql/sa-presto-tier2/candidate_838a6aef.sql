-- account:    sa-presto-tier2
-- skeleton:   6d32abfefca99680243bcfddc079799d
-- pattern:    838a6aef381baa0c852c8559ced3105b  (1 execution(s))
-- in suite:   column coverage
-- hoover:     candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   c.request__timestamp < CAST(? AS TIMESTAMP)
--   c.request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  COUNT(*) AS cnt
FROM ${bcv_candidate} AS c
WHERE
  c.request__context__video_cro_network_id = 393759
  AND CONTAINS(
    FLATTEN(c.candidate__request__rtb_auction__deal__internal_deal_id),
    CAST('670542' AS BIGINT)
  )
