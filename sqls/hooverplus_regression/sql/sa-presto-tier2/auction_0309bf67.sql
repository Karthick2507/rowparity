-- account:    sa-presto-tier2
-- skeleton:   74d86e5b3cec83475d0acaae152b3be9
-- pattern:    0309bf678468f84435bfaff59c61cc7c  (1 execution(s))
-- in suite:   column coverage
-- hoover:     auction
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < CAST(? AS TIMESTAMP)
--   request__timestamp >= CAST(? AS TIMESTAMP)

SELECT
  auction__network_id,
  COUNT_IF(NOT auction__supply_chain IS NULL) AS has_sc,
  COUNT_IF(NOT auction__device_ip IS NULL AND auction__device_ip <> '') AS has_ip,
  COUNT_IF(NOT auction__regs_coppa IS NULL) AS has_coppa,
  COUNT(*) AS n
FROM ${bcv_auction}
WHERE
  NOT auction__dsp_id IS NULL
GROUP BY
  auction__network_id
