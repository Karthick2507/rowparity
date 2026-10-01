-- account:    sa-mktplaceanalytics
-- skeleton:   d9abe92489dcb0cedf931a9236a13f17
-- pattern:    204d199db7a2f81c9b2778867ead968d  (347 execution(s))
-- in suite:   daily commitment
-- hoover:     ack, auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < DATE_ADD(?, -?, DATE_ADD(?, ?, DATE_TRUNC(?, CAST(? AS TIMESTAMP))))
--   ack__timestamp >= DATE_ADD(?, -?, DATE_TRUNC(?, CAST(? AS TIMESTAMP)))
--   request__timestamp < DATE_ADD(?, -?, DATE_ADD(?, ?, DATE_TRUNC(?, CAST(? AS TIMESTAMP))))
--   request__timestamp >= DATE_ADD(?, -?, DATE_TRUNC(?, CAST(? AS TIMESTAMP)))

SELECT
  *,
  event_date AS _arena_partition_event_date
FROM (
  WITH base AS (
    SELECT
      DATE_TRUNC('MINUTE', request__timestamp) AS event_date,
      request__context__video_cro_network_id AS cro_network_id,
      auction__network_id AS network_id,
      request__context__network_id AS distributor_network_id,
      auction__dsp_id AS dsp_id,
      request__context__site_section_cro_site_id AS site_id,
      CASE
        WHEN request__context__request_format IN (5, 6, 7)
        THEN 'ortb'
        WHEN REGEXP_REPLACE(visitor__caller, '^((js|android|iphone|tvos|ias3)-[0-9]).*', 'admanager') = 'admanager'
        THEN 'admanager'
        ELSE 'vast/direct'
      END AS integration_type,
      SUM(
        (
          CASE
            WHEN (
              NOT auction__bid_request_count IS NULL
            )
            THEN auction__bid_request_count
            ELSE auction__auction_sampling__magnifier
          END
        )
      ) AS bid_requests,
      0 AS impressions
    FROM ${bcv_auction}
    WHERE
      auction__integration_type = 'normal'
    GROUP BY
      1,
      2,
      3,
      4,
      5,
      6,
      7
    UNION ALL
    SELECT
      DATE_TRUNC('MINUTE', ack__timestamp) AS event_date,
      request__context__video_cro_network_id AS cro_network_id,
      auction__network_id AS network_id,
      request__context__network_id AS distributor_network_id,
      auction__dsp_id AS dsp_id,
      request__context__site_section_cro_site_id AS site_id,
      CASE
        WHEN request__context__request_format IN (5, 6, 7)
        THEN 'ortb'
        WHEN REGEXP_REPLACE(visitor__caller, '^((js|android|iphone|tvos|ias3)-[0-9]).*', 'admanager') = 'admanager'
        THEN 'admanager'
        ELSE 'vast/direct'
      END AS integration_type,
      0 AS bid_requests,
      SUM(ack__metrics__ad_impression) AS impressions
    FROM ${bcv_ack}
    WHERE
      auction__integration_type = 'normal'
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
    event_date,
    cro_network_id,
    network_id,
    distributor_network_id,
    dsp_id,
    site_id,
    integration_type,
    SUM(bid_requests) AS bid_requests,
    SUM(impressions) AS impressions
  FROM base
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7
  HAVING
    SUM(bid_requests) > 0 OR SUM(impressions) > 0
) AS arena_tmp
