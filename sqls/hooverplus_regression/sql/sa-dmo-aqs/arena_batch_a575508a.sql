-- account:    sa-dmo-aqs
-- skeleton:   c86328827b77b2aa4a43adf247db1444
-- pattern:    a575508af6f1aac77a90417f52541a2e  (174 execution(s))
-- in suite:   daily commitment
-- hoover:     request
-- kind:       WRITE
--
-- Raw hoover tables are left as {{bcv_<table>}}. Bind each to its BCV view.
--
-- Slice filter, lifted out during normalisation. Re-apply when running:
--   process_batch_id <= ?
--   request__timestamp > DATE_ADD(?, -?, DATE_PARSE(?, ?))

SELECT
  f.event_date,
  CAST(f.network_id AS BIGINT) AS network_id,
  f.tag,
  f.delivered_imps
FROM (
  SELECT
    DATE(request__timestamp) AS event_date,
    SUBSTR(
      request__context__custom_site_section_id,
      1,
      STRPOS(request__context__custom_site_section_id, '/') - 1
    ) AS network_id,
    SUBSTR(
      request__context__custom_site_section_id,
      STRPOS(request__context__custom_site_section_id, '/') + 1,
      255
    ) AS tag,
    COUNT(1) AS delivered_imps
  FROM ${bcv_request}
  WHERE
    (
      (
        (
          (
            BITWISE_AND(request__flags, 2048) = 2048
            AND (
              BITWISE_AND(request__flags, 64) = 0
              OR (
                BITWISE_AND(request__flags, 64) = 64 AND visitor__filtration_reason = 1001
              )
            )
          )
          AND NOT request__context__custom_site_section_id IS NULL
        )
        AND LENGTH(request__context__custom_site_section_id) > 0
      )
      AND STRPOS(request__context__custom_site_section_id, '/') > 1
    )
    AND COALESCE(request__context__video_cro_network_id, -1) <> 529566
  GROUP BY
    1,
    2,
    3
) AS f
JOIN (
  SELECT
    CAST(nf.network_id AS VARCHAR) AS network_id,
    IF(nf.parameter = '', 0, CAST(nf.parameter AS INTEGER)) AS threshold
  FROM db.default.d_network_function AS nf
  JOIN db.default.d_lu_network_function AS lnf
    ON nf.function_id = lnf.id AND lnf.name = 'frontend_ingest_site_section'
) AS d
  ON f.network_id = d.network_id
WHERE
  f.delivered_imps >= d.threshold
