-- account:    sa-dataapp-yield
-- skeleton:   bbc2d7db074a9204c495158a7fd8f2bb
-- pattern:    b2f597913e304d2ccecc567a342aae7c  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(request__context__distributor_network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  CASE
    WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
    AND request__context__request_format = 1
    THEN 'sspu vast'
    WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
    AND request__context__request_format = 7
    THEN 'sspu ortb'
    WHEN BITWISE_AND(request__extra_flags3, 1) > 0
    THEN 'streaminghub openrtb'
    WHEN BITWISE_AND(request__extra_flags2, 8) > 0
    AND COALESCE(request__server_pool, 'na') = 'ads-sfx'
    THEN 'smi bidder'
    WHEN BITWISE_AND(request__extra_flags2, 8) > 0
    THEN 'mrm bidder'
    WHEN request__delivery_method = 'gateway'
    THEN 'linear - scheduled based'
    WHEN (
      BITWISE_AND(request__extra_flags, 1024) > 0
      AND BITWISE_AND(request__extra_flags, 16384) > 0
    )
    OR BITWISE_AND(request__extra_flags, 128) > 0
    THEN 'linear - gateway dai'
    WHEN (
      BITWISE_AND(request__extra_flags, 1024) > 0
      AND BITWISE_AND(request__extra_flags, 67108864) > 0
    )
    THEN 'linear - ip player'
    WHEN BITWISE_AND(request__extra_flags, 1024) > 0
    OR request__delivery_method = 'casucpsu'
    THEN 'linear - stb dai'
    WHEN request__visitor__user_agent_device_type = 'set top box'
    THEN 'stb vod'
    WHEN BITWISE_AND(request__flags, 8) > 0
    AND request__visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - live ott'
    WHEN BITWISE_AND(request__flags, 8) > 0
    AND NOT request__visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - live others'
    WHEN BITWISE_AND(request__flags, 8) = 0
    AND request__visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - non-live ott'
    WHEN BITWISE_AND(request__flags, 8) = 0
    AND NOT request__visitor__user_agent_device_type IN ('smart tv', 'game console')
    THEN 'digital - non-live others'
    ELSE 'na'
  END AS service_type,
  COALESCE(request__visitor__user_agent_device_type, 'na') AS platform,
  COALESCE(request__server_group, 'na') AS server_group,
  IF(BITWISE_AND(request__extra_flags, 16777216) > 0, 'true', 'false') AS is_mkpl,
  IF(request__is_first_request, 'true', 'false') AS is_first_request,
  COUNT(1) AS req_ad_request,
  SUM(request__request_byte_size) AS req_request_byte_size,
  SUM(COALESCE(request__kafka_msg_size, 0)) AS req_raw_request_byte_size,
  MAX(COALESCE(request__kafka_msg_size, 0)) AS max_raw_request_byte_size,
  MAX(request__request_byte_size) AS max_unnest_request_byte_size,
  MAX(
    IF(
      COALESCE(request__kafka_msg_size, 0) > 0,
      request__request_byte_size * 1.00 / request__kafka_msg_size,
      0
    )
  ) AS max_ratio_raw_unnest,
  AVG(
    IF(
      COALESCE(request__kafka_msg_size, 0) > 0,
      request__request_byte_size * 1.00 / request__kafka_msg_size,
      0
    )
  ) AS avg_ratio_raw_unnest,
  ROUND(SUM(CARDINALITY(request__rtb_auction__integration_type))) AS transaction_auction_count,
  ROUND(SUM(CARDINALITY(request__context__key_value__key))) AS transaction_kv_count,
  ROUND(SUM(CARDINALITY(request__network_execution_ctx__data_right__field))) AS transaction_data_right_count,
  ROUND(SUM(CARDINALITY(request__external_candidate_ad__ad_id))) AS transaction_candidate_count,
  ROUND(SUM(CARDINALITY(request__advertisements__ad_id))) AS transaction_ad_count,
  ROUND(SUM(CARDINALITY(request__slots__environment))) AS transaction_slot_count,
  SUM(
    IF(
      CARDINALITY(COALESCE(request__advertisements__flags, ARRAY[])) = 0,
      request__request_byte_size,
      0
    )
  ) AS req_empty_response_size,
  SUM(
    IF(
      CARDINALITY(COALESCE(request__advertisements__flags, ARRAY[])) = 0,
      request__kafka_msg_size,
      0
    )
  ) AS req_empty_response_raw_size,
  COUNT_IF(CARDINALITY(COALESCE(request__advertisements__flags, ARRAY[])) = 0) AS req_empty_response
FROM ${bcv_transaction} AS t
LEFT JOIN db.default.d_network AS nw
  ON t.request__context__video_cro_network_id = nw.id
LEFT JOIN db.default.d_network AS d_nw
  ON t.request__context__distributor_network_id = d_nw.id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  (
    request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
  )
  AND request__is_first_request
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
  12
