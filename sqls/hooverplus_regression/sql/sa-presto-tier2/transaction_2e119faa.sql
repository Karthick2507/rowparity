-- account:    sa-presto-tier2
-- skeleton:   e09754b8493bb5f91837f79d723cf724
-- pattern:    2e119faaa52be2a9843c6f4783c97d93  (1 execution(s))
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
  SPLIT_PART(kv_val, ':', 1) AS prefix,
  COUNT(*) AS request_count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM ${bcv_transaction}
CROSS JOIN UNNEST(request__context__key_value__key, request__context__key_value__value) AS t(kv_key, kv_val)
WHERE
  (
    (
      (
        request__context__video_cro_network_id = 174057
        AND request__is_first_request = TRUE
      )
      AND LOWER(kv_key) = '_fw_vcid2'
    )
    AND NOT kv_val IS NULL
  )
  AND kv_val <> ''
GROUP BY
  1
