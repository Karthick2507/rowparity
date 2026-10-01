-- account:    sa-presto-tier2
-- skeleton:   a94bded9e53188d3d18d661615a63d95
-- pattern:    786bd3bd1219e20814ff55bd04bf7116  (2 execution(s))
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
  DATE(request__timestamp) AS day,
  COUNT(*) AS total_requests,
  COUNT_IF(NOT aim_info__aim_identity_info__metadata_version IS NULL) AS with_aim_metadata,
  COUNT_IF(CARDINALITY(aim_info__aim_audience_info__segments) > 0) AS with_aim_segments,
  ROUND(
    COUNT_IF(NOT aim_info__aim_identity_info__metadata_version IS NULL) * 100.0 / COUNT(*),
    2
  ) AS pct_aim_metadata
FROM ${bcv_transaction}
WHERE
  request__context__video_cro_network_id = 510626
  AND request__is_first_request = TRUE
GROUP BY
  1
ORDER BY
  1
