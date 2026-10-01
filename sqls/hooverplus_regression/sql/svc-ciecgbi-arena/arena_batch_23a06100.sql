-- account:    svc-ciecgbi-arena
-- skeleton:   0ba57594be5e076d5e2a48fbd7dd259c
-- pattern:    23a061000fb75dd90dd17543f971b033  (19 execution(s))
-- in suite:   daily commitment
-- hoover:     auction, candidate, request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   a.request__timestamp < DATE_TRUNC(?, CURRENT_DATE)
--   a.request__timestamp >= DATE_TRUNC(?, CURRENT_DATE - INTERVAL ? DAY)
--   c.request__timestamp < DATE_TRUNC(?, CURRENT_DATE)
--   c.request__timestamp >= DATE_TRUNC(?, CURRENT_DATE - INTERVAL ? DAY)
--   f.request_event_date < DATE_TRUNC(?, CURRENT_DATE)
--   f.request_event_date >= DATE_TRUNC(?, CURRENT_DATE - INTERVAL ? DAY)
--   r.request__timestamp < DATE_TRUNC(?, CURRENT_DATE)
--   r.request__timestamp >= DATE_TRUNC(?, CURRENT_DATE - INTERVAL ? DAY)

WITH bucket_array AS (
  SELECT
    ARRAY[TRY_CAST(CAST('2021' AS VARCHAR) AS INTEGER), TRY_CAST(CAST('2022' AS VARCHAR) AS INTEGER)] AS buckets,
    TRY_CAST(CAST('2021' AS VARCHAR) AS INTEGER) AS bucket1,
    TRY_CAST(CAST('2022' AS VARCHAR) AS INTEGER) AS bucket2,
    TRY_CAST(CAST('523319' AS VARCHAR) AS BIGINT) AS network_id,
    TRY_CAST(CAST('4' AS VARCHAR) AS BIGINT) AS dsp_id,
    CAST('7' AS VARCHAR) AS custom_i
), base_request AS (
  SELECT
    DATE_TRUNC('DAY', r.request__timestamp) AS time_day,
    CASE
      WHEN CARDINALITY(ARRAY_INTERSECT(r.request__context__ab_test_item__bucket_id, ARRAY[b.bucket1])) > 0
      THEN 'pod bidding'
      WHEN CARDINALITY(ARRAY_INTERSECT(r.request__context__ab_test_item__bucket_id, ARRAY[b.bucket2])) > 0
      THEN 'others'
    END AS bucket_type,
    SUM(COALESCE(r.request__log_sampling__magnifier, 1)) AS ad_request_count
  FROM ${bcv_request} AS r
  CROSS JOIN bucket_array AS b
  WHERE
    CARDINALITY(ARRAY_INTERSECT(r.request__context__ab_test_item__bucket_id, b.buckets)) > 0
    AND (
      (
        r.request__context__network_id = b.network_id
      )
      OR CONTAINS(r.execution_networks__network_id, b.network_id)
    )
  GROUP BY
    1,
    2
), base_auction AS (
  SELECT
    DATE_TRUNC('DAY', a.request__timestamp) AS time_day,
    CASE
      WHEN CARDINALITY(ARRAY_INTERSECT(a.request__context__ab_test_item__bucket_id, ARRAY[b.bucket1])) > 0
      THEN 'pod bidding'
      WHEN CARDINALITY(ARRAY_INTERSECT(a.request__context__ab_test_item__bucket_id, ARRAY[b.bucket2])) > 0
      THEN 'others'
    END AS bucket_type,
    a.auction__dsp_id AS auction_dsp_id,
    a.auction__network_id AS auction_network_id,
    SUM(
      IF(BITWISE_AND(a.auction__auction_status, 2) > 0, 1, 0) * COALESCE(a.request__multiplier, 1) * COALESCE(a.request__magnifier, 1) * COALESCE(a.auction__auction_sampling__magnifier, 1) * COALESCE(a.request__log_sampling__magnifier, 1)
    ) AS total_auction_requests,
    SUM(
      COALESCE(a.auction__impression__equivalent_opportunity_number[1], 0) * COALESCE(a.request__multiplier, 1) * COALESCE(a.request__magnifier, 1) * COALESCE(a.auction__auction_sampling__magnifier, 1) * COALESCE(a.request__log_sampling__magnifier, 1)
    ) AS total_auction_opportunities,
    COUNT_IF(BITWISE_AND(a.auction__auction_status, 8) > 0) AS total_response_with_bids,
    COUNT_IF(a.auction__error = 'timeout') AS timeout_bid_request
  FROM ${bcv_auction} AS a
  CROSS JOIN bucket_array AS b
  WHERE
    (
      (
        (
          CARDINALITY(ARRAY_INTERSECT(a.request__context__ab_test_item__bucket_id, b.buckets)) > 0
          AND a.auction__integration_type = 'normal'
        )
        AND a.auction__network_id = b.network_id
      )
      AND a.auction__dsp_id = b.dsp_id
    )
    AND BITWISE_AND(a.auction__auction_status, 2) > 0
  GROUP BY
    1,
    2,
    3,
    4
), base_candidate_mrm AS (
  SELECT
    DATE_TRUNC('DAY', c.request__timestamp) AS time_day,
    CASE
      WHEN CARDINALITY(ARRAY_INTERSECT(c.request__context__ab_test_item__bucket_id, ARRAY[b.bucket1])) > 0
      THEN 'pod bidding'
      WHEN CARDINALITY(ARRAY_INTERSECT(c.request__context__ab_test_item__bucket_id, ARRAY[b.bucket2])) > 0
      THEN 'others'
    END AS bucket_type,
    COUNT_IF(BITWISE_AND(c.candidate__bid_status, 1) > 0) AS total_bids,
    COUNT_IF(BITWISE_AND(c.candidate__bid_status, 8) > 0) AS total_win_bids,
    ROUND(
      (
        COUNT_IF(BITWISE_AND(c.candidate__bid_status, 8) > 0) * 100.0
      ) / NULLIF(COUNT_IF(BITWISE_AND(c.candidate__bid_status, 1) > 0), 0),
      3
    ) AS win_rate,
    SUM(c.candidate__raw_price) / NULLIF(COUNT_IF(BITWISE_AND(c.candidate__bid_status, 1) > 0), 0) AS all_bids_cpm_bid_price,
    SUM(IF(BITWISE_AND(c.candidate__bid_status, 8) > 0, c.candidate__raw_price, 0)) / NULLIF(COUNT_IF(BITWISE_AND(c.candidate__bid_status, 8) > 0), 0) AS won_bids_cpm_bid_price,
    SUM(IF(BITWISE_AND(c.candidate__bid_status, 8) > 0, c.candidate__clearing_price, 0)) / NULLIF(COUNT_IF(BITWISE_AND(c.candidate__bid_status, 8) > 0), 0) AS won_bids_cpm_clearing_price
  FROM ${bcv_candidate} AS c
  CROSS JOIN bucket_array AS b
  WHERE
    (
      (
        (
          CARDINALITY(ARRAY_INTERSECT(c.request__context__ab_test_item__bucket_id, b.buckets)) > 0
          AND c.auction__integration_type = 'normal'
        )
        AND c.auction__network_id = b.network_id
      )
      AND c.auction__dsp_id = b.dsp_id
    )
    AND BITWISE_AND(c.candidate__bid_status, 1) > 0
  GROUP BY
    1,
    2
), base_candidate_fw AS (
  SELECT
    DATE_TRUNC('DAY', f.request_event_date) AS time_day,
    CASE
      WHEN CARDINALITY(
        ARRAY_INTERSECT(f.candidate__request__context__ab_test_item__bucket_id, ARRAY[b.bucket1])
      ) > 0
      THEN 'pod bidding'
      WHEN CARDINALITY(
        ARRAY_INTERSECT(f.candidate__request__context__ab_test_item__bucket_id, ARRAY[b.bucket2])
      ) > 0
      THEN 'others'
    END AS bucket_type,
    SUM(COALESCE(f.candidate__advertisement__ad_impression, 0)) AS impressions,
    SUM(
      COALESCE(f.candidate__advertisement__ad_impression, 0) * COALESCE(f.candidate__clearing_price, 0)
    ) / 1000.0 AS dsp_revenue,
    COUNT_IF(
      f.candidate__request__is_first_request AND f.candidate__error = 'wrapper_timeout'
    ) AS wrapper_timeout_bid_request,
    ROUND(
      AVG(
        CASE
          WHEN f.candidate__request__is_first_request
          THEN f.candidate__response_time_first_hop
        END
      ),
      3
    ) AS avg_response,
    ROUND(
      APPROX_PERCENTILE(
        CASE
          WHEN f.candidate__request__is_first_request
          THEN f.candidate__response_time_first_hop
        END,
        0.50
      ),
      3
    ) AS p50_response,
    ROUND(
      APPROX_PERCENTILE(
        CASE
          WHEN f.candidate__request__is_first_request
          THEN f.candidate__response_time_first_hop
        END,
        0.70
      ),
      3
    ) AS p70_response,
    ROUND(
      APPROX_PERCENTILE(
        CASE
          WHEN f.candidate__request__is_first_request
          THEN f.candidate__response_time_first_hop
        END,
        0.85
      ),
      3
    ) AS p85_response,
    ROUND(
      APPROX_PERCENTILE(
        CASE
          WHEN f.candidate__request__is_first_request
          THEN f.candidate__response_time_first_hop
        END,
        0.95
      ),
      3
    ) AS p95_response,
    ROUND(
      APPROX_PERCENTILE(
        CASE
          WHEN f.candidate__request__is_first_request
          THEN f.candidate__response_time_first_hop
        END,
        0.99
      ),
      3
    ) AS p99_response
  FROM ${bcv_candidate} AS f
  CROSS JOIN bucket_array AS b
  WHERE
    (
      (
        f.candidate__integration_type = 'openrtb_normal'
        AND f.candidate__rtb_auction__network_id = b.network_id
      )
      AND f.candidate__rtb_auction__dsp_id = b.dsp_id
    )
    AND CARDINALITY(
      ARRAY_INTERSECT(f.candidate__request__context__ab_test_item__bucket_id, b.buckets)
    ) > 0
  GROUP BY
    1,
    2
)
SELECT
  (
    SELECT
      custom_i
    FROM bucket_array
  ) AS "custom_i",
  req.bucket_type AS "bid_type",
  DATE_FORMAT(req.time_day, '%m-%d-%y') AS "date",
  auc.auction_dsp_id AS "dsp_id",
  auc.auction_network_id AS "network_id",
  COALESCE(req.ad_request_count, 0) AS "ad_requests",
  COALESCE(auc.total_auction_requests, 0) AS "auction_requests",
  COALESCE(auc.total_auction_opportunities, 0) AS "auction_opportunities",
  COALESCE(cand_mrm.total_bids, 0) AS "total_bids",
  COALESCE(cand_mrm.total_win_bids, 0) AS "total_win_bids",
  COALESCE(cand_mrm.win_rate, 0) AS "win_rate",
  COALESCE(cand_fw.impressions, 0) AS "impression_count",
  COALESCE(cand_fw.dsp_revenue, 0.0) AS "dsp_revenue",
  CASE
    WHEN COALESCE(auc.total_auction_requests, 0.0) > 0.0
    THEN (
      COALESCE(CAST(cand_mrm.total_bids AS DOUBLE), 0.0) / NULLIF(COALESCE(auc.total_auction_requests, 0.0), 0.0)
    ) * 100
    ELSE 0.0
  END AS bid_rate,
  (
    COALESCE(cand_fw.dsp_revenue, 0.0) / NULLIF(COALESCE(req.ad_request_count, 0.0), 0.0)
  ) * 1000 AS revenue_per_ad_request,
  COALESCE(cand_mrm.all_bids_cpm_bid_price, 0.0) AS "all_bids_cpm_bid_price",
  COALESCE(cand_mrm.won_bids_cpm_bid_price, 0.0) AS "won_bids_cpm_bid_price",
  COALESCE(cand_mrm.won_bids_cpm_clearing_price, 0.0) AS "won_bids_cpm_clearing_price",
  COALESCE(auc.timeout_bid_request, 0) AS "bid_request_timeouts",
  COALESCE(cand_fw.wrapper_timeout_bid_request, 0) AS "timeout_bid_request",
  COALESCE(cand_fw.avg_response, 0.0) AS "avg_response_time",
  COALESCE(cand_fw.p50_response, 0) AS "p50_response_time",
  COALESCE(cand_fw.p70_response, 0) AS "p70_response_time",
  COALESCE(cand_fw.p85_response, 0) AS "p85_response_time",
  COALESCE(cand_fw.p95_response, 0) AS "p95_response_time",
  COALESCE(cand_fw.p99_response, 0) AS "p99_response_time",
  CASE
    WHEN req.bucket_type = 'pod bidding'
    THEN (
      SELECT
        bucket1
      FROM bucket_array
    )
    WHEN req.bucket_type = 'others'
    THEN (
      SELECT
        bucket2
      FROM bucket_array
    )
  END AS "bucket_id"
FROM base_request AS req
LEFT JOIN base_auction AS auc
  ON req.time_day = auc.time_day AND req.bucket_type = auc.bucket_type
LEFT JOIN base_candidate_mrm AS cand_mrm
  ON req.time_day = cand_mrm.time_day AND req.bucket_type = cand_mrm.bucket_type
LEFT JOIN base_candidate_fw AS cand_fw
  ON req.time_day = cand_fw.time_day AND req.bucket_type = cand_fw.bucket_type
