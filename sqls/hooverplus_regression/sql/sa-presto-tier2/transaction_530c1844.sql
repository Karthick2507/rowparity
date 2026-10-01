-- account:    sa-presto-tier2
-- skeleton:   b8b0ca8c1ab459904c9600f722cd64f8
-- pattern:    530c18449c8aa4400e80970ab59433ca  (1 execution(s))
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
  vcid_val,
  fw_vcid2_val,
  CASE
    WHEN fw_vcid2_val = CONCAT('174057:', vcid_val)
    THEN 'match (174057: prefix)'
    WHEN fw_vcid2_val = vcid_val
    THEN 'exact match (no prefix)'
    WHEN vcid_val IS NULL
    THEN 'vcid missing'
    WHEN fw_vcid2_val IS NULL
    THEN 'fw_vcid2 missing'
    ELSE 'mismatch'
  END AS match_status,
  COUNT(*) AS request_count
FROM (
  SELECT
    request__transaction_id,
    MAX(CASE WHEN LOWER(kv_key) = 'vcid' THEN kv_val END) AS vcid_val,
    MAX(CASE WHEN LOWER(kv_key) = '_fw_vcid2' THEN kv_val END) AS fw_vcid2_val
  FROM ${bcv_transaction}
  CROSS JOIN UNNEST(request__context__key_value__key, request__context__key_value__value) AS t(kv_key, kv_val)
  WHERE
    (
      request__context__video_cro_network_id = 174057
      AND request__is_first_request = TRUE
    )
    AND LOWER(kv_key) IN ('vcid', '_fw_vcid2')
  GROUP BY
    request__transaction_id
) AS sub
GROUP BY
  1,
  2,
  3
