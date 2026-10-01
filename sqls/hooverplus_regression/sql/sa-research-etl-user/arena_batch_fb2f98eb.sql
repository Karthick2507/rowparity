-- account:    sa-research-etl-user
-- skeleton:   6d7df774d142ad8e987c7eeb90249f12
-- pattern:    fb2f98ebc0261c040f53166129b0b0b0  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id < CONCAT(REPLACE(SUBSTR(?, ?, ?), ?, ?), ?)
--   process_batch_id >= REPLACE(SUBSTR(?, ?, ?), ?, ?)
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  process_batch_id,
  COALESCE(request__context__network_id, CAST(-1 AS BIGINT)) AS network_id,
  COALESCE(partner.role, '') AS transaction_type,
  CAST(-1 AS BIGINT) AS scenario_id,
  COALESCE(request__context__site_section_id, CAST(-1 AS BIGINT)) AS site_section_id,
  IF(
    CARDINALITY(visitor__standard_device_type_ids) > 0,
    visitor__standard_device_type_ids[1],
    -1
  ) AS device_type,
  COALESCE(slot__time_position_class, 'unknown') AS time_position_class,
  IF(
    partner.network_is_ad_owner,
    COALESCE(advertisement__placement_id, CAST(-1 AS BIGINT)),
    CAST(-1 AS BIGINT)
  ) AS placement_id,
  request__context__profile_id AS profile_id,
  request__bid_request__app_bundle AS app_bundle,
  COALESCE(slot__sequence, -1) AS slot_sequence,
  SUM(IF(NOT advertisement__is_fallback, 1, 0)) AS selected_primary_ads,
  SUM(IF(advertisement__is_fallback, 1, 0)) AS selected_fallback_ads,
  advertisement__position_in_slot AS ad_position_in_slot,
  COALESCE(request__context__request_duration, 0.0) AS request_duration,
  REPLACE(SUBSTR('2026-08-14 00:00:00', 1, 10), '-', '') AS request_date
FROM ${bcv_ad}
CROSS JOIN UNNEST(partners__network_is_ad_owner, partners__network_is_extra_item_owner, partners__network_id, partners__role) AS partner(network_is_ad_owner, network_is_extra_item_owner, network_id, role)
WHERE
  (
    (
      advertisement__is_embedded_tracking = FALSE
      OR (
        advertisement__is_embedded_tracking
        AND (
          partner.network_is_ad_owner OR partner.network_is_extra_item_owner
        )
      )
    )
    AND advertisement__is_bumper = FALSE
  )
  AND advertisement__is_undeliverable = FALSE
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
  14,
  15
