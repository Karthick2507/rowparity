-- account:    sa-presto-tier2
-- skeleton:   931261daae04c2a890acc25fe7a91c62
-- pattern:    a1736f485d471856d7f4fd7c7d484341  (1 execution(s))
-- in suite:   column coverage
-- hoover:     request
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  CASE request__context__site_section_id
    WHEN 1819063
    THEN 'comcast: ip stb vod: spotlight local'
    WHEN 1819064
    THEN 'comcast: ip stb vod: programmer national'
    WHEN 1819065
    THEN 'comcast: ip stb vod: title vi'
    WHEN 674942
    THEN 'charter: stb vod (group)'
    WHEN 1779684
    THEN 'cox: watermark_c2_section_live'
    WHEN 1779685
    THEN 'cox: legacy_section_live'
  END AS upstream_section_name,
  request__context__site_section_id AS upstream_section_id,
  request__context__stream_mode_ids AS stream_mode_ids,
  CASE
    WHEN request__context__stream_mode_ids = ARRAY[CAST('2' AS BIGINT)]
    THEN 'on-demand [2] ✓ correct'
    WHEN request__context__stream_mode_ids = ARRAY[CAST('1' AS BIGINT), CAST('3' AS BIGINT)]
    THEN 'live+dai [1,3] ✗ wrong'
    WHEN request__context__stream_mode_ids = ARRAY[CAST('1' AS BIGINT), CAST('6' AS BIGINT)]
    THEN 'live+highconcurrency [1,6]'
    ELSE 'other'
  END AS stream_type_label,
  COUNT(*) AS request_count,
  ROUND(
    100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY request__context__site_section_id),
    2
  ) AS pct_of_section
FROM ${bcv_request}
WHERE
  request__context__site_section_id IN (1819063, 1819064, 1819065, 674942, 1779684, 1779685)
GROUP BY
  1,
  2,
  3,
  4
ORDER BY
  upstream_section_id,
  request_count DESC
