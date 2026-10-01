-- account:    sa-presto-tier2
-- skeleton:   db8b3ed86aa3faa68ee54da9e0636c38
-- pattern:    9d4662d29ec86563f4165024dffa49e2  (30 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp <= CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__context__network_id AS distributor_network_id,
  n.name AS distributor_network_name,
  request__context__profile_id AS profile_id,
  request__context__profile_type,
  CASE
    WHEN request__context__profile_type = 'compound'
    THEN cp.name
    WHEN request__context__profile_type = 'normal'
    THEN p.name
    ELSE 'n/a'
  END AS profile_name,
  COUNT(1) AS request_num,
  COUNT_IF(request__traffic_type = 1 AND NOT visitor__filtration_reason IN (23, 24)) AS "pre-filter ivt request",
  COUNT_IF(
    request__traffic_type = 1
    AND visitor__filtration_reason IN (23, 24)
    AND NOT request__prebid_sivt__whiteops IS NULL
  ) AS "hmn ivt request",
  COUNT_IF(
    request__traffic_type = 1
    AND visitor__filtration_reason IN (23, 24)
    AND NOT request__prebid_sivt__inhouse IS NULL
  ) AS "in-house prebid ivt request",
  COUNT_IF(request__traffic_type = 1 AND NOT visitor__filtration_reason IN (23, 24)) * 100.00 / COUNT(1) AS "pre-filter ivt request ratio",
  COUNT_IF(
    request__traffic_type = 1
    AND visitor__filtration_reason IN (23, 24)
    AND NOT request__prebid_sivt__whiteops IS NULL
  ) * 100.00 / COUNT(1) AS "hmn ivt request ratio",
  COUNT_IF(
    request__traffic_type = 1
    AND visitor__filtration_reason IN (23, 24)
    AND NOT request__prebid_sivt__inhouse IS NULL
  ) * 100.00 / COUNT(1) AS "in-house prebid ivt request ratio"
FROM ${bcv_request}
LEFT JOIN db.default.d_ad_environment_compound_profile AS cp
  ON cp.id = request__context__profile_id
  AND request__context__profile_type = 'compound'
LEFT JOIN db.default.d_ad_environment_profile AS p
  ON p.id = request__context__profile_id AND request__context__profile_type = 'normal'
LEFT JOIN db.default.d_network AS n
  ON n.id = request__context__network_id
GROUP BY
  1,
  2,
  3,
  4,
  5
