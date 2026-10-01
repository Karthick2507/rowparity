-- account:    sa-trust_standards
-- skeleton:   9a584689f726e9aaf9c629e8e07659c5
-- pattern:    93be09780e1f14ee41df5852ce88a05d  (115 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE_TRUNC(?, CURRENT_TIMESTAMP) - INTERVAL ? HOUR
--   request__timestamp >= DATE_TRUNC(?, CURRENT_TIMESTAMP) - INTERVAL ? HOUR

SELECT
  *,
  date AS _arena_partition_date
FROM (
  SELECT
    pageauthority AS domain,
    'sfx' AS origin,
    DATE_TRUNC('HOUR', DATE_ADD('HOUR', -9, CAST('${as_of_ts}' AS TIMESTAMP))) AS date,
    CAST('${as_of_ts}' AS TIMESTAMP) AS updated,
    COUNT(1) AS request_num
  FROM glue_sfx_us.sfxraw."rq"
  WHERE
    (
      (
        NOT pageauthority IS NULL AND requestblockingtype IS NULL
      )
      AND batch >= CAST(DATE_FORMAT(DATE_ADD('HOUR', -9, CAST('${as_of_ts}' AS TIMESTAMP)), '%y%m%d%h') AS BIGINT)
    )
    AND batch < CAST(DATE_FORMAT(DATE_ADD('HOUR', -3, CAST('${as_of_ts}' AS TIMESTAMP)), '%y%m%d%h') AS BIGINT)
  GROUP BY
    pageauthority
  UNION ALL
  SELECT
    IF(
      CARDINALITY(SPLIT(visitor__referrer, '://')) = 1,
      URL_EXTRACT_HOST(CONCAT('http://', visitor__referrer)),
      CONCAT(
        CONCAT(URL_EXTRACT_PROTOCOL(visitor__referrer), '://'),
        URL_EXTRACT_HOST(visitor__referrer)
      )
    ) AS domain,
    'mrm' AS origin,
    DATE_TRUNC('HOUR', DATE_ADD('HOUR', -9, CAST('${as_of_ts}' AS TIMESTAMP))) AS date,
    CAST('${as_of_ts}' AS TIMESTAMP) AS updated,
    COUNT(1) AS request_num
  FROM ${bcv_request}
  WHERE
    (
      NOT visitor__referrer IS NULL AND visitor__referrer <> ''
    )
    AND visitor__referrer <> 'null'
  GROUP BY
    1
) AS arena_tmp
