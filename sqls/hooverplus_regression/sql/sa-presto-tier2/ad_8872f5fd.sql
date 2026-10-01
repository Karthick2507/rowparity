-- account:    sa-presto-tier2
-- skeleton:   a65dbf138a05b29f081281803e245899
-- pattern:    8872f5fdf6af88ff7848c751149aa681  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.

WITH ad_delivery_summary AS (
  SELECT
    advertisement__transaction_id,
    advertisement__request__timestamp,
    DATE_TRUNC('DAY', advertisement__request__timestamp) AS event_date,
    MAX(CASE WHEN advertisement__ad_id = 92683573 THEN 1 ELSE 0 END) AS has_blipvert,
    MAX(
      CASE
        WHEN advertisement__network_id = 144750 AND advertisement__ad_id <> 92683573
        THEN 1
        ELSE 0
      END
    ) AS has_sky_priority_ads,
    MAX(CASE WHEN advertisement__network_id IN (191701, 386345) THEN 1 ELSE 0 END) AS has_passback_ads,
    COUNT(DISTINCT CASE WHEN advertisement__ad_id = 92683573 THEN advertisement__ad_id END) AS blipvert_ad_count,
    COUNT(
      DISTINCT CASE
        WHEN advertisement__network_id = 144750 AND advertisement__ad_id <> 92683573
        THEN advertisement__ad_id
      END
    ) AS sky_priority_ad_count,
    COUNT(
      DISTINCT CASE
        WHEN advertisement__network_id IN (191701, 386345)
        THEN advertisement__ad_id
      END
    ) AS passback_ad_count
  FROM ${bcv_ad}
  WHERE
    (
      (
        (
          advertisement__request__timestamp >= CAST('2026-05-21 00:00:00' AS TIMESTAMP)
          AND advertisement__request__timestamp < CAST('2026-05-22 00:00:00' AS TIMESTAMP)
        )
        AND advertisement__request__context__video_cro_network_id = 386345
      )
      AND advertisement__request__context__standard_endpoint_id = 629
    )
    AND advertisement__request__is_first_request = TRUE
  GROUP BY
    advertisement__transaction_id,
    advertisement__request__timestamp,
    event_date
), categorized_transactions AS (
  SELECT
    event_date,
    advertisement__transaction_id,
    CASE
      WHEN has_blipvert = 1 AND has_sky_priority_ads = 0 AND has_passback_ads = 0
      THEN 'only_blipvert'
      WHEN has_blipvert = 1 AND has_sky_priority_ads = 1
      THEN 'sky_priority_plus_blipvert'
      WHEN has_blipvert = 0 AND has_sky_priority_ads = 0 AND has_passback_ads = 1
      THEN 'passback_only'
      ELSE 'other'
    END AS delivery_scenario,
    blipvert_ad_count,
    sky_priority_ad_count,
    passback_ad_count
  FROM ad_delivery_summary
)
SELECT
  event_date,
  delivery_scenario,
  COUNT(DISTINCT advertisement__transaction_id) AS ad_request_count,
  SUM(blipvert_ad_count) AS total_blipvert_ads,
  SUM(sky_priority_ad_count) AS total_sky_priority_ads,
  SUM(passback_ad_count) AS total_passback_ads
FROM categorized_transactions
WHERE
  delivery_scenario IN ('only_blipvert', 'sky_priority_plus_blipvert', 'passback_only')
GROUP BY
  event_date,
  delivery_scenario
ORDER BY
  event_date DESC,
  delivery_scenario
