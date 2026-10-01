-- account:    sa-dmo-aqs
-- skeleton:   18ef3727a86c8a1745348ac89827b27e
-- pattern:    7300931d962391c97bcffedefe75e7d6  (175 execution(s))
-- in suite:   daily commitment
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id <= ?
--   process_batch_id > ?

SELECT
  DATE(ack__timestamp) AS event_date,
  COALESCE(request__context__network_id, -1) AS network_id,
  COALESCE(request__context__profile_id, -1) AS profile_id,
  COALESCE(ack__ad_id, -1) AS ad_id,
  COALESCE(ack__creative_rendition_id, -1) AS creative_rendition_id,
  COALESCE(REGEXP_EXTRACT(ack__event_key_renderer, '^[a-za-z]+$'), '') AS renderer,
  SUBSTR(COALESCE(IF(ack__event_type = 'i', '_e_really-no-ad', ack__event_name), ''), 1, 64) AS event_name,
  COUNT(1) AS event_count
FROM ${bcv_ack}
WHERE
  (
    ack__event_type = 'e'
    OR (
      ack__event_type = 'i'
      AND ack__event_name = 'resellernoad'
      AND BITWISE_AND(advertisement__flags, 512) = 0
    )
  )
  AND NOT COALESCE(REGEXP_EXTRACT(ack__event_key_renderer, '^[a-za-z]+$'), '') IN ('fwcrashreporter', 'custom')
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7
