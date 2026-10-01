-- account:    sa-presto-tier2
-- skeleton:   9907c12661f82561e6c05f29ee1fb732
-- pattern:    578a7f12d86c8cd74d249e0c5f916f1c  (1 execution(s))
-- in suite:   column coverage
-- hoover:     slot
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  slot__index,
  slot__max_duration,
  slot__max_ads,
  slot__num_ads,
  slot__time_position_class,
  COUNT(*) AS cnt
FROM ${bcv_slot}
WHERE
  request__context__network_id = 534985
  AND request__transaction_id IN ('1786366797286817643', '1786366791922590858', '1786366780391652627')
GROUP BY
  1,
  2,
  3,
  4,
  5
