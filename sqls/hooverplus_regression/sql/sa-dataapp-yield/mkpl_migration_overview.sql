-- account:    sa-dataapp-yield
-- skeleton:   d1f788d1a2e4eaf1ba281cdc883900aa
-- pattern:    a6c848049d9538e0fba0aa072f60296c  (697 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH tmp1 AS (
  SELECT
    DATE_TRUNC('HOUR', ack__timestamp) AS timestamp,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(request__context__network_id, -1) AS distributor_network_id,
    IF(
      CARDINALITY(visitor__standard_device_type_ids) > 0,
      ELEMENT_AT(visitor__standard_device_type_ids, 1),
      -1
    ) AS parent_device_type_id,
    ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)) AS ad_network_id,
    REDUCE(partners__flags, FALSE, (s, x) -> s OR BITWISE_AND(COALESCE(x, 0), 4) > 0, s -> s) AS has_loop,
    CONTAINS(partners__network_id, 382926) AS has_canoe,
    TRANSFORM(
      FILTER(
        TRANSFORM(
          ZIP(
            SLICE(partners__network_id, 1, ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)),
            SLICE(
              partners__reseller_network_id,
              1,
              ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)
            ),
            SLICE(
              partners__sales_channel,
              1,
              ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)
            ),
            SLICE(
              partners__outbound_order_id,
              1,
              ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)
            ),
            SLICE(
              partners__network_is_extra_item_owner,
              1,
              ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)
            )
          ),
          r -> CAST(r AS ROW(
            network_id BIGINT,
            reseller_id BIGINT,
            sales_channel INTEGER,
            outbound_order_id BIGINT,
            network_is_extra_item_owner BOOLEAN
          ))
        ),
        x -> NOT x.network_id IN (382926, 379619, 386329, 511757, 520024)
        OR x.network_is_extra_item_owner
      ),
      x -> CAST(ROW(
        x.network_id,
        x.sales_channel,
        COALESCE(x.outbound_order_id, -1),
        x.network_is_extra_item_owner,
        CASE
          WHEN x.reseller_id IN (379619, 386329, 511757, 520024)
          AND ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)) = x.reseller_id
          THEN ''
          WHEN x.reseller_id = 382926
          THEN 'canoe'
          WHEN x.reseller_id IN (379619, 386329, 511757)
          THEN 'ff'
          WHEN x.reseller_id = 520024
          THEN 'ca'
          ELSE ''
        END
      ) AS ROW(
        network_id BIGINT,
        sales_channel INTEGER,
        outbound_order_id BIGINT,
        network_is_extra_item_owner BOOLEAN,
        sales_chanel_extra VARCHAR
      ))
    ) AS network_sales_channels,
    TRANSFORM(
      FILTER(
        TRANSFORM(
          ZIP(
            SLICE(
              partners__reseller_network_id,
              1,
              ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)
            ),
            CONCAT(
              SLICE(
                partners__network_is_extra_item_owner,
                2,
                ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE) - 1
              ),
              ARRAY[TRUE]
            )
          ),
          r -> CAST(r AS ROW(reseller_id BIGINT, reseller_is_extra_item_owner BOOLEAN))
        ),
        x -> NOT x.reseller_id IN (382926, 379619, 386329, 511757, 520024)
        OR x.reseller_is_extra_item_owner
      ),
      x -> x.reseller_id
    ) AS resellers,
    TRANSFORM(
      FILTER(
        TRANSFORM(
          ZIP(
            SLICE(partners__network_id, 1, ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)),
            SLICE(partners__revenue, 1, ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)),
            SLICE(
              partners__network_is_extra_item_owner,
              1,
              ARRAY_POSITION(partners__network_is_extra_item_owner, TRUE)
            )
          ),
          r -> CAST(r AS ROW(network_id BIGINT, revenue DOUBLE, network_is_extra_item_owner BOOLEAN))
        ),
        x -> NOT x.network_id IN (382926, 379619, 386329, 511757, 520024)
        OR x.network_is_extra_item_owner
      ),
      x -> CAST(ROW(x.revenue) AS ROW(revenue DOUBLE))
    ) AS network_revenues,
    SLICE(partners__network_id, 1, ARRAY_POSITION(partners__network_is_ad_owner, TRUE)) AS network_id_path,
    IF(BITWISE_AND(COALESCE(request__extra_flags2, 0), 8) > 0, 'true', 'false') AS bidder_traffic,
    COALESCE(ack__traffic_type, 0) AS ack_traffic_type,
    COALESCE(slot__time_position_class, 'na') AS time_position_class,
    ack__metrics__ad_impression
  FROM ${bcv_ack}
  WHERE
    ack__ack_entity_type = 'ad' AND COALESCE(ack__metrics__ad_impression, 0) > 0
)
SELECT
  timestamp,
  COALESCE(video_cro_network_id, -1) AS video_cro_network_id,
  cro_nw.name AS video_cro_network_name,
  COALESCE(distributor_network_id, -1) AS distributor_network_id,
  d_nw.name AS distributor_network_name,
  COALESCE(parent_device.name, 'na') AS parent_device_type_name,
  COALESCE(ad_network_id, -1) AS ad_network_id,
  ad_nw.name AS ad_network_name,
  COALESCE(t.network_id, -1) AS network_id,
  nw.name AS network_name,
  CASE
    WHEN COALESCE(video_cro_network_id, -1) = COALESCE(t.network_id, -1)
    AND has_loop = FALSE
    THEN 'cro'
    WHEN COALESCE(video_cro_network_id, -1) = COALESCE(t.network_id, -1)
    AND has_loop = TRUE
    AND network_is_extra_item_owner = FALSE
    THEN 'cro'
    ELSE 'r'
  END AS network_role,
  COALESCE(t.reseller_id, -1) AS reseller_id,
  COALESCE(r_dsp.name, r_nw.name, 'na') AS reseller_name,
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
    WHEN sales_channel = 3 AND sales_chanel_extra = 'canoe'
    THEN 'mrm2mrm (canoe)'
    WHEN sales_channel = 3 AND sales_chanel_extra = 'ff' AND has_canoe AND has_loop
    THEN 'mrm2mrm (ff stbvod buyback)'
    WHEN sales_channel = 3 AND sales_chanel_extra = 'ff'
    THEN 'mrm2mrm (ff)'
    WHEN sales_channel = 3 AND r_nw.network_type = 'full'
    THEN 'mrm2mrm (no ff)'
    WHEN sales_channel = 3 AND r_nw.network_type = 'internal'
    THEN 'reseller tag'
    WHEN sales_channel = 4
    THEN 'programmatic'
    WHEN sales_channel = 5
    AND sales_chanel_extra = 'ca'
    AND out_order.order_type = 'carriage_order'
    THEN 'mpp (ca inventory split)'
    WHEN sales_channel = 5 AND sales_chanel_extra = 'ca' AND has_canoe AND has_loop
    THEN 'mpp (stbvod canoe buyback)'
    WHEN sales_channel = 5 AND sales_chanel_extra = 'ca'
    THEN 'mpp (ca inventory order)'
    WHEN sales_channel = 5
    AND out_order.internal_module = 'partner_tag'
    AND out_order.order_type = 'carriage_order'
    THEN 'mpp (partner tag inventory split)'
    WHEN sales_channel = 5 AND out_order.internal_module = 'partner_tag'
    THEN 'mpp (partner tag inventory order)'
    WHEN sales_channel = 5 AND out_order.order_type = 'carriage_order'
    THEN 'mpp (inventory split)'
    WHEN sales_channel = 5
    THEN 'mpp (inventory order)'
    WHEN sales_channel = 6
    THEN 'mpe'
    ELSE 'unknown'
  END AS sales_channel_detailed,
  network_id_path,
  bidder_traffic,
  time_position_class,
  SUM(COALESCE(ack__metrics__ad_impression, 0)) AS impression,
  SUM(IF(ack_traffic_type = 0, COALESCE(ack__metrics__ad_impression, 0), 0)) AS net_counted_ads,
  SUM(COALESCE(revenue, 0)) AS gross_revenue,
  SUM(IF(ack_traffic_type = 0, COALESCE(revenue, 0), 0)) AS net_revenue
FROM tmp1
CROSS JOIN UNNEST(network_sales_channels, resellers, network_revenues) AS t(network_id, sales_channel, outbound_order_id, network_is_extra_item_owner, sales_chanel_extra, reseller_id, revenue)
LEFT JOIN db.default.d_network AS cro_nw
  ON cro_nw.id = video_cro_network_id
LEFT JOIN db.default.d_network AS d_nw
  ON d_nw.id = distributor_network_id
LEFT JOIN db.default.d_network AS ad_nw
  ON ad_nw.id = ad_network_id
LEFT JOIN db.default.d_network AS nw
  ON nw.id = t.network_id
LEFT JOIN db.default.d_network AS r_nw
  ON r_nw.id = t.reseller_id
LEFT JOIN db.default.d_ssp_demand_side_platform AS r_dsp
  ON r_dsp.network_id = t.reseller_id
LEFT JOIN db.default.d_mkpl_order AS out_order
  ON out_order.id = outbound_order_id
LEFT JOIN db.default.d_lu_mkpl_standard_device_type AS parent_device
  ON parent_device.id = parent_device_type_id
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
  18
