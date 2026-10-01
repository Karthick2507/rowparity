-- account:    sa-presto-tier2
-- skeleton:   abad94bbb3f863470d7d9de08dcc029d
-- pattern:    a4ce51289632524f2a2d64e2616a2922  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

WITH base AS (
  SELECT
    visitor__user_id,
    request__transaction_id,
    request__context__network_id AS network_id,
    advertisement__placement_id AS placement_id,
    partners__audience_partner_segment_infos__audience_partner_id AS aud_partner_ids,
    partners__audience_partner_segment_infos__max_cpm AS aud_max_cpm,
    FLATTEN(FLATTEN(partners__audience_partner_segment_infos__matched_segments__id)) AS matched_seg_ids,
    COALESCE(ack__metrics__raw_ad_impression, 0) AS raw_imp,
    IF(ack__traffic_type = 0, COALESCE(ack__metrics__raw_ad_impression, 0), 0) AS net_imp,
    COALESCE(ack__metrics__video_view, 0) AS video_view,
    COALESCE(ack__metrics__first_quartile, 0) AS q1,
    COALESCE(ack__metrics__middle_quartile, 0) AS q2,
    COALESCE(ack__metrics__third_quartile, 0) AS q3,
    COALESCE(ack__metrics__complete_quartile, 0) AS q4,
    partners__revenue AS rev_arr,
    partners__role AS role_arr,
    COALESCE(ack__metrics__fire_event_revenue_ratio, 0) AS rev_ratio,
    CARDINALITY(FILTER(partners__audience_partner_segment_infos__max_cpm, x -> NOT x IS NULL)) > 0 AS is_audience_targeted,
    ack__traffic_type
  FROM ${bcv_ack}
  WHERE
    (
      (
        (
          ack__ack_entity_type = 'ad' AND request__is_filtered = FALSE
        )
        AND advertisement__is_bumper = FALSE
      )
      AND ack__is_private_impression = FALSE
    )
    AND CARDINALITY(FILTER(partners__audience_partner_segment_infos__max_cpm, x -> NOT x IS NULL)) > 0
), seg_flat AS (
  SELECT
    visitor__user_id,
    network_id,
    placement_id,
    seg_id,
    SUM(raw_imp) AS raw_imp,
    SUM(net_imp) AS net_imp,
    SUM(video_view) AS video_views,
    SUM(q1) AS q1_cnt,
    SUM(q2) AS q2_cnt,
    SUM(q3) AS q3_cnt,
    SUM(q4) AS completions,
    COUNT(DISTINCT request__transaction_id) AS ad_requests
  FROM base
  CROSS JOIN UNNEST(matched_seg_ids) AS t(seg_id)
  WHERE
    NOT visitor__user_id IS NULL AND visitor__user_id <> ''
  GROUP BY
    1,
    2,
    3,
    4
), seg_named AS (
  SELECT
    sf.visitor__user_id,
    sf.network_id,
    sf.placement_id,
    sf.seg_id,
    COALESCE(ds.custom_id, CAST(sf.seg_id AS VARCHAR)) AS segment_custom_id,
    COALESCE(ds.name, 'unknown') AS segment_name,
    sf.ad_requests,
    sf.raw_imp,
    sf.net_imp,
    sf.video_views,
    sf.q1_cnt,
    sf.q2_cnt,
    sf.q3_cnt,
    sf.completions
  FROM seg_flat AS sf
  LEFT JOIN etl.ds_billing.d_ds_segment AS ds
    ON ds.id_pk = sf.seg_id
)
SELECT
  visitor__user_id AS user_id,
  network_id,
  placement_id,
  seg_id AS matched_segment_id,
  segment_custom_id,
  segment_name,
  ad_requests,
  raw_imp AS gross_impressions,
  net_imp AS net_counted_impressions,
  video_views,
  q1_cnt AS first_quartile,
  q2_cnt AS midpoint,
  q3_cnt AS third_quartile,
  completions AS video_completions,
  ROUND(CAST(completions AS DOUBLE) / NULLIF(video_views, 0) * 100.0, 2) AS completion_rate_pct
FROM seg_named
