-- account:    jou254
-- skeleton:   75d5313f4ac9359e450bea099deea9c9
-- pattern:    432299167eeb132f17ab0ebf22536676  (32 execution(s))
-- in suite:   daily commitment
-- hoover:     ack, auction, candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE(CURRENT_TIMESTAMP)
--   request__timestamp >= DATE(CURRENT_TIMESTAMP) - INTERVAL ? DAY

SELECT
  *,
  event_timestamp AS _arena_partition_event_timestamp
FROM (
  WITH cte_ack AS (
    SELECT
      DATE_TRUNC('HOUR', request__timestamp) AS timestamp,
      CASE
        WHEN candidate__integration_type = 'mkpl_partner_tag'
        THEN 60
        WHEN CONTAINS(partners__outbound_order_type, 'exchange_order')
        THEN 59
        ELSE 56
      END AS bucket_id,
      CASE
        WHEN candidate__integration_type = 'mkpl_partner_tag'
        THEN COALESCE(candidate__network_id, -1)
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
      SUM(
        COALESCE(ack__metrics__raw_ad_impression, 0) * COALESCE(request__log_sampling__magnifier, 1)
      ) AS impression_logged,
      SUM(
        CASE
          WHEN auction__bid_throttling_info__flags = 6
          THEN COALESCE(ack__metrics__raw_ad_impression, 0) * COALESCE(1000 / CAST(auction__bid_throttling_info__exempt_thousandth AS DOUBLE) - 1, 1) * COALESCE(request__log_sampling__magnifier, 1)
          ELSE 0
        END
      ) AS impression_real_filtered,
      SUM(
        COALESCE(ack__metrics__raw_ad_impression, 0) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(candidate__clearing_price, 0) * COALESCE(candidate__candidate_network_to_auction_network_exchange_rate, 0)
      ) AS revenue_logged,
      SUM(
        CASE
          WHEN auction__bid_throttling_info__flags = 6
          THEN COALESCE(ack__metrics__raw_ad_impression, 0) * COALESCE(1000 / CAST(auction__bid_throttling_info__exempt_thousandth AS DOUBLE) - 1, 1) * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(candidate__clearing_price, 0) * COALESCE(candidate__candidate_network_to_auction_network_exchange_rate, 0)
          ELSE 0
        END
      ) AS revenue_real_filtered
    FROM ${bcv_ack}
    WHERE
      (
        (
          BITWISE_AND(COALESCE(auction__auction_status, 0), 8) > 0
          AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0
        )
        AND (
          candidate__integration_type IN ('openrtb_normal')
          OR (
            candidate__integration_type = 'mkpl_partner_tag'
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
      16
  ), cte_auction AS (
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
          auction__integration_type IN ('normal')
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
      16
  ), cte_candidate AS (
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
      SUM(1 * COALESCE(request__log_sampling__magnifier, 1)) AS candidate_logged,
      SUM(
        CASE
          WHEN auction__bid_throttling_info__flags = 6
          THEN COALESCE(1000 / CAST(auction__bid_throttling_info__exempt_thousandth AS DOUBLE) - 1, 1) * COALESCE(request__log_sampling__magnifier, 1)
          ELSE 0
        END
      ) AS candidate_real_filtered
    FROM ${bcv_candidate}
    WHERE
      (
        (
          BITWISE_AND(auction__auction_status, 2) = 2
          AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0
        )
        AND (
          auction__integration_type IN ('normal')
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
      16
  )
  SELECT
    COALESCE(ack.timestamp, auction.timestamp, candidate.timestamp) AS event_timestamp,
    COALESCE(ack.bucket_id, auction.bucket_id, candidate.bucket_id) AS bucket_id,
    COALESCE(ack.dsp_id, auction.dsp_id, candidate.dsp_id) AS dsp_id,
    COALESCE(ack.network_id, auction.network_id, candidate.network_id) AS network_id,
    COALESCE(
      ack.video_cro_network_id,
      auction.video_cro_network_id,
      candidate.video_cro_network_id
    ) AS video_cro_network_id,
    COALESCE(ack.is_sspu_traffic, auction.is_sspu_traffic, candidate.is_sspu_traffic) AS is_sspu_traffic,
    COALESCE(ack.is_baseline, auction.is_baseline, candidate.is_baseline) AS is_baseline,
    COALESCE(ack.is_apply_outbound, auction.is_apply_outbound, candidate.is_apply_outbound) AS is_apply_outbound,
    COALESCE(ack.is_passed, auction.is_passed, candidate.is_passed) AS is_passed,
    COALESCE(ack.is_filtered, auction.is_filtered, candidate.is_filtered) AS is_filtered,
    COALESCE(
      ack.is_escaped_from_feedback,
      auction.is_escaped_from_feedback,
      candidate.is_escaped_from_feedback
    ) AS is_escaped_from_feedback,
    COALESCE(
      ack.is_passed_by_feedback,
      auction.is_passed_by_feedback,
      candidate.is_passed_by_feedback
    ) AS is_passed_by_feedback,
    COALESCE(
      ack.is_open_exchange_auction,
      auction.is_open_exchange_auction,
      candidate.is_open_exchange_auction
    ) AS is_open_exchange_auction,
    COALESCE(ack.framework_type, auction.framework_type, candidate.framework_type) AS framework_type,
    COALESCE(ack.server_pool, auction.server_pool, candidate.server_pool) AS server_pool,
    COALESCE(ack.server_group, auction.server_group, candidate.server_group) AS server_group,
    ack.impression_logged,
    CAST(ack.impression_real_filtered AS BIGINT) AS impression_real_filtered,
    CAST(ack.revenue_logged AS DECIMAL(38, 8)) AS revenue_logged,
    CAST(ack.revenue_real_filtered AS DECIMAL(38, 8)) AS revenue_real_filtered,
    auction.request_logged,
    CAST(auction.request_real_filtered AS BIGINT) AS request_real_filtered,
    candidate.candidate_logged,
    CAST(candidate.candidate_real_filtered AS BIGINT) AS candidate_real_filtered
  FROM cte_ack AS ack
  FULL OUTER JOIN cte_auction AS auction
    ON ack.timestamp = auction.timestamp
    AND ack.bucket_id = auction.bucket_id
    AND ack.dsp_id = auction.dsp_id
    AND ack.network_id = auction.network_id
    AND ack.video_cro_network_id = auction.video_cro_network_id
    AND ack.is_sspu_traffic = auction.is_sspu_traffic
    AND ack.is_baseline = auction.is_baseline
    AND ack.is_apply_outbound = auction.is_apply_outbound
    AND ack.is_passed = auction.is_passed
    AND ack.is_filtered = auction.is_filtered
    AND ack.is_escaped_from_feedback = auction.is_escaped_from_feedback
    AND ack.is_passed_by_feedback = auction.is_passed_by_feedback
    AND ack.is_open_exchange_auction = auction.is_open_exchange_auction
    AND ack.framework_type = auction.framework_type
    AND ack.server_pool = auction.server_pool
    AND ack.server_group = auction.server_group
  FULL OUTER JOIN cte_candidate AS candidate
    ON COALESCE(ack.timestamp, auction.timestamp) = candidate.timestamp
    AND COALESCE(ack.bucket_id, auction.bucket_id) = candidate.bucket_id
    AND COALESCE(ack.dsp_id, auction.dsp_id) = candidate.dsp_id
    AND COALESCE(ack.network_id, auction.network_id) = candidate.network_id
    AND COALESCE(ack.video_cro_network_id, auction.video_cro_network_id) = candidate.video_cro_network_id
    AND COALESCE(ack.is_sspu_traffic, auction.is_sspu_traffic) = candidate.is_sspu_traffic
    AND COALESCE(ack.is_baseline, auction.is_baseline) = candidate.is_baseline
    AND COALESCE(ack.is_apply_outbound, auction.is_apply_outbound) = candidate.is_apply_outbound
    AND COALESCE(ack.is_passed, auction.is_passed) = candidate.is_passed
    AND COALESCE(ack.is_filtered, auction.is_filtered) = candidate.is_filtered
    AND COALESCE(ack.is_escaped_from_feedback, auction.is_escaped_from_feedback) = candidate.is_escaped_from_feedback
    AND COALESCE(ack.is_passed_by_feedback, auction.is_passed_by_feedback) = candidate.is_passed_by_feedback
    AND COALESCE(ack.is_open_exchange_auction, auction.is_open_exchange_auction) = candidate.is_open_exchange_auction
    AND COALESCE(ack.framework_type, auction.framework_type) = candidate.framework_type
    AND COALESCE(ack.server_pool, auction.server_pool) = candidate.server_pool
    AND COALESCE(ack.server_group, auction.server_group) = candidate.server_group
) AS arena_tmp
