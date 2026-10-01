-- account:    sa-presto-tier2
-- skeleton:   bb13d9f4b284e50945541ad6381b4085
-- pattern:    ff5f556135e59f457a65ae6b6555257a  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH transaction_ads AS (
  SELECT
    request__transaction_id,
    DATE_FORMAT(request__timestamp, '%y-%m-%d') AS date,
    MAX(IF(advertisement__ad_id = 92683573, 1, 0)) AS has_blipvert,
    MAX(
      IF(
        advertisement__request__context__distributor_network_id = 144750
        AND advertisement__ad_id <> 92683573,
        1,
        0
      )
    ) AS has_sky_priority_ads,
    MAX(IF(CONTAINS(partners__network_id, CAST('191701' AS BIGINT)), 1, 0)) AS has_wbd_passback,
    MAX(
      IF(
        CONTAINS(partners__network_id, CAST('386345' AS BIGINT))
        AND BITWISE_AND(COALESCE(partners__bit_flags, 0), BITWISE_LEFT_SHIFT(CAST(1 AS BIGINT), 51)) > 0,
        1,
        0
      )
    ) AS has_dni_passback
  FROM ${bcv_ad}
  WHERE
    (
      request__is_first_request = TRUE AND video_cro_network_id = 386345
    )
    AND CONTAINS(
      FLATTEN(request__context__site_section_chain__content_owner__network_id),
      CAST('629' AS BIGINT)
    )
  GROUP BY
    1,
    2
)
SELECT
  date,
  COUNT(DISTINCT request__transaction_id) AS only_blipvert_requests
FROM transaction_ads
WHERE
  (
    (
      has_blipvert = 1 AND has_sky_priority_ads = 0
    ) AND has_wbd_passback = 0
  )
  AND has_dni_passback = 0
GROUP BY
  1
ORDER BY
  1 DESC
