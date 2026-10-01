-- account:    sa-presto-tier2
-- skeleton:   60e0c4eae56d2ce06037e914db1deb3d
-- pattern:    e8d58a26dee2316fe5fcadd015c1f911  (2 execution(s))
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
  candidate__deal_type,
  request__context__video_cro_network_id AS cro_network_id,
  ELEMENT_AT(partners__network_id, 1) AS partner_1_network_id,
  ELEMENT_AT(partners__network_id, 2) AS partner_2_network_id,
  ELEMENT_AT(partners__asset_group_ids, 1) AS p1_asset_group_ids,
  ELEMENT_AT(partners__asset_group_ids, 2) AS p2_asset_group_ids,
  ELEMENT_AT(partners__site_section_group_ids, 1) AS p1_ssg_ids,
  ELEMENT_AT(partners__site_section_group_ids, 2) AS p2_ssg_ids,
  COUNT(*) AS cnt
FROM ${bcv_candidate}
WHERE
  candidate__internal_deal_id = 250652
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8
