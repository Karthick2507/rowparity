-- account:    sa-dataapp-yield
-- skeleton:   e9f1d6259bdbc1d9030f244ef7e6ad0e
-- pattern:    fe7188b94e2e09bec5f05c0699d6874d  (700 execution(s))
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
  SUM(IF(request__is_first_request, COALESCE(request__log_sampling__magnifier, 1), 0)) AS req_ad_request,
  SUM(
    IF(
      request__is_first_request,
      IF(
        CARDINALITY(COALESCE(request__advertisements__flags, ARRAY[])) = 0,
        COALESCE(request__log_sampling__magnifier, 1),
        0
      ),
      0
    )
  ) AS req_empty_ad_response,
  SUM(
    IF(
      request__is_first_request,
      CARDINALITY(COALESCE(request__bidding_context__bid_request__impression__index, ARRAY[])) * COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS ad_request_impression,
  SUM(
    IF(
      request__is_first_request,
      CARDINALITY(COALESCE(request__slots__environment, ARRAY[])) * COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS slots,
  SUM(
    IF(
      request__is_first_request,
      CARDINALITY(COALESCE(request__advertisements__ad_id, ARRAY[])) * COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS ad_delivered_ad,
  SUM(
    IF(
      request__is_first_request,
      CARDINALITY(COALESCE(request__rtb_auction__integration_type, ARRAY[])) * COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS auction_request,
  SUM(
    IF(
      request__is_first_request,
      CARDINALITY(
        FILTER(
          COALESCE(request__external_candidate_ad__bid_status, ARRAY[]),
          x -> (
            BITWISE_AND(x, 1) = 1
          )
        )
      ) * COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS bids_received,
  SUM(
    IF(
      request__is_first_request,
      CARDINALITY(
        FILTER(
          COALESCE(request__external_candidate_ad__bid_status, ARRAY[]),
          x -> (
            BITWISE_AND(x, 9) = 1
          )
        )
      ) * COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS bids_filtered,
  SUM(
    IF(
      request__is_first_request,
      CARDINALITY(
        FILTER(
          COALESCE(request__external_candidate_ad__bid_status, ARRAY[]),
          x -> (
            BITWISE_AND(x, 8) = 8
          )
        )
      ) * COALESCE(request__log_sampling__magnifier, 1),
      0
    )
  ) AS bids_delivered,
  SUM(
    REDUCE(COALESCE(acks__metrics__ad_impression, ARRAY[]), 0, (s, x) -> s + x, s -> s)
  ) AS ack_ad_impression
FROM ${bcv_transaction}
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
CROSS JOIN UNNEST(request__context__ab_test_item__bucket_id) AS t(bucket_id)
WHERE
  (
    request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
  )
  AND CARDINALITY(COALESCE(request__context__ab_test_item__bucket_id, ARRAY[])) > 0
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
