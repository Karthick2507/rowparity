-- account:    sa-realtime
-- skeleton:   a357dbef64149dbef4f81853430c8284
-- pattern:    8c128581421445887cb174ca2433355d  (694 execution(s))
-- in suite:   daily commitment
-- hoover:     ad, request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?
--   process_batch_id IN (?)

WITH custom AS (
  SELECT
    process_batch_id,
    request__kafka_msg_key AS key,
    request__kafka_msg_size AS bytes,
    IF(
      p.sales_channel = 4 AND p.supply_source = 4,
      CAST(auction__network_id AS VARCHAR),
      CAST(p.network_id AS VARCHAR)
    ) AS network_id,
    CASE
      WHEN BITWISE_AND(p.bit_flags, 1099511627776) > 0
      THEN 7
      WHEN BITWISE_AND(p.bit_flags, 1099511627776) = 0
      AND BITWISE_AND(p.bit_flags, 2199023255552) > 0
      THEN 7
      ELSE p.sales_channel
    END AS sales_channel,
    CASE
      WHEN BITWISE_AND(p.bit_flags, 2199023255552) > 0
      THEN 7
      ELSE p.supply_source
    END AS supply_source
  FROM ${bcv_ad}
  CROSS JOIN UNNEST(partners__network_id, partners__bit_flags, partners__supply_source, partners__sales_channel, partners__role) AS p(network_id, bit_flags, supply_source, sales_channel, role)
  WHERE
    role IN ('cro', 'r')
), tmp AS (
  SELECT
    process_batch_id,
    key,
    bytes,
    network_id,
    ARRAY_SORT(
      SPLIT(
        (
          CONCAT(CAST(supply_source AS VARCHAR), ',', CAST(sales_channel AS VARCHAR))
        ),
        ','
      )
    ) AS products
  FROM custom
), base AS (
  SELECT
    process_batch_id,
    key,
    bytes,
    network_id,
    product_number,
    COUNT(1) AS network_product_count
  FROM tmp
  CROSS JOIN UNNEST(products) AS t(product_number)
  GROUP BY
    1,
    2,
    3,
    4,
    5
), flat AS (
  SELECT
    process_batch_id,
    key,
    bytes,
    network_id,
    product_number,
    network_product_count,
    CAST(network_product_count AS DOUBLE) / SUM(network_product_count) OVER (PARTITION BY key) * bytes AS network_product_bytes
  FROM base
)
SELECT
  SUM(network_product_bytes) AS usage,
  CASE
    WHEN product_number = '1' OR product_number = '2'
    THEN 'o&o'
    WHEN product_number = '3'
    THEN 'mrm_rule'
    WHEN product_number = '4'
    THEN 'prog_mod'
    WHEN product_number = '5'
    THEN 'mpp'
    WHEN product_number = '6'
    THEN 'mpe'
    WHEN product_number = '7'
    THEN 'partner_tag'
    ELSE 'o&o'
  END AS product,
  CAST(network_id AS VARCHAR) AS network,
  process_batch_id AS custom_col,
  1 AS flag
FROM flat
GROUP BY
  2,
  3,
  4,
  5
UNION ALL
(
  SELECT
    CAST(SUM(request__kafka_msg_size) AS DOUBLE) AS usage,
    'o&o' AS product,
    CASE
      WHEN NOT request__context__video_cro_network_id IS NULL
      AND request__context__video_cro_network_id <> -1
      THEN CAST(request__context__video_cro_network_id AS VARCHAR)
      ELSE CAST(request__context__network_id AS VARCHAR)
    END AS network,
    process_batch_id AS custom_col,
    0 AS flag
  FROM ${bcv_request}
  WHERE
    request__advertisement_count = 0
  GROUP BY
    2,
    3,
    4,
    5
)
