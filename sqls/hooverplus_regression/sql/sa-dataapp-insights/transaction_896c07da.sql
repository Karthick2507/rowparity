-- account:    sa-dataapp-insights
-- skeleton:   dc789897d36768e185ac3d513882e74c
-- pattern:    896c07dae3575750096c945e4a754ac6  (53 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id <= ?
--   process_batch_id > ?
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  request__context__video_cro_network_id AS network_id,
  request__context__site__domain AS domain,
  MAX(process_batch_id) AS process_batch_id,
  2 AS traffic_source
FROM ${bcv_transaction}
WHERE
  (
    (
      request__is_first_request = TRUE AND NOT request__context__site__domain IS NULL
    )
    AND BITWISE_AND(request__extra_flags2, 8) <= 0
  )
  AND NOT request__context__video_cro_network_id IS NULL
GROUP BY
  1,
  2,
  4
HAVING
  COUNT(1) > 100
ORDER BY
  3,
  2
