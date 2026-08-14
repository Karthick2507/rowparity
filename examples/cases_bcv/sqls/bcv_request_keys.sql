-- Case A (completeness), BCV side: the same deterministic sample.
--
-- The batch column name is a PARAMETER per side, not a literal. SRC and BCV
-- need not agree on it, and a wrong guess costs a whole run: set
-- bcv_batch_column / src_batch_column rather than editing this file.
SELECT request__transaction_id
FROM ${bcv_catalog}.${bcv_schema}.request
WHERE ${bcv_batch_column} = '${batch_id}'
  AND abs(from_big_endian_64(xxhash64(to_utf8(request__transaction_id)))) % ${sample_modulus} = 0
