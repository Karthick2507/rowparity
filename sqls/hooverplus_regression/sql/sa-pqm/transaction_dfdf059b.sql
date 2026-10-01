-- account:    sa-pqm
-- skeleton:   a2d6a3b1091540893642c8c20482f77a
-- pattern:    dfdf059bcc8c712db2d6d4ee42eda45a  (1 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  *
FROM (
  SELECT
    request__context__video_cro_network_id AS video_cro_network_id,
    COUNT(*) AS requests,
    COUNT_IF(BITWISE_AND(COALESCE(request__extra_flags3, 0), 1024) > 0) AS fits_response_requests,
    COUNT_IF(BITWISE_AND(COALESCE(request__extra_flags3, 0), 2048) > 0) AS contextual_targeted_requests,
    COUNT_IF(BITWISE_AND(COALESCE(request__extra_flags3, 0), 4096) > 0) AS fits_timeout_requests,
    COUNT_IF(COALESCE(CARDINALITY(aim_info__aim_contextual_audience_info), 0) > 0) AS contextual_aim_info_requests
  FROM ${bcv_transaction}
  WHERE
    (
      BITWISE_AND(COALESCE(request__extra_flags3, 0), 7168) > 0
      OR COALESCE(CARDINALITY(aim_info__aim_contextual_audience_info), 0) > 0
      OR COALESCE(aim_info__fits_metadata_version, '') <> ''
    )
  GROUP BY
    1
  ORDER BY
    requests DESC
  LIMIT 50
) AS query_limit_wrapper
