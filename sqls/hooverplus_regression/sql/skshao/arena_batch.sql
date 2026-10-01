-- account:    skshao
-- skeleton:   d5818c9037b56d756ac0ba23208567ef
-- pattern:    bb6e4ce9710c8a02c3f4424e0ffdefc3  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     ack, ad, slot
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP) - INTERVAL ? DAY

WITH slot AS (
  SELECT
    DATE_TRUNC('DAY', ack__timestamp) AS event_date,
    nw.nw_id AS network_id,
    request__transaction_id AS transaction_id,
    request__server_id AS server_id,
    ack__timestamp,
    slot__flags,
    slot__time_position_class,
    slot__time_position,
    slot__sequence,
    slot__raw_max_ads,
    slot__max_ads,
    slot__max_duration,
    slot__time_unfilled
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(partners__network_id, partners__site_id, partners__site_section_id, partners__role) AS nw(nw_id, site_id, site_section_id, nw_role)
  JOIN (
    SELECT
      id,
      name
    FROM db.default.d_site_section
    WHERE
      (
        (
          network_id = 169843 AND LOWER(name) LIKE '%peacock%'
        )
        AND LOWER(name) NOT LIKE '%kids%'
      )
      AND LOWER(name) NOT LIKE '%teen%'
  ) AS ss
    ON ss.id = nw.site_section_id
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
                      request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
                    )
                    AND slot__time_position_class IN ('midroll')
                  )
                  AND COALESCE(nw.nw_role, '') = 'cro'
                )
                AND COALESCE(nw.nw_id, -1) = COALESCE(request__context__video_cro_network_id, -1)
              )
              AND nw.nw_id = 169843
            )
            AND IF(
              BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
              -3,
              COALESCE(request__context__profile_id, -1)
            ) <> 7712
          )
          AND COALESCE(visitor__country_id, -1) = 165
        )
        AND ack__ack_entity_type = 'slot'
      )
      AND COALESCE(ack__metrics__slot_impression, 0) > 0
    )
    AND BITWISE_AND(slot__flags, 46) = 0
), ad AS (
  SELECT
    DATE_TRUNC('DAY', ack__timestamp) AS event_date,
    request__transaction_id AS transaction_id,
    request__server_id AS server_id,
    slot__time_position_class AS slot_time_position_class,
    slot__sequence AS slot_sequence,
    COUNT_IF(ad_is_fallback = FALSE) AS phase9_num_ads,
    SUM(IF(ad_is_fallback = FALSE, ad_duration, 0)) AS phase9_duration,
    COUNT_IF(
      ad_is_undeliverable = FALSE
      AND (
        BITWISE_AND(ad_flags, 33554432) > 0 OR ad_is_fallback = FALSE
      )
    ) AS phase10_num_ads,
    COUNT_IF(
      ad_is_undeliverable = FALSE
      AND (
        (
          BITWISE_AND(ad_flags, 33554432) > 0 AND LOWER(pl.name) NOT LIKE '%promo%'
        )
        OR ad_is_fallback = FALSE
      )
    ) AS phase10_num_ads_consider_promo,
    SUM(
      IF(
        ad_is_undeliverable = FALSE
        AND (
          BITWISE_AND(ad_flags, 33554432) > 0 OR ad_is_fallback = FALSE
        ),
        ad_duration,
        0
      )
    ) AS phase10_duration,
    SUM(
      IF(
        ad_is_undeliverable = FALSE
        AND (
          (
            BITWISE_AND(ad_flags, 33554432) > 0 AND LOWER(pl.name) NOT LIKE '%promo%'
          )
          OR ad_is_fallback = FALSE
        ),
        ad_duration,
        0
      )
    ) AS phase10_duration_consider_promo,
    COUNT_IF(
      ad_is_undeliverable = TRUE
      AND BITWISE_AND(ad_flags, 67108864) > 0
      AND ad_is_fallback = FALSE
    ) AS sstf_fail_ads
  FROM ${bcv_ack}
  CROSS JOIN UNNEST(ads_in_slot__advertisement__ad_id, ads_in_slot__advertisement__placement_id, ads_in_slot__advertisement__duration, ads_in_slot__advertisement__is_fallback, ads_in_slot__advertisement__is_undeliverable, ads_in_slot__advertisement__flags, ads_in_slot__partners__network_id, ads_in_slot__partners__role, ads_in_slot__partners__site_section_id, ads_in_slot__partners__series_id) AS a(ad_id, placement_id, ad_duration, ad_is_fallback, ad_is_undeliverable, ad_flags, network_ids, roles, site_section_ids, series_ids)
  CROSS JOIN UNNEST(network_ids, roles, site_section_ids) AS nw(nw_id, nw_role, site_section_id)
  JOIN db.default.d_placement AS pl
    ON pl.id = a.placement_id
  WHERE
    (
      (
        (
          (
            (
              (
                (
                  (
                    request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
                  )
                  AND slot__time_position_class IN ('midroll')
                )
                AND COALESCE(nw.nw_role, '') = 'cro'
              )
              AND COALESCE(nw.nw_id, -1) = COALESCE(request__context__video_cro_network_id, -1)
            )
            AND nw.nw_id = 169843
          )
          AND IF(
            BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
            -3,
            COALESCE(request__context__profile_id, -1)
          ) <> 7712
        )
        AND COALESCE(visitor__country_id, -1) = 165
      )
      AND ack__ack_entity_type = 'slot'
    )
    AND COALESCE(ack__metrics__slot_impression, 0) > 0
  GROUP BY
    1,
    2,
    3,
    4,
    5
)
SELECT
  network_id,
  slot_count,
  slot_duration,
  pre_filled_ads,
  pre_filled_duration,
  final_filled_ads,
  final_filled_ads_consider_promo,
  final_filled_duration,
  final_filled_duration_consider_promo,
  unfilled_avails_with_pre_filled_ads,
  unfilled_avails_with_final_filled_ads,
  unfilled_avails_with_final_filled_ads_consider_promo,
  impression,
  impression_consider_promo,
  CASE
    WHEN (
      impression + unfilled_avails_with_pre_filled_ads
    ) > 0
    THEN impression * 1.0000 / (
      impression + unfilled_avails_with_pre_filled_ads
    )
    ELSE 0
  END AS "pre-filled sell-thru rate",
  CASE
    WHEN (
      impression + unfilled_avails_with_final_filled_ads
    ) > 0
    THEN impression * 1.0000 / (
      impression + unfilled_avails_with_final_filled_ads
    )
    ELSE 0
  END AS "final-filled sell-thru rate",
  CASE
    WHEN (
      impression + unfilled_avails_with_pre_filled_ads
    ) > 0
    THEN impression * 1.0000 / (
      impression + unfilled_avails_with_pre_filled_ads
    )
    ELSE 0
  END - CASE
    WHEN (
      impression + unfilled_avails_with_final_filled_ads
    ) > 0
    THEN impression * 1.0000 / (
      impression + unfilled_avails_with_final_filled_ads
    )
    ELSE 0
  END AS "sell-thru rate diff caused by sstf failure",
  unfilled_avails_with_final_filled_ads - unfilled_avails_with_pre_filled_ads AS "unfilled avails caused by sstf failure",
  CASE
    WHEN final_filled_ads > 0
    THEN sstf_fail_ads * 1.0000 / final_filled_ads
    ELSE 0
  END AS "sstf fail rate",
  CASE
    WHEN (
      impression_consider_promo + unfilled_avails_with_final_filled_ads_consider_promo
    ) > 0
    THEN impression_consider_promo * 1.0000 / (
      impression_consider_promo + unfilled_avails_with_final_filled_ads_consider_promo
    )
    ELSE 0
  END AS "final-filled sell-thru rate considering promo",
  CASE
    WHEN (
      impression_consider_promo + unfilled_avails_with_pre_filled_ads
    ) > 0
    THEN impression_consider_promo * 1.0000 / (
      impression_consider_promo + unfilled_avails_with_pre_filled_ads
    )
    ELSE 0
  END - CASE
    WHEN (
      impression_consider_promo + unfilled_avails_with_final_filled_ads_consider_promo
    ) > 0
    THEN impression_consider_promo * 1.0000 / (
      impression_consider_promo + unfilled_avails_with_final_filled_ads_consider_promo
    )
    ELSE 0
  END AS "sell-thru rate diff caused by sstf failure considering promo",
  unfilled_avails_with_final_filled_ads_consider_promo - unfilled_avails_with_pre_filled_ads AS "unfilled avails caused by sstf failure considering promo",
  event_date
FROM (
  SELECT
    event_date,
    network_id,
    SUM(slot_count) AS slot_count,
    SUM(slot_duration) AS slot_duration,
    SUM(phase9_num_ads) AS pre_filled_ads,
    SUM(phase9_duration) AS pre_filled_duration,
    SUM(phase10_num_ads) AS final_filled_ads,
    SUM(phase10_num_ads_consider_promo) AS final_filled_ads_consider_promo,
    SUM(phase10_duration) AS final_filled_duration,
    SUM(phase10_duration_consider_promo) AS final_filled_duration_consider_promo,
    SUM(nbcu_phase9_unfilled_avails) AS unfilled_avails_with_pre_filled_ads,
    SUM(nbcu_phase10_unfilled_avails) AS unfilled_avails_with_final_filled_ads,
    SUM(nbcu_phase10_unfilled_avails_consider_promo) AS unfilled_avails_with_final_filled_ads_consider_promo,
    SUM(impressions) AS impression,
    SUM(impressions_consider_promo) AS impression_consider_promo,
    SUM(sstf_fail_ads) AS sstf_fail_ads
  FROM (
    SELECT
      slot.event_date,
      network_id,
      COUNT(1) AS slot_count,
      SUM(slot.slot__max_duration) AS slot_duration,
      SUM(ad.phase9_num_ads) AS phase9_num_ads,
      SUM(ad.phase9_duration) AS phase9_duration,
      SUM(ad.phase10_num_ads) AS phase10_num_ads,
      SUM(ad.phase10_duration) AS phase10_duration,
      SUM(
        LEAST(
          (
            slot__max_duration - COALESCE(ad.phase9_duration, 0)
          ) / 24 + (
            slot__max_duration - COALESCE(ad.phase9_duration, 0)
          ) % 24 / 15,
          IF(
            CASE
              WHEN slot__time_position_class = 'midroll' AND COALESCE(slot__max_duration, 0) = 30
              THEN 1
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 60
              AND COALESCE(slot__max_duration, 0) <= 64
              THEN 3
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 170
              AND COALESCE(slot__max_duration, 0) <= 180
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 175
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 200
              AND COALESCE(slot__max_duration, 0) <= 210
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 204
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 90
              AND COALESCE(slot__max_duration, 0) <= 96
              THEN 3
              ELSE COALESCE(slot__max_duration, 0) / 15
            END < COALESCE(ad.phase9_num_ads, 0),
            0,
            CASE
              WHEN slot__time_position_class = 'midroll' AND COALESCE(slot__max_duration, 0) = 30
              THEN 1
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 60
              AND COALESCE(slot__max_duration, 0) <= 64
              THEN 3
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 170
              AND COALESCE(slot__max_duration, 0) <= 180
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 175
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 200
              AND COALESCE(slot__max_duration, 0) <= 210
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 204
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 90
              AND COALESCE(slot__max_duration, 0) <= 96
              THEN 3
              ELSE COALESCE(slot__max_duration, 0) / 15
            END - COALESCE(ad.phase9_num_ads, 0)
          )
        )
      ) AS nbcu_phase9_unfilled_avails,
      SUM(
        LEAST(
          (
            slot__max_duration - COALESCE(ad.phase10_duration, 0)
          ) / 24 + (
            slot__max_duration - COALESCE(ad.phase10_duration, 0)
          ) % 24 / 15,
          IF(
            CASE
              WHEN slot__time_position_class = 'midroll' AND COALESCE(slot__max_duration, 0) = 30
              THEN 1
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 60
              AND COALESCE(slot__max_duration, 0) <= 64
              THEN 3
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 170
              AND COALESCE(slot__max_duration, 0) <= 180
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 175
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 200
              AND COALESCE(slot__max_duration, 0) <= 210
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 204
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 90
              AND COALESCE(slot__max_duration, 0) <= 96
              THEN 3
              ELSE COALESCE(slot__max_duration, 0) / 15
            END < COALESCE(ad.phase10_num_ads, 0),
            0,
            CASE
              WHEN slot__time_position_class = 'midroll' AND COALESCE(slot__max_duration, 0) = 30
              THEN 1
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 60
              AND COALESCE(slot__max_duration, 0) <= 64
              THEN 3
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 170
              AND COALESCE(slot__max_duration, 0) <= 180
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 175
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 200
              AND COALESCE(slot__max_duration, 0) <= 210
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 204
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 90
              AND COALESCE(slot__max_duration, 0) <= 96
              THEN 3
              ELSE COALESCE(slot__max_duration, 0) / 15
            END - COALESCE(ad.phase10_num_ads, 0)
          )
        )
      ) AS nbcu_phase10_unfilled_avails,
      SUM(ad.sstf_fail_ads) AS sstf_fail_ads,
      0 AS impressions,
      0 AS impressions_consider_promo,
      SUM(ad.phase10_num_ads_consider_promo) AS phase10_num_ads_consider_promo,
      SUM(ad.phase10_duration_consider_promo) AS phase10_duration_consider_promo,
      SUM(
        LEAST(
          (
            slot__max_duration - COALESCE(ad.phase10_duration_consider_promo, 0)
          ) / 24 + (
            slot__max_duration - COALESCE(ad.phase10_duration_consider_promo, 0)
          ) % 24 / 15,
          IF(
            CASE
              WHEN slot__time_position_class = 'midroll' AND COALESCE(slot__max_duration, 0) = 30
              THEN 1
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 60
              AND COALESCE(slot__max_duration, 0) <= 64
              THEN 3
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 170
              AND COALESCE(slot__max_duration, 0) <= 180
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 175
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 200
              AND COALESCE(slot__max_duration, 0) <= 210
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 204
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 90
              AND COALESCE(slot__max_duration, 0) <= 96
              THEN 3
              ELSE COALESCE(slot__max_duration, 0) / 15
            END < COALESCE(ad.phase10_num_ads_consider_promo, 0),
            0,
            CASE
              WHEN slot__time_position_class = 'midroll' AND COALESCE(slot__max_duration, 0) = 30
              THEN 1
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 60
              AND COALESCE(slot__max_duration, 0) <= 64
              THEN 3
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 170
              AND COALESCE(slot__max_duration, 0) <= 180
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 175
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) >= 200
              AND COALESCE(slot__max_duration, 0) <= 210
              AND ack__timestamp >= CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 10
              WHEN slot__time_position_class = 'preroll'
              AND COALESCE(slot__max_duration, 0) = 204
              AND ack__timestamp < CAST('2023-03-09 00:00:00' AS TIMESTAMP)
              THEN 8
              WHEN slot__time_position_class = 'midroll'
              AND COALESCE(slot__max_duration, 0) >= 90
              AND COALESCE(slot__max_duration, 0) <= 96
              THEN 3
              ELSE COALESCE(slot__max_duration, 0) / 15
            END - COALESCE(ad.phase10_num_ads_consider_promo, 0)
          )
        )
      ) AS nbcu_phase10_unfilled_avails_consider_promo
    FROM ${bcv_slot}
    LEFT JOIN ${bcv_ad}
      ON slot.transaction_id = ad.transaction_id
      AND slot.server_id = ad.server_id
      AND slot.slot__time_position_class = ad.slot_time_position_class
      AND slot.slot__sequence = ad.slot_sequence
      AND slot.event_date = ad.event_date
    GROUP BY
      1,
      2
    UNION ALL
    SELECT
      DATE_TRUNC('DAY', ack__timestamp) AS event_date,
      nw.nw_id AS network_id,
      0 AS slot_count,
      0 AS slot_duration,
      0 AS phase9_num_ads,
      0 AS phase9_duration,
      0 AS phase10_num_ads,
      0 AS phase10_duration,
      0 AS nbcu_phase9_unfilled_avails,
      0 AS nbcu_phase10_unfilled_avails,
      0 AS sstf_fail_ads,
      SUM(1) AS impressions,
      0 AS impressions_consider_promo,
      0 AS phase10_num_ads_consider_promo,
      0 AS phase10_duration_consider_promo,
      0 AS nbcu_phase10_unfilled_avails_consider_promo
    FROM ${bcv_ack}
    CROSS JOIN UNNEST(partners__network_id, partners__role, partners__site_section_id) AS nw(nw_id, nw_role, site_section_id)
    JOIN (
      SELECT
        id,
        name
      FROM db.default.d_site_section
      WHERE
        (
          (
            network_id = 169843 AND LOWER(name) LIKE '%peacock%'
          )
          AND LOWER(name) NOT LIKE '%kids%'
        )
        AND LOWER(name) NOT LIKE '%teen%'
    ) AS ss
      ON ss.id = nw.site_section_id
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
                          request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
                        )
                        AND BITWISE_AND(slot__flags, 64) = 0
                      )
                      AND slot__time_position_class IN ('midroll')
                    )
                    AND COALESCE(nw.nw_role, '') = 'cro'
                  )
                  AND COALESCE(nw.nw_id, -1) = COALESCE(request__context__video_cro_network_id, -1)
                )
                AND nw.nw_id = 169843
              )
              AND IF(
                BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
                -3,
                COALESCE(request__context__profile_id, -1)
              ) <> 7712
            )
            AND COALESCE(visitor__country_id, -1) = 165
          )
          AND ack__ack_entity_type = 'ad'
        )
        AND COALESCE(ack__metrics__ad_impression, 0) > 0
      )
      AND advertisement__is_bumper = FALSE
    GROUP BY
      1,
      2
    UNION ALL
    SELECT
      DATE_TRUNC('DAY', ack__timestamp) AS event_date,
      nw.nw_id AS network_id,
      0 AS slot_count,
      0 AS slot_duration,
      0 AS phase9_num_ads,
      0 AS phase9_duration,
      0 AS phase10_num_ads,
      0 AS phase10_duration,
      0 AS nbcu_phase9_unfilled_avails,
      0 AS nbcu_phase10_unfilled_avails,
      0 AS sstf_fail_ads,
      0 AS impressions,
      SUM(1) AS impressions_consider_promo,
      0 AS phase10_num_ads_consider_promo,
      0 AS phase10_duration_consider_promo,
      0 AS nbcu_phase10_unfilled_avails_consider_promo
    FROM ${bcv_ack}
    CROSS JOIN UNNEST(partners__network_id, partners__role, partners__site_section_id) AS nw(nw_id, nw_role, site_section_id)
    JOIN (
      SELECT
        id,
        name
      FROM db.default.d_site_section
      WHERE
        (
          (
            network_id = 169843 AND LOWER(name) LIKE '%peacock%'
          )
          AND LOWER(name) NOT LIKE '%kids%'
        )
        AND LOWER(name) NOT LIKE '%teen%'
    ) AS ss
      ON ss.id = nw.site_section_id
    JOIN db.default.d_placement AS dbpl
      ON dbpl.id = advertisement__placement_id
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
                          NOT (
                            LOWER(dbpl.name) LIKE '%promo%'
                            AND BITWISE_AND(advertisement__flags, 33554432) > 0
                          )
                          AND (
                            request__delivery_method IS NULL OR request__delivery_method <> 'casucpsu'
                          )
                        )
                        AND BITWISE_AND(slot__flags, 64) = 0
                      )
                      AND slot__time_position_class IN ('midroll')
                    )
                    AND COALESCE(nw.nw_role, '') = 'cro'
                  )
                  AND COALESCE(nw.nw_id, -1) = COALESCE(request__context__video_cro_network_id, -1)
                )
                AND nw.nw_id = 169843
              )
              AND IF(
                BITWISE_AND(COALESCE(request__extra_flags, 0), 1073741824) > 0,
                -3,
                COALESCE(request__context__profile_id, -1)
              ) <> 7712
            )
            AND COALESCE(visitor__country_id, -1) = 165
          )
          AND ack__ack_entity_type = 'ad'
        )
        AND COALESCE(ack__metrics__ad_impression, 0) > 0
      )
      AND advertisement__is_bumper = FALSE
    GROUP BY
      1,
      2
  )
  GROUP BY
    1,
    2
)
