-- account:    sa-dmo-aqs
-- skeleton:   acaea0ef9b55033d80e5b556d9ca201e
-- pattern:    9a659f0ddcba02d50338b24c0d00459a  (173 execution(s))
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
  t.deal_id AS deal_id,
  t.buyer_id AS buyer_id,
  COUNT(1) AS score
FROM ${bcv_request}
CROSS JOIN UNNEST(request__guaranteed_deal_avail__internal_deal_id, request__guaranteed_deal_avail__buyer_id) AS t(deal_id, buyer_id)
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
