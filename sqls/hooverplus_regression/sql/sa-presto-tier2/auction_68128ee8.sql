-- account:    sa-presto-tier2
-- skeleton:   fbfcbcf6266c436c00fbaf05c7762216
-- pattern:    68128ee80d89238e65769c6ac14f50c0  (1 execution(s))
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
  COUNT_IF(BITWISE_AND(auction__extra_flags, 4194304) > 0) AS auctions_with_fw_enriched_uid,
  COUNT(*) AS total_auctions
FROM ${bcv_auction}
WHERE
  request__context__video_cro_network_id = 376521
