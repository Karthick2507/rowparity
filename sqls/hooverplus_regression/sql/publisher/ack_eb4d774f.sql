-- account:    publisher
-- skeleton:   fc4a565de032dbfcc6eb7cf58a1f95f6
-- pattern:    eb4d774fd3ca585bf02238b3ad584efd  (32 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)
--   process_batch_id <= ?
--   process_batch_id >= ?

SELECT
  d_lu_operator_zone.name AS "zone name",
  visitor__syscode AS "syscode",
  d_linear_television_network.name AS "network",
  COALESCE(
    TRY(
      DATE_FORMAT(
        FROM_ISO8601_TIMESTAMP(
          SPLIT(
            URL_DECODE(
              COALESCE(request__context__extracted_key_value___fw_lto, '0001-01-01t00:00:00.000-05:00')
            ),
            ':'
          )[1]
        ),
        '%y-%m-%d'
      )
    ),
    TRY(
      DATE_FORMAT(
        DATE_PARSE(
          SPLIT(
            URL_DECODE(
              COALESCE(request__context__extracted_key_value___fw_lto, '0001-01-01t00:00:00.000-05:00')
            ),
            ':'
          )[1],
          '%m/%d/%yt%h'
        ),
        '%y-%m-%d'
      )
    )
  ) AS "event day (local day)",
  COALESCE(
    TRY(
      DATE_FORMAT(
        FROM_ISO8601_TIMESTAMP(
          SPLIT(
            URL_DECODE(
              COALESCE(request__context__extracted_key_value___fw_lto, '0001-01-01t00:00:00.000-05:00')
            ),
            ':'
          )[1]
        ),
        '%h:00:00'
      )
    ),
    TRY(
      DATE_FORMAT(
        DATE_PARSE(
          SPLIT(
            URL_DECODE(
              COALESCE(request__context__extracted_key_value___fw_lto, '0001-01-01t00:00:00.000-05:00')
            ),
            ':'
          )[1],
          '%m/%d/%yt%h'
        ),
        '%h:00:00'
      )
    )
  ) AS "event hour (local time)",
  'valid traffic (post-capping)' AS "traffic type",
  COUNT(DISTINCT d_linear_opportunity.spot_external_id) AS "number of spots",
  SUM(
    IF(
      (
        BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 1) = 0
        AND BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 2) > 0
      ),
      COALESCE(ack__metrics__ad_impression, 0),
      0
    )
  ) AS "addressable_default_ad_impressions",
  SUM(
    IF(
      (
        BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 1) > 0
        AND BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 2) = 0
      ),
      COALESCE(ack__metrics__ad_impression, 0),
      0
    )
  ) AS "addressable_variant_ad_impressions",
  SUM(
    IF(
      (
        BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 1) = 0
        AND BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 2) = 0
      ),
      COALESCE(ack__metrics__ad_impression, 0),
      0
    )
  ) AS "linear_scheduled_ad_impressions",
  SUM(
    IF(
      (
        BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 1) > 0
        AND BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 2) > 0
      ),
      COALESCE(ack__metrics__ad_impression, 0),
      0
    )
  ) AS "linear_evergreen_ad_impressions",
  ROUND(
    SUM(
      IF(
        (
          BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 1) > 0
          AND BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 2) = 0
        )
        OR (
          BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 1) = 0
          AND BITWISE_AND(COALESCE(advertisement__extra_flags, 0), 2) > 0
        ),
        COALESCE(adv_network.revenue, 0) * COALESCE(ack__metrics__fire_event_revenue_ratio, 0),
        0
      )
    ) * 1000 / SUM(ack__metrics__ad_impression),
    2
  ) AS "average ecpm"
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__network_id, partners__role, partners__network_is_ad_owner, partners__reseller_network_id, partners__revenue) AS adv_network(network_id, role, network_is_ad_owner, reseller_id, revenue)
JOIN db.default.d_linear_opportunity
  ON slot__opportunity_id = d_linear_opportunity.opportunity_id
JOIN db.default.d_lu_operator_zone
  ON visitor__operator_zone_id = d_lu_operator_zone.id
JOIN db.default.d_linear_television_network
  ON request__context__tv_network_id = d_linear_television_network.id
WHERE
  (
    (
      (
        (
          (
            (
              (
                (
                  (
                    (
                      request__prebid_sivt__capnedit__traffic_valid IS NULL
                      OR request__prebid_sivt__capnedit__traffic_valid = TRUE
                    )
                    AND slot__avail_type = 'addressable_split_avail'
                  )
                  AND COALESCE(ack__metrics__ad_impression, 0) <> 0
                )
                AND adv_network.role IN ('cro', 'r')
              )
              AND advertisement__is_bumper = FALSE
            )
            AND (
              ack__is_private_impression = FALSE OR network_is_ad_owner = TRUE
            )
          )
          AND request__is_filtered = FALSE
        )
        AND BITWISE_AND(COALESCE(ack__flags, 0), 67108864) = 0
      )
      AND BITWISE_AND(COALESCE(request__extra_flags, 0), 1024) > 0
    )
    AND adv_network.network_id = 384777
  )
  AND CONTAINS(d_linear_opportunity.inventory_owner_names, 'local')
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6
