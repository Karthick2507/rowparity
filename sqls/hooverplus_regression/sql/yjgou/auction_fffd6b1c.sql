-- account:    yjgou
-- skeleton:   b9aaa725cbda9b6e83e09c8db0c397b0
-- pattern:    fffd6b1c55e92420e7760fd0321c32c2  (2 execution(s))
-- in suite:   column coverage
-- hoover:     auction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id IN (?)

WITH custom AS (
  SELECT
    process_batch_id,
    CAST(p.network_id AS VARCHAR) AS network_id,
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
  FROM ${bcv_auction}
  CROSS JOIN UNNEST(partners__network_id, partners__bit_flags, partners__supply_source, partners__sales_channel) AS p(network_id, bit_flags, supply_source, sales_channel)
), tmp AS (
  SELECT
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
)
SELECT
  network_id,
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
    ELSE 'unknown'
  END AS product,
  CAST((
    SUM(1) * 1.000000 / (
      SELECT
        SUM(1)
      FROM tmp
      CROSS JOIN UNNEST(products) AS t(product_number)
    ) * 644019.120412
  ) AS INTEGER) AS size
FROM tmp
CROSS JOIN UNNEST(products) AS t(product_number)
GROUP BY
  1,
  2
