-- account:    sa-presto-tier2
-- skeleton:   cd73d5213c62d1c514fac1510373410e
-- pattern:    1363d1dbd760c10212f7986182e30a3f  (1 execution(s))
-- in suite:   column coverage
-- hoover:     candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp >= CURRENT_TIMESTAMP - INTERVAL ? HOUR

SELECT
  candidate__request__context__profile_id,
  candidate__error,
  COUNT(*) AS cnt
FROM ${bcv_candidate}
WHERE
  (
    request__context__network_id = 520311 AND candidate__network_id = 530364
  )
  AND candidate__integration_type = 'mkpl_partner_tag'
GROUP BY
  1,
  2
