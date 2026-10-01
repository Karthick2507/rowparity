-- account:    sa-presto-tier2
-- skeleton:   73480b51bb931e33d9c37e587e1214c6
-- pattern:    a2859597d8dd1d4bfd010de8dabc48f7  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH tx_ads AS (
  SELECT
    request__transaction_id,
    DATE_FORMAT(request__timestamp, '%y-%m-%d') AS date,
    COUNT(DISTINCT IF(advertisement__ad_id = 92683573, 1, NULL)) AS blipvert_count,
    COUNT(
      DISTINCT IF(
        advertisement__request__context__distributor_network_id = 144750
        AND advertisement__ad_id <> 92683573,
        1,
        NULL
      )
    ) AS sky_priority_count,
    COUNT(DISTINCT IF(CONTAINS(partners__network_id, CAST('191701' AS BIGINT)), 1, NULL)) AS wbd_passback_count,
    COUNT(
      DISTINCT IF(
        CONTAINS(partners__network_id, CAST('386345' AS BIGINT))
        AND BITWISE_AND(COALESCE(partners__bit_flags, 0), BITWISE_LEFT_SHIFT(CAST(1 AS BIGINT), 51)) > 0,
        1,
        NULL
      )
    ) AS dni_passback_count
  FROM ${bcv_ad}
  WHERE
    request__context__video_cro_network_id = 386345
    AND CARDINALITY(
      ARRAY_INTERSECT(
        request__context__site_section_chain__content_owner__network_id,
        ARRAY[CAST('629' AS BIGINT)]
      )
    ) > 0
  GROUP BY
    1,
    2
)
SELECT
  date,
  COUNT(DISTINCT request__transaction_id) AS only_blipvert_requests
FROM tx_ads
WHERE
  (
    (
      blipvert_count > 0 AND sky_priority_count = 0
    ) AND wbd_passback_count = 0
  )
  AND dni_passback_count = 0
GROUP BY
  1
ORDER BY
  1 DESC
