-- account:    saengalgo
-- skeleton:   eeb07a5ab32898b4dc7a97ed5cd81a24
-- pattern:    f8a938d65aae945e5e5be438124b7b8b  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < (CAST(? AS TIMESTAMP) + INTERVAL ? DAY)
--   ack__timestamp >= (CAST(? AS TIMESTAMP) - INTERVAL ? DAY)

WITH timezone AS (
  SELECT
    id,
    tz_name
  FROM oltp.fwmrm_oltp.lu_timezone
), operatorzone AS (
  SELECT
    id,
    timezone_id
  FROM oltp.fwmrm_oltp.lu_operator_zone
  WHERE
    NOT timezone_id IS NULL
), operatorzone_timezone AS (
  SELECT
    timezone.id AS timezone_id,
    operatorzone.id AS operator_zone_id,
    timezone.tz_name
  FROM operatorzone
  LEFT JOIN timezone
    ON operatorzone.timezone_id = timezone.id
)
SELECT
  with_tz.video_cro_network_id,
  with_tz.tv_network_id,
  with_tz.source_id,
  with_tz.station_id,
  with_tz.operator_zone_id,
  with_tz.syscode,
  with_tz.impression,
  with_tz.local_hour,
  with_tz.local_date
FROM (
  SELECT
    ack.operator_zone_id,
    ack.syscode,
    ack.tv_network_id,
    ack.station_id,
    ack.source_id,
    ack.video_cro_network_id,
    HOUR(
      FROM_UNIXTIME(TO_UNIXTIME(ack.utc_date_hour), IF(tz.tz_name IS NULL, 'utc', tz.tz_name))
    ) AS local_hour,
    ack.impression,
    DATE_FORMAT(
      FROM_UNIXTIME(TO_UNIXTIME(ack.utc_date_hour), IF(tz.tz_name IS NULL, 'utc', tz.tz_name)),
      '%y-%m-%d'
    ) AS local_date
  FROM (
    SELECT
      operator_zone_id,
      syscode,
      tv_network_id,
      station_id,
      source_id,
      video_cro_network_id,
      utc_date_hour,
      CAST(ack_cnt AS DOUBLE) / opportunity_cnt AS impression
    FROM (
      SELECT
        visitor__operator_zone_id AS operator_zone_id,
        visitor__syscode AS syscode,
        request__context__tv_network_id AS tv_network_id,
        request__context__station_id AS station_id,
        CASE
          WHEN BITWISE_AND(request__extra_flags, 67108864) <> 0
          THEN ''
          ELSE request__context__source_id
        END AS source_id,
        request__context__video_cro_network_id AS video_cro_network_id,
        DATE_TRUNC('HOUR', ack__timestamp) AS utc_date_hour,
        COUNT(*) AS ack_cnt,
        COUNT(DISTINCT slot__opportunity_id) AS opportunity_cnt
      FROM ${bcv_ack}
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
                          request__context__video_cro_network_id IN (384777, 505334)
                          AND NOT visitor__device_id IS NULL
                        )
                        AND NOT request__context__station_id IS NULL
                      )
                      AND NOT visitor__operator_zone_id IS NULL
                    )
                    AND NOT visitor__syscode IS NULL
                  )
                  AND request__context__tv_network_id > 0
                )
                AND NOT slot__break_id IS NULL
              )
              AND ack__event_type = 'i'
            )
            AND ack__event_name = 'defaultimpression'
          )
          AND request__prebid_sivt__capnedit__traffic_valid = TRUE
        )
        AND visitor__active_state = TRUE
      GROUP BY
        1,
        2,
        3,
        4,
        5,
        6,
        7
    )
  ) AS ack
  LEFT JOIN operatorzone_timezone AS tz
    ON ack.operator_zone_id = tz.operator_zone_id
  WHERE
    NOT ack.source_id IS NULL
) AS with_tz
WHERE
  (
    with_tz.local_date >= '2026-08-08' AND with_tz.local_date < '2026-08-09'
  )
  AND with_tz.operator_zone_id <> -1
