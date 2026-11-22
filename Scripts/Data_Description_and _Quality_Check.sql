USE elliptic_project; 


-- =======================================check primary and foreign keys in the database=============================================
SELECT
    CONCAT(
        TABLE_NAME, '.', COLUMN_NAME,
        ': ',
        CASE
            WHEN CONSTRAINT_NAME = 'PRIMARY'
                THEN 'PRIMARY KEY'
            WHEN REFERENCED_TABLE_NAME IS NOT NULL
                THEN CONCAT(
                    'FOREIGN KEY -> ',
                    REFERENCED_TABLE_NAME, '.',
                    REFERENCED_COLUMN_NAME
                )
            ELSE CONSTRAINT_NAME
        END
    ) AS key_relationship
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'elliptic_project'
  AND (
      CONSTRAINT_NAME = 'PRIMARY'
      OR REFERENCED_TABLE_NAME IS NOT NULL
  )
ORDER BY TABLE_NAME, CONSTRAINT_NAME, ORDINAL_POSITION;

-- =======================================check metrics =============================================
SELECT
    CONCAT(
        TABLE_NAME,
        ': columns=', COUNT(*),
        ', numeric_columns=',
        SUM(
            DATA_TYPE IN (
                'tinyint', 'smallint', 'mediumint',
                'int', 'bigint', 'decimal',
                'float', 'double'
            )
        ),
        ', nullable_columns=',
        SUM(IS_NULLABLE = 'YES')
    ) AS schema_summary
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'elliptic_project'
  AND TABLE_NAME IN ('txs_features', 'txs_classes', 'txs_edges')
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;

-- =======================================check data amount=============================================
SELECT CONCAT(
    'txs_features: rows=', FORMAT(COUNT(*), 0),
    ', unique_transactions=', FORMAT(COUNT(DISTINCT tx_id), 0),
    ', distinct_time_steps=', FORMAT(COUNT(DISTINCT time_step), 0)
) AS dataset_summary
FROM txs_features

UNION ALL

SELECT CONCAT(
    'txs_classes: rows=', FORMAT(COUNT(*), 0),
    ', unique_transactions=', FORMAT(COUNT(DISTINCT txId), 0),
    ', distinct_class_values=', FORMAT(COUNT(DISTINCT class), 0)
)
FROM txs_classes

UNION ALL

SELECT CONCAT(
    'txs_edges: rows=', FORMAT(COUNT(*), 0),
    ', unique_edges=', FORMAT(COUNT(DISTINCT txId1, txId2), 0),
    ', unique_source_transactions=', FORMAT(COUNT(DISTINCT txId1), 0),
    ', unique_target_transactions=', FORMAT(COUNT(DISTINCT txId2), 0)
)
FROM txs_edges;



-- =======================================label distribution=============================================
SELECT CONCAT(
    'Label distribution: n=', FORMAT(COUNT(*), 0),

    ', illicit=', FORMAT(
        SUM(CASE WHEN class = 1 THEN 1 ELSE 0 END), 0
    ),
    ' (', ROUND(
        100.0 * SUM(CASE WHEN class = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ), '%)',

    ', licit=', FORMAT(
        SUM(CASE WHEN class = 2 THEN 1 ELSE 0 END), 0
    ),
    ' (', ROUND(
        100.0 * SUM(CASE WHEN class = 2 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ), '%)',

    ', unknown=', FORMAT(
        SUM(CASE WHEN class = 3 THEN 1 ELSE 0 END), 0
    ),
    ' (', ROUND(
        100.0 * SUM(CASE WHEN class = 3 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ), '%)',

    ', null_or_unexpected=', FORMAT(
        SUM(
            CASE
                WHEN class IS NULL OR class NOT IN (1, 2, 3)
                THEN 1 ELSE 0
            END
        ),
        0
    )
) AS label_summary
FROM txs_classes;

-- =======================================illicit proportion in known labels=============================================
SELECT CONCAT(
    'Known-label subset: n=', FORMAT(COUNT(*), 0),
    ', illicit=', FORMAT(
        SUM(CASE WHEN class = 1 THEN 1 ELSE 0 END), 0
    ),
    ', licit=', FORMAT(
        SUM(CASE WHEN class = 2 THEN 1 ELSE 0 END), 0
    ),
    ', illicit_rate=', ROUND(
        100.0 * SUM(CASE WHEN class = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ), '%'
) AS known_label_summary
FROM txs_classes
WHERE class IN (1, 2);

-- =======================================time range =============================================
SELECT CONCAT(
    'Time coverage: min_time_step=',
    COALESCE(CAST(MIN(time_step) AS CHAR), 'NULL'),
    ', max_time_step=',
    COALESCE(CAST(MAX(time_step) AS CHAR), 'NULL'),
    ', distinct_time_steps=',
    FORMAT(COUNT(DISTINCT time_step), 0),
    ', null_time_steps=',
    FORMAT(SUM(CASE WHEN time_step IS NULL THEN 1 ELSE 0 END), 0),
    ', rows_outside_expected_1_to_49=',
    FORMAT(
        SUM(
            CASE
                WHEN time_step IS NOT NULL
                     AND time_step NOT BETWEEN 1 AND 49
                THEN 1 ELSE 0
            END
        ),
        0
    )
) AS time_summary
FROM txs_features;

-- =======================================transaction and label distribution at each timestep=============================================
SELECT CONCAT(
    'time_step=', f.time_step,
    ', transactions=', FORMAT(COUNT(*), 0),
    ', illicit=', FORMAT(
        SUM(CASE WHEN c.class = 1 THEN 1 ELSE 0 END), 0
    ),
    ', licit=', FORMAT(
        SUM(CASE WHEN c.class = 2 THEN 1 ELSE 0 END), 0
    ),
    ', unknown=', FORMAT(
        SUM(CASE WHEN c.class = 3 THEN 1 ELSE 0 END), 0
    ),
    ', no_class_row=', FORMAT(
        SUM(CASE WHEN c.txId IS NULL THEN 1 ELSE 0 END), 0
    )
) AS time_step_summary
FROM txs_features AS f
LEFT JOIN txs_classes AS c
    ON f.tx_id = c.txId
GROUP BY f.time_step
ORDER BY f.time_step;

-- =======================================check data quality=============================================

-- check primary key and duplication
SELECT CONCAT(
    'txs_features key check: null_tx_id=',
    FORMAT(SUM(CASE WHEN tx_id IS NULL THEN 1 ELSE 0 END), 0),
    ', duplicate_non_null_tx_id_rows=',
    FORMAT(COUNT(tx_id) - COUNT(DISTINCT tx_id), 0)
) AS key_quality
FROM txs_features

UNION ALL

SELECT CONCAT(
    'txs_classes key check: null_txId=',
    FORMAT(SUM(CASE WHEN txId IS NULL THEN 1 ELSE 0 END), 0),
    ', duplicate_non_null_txId_rows=',
    FORMAT(COUNT(txId) - COUNT(DISTINCT txId), 0)
)
FROM txs_classes

UNION ALL

SELECT CONCAT(
    'txs_edges key check: null_txId1=',
    FORMAT(SUM(CASE WHEN txId1 IS NULL THEN 1 ELSE 0 END), 0),
    ', null_txId2=',
    FORMAT(SUM(CASE WHEN txId2 IS NULL THEN 1 ELSE 0 END), 0),
    ', duplicate_non_null_edge_rows=',
    FORMAT(
        SUM(
            CASE
                WHEN txId1 IS NOT NULL AND txId2 IS NOT NULL
                THEN 1 ELSE 0
            END
        ) - COUNT(DISTINCT txId1, txId2),
        0
    )
)
FROM txs_edges;


-- check forreign keys correspondence
SELECT CONCAT(
    'Referential check - class rows without matching feature transaction: n=',
    FORMAT(COUNT(*), 0)
) AS relationship_quality
FROM txs_classes AS c
LEFT JOIN txs_features AS f
    ON c.txId = f.tx_id
WHERE f.tx_id IS NULL

UNION ALL

SELECT CONCAT(
    'Referential check - edge sources without matching feature transaction: n=',
    FORMAT(COUNT(*), 0)
)
FROM txs_edges AS e
LEFT JOIN txs_features AS f
    ON e.txId1 = f.tx_id
WHERE f.tx_id IS NULL

UNION ALL

SELECT CONCAT(
    'Referential check - edge targets without matching feature transaction: n=',
    FORMAT(COUNT(*), 0)
)
FROM txs_edges AS e
LEFT JOIN txs_features AS f
    ON e.txId2 = f.tx_id
WHERE f.tx_id IS NULL;

-- check NULL class label
SELECT CONCAT(
    'Class coverage: total_transactions=', FORMAT(COUNT(*), 0),
    ', transactions_with_class_row=',
    FORMAT(
        SUM(CASE WHEN c.txId IS NOT NULL THEN 1 ELSE 0 END),
        0
    ),
    ', transactions_without_class_row=',
    FORMAT(
        SUM(CASE WHEN c.txId IS NULL THEN 1 ELSE 0 END),
        0
    ),
    ', class_row_coverage=',
    ROUND(
        100.0 * SUM(CASE WHEN c.txId IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ), '%'
) AS class_coverage_summary
FROM txs_features AS f
LEFT JOIN txs_classes AS c
    ON f.tx_id = c.txId;


-- check class value quality
SELECT CONCAT(
    'Class value quality: null_class=',
    FORMAT(SUM(CASE WHEN class IS NULL THEN 1 ELSE 0 END), 0),
    ', unexpected_class=',
    FORMAT(
        SUM(
            CASE
                WHEN class IS NOT NULL AND class NOT IN (1, 2, 3)
                THEN 1 ELSE 0
            END
        ),
        0
    )
) AS value_quality
FROM txs_classes

UNION ALL

SELECT CONCAT(
    'Edge quality: self_loops=',
    FORMAT(
        SUM(CASE WHEN txId1 = txId2 THEN 1 ELSE 0 END),
        0
    ),
    ', null_endpoint_rows=',
    FORMAT(
        SUM(
            CASE
                WHEN txId1 IS NULL OR txId2 IS NULL
                THEN 1 ELSE 0
            END
        ),
        0
    )
)
FROM txs_edges;


-- check Feature value quality (nagative money, min > max, etc.)
SELECT CONCAT(
    'Feature value quality: negative_value_rows=',
    FORMAT(
        SUM(
            CASE
                WHEN total_BTC < 0
                  OR fees < 0
                  OR in_BTC_min < 0
                  OR in_BTC_max < 0
                  OR in_BTC_mean < 0
                  OR in_BTC_median < 0
                  OR in_BTC_total < 0
                  OR out_BTC_min < 0
                  OR out_BTC_max < 0
                  OR out_BTC_mean < 0
                  OR out_BTC_median < 0
                  OR out_BTC_total < 0
                THEN 1 ELSE 0
            END
        ),
        0
    ),

    ', invalid_input_BTC_summary_rows=',
    FORMAT(
        SUM(
            CASE
                WHEN in_BTC_min > in_BTC_max
                  OR in_BTC_mean NOT BETWEEN in_BTC_min AND in_BTC_max
                  OR in_BTC_median NOT BETWEEN in_BTC_min AND in_BTC_max
                THEN 1 ELSE 0
            END
        ),
        0
    ),

    ', invalid_output_BTC_summary_rows=',
    FORMAT(
        SUM(
            CASE
                WHEN out_BTC_min > out_BTC_max
                  OR out_BTC_mean NOT BETWEEN out_BTC_min AND out_BTC_max
                  OR out_BTC_median NOT BETWEEN out_BTC_min AND out_BTC_max
                THEN 1 ELSE 0
            END
        ),
        0
    )
) AS feature_value_quality
FROM txs_features;

-- check missing values for all 184 columns in txs_features
SET SESSION group_concat_max_len = 1000000;

SELECT COUNT(*)
INTO @feature_column_count
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'elliptic_project'
  AND TABLE_NAME = 'txs_features';


SELECT GROUP_CONCAT(
    CONCAT('(`', COLUMN_NAME, '` IS NULL)')
    ORDER BY ORDINAL_POSITION
    SEPARATOR ' + '
)
INTO @row_null_expression
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'elliptic_project'
  AND TABLE_NAME = 'txs_features';


SELECT GROUP_CONCAT(
    CONCAT('(SUM(`', COLUMN_NAME, '` IS NULL) > 0)')
    ORDER BY ORDINAL_POSITION
    SEPARATOR ' + '
)
INTO @column_null_expression
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'elliptic_project'
  AND TABLE_NAME = 'txs_features';


SELECT GROUP_CONCAT(
    CONCAT(
        'IF(SUM(`', COLUMN_NAME, '` IS NULL) > 0, ',
        'CONCAT(''',
        COLUMN_NAME,
        '='', FORMAT(SUM(`',
        COLUMN_NAME,
        '` IS NULL), 0)), NULL)'
    )
    ORDER BY ORDINAL_POSITION
    SEPARATOR ', '
)
INTO @missing_detail_expression
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'elliptic_project'
  AND TABLE_NAME = 'txs_features';


SET @null_audit_sql = CONCAT(
    'SELECT ',
    '''txs_features'' AS table_name, ',
    'FORMAT(COUNT(*), 0) AS rows_checked, ',
    @feature_column_count, ' AS columns_checked, ',
    '(', @column_null_expression, ') AS columns_with_missing, ',
    'FORMAT(SUM((', @row_null_expression, ') > 0), 0) ',
    'AS rows_with_any_missing, ',
    'FORMAT(SUM(', @row_null_expression, '), 0) ',
    'AS total_missing_cells, ',
    'COALESCE(',
        'NULLIF(CONCAT_WS('', '', ',
        @missing_detail_expression,
        '), ''''), ',
        '''none''',
    ') AS missing_details ',
    'FROM elliptic_project.txs_features'
);

PREPARE null_audit_statement FROM @null_audit_sql;
EXECUTE null_audit_statement;
DEALLOCATE PREPARE null_audit_statement;

-- continue: check if missing values comes from original csv
-- create list
USE elliptic_project;

DROP TEMPORARY TABLE IF EXISTS tmp_missing_augmented;

CREATE TEMPORARY TABLE tmp_missing_augmented AS
SELECT
    tx_id,
    time_step
FROM txs_features
WHERE in_txs_degree IS NULL
   OR out_txs_degree IS NULL
   OR total_BTC IS NULL
   OR fees IS NULL
   OR size IS NULL
   OR num_input_addresses IS NULL
   OR num_output_addresses IS NULL
   OR in_BTC_min IS NULL
   OR in_BTC_max IS NULL
   OR in_BTC_mean IS NULL
   OR in_BTC_median IS NULL
   OR in_BTC_total IS NULL
   OR out_BTC_min IS NULL
   OR out_BTC_max IS NULL
   OR out_BTC_mean IS NULL
   OR out_BTC_median IS NULL
   OR out_BTC_total IS NULL;

SELECT CONCAT(
    'Missing augmented transaction list created: n=',
    FORMAT(COUNT(*), 0)
) AS result
FROM tmp_missing_augmented;

-- check if missing values comes from original csv
SELECT CONCAT(
    'Missing pattern check: rows_with_any_missing=',
    FORMAT(COUNT(*), 0),

    ', rows_with_all_17_missing=',
    FORMAT(
        SUM(
            CASE
                WHEN in_txs_degree IS NULL
                 AND out_txs_degree IS NULL
                 AND total_BTC IS NULL
                 AND fees IS NULL
                 AND size IS NULL
                 AND num_input_addresses IS NULL
                 AND num_output_addresses IS NULL
                 AND in_BTC_min IS NULL
                 AND in_BTC_max IS NULL
                 AND in_BTC_mean IS NULL
                 AND in_BTC_median IS NULL
                 AND in_BTC_total IS NULL
                 AND out_BTC_min IS NULL
                 AND out_BTC_max IS NULL
                 AND out_BTC_mean IS NULL
                 AND out_BTC_median IS NULL
                 AND out_BTC_total IS NULL
                THEN 1 ELSE 0
            END
        ),
        0
    ),

    ', rows_with_partial_missing=',
    FORMAT(
        COUNT(*) -
        SUM(
            CASE
                WHEN in_txs_degree IS NULL
                 AND out_txs_degree IS NULL
                 AND total_BTC IS NULL
                 AND fees IS NULL
                 AND size IS NULL
                 AND num_input_addresses IS NULL
                 AND num_output_addresses IS NULL
                 AND in_BTC_min IS NULL
                 AND in_BTC_max IS NULL
                 AND in_BTC_mean IS NULL
                 AND in_BTC_median IS NULL
                 AND in_BTC_total IS NULL
                 AND out_BTC_min IS NULL
                 AND out_BTC_max IS NULL
                 AND out_BTC_mean IS NULL
                 AND out_BTC_median IS NULL
                 AND out_BTC_total IS NULL
                THEN 1 ELSE 0
            END
        ),
        0
    )
) AS missing_pattern
FROM txs_features
WHERE tx_id IN (
    SELECT tx_id
    FROM tmp_missing_augmented
);

SELECT tx_id
FROM tmp_missing_augmented
ORDER BY tx_id;
-- CONFIRMED: ALL MISSING VALUES IN txs_features COME FROM ORIGINAL CSV FILE.

-- continue: check lable distributions in the missing values
SELECT CONCAT(
    'group=', missing_group,

    ', n=', FORMAT(COUNT(*), 0),

    ', illicit=', FORMAT(
        SUM(CASE WHEN class = 1 THEN 1 ELSE 0 END),
        0
    ),

    ', licit=', FORMAT(
        SUM(CASE WHEN class = 2 THEN 1 ELSE 0 END),
        0
    ),

    ', unknown=', FORMAT(
        SUM(CASE WHEN class = 3 THEN 1 ELSE 0 END),
        0
    ),

    ', known_label_n=', FORMAT(
        SUM(CASE WHEN class IN (1, 2) THEN 1 ELSE 0 END),
        0
    ),

    ', illicit_rate_among_known=',
    ROUND(
        100.0 *
        SUM(CASE WHEN class = 1 THEN 1 ELSE 0 END)
        /
        NULLIF(
            SUM(CASE WHEN class IN (1, 2) THEN 1 ELSE 0 END),
            0
        ),
        2
    ),
    '%'
) AS missing_label_comparison
FROM (
    SELECT
        f.tx_id,
        c.class,
        CASE
            WHEN m.tx_id IS NOT NULL
                THEN 'missing_augmented'
            ELSE 'complete_augmented'
        END AS missing_group
    FROM txs_features AS f
    INNER JOIN txs_classes AS c
        ON f.tx_id = c.txId
    LEFT JOIN tmp_missing_augmented AS m
        ON f.tx_id = m.tx_id
) AS grouped_transactions
GROUP BY missing_group
ORDER BY missing_group;

-- continue: check if missing values are concentrated at certain timestep
SELECT COUNT(*)
INTO @total_missing_augmented
FROM tmp_missing_augmented;


SELECT CONCAT(
    'time_step=', f.time_step,

    ', total_transactions=',
    FORMAT(COUNT(*), 0),

    ', missing_augmented_n=',
    FORMAT(
        SUM(CASE WHEN m.tx_id IS NOT NULL THEN 1 ELSE 0 END),
        0
    ),

    ', missing_rate_within_time_step=',
    ROUND(
        100.0 *
        SUM(CASE WHEN m.tx_id IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ),
    '%',

    ', share_of_all_missing=',
    ROUND(
        100.0 *
        SUM(CASE WHEN m.tx_id IS NOT NULL THEN 1 ELSE 0 END)
        / NULLIF(@total_missing_augmented, 0),
        2
    ),
    '%'
) AS missing_by_time_step

FROM txs_features AS f

LEFT JOIN tmp_missing_augmented AS m
    ON f.tx_id = m.tx_id

GROUP BY f.time_step

HAVING SUM(
    CASE WHEN m.tx_id IS NOT NULL THEN 1 ELSE 0 END
) > 0

ORDER BY
    SUM(CASE WHEN m.tx_id IS NOT NULL THEN 1 ELSE 0 END) DESC,
    f.time_step;
    
-- CONCLUSION: HAS OBVIOUS CONCENTRAION, BUT NOT TREND

-- continue: check whether these missing transactions exist in the edge table.
WITH calculated_out_edges AS (
    SELECT
        txId1 AS tx_id,
        COUNT(*) AS out_edge_count
    FROM txs_edges
    GROUP BY txId1
),
calculated_in_edges AS (
    SELECT
        txId2 AS tx_id,
        COUNT(*) AS in_edge_count
    FROM txs_edges
    GROUP BY txId2
)
SELECT CONCAT(
    'Missing augmented edge presence: n=',
    FORMAT(COUNT(*), 0),

    ', appears_as_source=',
    FORMAT(
        SUM(
            CASE
                WHEN COALESCE(o.out_edge_count, 0) > 0
                THEN 1 ELSE 0
            END
        ),
        0
    ),

    ', appears_as_target=',
    FORMAT(
        SUM(
            CASE
                WHEN COALESCE(i.in_edge_count, 0) > 0
                THEN 1 ELSE 0
            END
        ),
        0
    ),

    ', appears_in_any_edge=',
    FORMAT(
        SUM(
            CASE
                WHEN COALESCE(o.out_edge_count, 0) > 0
                  OR COALESCE(i.in_edge_count, 0) > 0
                THEN 1 ELSE 0
            END
        ),
        0
    ),

    ', isolated_transactions=',
    FORMAT(
        SUM(
            CASE
                WHEN COALESCE(o.out_edge_count, 0) = 0
                 AND COALESCE(i.in_edge_count, 0) = 0
                THEN 1 ELSE 0
            END
        ),
        0
    ),

    ', total_calculated_out_edges=',
    FORMAT(SUM(COALESCE(o.out_edge_count, 0)), 0),

    ', total_calculated_in_edges=',
    FORMAT(SUM(COALESCE(i.in_edge_count, 0)), 0)
) AS missing_edge_summary
FROM tmp_missing_augmented AS m
LEFT JOIN calculated_out_edges AS o
    ON m.tx_id = o.tx_id
LEFT JOIN calculated_in_edges AS i
    ON m.tx_id = i.tx_id;

-- check transaction degrees (id1 is source, id2 is target)
WITH calculated_out_degree AS (
    SELECT
        txId1 AS tx_id,
        COUNT(*) AS calculated_out_degree
    FROM txs_edges
    GROUP BY txId1
),
calculated_in_degree AS (
    SELECT
        txId2 AS tx_id,
        COUNT(*) AS calculated_in_degree
    FROM txs_edges
    GROUP BY txId2
)
SELECT CONCAT(
    'Degree consistency: transactions_checked=',
    FORMAT(COUNT(*), 0),

    ', out_degree_mismatch=',
    FORMAT(
        SUM(
            CASE
                WHEN f.out_txs_degree IS NOT NULL
                 AND f.out_txs_degree <>
                     COALESCE(o.calculated_out_degree, 0)
                THEN 1 ELSE 0
            END
        ),
        0
    ),

    ', in_degree_mismatch=',
    FORMAT(
        SUM(
            CASE
                WHEN f.in_txs_degree IS NOT NULL
                 AND f.in_txs_degree <>
                     COALESCE(i.calculated_in_degree, 0)
                THEN 1 ELSE 0
            END
        ),
        0
    )
) AS degree_quality
FROM txs_features AS f
LEFT JOIN calculated_out_degree AS o
    ON f.tx_id = o.tx_id
LEFT JOIN calculated_in_degree AS i
    ON f.tx_id = i.tx_id;