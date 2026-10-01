-- account:    svc-ciec-sct
-- skeleton:   786d68570f0ca97df8db0ea64fbf5fbd
-- pattern:    7dd39944f24d129af871f20c57334033  (694 execution(s))
-- in suite:   daily commitment
-- hoover:     ack, ad, candidate
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack.request__timestamp < CAST(? AS TIMESTAMP)
--   ack.request__timestamp >= CAST(DATE_FORMAT(CAST(? AS TIMESTAMP) - INTERVAL ? HOUR, ?) AS TIMESTAMP)
--   ad.request__timestamp < CAST(? AS TIMESTAMP)
--   ad.request__timestamp >= CAST(DATE_FORMAT(CAST(? AS TIMESTAMP) - INTERVAL ? HOUR, ?) AS TIMESTAMP)
--   batch_date = (SELECT MAX(batch_date) FROM glue.buyside_auction_db.pg_dsp_seat_id_consent)
--   batch_date = (SELECT MAX(batch_date) FROM glue.buyside_auction_db.pg_report_publisher_network_consent)
--   c.request__timestamp < CAST(? AS TIMESTAMP)
--   c.request__timestamp >= CAST(DATE_FORMAT(CAST(? AS TIMESTAMP) - INTERVAL ? HOUR, ?) AS TIMESTAMP)

WITH candidate_filtered AS (
  SELECT
    c.request__identifier__source,
    c.request__transaction_id,
    c.request__server_id,
    c.request__timestamp,
    c.auction__network_id,
    c.candidate__dsp_id,
    dsdsp.name,
    c.candidate__external_seat_id,
    c.candidate__dsp_currency_id,
    c.candidate__candidate_network_to_auction_network_exchange_rate,
    c.candidate__original_price,
    c.candidate__clearing_price,
    c.candidate__external_ad_id,
    c.candidate__advertisement_index,
    c.auction__time_position_class,
    c.candidate__bid_status,
    c.candidate__error,
    candidate__internal_deal_id,
    c.candidate__dsp_cid,
    c.auction__bid_request_id,
    c.request__traffic_type,
    c.auction__width,
    c.auction__height
  FROM ${bcv_candidate} AS c
  JOIN (
    SELECT
      dsp_name,
      seat_id,
      batch_date
    FROM glue.buyside_auction_db.pg_dsp_seat_id_consent
  ) AS sid
    ON candidate__external_seat_id = CAST(sid.seat_id AS VARCHAR)
  JOIN db.default.d_ssp_demand_side_platform AS dsdsp
    ON sid.dsp_name = dsdsp.name AND c.candidate__dsp_id = dsdsp.id
  WHERE
    c.auction__network_id IN (
      SELECT
        publisher_network_id
      FROM glue.buyside_auction_db.pg_report_publisher_network_consent
    )
), dimension_join AS (
  SELECT
    c.request__identifier__source,
    c.candidate__advertisement_index,
    c.request__transaction_id,
    c.request__server_id,
    c.request__timestamp,
    c.auction__network_id,
    dn.name AS network_name,
    c.candidate__dsp_id,
    c.name AS dsp_name,
    c.candidate__external_seat_id,
    dsdm.external_id AS deal_id,
    dlc.code AS currency_code,
    c.candidate__candidate_network_to_auction_network_exchange_rate,
    c.candidate__original_price,
    c.candidate__clearing_price,
    dmc.brand_name,
    c.auction__time_position_class,
    c.candidate__error,
    CASE
      WHEN c.candidate__error IS NULL
      THEN NULL
      WHEN NOT lsbe.display_name IS NULL
      THEN CAST(lsbe.iab_error_code AS VARCHAR)
      ELSE 'other reason'
    END AS error_code,
    c.candidate__bid_status,
    c.candidate__dsp_cid,
    c.auction__bid_request_id,
    c.request__traffic_type,
    c.auction__width,
    c.auction__height
  FROM candidate_filtered AS c
  LEFT JOIN (
    SELECT DISTINCT
      market_external_ad_id,
      brand_name
    FROM db.default.d_market_creative
    WHERE
      network_id = 0
  ) AS dmc
    ON c.candidate__external_ad_id = dmc.market_external_ad_id
  JOIN db.default.d_network AS dn
    ON c.auction__network_id = dn.id
  JOIN db.default.d_lu_currency AS dlc
    ON c.candidate__dsp_currency_id = dlc.id
  LEFT JOIN db.default.d_ssp_deal_metadata AS dsdm
    ON c.candidate__internal_deal_id = dsdm.id
  LEFT JOIN oltp.fwmrm_oltp.lu_ssp_bidding_error AS lsbe
    ON candidate__error = lsbe.error_code AND lsbe.level = 'candidate'
), ack_table AS (
  SELECT
    candidate__bid_status,
    candidate__advertisement_index,
    request__identifier__source,
    auction__bid_request_id,
    ack__traffic_type,
    request__traffic_type,
    ack__event_name
  FROM ${bcv_ack}
  JOIN (
    SELECT
      dsp_name,
      seat_id,
      batch_date
    FROM glue.buyside_auction_db.pg_dsp_seat_id_consent
  ) AS sid
    ON candidate__external_seat_id = CAST(sid.seat_id AS VARCHAR)
  JOIN db.default.d_ssp_demand_side_platform AS dsdsp
    ON sid.dsp_name = dsdsp.name AND ack.candidate__dsp_id = dsdsp.id
  WHERE
    ack.auction__network_id IN (
      SELECT
        publisher_network_id
      FROM glue.buyside_auction_db.pg_report_publisher_network_consent
    )
), ack_join AS (
  SELECT
    request__timestamp AS eventtime,
    dj.candidate__bid_status,
    ack.ack__traffic_type,
    ack.ack__event_name,
    dj.request__identifier__source,
    dj.candidate__advertisement_index,
    CASE
      WHEN dj.candidate__bid_status = 15 AND ack.ack__event_name = 'defaultimpression'
      THEN 'defaultimpression'
      WHEN dj.candidate__bid_status = 15
      THEN 'selectedbid'
      ELSE 'notselectedbid'
    END AS eventname,
    dj.auction__network_id AS networkid,
    dj.network_name AS networkname,
    dj.candidate__dsp_id AS dspid,
    dj.dsp_name AS dspname,
    dj.candidate__external_seat_id AS buyerseatid,
    dj.deal_id AS buyerdealid,
    dj.currency_code AS currency,
    dj.candidate__candidate_network_to_auction_network_exchange_rate AS conversionrate,
    dj.candidate__original_price AS bidprice,
    CASE
      WHEN dj.candidate__bid_status IN (7, 15)
      THEN dj.candidate__clearing_price
      ELSE NULL
    END AS clearingprice,
    ad.partners__audience_segment_max_cpm[ARRAY_POSITION(ad.partners__network_id, dj.auction__network_id)] AS datacost,
    CASE
      WHEN dj.candidate__bid_status IN (1, 3, 7) AND dj.error_code IS NULL
      THEN '1'
      ELSE dj.error_code
    END AS iablossreasoncode,
    dj.brand_name AS brandname,
    dj.auction__time_position_class AS timepositionclass,
    dj.candidate__dsp_cid AS dspcampaignid,
    dj.auction__bid_request_id AS auctionid,
    dj.request__traffic_type,
    dj.auction__width AS resolutionwidth,
    dj.auction__height AS resolutionheight
  FROM dimension_join AS dj
  LEFT JOIN (
    SELECT
      request__transaction_id,
      request__server_id,
      auction__network_id,
      candidate__external_seat_id,
      candidate__bid_status,
      candidate__dsp_id,
      partners__network_id,
      partners__audience_segment_max_cpm,
      candidate__original_price,
      candidate__clearing_price,
      candidate__advertisement_index,
      request__identifier__source,
      auction__bid_request_id
    FROM ${bcv_ad}
    JOIN (
      SELECT
        dsp_name,
        seat_id,
        batch_date
      FROM glue.buyside_auction_db.pg_dsp_seat_id_consent
    ) AS sid
      ON candidate__external_seat_id = CAST(sid.seat_id AS VARCHAR)
    JOIN db.default.d_ssp_demand_side_platform AS dsdsp
      ON sid.dsp_name = dsdsp.name AND ad.candidate__dsp_id = dsdsp.id
    WHERE
      ad.auction__network_id IN (
        SELECT
          publisher_network_id
        FROM glue.buyside_auction_db.pg_report_publisher_network_consent
        WHERE
          batch_date = (
            SELECT
              MAX(batch_date)
            FROM glue.buyside_auction_db.pg_report_publisher_network_consent
          )
      )
      AND candidate__bid_status = 15
  ) AS ad
    ON dj.candidate__bid_status = ad.candidate__bid_status
    AND dj.request__identifier__source = ad.request__identifier__source
    AND dj.candidate__advertisement_index = ad.candidate__advertisement_index
    AND dj.auction__bid_request_id = ad.auction__bid_request_id
  LEFT JOIN (
    SELECT
      *
    FROM ack_table
    WHERE
      candidate__bid_status = 15 AND ack__event_name = 'defaultimpression'
  ) AS ack
    ON dj.candidate__bid_status = ack.candidate__bid_status
    AND dj.request__identifier__source = ack.request__identifier__source
    AND dj.candidate__advertisement_index = ack.candidate__advertisement_index
    AND dj.auction__bid_request_id = ack.auction__bid_request_id
), traffic_query AS (
  SELECT
    ack_join.*,
    CASE
      WHEN ack_join.ack__event_name = 'defaultimpression'
      THEN ack_join.ack__traffic_type
      ELSE ack_table.ack__traffic_type
    END AS traffic_type_ivt
  FROM ack_join
  LEFT JOIN ack_table
    ON ack_join.ack__event_name IS NULL
    AND ack_join.candidate__bid_status = ack_table.candidate__bid_status
    AND ack_join.request__identifier__source = ack_table.request__identifier__source
    AND ack_join.candidate__advertisement_index = ack_table.candidate__advertisement_index
    AND ack_join.auctionid = ack_table.auction__bid_request_id
)
SELECT
  eventtime,
  eventname,
  CASE
    WHEN COALESCE(traffic_type_ivt, request__traffic_type, NULL) = 0
    THEN 'pass'
    ELSE 'fail'
  END AS givtdecisionresult,
  networkid,
  networkname,
  dspid,
  dspname,
  buyerseatid,
  buyerdealid,
  currency,
  conversionrate,
  bidprice,
  clearingprice,
  datacost,
  iablossreasoncode,
  brandname,
  timepositionclass,
  dspcampaignid,
  auctionid,
  resolutionwidth,
  resolutionheight
FROM traffic_query
