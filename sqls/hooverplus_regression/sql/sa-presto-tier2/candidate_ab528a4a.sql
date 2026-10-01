-- account:    sa-presto-tier2
-- skeleton:   d363f22c4adc0ad0169e72b5dc95d2da
-- pattern:    ab528a4ae5ee7781ea57d077d678670f  (1 execution(s))
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
  candidate__advertisement__market_ad_id,
  candidate__error,
  candidate__internal_deal_id,
  candidate__brand_id,
  COUNT(*) AS cnt
FROM ${bcv_candidate}
WHERE
  candidate__advertisement__market_ad_id IN (
    CAST('322682260' AS BIGINT),
    CAST('322682333' AS BIGINT),
    CAST('322683525' AS BIGINT),
    CAST('322683701' AS BIGINT)
  )
GROUP BY
  1,
  2,
  3,
  4
