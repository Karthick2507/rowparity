-- account:    sa-presto-tier2
-- skeleton:   34681b62d8b98c784f48c054709b9c73
-- pattern:    264f5bd272d08b4d782221d956c7f78e  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__context__site_section_id AS request_level_site_section_id,
  COUNT(*) AS impression_count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__network_id, partners__site_section_id, partners__role) AS p(p_network_id, p_site_section_id, p_role)
WHERE
  (
    (
      (
        p_network_id = 535279 AND p_role IN ('cro', 'r')
      )
      AND ack__ack_entity_type = 'ad'
    )
    AND ack__traffic_type = 0
  )
  AND (
    p_site_section_id IS NULL OR p_site_section_id = -1
  )
GROUP BY
  1
