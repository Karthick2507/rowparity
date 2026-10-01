-- account:    sa-presto-tier2
-- skeleton:   c9416fa16fbc8f466c4874d72a1c614b
-- pattern:    e68a93929809c632d91f11d032a5c0c0  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   primary_ad.request__timestamp < CAST(? AS TIMESTAMP)
--   primary_ad.request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_TRUNC('DAY', primary_ad.request__timestamp) AS day,
  COUNT(DISTINCT primary_ad.request__transaction_id) AS transactions,
  COUNT(*) AS primary_prog_ads_with_podbuster_fallback
FROM ${bcv_ad} AS primary_ad
JOIN ${bcv_ad} AS fallback_ad
  ON primary_ad.request__transaction_id = fallback_ad.request__transaction_id
  AND primary_ad.slot__index = fallback_ad.slot__index
  AND fallback_ad.request__timestamp = primary_ad.request__timestamp
WHERE
  (
    (
      (
        (
          BITWISE_AND(COALESCE(primary_ad.request__extra_flags2, 0), 4194304) > 0
          AND primary_ad.advertisement__position_in_slot = 0
        )
        AND primary_ad.advertisement__is_fallback = FALSE
      )
      AND primary_ad.candidate__integration_type IN ('openrtb_normal', 'openrtb_pg_td', 'openrtb_sfx')
    )
    AND fallback_ad.advertisement__is_fallback = TRUE
  )
  AND BITWISE_AND(COALESCE(fallback_ad.advertisement__extra_flags2, 0), 16777216) > 0
GROUP BY
  1
