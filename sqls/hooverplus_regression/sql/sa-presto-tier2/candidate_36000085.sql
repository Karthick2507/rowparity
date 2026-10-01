-- account:    sa-presto-tier2
-- skeleton:   b3c47d44138c7a774d30efd1dd841afa
-- pattern:    360000851732fdb9421864f1b54a98e9  (1 execution(s))
-- in suite:   column coverage
-- hoover:     candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp >= CURRENT_TIMESTAMP - INTERVAL ? HOUR

SELECT
  ELEMENT_AT(
    request__context__key_value__value,
    ARRAY_POSITION(request__context__key_value__key, 'csid')
  ) AS csid,
  ELEMENT_AT(
    request__context__key_value__value,
    ARRAY_POSITION(request__context__key_value__key, 'tpcl')
  ) AS tpcl,
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
  2,
  3
