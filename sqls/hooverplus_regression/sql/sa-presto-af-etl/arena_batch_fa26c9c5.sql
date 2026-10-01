-- account:    sa-presto-af-etl
-- skeleton:   55d49472dd9ed952003d657b2554b0b8
-- pattern:    fa26c9c5ba780a92d4b90259e8f04b19  (1 execution(s))
-- in suite:   column coverage
-- hoover:     auction, candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   TO_UNIXTIME(request__timestamp) % ? = ?
--   process_batch_id < ?
--   process_batch_id >= ?

WITH auction_all AS (
  SELECT
    request__transaction_id,
    request__server_id,
    auction__index,
    auction__integration_type,
    auction__network_id,
    auction__time_position_class,
    auction__internal_seat_id,
    auction__impression__index,
    FLATTEN(auction__impression__deals__impression_index) AS deals__impression_index,
    FLATTEN(auction__impression__deals__internal_deal_id) AS deals__internal_deal_id,
    FLATTEN(auction__impression__deals__buyers__internal_seat_id) AS deals__internal_seat_id,
    auction__auction_sampling__magnifier AS auction_sampling__magnifier
  FROM ${bcv_auction}
  WHERE
    (
      request__extra_flags2 IS NULL OR BITWISE_AND(65536, request__extra_flags2) = 0
    )
    AND auction__integration_type <> 'pg_td'
), auction_in_tid AS (
  SELECT
    request__transaction_id,
    request__server_id,
    ARRAY_AGG(auction__index) AS request__rtb_auction__index,
    ARRAY_AGG(auction__integration_type) AS request__rtb_auction__integration_type,
    ARRAY_AGG(auction__network_id) AS request__rtb_auction__network_id,
    ARRAY_AGG(auction__time_position_class) AS request__rtb_auction__time_position_class,
    ARRAY_AGG(auction__internal_seat_id) AS request__rtb_auction__internal_seat_id,
    ARRAY_AGG(auction__impression__index) AS request__rtb_auction__impression__index,
    ARRAY_AGG(deals__impression_index) AS request__rtb_auction__deal__impression_index,
    ARRAY_AGG(deals__internal_deal_id) AS request__rtb_auction__deal__internal_deal_id,
    ARRAY_AGG(deals__internal_seat_id) AS request__rtb_auction__deal__internal_seat_id,
    ARRAY_AGG(auction_sampling__magnifier) AS request__rtb_auction__auction_sampling__magnifier
  FROM auction_all
  GROUP BY
    1,
    2
), candidate_all AS (
  SELECT
    request__transaction_id,
    request__server_id,
    candidate__rtb_auction_index,
    candidate__integration_type,
    candidate__rtb_impression_index,
    candidate__internal_seat_id,
    candidate__internal_deal_id,
    candidate__buyer_group_id,
    candidate__ad_id,
    candidate__pod_replica_id,
    candidate__external_ad_id,
    candidate__original_price,
    candidate__dsp_currency_id,
    candidate__duration,
    candidate__profile_check_passed,
    candidate__two_phase_translated,
    candidate__response_industry,
    candidate__error,
    candidate__network_execution_ctx_index,
    ZIP_WITH(
      partners__inbound_order_id,
      partners__network_execution_ctx_index,
      (x, y) -> IF(y = candidate__network_execution_ctx_index, x, NULL)
    ) AS mkpl_partner_tag_order_ids
  FROM ${bcv_candidate}
  WHERE
    (
      request__extra_flags2 IS NULL OR BITWISE_AND(65536, request__extra_flags2) = 0
    )
    AND candidate__integration_type <> 'openrtb_pg_td'
), candidate_in_tid AS (
  SELECT
    request__transaction_id,
    request__server_id,
    ARRAY_AGG(candidate__rtb_auction_index) AS request__external_candidate_ad__rtb_auction_index,
    ARRAY_AGG(candidate__internal_seat_id) AS request__external_candidate_ad__internal_seat_id,
    ARRAY_AGG(candidate__internal_deal_id) AS request__external_candidate_ad__internal_deal_id,
    ARRAY_AGG(candidate__buyer_group_id) AS request__external_candidate_ad__buyer_group_id,
    ARRAY_AGG(candidate__rtb_impression_index) AS request__external_candidate_ad__rtb_impression_index,
    ARRAY_AGG(candidate__ad_id) AS request__external_candidate_ad__ad_id,
    ARRAY_AGG(candidate__pod_replica_id) AS request__external_candidate_ad__pod_replica_id,
    ARRAY_AGG(candidate__external_ad_id) AS request__external_candidate_ad__external_ad_id,
    ARRAY_AGG(candidate__original_price) AS request__external_candidate_ad__original_price,
    ARRAY_AGG(candidate__dsp_currency_id) AS request__external_candidate_ad__dsp_currency_id,
    ARRAY_AGG(candidate__duration) AS request__external_candidate_ad__duration,
    ARRAY_AGG(candidate__profile_check_passed) AS request__external_candidate_ad__profile_check_passed,
    ARRAY_AGG(candidate__two_phase_translated) AS request__external_candidate_ad__two_phase_translated,
    ARRAY_AGG(candidate__response_industry) AS request__external_candidate_ad__response_industry,
    ARRAY_AGG(candidate__error) AS request__external_candidate_ad__error,
    ARRAY_AGG(candidate__network_execution_ctx_index) AS request__external_candidate_ad__network_execution_ctx_index,
    ARRAY_AGG(
      IF(CARDINALITY(mkpl_partner_tag_order_ids) > 0, mkpl_partner_tag_order_ids[1], NULL)
    ) AS request__network_execution_ctx__inbound_order_id
  FROM candidate_all
  GROUP BY
    1,
    2
)
SELECT
  auction_in_tid.request__transaction_id,
  auction_in_tid.request__server_id,
  request__rtb_auction__index,
  request__rtb_auction__integration_type,
  request__rtb_auction__network_id,
  request__rtb_auction__time_position_class,
  request__rtb_auction__internal_seat_id,
  request__rtb_auction__impression__index,
  request__rtb_auction__deal__impression_index,
  request__rtb_auction__deal__internal_deal_id,
  request__rtb_auction__deal__internal_seat_id,
  request__rtb_auction__auction_sampling__magnifier,
  COALESCE(request__external_candidate_ad__rtb_auction_index, CAST(ARRAY[] AS ARRAY(INTEGER))) AS request__external_candidate_ad__rtb_auction_index,
  COALESCE(request__external_candidate_ad__internal_seat_id, CAST(ARRAY[] AS ARRAY(BIGINT))) AS request__external_candidate_ad__internal_seat_id,
  COALESCE(request__external_candidate_ad__internal_deal_id, CAST(ARRAY[] AS ARRAY(BIGINT))) AS request__external_candidate_ad__internal_deal_id,
  COALESCE(request__external_candidate_ad__buyer_group_id, CAST(ARRAY[] AS ARRAY(BIGINT))) AS request__external_candidate_ad__buyer_group_id,
  COALESCE(
    request__external_candidate_ad__rtb_impression_index,
    CAST(ARRAY[] AS ARRAY(INTEGER))
  ) AS request__external_candidate_ad__rtb_impression_index,
  COALESCE(request__external_candidate_ad__ad_id, CAST(ARRAY[] AS ARRAY(BIGINT))) AS request__external_candidate_ad__ad_id,
  COALESCE(request__external_candidate_ad__pod_replica_id, CAST(ARRAY[] AS ARRAY(INTEGER))) AS request__external_candidate_ad__pod_replica_id,
  COALESCE(request__external_candidate_ad__external_ad_id, CAST(ARRAY[] AS ARRAY(VARCHAR))) AS request__external_candidate_ad__external_ad_id,
  COALESCE(request__external_candidate_ad__original_price, CAST(ARRAY[] AS ARRAY(DOUBLE))) AS request__external_candidate_ad__original_price,
  COALESCE(request__external_candidate_ad__dsp_currency_id, CAST(ARRAY[] AS ARRAY(BIGINT))) AS request__external_candidate_ad__dsp_currency_id,
  COALESCE(request__external_candidate_ad__duration, CAST(ARRAY[] AS ARRAY(INTEGER))) AS request__external_candidate_ad__duration,
  COALESCE(
    request__external_candidate_ad__profile_check_passed,
    CAST(ARRAY[] AS ARRAY(BOOLEAN))
  ) AS request__external_candidate_ad__profile_check_passed,
  COALESCE(
    request__external_candidate_ad__two_phase_translated,
    CAST(ARRAY[] AS ARRAY(BOOLEAN))
  ) AS request__external_candidate_ad__two_phase_translated,
  COALESCE(
    request__external_candidate_ad__response_industry,
    CAST(ARRAY[] AS ARRAY(ARRAY(BIGINT)))
  ) AS request__external_candidate_ad__response_industry,
  COALESCE(request__external_candidate_ad__error, CAST(ARRAY[] AS ARRAY(VARCHAR))) AS request__external_candidate_ad__error,
  COALESCE(
    request__external_candidate_ad__network_execution_ctx_index,
    CAST(ARRAY[] AS ARRAY(INTEGER))
  ) AS request__external_candidate_ad__network_execution_ctx_index,
  COALESCE(request__network_execution_ctx__inbound_order_id, CAST(ARRAY[] AS ARRAY(BIGINT))) AS request__network_execution_ctx__inbound_order_id,
  SUBSTR('20260723', 1, 8) AS process_date
FROM auction_in_tid
LEFT JOIN candidate_in_tid
  ON (
    auction_in_tid.request__transaction_id = candidate_in_tid.request__transaction_id
    AND auction_in_tid.request__server_id = candidate_in_tid.request__server_id
  )
