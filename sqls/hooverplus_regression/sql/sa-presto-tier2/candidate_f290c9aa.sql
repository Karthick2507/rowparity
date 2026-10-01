-- account:    sa-presto-tier2
-- skeleton:   55abd062a723d3cc4b2d65bb138e42d4
-- pattern:    f290c9aa99bbf8f57e75077eedc16f5e  (2 execution(s))
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
  request__log_version__major_release_version,
  request__log_version__minor_release_version,
  COUNT(*) AS requests
FROM ${bcv_candidate}
WHERE
  request__context__network_id = 393759
GROUP BY
  1,
  2
