-- account:    sa-presto-tier2
-- skeleton:   927ca9740c9582134d9a77604db1134b
-- pattern:    e8e135171f8a891be9750f276e197c31  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp <= NETWORKLOCAL_TO_UTC(CAST(? AS TIMESTAMP), ?)
--   request__timestamp >= NETWORKLOCAL_TO_UTC(CAST(? AS TIMESTAMP), ?)

SELECT
  advertisement__market_ad_id,
  candidate__error,
  advertisement__error,
  auction__error,
  candidate__filter_reason__error,
  candidate__filter_reason__error_category,
  advertisement__error_partner,
  advertisement__error_domain,
  COUNT(*)
FROM ${bcv_ad}
WHERE
  advertisement__market_ad_id IN (322682260, 322682333, 322683525, 322683701)
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8
