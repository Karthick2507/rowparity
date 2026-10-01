-- account:    publisher
-- skeleton:   76d9b22ab62063a5e54f332b819b5afe
-- pattern:    f73b9b6606243ed43a509c7633656297  (3 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < DATE_ADD(?, ?, CAST(? AS TIMESTAMP))
--   ack__timestamp >= DATE_ADD(?, -?, CAST(? AS TIMESTAMP))

SELECT
  nw.id AS networkid,
  nw.name AS networkname,
  COUNT(DISTINCT candidate__cch_key) AS numberofadstortranscodedcreativeswithimps
FROM ${bcv_ack}
JOIN db.default.d_network AS nw
  ON nw.id = auction__network_id
WHERE
  (
    (
      (
        (
          BITWISE_AND(advertisement__inventory_protection_flags, 32) > 0
          AND BITWISE_AND(COALESCE(request__flags, 0), 64) = 0
        )
        AND COALESCE(ack__metrics__raw_ad_impression, 0) <> 0
      )
      AND ack__timestamp >= NETWORKLOCAL_TO_UTC(CAST('2026-07-01' AS TIMESTAMP), nw.id)
    )
    AND ack__timestamp < NETWORKLOCAL_TO_UTC(CAST('2026-08-01' AS TIMESTAMP), nw.id)
  )
  AND nw.id IN (
    SELECT DISTINCT
      network.id
    FROM db.default.d_network AS network
    JOIN db.default.d_network_function AS nf
      ON network.id = nf.network_id
    JOIN db.default.d_lu_network_function AS lu_nf
      ON nf.function_id = lu_nf.id
    WHERE
      lu_nf.name IN ('markets_management', 'price_awareness_3rd_party_ads')
      AND STRPOS(LOWER(network.name), 'test') = 0
  )
GROUP BY
  1,
  2
