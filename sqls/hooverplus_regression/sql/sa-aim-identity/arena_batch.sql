-- account:    sa-aim-identity
-- skeleton:   4b29be116a608beceb2ed579cb3d4763
-- pattern:    c89307b7380d899a12e6a00e0bbf7e5c  (347 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CURRENT_TIMESTAMP
--   request__timestamp >= (CURRENT_TIMESTAMP - INTERVAL ? DAY)

SELECT
  request__context__video_cro_network_id AS video_cro_network_id,
  network.network_name AS cro_name,
  SUM(
    CASE
      WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
      THEN ack__metrics__ad_impression
      ELSE 0
    END
  ) AS fw_ssp_imp,
  SUM(
    CASE
      WHEN BITWISE_AND(request__extra_flags2, 65536) <= 0
      THEN ack__metrics__ad_impression
      ELSE 0
    END
  ) AS fw_non_ssp_imp,
  SUM(ack__metrics__ad_impression) AS total_imp,
  SUM(
    CASE
      WHEN (
        BITWISE_AND(advertisement__extra_flags2, 4194304) > 0
        OR BITWISE_AND(advertisement__extra_flags2, 8388608) > 0
      )
      THEN ack__metrics__ad_impression
      ELSE 0
    END
  ) AS am_imp,
  SUM(
    CASE
      WHEN (
        (
          (
            BITWISE_AND(advertisement__extra_flags2, 4194304) > 0
            OR BITWISE_AND(advertisement__extra_flags2, 8388608) > 0
          )
        )
        AND BITWISE_AND(request__extra_flags2, 65536) > 0
      )
      THEN ack__metrics__ad_impression
      ELSE 0
    END
  ) AS am_ssp_imp,
  SUM(
    CASE
      WHEN (
        (
          (
            BITWISE_AND(advertisement__extra_flags2, 4194304) > 0
            OR BITWISE_AND(advertisement__extra_flags2, 8388608) > 0
          )
        )
        AND BITWISE_AND(request__extra_flags2, 65536) <= 0
      )
      THEN ack__metrics__ad_impression
      ELSE 0
    END
  ) AS am_non_ssp_imp,
  SUM(
    CASE
      WHEN BITWISE_AND(advertisement__extra_flags2, 2097152) > 0
      THEN ack__metrics__ad_impression
      ELSE 0
    END
  ) AS aic_imp,
  SUM(
    CASE
      WHEN (
        BITWISE_AND(advertisement__extra_flags2, 2097152) > 0
        AND BITWISE_AND(request__extra_flags2, 65536) > 0
      )
      THEN ack__metrics__ad_impression
      ELSE 0
    END
  ) AS aic_ssp_imp,
  SUM(
    CASE
      WHEN (
        BITWISE_AND(advertisement__extra_flags2, 2097152) > 0
        AND BITWISE_AND(request__extra_flags2, 65536) <= 0
      )
      THEN ack__metrics__ad_impression
      ELSE 0
    END
  ) AS aic_non_ssp_imp,
  DATE_TRUNC('DAY', request__timestamp) AS request_time
FROM ${bcv_ack} AS ack
JOIN etl.ds_api.get_network_id_name AS network
  ON network.network_id = request__context__video_cro_network_id
WHERE
  (
    (
      ack__metrics__ad_impression > 0 AND ack__event_type = 'i'
    )
    AND ack__event_name = 'defaultimpression'
  )
  AND CARDINALITY(visitor__user_segments_lookup_key) > 0
GROUP BY
  DATE_TRUNC('DAY', request__timestamp),
  request__context__video_cro_network_id,
  network.network_name
ORDER BY
  request_time DESC
