-- account:    sa-presto-tier2
-- skeleton:   77d17b6a0f1f20156608d0309ac2e0af
-- pattern:    72181bab1f43617986278acb6083e654  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
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
  CASE
    WHEN request__context__profile_type = 'compound'
    THEN cp.name
    WHEN request__context__profile_type = 'normal'
    THEN p.name
    ELSE 'n/a'
  END AS profile_name,
  SUM(ack__metrics__raw_ad_impression) AS gross_counted_ads,
  SUM(IF(ack__traffic_type = 2, ack__metrics__raw_ad_impression, 0)) AS post_bid_ivt_impressions,
  SUM(IF(ack__traffic_type = 2, ack__metrics__raw_ad_impression, 0)) * 100.00 / SUM(ack__metrics__raw_ad_impression) AS "post_bid_ivt_ratio",
  SUM(ack__metrics__raw_ad_impression) * 100.00 / SUM(SUM(ack__metrics__raw_ad_impression)) OVER (PARTITION BY request__context__network_id) AS "profile_impression_proportion_by_network"
FROM ${bcv_ack}
LEFT JOIN db.default.d_ad_environment_compound_profile AS cp
  ON cp.id = request__context__profile_id
  AND request__context__profile_type = 'compound'
LEFT JOIN db.default.d_ad_environment_profile AS p
  ON p.id = request__context__profile_id AND request__context__profile_type = 'normal'
LEFT JOIN db.default.d_network AS n
  ON n.id = request__context__network_id
WHERE
  ack__metrics__raw_ad_impression > 0
GROUP BY
  1,
  2,
  3,
  4
