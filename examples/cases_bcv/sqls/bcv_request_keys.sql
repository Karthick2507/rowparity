-- Case A (completeness), BCV side: the same deterministic sample.
--
-- Note the column name differs from SRC: the BCV layout partitions on
-- `batch_id` where SRC uses `process_batch_id`. Same value, different column.
SELECT request__transaction_id
FROM ${bcv_catalog}.${bcv_schema}.request
WHERE batch_id = '${batch_id}'
  AND abs(from_big_endian_64(xxhash64(to_utf8(request__transaction_id)))) % ${sample_modulus} = 0
