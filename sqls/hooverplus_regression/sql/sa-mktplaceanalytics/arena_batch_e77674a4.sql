-- account:    sa-mktplaceanalytics
-- skeleton:   c80740057b31d0dc197c37e0259e10c1
-- pattern:    e77674a4d73409e44ad43c51ed5db402  (36 execution(s))
-- in suite:   column coverage
-- hoover:     auction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   DATE(DATE_TRUNC(?, AT_TIMEZONE(request__timestamp, ?))) = DATE_ADD(?, -?, DATE_TRUNC(?, AT_TIMEZONE(CAST(? AS TIMESTAMP), ?)))

SELECT
  *,
  event_date AS _arena_partition_event_date
FROM (
  WITH client_types AS (
    SELECT
      network_id,
      ARRAY_SORT(ARRAY_DISTINCT(ARRAY_AGG(nl.name))) AS nwlabel
    FROM oltp.fwmrm_oltp.network_label_assignment AS nla
    INNER JOIN oltp.fwmrm_oltp.network_label AS nl
      ON nla.label_id = nl.id
      AND nl.name IN ('fw ssp', 'curation hub', 'streaming hub', 'freewheel managed')
    GROUP BY
      1
  ), temp AS (
    SELECT
      DATE(DATE_TRUNC('DAY', AT_TIMEZONE(request__timestamp, 'america/new_york'))) AS event_date,
      request__context__network_id,
      auction__dsp_id,
      auction__network_id,
      auction__supply_chain__nodes__asi,
      auction__supply_chain__nodes__sid,
      auction__supply_chain__ver,
      auction__supply_chain__complete,
      COUNT(*) AS reqs
    FROM ${bcv_auction}
    GROUP BY
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8
  )
  SELECT
    a.event_date,
    a.request__context__network_id AS network_id,
    nw.name AS network_name,
    ct.nwlabel AS client_type,
    a.auction__dsp_id,
    a.auction__network_id,
    CARDINALITY(a.auction__supply_chain__nodes__asi) AS node_count,
    a.auction__supply_chain__nodes__asi AS asi,
    a.auction__supply_chain__nodes__sid AS sid,
    ELEMENT_AT(FILTER(a.auction__supply_chain__nodes__sid, x -> NOT x IS NULL), -1) AS fw_sid,
    CAST(CASE
      WHEN NOT ELEMENT_AT(FILTER(a.auction__supply_chain__nodes__sid, x -> NOT x IS NULL), -1) IS NULL
      AND sjpi.type IS NULL
      THEN 'sid not found in sellers.json'
      ELSE sjpi.type
    END AS VARCHAR) AS seller_type,
    a.auction__supply_chain__ver AS ver,
    SUM(CASE WHEN a.auction__supply_chain__complete = TRUE THEN reqs ELSE 0 END) AS reqs_schain_complete,
    SUM(CASE WHEN a.auction__supply_chain__complete = TRUE THEN reqs ELSE 0 END) * 100.0 / SUM(reqs) AS pct_schain_complete,
    SUM(CASE WHEN a.auction__supply_chain__complete = FALSE THEN reqs ELSE 0 END) AS reqs_schain_incomplete,
    SUM(CASE WHEN a.auction__supply_chain__complete = FALSE THEN reqs ELSE 0 END) * 100.0 / SUM(reqs) AS pct_schain_incomplete,
    SUM(CASE WHEN a.auction__supply_chain__complete IS NULL THEN reqs ELSE 0 END) AS reqs_schain_null,
    SUM(CASE WHEN a.auction__supply_chain__complete IS NULL THEN reqs ELSE 0 END) * 100.0 / SUM(reqs) AS pct_schain_null,
    SUM(reqs) AS reqs
  FROM temp AS a
  INNER JOIN oltp.fwmrm_oltp.network AS nw
    ON a.request__context__network_id = nw.id
  LEFT JOIN client_types AS ct
    ON a.request__context__network_id = ct.network_id
  LEFT JOIN oltp.fwmrm_oltp.sellers_json_publisher_info AS sjpi
    ON ELEMENT_AT(FILTER(a.auction__supply_chain__nodes__sid, x -> NOT x IS NULL), -1) = sjpi.seller_id
  WHERE
    nw.network_type = 'full'
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
  ORDER BY
    network_id DESC,
    reqs DESC
) AS arena_tmp
