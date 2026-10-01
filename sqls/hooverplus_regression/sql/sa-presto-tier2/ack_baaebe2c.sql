-- account:    sa-presto-tier2
-- skeleton:   817f3c1f53d47c52a72914e85a2002c6
-- pattern:    baaebe2cd2706dbf91d5911981196b7a  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   ack__timestamp < CAST(? AS TIMESTAMP)
--   ack__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  DATE_FORMAT(DATE_TRUNC('MONTH', AT_TIMEZONE(ack__timestamp, 'america/new_york')), '%y-%m') AS month,
  COUNT(*) AS row_count,
  SUM(COALESCE(ack__metrics__ad_impression, 0)) AS total_impressions
FROM ${bcv_ack}
WHERE
  (
    (
      (
        (
          request__context__network_id = 10613
          AND request__context__site_section_cro_network_id = 535279
        )
        AND request__is_filtered = FALSE
      )
      AND advertisement__is_bumper = FALSE
    )
    AND ack__is_private_impression = FALSE
  )
  AND COALESCE(ack__metrics__ad_impression, 0) <> 0
GROUP BY
  1
ORDER BY
  1
