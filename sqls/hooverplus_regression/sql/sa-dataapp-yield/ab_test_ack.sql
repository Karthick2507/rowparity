-- account:    sa-dataapp-yield
SELECT
  DATE_TRUNC('HOUR', ack__timestamp) AS timestamp,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(request__context__site_section_id, -1) AS site_section_id,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  request__server_pool AS server_pool,
  IF(BITWISE_AND(request__flags, 64) > 0, 'true', 'false') AS is_filtered,
  IF(BITWISE_AND(request__extra_flags2, 8) > 0, 'true', 'false') AS is_ssp_bidder_traffic,
  IF(
    BITWISE_AND(request__extra_flags2, 65536) > 0
    AND request__context__request_format = 1,
    'true',
    'false'
  ) AS is_sspu_vast_traffic,
  IF(
    BITWISE_AND(request__extra_flags2, 65536) > 0
    AND request__context__request_format = 7,
    'true',
    'false'
  ) AS is_sspu_ortb_traffic,
  IF(BITWISE_AND(request__extra_flags2, 2097152) > 0, 'true', 'false') AS is_ssp_dynamic_pod,
  t.bucket_id AS bucket_id,
  SUM(
    IF(
      COALESCE(ack__metrics__ad_impression, 0) > 0,
      COALESCE(t.revenue, 0) * COALESCE(ack__metrics__fire_event_revenue_ratio, 0),
      0
    )
  ) AS ack_ad_revenue,
  SUM(
    CASE
      WHEN candidate__integration_type IN ('openrtb_normal')
      THEN COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000
      ELSE 0
    END
  ) AS ack_prog_ad_revenue_usd
FROM ${bcv_ack}
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
CROSS JOIN UNNEST(request__context__ab_test_item__bucket_id) AS t(bucket_id)
CROSS JOIN UNNEST(partners__role, partners__revenue) AS t(network_role, revenue)
WHERE
  (
    (
      network_role = 'cro' AND ack__ack_entity_type = 'ad'
    )
    AND CARDINALITY(COALESCE(request__context__ab_test_item__bucket_id, ARRAY[])) > 0
  )
  AND COALESCE(ack__metrics__ad_impression, 0) > 0
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  11,
  12,
  13,
  14,
  15
