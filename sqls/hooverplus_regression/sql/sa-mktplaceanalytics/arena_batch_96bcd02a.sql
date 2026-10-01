-- account:    sa-mktplaceanalytics
-- skeleton:   cd53acd1bfc931497deece0bae141f7d
-- pattern:    96bcd02a9a0422a7c4629102c0ccc1bd  (343 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   t.request__timestamp < CAST(? AS TIMESTAMP)
--   t.request__timestamp >= CAST(? AS TIMESTAMP)

WITH base AS (
  SELECT
    DATE(t.request__timestamp) AS event_date,
    t.request__visitor__country_id AS country_id,
    t.request__context__video_cro_network_id AS network_id,
    t.request__context__content_form_id AS content_form_id,
    CASE
      WHEN CARDINALITY(t.request__visitor__standard_device_type_ids) = 0
      THEN -1
      ELSE t.request__visitor__standard_device_type_ids[1]
    END AS standard_device_type_id,
    CASE
      WHEN CARDINALITY(t.request__context__stream_mode_ids) = 0
      THEN -1
      ELSE t.request__context__stream_mode_ids[1]
    END AS stream_mode_id,
    CASE
      WHEN CONTAINS(TRANSFORM(t.request__slots__time_position_class, x -> LOWER(x)), 'preroll')
      THEN 'preroll'
      WHEN CONTAINS(TRANSFORM(t.request__slots__time_position_class, x -> LOWER(x)), 'midroll')
      AND NOT CONTAINS(TRANSFORM(t.request__slots__time_position_class, x -> LOWER(x)), 'pause_midroll')
      THEN 'midroll'
      WHEN CONTAINS(TRANSFORM(t.request__slots__time_position_class, x -> LOWER(x)), 'postroll')
      THEN 'postroll'
      ELSE 'other'
    END AS ad_unit_position,
    t.request__transaction_id,
    t.request__context__asset_id AS asset_id,
    t.request__context__asset_duration AS asset_duration_sec,
    t.request__advertisement_count,
    t.request__advertisements__creative_id
  FROM ${bcv_transaction} AS t
  WHERE
    (
      (
        (
          (
            t.request__extra_flags2 IS NULL
            OR BITWISE_AND(65536, t.request__extra_flags2) = 0
          )
          AND NOT t.request__transaction_id IS NULL
        )
        AND NOT t.request__context__asset_duration IS NULL
      )
      AND t.request__context__asset_duration <> 0
    )
    AND (
      CONTAINS(TRANSFORM(t.request__slots__time_position_class, x -> LOWER(x)), 'preroll')
      OR (
        CONTAINS(TRANSFORM(t.request__slots__time_position_class, x -> LOWER(x)), 'midroll')
        AND NOT CONTAINS(TRANSFORM(t.request__slots__time_position_class, x -> LOWER(x)), 'pause_midroll')
      )
      OR CONTAINS(TRANSFORM(t.request__slots__time_position_class, x -> LOWER(x)), 'postroll')
    )
), ad_duration AS (
  SELECT
    b.request__transaction_id,
    SUM(c.duration) AS ad_duration_sec
  FROM (
    SELECT
      *
    FROM base
    WHERE
      CARDINALITY(request__advertisements__creative_id) > 0
  ) AS b
  CROSS JOIN UNNEST(FILTER(b.request__advertisements__creative_id, x -> NOT x IS NULL)) AS creative(id)
  INNER JOIN oltp.fwmrm_oltp.creative AS c
    ON creative.id = c.id
  WHERE
    NOT c.duration IS NULL AND c.duration > 0
  GROUP BY
    1
), final_agg AS (
  SELECT
    b.event_date,
    YEAR(b.event_date) AS year,
    QUARTER(b.event_date) AS quarter,
    MONTH(b.event_date) AS month,
    b.country_id,
    b.network_id,
    b.content_form_id,
    b.standard_device_type_id,
    b.stream_mode_id,
    b.ad_unit_position,
    COUNT(DISTINCT b.request__transaction_id) AS txn_cnt,
    COUNT(DISTINCT b.asset_id) AS distinct_video_count,
    SUM(b.asset_duration_sec) AS total_video_duration_sec,
    SUM(COALESCE(a.ad_duration_sec, 0)) AS total_ad_duration_sec,
    SUM(COALESCE(b.request__advertisement_count, 0)) AS total_ad_count
  FROM base AS b
  LEFT JOIN ad_duration AS a
    ON b.request__transaction_id = a.request__transaction_id
  GROUP BY
    event_date,
    country_id,
    network_id,
    content_form_id,
    standard_device_type_id,
    stream_mode_id,
    ad_unit_position
), final_with_dims AS (
  SELECT
    f.*,
    c.name AS country_code,
    c.description AS country_name,
    nwk.name AS network_name,
    cf.name AS content_form_name,
    dt.parent_name AS standard_device_type,
    sm.parent_name AS standard_stream_type
  FROM final_agg AS f
  LEFT JOIN db.default.d_country AS c
    ON f.country_id = c.id
  LEFT JOIN db.default.d_network AS nwk
    ON f.network_id = nwk.id
  LEFT JOIN db.default.d_lu_mkpl_standard_content_form AS cf
    ON f.content_form_id = cf.id
  LEFT JOIN db.default.d_lu_mkpl_standard_sub_device_type AS dt
    ON f.standard_device_type_id = dt.id
  LEFT JOIN db.default.d_lu_mkpl_sub_stream_mode AS sm
    ON f.stream_mode_id = sm.id
)
SELECT
  *
FROM final_with_dims
