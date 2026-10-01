-- account:    sa-presto-tier2
-- skeleton:   8de89e2abd32313392f12a2136077fe0
-- pattern:    6c1fc96ab587664c30b0a6e98f0d403c  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.

SELECT
  COUNT(*) AS total_rows,
  COUNT(CASE WHEN partners.series_id IS NULL THEN 1 END) AS null_series_id,
  COUNT(CASE WHEN request__context__standard_content_series_id IS NULL THEN 1 END) AS null_std_series_id,
  COUNT(CASE WHEN request__context__standard_channel_id IS NULL THEN 1 END) AS null_std_channel_id,
  COUNT(CASE WHEN partners.asset_id IS NULL THEN 1 END) AS null_asset_id,
  COUNT(CASE WHEN request__context__standard_programmer_id IS NULL THEN 1 END) AS null_std_programmer_id
FROM ${bcv_ack}
CROSS JOIN UNNEST(partners) AS t(partners)
WHERE
  request__event_date >= DATE_ADD('DAY', -7, CAST('${as_of_date}' AS DATE))
  AND ack_entity_type = 'ad'
