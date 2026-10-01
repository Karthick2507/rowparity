-- account:    sa-dataapp-yield
-- skeleton:   fc1a231a505e69aa630b5bae4afd748c
-- pattern:    8275aefb7e5ff120073840e7a9d5bcc0  (696 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH device_type AS (
  SELECT
    MAP_AGG(id, name) AS device_name_map
  FROM db.default.d_lu_mkpl_standard_device_type
)
SELECT
  tmp.*,
  COALESCE(vcro.name, 'na') AS video_cro_network_name,
  COALESCE(dis.name, 'na') AS distributor_network_name,
  COALESCE(brand.name, 'na') AS standard_brand_name,
  COALESCE(channel.name, 'na') AS standard_channel_name,
  COALESCE(endpoint.name, 'na') AS standard_endpoint_name,
  TRANSFORM(standard_device_type_ids, x -> COALESCE(ELEMENT_AT(device_name_map, x), 'na')) AS standard_device_type_names,
  COALESCE(nw.name, 'na') AS network_name,
  COALESCE(section.name, 'na') AS site_section_name,
  COALESCE(co_nw.name, 'na') AS content_owner_name
FROM (
  SELECT
    DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
    COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
    COALESCE(request__context__network_id, -1) AS distributor_network_id,
    COALESCE(request__context__standard_brand_id, -1) AS standard_brand_id,
    COALESCE(request__context__standard_channel_id, -1) AS standard_channel_id,
    COALESCE(request__context__standard_endpoint_id, -1) AS standard_endpoint_id,
    COALESCE(visitor__standard_device_type_ids, ARRAY[-1]) AS standard_device_type_ids,
    COALESCE(nw.nw_id, -1) AS network_id,
    COALESCE(nw.site_section_id, -1) AS site_section_id,
    COALESCE(nw.site_id, -1) AS site_id,
    COALESCE(nw.co_id, -1) AS content_owner_id,
    COALESCE(inbound_order_id, -1) AS inbound_order_id,
    SUM(
      1 * COALESCE(request__multiplier, 1) * COALESCE(request__magnifier, 1) * COALESCE(request__log_sampling__magnifier, 1)
    ) AS req_ad_request
  FROM ${bcv_request}
  CROSS JOIN UNNEST(execution_networks__content_owner_network_id, execution_networks__network_id, execution_networks__role, execution_networks__site_id, execution_networks__site_section_id, execution_networks__supply_source, execution_networks__inbound_order_id, execution_networks__inbound_listing_id, execution_networks__inbound_order_type) AS nw(co_id, nw_id, nw_role, site_id, site_section_id, supply_source, inbound_order_id, inbound_listing_id, inbound_order_type)
  JOIN db.default.d_network_function AS nf
    ON nf.network_id = nw.nw_id AND nf.function_id = 1428
  WHERE
    (
      COALESCE(nw.nw_role, '') = 'r' AND COALESCE(nw.supply_source, 0) IN (5, 6)
    )
    AND (
      request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
    )
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
    12
) AS tmp
LEFT JOIN db.default.d_network AS vcro
  ON vcro.id = tmp.video_cro_network_id
LEFT JOIN db.default.d_network AS dis
  ON dis.id = tmp.distributor_network_id
LEFT JOIN db.default.d_network AS nw
  ON nw.id = tmp.network_id
LEFT JOIN db.default.d_network AS co_nw
  ON co_nw.id = tmp.content_owner_id
LEFT JOIN db.default.d_lu_mkpl_standard_brand AS brand
  ON brand.id = tmp.standard_brand_id
LEFT JOIN db.default.d_lu_mkpl_standard_channel AS channel
  ON channel.id = tmp.standard_channel_id
LEFT JOIN db.default.d_lu_mkpl_endpoint AS endpoint
  ON endpoint.id = tmp.standard_endpoint_id
LEFT JOIN db.default.d_site_section AS section
  ON section.id = tmp.site_section_id
JOIN device_type
  ON 1 = 1
