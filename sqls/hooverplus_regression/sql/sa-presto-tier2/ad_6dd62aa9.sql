-- account:    sa-presto-tier2
-- skeleton:   e8612b64d36a69fb20b73392e61b13b0
-- pattern:    6dd62aa91cd398c394fca50b43a5f5d2  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH blipvert_txns AS (
  SELECT
    request__transaction_id,
    COUNT(DISTINCT advertisement__ad_id) AS ad_count,
    COUNT_IF(advertisement__ad_id = 92683573) AS blipvert_count,
    COUNT_IF(CONTAINS(partners__network_id, CAST('191701' AS BIGINT))) AS wbd_count,
    COUNT_IF(
      CONTAINS(partners__network_id, CAST('386345' AS BIGINT))
      AND advertisement__ad_id <> 92683573
    ) AS dni_passback_count
  FROM ${bcv_ad}
  WHERE
    request__context__video_cro_network_id = 386345
    AND request__context__standard_endpoint_id = 629
  GROUP BY
    1
)
SELECT
  'only blipverts' AS scenario,
  COUNT(*) AS ad_request_count
FROM blipvert_txns
WHERE
  (
    (
      blipvert_count > 0 AND ad_count = 1
    ) AND wbd_count = 0
  )
  AND dni_passback_count = 0
