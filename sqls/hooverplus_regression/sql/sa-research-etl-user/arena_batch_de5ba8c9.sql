-- account:    sa-research-etl-user
-- skeleton:   fd08263254584630ad9c98bcfa1e6088
-- pattern:    de5ba8c92e1d7eb92e3b60d424cecd76  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     ack, auction, candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH auction_table AS (
  SELECT
    DATE_FORMAT(request__timestamp, '%y-%m-%d-%h') AS event_date_hour,
    IF(
      auction__network_id = 523319
      AND CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    ) AS partner__network_id,
    auction__network_id AS auction__network_id,
    COALESCE(auction__app_bundle, '-3') AS app_bundle,
    COALESCE(visitor__country_id, -3) AS user_country_id,
    COALESCE(auction__dsp_id, -3) AS rtb_auction__dsp_id,
    15 AS max_duration,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 2097152) > 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_baseline,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_probe_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) > 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_probe_additional,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 8388608) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_feedback_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 8388608) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) > 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_feedback_additional,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 4) > 0
        AND BITWISE_AND(auction__extra_flags, 2) = 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_v2_probe_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 4) > 0
        AND BITWISE_AND(auction__extra_flags, 2) > 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_v2_probe_additional,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 8) > 0
        AND BITWISE_AND(auction__extra_flags, 2) = 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_v2_feedback_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 8) > 0
        AND BITWISE_AND(auction__extra_flags, 2) > 0,
        COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_v2_feedback_additional
  FROM ${bcv_auction}
  WHERE
    (
      (
        (
          (
            NOT (
              CONTAINS(auction__ab_test_items__collection_id, 42)
              AND CONTAINS(auction__ab_test_items__bucket_id, 142)
            )
            AND NOT CONTAINS(auction__ab_test_items__collection_id, 58)
          )
          OR (
            auction__ab_test_items__collection_id IS NULL
          )
          OR (
            auction__ab_test_items__bucket_id IS NULL
          )
        )
        AND auction__integration_type IN ('normal')
      )
      AND COALESCE(request__traffic_type, -1) <= 0
    )
    AND auction__network_id = 523319
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7
), candidate_table AS (
  SELECT
    DATE_FORMAT(request__timestamp, '%y-%m-%d-%h') AS event_date_hour,
    IF(
      auction__network_id = 523319
      AND CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    ) AS partner__network_id,
    auction__network_id AS auction__network_id,
    COALESCE(auction__app_bundle, '-3') AS app_bundle,
    COALESCE(visitor__country_id, -3) AS user_country_id,
    COALESCE(auction__dsp_id, -3) AS rtb_auction__dsp_id,
    15 AS max_duration,
    SUM(IF(BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0, 1, 0)) AS bids_resolved,
    SUM(
      IF(
        BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 2097152) > 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_baseline,
    SUM(
      IF(
        BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_probe_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) > 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_probe_additional,
    SUM(
      IF(
        BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 8388608) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_feedback_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 8388608) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) > 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_feedback_additional,
    SUM(
      IF(
        BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 4) > 0
        AND BITWISE_AND(auction__extra_flags, 2) = 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_v2_probe_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 4) > 0
        AND BITWISE_AND(auction__extra_flags, 2) > 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_v2_probe_additional,
    SUM(
      IF(
        BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 8) > 0
        AND BITWISE_AND(auction__extra_flags, 2) = 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_v2_feedback_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 8) > 0
        AND BITWISE_AND(auction__extra_flags, 2) > 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_v2_feedback_additional
  FROM ${bcv_candidate}
  WHERE
    (
      (
        (
          (
            NOT (
              CONTAINS(auction__ab_test_items__collection_id, 42)
              AND CONTAINS(auction__ab_test_items__bucket_id, 142)
            )
            AND NOT CONTAINS(auction__ab_test_items__collection_id, 58)
          )
          OR (
            auction__ab_test_items__collection_id IS NULL
          )
          OR (
            auction__ab_test_items__bucket_id IS NULL
          )
        )
        AND candidate__integration_type IN ('openrtb_normal')
      )
      AND COALESCE(request__traffic_type, -1) <= 0
    )
    AND auction__network_id = 523319
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7
), revenue_table AS (
  SELECT
    DATE_FORMAT(request__timestamp, '%y-%m-%d-%h') AS event_date_hour,
    IF(
      auction__network_id = 523319 AND ARRAY_POSITION(partners__network_id, 523319) > 1,
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_id, 523319) - 1),
      -1
    ) AS partner__network_id,
    auction__network_id AS auction__network_id,
    COALESCE(auction__app_bundle, '-3') AS app_bundle,
    COALESCE(visitor__country_id, -3) AS user_country_id,
    COALESCE(auction__dsp_id, -3) AS rtb_auction__dsp_id,
    15 AS max_duration,
    SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS ack_ad_impression,
    SUM(
      IF(
        BITWISE_AND(auction__flags, 2097152) > 0,
        COALESCE(ack__metrics__raw_ad_impression, 0),
        0
      )
    ) AS ack_ad_impression_smartly_bidding_baseline,
    SUM(
      IF(
        BITWISE_AND(auction__flags, 4194304) > 0
        AND BITWISE_AND(auction__flags, 1048576) = 0,
        COALESCE(ack__metrics__raw_ad_impression, 0),
        0
      )
    ) AS ack_ad_impression_smartly_bidding_probe_original,
    SUM(
      IF(
        BITWISE_AND(auction__flags, 4194304) > 0
        AND BITWISE_AND(auction__flags, 1048576) > 0,
        COALESCE(ack__metrics__raw_ad_impression, 0),
        0
      )
    ) AS ack_ad_impression_smartly_bidding_probe_additional,
    SUM(
      IF(
        BITWISE_AND(auction__flags, 8388608) > 0
        AND BITWISE_AND(auction__flags, 1048576) = 0,
        COALESCE(ack__metrics__raw_ad_impression, 0),
        0
      )
    ) AS ack_ad_impression_smartly_bidding_feedback_original,
    SUM(
      IF(
        BITWISE_AND(auction__flags, 8388608) > 0
        AND BITWISE_AND(auction__flags, 1048576) > 0,
        COALESCE(ack__metrics__raw_ad_impression, 0),
        0
      )
    ) AS ack_ad_impression_smartly_bidding_feedback_additional,
    SUM(
      IF(
        BITWISE_AND(auction__extra_flags, 4) > 0
        AND BITWISE_AND(auction__extra_flags, 2) = 0,
        COALESCE(ack__metrics__raw_ad_impression, 0),
        0
      )
    ) AS ack_ad_impression_smartly_bidding_v2_probe_original,
    SUM(
      IF(
        BITWISE_AND(auction__extra_flags, 4) > 0
        AND BITWISE_AND(auction__extra_flags, 2) > 0,
        COALESCE(ack__metrics__raw_ad_impression, 0),
        0
      )
    ) AS ack_ad_impression_smartly_bidding_v2_probe_additional,
    SUM(
      IF(
        BITWISE_AND(auction__extra_flags, 8) > 0
        AND BITWISE_AND(auction__extra_flags, 2) = 0,
        COALESCE(ack__metrics__raw_ad_impression, 0),
        0
      )
    ) AS ack_ad_impression_smartly_bidding_v2_feedback_original,
    SUM(
      IF(
        BITWISE_AND(auction__extra_flags, 8) > 0
        AND BITWISE_AND(auction__extra_flags, 2) > 0,
        COALESCE(ack__metrics__raw_ad_impression, 0),
        0
      )
    ) AS ack_ad_impression_smartly_bidding_v2_feedback_additional,
    SUM(
      COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000
    ) AS ack_ad_revenue,
    SUM(
      IF(
        BITWISE_AND(auction__flags, 2097152) > 0,
        COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
        0
      )
    ) AS ack_ad_revenue_smartly_bidding_baseline,
    SUM(
      IF(
        BITWISE_AND(auction__flags, 4194304) > 0
        AND BITWISE_AND(auction__flags, 1048576) = 0,
        COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
        0
      )
    ) AS ack_ad_revenue_smartly_bidding_probe_original,
    SUM(
      IF(
        BITWISE_AND(auction__flags, 4194304) > 0
        AND BITWISE_AND(auction__flags, 1048576) > 0,
        COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
        0
      )
    ) AS ack_ad_revenue_smartly_bidding_probe_additional,
    SUM(
      IF(
        BITWISE_AND(auction__flags, 8388608) > 0
        AND BITWISE_AND(auction__flags, 1048576) = 0,
        COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
        0
      )
    ) AS ack_ad_revenue_smartly_bidding_feedback_original,
    SUM(
      IF(
        BITWISE_AND(auction__flags, 8388608) > 0
        AND BITWISE_AND(auction__flags, 1048576) > 0,
        COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
        0
      )
    ) AS ack_ad_revenue_smartly_bidding_feedback_additional,
    SUM(
      IF(
        BITWISE_AND(auction__extra_flags, 4) > 0
        AND BITWISE_AND(auction__extra_flags, 2) = 0,
        COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
        0
      )
    ) AS ack_ad_revenue_smartly_bidding_v2_probe_original,
    SUM(
      IF(
        BITWISE_AND(auction__extra_flags, 4) > 0
        AND BITWISE_AND(auction__extra_flags, 2) > 0,
        COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
        0
      )
    ) AS ack_ad_revenue_smartly_bidding_v2_probe_additional,
    SUM(
      IF(
        BITWISE_AND(auction__extra_flags, 8) > 0
        AND BITWISE_AND(auction__extra_flags, 2) = 0,
        COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
        0
      )
    ) AS ack_ad_revenue_smartly_bidding_v2_feedback_original,
    SUM(
      IF(
        BITWISE_AND(auction__extra_flags, 8) > 0
        AND BITWISE_AND(auction__extra_flags, 2) > 0,
        COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000,
        0
      )
    ) AS ack_ad_revenue_smartly_bidding_v2_feedback_additional
  FROM ${bcv_ack}
  WHERE
    (
      (
        (
          (
            (
              NOT (
                CONTAINS(auction__ab_test_items__collection_id, 42)
                AND CONTAINS(auction__ab_test_items__bucket_id, 142)
              )
              AND NOT CONTAINS(auction__ab_test_items__collection_id, 58)
            )
            OR (
              auction__ab_test_items__collection_id IS NULL
            )
            OR (
              auction__ab_test_items__bucket_id IS NULL
            )
          )
          AND candidate__integration_type IN ('openrtb_normal')
        )
        AND COALESCE(ack__traffic_type, -1) <= 0
      )
      AND auction__network_id = 523319
    )
    AND ack__ack_entity_type = 'ad'
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7
)
SELECT
  ARRAY_JOIN(
    IF(
      auction_table.auction__network_id = 523319,
      ARRAY[auction_table.partner__network_id, auction_table.auction__network_id],
      ARRAY[auction_table.auction__network_id]
    ),
    '-'
  ) AS publisher_id,
  auction_table.app_bundle AS app_bundle,
  auction_table.user_country_id AS user_country_id,
  auction_table.rtb_auction__dsp_id AS rtb_auction__dsp_id,
  auction_table.max_duration AS max_duration,
  COALESCE(auction_request, 0) AS auction_request,
  COALESCE(auction_request_smartly_bidding_baseline, 0) AS auction_request_smartly_bidding_baseline,
  COALESCE(auction_request_smartly_bidding_probe_original, 0) AS auction_request_smartly_bidding_probe_original,
  COALESCE(auction_request_smartly_bidding_probe_additional, 0) AS auction_request_smartly_bidding_probe_additional,
  COALESCE(auction_request_smartly_bidding_feedback_original, 0) AS auction_request_smartly_bidding_feedback_original,
  COALESCE(auction_request_smartly_bidding_feedback_additional, 0) AS auction_request_smartly_bidding_feedback_additional,
  COALESCE(auction_request_smartly_bidding_v2_probe_original, 0) AS auction_request_smartly_bidding_v2_probe_original,
  COALESCE(auction_request_smartly_bidding_v2_probe_additional, 0) AS auction_request_smartly_bidding_v2_probe_additional,
  COALESCE(auction_request_smartly_bidding_v2_feedback_original, 0) AS auction_request_smartly_bidding_v2_feedback_original,
  COALESCE(auction_request_smartly_bidding_v2_feedback_additional, 0) AS auction_request_smartly_bidding_v2_feedback_additional,
  COALESCE(bids_resolved, 0) AS bids_resolved,
  COALESCE(bids_resolved_smartly_bidding_baseline, 0) AS bids_resolved_smartly_bidding_baseline,
  COALESCE(bids_resolved_smartly_bidding_probe_original, 0) AS bids_resolved_smartly_bidding_probe_original,
  COALESCE(bids_resolved_smartly_bidding_probe_additional, 0) AS bids_resolved_smartly_bidding_probe_additional,
  COALESCE(bids_resolved_smartly_bidding_feedback_original, 0) AS bids_resolved_smartly_bidding_feedback_original,
  COALESCE(bids_resolved_smartly_bidding_feedback_additional, 0) AS bids_resolved_smartly_bidding_feedback_additional,
  COALESCE(bids_resolved_smartly_bidding_v2_probe_original, 0) AS bids_resolved_smartly_bidding_v2_probe_original,
  COALESCE(bids_resolved_smartly_bidding_v2_probe_additional, 0) AS bids_resolved_smartly_bidding_v2_probe_additional,
  COALESCE(bids_resolved_smartly_bidding_v2_feedback_original, 0) AS bids_resolved_smartly_bidding_v2_feedback_original,
  COALESCE(bids_resolved_smartly_bidding_v2_feedback_additional, 0) AS bids_resolved_smartly_bidding_v2_feedback_additional,
  COALESCE(revenue_table.ack_ad_impression, 0) AS ack_ad_impression,
  COALESCE(revenue_table.ack_ad_impression_smartly_bidding_baseline, 0) AS ack_ad_impression_smartly_bidding_baseline,
  COALESCE(revenue_table.ack_ad_impression_smartly_bidding_probe_original, 0) AS ack_ad_impression_smartly_bidding_probe_original,
  COALESCE(revenue_table.ack_ad_impression_smartly_bidding_probe_additional, 0) AS ack_ad_impression_smartly_bidding_probe_additional,
  COALESCE(revenue_table.ack_ad_impression_smartly_bidding_feedback_original, 0) AS ack_ad_impression_smartly_bidding_feedback_original,
  COALESCE(revenue_table.ack_ad_impression_smartly_bidding_feedback_additional, 0) AS ack_ad_impression_smartly_bidding_feedback_additional,
  COALESCE(revenue_table.ack_ad_impression_smartly_bidding_v2_probe_original, 0) AS ack_ad_impression_smartly_bidding_v2_probe_original,
  COALESCE(revenue_table.ack_ad_impression_smartly_bidding_v2_probe_additional, 0) AS ack_ad_impression_smartly_bidding_v2_probe_additional,
  COALESCE(revenue_table.ack_ad_impression_smartly_bidding_v2_feedback_original, 0) AS ack_ad_impression_smartly_bidding_v2_feedback_original,
  COALESCE(revenue_table.ack_ad_impression_smartly_bidding_v2_feedback_additional, 0) AS ack_ad_impression_smartly_bidding_v2_feedback_additional,
  COALESCE(revenue_table.ack_ad_revenue, 0) AS ack_ad_revenue,
  COALESCE(revenue_table.ack_ad_revenue_smartly_bidding_baseline, 0) AS ack_ad_revenue_smartly_bidding_baseline,
  COALESCE(revenue_table.ack_ad_revenue_smartly_bidding_probe_original, 0) AS ack_ad_revenue_smartly_bidding_probe_original,
  COALESCE(revenue_table.ack_ad_revenue_smartly_bidding_probe_additional, 0) AS ack_ad_revenue_smartly_bidding_probe_additional,
  COALESCE(revenue_table.ack_ad_revenue_smartly_bidding_feedback_original, 0) AS ack_ad_revenue_smartly_bidding_feedback_original,
  COALESCE(revenue_table.ack_ad_revenue_smartly_bidding_feedback_additional, 0) AS ack_ad_revenue_smartly_bidding_feedback_additional,
  COALESCE(revenue_table.ack_ad_revenue_smartly_bidding_v2_probe_original, 0) AS ack_ad_revenue_smartly_bidding_v2_probe_original,
  COALESCE(revenue_table.ack_ad_revenue_smartly_bidding_v2_probe_additional, 0) AS ack_ad_revenue_smartly_bidding_v2_probe_additional,
  COALESCE(revenue_table.ack_ad_revenue_smartly_bidding_v2_feedback_original, 0) AS ack_ad_revenue_smartly_bidding_v2_feedback_original,
  COALESCE(revenue_table.ack_ad_revenue_smartly_bidding_v2_feedback_additional, 0) AS ack_ad_revenue_smartly_bidding_v2_feedback_additional,
  auction_table.event_date_hour
FROM auction_table
LEFT OUTER JOIN candidate_table
  ON auction_table.partner__network_id = candidate_table.partner__network_id
  AND auction_table.auction__network_id = candidate_table.auction__network_id
  AND auction_table.app_bundle = candidate_table.app_bundle
  AND auction_table.user_country_id = candidate_table.user_country_id
  AND auction_table.rtb_auction__dsp_id = candidate_table.rtb_auction__dsp_id
  AND auction_table.max_duration = candidate_table.max_duration
  AND auction_table.event_date_hour = candidate_table.event_date_hour
LEFT OUTER JOIN revenue_table
  ON auction_table.partner__network_id = revenue_table.partner__network_id
  AND auction_table.auction__network_id = revenue_table.auction__network_id
  AND auction_table.app_bundle = revenue_table.app_bundle
  AND auction_table.user_country_id = revenue_table.user_country_id
  AND auction_table.rtb_auction__dsp_id = revenue_table.rtb_auction__dsp_id
  AND auction_table.max_duration = revenue_table.max_duration
  AND auction_table.event_date_hour = revenue_table.event_date_hour
