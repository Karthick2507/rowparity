-- account:    yjgou
-- skeleton:   810c8bdaeddd133a560f4fa03832fe63
-- pattern:    6d931ddf0d16155fad24a39479f48c42  (29 execution(s))
-- in suite:   daily commitment
-- hoover:     transaction
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id < DATE_FORMAT(CAST(? AS TIMESTAMP), ?)
--   process_batch_id >= DATE_FORMAT(DATE_ADD(?, -?, CAST(? AS TIMESTAMP)), ?)

SELECT
  request__log_sampling__mode AS sampling_mode,
  request__log_sampling__magnifier AS sampling_magnifier,
  request__advertisement_count > 0 AS has_adv,
  request__external_candidate_count > 0 AS has_candidate,
  IF(
    BITWISE_AND(COALESCE(request__request_throttling_info__flags, 0), 1) > 0,
    TRUE,
    FALSE
  ) AS is_baseline,
  IF(
    BITWISE_AND(COALESCE(request__request_throttling_info__flags, 0), 2) > 0,
    TRUE,
    FALSE
  ) AS is_apply_prefilter,
  IF(
    BITWISE_AND(COALESCE(request__request_throttling_info__flags, 0), 4) > 0,
    TRUE,
    FALSE
  ) AS is_prefiltered,
  SUM(CASE WHEN request__is_first_request THEN 1 ELSE 0 END) AS total_first_request,
  COUNT(1) AS total_request,
  SUM(request__request_byte_size) AS total_request_byte_size,
  request__context__network_id AS network_id,
  DATE_TRUNC('DAY', DATE_PARSE(process_batch_id, '%y%m%d%h%i%s')) AS process_date
FROM ${bcv_transaction}
GROUP BY
  1,
  2,
  3,
  4,
  5,
  6,
  7,
  11,
  12
