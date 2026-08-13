-- Case B (value parity), BCV side: the mirror image of src_request_values.sql.
--
-- Both sides resolve to the same set:
--     { k : hash(k) % modulus = 0  AND  k in SRC  AND  k in BCV }
-- so neither lag nor a partially-ingested batch can produce a spurious diff.
SELECT *
FROM ${bcv_catalog}.${bcv_schema}.request
WHERE batch_id = '${batch_id}'
  AND abs(from_big_endian_64(xxhash64(to_utf8(request__transaction_id)))) % ${sample_modulus} = 0
  AND request__transaction_id IN (
        SELECT request__transaction_id
        FROM ${src_catalog}.${src_schema}.request
        WHERE process_batch_id = '${batch_id}'
          AND abs(from_big_endian_64(xxhash64(to_utf8(request__transaction_id))))
              % ${sample_modulus} = 0
      )
