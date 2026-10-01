-- account:    sa-presto-tier2
-- skeleton:   b25499e3721c6257f701739a771c16fe
-- pattern:    4faac2d4f1d431509627a3b09a8becf1  (1 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   t.request__timestamp < CAST(? AS TIMESTAMP)
--   t.request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  COUNT(*) AS cnt
FROM ${bcv_transaction} AS t
WHERE
  t.request__context__video_cro_network_id = 393759
  AND CONTAINS(
    FLATTEN(t.transaction__request__rtb_auction__deal__internal_deal_id),
    CAST('670542' AS BIGINT)
  )
