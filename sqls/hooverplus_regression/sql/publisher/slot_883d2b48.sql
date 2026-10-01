-- account:    publisher
-- skeleton:   701cb84b693effdf22d892c2f434bf3a
-- pattern:    883d2b48306fffcbcbf803504db743d4  (30 execution(s))
-- in suite:   daily commitment
-- hoover:     slot
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH inventory_split_setting AS (
  SELECT
    clsr.network_id AS network_id,
    n.name AS network_name,
    clsu.listing_id AS listing_id,
    ml.name AS listing_name,
    clsr.split_unit_id AS split_unit_id,
    clsr.inventory_owner_id AS inventory_owner_id,
    invo.inventory_owner_network_id AS inventory_owner_network_id,
    ion.name AS inventory_owner_network_name,
    CASE
      WHEN ml.inventory_split_type = 'all'
      THEN 'all'
      WHEN ml.inventory_split_type = 'brand_and_endpoint_owner'
      THEN 'brand & endpoint owner'
      ELSE 'not split'
    END AS split_type,
    IF(
      ml.inventory_split_type = 'brand_and_endpoint_owner',
      COALESCE(brand.name, 'unknown'),
      'all'
    ) AS brand,
    IF(
      ml.inventory_split_type = 'brand_and_endpoint_owner',
      COALESCE(endpoint_owner.name, 'unknown'),
      'all'
    ) AS endpoint_owner,
    CAST(clsr.percentage AS VARCHAR) || '%' AS split_ratio
  FROM db.default.d_carriage_listing_split_ratio AS clsr
  JOIN db.default.d_carriage_listing_split_unit AS clsu
    ON clsu.id = clsr.split_unit_id
  JOIN db.default.d_mkpl_listing AS ml
    ON ml.id = clsu.listing_id
  JOIN db.default.d_network AS n
    ON n.id = ml.network_id
  JOIN db.default.d_inventory_owner AS invo
    ON invo.id = clsr.inventory_owner_id
  JOIN db.default.d_network AS ion
    ON ion.id = invo.inventory_owner_network_id
  LEFT JOIN db.default.d_lu_mkpl_standard_brand AS brand
    ON brand.id = clsu.brand_id
  LEFT JOIN db.default.d_lu_mkpl_endpoint_owner AS endpoint_owner
    ON endpoint_owner.id = clsu.endpoint_owner_id
  WHERE
    clsr.network_id = 520311
), tmp_seller AS (
  SELECT
    request__timestamp,
    p.network_id AS network_id,
    p.eligible_carriage_listing_split_unit_ids AS eligible_unit_ids,
    IF(
      CARDINALITY(p.ctxs__carriage_listing_split_unit_id) > 0,
      p.ctxs__carriage_listing_split_unit_id,
      ARRAY[carriage_listing_split_unit_id]
    ) AS ctx_split_unit_ids,
    IF(
      CARDINALITY(p.ctxs__carriage_inventory_owner_id) > 0,
      p.ctxs__carriage_inventory_owner_id,
      ARRAY[carriage_inventory_owner_id]
    ) AS ctx_inventory_owner_ids,
    COALESCE(slot__carriage_listing_split_unit_num, 1) AS unit_num
  FROM ${bcv_slot}
  CROSS JOIN UNNEST(partners__network_id, partners__eligible_carriage_listing_split_unit_ids, partners__inventory_distribution_contexts__carriage_listing_split_unit_id, partners__inventory_distribution_contexts__carriage_inventory_owner_id, partners__carriage_listing_split_unit_id, partners__carriage_inventory_owner_id) AS p(network_id, eligible_carriage_listing_split_unit_ids, ctxs__carriage_listing_split_unit_id, ctxs__carriage_inventory_owner_id, carriage_listing_split_unit_id, carriage_inventory_owner_id)
  WHERE
    (
      (
        (
          BITWISE_AND(slot__flags, 64) = 0 AND NOT p.carriage_listing_split_unit_id IS NULL
        )
        AND NOT p.carriage_inventory_owner_id IS NULL
      )
      AND COALESCE(slot__carriage_listing_split_unit_num, 1) > 0
    )
    AND p.network_id = 520311
  UNION ALL
  SELECT
    request__timestamp,
    p.network_id AS network_id,
    p.eligible_carriage_listing_split_unit_ids AS eligible_unit_ids,
    IF(
      CARDINALITY(p.ctxs__carriage_listing_split_unit_id) > 0,
      p.ctxs__carriage_listing_split_unit_id,
      ARRAY[slot__carriage_listing_split_unit_id]
    ) AS ctx_split_unit_ids,
    IF(
      CARDINALITY(p.ctxs__carriage_inventory_owner_id) > 1,
      ARRAY[p.ctxs__carriage_inventory_owner_id[1], slot__seller_sponsor_occupation_on_carriage__seller_inventory_owner_id],
      ARRAY[slot__seller_sponsor_occupation_on_carriage__seller_inventory_owner_id]
    ) AS ctx_inventory_owner_ids,
    COALESCE(slot__seller_sponsor_occupation_on_carriage__seller_sponsor_split_unit_num, 0) AS unit_num
  FROM ${bcv_slot}
  CROSS JOIN UNNEST(partners__network_id, partners__role, partners__eligible_carriage_listing_split_unit_ids, partners__inventory_distribution_contexts__carriage_listing_split_unit_id, partners__inventory_distribution_contexts__carriage_inventory_owner_id) AS p(network_id, role, eligible_carriage_listing_split_unit_ids, ctxs__carriage_listing_split_unit_id, ctxs__carriage_inventory_owner_id)
  WHERE
    (
      (
        (
          BITWISE_AND(slot__flags, 64) = 0 AND p.role = 'cro'
        )
        AND NOT slot__seller_sponsor_occupation_on_carriage__seller_inventory_owner_id IS NULL
      )
      AND COALESCE(slot__seller_sponsor_occupation_on_carriage__seller_sponsor_split_unit_num, 0) > 0
    )
    AND p.network_id = 520311
)
SELECT
  DATE_FORMAT((
    AT_TIMEZONE(request__timestamp, 'america/new_york')
  ), '%y%m%d') AS date,
  iss.listing_name AS listing_name,
  f.network_id AS seller_network_id,
  iss.network_name AS seller_network_name,
  iss.inventory_owner_network_id AS inventory_owner_network_id,
  iss.inventory_owner_network_name AS inventory_owner_network_name,
  iss.split_type AS split_type,
  iss.brand AS brand,
  iss.endpoint_owner AS endpoint_owner,
  iss.split_ratio AS split_ratio,
  SUM(total_unit_num) AS total_slot_unit,
  SUM(selected_unit_num) AS selected_slot_unit,
  SUM(IF(f.inventory_owner_id = iss.inventory_owner_id, selected_unit_num, 0)) AS inventory_ower_slot_unit
FROM (
  SELECT
    request__timestamp,
    network_id,
    t.eligible_unit_id AS split_unit_id,
    -1 AS inventory_owner_id,
    unit_num AS total_unit_num,
    0 AS selected_unit_num
  FROM tmp_seller
  CROSS JOIN UNNEST(tmp_seller.eligible_unit_ids) AS t(eligible_unit_id)
  UNION ALL
  SELECT
    request__timestamp,
    network_id,
    ctx.split_unit_id AS split_unit_id,
    ctx.inventory_owner_id AS inventory_owner_id,
    0 AS total_unit_num,
    unit_num AS selected_unit_num
  FROM tmp_seller
  CROSS JOIN UNNEST(ctx_split_unit_ids, ctx_inventory_owner_ids) AS ctx(split_unit_id, inventory_owner_id)
) AS f
LEFT JOIN inventory_split_setting AS iss
  ON iss.split_unit_id = f.split_unit_id
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
  10
ORDER BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10
