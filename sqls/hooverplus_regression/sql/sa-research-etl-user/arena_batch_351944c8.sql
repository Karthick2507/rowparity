-- account:    sa-research-etl-user
-- skeleton:   1b17a9b970d9da176d706b51af9c6df7
-- pattern:    351944c8b26aa2fa12f8fd5f14dfdc63  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     ack, auction, candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

WITH auction_table AS (
  SELECT
    DATE_FORMAT(request__timestamp, '%y-%m-%d-%h') AS event_date_hour,
    DATE_FORMAT(request__timestamp, '%y-%m-%d %h:00:00') AS timestamp,
    CASE
      WHEN auction__integration_type = 'normal'
      THEN 'fullstack_non_pg'
      WHEN auction__integration_type = 'pg_td'
      THEN 'fullstack_pg'
      WHEN auction__integration_type = 'sfx'
      THEN 'sfx_openrtb'
      ELSE 'sfx_tag'
    END AS market_integration_type,
    COALESCE(auction__dsp_id, -1) AS dsp_id,
    COALESCE(d_dsp.name, 'na') AS dsp_name,
    COALESCE(auction__network_id, -1) AS auction_network_id,
    COALESCE(d_network.name, 'na') AS auction_network_name,
    IF(
      auction__network_id = 523319
      AND CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    ) AS auction_upstream_network_id,
    COALESCE(auc_upstream.name, 'na') AS auction_upstream_network_name,
    COALESCE(NULLIF(auction__ab_test_items__bucket_id, ARRAY[]), ARRAY[-1]) AS bucket_id,
    COALESCE(NULLIF(auction__ab_test_items__collection_id, ARRAY[]), ARRAY[-1]) AS collection_id,
    BITWISE_AND(COALESCE(auction__flags, 0), 1075838976) > 0 AS is_smart_bidding_traffic,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0,
        1 * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_sent,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 2097152) > 0,
        1 * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_baseline,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
        1 * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_probe_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) > 0,
        1 * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_probe_additional,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 8388608) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
        1 * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_feedback_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 8388608) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) > 0,
        1 * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_feedback_additional,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 4) > 0
        AND BITWISE_AND(auction__extra_flags, 2) = 0,
        1 * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_v2_probe_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 4) > 0
        AND BITWISE_AND(auction__extra_flags, 2) > 0,
        1 * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_v2_probe_additional,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 8) > 0
        AND BITWISE_AND(auction__extra_flags, 2) = 0,
        1 * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_v2_feedback_original,
    SUM(
      IF(
        BITWISE_AND(COALESCE(auction__auction_status, 0), 2) > 0
        AND BITWISE_AND(auction__extra_flags, 8) > 0
        AND BITWISE_AND(auction__extra_flags, 2) > 0,
        1 * COALESCE(request__log_sampling__magnifier, 1) * COALESCE(auction__auction_sampling__magnifier, 1),
        0
      )
    ) AS auction_request_smartly_bidding_v2_feedback_additional
  FROM ${bcv_auction}
  LEFT JOIN db.default.d_ssp_demand_side_platform AS d_dsp
    ON d_dsp.id = auction__dsp_id
  LEFT JOIN db.default.d_network AS d_network
    ON auction__network_id = d_network.id
  LEFT JOIN db.default.d_network AS auc_upstream
    ON auc_upstream.id = IF(
      auction__network_id = 523319
      AND CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    )
  WHERE
    (
      auction__integration_type IN ('normal', 'pg_td', 'sfx', 'reseller_tag')
      AND BITWISE_AND(auction__flags, 8) = 0
    )
    AND BITWISE_AND(auction__flags, 64) = 0
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
    12
), candidate_table AS (
  SELECT
    DATE_FORMAT(request__timestamp, '%y-%m-%d-%h') AS event_date_hour,
    DATE_FORMAT(request__timestamp, '%y-%m-%d %h:00:00') AS timestamp,
    CASE
      WHEN candidate__integration_type = 'openrtb_pg_td'
      THEN 'fullstack_pg'
      WHEN candidate__integration_type = 'openrtb_normal'
      THEN 'fullstack_non_pg'
      WHEN candidate__integration_type = 'openrtb_sfx'
      THEN 'sfx_openrtb'
      WHEN candidate__integration_type = 'reseller_tag'
      AND candidate__external_network_id = 127719
      THEN 'sfx_tag'
      WHEN candidate__integration_type = 'reseller_tag'
      THEN 'ssp_others'
      WHEN candidate__integration_type = 'mkpl_partner_tag'
      THEN 'mkpl_partner_tag'
      ELSE 'na'
    END AS market_integration_type,
    COALESCE(candidate__dsp_id, -1) AS dsp_id,
    COALESCE(d_dsp.name, 'na') AS dsp_name,
    COALESCE(auction__network_id, -1) AS auction_network_id,
    COALESCE(auc_network.name, 'na') AS auction_network_name,
    IF(
      auction__network_id = 523319
      AND CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    ) AS auction_upstream_network_id,
    COALESCE(auc_upstream.name, 'na') AS auction_upstream_network_name,
    COALESCE(NULLIF(auction__ab_test_items__bucket_id, ARRAY[]), ARRAY[-1]) AS bucket_id,
    COALESCE(NULLIF(auction__ab_test_items__collection_id, ARRAY[]), ARRAY[-1]) AS collection_id,
    BITWISE_AND(COALESCE(auction__flags, 0), 1075838976) > 0 AS is_smart_bidding_traffic,
    SUM(IF(BITWISE_AND(COALESCE(candidate__bid_status, 0), 2) > 0, 1, 0)) AS bids_resolved,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 2097152) > 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_baseline,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_probe_original,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 4194304) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) > 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_probe_additional,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 2) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 8388608) > 0
        AND BITWISE_AND(COALESCE(auction__flags, 0), 1048576) = 0,
        1,
        0
      )
    ) AS bids_resolved_smartly_bidding_feedback_original,
    SUM(
      IF(
        BITWISE_AND(candidate__bid_status, 2) > 0
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
  LEFT JOIN db.default.d_ssp_demand_side_platform AS d_dsp
    ON d_dsp.id = candidate__dsp_id
  LEFT JOIN db.default.d_ssp_buyer_platform
    ON d_ssp_buyer_platform.id = candidate__buyer_platform_id
  LEFT JOIN db.default.d_network AS cand_network
    ON candidate__network_id = cand_network.id
  LEFT JOIN db.default.d_network AS auc_network
    ON auction__network_id = auc_network.id
  LEFT JOIN db.default.d_network AS cro
    ON cro.id = request__context__video_cro_network_id
  LEFT JOIN db.default.d_network AS dis
    ON dis.id = request__context__network_id
  LEFT JOIN db.default.d_network AS auc_upstream
    ON auc_upstream.id = IF(
      auction__network_id = 523319
      AND CONTAINS(partners__entity_source, 'auction_upstream'),
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__entity_source, 'auction_upstream')),
      -1
    )
  LEFT JOIN db.default.d_ad_environment_compound_profile AS p
    ON p.id = request__context__profile_id
  WHERE
    candidate__integration_type IN (
      'openrtb_normal',
      'openrtb_pg_td',
      'openrtb_sfx',
      'reseller_tag',
      'mkpl_partner_tag'
    )
    AND BITWISE_AND(auction__flags, 8) = 0
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
    12
), revenue_table AS (
  SELECT
    DATE_FORMAT(ack__timestamp, '%y-%m-%d-%h') AS event_date_hour,
    DATE_FORMAT(ack__timestamp, '%y-%m-%d %h:00:00') AS timestamp,
    CASE
      WHEN candidate__integration_type = 'openrtb_pg_td'
      THEN 'fullstack_pg'
      WHEN candidate__integration_type = 'openrtb_normal'
      THEN 'fullstack_non_pg'
      WHEN candidate__integration_type = 'openrtb_sfx'
      THEN 'sfx_openrtb'
      WHEN candidate__integration_type = 'reseller_tag'
      AND advertisement__external_reseller__network_id = 127719
      THEN 'sfx_tag'
      WHEN candidate__integration_type = 'reseller_tag'
      THEN 'ssp_others'
      WHEN candidate__integration_type = 'mkpl_partner_tag'
      THEN 'mkpl_partner_tag'
      ELSE 'na'
    END AS market_integration_type,
    COALESCE(candidate__dsp_id, -1) AS dsp_id,
    COALESCE(d_dsp.name, 'na') AS dsp_name,
    COALESCE(auction__network_id, -1) AS auction_network_id,
    COALESCE(auc_network.name, 'na') AS auction_network_name,
    IF(
      auction__network_id = 523319 AND ARRAY_POSITION(partners__network_id, 523319) > 1,
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_id, 523319) - 1),
      -1
    ) AS auction_upstream_network_id,
    COALESCE(auc_upstream.name, 'na') AS auction_upstream_network_name,
    COALESCE(NULLIF(auction__ab_test_items__bucket_id, ARRAY[]), ARRAY[-1]) AS bucket_id,
    COALESCE(NULLIF(auction__ab_test_items__collection_id, ARRAY[]), ARRAY[-1]) AS collection_id,
    BITWISE_AND(COALESCE(auction__flags, 0), 1075838976) > 0 AS is_smart_bidding_traffic,
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
      CASE
        WHEN candidate__integration_type IN ('reseller_tag', 'openrtb_sfx')
        AND NOT advertisement__external_reseller__up_revenue IS NULL
        THEN advertisement__external_reseller__up_revenue * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0)
        WHEN candidate__integration_type IN ('openrtb_normal', 'openrtb_pg_td')
        THEN COALESCE(candidate__clearing_price, 0) * candidate__candidate_network_to_auction_network_exchange_rate * auction__auction_network_to_usd_exchange_rate * COALESCE(ack__metrics__raw_ad_impression, 0) / 1000
        WHEN candidate__integration_type IN ('mkpl_partner_tag')
        THEN COALESCE(
          ELEMENT_AT(
            REVERSE(partners__revenue),
            ARRAY_POSITION(REVERSE(partners__network_id), auction__network_id)
          ),
          0
        ) * COALESCE(
          ELEMENT_AT(
            MAP_FROM_ENTRIES(ARRAY[(62, 1.0), (49, 1.1421), (44, 1.3196), (21, 0.1097)]),
            auc_network.default_currency_id
          ),
          1
        ) * COALESCE(ack__metrics__raw_ad_impression, 0)
        ELSE 0
      END
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
  FROM ${bcv_ack} AS t1
  LEFT JOIN db.default.d_ssp_demand_side_platform AS d_dsp
    ON d_dsp.id = candidate__dsp_id
  LEFT JOIN db.default.d_network AS auc_network
    ON auction__network_id = auc_network.id
  LEFT JOIN db.default.d_network AS auc_upstream
    ON auc_upstream.id = IF(
      auction__network_id = 523319 AND ARRAY_POSITION(partners__network_id, 523319) > 1,
      ELEMENT_AT(partners__network_id, ARRAY_POSITION(partners__network_id, 523319) - 1),
      -1
    )
  WHERE
    (
      (
        candidate__integration_type IN (
          'openrtb_normal',
          'openrtb_pg_td',
          'reseller_tag',
          'openrtb_sfx',
          'mkpl_partner_tag'
        )
        AND BITWISE_AND(auction__flags, 8) = 0
      )
      AND ack__ack_entity_type = 'ad'
    )
    AND COALESCE(ack__traffic_type, -1) <= 0
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
    12
)
SELECT
  auction_table.timestamp AS __time,
  0 AS ack_ad_impression,
  0 AS ack_ad_impression_smartly_bidding_baseline,
  0 AS ack_ad_impression_smartly_bidding_feedback_additional,
  0 AS ack_ad_impression_smartly_bidding_feedback_original,
  0 AS ack_ad_impression_smartly_bidding_probe_additional,
  0 AS ack_ad_impression_smartly_bidding_probe_original,
  0 AS ack_ad_impression_smartly_bidding_v2_feedback_additional,
  0 AS ack_ad_impression_smartly_bidding_v2_feedback_original,
  0 AS ack_ad_impression_smartly_bidding_v2_probe_additional,
  0 AS ack_ad_impression_smartly_bidding_v2_probe_original,
  0 AS ack_ad_revenue,
  0 AS ack_ad_revenue_smartly_bidding_baseline,
  0 AS ack_ad_revenue_smartly_bidding_feedback_additional,
  0 AS ack_ad_revenue_smartly_bidding_feedback_original,
  0 AS ack_ad_revenue_smartly_bidding_probe_additional,
  0 AS ack_ad_revenue_smartly_bidding_probe_original,
  0 AS ack_ad_revenue_smartly_bidding_v2_feedback_additional,
  0 AS ack_ad_revenue_smartly_bidding_v2_feedback_original,
  0 AS ack_ad_revenue_smartly_bidding_v2_probe_additional,
  0 AS ack_ad_revenue_smartly_bidding_v2_probe_original,
  auction_table.auction_network_id AS auction_network_id,
  auction_table.auction_network_name AS auction_network_name,
  auction_table.auction_request_sent AS auction_request_sent,
  auction_table.auction_request_smartly_bidding_baseline AS auction_request_smartly_bidding_baseline,
  auction_table.auction_request_smartly_bidding_feedback_additional AS auction_request_smartly_bidding_feedback_additional,
  auction_table.auction_request_smartly_bidding_feedback_original AS auction_request_smartly_bidding_feedback_original,
  auction_table.auction_request_smartly_bidding_probe_additional AS auction_request_smartly_bidding_probe_additional,
  auction_table.auction_request_smartly_bidding_probe_original AS auction_request_smartly_bidding_probe_original,
  auction_table.auction_request_smartly_bidding_v2_feedback_additional AS auction_request_smartly_bidding_v2_feedback_additional,
  auction_table.auction_request_smartly_bidding_v2_feedback_original AS auction_request_smartly_bidding_v2_feedback_original,
  auction_table.auction_request_smartly_bidding_v2_probe_additional AS auction_request_smartly_bidding_v2_probe_additional,
  auction_table.auction_request_smartly_bidding_v2_probe_original AS auction_request_smartly_bidding_v2_probe_original,
  auction_table.auction_upstream_network_id AS auction_upstream_network_id,
  auction_table.auction_upstream_network_name AS auction_upstream_network_name,
  0 AS bids_resolved,
  0 AS bids_resolved_smartly_bidding_baseline,
  0 AS bids_resolved_smartly_bidding_feedback_additional,
  0 AS bids_resolved_smartly_bidding_feedback_original,
  0 AS bids_resolved_smartly_bidding_probe_additional,
  0 AS bids_resolved_smartly_bidding_probe_original,
  0 AS bids_resolved_smartly_bidding_v2_feedback_additional,
  0 AS bids_resolved_smartly_bidding_v2_feedback_original,
  0 AS bids_resolved_smartly_bidding_v2_probe_additional,
  0 AS bids_resolved_smartly_bidding_v2_probe_original,
  auction_table.bucket_id AS bucket_id,
  auction_table.collection_id AS collection_id,
  auction_table.dsp_id AS dsp_id,
  auction_table.dsp_name AS dsp_name,
  auction_table.is_smart_bidding_traffic AS is_smart_bidding_traffic,
  auction_table.market_integration_type AS market_integration_type,
  auction_table.event_date_hour
FROM auction_table
UNION ALL
SELECT
  candidate_table.timestamp AS __time,
  0 AS ack_ad_impression,
  0 AS ack_ad_impression_smartly_bidding_baseline,
  0 AS ack_ad_impression_smartly_bidding_feedback_additional,
  0 AS ack_ad_impression_smartly_bidding_feedback_original,
  0 AS ack_ad_impression_smartly_bidding_probe_additional,
  0 AS ack_ad_impression_smartly_bidding_probe_original,
  0 AS ack_ad_impression_smartly_bidding_v2_feedback_additional,
  0 AS ack_ad_impression_smartly_bidding_v2_feedback_original,
  0 AS ack_ad_impression_smartly_bidding_v2_probe_additional,
  0 AS ack_ad_impression_smartly_bidding_v2_probe_original,
  0 AS ack_ad_revenue,
  0 AS ack_ad_revenue_smartly_bidding_baseline,
  0 AS ack_ad_revenue_smartly_bidding_feedback_additional,
  0 AS ack_ad_revenue_smartly_bidding_feedback_original,
  0 AS ack_ad_revenue_smartly_bidding_probe_additional,
  0 AS ack_ad_revenue_smartly_bidding_probe_original,
  0 AS ack_ad_revenue_smartly_bidding_v2_feedback_additional,
  0 AS ack_ad_revenue_smartly_bidding_v2_feedback_original,
  0 AS ack_ad_revenue_smartly_bidding_v2_probe_additional,
  0 AS ack_ad_revenue_smartly_bidding_v2_probe_original,
  candidate_table.auction_network_id AS auction_network_id,
  candidate_table.auction_network_name AS auction_network_name,
  0 AS auction_request_sent,
  0 AS auction_request_smartly_bidding_baseline,
  0 AS auction_request_smartly_bidding_feedback_additional,
  0 AS auction_request_smartly_bidding_feedback_original,
  0 AS auction_request_smartly_bidding_probe_additional,
  0 AS auction_request_smartly_bidding_probe_original,
  0 AS auction_request_smartly_bidding_v2_feedback_additional,
  0 AS auction_request_smartly_bidding_v2_feedback_original,
  0 AS auction_request_smartly_bidding_v2_probe_additional,
  0 AS auction_request_smartly_bidding_v2_probe_original,
  candidate_table.auction_upstream_network_id AS auction_upstream_network_id,
  candidate_table.auction_upstream_network_name AS auction_upstream_network_name,
  candidate_table.bids_resolved AS bids_resolved,
  candidate_table.bids_resolved_smartly_bidding_baseline AS bids_resolved_smartly_bidding_baseline,
  candidate_table.bids_resolved_smartly_bidding_feedback_additional AS bids_resolved_smartly_bidding_feedback_additional,
  candidate_table.bids_resolved_smartly_bidding_feedback_original AS bids_resolved_smartly_bidding_feedback_original,
  candidate_table.bids_resolved_smartly_bidding_probe_additional AS bids_resolved_smartly_bidding_probe_additional,
  candidate_table.bids_resolved_smartly_bidding_probe_original AS bids_resolved_smartly_bidding_probe_original,
  candidate_table.bids_resolved_smartly_bidding_v2_feedback_additional AS bids_resolved_smartly_bidding_v2_feedback_additional,
  candidate_table.bids_resolved_smartly_bidding_v2_feedback_original AS bids_resolved_smartly_bidding_v2_feedback_original,
  candidate_table.bids_resolved_smartly_bidding_v2_probe_additional AS bids_resolved_smartly_bidding_v2_probe_additional,
  candidate_table.bids_resolved_smartly_bidding_v2_probe_original AS bids_resolved_smartly_bidding_v2_probe_original,
  candidate_table.bucket_id AS bucket_id,
  candidate_table.collection_id AS collection_id,
  candidate_table.dsp_id AS dsp_id,
  candidate_table.dsp_name AS dsp_name,
  candidate_table.is_smart_bidding_traffic AS is_smart_bidding_traffic,
  candidate_table.market_integration_type AS market_integration_type,
  candidate_table.event_date_hour
FROM candidate_table
UNION ALL
SELECT
  revenue_table.timestamp AS __time,
  revenue_table.ack_ad_impression AS ack_ad_impression,
  revenue_table.ack_ad_impression_smartly_bidding_baseline AS ack_ad_impression_smartly_bidding_baseline,
  revenue_table.ack_ad_impression_smartly_bidding_feedback_additional AS ack_ad_impression_smartly_bidding_feedback_additional,
  revenue_table.ack_ad_impression_smartly_bidding_feedback_original AS ack_ad_impression_smartly_bidding_feedback_original,
  revenue_table.ack_ad_impression_smartly_bidding_probe_additional AS ack_ad_impression_smartly_bidding_probe_additional,
  revenue_table.ack_ad_impression_smartly_bidding_probe_original AS ack_ad_impression_smartly_bidding_probe_original,
  revenue_table.ack_ad_impression_smartly_bidding_v2_feedback_additional AS ack_ad_impression_smartly_bidding_v2_feedback_additional,
  revenue_table.ack_ad_impression_smartly_bidding_v2_feedback_original AS ack_ad_impression_smartly_bidding_v2_feedback_original,
  revenue_table.ack_ad_impression_smartly_bidding_v2_probe_additional AS ack_ad_impression_smartly_bidding_v2_probe_additional,
  revenue_table.ack_ad_impression_smartly_bidding_v2_probe_original AS ack_ad_impression_smartly_bidding_v2_probe_original,
  revenue_table.ack_ad_revenue AS ack_ad_revenue,
  revenue_table.ack_ad_revenue_smartly_bidding_baseline AS ack_ad_revenue_smartly_bidding_baseline,
  revenue_table.ack_ad_revenue_smartly_bidding_feedback_additional AS ack_ad_revenue_smartly_bidding_feedback_additional,
  revenue_table.ack_ad_revenue_smartly_bidding_feedback_original AS ack_ad_revenue_smartly_bidding_feedback_original,
  revenue_table.ack_ad_revenue_smartly_bidding_probe_additional AS ack_ad_revenue_smartly_bidding_probe_additional,
  revenue_table.ack_ad_revenue_smartly_bidding_probe_original AS ack_ad_revenue_smartly_bidding_probe_original,
  revenue_table.ack_ad_revenue_smartly_bidding_v2_feedback_additional AS ack_ad_revenue_smartly_bidding_v2_feedback_additional,
  revenue_table.ack_ad_revenue_smartly_bidding_v2_feedback_original AS ack_ad_revenue_smartly_bidding_v2_feedback_original,
  revenue_table.ack_ad_revenue_smartly_bidding_v2_probe_additional AS ack_ad_revenue_smartly_bidding_v2_probe_additional,
  revenue_table.ack_ad_revenue_smartly_bidding_v2_probe_original AS ack_ad_revenue_smartly_bidding_v2_probe_original,
  revenue_table.auction_network_id AS auction_network_id,
  revenue_table.auction_network_name AS auction_network_name,
  0 AS auction_request_sent,
  0 AS auction_request_smartly_bidding_baseline,
  0 AS auction_request_smartly_bidding_feedback_additional,
  0 AS auction_request_smartly_bidding_feedback_original,
  0 AS auction_request_smartly_bidding_probe_additional,
  0 AS auction_request_smartly_bidding_probe_original,
  0 AS auction_request_smartly_bidding_v2_feedback_additional,
  0 AS auction_request_smartly_bidding_v2_feedback_original,
  0 AS auction_request_smartly_bidding_v2_probe_additional,
  0 AS auction_request_smartly_bidding_v2_probe_original,
  revenue_table.auction_upstream_network_id AS auction_upstream_network_id,
  revenue_table.auction_upstream_network_name AS auction_upstream_network_name,
  0 AS bids_resolved,
  0 AS bids_resolved_smartly_bidding_baseline,
  0 AS bids_resolved_smartly_bidding_feedback_additional,
  0 AS bids_resolved_smartly_bidding_feedback_original,
  0 AS bids_resolved_smartly_bidding_probe_additional,
  0 AS bids_resolved_smartly_bidding_probe_original,
  0 AS bids_resolved_smartly_bidding_v2_feedback_additional,
  0 AS bids_resolved_smartly_bidding_v2_feedback_original,
  0 AS bids_resolved_smartly_bidding_v2_probe_additional,
  0 AS bids_resolved_smartly_bidding_v2_probe_original,
  revenue_table.bucket_id AS bucket_id,
  revenue_table.collection_id AS collection_id,
  revenue_table.dsp_id AS dsp_id,
  revenue_table.dsp_name AS dsp_name,
  revenue_table.is_smart_bidding_traffic AS is_smart_bidding_traffic,
  revenue_table.market_integration_type AS market_integration_type,
  revenue_table.event_date_hour
FROM revenue_table
