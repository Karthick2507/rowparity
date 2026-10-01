-- account:    sa-presto-tier2
-- skeleton:   0c4dea6b0116b84ca4751bf5f661d694
-- pattern:    822bd02852584c0563a3d10bb81b45cc  (2 execution(s))
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
  COUNT(*) AS total_impressions,
  COUNT_IF(p_site_section_id IS NULL OR p_site_section_id = -1) AS null_or_minus1_site_section,
  COUNT_IF(NOT p_site_section_id IS NULL AND p_site_section_id <> -1) AS valid_site_section,
  ROUND(
    100.0 * COUNT_IF(p_site_section_id IS NULL OR p_site_section_id = -1) / COUNT(*),
    2
  ) AS pct_missing
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners__network_id, partners__site_section_id, partners__role) AS p(p_network_id, p_site_section_id, p_role)
WHERE
  (
    (
      p_network_id = 535279 AND p_role IN ('cro', 'r')
    )
    AND ack__ack_entity_type = 'ad'
  )
  AND ack__traffic_type = 0
