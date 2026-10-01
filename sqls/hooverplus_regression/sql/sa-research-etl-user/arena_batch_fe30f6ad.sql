-- account:    sa-research-etl-user
-- skeleton:   9c3f5d76e642a0d922f7591f27fae7ee
-- pattern:    fe30f6ad8c1945b6b4e9b97ba1e138ac  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad, transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.

WITH date_range AS (
  SELECT
    CAST('2026-07-21 15:00:00' AS TIMESTAMP) AS start_date,
    CAST('2026-07-28 15:00:00' AS TIMESTAMP) AS end_date
), listing AS (
  SELECT
    request__context__video_cro_network_id AS cro_nw_id,
    ARRAY_AGG(DISTINCT listing_table.network_id) AS listing_network_ids
  FROM ${bcv_transaction}
  CROSS JOIN UNNEST(request__slots__outbound_order__listing_id, request__slots__outbound_order__flags) AS t(outbound_order__listing_id, outbound_order__flags)
  CROSS JOIN UNNEST(t.outbound_order__listing_id, t.outbound_order__flags) AS k(listing_ids, flag)
  CROSS JOIN UNNEST(k.listing_ids) AS l(listing_id)
  LEFT JOIN oltp.fwmrm_oltp.mkpl_listing AS listing_table
    ON l.listing_id = listing_table.id
  WHERE
    (
      request__timestamp BETWEEN (
        SELECT
          start_date
        FROM date_range
      ) AND (
        SELECT
          end_date
        FROM date_range
      )
      AND (
        BITWISE_AND(k.flag, 1) > 0
        OR BITWISE_AND(k.flag, 2) > 0
        OR BITWISE_AND(k.flag, 4) > 0
      )
    )
    AND BITWISE_AND(request__audience_flags, 256) = 0
  GROUP BY
    1
), ad AS (
  SELECT
    request__context__video_cro_network_id AS cro_nw_id,
    ARRAY_AGG(DISTINCT ad_network_id) AS ad_network_ids
  FROM ${bcv_transaction}
  CROSS JOIN UNNEST(request__advertisements__network_id, request__advertisements__extra_flags2, request__advertisements__extra_flags) AS t(ad_network_id, extra_flags2, extra_flags)
  WHERE
    (
      request__timestamp BETWEEN (
        SELECT
          start_date
        FROM date_range
      ) AND (
        SELECT
          end_date
        FROM date_range
      )
      AND (
        BITWISE_AND(t.extra_flags2, 2097152) > 0
        OR BITWISE_AND(t.extra_flags2, 4194304) > 0
        OR BITWISE_AND(t.extra_flags2, 8388608) > 0
        OR BITWISE_AND(t.extra_flags, 2097152) > 0
        OR BITWISE_AND(t.extra_flags2, 16) > 0
      )
    )
    AND BITWISE_AND(request__audience_flags, 256) = 0
  GROUP BY
    1
)
SELECT
  nw.id,
  ARRAY_JOIN(
    ARRAY_DISTINCT(
      CONCAT(
        COALESCE(ad.ad_network_ids, ARRAY[]),
        COALESCE(listing.listing_network_ids, ARRAY[])
      )
    ),
    '|'
  ) AS all_network_list
FROM oltp.fwmrm_oltp.network AS nw
LEFT JOIN ${bcv_ad}
  ON nw.id = ad.cro_nw_id
LEFT JOIN listing
  ON ad.cro_nw_id = listing.cro_nw_id
WHERE
  LOWER(nw.name) NOT LIKE '%test%'
  AND NOT nw.id IN (505644, 174057, 511845, 535339, 510626, 520311, 386345, 545332)
ORDER BY
  all_network_list DESC
