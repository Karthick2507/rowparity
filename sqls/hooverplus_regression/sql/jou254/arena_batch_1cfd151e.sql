-- account:    jou254
-- skeleton:   4d7f7c2ae4ab0ce37899fbf3b573ddc5
-- pattern:    1cfd151e38a5210200f214baff1804aa  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   request__timestamp < DATE(CURRENT_TIMESTAMP)
--   request__timestamp >= DATE(DATE_ADD(?, -?, CURRENT_TIMESTAMP))

SELECT
  DATE_FORMAT(DATE(CAST('${as_of_ts}' AS TIMESTAMP)), '%y-%m-%d') AS data_collection_date,
  request__context__network_id AS network_id,
  ELEMENT_AT(
    request__context__key_value__value,
    ARRAY_POSITION(request__context__key_value__key, '_fw_content_genre')
  ) AS raw_genre,
  request__context__asset_id,
  request__visitor__referrer,
  SUM(1) AS tx_cnt
FROM ${bcv_transaction}
WHERE
  (
    (
      (
        (
          request__is_first_request AND NOT request__transaction_id IS NULL
        )
        AND (
          request__visitor__filtration_reason IS NULL
          OR request__visitor__filtration_reason > 25
        )
      )
      AND BITWISE_AND(request__flags, BITWISE_OR(32, 64)) = 0
    )
    AND CONTAINS(request__context__key_value__key, '_fw_content_genre')
  )
  AND (
    request__context__network_id IN (
      SELECT
        network_id
      FROM oltp.fwmrm_oltp.network_function
      WHERE
        function_id = 1661
    )
    OR BITWISE_AND(request__extra_flags2, 65536) > 0
  )
GROUP BY
  1,
  2,
  3,
  4,
  5
