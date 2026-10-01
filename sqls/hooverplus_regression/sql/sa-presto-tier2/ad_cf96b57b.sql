-- account:    sa-presto-tier2
-- skeleton:   2cf4a3ded421ca4b8c3e85279e41628b
-- pattern:    cf96b57b039244520b591d2849afdd89  (2 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request_event_date < CAST(? AS TIMESTAMP)
--   request_event_date >= CAST(? AS TIMESTAMP)

SELECT
  advertisement__is_fallback,
  CASE
    WHEN advertisement__replaced_ad_id IS NULL
    THEN 'null (no primary replaced)'
    ELSE 'not null (has replaced primary)'
  END AS replaced_ad_id_status,
  COUNT(*) AS cnt
FROM ${bcv_ad}
WHERE
  request__is_first_request = TRUE
GROUP BY
  1,
  2
