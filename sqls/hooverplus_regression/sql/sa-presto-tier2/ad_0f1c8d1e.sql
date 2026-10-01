-- account:    sa-presto-tier2
-- skeleton:   0b47f66265dd18b40a468cd177f28dea
-- pattern:    0f1c8d1eab60ffccd5d7cfd6b96472e9  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__transaction_id,
  COUNT(*) AS record_count,
  ARRAY_AGG(DISTINCT advertisement__ad_id) AS ad_ids,
  ARRAY_AGG(DISTINCT candidate__network_id) AS network_ids
FROM ${bcv_ad}
WHERE
  candidate__network_id = 500763
  AND request__transaction_id = '1781802475392189716-w91fb'
GROUP BY
  request__transaction_id
