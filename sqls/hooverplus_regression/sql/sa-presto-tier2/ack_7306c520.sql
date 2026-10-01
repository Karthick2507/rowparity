-- account:    sa-presto-tier2
-- skeleton:   3f625086aa5351374f3e347763694541
-- pattern:    7306c52032e563d6d548236abd91fc60  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id = ?

SELECT
  COUNT(*) AS total_ack_rows,
  SUM(ack__metrics__raw_ad_impression) AS total_raw_impressions,
  SUM(IF(ack__traffic_type = 0, ack__metrics__raw_ad_impression, 0)) AS net_impressions,
  COUNT(DISTINCT visitor__user_id) AS distinct_users
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__audience_partner_segment_infos__audience_partner_id) AS p(a_partner_id)
WHERE
  (
    ack__ack_entity_type = 'ad'
    AND CARDINALITY(FILTER(partners__audience_partner_segment_infos__max_cpm, x -> NOT x IS NULL)) > 0
  )
  AND CONTAINS(p.a_partner_id, 536344)
