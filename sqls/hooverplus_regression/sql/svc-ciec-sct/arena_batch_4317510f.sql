-- account:    svc-ciec-sct
-- skeleton:   2582a96e5a44af9ac126830f07e4a0cc
-- pattern:    4317510f2a482a8baa191f65f2a2be04  (348 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   a.process_batch_id < DATE_FORMAT(CAST(? AS TIMESTAMP), ?)
--   a.process_batch_id >= DATE_FORMAT(DATE_ADD(?, -?, CAST(? AS TIMESTAMP)), ?)

SELECT
  *,
  process_batch_id AS _arena_partition_process_batch_id
FROM (
  SELECT
    MIN(process_batch_id) AS process_batch_id,
    app_bundle_id AS app_bundle,
    SUBSTR(ARRAY_JOIN(ARRAY_AGG(app_id), '||', ''), 1, 32000) AS app_id_list,
    app_name AS app_name,
    SUM(request_num) AS request_num,
    SUBSTR(ARRAY_JOIN(ARRAY_AGG(app_store_url), '||', ''), 1, 32000) AS store_url_list,
    ARRAY_JOIN(SET_AGG(ssp_id), ',', '') AS ssp_id_list,
    traffic_type AS traffic_type
  FROM (
    SELECT
      MIN(process_batch_id) AS process_batch_id,
      LOWER(TRIM(request__bidding_context__bid_request__app__bundle)) AS app_bundle_id,
      request__bidding_context__bid_request__app__id AS app_id,
      request__bidding_context__bid_request__app__name AS app_name,
      request__bidding_context__bid_request__app__storeurl AS app_store_url,
      COALESCE(request__context__site_section_cro_network_id, 0) AS ssp_id,
      CASE
        WHEN BITWISE_AND(request__extra_flags2, 8) > 0
        THEN 'ssp_bidder_traffic'
        WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
        THEN 'fw_ssp'
        ELSE ''
      END AS traffic_type,
      COUNT(1) AS request_num
    FROM ${bcv_transaction} AS a
    WHERE
      (
        request__is_first_request = TRUE
        AND NOT request__bidding_context__bid_request__app__bundle IS NULL
      )
      AND request__bidding_context__bid_request__app__bundle <> ''
    GROUP BY
      2,
      3,
      4,
      5,
      6,
      7
    UNION ALL
    SELECT
      MIN(process_batch_id) AS process_batch_id,
      LOWER(TRIM(request__context__app__bundle)) AS app_bundle_id,
      request__context__app__id AS app_id,
      request__context__app__name AS app_name,
      request__context__app__storeurl AS app_store_url,
      COALESCE(request__context__site_section_cro_network_id, 0) AS ssp_id,
      CASE
        WHEN BITWISE_AND(request__extra_flags2, 8) > 0
        THEN 'ssp_bidder_traffic'
        WHEN BITWISE_AND(request__extra_flags2, 65536) > 0
        THEN 'fw_ssp'
        ELSE ''
      END AS traffic_type,
      COUNT(1) AS request_num
    FROM ${bcv_transaction} AS a
    WHERE
      (
        request__is_first_request = TRUE AND NOT request__context__app__bundle IS NULL
      )
      AND request__context__app__bundle <> ''
    GROUP BY
      2,
      3,
      4,
      5,
      6,
      7
  )
  WHERE
    traffic_type <> ''
  GROUP BY
    app_bundle_id,
    app_name,
    traffic_type
) AS arena_tmp
