-- Resolves the batch_id parameter automatically: the newest batch that exists
-- on BOTH sides, excluding the most recent ones which may still be landing.
--
-- Do NOT write the placeholder form of that name anywhere in this file, not
-- even in a comment. Substitution is plain text and has no idea what a SQL
-- comment is, so mentioning it here would make this query demand the very
-- value it exists to produce.
--
-- Picking the newest SRC batch would be wrong twice over: BCV may not have
-- ingested it yet (every transaction would read as missing), and it may still
-- be being written (the comparison would shift underneath itself).
--
-- INTERSECT gives the batches both sides agree exist. skip_recent_batches
-- then drops that many from the top, so the chosen batch is settled rather
-- than merely present. Raise it if the pipeline runs behind.
--
-- If this is slow, the tables are Hive-backed and these are partition
-- columns: swap each side for the metadata-only partitions table, e.g.
--   SELECT process_batch_id FROM ${src_catalog}.${src_schema}."request$partitions"
-- which answers from the catalog without scanning any data.
SELECT b
FROM (
    SELECT b, row_number() OVER (ORDER BY b DESC) AS rn
    FROM (
        SELECT DISTINCT ${src_batch_column} AS b
        FROM ${src_catalog}.${src_schema}.request
        INTERSECT
        SELECT DISTINCT ${bcv_batch_column} AS b
        FROM ${bcv_catalog}.${bcv_schema}.request
    )
)
WHERE rn = ${skip_recent_batches} + 1
