-- account:    dliss299
-- skeleton:   6929200e3603a0a816adba2a36790147
-- pattern:    e524a91479ba97bc0ddf99369af96b7f  (2 execution(s))
-- in suite:   column coverage
-- hoover:     request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_FORMAT(request__timestamp, '%y-%m-%d') AS request_date,
  request__context__network_id AS network_id,
  request__context__standard_endpoint_id AS endpoint_id,
  visitor__standard_device_type_child_id AS standard_device_type_child_id,
  request__bid_request__app_bundle AS app_bundle,
  APPROX_DISTINCT(request__transaction_id) AS unique_ad_requests,
  APPROX_DISTINCT(visitor__user_id) AS unique_user_id,
  APPROX_DISTINCT(visitor__address) AS unique_ip_addr,
  APPROX_DISTINCT(visitor__peer_address) AS unique_ip_peer_addr
FROM ${bcv_request}
WHERE
  NOT visitor__user_id IS NULL
GROUP BY
  1,
  2,
  3,
  4,
  5
