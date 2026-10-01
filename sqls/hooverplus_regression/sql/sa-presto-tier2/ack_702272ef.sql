-- account:    sa-presto-tier2
-- skeleton:   61644d98514f8dff34e610712283fcad
-- pattern:    702272ef268304104f8753cf2bf22d80  (1 execution(s))
-- in suite:   column coverage
-- hoover:     ack
-- kind:       READ
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id < ?
--   process_batch_id >= ?

SELECT
  DATE_FORMAT(AT_TIMEZONE(MIN(ack__timestamp), 'america/new_york'), '%y-%m-%d') AS earliest_available,
  DATE_FORMAT(AT_TIMEZONE(MAX(ack__timestamp), 'america/new_york'), '%y-%m-%d') AS latest_available
FROM ${bcv_ack}
WHERE
  request__context__network_id = 10613
