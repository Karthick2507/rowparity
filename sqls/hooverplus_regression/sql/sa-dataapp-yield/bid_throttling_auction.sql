-- account:    sa-dataapp-yield
-- skeleton:   8d2374576030ac76910b185d5bac5a9a
-- pattern:    bce3e64667ef69f1310294ae76d211f4  (701 execution(s))
-- in suite:   daily commitment
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
  CASE
    WHEN auction__integration_type = 'mkpl_partner_tag'
    THEN 60
    WHEN CONTAINS(partners__entity_source, 'auction')
    AND ELEMENT_AT(partners__supply_source_type, ARRAY_POSITION(partners__entity_source, 'auction')) = 'mpe'
    THEN 59
    ELSE 56
  END AS bucket_id,
  CASE
    WHEN auction__integration_type = 'mkpl_partner_tag'
    THEN COALESCE(partners__network_id[2], -1)
    ELSE COALESCE(auction__dsp_id, -1)
  END AS dsp_id,
  COALESCE(auction__network_id, -1) AS network_id,
  COALESCE(request__context__video_cro_network_id, -1) AS video_cro_network_id,
  IF(BITWISE_AND(request__extra_flags2, 65536) = 65536, 'true', 'false') AS is_sspu_traffic,
  IF(auction__bid_throttling_info__flags = 1, 'true', 'false') AS is_baseline,
  CASE
    WHEN auction__bid_throttling_info__flags IN (2, 6)
    THEN 'new_framework'
    ELSE 'false'
  END AS is_apply_outbound,
  CASE
    WHEN auction__bid_throttling_info__flags = 2
    THEN 'new_framework'
    ELSE 'false'
  END AS is_passed,
  CASE
    WHEN auction__bid_throttling_info__flags = 6
    THEN 'new_framework'
    ELSE 'false'
  END AS is_filtered,
  IF(
    auction__bid_throttling_info__flags = 6
    AND ALL_MATCH(auction__bid_throttling_info__model_info__model_id, e -> e IN (21, 22)),
    'true',
    'false'
  ) AS is_escaped_from_feedback,
  IF(
    auction__bid_throttling_info__flags = 2
    AND ALL_MATCH(auction__bid_throttling_info__model_info__model_id, e -> e IN (21, 22)),
    'true',
    'false'
  ) AS is_passed_by_feedback,
  IF(
    auction__buyer_group_id IS NULL,
    'pure_deal',
    IF(auction__invite_deal_size = 0, 'pure_ox', 'mix')
  ) AS is_open_exchange_auction,
  IF(NOT auction__bid_throttling_info IS NULL, 'new_framework', 'other_strategy') AS framework_type,
  COALESCE(request__server_pool, 'na') AS server_pool,
  COALESCE(request__server_group, 'na') AS server_group,
  CASE
    WHEN auction__bid_throttling_info__flags = 2
    AND ELEMENT_AT(
      auction__bid_throttling_info__model_info__model_flags,
      COALESCE(
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 55), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 57), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 59), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 63), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 65), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 69), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 71), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 73), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 75), 0)
      )
    ) = 2
    THEN 'true'
    ELSE 'false'
  END AS is_impression_model_passed,
  CASE
    WHEN auction__bid_throttling_info__flags = 2
    AND ELEMENT_AT(
      auction__bid_throttling_info__model_info__model_flags,
      COALESCE(
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 54), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 56), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 58), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 62), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 64), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 68), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 70), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 72), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 74), 0)
      )
    ) = 2
    THEN 'true'
    ELSE 'false'
  END AS is_response_model_passed,
  CASE
    WHEN auction__bid_throttling_info__flags = 2
    AND ELEMENT_AT(
      auction__bid_throttling_info__model_info__model_flags,
      COALESCE(
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 22), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 78), 0)
      )
    ) = 2
    THEN 'true'
    ELSE 'false'
  END AS is_rcpm_model_passed,
  CASE
    WHEN ELEMENT_AT(
      auction__bid_throttling_info__model_info__model_flags,
      COALESCE(
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 22), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 78), 0)
      )
    ) = 16
    THEN 'true'
    ELSE 'false'
  END AS is_rcpm_model_notfound,
  CASE
    WHEN ELEMENT_AT(
      auction__bid_throttling_info__model_info__model_flags,
      COALESCE(
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 22), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 78), 0)
      )
    ) = 32
    THEN 'true'
    ELSE 'false'
  END AS is_rcpm_model_undetermined,
  CASE
    WHEN auction__bid_throttling_info__flags = 2
    AND ELEMENT_AT(
      auction__bid_throttling_info__model_info__model_flags,
      COALESCE(
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 79), 0),
        NULLIF(ARRAY_POSITION(auction__bid_throttling_info__model_info__model_id, 80), 0)
      )
    ) = 2
    THEN 'true'
    ELSE 'false'
  END AS is_single_model_passed,
  SUM(
    1 * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
  ) AS request_logged,
  SUM(
    CASE
      WHEN auction__bid_throttling_info__flags = 6
      THEN COALESCE(1000 / CAST(auction__bid_throttling_info__exempt_thousandth AS DOUBLE) - 1, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1)
      ELSE 0
    END
  ) AS request_real_filtered
FROM ${bcv_auction}
WHERE
  (
    (
      BITWISE_AND(auction__auction_status, 2) = 2
      AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0
    )
    AND (
      (
        auction__integration_type IN ('normal')
      )
      OR (
        auction__integration_type = 'mkpl_partner_tag'
        AND BITWISE_AND(auction__auction_status, 64) = 0
        AND CONTAINS(auction__mkpl_partner_tags__strategy, 'incremental_demand')
      )
    )
  )
  AND COALESCE(request__delivery_method, 'mrmads') = 'mrmads'
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
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  19,
  20,
  21,
  22
