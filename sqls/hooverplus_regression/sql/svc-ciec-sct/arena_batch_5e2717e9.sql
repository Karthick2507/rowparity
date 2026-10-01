-- account:    svc-ciec-sct
-- skeleton:   1b4987ca9251d90ff337a16bad94f92c
-- pattern:    5e2717e90bb66b61eddf9c2d137caf1d  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     ack, auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id < CONCAT(DATE_FORMAT(DATE_ADD(?, -?, CAST(? AS TIMESTAMP)), ?), ?)
--   process_batch_id >= CONCAT(DATE_FORMAT(DATE_ADD(?, -?, CAST(? AS TIMESTAMP)), ?), ?)

SELECT
  process_batch_id,
  LOWER(publisher_id) AS publisher_id,
  LOWER(sub_name) AS sub_name,
  LOWER(sub_type) AS sub_type,
  SUM(request_number) AS bid_request,
  SUM(impression_number) AS impression,
  CAST(0 AS DOUBLE) AS revenue,
  CONCAT(
    SUBSTR(process_batch_id, 1, 4),
    '-',
    SUBSTR(process_batch_id, 5, 2),
    '-',
    SUBSTR(process_batch_id, 7, 2)
  ) AS date
FROM (
  SELECT
    process_batch_id,
    CASE
      WHEN net.inbound_order_type = 'exchange_order'
      THEN CONCAT(CAST(net.co_network_id AS VARCHAR), '-', CAST(net.network_id AS VARCHAR))
      ELSE CAST(net.network_id AS VARCHAR)
    END AS publisher_id,
    CASE
      WHEN NOT auction__site_domain IS NULL
      THEN auction__site_domain
      WHEN NOT auction__app_bundle IS NULL
      THEN auction__app_bundle
      ELSE ''
    END AS sub_name,
    CASE
      WHEN NOT auction__site_domain IS NULL
      THEN 'site_domain'
      WHEN NOT auction__app_bundle IS NULL
      THEN 'app_bundle'
      ELSE ''
    END AS sub_type,
    COUNT(1) AS request_number,
    0 AS impression_number
  FROM ${bcv_auction}
  CROSS JOIN UNNEST(partners__entity_source, partners__network_id, partners__content_owner_network_id, partners__inbound_order_type, partners__sales_channel) AS net(entity_source, network_id, co_network_id, inbound_order_type, sales_channel)
  WHERE
    (
      auction__integration_type IN ('normal', 'pg_td')
      AND net.entity_source = 'auction'
    )
    AND net.sales_channel = 4
  GROUP BY
    1,
    2,
    3,
    4
  UNION ALL
  SELECT
    process_batch_id,
    CASE
      WHEN net.inbound_order_type = 'exchange_order'
      THEN CONCAT(CAST(net.co_network_id AS VARCHAR), '-', CAST(net.network_id AS VARCHAR))
      ELSE CAST(net.network_id AS VARCHAR)
    END AS publisher_id,
    CASE
      WHEN NOT auction__site_domain IS NULL
      THEN auction__site_domain
      WHEN NOT auction__app_bundle IS NULL
      THEN auction__app_bundle
      ELSE ''
    END AS sub_name,
    CASE
      WHEN NOT auction__site_domain IS NULL
      THEN 'site_domain'
      WHEN NOT auction__app_bundle IS NULL
      THEN 'app_bundle'
      ELSE ''
    END AS sub_type,
    0 AS request_number,
    SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS impression_number
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(partners__entity_source, partners__network_id, partners__content_owner_network_id, partners__inbound_order_type, partners__sales_channel) AS net(entity_source, network_id, co_network_id, inbound_order_type, sales_channel)
  WHERE
    auction__integration_type IN ('normal', 'pg_td') AND net.sales_channel = 4
  GROUP BY
    1,
    2,
    3,
    4
)
WHERE
  LOWER(sub_name) NOT LIKE '%googlesyndication%'
GROUP BY
  1,
  2,
  3,
  4
HAVING
  SUM(request_number) > 1
