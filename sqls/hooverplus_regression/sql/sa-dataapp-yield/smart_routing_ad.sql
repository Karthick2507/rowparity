-- account:    sa-dataapp-yield
-- skeleton:   9c1d8d2f6bdf711641c9337bb211c86d
-- pattern:    c831b379c5f199185adfd8d843e74a4f  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     ad
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH flag AS (
  SELECT
    4261412864 AS smart_routing_baseline,
    16777216 AS smart_routing_applied
)
SELECT
  DATE_FORMAT(request__timestamp, '%y-%m-%d %h:00:00') AS timestamp,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(nw.name, 'na') AS video_cro_network_name,
  COALESCE(co_id, -1) AS mpe_seller_id,
  COALESCE(n_id, -1) AS mpe_buyer_id,
  COALESCE(exchange_listing_id, -1) AS exchange_listing_id,
  IF(
    BITWISE_AND(COALESCE(throttling_flag, 0), smart_routing_baseline) = 0,
    'true',
    'false'
  ) AS is_baseline,
  IF(BITWISE_AND(request__extra_flags2, 65536) = 65536, 'true', 'false') AS is_fw_ssp,
  COUNT(1) AS ad_logged,
  SUM(COALESCE(request__log_sampling__magnifier, 1)) AS ad_actual,
  SUM(
    IF(
      BITWISE_AND(COALESCE(throttling_flag, 0), smart_routing_baseline) = 0,
      COALESCE(request__log_sampling__magnifier, 1) * (
        100 / COALESCE(CAST(throttling_baseline_thousandth AS DOUBLE), 100)
      ),
      0
    )
  ) AS ad_total_est
FROM ${bcv_ad}
LEFT JOIN flag
  ON TRUE
CROSS JOIN UNNEST(partners__network_id, partners__content_owner_network_id, partners__supply_source, partners__inbound_listing_id, partners__network_execution_ctx_flags) AS t(n_id, co_id, supply_source, exchange_listing_ids, throttling_flag)
CROSS JOIN UNNEST(t.exchange_listing_ids) AS ex(exchange_listing_id)
CROSS JOIN UNNEST(request__mpe_matcher_filters__id, request__mpe_matcher_filters__weight, request__mpe_matcher_filters__bucket_id) AS mpe_filter(filter_id, throttling_baseline_thousandth, filter_bucket_id)
LEFT JOIN db.default.d_network AS nw
  ON nw.id = request__context__video_cro_network_id
WHERE
  (
    supply_source = 6 AND filter_id = 3
  )
  AND BITWISE_AND(COALESCE(throttling_flag, 0), smart_routing_applied) = smart_routing_applied
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8
