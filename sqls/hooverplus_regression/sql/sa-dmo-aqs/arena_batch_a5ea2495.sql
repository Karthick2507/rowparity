-- account:    sa-dmo-aqs
-- skeleton:   3eac6faeb26ca301c5c5f972813db0e2
-- pattern:    a5ea24955165c757a69f13f81659e9b0  (173 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id <= ?
--   request__timestamp > DATE_ADD(?, -?, DATE_PARSE(?, ?))

SELECT
  request__context__network_id AS network_id,
  candidate,
  COUNT(1) AS avails
FROM ${bcv_request}
CROSS JOIN UNNEST(request__candidates) AS t(candidate)
WHERE
  (
    BITWISE_AND(request__flags, 64) = 0
    OR (
      BITWISE_AND(request__flags, 64) = 64 AND visitor__filtration_reason = 1001
    )
  )
GROUP BY
  1,
  2
