-- account:    sa-presto-tier2
-- skeleton:   9ff75f38592ab7a8ec83a6ff3be4bcda
-- pattern:    436be3f5ea570ab7eccdf26ea99724c6  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  visitor__user_id AS user_id,
  request__context__network_id AS network_id,
  COUNT(DISTINCT request__transaction_id) AS ad_requests,
  SUM(COALESCE(ack__metrics__raw_ad_impression, 0)) AS gross_impressions,
  SUM(IF(ack__traffic_type = 0, COALESCE(ack__metrics__raw_ad_impression, 0), 0)) AS net_counted_impressions,
  SUM(COALESCE(ack__metrics__video_view, 0)) AS video_views,
  SUM(COALESCE(ack__metrics__first_quartile, 0)) AS first_quartile,
  SUM(COALESCE(ack__metrics__middle_quartile, 0)) AS midpoint,
  SUM(COALESCE(ack__metrics__third_quartile, 0)) AS third_quartile,
  SUM(COALESCE(ack__metrics__complete_quartile, 0)) AS completions,
  ARRAY_AGG(
    DISTINCT FLATTEN(FLATTEN(partners__audience_partner_segment_infos__matched_segments__id))
  ) AS matched_segment_id_arrays
FROM ${bcv_ack}
WHERE
  (
    (
      (
        (
          (
            ack__ack_entity_type = 'ad' AND request__is_filtered = FALSE
          )
          AND advertisement__is_bumper = FALSE
        )
        AND ack__is_private_impression = FALSE
      )
      AND NOT visitor__user_id IS NULL
    )
    AND visitor__user_id <> ''
  )
  AND CARDINALITY(FILTER(partners__audience_partner_segment_infos__max_cpm, x -> NOT x IS NULL)) > 0
GROUP BY
  1,
  2
