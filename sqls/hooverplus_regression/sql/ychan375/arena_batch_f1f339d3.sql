-- account:    ychan375
-- skeleton:   95b34ce6099e4cf007eac12f68af7be0
-- pattern:    f1f339d3ce6b4f665ff3e9b9d7559b83  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP) - INTERVAL ? DAY
--   request__timestamp >= CAST(? AS TIMESTAMP) - INTERVAL ? DAY

SELECT
  '2026-07-29 00:00:00' AS period,
  DATE(request__timestamp) AS date_time,
  a.visitor__country_id AS country_id,
  a.visitor__country AS country,
  a.visitor__state_id AS state_id,
  b.description AS state,
  SUM(a.ack__metrics__raw_ad_impression) AS impression,
  SUM(IF(ack__traffic_type = 0, ack__metrics__raw_ad_impression, 0)) AS counted_ads,
  SUM(CASE WHEN BITWISE_AND(request__extra_flags, 1048576) > 0 THEN 1 ELSE 0 END) AS ccpa_opt_out,
  SUM(CASE WHEN BITWISE_AND(request__extra_flags, 32) > 0 THEN 1 ELSE 0 END) AS gdpr_opt_out,
  SUM(CASE WHEN BITWISE_AND(request__extra_flags, 4096) > 0 THEN 1 ELSE 0 END) AS lat_opt_out,
  SUM(CASE WHEN BITWISE_AND(request__extra_flags, 8192) > 0 THEN 1 ELSE 0 END) AS lat_fc_opt_out,
  SUM(CASE WHEN BITWISE_AND(request__extra_flags, 512) > 0 THEN 1 ELSE 0 END) AS coppa_opt_out
FROM ${bcv_ack} AS a
LEFT JOIN db.default.d_lu_state AS b
  ON a.visitor__state_id = b.id
WHERE
  a.visitor__country = 'us'
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6
