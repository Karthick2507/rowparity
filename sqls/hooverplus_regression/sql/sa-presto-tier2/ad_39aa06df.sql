-- account:    sa-presto-tier2
-- skeleton:   89f3119b6a8c59c36caa78e6a38e2452
-- pattern:    39aa06dfca088b3d3103bca4d6a59c8f  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH passback_only_txns AS (
  SELECT
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
    1
)
SELECT
  'passback only (no sky, no blipvert)' AS scenario,
  COUNT(*) AS ad_request_count
FROM passback_only_txns
WHERE
  (
    blipvert_count = 0 AND sky_ad_count = 0
  ) AND passback_count > 0
