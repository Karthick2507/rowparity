-- account:    ychan375
-- skeleton:   bfbaf5e22f923a1d1ceb35f00925dfb1
-- pattern:    69e586506817a839694903fe8b754083  (3 execution(s))
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
  event_date,
  platform,
  profile,
  slot_type,
  integration,
  SUM(ad_views) AS "gross_counted_ads",
  SUM(CASE WHEN (
    filter_type = 0
  ) THEN ad_views ELSE 0 END) AS "net_counted_ads",
  SUM(CASE WHEN (
    compliance_status = 'delivered'
  ) THEN ad_views ELSE 0 END) AS "gross_impressions",
  SUM(
    CASE
      WHEN (
        filter_type = 0 AND compliance_status = 'delivered'
      )
      THEN ad_views
      ELSE 0
    END
  ) AS "net_impressions",
  SUM(tracked_ads) AS "gross_tracked_ads"
FROM (
  SELECT
    DATE(request__timestamp) AS event_date,
    visitor__platform_group AS "platform",
    request__context__profile_id AS "profile",
    slot__time_position_class AS "slot_type",
    CASE
      WHEN REGEXP_REPLACE(visitor__caller, '^((js|android|iphone|tvos)-[0-9]).*', 'admanager') = 'admanager'
      AND request__context__response_format IN (2, 3, 5, 7, 8, 10, 12, 13, 14)
      THEN 'ad manager ip delivery'
      WHEN REGEXP_REPLACE(visitor__caller, '^((js|android|iphone|tvos)-[0-9]).*', 'admanager') = 'admanager'
      AND request__context__response_format = 18
      THEN 'ad manager scte-130 integration'
      WHEN REGEXP_REPLACE(visitor__caller, '^((js|android|iphone|tvos)-[0-9]).*', 'admanager') = 'admanager'
      AND NOT request__context__response_format IN (2, 3, 5, 7, 8, 10, 12, 13, 14, 18)
      THEN 'ad manager only'
      WHEN request__context__response_format IN (2, 3, 5, 7, 8, 10, 12, 13, 14)
      THEN 'direct xml'
      WHEN request__context__response_format = 1
      THEN 'type b integration'
      WHEN request__context__response_format = 18
      THEN 'scte-130 integration'
      WHEN request__context__response_format IN (4, 6)
      THEN 'custom json integration'
      WHEN request__context__response_format IS NULL
      THEN 'others'
      ELSE 'others'
    END AS integration,
    CASE
      WHEN (
        request__traffic_compliance__mrc_compliance_flag IS NULL
        AND CONTAINS(request__mrc_compliance_label, 'not_explicit_rendered')
      )
      THEN 'counted only'
      WHEN BITWISE_AND(request__traffic_compliance__mrc_compliance_flag, 2) <> 0
      THEN 'counted only'
      WHEN (
        request__traffic_compliance__mrc_compliance_flag > 0
        AND request__traffic_compliance__mrc_non_compliance_type IS NULL
      )
      THEN 'counted only'
      WHEN (
        BITWISE_AND(request__traffic_compliance__mrc_compliance_flag, 1) <> 0
        AND slot__time_position_class IN ('preroll', 'midroll', 'postroll', 'pause_midroll', 'overlay')
        AND BITWISE_AND(request__traffic_compliance__mrc_non_compliance_type, 1) <> 0
      )
      THEN 'counted only'
      WHEN (
        (
          BITWISE_AND(request__traffic_compliance__mrc_compliance_flag, 1) <> 0
          AND slot__time_position_class IN ('display', 'in-player-display')
          AND BITWISE_AND(request__traffic_compliance__mrc_non_compliance_type, 2) <> 0
        )
      )
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
    COALESCE(
      SUM(
        (
          1 * (
            COALESCE(request__magnifier, 1)
          ) * (
            COALESCE(request__multiplier, 1)
          )
        )
      ),
      0
    ) AS ad_views,
    SUM(
      IF(
        BITWISE_AND(request__bit_flags, 70368744177664) = 70368744177664,
        ack__metrics__raw_ad_impression,
        0
      )
    ) AS tracked_ads
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
    5,
    6,
    7
  ORDER BY
    1,
    2
)
GROUP BY
  1,
  2,
  3,
  4,
  5
ORDER BY
  6 DESC
