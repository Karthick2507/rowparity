-- account:    publisher
-- skeleton:   bde42b3a1f8075c89bb38d1354bd648f
-- pattern:    f573df3f4fdb4f4026fb554daf1e5b62  (2 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack.ack__timestamp < CAST(? AS TIMESTAMP)
--   ack.ack__timestamp >= CAST(? AS TIMESTAMP)

WITH tmp AS (
  SELECT
    MAP_AGG(kv.id, kv.name) AS kv_dict
  FROM db.default.d_key_value_term AS kv
  WHERE
    network_id = 511351
    AND REGEXP_EXTRACT(kv.name, '(_fwu)(:)(.*)(:)(.*)(=)(.*)', 3) = '394150'
)
SELECT
  DATE_FORMAT(AT_TIMEZONE(ack.ack__timestamp, 'cet'), '%d/%m/%y') AS date,
  ARRAY_JOIN(
    ARRAY_DISTINCT(
      FILTER(
        TRANSFORM(advertisement__matched_key_value_ids, k -> ELEMENT_AT(tmp.kv_dict, k)),
        kv -> NOT kv IS NULL
      ) || ARRAY[IF(
        BITWISE_AND(request__audience_flags, 16) = 16
        AND (
          CARDINALITY(advertisement__matched_country_ids) > 0
          OR CARDINALITY(advertisement__matched_state_ids) > 0
          OR CARDINALITY(advertisement__matched_city_ids) > 0
          OR CARDINALITY(advertisement__matched_dma_ids) > 0
          OR CARDINALITY(advertisement__matched_geo_ids) > 0
          OR CARDINALITY(advertisement__matched_postal_code_ids) > 0
          OR CARDINALITY(advertisement__matched_postal_code_package_ids) > 0
          OR CARDINALITY(advertisement__matched_region_ids) > 0
        ),
        CONCAT(
          '_fwu:',
          CAST(request__geo_data_provider_id AS VARCHAR),
          ':_fw_postalcode=',
          visitor__postal_code,
          ',_fwu:',
          CAST(request__geo_data_provider_id AS VARCHAR),
          ':_fw_country=',
          visitor__country
        ),
        NULL
      )]
    ),
    ','
  ) AS "operator segment ids",
  SUM(ack__metrics__ad_impression) AS "total impressions"
FROM ${bcv_ack}, tmp
WHERE
  (
    (
      (
        (
          (
            (
              ack.request__is_filtered = FALSE
            )
            AND (
              ack.ack__event_type = 'i' AND ack.ack__event_name = 'defaultimpression'
            )
          )
          AND ack.advertisement__is_bumper = FALSE
        )
        AND ack.advertisement__ad_oo_network_id = 511351
      )
      AND ack.advertisement__is_external = FALSE
    )
    AND BITWISE_AND(ack__flags, 1048576) = 0
  )
  AND (
    (
      request__geo_data_provider_id = 394150
      AND BITWISE_AND(request__audience_flags, 16) = 16
      AND (
        CARDINALITY(advertisement__matched_country_ids) > 0
        OR CARDINALITY(advertisement__matched_state_ids) > 0
        OR CARDINALITY(advertisement__matched_city_ids) > 0
        OR CARDINALITY(advertisement__matched_dma_ids) > 0
        OR CARDINALITY(advertisement__matched_geo_ids) > 0
        OR CARDINALITY(advertisement__matched_postal_code_ids) > 0
        OR CARDINALITY(advertisement__matched_postal_code_package_ids) > 0
        OR CARDINALITY(advertisement__matched_region_ids) > 0
      )
    )
    OR CONTAINS(advertisement__data_provider_id, 394150)
  )
GROUP BY
  1,
  2
