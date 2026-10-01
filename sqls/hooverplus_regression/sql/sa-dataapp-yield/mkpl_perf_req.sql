-- account:    sa-dataapp-yield
-- skeleton:   a2537e8e3bdaf8d2e731879b92ba9368
-- pattern:    41551b8514735cf0f300e554153dc3b5  (696 execution(s))
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
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(p.name, 'na') AS profile_name,
  COALESCE(request__context__profile_trait__pre_selection_external_ad_timeout, -1) AS pre_selection_external_ad_timeout,
  COALESCE(request__context__profile_trait__post_selection_external_ad_timeout, -1) AS post_selection_external_ad_timeout,
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
  COALESCE(request__server_pool, 'na') AS server_pool,
  COUNT(1) AS req_ad_request_logged,
  SUM(COALESCE(request__log_sampling__magnifier, 1)) AS req_ad_request,
  SUM(
    COALESCE(request__time_record__total, 0) * COALESCE(request__log_sampling__magnifier, 1)
  ) AS req_resp_time,
  SUM(
    IF(request__time_record__total > 3000, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_3000ms,
  SUM(
    IF(request__time_record__total > 2000, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_2000ms,
  SUM(
    IF(request__time_record__total > 1500, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_1500ms,
  SUM(
    IF(request__time_record__total > 1000, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_1000ms,
  SUM(
    IF(request__time_record__total > 500, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_500ms,
  SUM(
    IF(request__time_record__total > 300, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_300ms,
  SUM(
    IF(request__time_record__total > 100, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_100ms,
  SUM(
    IF(request__time_record__total > 50, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_50ms,
  SUM(
    IF(request__time_record__total > 20, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_20ms,
  SUM(
    IF(request__time_record__total > 10, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_10ms,
  SUM(
    IF(request__time_record__total > 5, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_gt_5ms,
  SUM(
    IF(request__time_record__total <= 5, COALESCE(request__log_sampling__magnifier, 1), 0)
  ) AS req_resp_time_lt_5ms,
  SUM(CARDINALITY(request__network_execution_ctx__context_sequence)) AS execution_ctx_nums,
  SUM(
    CARDINALITY(FILTER(request__network_execution_ctx__supply_source_type, x -> x = 'mrm_rule'))
  ) AS rule_buyers,
  SUM(
    CARDINALITY(FILTER(request__network_execution_ctx__supply_source_type, x -> x = 'mpe'))
  ) AS mpe_buyers,
  SUM(
    CARDINALITY(FILTER(request__network_execution_ctx__supply_source_type, x -> x = 'mpp'))
  ) AS mpp_buyers,
  SUM(
    CARDINALITY(
      FILTER(request__network_execution_ctx__supply_source_type, x -> x = 'partner_tag')
    )
  ) AS partner_tag_buyers,
  SUM(
    CARDINALITY(
      ARRAY_DISTINCT(
        FLATTEN(FLATTEN(request__slots__listing_id || request__slots__resellers__listing_id))
      )
    )
  ) AS collected_listings,
  SUM(
    CARDINALITY(
      ARRAY_DISTINCT(
        FILTER(
          request__network_execution_ctx__inbound_listing_id,
          x -> NOT x IS NULL AND CARDINALITY(x) > 0
        )
      )
    )
  ) AS expanded_listings,
  SUM(
    CARDINALITY(
      ARRAY_DISTINCT(FILTER(request__network_execution_ctx__inbound_order_id, x -> NOT x IS NULL))
    )
  ) AS expanded_orders,
  SUM(CARDINALITY(request__slots__flags)) AS slot_nums,
  SUM(CARDINALITY(FLATTEN(request__slots__resellers__outbound_order__order_type))) AS reseller_nums,
  SUM(
    REDUCE(
      TRANSFORM(
        request__slots__outbound_order__order_type,
        x -> CARDINALITY(FILTER(x, y -> y = 'programmatic_order'))
      ),
      CAST(ROW(0.0, 0) AS ROW(sum DOUBLE, count INTEGER)),
      (s, x) -> CAST(ROW(COALESCE(x, 0) + s.sum, s.count + 1) AS ROW(sum DOUBLE, count INTEGER)),
      s -> IF(s.count = 0, 0, s.sum / s.count)
    )
  ) AS per_slot_prog_orders,
  SUM(
    REDUCE(
      TRANSFORM(
        request__slots__resellers__outbound_order__order_type,
        z -> REDUCE(
          TRANSFORM(z, x -> CARDINALITY(FILTER(x, y -> y = 'programmatic_order'))),
          CAST(0 AS BIGINT),
          (s, x) -> s + COALESCE(x, 0),
          s -> s
        )
      ),
      CAST(ROW(0.0, 0) AS ROW(sum DOUBLE, count INTEGER)),
      (s, x) -> CAST(ROW(COALESCE(x, 0) + s.sum, s.count + 1) AS ROW(sum DOUBLE, count INTEGER)),
      s -> IF(s.count = 0, 0, s.sum / s.count)
    )
  ) AS per_slot_reseller_prog_orders,
  SUM(CARDINALITY(request__rtb_auction__index)) AS auction_nums,
  SUM(
    REDUCE(
      FILTER(
        TRANSFORM(
          ZIP(
            request__network_execution_ctx__supply_source_type,
            request__network_execution_ctx__candidate_ad_num,
            request__network_execution_ctx__programmatic_candidate_ad_num
          ),
          r -> CAST(r AS ROW(
            supply_source_type VARCHAR,
            candidate_ad_num BIGINT,
            programmatic_candidate_ad_num BIGINT
          ))
        ),
        x -> x.supply_source_type IN ('mpe', 'partner_tag', 'mpp')
      ),
      0,
      (s, x) -> s + COALESCE(x.candidate_ad_num, 0) + COALESCE(x.programmatic_candidate_ad_num, 0),
      s -> s
    )
  ) AS mkpl_candidate_ad_nums,
  SUM(
    (
      REDUCE(
        request__network_execution_ctx__candidate_ad_num,
        CAST(0 AS BIGINT),
        (s, x) -> s + COALESCE(x, 0),
        s -> s
      ) + REDUCE(
        request__network_execution_ctx__programmatic_candidate_ad_num,
        CAST(0 AS BIGINT),
        (s, x) -> s + COALESCE(x, 0),
        s -> s
      )
    )
  ) AS candidate_ad_nums
FROM ${bcv_transaction}
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_ad_environment_compound_profile AS p
  ON p.id = request__context__profile_id
WHERE
  request__is_first_request = TRUE
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
  14
