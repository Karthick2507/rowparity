-- account:    sa-dmo-aqs
-- skeleton:   143a4ecaf7646beb244a67f0dea04e64
-- pattern:    758ff1db0a33ff07ce32a3195192a70c  (173 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id <= ?
--   request__timestamp > DATE_ADD(?, -?, DATE_PARSE(?, ?))

WITH temp_table AS (
  SELECT
    network_id,
    slot_type_id,
    guarantee_mode,
    ARRAY[APPROX_PERCENTILE(score, counting, 0.1, 0.0001)] || APPROX_PERCENTILE(score, counting, 0.2, 0.0001) || APPROX_PERCENTILE(score, counting, 0.3, 0.0001) || APPROX_PERCENTILE(score, counting, 0.4, 0.0001) || APPROX_PERCENTILE(score, counting, 0.5, 0.0001) || APPROX_PERCENTILE(score, counting, 0.6, 0.0001) || APPROX_PERCENTILE(score, counting, 0.7, 0.0001) || APPROX_PERCENTILE(score, counting, 0.8, 0.0001) || APPROX_PERCENTILE(score, counting, 0.9, 0.0001) || APPROX_PERCENTILE(score, counting, 1.0, 0.0001) AS percentiles
  FROM (
    SELECT
      t.n_id AS network_id,
      BITWISE_AND(t.flag, 255) AS slot_type_id,
      CASE BITWISE_AND(t.flag / 256, 3)
        WHEN 1
        THEN 'preemptible'
        WHEN 2
        THEN 'guaranteed'
        ELSE ''
      END AS guarantee_mode,
      t.score AS score,
      COUNT(1) AS counting
    FROM ${bcv_request}
    CROSS JOIN UNNEST(request__scores__network_id, request__scores__flag, request__scores__score) AS t(n_id, flag, score)
    WHERE
      (
        BITWISE_AND(request__flags, 64) = 0
        OR (
          BITWISE_AND(request__flags, 64) = 64 AND visitor__filtration_reason = 1001
        )
      )
    GROUP BY
      1,
      2,
      3,
      4
  )
  GROUP BY
    1,
    2,
    3
)
SELECT
  network_id,
  slot_type_id,
  guarantee_mode,
  percentile * 10 AS percentile,
  score
FROM temp_table
CROSS JOIN UNNEST(percentiles) WITH ORDINALITY AS groups(score, percentile)
