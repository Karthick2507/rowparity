-- account:    publisher
-- skeleton:   0c5069beb3faa6776f2ddd8fbc81c8f1
-- pattern:    fa2e5d2d80f56051369de1147fca51b6  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ad
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   a.request__timestamp < DATE_ADD(?, ?, CAST(? AS TIMESTAMP))
--   a.request__timestamp >= DATE_ADD(?, -?, CAST(? AS TIMESTAMP))

SELECT
  DATE_FORMAT(
    UTC_TO_NETWORKLOCAL(a.request__timestamp, advertisement__ad_oo_network_id),
    '%y-%m-%d'
  ) AS "request date",
  a.advertisement__placement_id AS "reseller placement id",
  dp.name AS "reseller placement name",
  COUNT(*) AS "selected ads - primary",
  COUNT_IF(BITWISE_AND(a.advertisement__flags, 32) > 0) AS "selected ads - fallback",
  COUNT_IF(BITWISE_AND(a.advertisement__flags, 67108864) > 0) AS "sstf failed ads"
FROM ${bcv_ad} AS a
LEFT JOIN db.default.d_placement AS dp
  ON dp.id = advertisement__placement_id
WHERE
  (
    (
      (
        advertisement__ad_oo_network_id = 171213 AND candidate__integration_type IS NULL
      )
      AND dp.is_external = 1
    )
    AND a.request__timestamp >= NETWORKLOCAL_TO_UTC(CAST('2026-07-21' AS TIMESTAMP), advertisement__ad_oo_network_id)
  )
  AND a.request__timestamp < NETWORKLOCAL_TO_UTC(CAST('2026-07-24' AS TIMESTAMP), advertisement__ad_oo_network_id)
GROUP BY
  1,
  2,
  3
ORDER BY
  1,
  2,
  3
