-- account:    sa-presto-tier2
-- skeleton:   cc576d733b9e6b7b6128f08ee30cec7b
-- pattern:    b9f71bdd2b0911787bfae9941237efe2  (1 execution(s))
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
  COUNT_IF(NOT transaction__aim_info__aim_identity_info__metadata_version IS NULL) AS with_aim_metadata,
  COUNT_IF(CARDINALITY(transaction__aim_info__aim_audience_info__aim_audience_id) > 0) AS with_aim_audiences,
  ROUND(
    COUNT_IF(NOT transaction__aim_info__aim_identity_info__metadata_version IS NULL) * 100.0 / COUNT(*),
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
