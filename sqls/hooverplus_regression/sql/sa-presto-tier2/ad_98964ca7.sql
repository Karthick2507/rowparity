-- account:    sa-presto-tier2
-- skeleton:   232737baf731aabbf38ad0f363d44494
-- pattern:    98964ca7d6f8f372fe86217125cece0b  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH daily_scenarios AS (
  SELECT
    DATE_FORMAT(request__timestamp, '%y-%m-%d') AS request_date,
    request__transaction_id,
    COUNT_IF(advertisement__ad_id = 92683573) AS blipvert_count,
    COUNT_IF(CONTAINS(partners__network_id, CAST('144750' AS BIGINT))) AS sky_ad_count,
    COUNT_IF(
      CONTAINS(partners__network_id, CAST('191701' AS BIGINT))
      OR CONTAINS(partners__network_id, CAST('386345' AS BIGINT))
    ) AS passback_count
  FROM ${bcv_ad}
  WHERE
    request__context__video_cro_network_id = 386345
    AND request__context__standard_endpoint_id = 629
  GROUP BY
    1,
    2
)
SELECT
  request_date,
  SUM(
    CASE
      WHEN blipvert_count > 0 AND sky_ad_count = 0 AND passback_count = 0
      THEN 1
      ELSE 0
    END
  ) AS only_blipverts,
  SUM(CASE WHEN blipvert_count > 0 AND sky_ad_count > 0 THEN 1 ELSE 0 END) AS sky_priority_plus_blipverts,
  SUM(
    CASE
      WHEN blipvert_count = 0 AND sky_ad_count = 0 AND passback_count > 0
      THEN 1
      ELSE 0
    END
  ) AS passback_only_no_sky_no_blipvert
FROM daily_scenarios
GROUP BY
  1
ORDER BY
  1
