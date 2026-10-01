-- account:    sa-presto-tier2
-- skeleton:   eb5336663c1cfcc5b9a8ffdd924ad33d
-- pattern:    d94f7241802b59840d482a3c719307b4  (1 execution(s))
-- in suite:   column coverage
-- hoover:     candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp >= CURRENT_TIMESTAMP - INTERVAL ? HOUR

SELECT
  candidate__order_id,
  candidate__error,
  candidate__raw_price,
  candidate__price,
  candidate__original_price,
  COUNT(*) AS cnt
FROM ${bcv_candidate}
WHERE
  (
    request__context__network_id = 520311 AND candidate__network_id = 530364
  )
  AND candidate__integration_type = 'mkpl_partner_tag'
GROUP BY
  1,
  2,
  3,
  4,
  5
