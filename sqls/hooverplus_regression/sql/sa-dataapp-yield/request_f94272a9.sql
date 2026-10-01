-- account:    sa-dataapp-yield
-- skeleton:   018f7400bcfefa76875f5b34e193de4e
-- pattern:    f94272a94c7121f3d614089ff71410c4  (2 execution(s))
-- in suite:   column coverage
-- hoover:     request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP) + INTERVAL ? DAY
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  CAST('2026-08-01 00:00:00' AS TIMESTAMP) AS "timestamp",
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  APPROX_DISTINCT(visitor__server_side_user_id) AS distinct_user_id_num_in_2_days,
  APPROX_DISTINCT(
    IF(
      request__timestamp >= CAST('2026-08-01 00:00:00' AS TIMESTAMP)
      AND request__timestamp < CAST('2026-08-01 00:00:00' AS TIMESTAMP) + INTERVAL '1' DAY,
      visitor__server_side_user_id,
      NULL
    )
  ) AS distinct_user_id_num_in_1_day,
  COUNT_IF(
    request__timestamp >= CAST('2026-08-01 00:00:00' AS TIMESTAMP)
    AND request__timestamp < CAST('2026-08-01 00:00:00' AS TIMESTAMP) + INTERVAL '1' DAY
  ) AS traffic_in_1_day,
  COUNT(*) AS traffic_in_2_days
FROM ${bcv_request}
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  NOT visitor__server_side_user_id IS NULL
GROUP BY
  1,
  2,
  3
