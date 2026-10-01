-- account:    publisher
-- skeleton:   a82bfe491c7c8524655e47d22c6f56d1
-- pattern:    2a7bd9c3a4a95239b3f4ee45108171e2  (31 execution(s))
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
    CAST(clsr.percentage AS VARCHAR) || '%' AS split_ratio,
    mol.order_id AS carriage_order_id,
    mol.order_name AS carriage_order_name
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
  LEFT JOIN (
    SELECT
      mola.seller_listing_id AS seller_listing_id,
      mo.id AS order_id,
      mo.name AS order_name,
      mo.buyer_network_id AS buyer_network_id,
      mo.inventory_owner_id AS inventory_owner_id
    FROM db.default.d_mkpl_order_listing_assignment AS mola
    JOIN db.default.d_mkpl_order AS mo
      ON mo.id = mola.order_id
    GROUP BY
      1,
      2,
      3,
      4,
      5
  ) AS mol
    ON mol.seller_listing_id = clsu.listing_id
    AND mol.inventory_owner_id = clsr.inventory_owner_id
    AND mol.buyer_network_id = invo.inventory_owner_network_id
  WHERE
    invo.inventory_owner_network_id = 380990
)
SELECT
  DATE_FORMAT((
    AT_TIMEZONE(request__timestamp, 'europe/london')
  ), '%y%m%d') AS date,
  COALESCE(iss.carriage_order_name, iss.listing_name) AS order_name,
  f.network_id AS seller_network_id,
  iss.network_name AS seller_network_name,
  iss.inventory_owner_network_id AS inventory_owner_network_id,
  iss.inventory_owner_network_name AS inventory_owner_network_name,
  iss.split_type AS split_type,
  iss.brand AS brand,
  iss.endpoint_owner AS endpoint_owner,
  iss.split_ratio AS split_ratio,
  SUM(unit_num) AS total_slot_unit,
  SUM(
    IF(
      t.eligible_unit_id = f.selected_unit_id
      AND f.selected_inv_owner_id = iss.inventory_owner_id,
      unit_num,
      0
    )
  ) AS slot_unit,
  CAST((
    100.00 * SUM(
      IF(
        t.eligible_unit_id = f.selected_unit_id
        AND f.selected_inv_owner_id = iss.inventory_owner_id,
        unit_num,
        0
      )
    )
  ) / SUM(unit_num) AS VARCHAR) || '%' AS slot_unit_ratio
FROM (
  SELECT
    request__timestamp,
    p.network_id AS network_id,
    COALESCE(
      p.eligible_carriage_listing_split_unit_ids,
      ARRAY[p.carriage_listing_split_unit_id]
    ) AS eligible_unit_ids,
    p.carriage_listing_split_unit_id AS selected_unit_id,
    carriage_inventory_owner_id AS selected_inv_owner_id,
    COALESCE(p.site_id, -1) AS site_id,
    COALESCE(slot__carriage_listing_split_unit_num, 1) AS unit_num
  FROM ${bcv_slot}
  CROSS JOIN UNNEST(partners__network_id, partners__eligible_carriage_listing_split_unit_ids, partners__carriage_listing_split_unit_id, partners__carriage_inventory_owner_id, partners__site_id) AS p(network_id, eligible_carriage_listing_split_unit_ids, carriage_listing_split_unit_id, carriage_inventory_owner_id, site_id)
  WHERE
    (
      (
        NOT p.carriage_listing_split_unit_id IS NULL
        AND NOT p.carriage_inventory_owner_id IS NULL
      )
      AND BITWISE_AND(slot__flags, 64) = 0
    )
    AND COALESCE(slot__carriage_listing_split_unit_num, 1) > 0
  UNION ALL
  SELECT
    request__timestamp,
    p.network_id AS network_id,
    p.eligible_carriage_listing_split_unit_ids AS eligible_unit_ids,
    slot__carriage_listing_split_unit_id AS selected_unit_id,
    slot__seller_sponsor_occupation_on_carriage__seller_inventory_owner_id AS selected_inv_owner_id,
    COALESCE(p.site_id, -1) AS site_id,
    slot__seller_sponsor_occupation_on_carriage__seller_sponsor_split_unit_num AS unit_num
  FROM ${bcv_slot}
  CROSS JOIN UNNEST(partners__network_id, partners__role, partners__eligible_carriage_listing_split_unit_ids, partners__site_id) AS p(network_id, role, eligible_carriage_listing_split_unit_ids, site_id)
  WHERE
    (
      (
        BITWISE_AND(slot__flags, 64) = 0 AND p.role = 'cro'
      )
      AND NOT slot__seller_sponsor_occupation_on_carriage__seller_inventory_owner_id IS NULL
    )
    AND COALESCE(slot__seller_sponsor_occupation_on_carriage__seller_sponsor_split_unit_num, 0) > 0
) AS f
CROSS JOIN UNNEST(f.eligible_unit_ids) AS t(eligible_unit_id)
JOIN inventory_split_setting AS iss
  ON iss.split_unit_id = t.eligible_unit_id
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
