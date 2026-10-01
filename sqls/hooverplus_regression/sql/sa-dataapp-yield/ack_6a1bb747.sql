-- account:    sa-dataapp-yield
-- skeleton:   945668ededdcbcdcaa9715225d302656
-- pattern:    6a1bb7479a881f27d87d665f05298663  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH tmp AS (
  SELECT
    ack__timestamp,
    request__context__network_id,
    request__dro_network_id,
    advertisement__ad_oo_network_id,
    TRANSFORM(advertisement__active_term_id, x -> BITWISE_AND(x / 281474976710656, 255)) AS active_term_sub_type,
    COALESCE(ack__metrics__ad_impression, 0) AS ack__metrics__ad_impression
  FROM ${bcv_ack}
  WHERE
    request__dro_network_id > 0
)
SELECT
  DATE_FORMAT(ack__timestamp, '%y-%m-%d %h:00:00') AS timestamp,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(dis.name, 'na') AS distributor_network_name,
  COALESCE(request__dro_network_id, -1) AS dro_network_id,
  COALESCE(dro.name, 'na') AS dro_network_name,
  COALESCE(advertisement__ad_oo_network_id, -1) AS ad_network_id,
  COALESCE(oo.name, 'na') AS ad_network_name,
  SUM(IF(CONTAINS(active_term_sub_type, 21), ack__metrics__ad_impression, 0)) AS ack_ad_impression_with_audience,
  SUM(IF(CONTAINS(active_term_sub_type, 12), ack__metrics__ad_impression, 0)) AS ack_ad_impression_with_kv,
  SUM(IF(CONTAINS(active_term_sub_type, 2), ack__metrics__ad_impression, 0)) AS ack_ad_impression_with_geo_state,
  SUM(IF(CONTAINS(active_term_sub_type, 3), ack__metrics__ad_impression, 0)) AS ack_ad_impression_with_geo_city,
  SUM(IF(CONTAINS(active_term_sub_type, 4), ack__metrics__ad_impression, 0)) AS ack_ad_impression_with_geo_dma,
  SUM(IF(CONTAINS(active_term_sub_type, 16), ack__metrics__ad_impression, 0)) AS ack_ad_impression_with_geo_postal_code,
  SUM(IF(CONTAINS(active_term_sub_type, 17), ack__metrics__ad_impression, 0)) AS ack_ad_impression_with_geo_postal_code_package,
  SUM(IF(CONTAINS(active_term_sub_type, 19), ack__metrics__ad_impression, 0)) AS ack_ad_impression_with_ua,
  SUM(ack__metrics__ad_impression) AS ack_ad_impression
FROM tmp
LEFT JOIN db.default.d_network AS dro
  ON dro.id = request__dro_network_id
LEFT JOIN db.default.d_network AS dis
  ON dis.id = request__context__network_id
LEFT JOIN db.default.d_network AS oo
  ON oo.id = advertisement__ad_oo_network_id
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7
