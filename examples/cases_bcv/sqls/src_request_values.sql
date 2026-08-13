-- Case B (value parity), SRC side.
--
-- SELECT * on purpose. SRC has ~1697 columns and BCV ~837; rowparity compares
-- the INTERSECTION and reports the rest as columns_only_in_expected, so the
-- comparison lands on exactly the MATCHED set without naming 800 columns here
-- and having to re-edit this file every time the BCV layout gains one.
--
-- The IN (...) subquery pins this side to transactions that exist in BCV too.
-- Without it, a transaction BCV has not ingested yet shows up as a value
-- failure, which is a pipeline timing artefact rather than a migration defect.
-- Case A is what reports those honestly; this case deliberately excludes them
-- so that anything it flags is a genuine value difference.
SELECT *
FROM ${src_catalog}.${src_schema}.request
WHERE process_batch_id = '${batch_id}'
  AND abs(from_big_endian_64(xxhash64(to_utf8(request__transaction_id)))) % ${sample_modulus} = 0
  AND request__transaction_id IN (
        SELECT request__transaction_id
        FROM ${bcv_catalog}.${bcv_schema}.request
        WHERE batch_id = '${batch_id}'
          AND abs(from_big_endian_64(xxhash64(to_utf8(request__transaction_id))))
              % ${sample_modulus} = 0
      )
