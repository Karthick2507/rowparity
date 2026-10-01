-- account:    ychan375
-- skeleton:   8ac7aeaa9bea5ec048bb2523a266a9ff
-- pattern:    42373da1c8553560d8bcc66756d6abaf  (2 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE(ack_event_date) AS ack_event_date,
  platform,
  ad_type,
  SUM(CASE WHEN compliance_status = 'delivered' THEN ad_views ELSE 0 END) AS "gross_impressions",
  SUM(
    CASE
      WHEN filter_type IN (-1, 12, 18) AND compliance_status = 'delivered'
      THEN ad_views
      ELSE 0
    END
  ) AS "invalid_corrupt_impressions",
  SUM(
    CASE
      WHEN filter_type IN (11, 14, 15, 16, 17) AND compliance_status = 'delivered'
      THEN ad_views
      ELSE 0
    END
  ) AS "list_based_impressions",
  SUM(
    CASE
      WHEN filter_type = 1001 AND compliance_status = 'delivered'
      THEN ad_views
      ELSE 0
    END
  ) AS "activity_based_impressions",
  SUM(
    CASE
      WHEN filter_type = 13 AND compliance_status = 'delivered'
      THEN ad_views
      ELSE 0
    END
  ) AS "internal_traffic_impressions",
  SUM(
    CASE
      WHEN filter_type = 0 AND compliance_status = 'delivered'
      THEN ad_views
      ELSE 0
    END
  ) AS "net_impressions"
FROM (
  SELECT
    DATE(request__timestamp) AS ack_event_date,
    visitor__platform_group AS "platform",
    slot__time_position_class AS "ad_type",
    CASE
      WHEN BITWISE_AND(request__traffic_compliance__mrc_compliance_flag, 1) > 0
      THEN 'counted only'
      ELSE 'delivered'
    END AS compliance_status,
    CASE
      WHEN BITWISE_AND(COALESCE(request__flags, 0), 64) = 0
      THEN CAST(0 AS BIGINT)
      WHEN COALESCE(visitor__filtration_reason, 0) IN (11, 12, 13, 14, 15, 16, 17, 18, 1001)
      THEN visitor__filtration_reason
      ELSE CAST(-1 AS BIGINT)
    END AS filter_type,
    SUM(ack__metrics__raw_ad_impression) AS ad_views
  FROM ${bcv_ack}
  WHERE
    (
      (
        (
          ack__event_type = 'i' AND ack__event_name = 'defaultimpression'
        )
        AND BITWISE_AND(ack__flags, 1) = 1
      )
      AND BITWISE_AND(ack__flags, 16) = 0
    )
    AND BITWISE_AND((
      COALESCE(advertisement__flags, 0)
    ), 128) = 0
  GROUP BY
    1,
    2,
    3,
    4,
    5
  ORDER BY
    1,
    2
  
)
GROUP BY
  1,
  2,
  3
