-- Case A (completeness), SRC side: the sampled transaction keys only.
--
-- Key column alone, so this stays cheap even over a whole batch. The sample is
-- DETERMINISTIC -- a pure function of the join key -- so the BCV side selects
-- exactly the same transactions without any coordination between the two
-- queries. That is what makes independent sampling correct here; TABLESAMPLE
-- would pick a different set on each side and every row would look missing.
--
-- Set sample_modulus=1 to compare the whole batch.
SELECT request__transaction_id
FROM ${src_catalog}.${src_schema}.request
WHERE ${src_batch_column} = '${batch_id}'
  AND abs(from_big_endian_64(xxhash64(to_utf8(request__transaction_id)))) % ${sample_modulus} = 0
