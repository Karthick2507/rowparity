-- account:    sa-dataapp-yield
-- skeleton:   6679782ecf7a9d7fada60f962e11db0c
-- pattern:    9b584e879472ebe5441caa3c70afc91f  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH rule_map AS (
  SELECT
    MAP_AGG(id, rule_id) AS rule_application_map
  FROM db.default.d_mrm_access_rule
), network_type_map AS (
  SELECT
    MAP_AGG(id, network_type) AS network_type_map
  FROM db.default.d_network
), mkpl_order_map AS (
  SELECT
    MAP_AGG(id, internal_module) AS mkpl_order_map
  FROM db.default.d_mkpl_order
), tmp1 AS (
  SELECT
    ack__timestamp,
    advertisement__ad_oo_network_id,
    request__extra_flags2,
    request__context__network_id,
    request__context__video_cro_network_id,
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)) AS ad_network_id,
    request__context__standard_endpoint_id,
    request__context__standard_endpoint_owner_id,
    request__context__standard_programmer_id,
    request__context__standard_brand_id,
    request__context__standard_channel_id,
    IF(
      CARDINALITY(request__context__stream_mode_ids) > 0,
      ELEMENT_AT(request__context__stream_mode_ids, 1),
      -1
    ) AS parent_stream_mode_id,
    slot__time_position_class,
    IF(
      CARDINALITY(visitor__standard_device_type_ids) > 0,
      ELEMENT_AT(visitor__standard_device_type_ids, 1),
      -1
    ) AS parent_device_type_id,
    IF(
      CARDINALITY(visitor__standard_device_type_ids) > 1,
      ELEMENT_AT(visitor__standard_device_type_ids, 2),
      -1
    ) AS child_device_type_id,
    SLICE(partners__network_id, 1, ARRAY_POSITION(partners__network_is_ad_owner, TRUE)) AS partners__network_id,
    SLICE(
      partners__reseller_network_id,
      1,
      ARRAY_POSITION(partners__network_is_ad_owner, TRUE)
    ) AS partners__reseller_network_id,
    SLICE(
      partners__content_owner_network_id,
      1,
      ARRAY_POSITION(partners__network_is_ad_owner, TRUE)
    ) AS partners__content_owner_network_id,
    SLICE(partners__role, 1, ARRAY_POSITION(partners__network_is_ad_owner, TRUE)) AS partners__role,
    SLICE(
      partners__network_is_extra_item_owner,
      1,
      ARRAY_POSITION(partners__network_is_ad_owner, TRUE)
    ) AS partners__network_is_extra_item_owner,
    SLICE(partners__sales_channel, 1, ARRAY_POSITION(partners__network_is_ad_owner, TRUE)) AS partners__sales_channel,
    SLICE(partners__inbound_rule_id, 1, ARRAY_POSITION(partners__network_is_ad_owner, TRUE)) AS partners__inbound_rule_id,
    SLICE(partners__rule_id, 1, ARRAY_POSITION(partners__network_is_ad_owner, TRUE)) AS partners__rule_id,
    SLICE(partners__inbound_order_id, 1, ARRAY_POSITION(partners__network_is_ad_owner, TRUE)) AS partners__inbound_order_id,
    SLICE(partners__outbound_order_id, 1, ARRAY_POSITION(partners__network_is_ad_owner, TRUE)) AS partners__outbound_order_id,
    SLICE(
      partners__outbound_order_type,
      1,
      ARRAY_POSITION(partners__network_is_ad_owner, TRUE)
    ) AS partners__outbound_order_type,
    SLICE(
      partners__outbound_exchange_order_id,
      1,
      ARRAY_POSITION(partners__network_is_ad_owner, TRUE)
    ) AS partners__outbound_exchange_order_id,
    SLICE(partners__supply_source, 1, ARRAY_POSITION(partners__network_is_ad_owner, TRUE)) AS partners__supply_source,
    IF(
      REDUCE(partners__flags, FALSE, (s, x) -> s OR BITWISE_AND(COALESCE(x, 0), 4) > 0, s -> s),
      'true',
      'false'
    ) AS has_loop,
    CONTAINS(partners__network_id, 382926) AS has_canoe,
    ack__metrics__ad_impression,
    IF(COALESCE(ack__traffic_type, 0) = 0, ack__metrics__ad_impression, 0) AS net_counted_ads
  FROM ${bcv_ack}
  WHERE
    ack__ack_entity_type = 'ad' AND COALESCE(ack__metrics__ad_impression, 0) > 0
), tmp2 AS (
  SELECT
    *,
    TRANSFORM(
      ZIP(
        partners__network_id,
        partners__reseller_network_id,
        partners__sales_channel,
        partners__outbound_order_id,
        partners__outbound_order_type
      ),
      r -> CAST(r AS ROW(
        network_id BIGINT,
        reseller_id BIGINT,
        sales_channel INTEGER,
        outbound_order_id BIGINT,
        outbound_order_type VARCHAR
      ))
    ) AS network_sales_channels,
    TRANSFORM(
      ZIP(
        partners__network_id,
        partners__reseller_network_id,
        partners__network_is_extra_item_owner
      ),
      r -> CAST(r AS ROW(network_id BIGINT, reseller_id BIGINT, network_is_extra_item_owner BOOLEAN))
    ) AS network_reseller_ad_owners
  FROM tmp1
)
SELECT
  DATE_TRUNC('HOUR', ack__timestamp) AS timestamp,
  COALESCE(request__context__network_id, -1) AS distributor_network_id,
  COALESCE(d_nw.name, 'na') AS distributor_network_name,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  COALESCE(cro_nw.name, 'na') AS video_cro_network_name,
  COALESCE(ad_network_id, -1) AS ad_network_id,
  COALESCE(ad_nw.name, 'na') AS ad_network_name,
  COALESCE(request__context__standard_endpoint_id, -1) AS endpoint_id,
  COALESCE(ep.name, 'na') AS endpoint_name,
  COALESCE(request__context__standard_endpoint_owner_id, -1) AS endpoint_owner_id,
  COALESCE(eo.name, 'na') AS endpoint_owner_name,
  COALESCE(request__context__standard_programmer_id, -1) AS programmer_id,
  COALESCE(prog.name, 'na') AS programmer_name,
  COALESCE(request__context__standard_brand_id, -1) AS brand_id,
  COALESCE(brand.name, 'na') AS brand_name,
  COALESCE(request__context__standard_channel_id, -1) AS channel_id,
  COALESCE(channel.name, 'na') AS channel_name,
  parent_device_type_id,
  child_device_type_id,
  COALESCE(parent_device.name, 'na') AS parent_device_type_name,
  COALESCE(child_device.name, 'na') AS child_device_type_name,
  parent_stream_mode_id,
  COALESCE(parent_stream_mode.name, 'na') AS parent_stream_mode_name,
  COALESCE(slot__time_position_class, 'na') AS time_position_class,
  nw_id AS network_id,
  COALESCE(nw.name, 'na') AS network_name,
  COALESCE(nw_dsp.id, -1) AS nw_dsp_id,
  COALESCE(nw_dsp.name, 'na') AS nw_dsp_name,
  t.role AS network_role,
  CASE
    WHEN sales_channel = 2
    THEN 'direct sold'
    WHEN sales_channel = 3 AND r_nw.network_type = 'full'
    THEN 'mrm2mrm'
    WHEN sales_channel = 3 AND r_nw.network_type = 'internal'
    THEN 'reseller tag'
    WHEN sales_channel = 4
    THEN 'programmatic'
    WHEN sales_channel = 5
    THEN 'mpp'
    WHEN sales_channel = 6
    THEN 'mpe'
    ELSE 'unknown'
  END AS sales_channel,
  CASE
    WHEN sales_channel = 2
    THEN 'direct sold'
    WHEN sales_channel = 3 AND (
      r_id = 382926 OR nw_id = 382926
    )
    THEN 'mrm2mrm (canoe)'
    WHEN sales_channel = 3 AND r_nw.network_type = 'internal'
    THEN 'reseller tag'
    WHEN sales_channel = 3
    AND r_id IN (379619, 386329, 511757)
    AND r_id = ad_network_id
    AND nw_id IN (379619, 386329, 511757)
    THEN 'mrm2mrm (ff)'
    WHEN sales_channel = 3 AND r_id IN (379619, 386329, 511757) AND r_id = ad_network_id
    THEN 'mrm2mrm (no ff)'
    WHEN sales_channel = 3
    AND has_loop = 'true'
    AND has_canoe
    AND (
      nw_id IN (379619, 386329, 511757) OR r_id IN (379619, 386329, 511757)
    )
    THEN 'mrm2mrm (ff stbvod buyback)'
    WHEN sales_channel = 3
    AND (
      nw_id IN (379619, 386329, 511757) OR r_id IN (379619, 386329, 511757)
    )
    THEN 'mrm2mrm (ff)'
    WHEN sales_channel = 3 AND r_nw.network_type = 'full'
    THEN 'mrm2mrm (no ff)'
    WHEN sales_channel = 4
    THEN 'programmatic'
    WHEN sales_channel = 5
    AND r_id = 520024
    AND r_id = ad_network_id
    AND outbound_order_type = 'carriage_order'
    THEN 'mpp (inventory split)'
    WHEN sales_channel = 5 AND r_id = 520024 AND r_id = ad_network_id
    THEN 'mpp (inventory order)'
    WHEN sales_channel = 5
    AND (
      nw_id = 520024 OR r_id = 520024
    )
    AND has_loop = 'true'
    AND has_canoe
    THEN 'mpp (stbvod canoe buyback)'
    WHEN sales_channel = 5 AND r_id = 520024 AND outbound_order_type = 'carriage_order'
    THEN 'mpp (ca inventory split)'
    WHEN sales_channel = 5 AND r_id = 520024
    THEN 'mpp (ca inventory order)'
    WHEN sales_channel = 5
    AND out_order.internal_module = 'partner_tag'
    AND outbound_order_type = 'carriage_order'
    THEN 'mpp (partner tag inventory split)'
    WHEN sales_channel = 5 AND out_order.internal_module = 'partner_tag'
    THEN 'mpp (partner tag inventory order)'
    WHEN sales_channel = 5 AND outbound_order_type = 'carriage_order'
    THEN 'mpp (inventory split)'
    WHEN sales_channel = 5
    THEN 'mpp (inventory order)'
    WHEN sales_channel = 6
    THEN 'mpe'
    ELSE 'unknown'
  END AS sales_channel_detailed,
  r_id AS reseller_id,
  COALESCE(r_nw.name, 'na') AS reseller_name,
  COALESCE(r_dsp.id, -1) AS dsp_id,
  COALESCE(r_dsp.name, 'na') AS dsp_name,
  COALESCE(imr.upstream_mrm_rule_id, -1) AS in_rule_id,
  COALESCE(ELEMENT_AT(rule_application_map, out_rule_id), -1) AS out_rule_id,
  COALESCE(inbound_order_id, -1) AS inbound_order_id,
  COALESCE(
    IF(COALESCE(outbound_order_id, -1) > 0, outbound_order_id, outbound_exchange_order_id),
    -1
  ) AS outbound_order_id,
  network_step,
  CASE
    WHEN supply_source = 1
    THEN 'o&o'
    WHEN supply_source = 3 AND nw.network_type = 'full'
    THEN 'mrm2mrm'
    WHEN supply_source = 3 AND nw.network_type = 'internal'
    THEN 'reseller tag'
    WHEN supply_source = 4
    THEN 'programmatic'
    WHEN supply_source = 5
    THEN 'mpp'
    WHEN supply_source = 6
    THEN 'mpe'
    ELSE 'unknown'
  END AS supply_source,
  TRANSFORM(partners__rule_id, x -> COALESCE(ELEMENT_AT(rule_application_map, x), -1)) AS rule_path,
  TRANSFORM(partners__inbound_order_id, x -> COALESCE(x, -1)) AS order_path,
  partners__network_id AS network_id_path,
  partners__reseller_network_id AS reseller_id_path,
  IF(BITWISE_AND(COALESCE(request__extra_flags2, 0), 8) > 0, 'true', 'false') AS bidder_traffic,
  TRANSFORM(
    network_sales_channels,
    x -> CASE
      WHEN x.sales_channel = 2
      THEN 'direct sold'
      WHEN x.sales_channel = 3 AND ELEMENT_AT(network_type_map, x.reseller_id) = 'full'
      THEN 'mrm2mrm'
      WHEN x.sales_channel = 3 AND ELEMENT_AT(network_type_map, x.reseller_id) = 'internal'
      THEN 'reseller tag'
      WHEN x.sales_channel = 4
      THEN 'programmatic'
      WHEN x.sales_channel = 5
      THEN 'mpp'
      WHEN x.sales_channel = 6
      THEN 'mpe'
      ELSE 'unknown'
    END
  ) AS sales_channel_path,
  TRANSFORM(
    network_sales_channels,
    x -> CASE
      WHEN x.sales_channel = 2
      THEN 'direct sold'
      WHEN x.sales_channel = 3 AND (
        x.reseller_id = 382926 OR x.network_id = 382926
      )
      THEN 'mrm2mrm (canoe)'
      WHEN x.sales_channel = 3 AND ELEMENT_AT(network_type_map, x.reseller_id) = 'internal'
      THEN 'reseller tag'
      WHEN x.sales_channel = 3
      AND x.reseller_id IN (379619, 386329, 511757)
      AND x.reseller_id = ad_network_id
      AND x.network_id IN (379619, 386329, 511757)
      THEN 'mrm2mrm (ff)'
      WHEN x.sales_channel = 3
      AND x.reseller_id IN (379619, 386329, 511757)
      AND x.reseller_id = ad_network_id
      THEN 'mrm2mrm (no ff)'
      WHEN x.sales_channel = 3
      AND has_loop = 'true'
      AND has_canoe
      AND (
        x.network_id IN (379619, 386329, 511757)
        OR x.reseller_id IN (379619, 386329, 511757)
      )
      THEN 'mrm2mrm (ff stbvod buyback)'
      WHEN x.sales_channel = 3
      AND (
        x.network_id IN (379619, 386329, 511757)
        OR x.reseller_id IN (379619, 386329, 511757)
      )
      THEN 'mrm2mrm (ff)'
      WHEN x.sales_channel = 3 AND ELEMENT_AT(network_type_map, x.reseller_id) = 'full'
      THEN 'mrm2mrm (no ff)'
      WHEN x.sales_channel = 4
      THEN 'programmatic'
      WHEN x.sales_channel = 5
      AND x.reseller_id = 520024
      AND x.reseller_id = ad_network_id
      AND x.outbound_order_type = 'carriage_order'
      THEN 'mpp (inventory split)'
      WHEN x.sales_channel = 5 AND x.reseller_id = 520024 AND x.reseller_id = ad_network_id
      THEN 'mpp (inventory order)'
      WHEN x.sales_channel = 5
      AND (
        x.network_id = 520024 OR x.reseller_id = 520024
      )
      AND has_loop = 'true'
      AND has_canoe
      THEN 'mpp (stbvod canoe buyback)'
      WHEN x.sales_channel = 5
      AND x.reseller_id = 520024
      AND x.outbound_order_type = 'carriage_order'
      THEN 'mpp (ca inventory split)'
      WHEN x.sales_channel = 5 AND x.reseller_id = 520024
      THEN 'mpp (ca inventory order)'
      WHEN x.sales_channel = 5
      AND ELEMENT_AT(mkpl_order_map, x.outbound_order_id) = 'partner_tag'
      AND x.outbound_order_type = 'carriage_order'
      THEN 'mpp (partner tag inventory split)'
      WHEN x.sales_channel = 5
      AND ELEMENT_AT(mkpl_order_map, x.outbound_order_id) = 'partner_tag'
      THEN 'mpp (partner tag inventory order)'
      WHEN x.sales_channel = 5 AND x.outbound_order_type = 'carriage_order'
      THEN 'mpp (inventory split)'
      WHEN x.sales_channel = 5
      THEN 'mpp (inventory order)'
      WHEN x.sales_channel = 6
      THEN 'mpe'
      ELSE 'unknown'
    END
  ) AS sales_channel_detailed_path,
  TRANSFORM(
    FILTER(
      network_reseller_ad_owners,
      x -> x.network_is_extra_item_owner
      OR NOT x.network_id IN (382926, 379619, 386329, 511757, 520024)
    ),
    x -> x.network_id
  ) AS network_id_path_trimmed,
  TRANSFORM(
    FILTER(
      network_reseller_ad_owners,
      x -> x.reseller_id = ad_network_id
      OR NOT x.reseller_id IN (382926, 379619, 386329, 511757, 520024)
    ),
    x -> x.reseller_id
  ) AS reseller_id_path_trimmed,
  has_loop,
  SUM(COALESCE(ack__metrics__ad_impression, 0)) AS impression,
  SUM(net_counted_ads) AS net_counted_ads
FROM tmp2
CROSS JOIN UNNEST(partners__network_id, partners__reseller_network_id, partners__content_owner_network_id, partners__role, partners__sales_channel, partners__inbound_rule_id, partners__rule_id, partners__inbound_order_id, partners__outbound_order_id, partners__outbound_exchange_order_id, partners__outbound_order_type, partners__supply_source) WITH ORDINALITY AS t(nw_id, r_id, co_id, role, sales_channel, imr_id, out_rule_id, inbound_order_id, outbound_order_id, outbound_exchange_order_id, outbound_order_type, supply_source, network_step)
LEFT JOIN db.default.d_inbound_mrm_rule AS imr
  ON imr.id = imr_id
LEFT JOIN db.default.d_network AS nw
  ON nw.id = nw_id
LEFT JOIN db.default.d_network AS r_nw
  ON r_nw.id = r_id
LEFT JOIN db.default.d_network AS cro_nw
  ON cro_nw.id = request__context__video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = request__context__network_id
LEFT JOIN db.default.d_network AS ad_nw
  ON ad_nw.id = ad_network_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS nw_dsp
  ON nw_dsp.network_id = nw_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS r_dsp
  ON r_dsp.network_id = r_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS ep
  ON ep.id = request__context__standard_endpoint_id
LEFT JOIN db.default.d_lu_mkpl_endpoint_owner AS eo
  ON eo.id = request__context__standard_endpoint_owner_id
LEFT JOIN db.default.d_lu_mkpl_standard_programmer AS prog
  ON prog.id = request__context__standard_programmer_id
LEFT JOIN db.default.d_lu_mkpl_standard_brand AS brand
  ON brand.id = request__context__standard_brand_id
LEFT JOIN db.default.d_lu_mkpl_standard_channel AS channel
  ON channel.id = request__context__standard_channel_id
LEFT JOIN db.default.d_mkpl_order AS out_order
  ON out_order.id = outbound_order_id
LEFT JOIN db.default.d_lu_mkpl_standard_device_type AS parent_device
  ON parent_device.id = parent_device_type_id
LEFT JOIN db.default.d_lu_mkpl_standard_device_type AS child_device
  ON child_device.id = child_device_type_id
LEFT JOIN db.default.d_lu_mkpl_stream_mode AS parent_stream_mode
  ON parent_stream_mode.id = parent_stream_mode_id
JOIN rule_map
  ON 1 = 1
JOIN network_type_map
  ON 1 = 1
JOIN mkpl_order_map
  ON 1 = 1
WHERE
  (
    role IN ('cro', 'r') AND supply_source <> 4
  ) AND sales_channel > 0
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
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22,
  23,
  24,
  25,
  26,
  27,
  28,
  29,
  30,
  31,
  32,
  33,
  34,
  35,
  36,
  37,
  38,
  39,
  40,
  41,
  42,
  43,
  44,
  45,
  46,
  47,
  48,
  49,
  50,
  51
