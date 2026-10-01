-- account:    publisher
-- skeleton:   4096c9ea2055b6bfbd9750e110d7ea32
-- pattern:    9b032d48d3810970d4f20cf76f3771a8  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack.ack__timestamp < CAST(? AS TIMESTAMP)
--   ack.ack__timestamp >= CAST(? AS TIMESTAMP)
--   process_batch_id <= ?
--   process_batch_id >= ?

SELECT DISTINCT
  l.geo_type AS "targeted geography type",
  l.geo_name AS "targeted geography name",
  ad.advertiser_id AS "advertiser id",
  ad.advertiser_name AS "advertiser name",
  io.id AS "insertion order id",
  io.name AS "insertion order name",
  io.client_po AS "client po",
  a.ad_tree_node_id AS "ad unit id",
  ad.ad_unit_name AS "ad unit name",
  DATE_FORMAT(plc.start_date, '%y-%m-%d %h:%i:%s') AS "ad start time",
  DATE_FORMAT(plc.end_date, '%y-%m-%d %h:%i:%s') AS "ad end time",
  ad.ad_unit_type AS "ad type",
  ad.status AS "ad status",
  a.creative_id AS "creative id",
  cr.name AS "creative name",
  DATE_FORMAT(cas.start_date, '%y-%m-%d %h:%i:%s') AS "creative start date",
  DATE_FORMAT(cas.end_date, '%y-%m-%d %h:%i:%s') AS "creative end date",
  crd.creative_type AS "creative type",
  crd.physical_file_size AS "creative size",
  url.defaultimpsurl AS "impression url",
  url.defaultclickurl AS "click thru url",
  io.primary_sales_person AS "salesperson",
  io.primary_trafficker AS "primary trafficker"
FROM (
  SELECT
    fact.placement_id,
    fact.ad_tree_node_id,
    fact.ad_unit_id,
    fact.creative_id,
    fact.creative_rendition_id,
    fact.matched_keyvalue_item_ids,
    MAX(
      BITWISE_OR(
        CASE
          WHEN BITWISE_AND(key_value_id, 16777216) = 16777216
          THEN 4311744512
          WHEN BITWISE_AND(key_value_id, 134217728) = 134217728
          THEN 8657043456
          WHEN BITWISE_AND(key_value_id, 33554432) = 33554432
          THEN 12918456320
          WHEN BITWISE_AND(key_value_id, 67108864) = 67108864
          THEN 17230200832
          ELSE 0
        END,
        BITWISE_AND(key_value_id, 16777215)
      )
    ) AS location_id
  FROM (
    SELECT
      COALESCE(advertisement__placement_id, -1) AS placement_id,
      COALESCE(advertisement__ad_id, -1) AS ad_tree_node_id,
      COALESCE(advertisement__ad_unit_id, -1) AS ad_unit_id,
      COALESCE(advertisement__creative_id, -1) AS creative_id,
      COALESCE(ack__creative_rendition_id, COALESCE(advertisement__rendition_id, -1)) AS creative_rendition_id,
      IF(
        BITWISE_AND(COALESCE(advertisement__entity_flags, 0), 33554432) = 0,
        CONCAT(
          TRANSFORM(advertisement__matched_country_ids, x -> BITWISE_OR(x, 16777216)),
          TRANSFORM(advertisement__matched_state_ids, x -> BITWISE_OR(x, 33554432)),
          TRANSFORM(advertisement__matched_city_ids, x -> BITWISE_OR(x, 67108864)),
          TRANSFORM(advertisement__matched_dma_ids, x -> BITWISE_OR(x, 134217728))
        ),
        ARRAY[]
      ) AS matched_keyvalue_item_ids,
      COALESCE(SUM(ack.ack__metrics__ad_impression), 0) AS ad_views,
      COALESCE(SUM(ack.ack__metrics__click), 0) AS clicks
    FROM ${bcv_ack}
    WHERE
      (
        (
          (
            (
              (
                (
                  (
                    ack.request__is_filtered = FALSE
                  )
                  AND (
                    (
                      ack.ack__event_type = 'i' AND ack.ack__event_name = 'defaultimpression'
                    )
                    OR (
                      ack.ack__event_type = 'c' AND ack.ack__event_name = 'defaultclick'
                    )
                  )
                )
                AND ack.advertisement__is_bumper = FALSE
              )
              AND advertisement__external_reseller IS NULL
            )
            AND BITWISE_AND(ack__flags, 1048576) = 0
          )
          AND BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) = 0
        )
        AND BITWISE_AND(COALESCE(request__extra_flags2, 0), 32) = 0
      )
      AND ack.advertisement__ad_oo_network_id = 191701
    GROUP BY
      1,
      2,
      3,
      4,
      5,
      6
    HAVING
      COALESCE(SUM(ack.ack__metrics__ad_impression), 0) > 0
      OR COALESCE(SUM(ack.ack__metrics__click), 0) > 0
  ) AS fact
  CROSS JOIN UNNEST(fact.matched_keyvalue_item_ids) AS kv(key_value_id)
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6
) AS a
LEFT JOIN db.default.d_location AS l
  ON l.id = BITWISE_AND(a.location_id, 4294967295)
LEFT JOIN db.default.d_ad_tree_node AS ad
  ON ad.id = a.ad_tree_node_id
LEFT JOIN db.default.d_placement AS plc
  ON plc.id = a.placement_id
LEFT JOIN db.default.d_io AS io
  ON io.id = ad.io_id
LEFT JOIN db.default.d_creative AS cr
  ON cr.id = a.creative_id
LEFT JOIN db.default.d_creative_ad_assignment AS cas
  ON cas.id = a.creative_id AND cas.ad_tree_node_id = a.ad_tree_node_id
LEFT JOIN db.default.d_creative_rendition AS crd
  ON crd.id = a.creative_rendition_id
LEFT JOIN (
  SELECT
    a.network_id,
    a.ad_tree_node_id,
    a.creative_id,
    MAX(IF(a.action_type = 'impression' AND a.name = 'defaultimpression', b.url, '')) AS defaultimpsurl,
    MAX(IF(a.action_type = 'click' AND a.name = 'defaultclick', b.url, '')) AS defaultclickurl
  FROM (
    SELECT
      ad.network_id,
      ca.ad_tree_node_id,
      ca.creative_id,
      ca.name,
      ca.action_type,
      MIN(ca.id) AS min_creative_action_id
    FROM db.default.d_creative_action AS ca
    JOIN db.default.d_ad_tree_node AS ad
      ON ca.ad_tree_node_id = ad.id
    WHERE
      (
        (
          ad.network_id = 191701
          AND (
            (
              ca.action_type = 'impression' AND ca.name = 'defaultimpression'
            )
            OR (
              ca.action_type = 'click' AND ca.name = 'defaultclick'
            )
          )
        )
        AND NOT ca.creative_id IS NULL
      )
      AND NOT ca.url IS NULL
    GROUP BY
      1,
      2,
      3,
      4,
      5
  ) AS a
  JOIN db.default.d_creative_action AS b
    ON b.id = a.min_creative_action_id
  GROUP BY
    1,
    2,
    3
) AS url
  ON url.ad_tree_node_id = a.ad_tree_node_id AND url.creative_id = a.creative_id
