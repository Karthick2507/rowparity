-- account:    sa-presto-tier2
-- skeleton:   c0a14e948d6659c6eb964043a81a8d4d
-- pattern:    78d30fe8b132747eb0bb2357062b4212  (2 execution(s))
-- in suite:   column coverage
-- hoover:     candidate
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < NETWORKLOCAL_TO_UTC(CAST(? AS TIMESTAMP), ?)
--   request__timestamp >= NETWORKLOCAL_TO_UTC(CAST(? AS TIMESTAMP), ?)

SELECT
  advertisement__market_ad_id,
  candidate__error,
  candidate__brand_id,
  advertisement__global_brand_id,
  candidate__internal_deal_id,
  CONTAINS(candidate__filter_reason__error, 'global_brand_restricted_by_deal') AS has_brand_deal_restriction,
  CONTAINS(candidate__filter_reason__error, 'brand_restricted_by_rule') AS has_brand_rule_restriction,
  CONTAINS(candidate__filter_reason__error, 'ad_pending_approval') AS has_pending_approval,
  advertisement__error,
  auction__error,
  COUNT(*) AS cnt
FROM ${bcv_candidate}
WHERE
  advertisement__market_ad_id IN (
    CAST('322682260' AS BIGINT),
    CAST('322682333' AS BIGINT),
    CAST('322683525' AS BIGINT),
    CAST('322683701' AS BIGINT)
  )
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10
