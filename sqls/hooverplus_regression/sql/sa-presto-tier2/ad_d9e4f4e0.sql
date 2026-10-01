-- account:    sa-presto-tier2
-- skeleton:   8e604c604574ac400393475914f06da2
-- pattern:    d9e4f4e063428e7c594b85b9a3610f10  (1 execution(s))
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
  DATE_TRUNC('DAY', request__timestamp) AS day,
  COUNT(DISTINCT request__transaction_id) AS mrs_first_requests_with_prog_primary,
  COUNT(*) AS total_primary_prog_ads,
  SUM(
    CASE
      WHEN BITWISE_AND(COALESCE(advertisement__extra_flags2, 0), 16777216) > 0
      THEN 1
      ELSE 0
    END
  ) AS has_podbuster_fallback
FROM ${bcv_ad}
WHERE
  (
    (
      (
        BITWISE_AND(COALESCE(request__extra_flags2, 0), 4194304) > 0
        AND request__is_first_request
      )
      AND advertisement__position_in_slot = 0
    )
    AND BITWISE_AND(COALESCE(advertisement__flags, 0), 32) = 0
  )
  AND advertisement__sales_strategy = 4
GROUP BY
  1
