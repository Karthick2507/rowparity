-- account:    ychan375
-- skeleton:   aadac645776bf860c8ef41a3198267a4
-- pattern:    adf74779b605d5a755c1fc6e20d32219  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE(request__timestamp) AS ack_event_date,
  CASE
    WHEN COALESCE(visitor__filtration_reason, 0) = 1
    THEN 'filtered_by_white_list'
    WHEN COALESCE(visitor__filtration_reason, 0) = 2
    THEN 'filtered_by_black_list'
    WHEN COALESCE(visitor__filtration_reason, 0) = 5
    THEN 'filtered_by_address'
    WHEN COALESCE(visitor__filtration_reason, 0) = 6
    THEN 'filtered_by_invalid_request'
    WHEN COALESCE(visitor__filtration_reason, 0) = 7
    THEN 'filtered_by_internal_error'
    WHEN COALESCE(visitor__filtration_reason, 0) = 8
    THEN 'filtered_by_ptiling'
    WHEN COALESCE(visitor__filtration_reason, 0) = 9
    THEN 'filtered_by_dot'
    WHEN COALESCE(visitor__filtration_reason, 0) = 11
    THEN 'filtered_by_network_invalid_traffic_but_serve'
    WHEN COALESCE(visitor__filtration_reason, 0) = 12
    THEN 'filtered_by_black_list_but_serve'
    WHEN COALESCE(visitor__filtration_reason, 0) = 13
    THEN 'filtered_by_address_but_serve'
    WHEN COALESCE(visitor__filtration_reason, 0) = 14
    THEN 'filtered_by_domain'
    WHEN COALESCE(visitor__filtration_reason, 0) = 15
    THEN 'filtered_by_domain_but_serve'
    WHEN COALESCE(visitor__filtration_reason, 0) = 16
    THEN 'filtered_by_network_invalid_domain'
    WHEN COALESCE(visitor__filtration_reason, 0) = 17
    THEN 'filtered_by_network_invalid_domain_but_serve'
    WHEN COALESCE(visitor__filtration_reason, 0) = 18
    THEN 'filtered_by_browser_prefetch_but_serve'
    WHEN COALESCE(visitor__filtration_reason, 0) = 19
    THEN 'filtered_by_app_bundle_but_serve'
    WHEN COALESCE(visitor__filtration_reason, 0) = 20
    THEN 'filtered_by_linear_faked_psn_but_serve'
    WHEN COALESCE(visitor__filtration_reason, 0) = 21
    THEN 'filtered_by_debug_internal_call_but_serve'
    WHEN COALESCE(visitor__filtration_reason, 0) = 22
    THEN 'filtered_by_capnedit_but_serve'
    WHEN COALESCE(visitor__filtration_reason, 0) = 23
    THEN 'filtered_by_prebid_detection'
    WHEN COALESCE(visitor__filtration_reason, 0) = 24
    THEN 'filtered_by_prebid_detection_but_serve'
  END AS front_end_filtration_code,
  CASE
    WHEN BITWISE_AND(request__backend_filtration_reason, 1) > 0
    THEN 'consecutive_click'
    WHEN BITWISE_AND(request__backend_filtration_reason, 2) > 0
    THEN 'extreme_impression_click_ad'
    WHEN BITWISE_AND(request__backend_filtration_reason, 4) > 0
    THEN 'high_ctr'
    WHEN BITWISE_AND(request__backend_filtration_reason, 8) > 0
    THEN 'repeat_transactions'
    WHEN BITWISE_AND(request__backend_filtration_reason, 16) > 0
    THEN 'speed_of_transactions'
    WHEN BITWISE_AND(request__backend_filtration_reason, 32) > 0
    THEN 'interval_testing'
    WHEN BITWISE_AND(request__backend_filtration_reason, 64) > 0
    THEN 'datacenter'
    WHEN BITWISE_AND(request__backend_filtration_reason, 128) > 0
    THEN 'nonprefetch'
    WHEN BITWISE_AND(request__backend_filtration_reason, 256) > 0
    THEN 'prefetch'
    WHEN BITWISE_AND(request__backend_filtration_reason, 512) > 0
    THEN 'ctr'
    WHEN BITWISE_AND(request__backend_filtration_reason, 1024) > 0
    THEN 'vod_outlier_identification'
    WHEN BITWISE_AND(request__backend_filtration_reason, 2048) > 0
    THEN 'vod_repeat_acks'
    WHEN BITWISE_AND(request__backend_filtration_reason, 4096) > 0
    THEN 'vod_repeat_transactions'
    WHEN BITWISE_AND(request__backend_filtration_reason, 8192) > 0
    THEN 'vod_ad_speed_of_transactions'
    WHEN BITWISE_AND(request__backend_filtration_reason, 16384) > 0
    THEN 'inactivity'
    WHEN BITWISE_AND(request__backend_filtration_reason, 32768) > 0
    THEN 'malicious_ip'
    WHEN BITWISE_AND(ack__extra_flags, 1) > 0 AND BITWISE_AND(ack__flags, 1048576) > 0
    THEN 'programmatic_duplicate_ack'
    WHEN BITWISE_AND(ack__extra_flags, 1) > 0 AND BITWISE_AND(ack__flags, 1048576) = 0
    THEN 'nonprogrammatic_duplicate_ack'
  END AS backend_filtration,
  SUM(ack__metrics__raw_ad_impression) AS gross_counted,
  SUM(IF(ack__traffic_type = 0, ack__metrics__raw_ad_impression, 0)) AS net_counted,
  SUM(IF(ack__traffic_type = 1, ack__metrics__raw_ad_impression, 0)) AS frontend_ivt,
  SUM(IF(ack__traffic_type = 2, ack__metrics__raw_ad_impression, 0)) AS backend_ivt,
  SUM(IF(ack__traffic_type <> 0, ack__metrics__raw_ad_impression, 0)) * 100.00 / SUM(ack__metrics__raw_ad_impression) AS ivt_ratio
FROM ${bcv_ack}
GROUP BY
  1,
  2,
  3
