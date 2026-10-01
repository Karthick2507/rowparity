-- account:    sa-presto-tier2
-- skeleton:   8403abbeec7b0a846f211440c27bfb21
-- pattern:    0945e094dd87e3a480abcbff8c4efe28  (1 execution(s))
-- in suite:   column coverage
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  has_vcid,
  has_fw_vcid2,
  COUNT(*) AS request_count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM (
  SELECT
    request__transaction_id,
    MAX(CASE WHEN LOWER(kv_key) = 'vcid' THEN 1 ELSE 0 END) AS has_vcid,
    MAX(CASE WHEN LOWER(kv_key) = '_fw_vcid2' THEN 1 ELSE 0 END) AS has_fw_vcid2
  FROM ${bcv_transaction}
  CROSS JOIN UNNEST(request__context__key_value__key) AS t(kv_key)
  WHERE
    request__context__video_cro_network_id = 174057
    AND request__is_first_request = TRUE
  GROUP BY
    request__transaction_id
) AS sub
GROUP BY
  1,
  2
ORDER BY
  request_count DESC
