-- account:    ychan375
-- skeleton:   639488593acdb17eb9c2f4761f2482ac
-- pattern:    858082efe4b4096c4850f6c8cbbb98ff  (2 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT DISTINCT
  DATE(request__timestamp) AS event_day,
  visitor__peer_address,
  ack__traffic_type,
  CASE
    WHEN ack__traffic_type = 1
    THEN visitor__filtration_reason
    WHEN ack__traffic_type = 2
    THEN request__backend_filtration_reason
  END AS filtration_reason,
  SUM(ack__metrics__raw_ad_impression) AS ad_impression
FROM ${bcv_ack}
WHERE
  (
    NOT ack__traffic_type IS NULL
  )
GROUP BY
  1,
  2,
  3,
  4
ORDER BY
  1 ASC
