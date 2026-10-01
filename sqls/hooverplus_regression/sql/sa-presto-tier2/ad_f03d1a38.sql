-- account:    sa-presto-tier2
-- skeleton:   01642c617cdbb80077b08bf036a241d8
-- pattern:    f03d1a385cefa7b6d0000023663d5826  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH mrs_slots AS (
  SELECT
    request__transaction_id,
    slot__index,
    request__timestamp,
    COUNT_IF(
      advertisement__position_in_slot = 0
      AND advertisement__is_fallback = FALSE
      AND candidate__integration_type IN ('openrtb_normal', 'openrtb_pg_td', 'openrtb_sfx')
    ) AS has_prog_primary,
    COUNT_IF(
      advertisement__is_fallback = TRUE
      AND BITWISE_AND(COALESCE(advertisement__extra_flags2, 0), 16777216) > 0
    ) AS has_podbuster_fallback
  FROM ${bcv_ad}
  WHERE
    BITWISE_AND(COALESCE(request__extra_flags2, 0), 4194304) > 0
  GROUP BY
    1,
    2,
    3
)
SELECT
  COUNT(*) AS total_mrs_first_slots,
  COUNT_IF(has_prog_primary > 0) AS slots_with_prog_primary,
  COUNT_IF(has_podbuster_fallback > 0) AS slots_with_podbuster_fallback,
  COUNT_IF(has_prog_primary > 0 AND has_podbuster_fallback > 0) AS slots_with_both
FROM mrs_slots
