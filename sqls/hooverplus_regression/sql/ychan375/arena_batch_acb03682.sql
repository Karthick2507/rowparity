-- account:    ychan375
-- skeleton:   78886955cd3307ea60eb48bbcb7c779e
-- pattern:    acb03682cbd1f83219ddf11b31f369e5  (2 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH tmp1 AS (
  SELECT
    DATE(request__timestamp) AS event_date,
    request__context__network_id AS "network_id",
    visitor__platform_group AS "platform",
    request__context__profile_id AS "profile",
    slot__time_position_class AS "slot_type",
    request__context__standard_endpoint_id AS "endpoint",
    CASE
      WHEN REGEXP_REPLACE(visitor__caller, '^((js|android|iphone|tvos)-[0-9]).*', 'admanager') = 'admanager'
      THEN 'ad manager'
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
    ) AS ad_views
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
    7,
    8,
    9
  ORDER BY
    1,
    2
), tmp2 AS (
  SELECT
    a.*,
    b.count_on_download_compliance
  FROM tmp1 AS a
  LEFT JOIN oltp.fwmrm_oltp.endpoint_mrc_compliance AS b
    ON a.endpoint = b.endpoint_id
    AND a.network_id = b.network_id
    AND a.profile = b.profile_id
    AND a.platform = b.platform_group
)
SELECT
  event_date,
  network_id,
  endpoint,
  profile,
  platform,
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
  SUM(
    CASE
      WHEN integration <> 'type b integration' OR count_on_download_compliance <> 0
      THEN ad_views
      ELSE 0
    END
  ) AS tracked_ads
FROM tmp2
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7
