USE elliptic_project;

-- ======================== 1. risk lables trend over timesteps ===========================
-- 1.1 transaction amout, lables, and risk for each timestep
WITH time_statistics AS (
    SELECT
        f.time_step,
        COUNT(*) AS total_transactions,

        SUM(
            CASE WHEN c.class IN (1, 2)
                 THEN 1 ELSE 0 END
        ) AS known_label_n,

        SUM(
            CASE WHEN c.class = 1
                 THEN 1 ELSE 0 END
        ) AS illicit_n,

        SUM(
            CASE WHEN c.class = 2
                 THEN 1 ELSE 0 END
        ) AS licit_n,

        SUM(
            CASE WHEN c.class = 3
                 THEN 1 ELSE 0 END
        ) AS unknown_n

    FROM txs_features AS f
    INNER JOIN txs_classes AS c
        ON f.tx_id = c.txId
    GROUP BY f.time_step
),

overall_statistics AS (
    SELECT
        SUM(known_label_n) AS overall_known_n,
        SUM(illicit_n) AS overall_illicit_n
    FROM time_statistics
)

SELECT CONCAT(
    'time_step=', t.time_step,

    ', total_transactions=',
    FORMAT(t.total_transactions, 0),

    ', known_label_n=',
    FORMAT(t.known_label_n, 0),

    ', illicit_n=',
    FORMAT(t.illicit_n, 0),

    ', licit_n=',
    FORMAT(t.licit_n, 0),

    ', unknown_n=',
    FORMAT(t.unknown_n, 0),

    ', known_label_coverage=',
    ROUND(
        100.0 * t.known_label_n
        / NULLIF(t.total_transactions, 0),
        2
    ),
    '%',

    ', illicit_rate_among_known=',
    ROUND(
        100.0 * t.illicit_n
        / NULLIF(t.known_label_n, 0),
        2
    ),
    '%',

    ', unknown_rate=',
    ROUND(
        100.0 * t.unknown_n
        / NULLIF(t.total_transactions, 0),
        2
    ),
    '%',

    ', risk_lift_vs_overall=',
    ROUND(
        (
            t.illicit_n / NULLIF(t.known_label_n, 0)
        )
        /
        (
            o.overall_illicit_n
            / NULLIF(o.overall_known_n, 0)
        ),
        2
    ),
    'x'
) AS time_risk_summary

FROM time_statistics AS t
CROSS JOIN overall_statistics AS o
ORDER BY t.time_step;

-- 1.2 top 10 riskiest timesteps， ordered by illicit rate
WITH time_risk AS (
    SELECT
        f.time_step,
        COUNT(*) AS total_transactions,

        SUM(
            CASE WHEN c.class IN (1, 2)
                 THEN 1 ELSE 0 END
        ) AS known_label_n,

        SUM(
            CASE WHEN c.class = 1
                 THEN 1 ELSE 0 END
        ) AS illicit_n,

        100.0 *
        SUM(CASE WHEN c.class = 1 THEN 1 ELSE 0 END)
        /
        NULLIF(
            SUM(CASE WHEN c.class IN (1, 2)
                     THEN 1 ELSE 0 END),
            0
        ) AS illicit_rate

    FROM txs_features AS f
    INNER JOIN txs_classes AS c
        ON f.tx_id = c.txId
    GROUP BY f.time_step
),

ranked_time_risk AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY illicit_rate DESC
        ) AS risk_rank
    FROM time_risk
)

SELECT CONCAT(
    'risk_rank=', risk_rank,
    ', time_step=', time_step,
    ', total_transactions=', FORMAT(total_transactions, 0),
    ', known_label_n=', FORMAT(known_label_n, 0),
    ', illicit_n=', FORMAT(illicit_n, 0),
    ', illicit_rate_among_known=',
    ROUND(illicit_rate, 2),
    '%'
) AS highest_risk_time_steps

FROM ranked_time_risk
WHERE risk_rank <= 10
ORDER BY risk_rank;

-- ============================= 2. compare similaritiese between unkown & know labels =========================
-- 2.1 if unknown labels are concentrated at certain timesteps
WITH time_unknown AS (
    SELECT
        f.time_step,
        COUNT(*) AS total_transactions,

        SUM(
            CASE WHEN c.class = 3
                 THEN 1 ELSE 0 END
        ) AS unknown_n

    FROM txs_features AS f
    INNER JOIN txs_classes AS c
        ON f.tx_id = c.txId
    GROUP BY f.time_step
),

overall_unknown AS (
    SELECT SUM(unknown_n) AS all_unknown_n
    FROM time_unknown
)

SELECT CONCAT(
    'time_step=', t.time_step,

    ', total_transactions=',
    FORMAT(t.total_transactions, 0),

    ', unknown_n=',
    FORMAT(t.unknown_n, 0),

    ', unknown_rate_within_time_step=',
    ROUND(
        100.0 * t.unknown_n
        / NULLIF(t.total_transactions, 0),
        2
    ),
    '%',

    ', share_of_all_unknown=',
    ROUND(
        100.0 * t.unknown_n
        / NULLIF(o.all_unknown_n, 0),
        2
    ),
    '%'
) AS unknown_time_summary

FROM time_unknown AS t
CROSS JOIN overall_unknown AS o
ORDER BY t.time_step;

-- 2.2 compare key features between unkown and known labels
WITH base_data AS (
    SELECT
        CASE
            WHEN c.class = 3 THEN 'Unknown'
            ELSE 'Known'
        END AS label_group,

        f.total_BTC,
        f.fees,
        f.`size`,
        f.in_txs_degree,
        f.out_txs_degree,
        f.num_input_addresses,
        f.num_output_addresses

    FROM txs_features AS f
    INNER JOIN txs_classes AS c
        ON f.tx_id = c.txId
    WHERE c.class IN (1, 2, 3)
),

long_data AS (
    SELECT label_group, 'total_BTC' AS feature_name,
           total_BTC AS feature_value
    FROM base_data

    UNION ALL

    SELECT label_group, 'fees', fees
    FROM base_data

    UNION ALL

    SELECT label_group, 'size', `size`
    FROM base_data

    UNION ALL

    SELECT label_group, 'in_txs_degree', in_txs_degree
    FROM base_data

    UNION ALL

    SELECT label_group, 'out_txs_degree', out_txs_degree
    FROM base_data

    UNION ALL

    SELECT label_group, 'num_input_addresses',
           num_input_addresses
    FROM base_data

    UNION ALL

    SELECT label_group, 'num_output_addresses',
           num_output_addresses
    FROM base_data
),

ranked_data AS (
    SELECT
        label_group,
        feature_name,
        feature_value,

        ROW_NUMBER() OVER (
            PARTITION BY label_group, feature_name
            ORDER BY feature_value
        ) AS row_number_value,

        COUNT(*) OVER (
            PARTITION BY label_group, feature_name
        ) AS group_n

    FROM long_data
    WHERE feature_value IS NOT NULL
),

feature_statistics AS (
    SELECT
        label_group,
        feature_name,

        MAX(group_n) AS valid_n,
        AVG(feature_value) AS mean_value,
        VAR_SAMP(feature_value) AS variance_value,

        MAX(
            CASE
                WHEN row_number_value = CEIL(0.25 * group_n)
                THEN feature_value
            END
        ) AS q1_value,

        AVG(
            CASE
                WHEN row_number_value IN (
                    FLOOR((group_n + 1) / 2),
                    FLOOR((group_n + 2) / 2)
                )
                THEN feature_value
            END
        ) AS median_value,

        MAX(
            CASE
                WHEN row_number_value = CEIL(0.75 * group_n)
                THEN feature_value
            END
        ) AS q3_value

    FROM ranked_data
    GROUP BY label_group, feature_name
)

SELECT CONCAT(
    'feature=', known.feature_name,

    ', known_valid_n=',
    FORMAT(known.valid_n, 0),

    ', unknown_valid_n=',
    FORMAT(unknown_group.valid_n, 0),

    ', known_mean=',
    FORMAT(known.mean_value, 8),

    ', unknown_mean=',
    FORMAT(unknown_group.mean_value, 8),

    ', known_median=',
    FORMAT(known.median_value, 8),

    ', unknown_median=',
    FORMAT(unknown_group.median_value, 8),

    ', known_Q1=',
    FORMAT(known.q1_value, 8),

    ', known_Q3=',
    FORMAT(known.q3_value, 8),

    ', unknown_Q1=',
    FORMAT(unknown_group.q1_value, 8),

    ', unknown_Q3=',
    FORMAT(unknown_group.q3_value, 8),

    ', median_difference_unknown_minus_known=',
    FORMAT(
        unknown_group.median_value
        - known.median_value,
        8
    ),

    ', standardized_mean_difference=',
    COALESCE(
        CAST(
            ROUND(
                (
                    unknown_group.mean_value
                    - known.mean_value
                )
                /
                NULLIF(
                    SQRT(
                        (
                            unknown_group.variance_value
                            + known.variance_value
                        ) / 2
                    ),
                    0
                ),
                4
            ) AS CHAR
        ),
        'undefined'
    )
) AS unknown_vs_known_feature_comparison

FROM feature_statistics AS known
INNER JOIN feature_statistics AS unknown_group
    ON known.feature_name = unknown_group.feature_name
   AND known.label_group = 'Known'
   AND unknown_group.label_group = 'Unknown'

ORDER BY known.feature_name;

-- ========================== 3. relationship b/w 17 augmented featues(last 17 featues in txs_features.csv) and lables ===================
WITH base_data AS (
    SELECT
        CASE
            WHEN c.class = 1 THEN 'Illicit'
            WHEN c.class = 2 THEN 'Licit'
        END AS class_name,

        f.in_txs_degree,
        f.out_txs_degree,
        f.total_BTC,
        f.fees,
        f.`size`,
        f.num_input_addresses,
        f.num_output_addresses,
        f.in_BTC_min,
        f.in_BTC_max,
        f.in_BTC_mean,
        f.in_BTC_median,
        f.in_BTC_total,
        f.out_BTC_min,
        f.out_BTC_max,
        f.out_BTC_mean,
        f.out_BTC_median,
        f.out_BTC_total

    FROM txs_features AS f
    INNER JOIN txs_classes AS c
        ON f.tx_id = c.txId
    WHERE c.class IN (1, 2)
),

group_totals AS (
    SELECT
        class_name,
        COUNT(*) AS total_group_n
    FROM base_data
    GROUP BY class_name
),

long_data AS (
    SELECT class_name, 'in_txs_degree' AS feature_name,
           in_txs_degree AS feature_value
    FROM base_data

    UNION ALL
    SELECT class_name, 'out_txs_degree', out_txs_degree
    FROM base_data

    UNION ALL
    SELECT class_name, 'total_BTC', total_BTC
    FROM base_data

    UNION ALL
    SELECT class_name, 'fees', fees
    FROM base_data

    UNION ALL
    SELECT class_name, 'size', `size`
    FROM base_data

    UNION ALL
    SELECT class_name, 'num_input_addresses',
           num_input_addresses
    FROM base_data

    UNION ALL
    SELECT class_name, 'num_output_addresses',
           num_output_addresses
    FROM base_data

    UNION ALL
    SELECT class_name, 'in_BTC_min', in_BTC_min
    FROM base_data

    UNION ALL
    SELECT class_name, 'in_BTC_max', in_BTC_max
    FROM base_data

    UNION ALL
    SELECT class_name, 'in_BTC_mean', in_BTC_mean
    FROM base_data

    UNION ALL
    SELECT class_name, 'in_BTC_median', in_BTC_median
    FROM base_data

    UNION ALL
    SELECT class_name, 'in_BTC_total', in_BTC_total
    FROM base_data

    UNION ALL
    SELECT class_name, 'out_BTC_min', out_BTC_min
    FROM base_data

    UNION ALL
    SELECT class_name, 'out_BTC_max', out_BTC_max
    FROM base_data

    UNION ALL
    SELECT class_name, 'out_BTC_mean', out_BTC_mean
    FROM base_data

    UNION ALL
    SELECT class_name, 'out_BTC_median', out_BTC_median
    FROM base_data

    UNION ALL
    SELECT class_name, 'out_BTC_total', out_BTC_total
    FROM base_data
),

non_null_data AS (
    SELECT *
    FROM long_data
    WHERE feature_value IS NOT NULL
),

ranked_data AS (
    SELECT
        class_name,
        feature_name,
        feature_value,

        ROW_NUMBER() OVER (
            PARTITION BY class_name, feature_name
            ORDER BY feature_value
        ) AS row_number_value,

        COUNT(*) OVER (
            PARTITION BY class_name, feature_name
        ) AS valid_n

    FROM non_null_data
),

quartile_statistics AS (
    SELECT
        class_name,
        feature_name,

        MAX(valid_n) AS valid_n,
        AVG(feature_value) AS mean_value,
        STDDEV_SAMP(feature_value) AS standard_deviation,
        MIN(feature_value) AS minimum_value,
        MAX(feature_value) AS maximum_value,

        MAX(
            CASE
                WHEN row_number_value = CEIL(0.25 * valid_n)
                THEN feature_value
            END
        ) AS q1_value,

        AVG(
            CASE
                WHEN row_number_value IN (
                    FLOOR((valid_n + 1) / 2),
                    FLOOR((valid_n + 2) / 2)
                )
                THEN feature_value
            END
        ) AS median_value,

        MAX(
            CASE
                WHEN row_number_value = CEIL(0.75 * valid_n)
                THEN feature_value
            END
        ) AS q3_value,

        MAX(
            CASE
                WHEN row_number_value = CEIL(0.99 * valid_n)
                THEN feature_value
            END
        ) AS p99_value

    FROM ranked_data
    GROUP BY class_name, feature_name
),

final_statistics AS (
    SELECT
        q.class_name,
        q.feature_name,
        g.total_group_n,
        q.valid_n,
        q.mean_value,
        q.standard_deviation,
        q.minimum_value,
        q.maximum_value,
        q.q1_value,
        q.median_value,
        q.q3_value,
        q.p99_value,

        SUM(
            CASE
                WHEN d.feature_value >
                     q.q3_value
                     + 1.5 * (q.q3_value - q.q1_value)
                THEN 1 ELSE 0
            END
        ) AS upper_outlier_n,

        AVG(
            LN(1 + d.feature_value)
        ) AS mean_log1p_value

    FROM quartile_statistics AS q
    INNER JOIN non_null_data AS d
        ON q.class_name = d.class_name
       AND q.feature_name = d.feature_name
    INNER JOIN group_totals AS g
        ON q.class_name = g.class_name

    GROUP BY
        q.class_name,
        q.feature_name,
        g.total_group_n,
        q.valid_n,
        q.mean_value,
        q.standard_deviation,
        q.minimum_value,
        q.maximum_value,
        q.q1_value,
        q.median_value,
        q.q3_value,
        q.p99_value
)

SELECT CONCAT(
    'feature=', feature_name,
    ', class=', class_name,

    ', total_group_n=',
    FORMAT(total_group_n, 0),

    ', valid_n=',
    FORMAT(valid_n, 0),

    ', missing_n=',
    FORMAT(total_group_n - valid_n, 0),

    ', mean=',
    FORMAT(mean_value, 8),

    ', median=',
    FORMAT(median_value, 8),

    ', Q1=',
    FORMAT(q1_value, 8),

    ', Q3=',
    FORMAT(q3_value, 8),

    ', IQR=',
    FORMAT(q3_value - q1_value, 8),

    ', standard_deviation=',
    FORMAT(standard_deviation, 8),

    ', minimum=',
    FORMAT(minimum_value, 8),

    ', P99=',
    FORMAT(p99_value, 8),

    ', maximum=',
    FORMAT(maximum_value, 8),

    ', mean_to_median_ratio=',
    COALESCE(
        CAST(
            ROUND(
                mean_value / NULLIF(median_value, 0),
                4
            ) AS CHAR
        ),
        'undefined_when_median_is_zero'
    ),

    ', upper_outlier_n=',
    FORMAT(upper_outlier_n, 0),

    ', upper_outlier_rate=',
    ROUND(
        100.0 * upper_outlier_n
        / NULLIF(valid_n, 0),
        2
    ),
    '%',

    ', mean_log1p=',
    FORMAT(mean_log1p_value, 8)
) AS augmented_feature_eda

FROM final_statistics
ORDER BY feature_name, class_name;

-- 3.2 Compare log-transformed Augmented Features
-- between Illicit and Licit transactions using SMD

DROP TEMPORARY TABLE IF EXISTS tmp_augmented_feature_map;

CREATE TEMPORARY TABLE tmp_augmented_feature_map (
    feature_order INT PRIMARY KEY,
    feature_name VARCHAR(64) NOT NULL
);

INSERT INTO tmp_augmented_feature_map
(feature_order, feature_name)
VALUES
    (1,  'in_txs_degree'),
    (2,  'out_txs_degree'),
    (3,  'total_BTC'),
    (4,  'fees'),
    (5,  'size'),
    (6,  'num_input_addresses'),
    (7,  'num_output_addresses'),
    (8,  'in_BTC_min'),
    (9,  'in_BTC_max'),
    (10, 'in_BTC_mean'),
    (11, 'in_BTC_median'),
    (12, 'in_BTC_total'),
    (13, 'out_BTC_min'),
    (14, 'out_BTC_max'),
    (15, 'out_BTC_mean'),
    (16, 'out_BTC_median'),
    (17, 'out_BTC_total');


SELECT GROUP_CONCAT(
    CONCAT(
        QUOTE(feature_name), ', JSON_OBJECT(',

        '''illicit_n'', ',
        'COUNT(CASE WHEN c.class = 1 ',
        'AND f.`', feature_name, '` IS NOT NULL THEN 1 END), ',

        '''illicit_log_mean'', ',
        'AVG(CASE WHEN c.class = 1 ',
        'THEN LN(1 + f.`', feature_name, '`) END), ',

        '''illicit_log_variance'', ',
        'VAR_SAMP(CASE WHEN c.class = 1 ',
        'THEN LN(1 + f.`', feature_name, '`) END), ',

        '''licit_n'', ',
        'COUNT(CASE WHEN c.class = 2 ',
        'AND f.`', feature_name, '` IS NOT NULL THEN 1 END), ',

        '''licit_log_mean'', ',
        'AVG(CASE WHEN c.class = 2 ',
        'THEN LN(1 + f.`', feature_name, '`) END), ',

        '''licit_log_variance'', ',
        'VAR_SAMP(CASE WHEN c.class = 2 ',
        'THEN LN(1 + f.`', feature_name, '`) END)',

        ')'
    )
    ORDER BY feature_order
    SEPARATOR ', '
)
INTO @augmented_log_json_pairs
FROM tmp_augmented_feature_map;

SET @augmented_log_sql = CONCAT(
    'SELECT JSON_OBJECT(',
    @augmented_log_json_pairs,
    ') INTO @augmented_log_json ',
    'FROM elliptic_project.txs_features AS f ',
    'INNER JOIN elliptic_project.txs_classes AS c ',
    'ON f.tx_id = c.txId ',
    'WHERE c.class IN (1, 2)'
);

PREPARE augmented_log_statement
FROM @augmented_log_sql;

EXECUTE augmented_log_statement;

DEALLOCATE PREPARE augmented_log_statement;


DROP TEMPORARY TABLE IF EXISTS tmp_augmented_log_profile;

CREATE TEMPORARY TABLE tmp_augmented_log_profile AS
SELECT
    m.feature_order,
    m.feature_name,

    CAST(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                @augmented_log_json,
                CONCAT('$."', m.feature_name, '".illicit_n')
            )
        ) AS UNSIGNED
    ) AS illicit_n,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @augmented_log_json,
            CONCAT('$."', m.feature_name, '".illicit_log_mean')
        )
    ) * 1.0 AS illicit_log_mean,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @augmented_log_json,
            CONCAT('$."', m.feature_name, '".illicit_log_variance')
        )
    ) * 1.0 AS illicit_log_variance,

    CAST(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                @augmented_log_json,
                CONCAT('$."', m.feature_name, '".licit_n')
            )
        ) AS UNSIGNED
    ) AS licit_n,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @augmented_log_json,
            CONCAT('$."', m.feature_name, '".licit_log_mean')
        )
    ) * 1.0 AS licit_log_mean,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @augmented_log_json,
            CONCAT('$."', m.feature_name, '".licit_log_variance')
        )
    ) * 1.0 AS licit_log_variance

FROM tmp_augmented_feature_map AS m;


WITH augmented_log_signal AS (
    SELECT
        *,
        (
            illicit_log_mean - licit_log_mean
        )
        /
        NULLIF(
            SQRT(
                (
                    illicit_log_variance
                    + licit_log_variance
                ) / 2
            ),
            0
        ) AS log1p_smd
    FROM tmp_augmented_log_profile
),
ranked_augmented_signal AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY ABS(log1p_smd) DESC
        ) AS signal_rank
    FROM augmented_log_signal
    WHERE log1p_smd IS NOT NULL
)
SELECT CONCAT(
    'rank=', signal_rank,
    ', feature=', feature_name,
    ', illicit_valid_n=', FORMAT(illicit_n, 0),
    ', licit_valid_n=', FORMAT(licit_n, 0),
    ', illicit_mean_log1p=', FORMAT(illicit_log_mean, 6),
    ', licit_mean_log1p=', FORMAT(licit_log_mean, 6),
    ', log1p_SMD=', FORMAT(log1p_smd, 4),
    ', absolute_log1p_SMD=', FORMAT(ABS(log1p_smd), 4),
    ', direction=',
    CASE
        WHEN log1p_smd > 0 THEN 'higher_in_illicit'
        WHEN log1p_smd < 0 THEN 'lower_in_illicit'
        ELSE 'no_mean_difference'
    END
) AS augmented_log_feature_signal
FROM ranked_augmented_signal
ORDER BY signal_rank;

-- ================================= 4. local and aggregate features ===========================
-- 4.1 create mapping relationship
USE elliptic_project;

SET SESSION group_concat_max_len = 16777216;

DROP TEMPORARY TABLE IF EXISTS tmp_feature_map;

CREATE TEMPORARY TABLE tmp_feature_map AS
SELECT
    COLUMN_NAME AS feature_name,
    CASE
        WHEN COLUMN_NAME LIKE 'local_feature_%' THEN 'Local'
        WHEN COLUMN_NAME LIKE 'aggregate_feature_%' THEN 'Aggregate'
    END AS feature_group,
    ORDINAL_POSITION
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'elliptic_project'
  AND TABLE_NAME = 'txs_features'
  AND (
        COLUMN_NAME REGEXP '^local_feature_[0-9]+$'
        OR COLUMN_NAME REGEXP '^aggregate_feature_[0-9]+$'
      );

SELECT CONCAT(
    'Feature list created: total_features=', COUNT(*),
    ', local_features=',
    SUM(feature_group = 'Local'),
    ', aggregate_features=',
    SUM(feature_group = 'Aggregate')
) AS feature_list_summary
FROM tmp_feature_map;

-- 4.2 Calculate Summary Statistics and Class Differences for All 165 Local and Aggregate Features

SELECT GROUP_CONCAT(
    CONCAT(
        QUOTE(feature_name), ', JSON_OBJECT(',

        '''valid_n'', COUNT(f.`', feature_name, '`), ',

        '''mean_all'', AVG(f.`', feature_name, '`), ',
        '''variance_all'', VAR_SAMP(f.`', feature_name, '`), ',

        '''illicit_n'', ',
        'COUNT(CASE WHEN c.class = 1 ',
        'AND f.`', feature_name, '` IS NOT NULL THEN 1 END), ',

        '''illicit_mean'', ',
        'AVG(CASE WHEN c.class = 1 ',
        'THEN f.`', feature_name, '` END), ',

        '''illicit_variance'', ',
        'VAR_SAMP(CASE WHEN c.class = 1 ',
        'THEN f.`', feature_name, '` END), ',

        '''licit_n'', ',
        'COUNT(CASE WHEN c.class = 2 ',
        'AND f.`', feature_name, '` IS NOT NULL THEN 1 END), ',

        '''licit_mean'', ',
        'AVG(CASE WHEN c.class = 2 ',
        'THEN f.`', feature_name, '` END), ',

        '''licit_variance'', ',
        'VAR_SAMP(CASE WHEN c.class = 2 ',
        'THEN f.`', feature_name, '` END)',

        ')'
    )
    ORDER BY ORDINAL_POSITION
    SEPARATOR ', '
)
INTO @feature_json_pairs
FROM tmp_feature_map;


SET @feature_profile_sql = CONCAT(
    'SELECT JSON_OBJECT(',
    @feature_json_pairs,
    ') INTO @feature_profile_json ',
    'FROM elliptic_project.txs_features AS f ',
    'JOIN elliptic_project.txs_classes AS c ',
    'ON c.txId = f.tx_id ',
    'WHERE c.class IN (1, 2)'
);

SELECT CONCAT(
    'Feature profiling query generated: SQL_length=',
    FORMAT(LENGTH(@feature_profile_sql), 0),
    ' characters'
) AS query_generation_status;

PREPARE feature_profile_statement
FROM @feature_profile_sql;

EXECUTE feature_profile_statement;

DEALLOCATE PREPARE feature_profile_statement;

SELECT CONCAT(
    'Feature aggregation completed: JSON_length=',
    FORMAT(LENGTH(@feature_profile_json), 0),
    ' characters'
) AS feature_aggregation_status;

-- 4.3 create table
DROP TEMPORARY TABLE IF EXISTS tmp_feature_profile;

CREATE TEMPORARY TABLE tmp_feature_profile AS
SELECT
    m.feature_name,
    m.feature_group,
    m.ORDINAL_POSITION,

    CAST(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                @feature_profile_json,
                CONCAT('$."', m.feature_name, '".valid_n')
            )
        ) AS UNSIGNED
    ) AS valid_n,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @feature_profile_json,
            CONCAT('$."', m.feature_name, '".mean_all')
        )
    ) * 1.0 AS mean_all,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @feature_profile_json,
            CONCAT('$."', m.feature_name, '".variance_all')
        )
    ) * 1.0 AS variance_all,

    CAST(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                @feature_profile_json,
                CONCAT('$."', m.feature_name, '".illicit_n')
            )
        ) AS UNSIGNED
    ) AS illicit_n,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @feature_profile_json,
            CONCAT('$."', m.feature_name, '".illicit_mean')
        )
    ) * 1.0 AS illicit_mean,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @feature_profile_json,
            CONCAT('$."', m.feature_name, '".illicit_variance')
        )
    ) * 1.0 AS illicit_variance,

    CAST(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                @feature_profile_json,
                CONCAT('$."', m.feature_name, '".licit_n')
            )
        ) AS UNSIGNED
    ) AS licit_n,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @feature_profile_json,
            CONCAT('$."', m.feature_name, '".licit_mean')
        )
    ) * 1.0 AS licit_mean,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @feature_profile_json,
            CONCAT('$."', m.feature_name, '".licit_variance')
        )
    ) * 1.0 AS licit_variance

FROM tmp_feature_map AS m;

SELECT CONCAT(
    'Feature profile table created: n_features=',
    COUNT(*)
) AS feature_profile_status
FROM tmp_feature_profile;

-- 4.4 check constant and non-constant features
SELECT CONCAT(
    'Variance screening summary: total_features=', COUNT(*),
    ', constant_features=',
    SUM(COALESCE(variance_all, 0) = 0),
    ', near_constant_features=',
    SUM(
        variance_all > 0
        AND SQRT(variance_all)
            <= 0.00000001 * GREATEST(1, ABS(mean_all))
    ),
    ', variable_features=',
    SUM(
        variance_all > 0
        AND SQRT(variance_all)
            > 0.00000001 * GREATEST(1, ABS(mean_all))
    )
) AS variance_screening_summary
FROM tmp_feature_profile;

SELECT CONCAT(
    'feature=', feature_name,
    ', group=', feature_group,
    ', valid_n=', FORMAT(valid_n, 0),
    ', mean=', FORMAT(mean_all, 8),
    ', variance=', FORMAT(variance_all, 12),
    ', status=',
    CASE
        WHEN COALESCE(variance_all, 0) = 0
            THEN 'constant'
        WHEN SQRT(variance_all)
             <= 0.00000001 * GREATEST(1, ABS(mean_all))
            THEN 'near_constant'
        ELSE 'variable'
    END
) AS constant_feature_details
FROM tmp_feature_profile
WHERE COALESCE(variance_all, 0) = 0
   OR SQRT(variance_all)
      <= 0.00000001 * GREATEST(1, ABS(mean_all))
ORDER BY feature_group, ORDINAL_POSITION;

-- 4.5 Find top 30 most different features b/t illicit and licit
-- use SMD
WITH feature_signal AS (
    SELECT
        *,
        (illicit_mean - licit_mean)
        /
        NULLIF(
            SQRT(
                (illicit_variance + licit_variance) / 2
            ),
            0
        ) AS standardized_mean_difference
    FROM tmp_feature_profile
),
ranked_features AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY ABS(standardized_mean_difference) DESC
        ) AS signal_rank
    FROM feature_signal
    WHERE standardized_mean_difference IS NOT NULL
)
SELECT CONCAT(
    'rank=', signal_rank,
    ', feature=', feature_name,
    ', group=', feature_group,
    ', illicit_n=', FORMAT(illicit_n, 0),
    ', licit_n=', FORMAT(licit_n, 0),
    ', illicit_mean=', FORMAT(illicit_mean, 6),
    ', licit_mean=', FORMAT(licit_mean, 6),
    ', SMD=', FORMAT(standardized_mean_difference, 4),
    ', absolute_SMD=',
    FORMAT(ABS(standardized_mean_difference), 4),
    ', signal_direction=',
    CASE
        WHEN standardized_mean_difference > 0
            THEN 'higher_in_illicit'
        WHEN standardized_mean_difference < 0
            THEN 'lower_in_illicit'
        ELSE 'no_mean_difference'
    END
) AS top_feature_signal
FROM ranked_features
WHERE signal_rank <= 30
ORDER BY signal_rank;

-- 4.6 Compare overall featues between local and aggregate
WITH feature_signal AS (
    SELECT
        *,
        (illicit_mean - licit_mean)
        /
        NULLIF(
            SQRT(
                (illicit_variance + licit_variance) / 2
            ),
            0
        ) AS standardized_mean_difference
    FROM tmp_feature_profile
)
SELECT CONCAT(
    'feature_group=', feature_group,
    ', n_features=', COUNT(*),
    ', constant_features=',
    SUM(COALESCE(variance_all, 0) = 0),
    ', average_absolute_SMD=',
    FORMAT(AVG(ABS(standardized_mean_difference)), 4),
    ', maximum_absolute_SMD=',
    FORMAT(MAX(ABS(standardized_mean_difference)), 4),
    ', features_with_abs_SMD_at_least_0.2=',
    SUM(ABS(standardized_mean_difference) >= 0.2),
    ', features_with_abs_SMD_at_least_0.5=',
    SUM(ABS(standardized_mean_difference) >= 0.5)
) AS feature_group_comparison
FROM feature_signal
GROUP BY feature_group
ORDER BY feature_group;

-- 4.7 Top predictive features over time and temporal feature drift
-- 4.7.1 Select the 10 features with the largest absolute SMD

DROP TEMPORARY TABLE IF EXISTS tmp_top10_features;

CREATE TEMPORARY TABLE tmp_top10_features AS
SELECT
    signal_rank,
    feature_name,
    feature_group,
    standardized_mean_difference
FROM (
    SELECT
        signal_data.*,
        ROW_NUMBER() OVER (
            ORDER BY ABS(standardized_mean_difference) DESC
        ) AS signal_rank
    FROM (
        SELECT
            feature_name,
            feature_group,
            (
                illicit_mean - licit_mean
            )
            /
            NULLIF(
                SQRT(
                    (illicit_variance + licit_variance) / 2
                ),
                0
            ) AS standardized_mean_difference
        FROM tmp_feature_profile
    ) AS signal_data
    WHERE standardized_mean_difference IS NOT NULL
) AS ranked_features
WHERE signal_rank <= 10;

SELECT CONCAT(
    'Top feature selection completed: n_features=',
    COUNT(*)
) AS top_feature_selection_status
FROM tmp_top10_features;

-- 4.7.2 Calculate each Top 10 feature's distribution by time step

SELECT GROUP_CONCAT(
    CONCAT(
        'SELECT ',
        signal_rank,
        ' AS signal_rank, ',
        QUOTE(feature_name),
        ' AS feature_name, ',
        'f.time_step, ',
        'COUNT(f.`', feature_name, '`) AS valid_n, ',
        'AVG(f.`', feature_name, '`) AS mean_value, ',
        'STDDEV_SAMP(f.`', feature_name, '`) AS standard_deviation ',
        'FROM elliptic_project.txs_features AS f ',
        'GROUP BY f.time_step'
    )
    ORDER BY signal_rank
    SEPARATOR ' UNION ALL '
)
INTO @top_feature_time_union
FROM tmp_top10_features;

DROP TEMPORARY TABLE IF EXISTS tmp_top_feature_time;

SET @top_feature_time_sql = CONCAT(
    'CREATE TEMPORARY TABLE tmp_top_feature_time AS ',
    @top_feature_time_union
);

PREPARE top_feature_time_statement
FROM @top_feature_time_sql;

EXECUTE top_feature_time_statement;

DEALLOCATE PREPARE top_feature_time_statement;

SELECT CONCAT(
    'rank=', signal_rank,
    ', feature=', feature_name,
    ', time_step=', time_step,
    ', valid_n=', FORMAT(valid_n, 0),
    ', mean=', FORMAT(mean_value, 6),
    ', standard_deviation=', FORMAT(standard_deviation, 6)
) AS top_feature_time_trend
FROM tmp_top_feature_time
ORDER BY signal_rank, time_step;

-- 4.7.3 Compare candidate training period (1-34)
-- with candidate testing period (35-49)

SELECT GROUP_CONCAT(
    CONCAT(
        'SELECT ',
        signal_rank,
        ' AS signal_rank, ',
        QUOTE(feature_name),
        ' AS feature_name, ',

        'COUNT(CASE WHEN f.time_step <= 34 ',
        'AND f.`', feature_name, '` IS NOT NULL ',
        'THEN 1 END) AS early_n, ',

        'AVG(CASE WHEN f.time_step <= 34 ',
        'THEN f.`', feature_name, '` END) AS early_mean, ',

        'VAR_SAMP(CASE WHEN f.time_step <= 34 ',
        'THEN f.`', feature_name, '` END) AS early_variance, ',

        'COUNT(CASE WHEN f.time_step >= 35 ',
        'AND f.`', feature_name, '` IS NOT NULL ',
        'THEN 1 END) AS late_n, ',

        'AVG(CASE WHEN f.time_step >= 35 ',
        'THEN f.`', feature_name, '` END) AS late_mean, ',

        'VAR_SAMP(CASE WHEN f.time_step >= 35 ',
        'THEN f.`', feature_name, '` END) AS late_variance ',

        'FROM elliptic_project.txs_features AS f'
    )
    ORDER BY signal_rank
    SEPARATOR ' UNION ALL '
)
INTO @top_feature_drift_union
FROM tmp_top10_features;

DROP TEMPORARY TABLE IF EXISTS tmp_top_feature_drift;

SET @top_feature_drift_sql = CONCAT(
    'CREATE TEMPORARY TABLE tmp_top_feature_drift AS ',
    @top_feature_drift_union
);

PREPARE top_feature_drift_statement
FROM @top_feature_drift_sql;

EXECUTE top_feature_drift_statement;

DEALLOCATE PREPARE top_feature_drift_statement;

WITH drift_results AS (
    SELECT
        *,
        (
            late_mean - early_mean
        )
        /
        NULLIF(
            SQRT(
                (early_variance + late_variance) / 2
            ),
            0
        ) AS temporal_drift_smd
    FROM tmp_top_feature_drift
)
SELECT CONCAT(
    'rank=', signal_rank,
    ', feature=', feature_name,
    ', early_period=time_steps_1_to_34',
    ', early_n=', FORMAT(early_n, 0),
    ', early_mean=', FORMAT(early_mean, 6),
    ', late_period=time_steps_35_to_49',
    ', late_n=', FORMAT(late_n, 0),
    ', late_mean=', FORMAT(late_mean, 6),
    ', temporal_drift_SMD=', FORMAT(temporal_drift_smd, 4),
    ', absolute_drift_SMD=',
    FORMAT(ABS(temporal_drift_smd), 4),
    ', direction=',
    CASE
        WHEN temporal_drift_smd > 0 THEN 'higher_in_late_period'
        WHEN temporal_drift_smd < 0 THEN 'lower_in_late_period'
        ELSE 'no_mean_change'
    END
) AS top_feature_temporal_drift
FROM drift_results
ORDER BY ABS(temporal_drift_smd) DESC;

-- 4.7.4 Check whether Illicit-vs-Licit predictive signals
-- remain stable between early and late periods

SET SESSION group_concat_max_len = 1000000;

-- Generate one aggregation query for each Top 10 feature
SELECT GROUP_CONCAT(
    CONCAT(
        'SELECT ',
        signal_rank,
        ' AS signal_rank, ',
        QUOTE(feature_name),
        ' AS feature_name, ',
        QUOTE(feature_group),
        ' AS feature_group, ',

        -- Early-period Illicit statistics
        'COUNT(CASE WHEN f.time_step <= 34 ',
        'AND c.class = 1 ',
        'AND f.`', feature_name, '` IS NOT NULL ',
        'THEN 1 END) AS early_illicit_n, ',

        'AVG(CASE WHEN f.time_step <= 34 ',
        'AND c.class = 1 ',
        'THEN f.`', feature_name, '` END) ',
        'AS early_illicit_mean, ',

        'VAR_SAMP(CASE WHEN f.time_step <= 34 ',
        'AND c.class = 1 ',
        'THEN f.`', feature_name, '` END) ',
        'AS early_illicit_variance, ',

        -- Early-period Licit statistics
        'COUNT(CASE WHEN f.time_step <= 34 ',
        'AND c.class = 2 ',
        'AND f.`', feature_name, '` IS NOT NULL ',
        'THEN 1 END) AS early_licit_n, ',

        'AVG(CASE WHEN f.time_step <= 34 ',
        'AND c.class = 2 ',
        'THEN f.`', feature_name, '` END) ',
        'AS early_licit_mean, ',

        'VAR_SAMP(CASE WHEN f.time_step <= 34 ',
        'AND c.class = 2 ',
        'THEN f.`', feature_name, '` END) ',
        'AS early_licit_variance, ',

        -- Late-period Illicit statistics
        'COUNT(CASE WHEN f.time_step >= 35 ',
        'AND c.class = 1 ',
        'AND f.`', feature_name, '` IS NOT NULL ',
        'THEN 1 END) AS late_illicit_n, ',

        'AVG(CASE WHEN f.time_step >= 35 ',
        'AND c.class = 1 ',
        'THEN f.`', feature_name, '` END) ',
        'AS late_illicit_mean, ',

        'VAR_SAMP(CASE WHEN f.time_step >= 35 ',
        'AND c.class = 1 ',
        'THEN f.`', feature_name, '` END) ',
        'AS late_illicit_variance, ',

        -- Late-period Licit statistics
        'COUNT(CASE WHEN f.time_step >= 35 ',
        'AND c.class = 2 ',
        'AND f.`', feature_name, '` IS NOT NULL ',
        'THEN 1 END) AS late_licit_n, ',

        'AVG(CASE WHEN f.time_step >= 35 ',
        'AND c.class = 2 ',
        'THEN f.`', feature_name, '` END) ',
        'AS late_licit_mean, ',

        'VAR_SAMP(CASE WHEN f.time_step >= 35 ',
        'AND c.class = 2 ',
        'THEN f.`', feature_name, '` END) ',
        'AS late_licit_variance ',

        'FROM elliptic_project.txs_features AS f ',
        'INNER JOIN elliptic_project.txs_classes AS c ',
        'ON f.tx_id = c.txId'
    )
    ORDER BY signal_rank
    SEPARATOR ' UNION ALL '
)
INTO @signal_stability_union
FROM tmp_top10_features;


DROP TEMPORARY TABLE IF EXISTS tmp_signal_stability_statistics;

SET @signal_stability_sql = CONCAT(
    'CREATE TEMPORARY TABLE tmp_signal_stability_statistics AS ',
    @signal_stability_union
);

PREPARE signal_stability_statement
FROM @signal_stability_sql;

EXECUTE signal_stability_statement;

DEALLOCATE PREPARE signal_stability_statement;


-- Calculate Early and Late Illicit-vs-Licit SMD
DROP TEMPORARY TABLE IF EXISTS tmp_signal_stability_smd;

CREATE TEMPORARY TABLE tmp_signal_stability_smd AS
SELECT
    signal_rank,
    feature_name,
    feature_group,

    early_illicit_n,
    early_licit_n,
    early_illicit_mean,
    early_licit_mean,

    (
        early_illicit_mean - early_licit_mean
    )
    /
    NULLIF(
        SQRT(
            (
                early_illicit_variance
                + early_licit_variance
            ) / 2
        ),
        0
    ) AS early_illicit_vs_licit_smd,

    late_illicit_n,
    late_licit_n,
    late_illicit_mean,
    late_licit_mean,

    (
        late_illicit_mean - late_licit_mean
    )
    /
    NULLIF(
        SQRT(
            (
                late_illicit_variance
                + late_licit_variance
            ) / 2
        ),
        0
    ) AS late_illicit_vs_licit_smd

FROM tmp_signal_stability_statistics;


-- Confirm that all Top 10 features produced valid comparisons
SELECT CONCAT(
    'Predictive signal stability table created: ',
    'features_checked=', COUNT(*),
    ', valid_early_and_late_SMD=',
    SUM(
        early_illicit_vs_licit_smd IS NOT NULL
        AND late_illicit_vs_licit_smd IS NOT NULL
    ),
    ', invalid_comparisons=',
    SUM(
        early_illicit_vs_licit_smd IS NULL
        OR late_illicit_vs_licit_smd IS NULL
    )
) AS signal_stability_status
FROM tmp_signal_stability_smd;


-- Readable final output
SELECT CONCAT(
    'rank=', signal_rank,
    ', feature=', feature_name,
    ', group=', feature_group,

    ', early_period=time_steps_1_to_34',
    ', early_illicit_n=', FORMAT(early_illicit_n, 0),
    ', early_licit_n=', FORMAT(early_licit_n, 0),
    ', early_Illicit_vs_Licit_SMD=',
    FORMAT(early_illicit_vs_licit_smd, 4),

    ', late_period=time_steps_35_to_49',
    ', late_illicit_n=', FORMAT(late_illicit_n, 0),
    ', late_licit_n=', FORMAT(late_licit_n, 0),
    ', late_Illicit_vs_Licit_SMD=',
    FORMAT(late_illicit_vs_licit_smd, 4),

    ', absolute_signal_change_late_minus_early=',
    FORMAT(
        ABS(late_illicit_vs_licit_smd)
        - ABS(early_illicit_vs_licit_smd),
        4
    ),

    ', direction_changed=',
    CASE
        WHEN early_illicit_vs_licit_smd
             * late_illicit_vs_licit_smd < 0
            THEN 'yes'
        ELSE 'no'
    END,

    ', signal_stability_assessment=',
    CASE
        WHEN early_illicit_vs_licit_smd
             * late_illicit_vs_licit_smd < 0
            THEN 'direction_reversal'

        WHEN ABS(late_illicit_vs_licit_smd)
             - ABS(early_illicit_vs_licit_smd) <= -0.20
            THEN 'substantially_weaker_in_late_period'

        WHEN ABS(late_illicit_vs_licit_smd)
             - ABS(early_illicit_vs_licit_smd) >= 0.20
            THEN 'substantially_stronger_in_late_period'

        ELSE 'similar_signal_strength'
    END
) AS early_vs_late_predictive_signal
FROM tmp_signal_stability_smd
WHERE early_illicit_vs_licit_smd IS NOT NULL
  AND late_illicit_vs_licit_smd IS NOT NULL
ORDER BY signal_rank;

-- 4.8 Compare all 165 Local and Aggregate features
-- between Known and Unknown transactions

SELECT GROUP_CONCAT(
    CONCAT(
        QUOTE(feature_name), ', JSON_OBJECT(',

        '''known_n'', ',
        'COUNT(CASE WHEN c.class IN (1, 2) ',
        'AND f.`', feature_name, '` IS NOT NULL THEN 1 END), ',

        '''known_mean'', ',
        'AVG(CASE WHEN c.class IN (1, 2) ',
        'THEN f.`', feature_name, '` END), ',

        '''known_variance'', ',
        'VAR_SAMP(CASE WHEN c.class IN (1, 2) ',
        'THEN f.`', feature_name, '` END), ',

        '''unknown_n'', ',
        'COUNT(CASE WHEN c.class = 3 ',
        'AND f.`', feature_name, '` IS NOT NULL THEN 1 END), ',

        '''unknown_mean'', ',
        'AVG(CASE WHEN c.class = 3 ',
        'THEN f.`', feature_name, '` END), ',

        '''unknown_variance'', ',
        'VAR_SAMP(CASE WHEN c.class = 3 ',
        'THEN f.`', feature_name, '` END)',

        ')'
    )
    ORDER BY ORDINAL_POSITION
    SEPARATOR ', '
)
INTO @known_unknown_json_pairs
FROM tmp_feature_map;

SET @known_unknown_sql = CONCAT(
    'SELECT JSON_OBJECT(',
    @known_unknown_json_pairs,
    ') INTO @known_unknown_json ',
    'FROM elliptic_project.txs_features AS f ',
    'INNER JOIN elliptic_project.txs_classes AS c ',
    'ON f.tx_id = c.txId'
);

PREPARE known_unknown_statement
FROM @known_unknown_sql;

EXECUTE known_unknown_statement;

DEALLOCATE PREPARE known_unknown_statement;


DROP TEMPORARY TABLE IF EXISTS tmp_known_unknown_profile;

CREATE TEMPORARY TABLE tmp_known_unknown_profile AS
SELECT
    m.feature_name,
    m.feature_group,
    m.ORDINAL_POSITION,

    CAST(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                @known_unknown_json,
                CONCAT('$."', m.feature_name, '".known_n')
            )
        ) AS UNSIGNED
    ) AS known_n,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @known_unknown_json,
            CONCAT('$."', m.feature_name, '".known_mean')
        )
    ) * 1.0 AS known_mean,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @known_unknown_json,
            CONCAT('$."', m.feature_name, '".known_variance')
        )
    ) * 1.0 AS known_variance,

    CAST(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                @known_unknown_json,
                CONCAT('$."', m.feature_name, '".unknown_n')
            )
        ) AS UNSIGNED
    ) AS unknown_n,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @known_unknown_json,
            CONCAT('$."', m.feature_name, '".unknown_mean')
        )
    ) * 1.0 AS unknown_mean,

    JSON_UNQUOTE(
        JSON_EXTRACT(
            @known_unknown_json,
            CONCAT('$."', m.feature_name, '".unknown_variance')
        )
    ) * 1.0 AS unknown_variance

FROM tmp_feature_map AS m;


WITH distribution_shift AS (
    SELECT
        *,
        (
            unknown_mean - known_mean
        )
        /
        NULLIF(
            SQRT(
                (known_variance + unknown_variance) / 2
            ),
            0
        ) AS known_unknown_smd
    FROM tmp_known_unknown_profile
),
ranked_shift AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            ORDER BY ABS(known_unknown_smd) DESC
        ) AS shift_rank
    FROM distribution_shift
    WHERE known_unknown_smd IS NOT NULL
)
SELECT CONCAT(
    'rank=', shift_rank,
    ', feature=', feature_name,
    ', group=', feature_group,
    ', known_n=', FORMAT(known_n, 0),
    ', unknown_n=', FORMAT(unknown_n, 0),
    ', known_mean=', FORMAT(known_mean, 6),
    ', unknown_mean=', FORMAT(unknown_mean, 6),
    ', mean_difference_unknown_minus_known=',
    FORMAT(unknown_mean - known_mean, 6),
    ', Known_vs_Unknown_SMD=',
    FORMAT(known_unknown_smd, 4),
    ', absolute_SMD=',
    FORMAT(ABS(known_unknown_smd), 4),
    ', direction=',
    CASE
        WHEN known_unknown_smd > 0 THEN 'higher_in_unknown'
        WHEN known_unknown_smd < 0 THEN 'lower_in_unknown'
        ELSE 'no_mean_difference'
    END
) AS top_known_unknown_feature_shift
FROM ranked_shift
WHERE shift_rank <= 20
ORDER BY shift_rank;

-- 4.8.2 Compare Known and Unknown transactions
-- within the same time step for the Top shifted features

SET SESSION group_concat_max_len = 1000000;

-- Change this value from 5 to 10 if Top 10 is required
SET @within_time_top_n = 5;


-- Select features with the largest overall Known-vs-Unknown SMD
DROP TEMPORARY TABLE IF EXISTS tmp_top_known_unknown_features;

CREATE TEMPORARY TABLE tmp_top_known_unknown_features AS
SELECT
    shift_rank,
    feature_name,
    feature_group,
    ordinal_position,
    overall_known_unknown_smd
FROM (
    SELECT
        shift_data.*,
        ROW_NUMBER() OVER (
            ORDER BY
                ABS(overall_known_unknown_smd) DESC,
                ordinal_position
        ) AS shift_rank
    FROM (
        SELECT
            feature_name,
            feature_group,
            ordinal_position,

            (
                unknown_mean - known_mean
            )
            /
            NULLIF(
                SQRT(
                    (
                        known_variance
                        + unknown_variance
                    ) / 2
                ),
                0
            ) AS overall_known_unknown_smd

        FROM tmp_known_unknown_profile
    ) AS shift_data
    WHERE overall_known_unknown_smd IS NOT NULL
) AS ranked_shift
WHERE shift_rank <= @within_time_top_n;


SELECT CONCAT(
    'Within-time-step Known-vs-Unknown feature selection: ',
    'features_selected=', COUNT(*)
) AS within_time_feature_selection_status
FROM tmp_top_known_unknown_features;


-- Generate one time-step aggregation query for each selected feature
SELECT GROUP_CONCAT(
    CONCAT(
        'SELECT ',
        shift_rank,
        ' AS shift_rank, ',
        QUOTE(feature_name),
        ' AS feature_name, ',
        QUOTE(feature_group),
        ' AS feature_group, ',
        'f.time_step, ',

        -- Known group
        'COUNT(CASE WHEN c.class IN (1, 2) ',
        'AND f.`', feature_name, '` IS NOT NULL ',
        'THEN 1 END) AS known_n, ',

        'AVG(CASE WHEN c.class IN (1, 2) ',
        'THEN f.`', feature_name, '` END) ',
        'AS known_mean, ',

        'VAR_SAMP(CASE WHEN c.class IN (1, 2) ',
        'THEN f.`', feature_name, '` END) ',
        'AS known_variance, ',

        -- Unknown group
        'COUNT(CASE WHEN c.class = 3 ',
        'AND f.`', feature_name, '` IS NOT NULL ',
        'THEN 1 END) AS unknown_n, ',

        'AVG(CASE WHEN c.class = 3 ',
        'THEN f.`', feature_name, '` END) ',
        'AS unknown_mean, ',

        'VAR_SAMP(CASE WHEN c.class = 3 ',
        'THEN f.`', feature_name, '` END) ',
        'AS unknown_variance ',

        'FROM elliptic_project.txs_features AS f ',
        'INNER JOIN elliptic_project.txs_classes AS c ',
        'ON f.tx_id = c.txId ',
        'GROUP BY f.time_step'
    )
    ORDER BY shift_rank
    SEPARATOR ' UNION ALL '
)
INTO @within_time_known_unknown_union
FROM tmp_top_known_unknown_features;


DROP TEMPORARY TABLE IF EXISTS tmp_within_time_known_unknown_statistics;

SET @within_time_known_unknown_sql = CONCAT(
    'CREATE TEMPORARY TABLE ',
    'tmp_within_time_known_unknown_statistics AS ',
    @within_time_known_unknown_union
);

PREPARE within_time_known_unknown_statement
FROM @within_time_known_unknown_sql;

EXECUTE within_time_known_unknown_statement;

DEALLOCATE PREPARE within_time_known_unknown_statement;


-- Calculate Known-vs-Unknown SMD inside each time step
DROP TEMPORARY TABLE IF EXISTS tmp_within_time_known_unknown_smd;

CREATE TEMPORARY TABLE tmp_within_time_known_unknown_smd AS
SELECT
    shift_rank,
    feature_name,
    feature_group,
    time_step,

    known_n,
    unknown_n,
    known_mean,
    unknown_mean,

    (
        unknown_mean - known_mean
    )
    /
    NULLIF(
        SQRT(
            (
                known_variance
                + unknown_variance
            ) / 2
        ),
        0
    ) AS within_time_known_unknown_smd

FROM tmp_within_time_known_unknown_statistics;


-- Summary: one readable row per feature
SELECT CONCAT(
    'overall_rank=', selected.shift_rank,
    ', feature=', selected.feature_name,
    ', group=', selected.feature_group,

    ', overall_all_time_SMD=',
    FORMAT(selected.overall_known_unknown_smd, 4),

    ', valid_time_steps=',
    COUNT(results.within_time_known_unknown_smd),

    ', mean_absolute_within_time_SMD=',
    FORMAT(
        AVG(
            ABS(results.within_time_known_unknown_smd)
        ),
        4
    ),

    ', maximum_absolute_within_time_SMD=',
    FORMAT(
        MAX(
            ABS(results.within_time_known_unknown_smd)
        ),
        4
    ),

    ', time_steps_with_abs_SMD_at_least_0.20=',
    COALESCE(
        SUM(
            ABS(results.within_time_known_unknown_smd)
            >= 0.20
        ),
        0
    ),

    ', time_steps_with_abs_SMD_at_least_0.50=',
    COALESCE(
        SUM(
            ABS(results.within_time_known_unknown_smd)
            >= 0.50
        ),
        0
    ),

    ', unknown_higher_time_steps=',
    COALESCE(
        SUM(
            results.within_time_known_unknown_smd > 0
        ),
        0
    ),

    ', unknown_lower_time_steps=',
    COALESCE(
        SUM(
            results.within_time_known_unknown_smd < 0
        ),
        0
    )
) AS within_time_known_unknown_summary

FROM tmp_top_known_unknown_features AS selected

LEFT JOIN tmp_within_time_known_unknown_smd AS results
    ON selected.feature_name = results.feature_name

GROUP BY
    selected.shift_rank,
    selected.feature_name,
    selected.feature_group,
    selected.overall_known_unknown_smd

ORDER BY selected.shift_rank;


-- Detailed output: one row per feature per time step
SELECT CONCAT(
    'overall_rank=', shift_rank,
    ', feature=', feature_name,
    ', group=', feature_group,
    ', time_step=', time_step,

    ', known_n=', FORMAT(known_n, 0),
    ', unknown_n=', FORMAT(unknown_n, 0),

    ', known_mean=', FORMAT(known_mean, 6),
    ', unknown_mean=', FORMAT(unknown_mean, 6),

    ', within_time_Known_vs_Unknown_SMD=',
    FORMAT(within_time_known_unknown_smd, 4),

    ', absolute_SMD=',
    FORMAT(
        ABS(within_time_known_unknown_smd),
        4
    ),

    ', direction=',
    CASE
        WHEN within_time_known_unknown_smd > 0
            THEN 'higher_in_unknown'
        WHEN within_time_known_unknown_smd < 0
            THEN 'lower_in_unknown'
        ELSE 'no_mean_difference'
    END
) AS within_time_known_unknown_detail

FROM tmp_within_time_known_unknown_smd
WHERE within_time_known_unknown_smd IS NOT NULL
ORDER BY shift_rank, time_step;

-- 4.9 Identify highly correlated pairs among Top 30 predictive features

DROP TEMPORARY TABLE IF EXISTS tmp_top30_features;

CREATE TEMPORARY TABLE tmp_top30_features AS
SELECT
    signal_rank,
    feature_name,
    feature_group,
    standardized_mean_difference
FROM (
    SELECT
        signal_data.*,
        ROW_NUMBER() OVER (
            ORDER BY ABS(standardized_mean_difference) DESC
        ) AS signal_rank
    FROM (
        SELECT
            feature_name,
            feature_group,
            (
                illicit_mean - licit_mean
            )
            /
            NULLIF(
                SQRT(
                    (illicit_variance + licit_variance) / 2
                ),
                0
            ) AS standardized_mean_difference
        FROM tmp_feature_profile
    ) AS signal_data
    WHERE standardized_mean_difference IS NOT NULL
) AS ranked_features
WHERE signal_rank <= 30;


-- Create a copy because MySQL cannot self-join
-- the same temporary table twice

DROP TEMPORARY TABLE IF EXISTS tmp_top30_features_copy;

CREATE TEMPORARY TABLE tmp_top30_features_copy AS
SELECT *
FROM tmp_top30_features;


DROP TEMPORARY TABLE IF EXISTS tmp_top_feature_pairs;

CREATE TEMPORARY TABLE tmp_top_feature_pairs AS
SELECT
    ROW_NUMBER() OVER (
        ORDER BY a.signal_rank, b.signal_rank
    ) AS pair_id,

    a.signal_rank AS feature_1_rank,
    a.feature_name AS feature_1,

    b.signal_rank AS feature_2_rank,
    b.feature_name AS feature_2

FROM tmp_top30_features AS a

INNER JOIN tmp_top30_features_copy AS b
    ON a.signal_rank < b.signal_rank;


SELECT CONCAT(
    'Feature pair table created: n_features=30',
    ', expected_pairs=435',
    ', actual_pairs=',
    COUNT(*)
) AS feature_pair_status
FROM tmp_top_feature_pairs;


SELECT GROUP_CONCAT(
    CONCAT(
        QUOTE(CAST(pair_id AS CHAR)),
        ', SUM(f.`',
        feature_1,
        '` * f.`',
        feature_2,
        '`)'
    )
    ORDER BY pair_id
    SEPARATOR ', '
)
INTO @correlation_product_pairs
FROM tmp_top_feature_pairs;

SET @top_correlation_sql = CONCAT(
    'SELECT JSON_OBJECT(',
    @correlation_product_pairs,
    ') INTO @correlation_product_json ',
    'FROM elliptic_project.txs_features AS f ',
    'INNER JOIN elliptic_project.txs_classes AS c ',
    'ON f.tx_id = c.txId ',
    'WHERE c.class IN (1, 2)'
);

PREPARE top_correlation_statement
FROM @top_correlation_sql;

EXECUTE top_correlation_statement;

DEALLOCATE PREPARE top_correlation_statement;


SELECT COUNT(*)
INTO @known_correlation_n
FROM txs_classes
WHERE class IN (1, 2);


-- Create a copy because MySQL cannot join
-- the same temporary profile table twice

DROP TEMPORARY TABLE IF EXISTS tmp_feature_profile_copy;

CREATE TEMPORARY TABLE tmp_feature_profile_copy AS
SELECT *
FROM tmp_feature_profile;


DROP TEMPORARY TABLE IF EXISTS tmp_top_feature_correlations;

CREATE TEMPORARY TABLE tmp_top_feature_correlations AS
SELECT
    pairs.pair_id,
    pairs.feature_1_rank,
    pairs.feature_1,
    pairs.feature_2_rank,
    pairs.feature_2,

    (
        (
            JSON_UNQUOTE(
                JSON_EXTRACT(
                    @correlation_product_json,
                    CONCAT('$."', pairs.pair_id, '"')
                )
            ) * 1.0
            -
            @known_correlation_n
            * profile_1.mean_all
            * profile_2.mean_all
        )
        /
        NULLIF(@known_correlation_n - 1, 0)
    )
    /
    NULLIF(
        SQRT(
            profile_1.variance_all
            * profile_2.variance_all
        ),
        0
    ) AS correlation_value

FROM tmp_top_feature_pairs AS pairs

INNER JOIN tmp_feature_profile AS profile_1
    ON pairs.feature_1 = profile_1.feature_name

INNER JOIN tmp_feature_profile_copy AS profile_2
    ON pairs.feature_2 = profile_2.feature_name;

SELECT CONCAT(
    'Correlation table created: expected_pairs=435',
    ', actual_pairs=', COUNT(*),
    ', null_correlations=',
    SUM(correlation_value IS NULL)
) AS correlation_table_status
FROM tmp_top_feature_correlations;


SELECT CONCAT(
    'Top feature correlation screening: pairs_checked=',
    COUNT(*),
    ', pairs_with_absolute_correlation_at_least_0.90=',
    SUM(ABS(correlation_value) >= 0.90)
) AS correlation_screening_summary
FROM tmp_top_feature_correlations;


SELECT CONCAT(
    'feature_1_rank=', feature_1_rank,
    ', feature_1=', feature_1,
    ', feature_2_rank=', feature_2_rank,
    ', feature_2=', feature_2,
    ', Pearson_correlation=',
    FORMAT(correlation_value, 4),
    ', absolute_correlation=',
    FORMAT(ABS(correlation_value), 4),
    ', relationship=',
    CASE
        WHEN correlation_value > 0 THEN 'positive'
        WHEN correlation_value < 0 THEN 'negative'
        ELSE 'none'
    END
) AS highly_correlated_feature_pairs
FROM tmp_top_feature_correlations
WHERE ABS(correlation_value) >= 0.90
ORDER BY ABS(correlation_value) DESC;

-- ==================== 5. performance evaluation for 1%, 5%, and 10% review budget for known labels ================
WITH time_statistics AS (
    SELECT
        f.time_step,

        SUM(
            CASE WHEN c.class IN (1, 2)
                 THEN 1 ELSE 0 END
        ) AS known_label_n,

        SUM(
            CASE WHEN c.class = 1
                 THEN 1 ELSE 0 END
        ) AS illicit_n

    FROM txs_features AS f
    INNER JOIN txs_classes AS c
        ON f.tx_id = c.txId
    GROUP BY f.time_step
),

evaluation_scopes AS (
    SELECT
        1 AS scope_order,
        time_step,
        CONCAT('time_step=', time_step) AS evaluation_scope,
        known_label_n,
        illicit_n
    FROM time_statistics

    UNION ALL

    SELECT
        0 AS scope_order,
        NULL AS time_step,
        'all_time_steps' AS evaluation_scope,
        SUM(known_label_n) AS known_label_n,
        SUM(illicit_n) AS illicit_n
    FROM time_statistics
),

review_budgets AS (
    SELECT
        *,
        '1_percent' AS budget_name,
        CEIL(known_label_n * 0.01) AS review_n
    FROM evaluation_scopes

    UNION ALL

    SELECT
        *,
        '5_percent',
        CEIL(known_label_n * 0.05)
    FROM evaluation_scopes

    UNION ALL

    SELECT
        *,
        '10_percent',
        CEIL(known_label_n * 0.10)
    FROM evaluation_scopes

    UNION ALL

    SELECT
        *,
        'fixed_100',
        LEAST(100, known_label_n)
    FROM evaluation_scopes
),

baseline_results AS (
    SELECT
        scope_order,
        time_step,
        evaluation_scope,
        budget_name,
        known_label_n,
        illicit_n,
        review_n,

        review_n *
        illicit_n
        / NULLIF(known_label_n, 0)
        AS random_expected_illicit,

        LEAST(review_n, illicit_n)
        AS perfect_max_illicit

    FROM review_budgets
)

SELECT CONCAT(
    'evaluation_scope=', evaluation_scope,

    ', budget=', budget_name,

    ', known_label_n=',
    FORMAT(known_label_n, 0),

    ', total_illicit_n=',
    FORMAT(illicit_n, 0),

    ', review_n=',
    FORMAT(review_n, 0),

    ', random_expected_illicit=',
    ROUND(random_expected_illicit, 2),

    ', random_expected_capture_rate=',
    ROUND(
        100.0 * random_expected_illicit
        / NULLIF(illicit_n, 0),
        2
    ),
    '%',

    ', random_expected_precision=',
    ROUND(
        100.0 * random_expected_illicit
        / NULLIF(review_n, 0),
        2
    ),
    '%',

    ', perfect_max_illicit=',
    FORMAT(perfect_max_illicit, 0),

    ', perfect_max_capture_rate=',
    ROUND(
        100.0 * perfect_max_illicit
        / NULLIF(illicit_n, 0),
        2
    ),
    '%',

    ', perfect_max_precision=',
    ROUND(
        100.0 * perfect_max_illicit
        / NULLIF(review_n, 0),
        2
    ),
    '%'
) AS review_budget_baseline

FROM baseline_results

ORDER BY
    scope_order,
    time_step,
    FIELD(
        budget_name,
        '1_percent',
        '5_percent',
        '10_percent',
        'fixed_100'
    );

-- 5.2 Aggregate Random and Perfect baselines
-- when the review budget is applied separately within each time step

WITH time_statistics AS (
    SELECT
        f.time_step,

        SUM(
            CASE WHEN c.class IN (1, 2)
                 THEN 1 ELSE 0 END
        ) AS known_label_n,

        SUM(
            CASE WHEN c.class = 1
                 THEN 1 ELSE 0 END
        ) AS illicit_n

    FROM txs_features AS f
    INNER JOIN txs_classes AS c
        ON f.tx_id = c.txId
    GROUP BY f.time_step
),

budget_config AS (
    SELECT
        1 AS budget_order,
        '1_percent_per_time_step' AS budget_name,
        0.01 AS budget_rate,
        NULL AS fixed_review_n

    UNION ALL

    SELECT
        2,
        '5_percent_per_time_step',
        0.05,
        NULL

    UNION ALL

    SELECT
        3,
        '10_percent_per_time_step',
        0.10,
        NULL

    UNION ALL

    SELECT
        4,
        'fixed_100_per_time_step',
        NULL,
        100
),

per_time_budget AS (
    SELECT
        t.time_step,
        t.known_label_n,
        t.illicit_n,
        b.budget_order,
        b.budget_name,

        CASE
            WHEN b.budget_rate IS NOT NULL
                THEN CEIL(
                    t.known_label_n * b.budget_rate
                )
            ELSE LEAST(
                b.fixed_review_n,
                t.known_label_n
            )
        END AS review_n

    FROM time_statistics AS t
    CROSS JOIN budget_config AS b
),

per_time_baseline AS (
    SELECT
        *,
        review_n * illicit_n
        / NULLIF(known_label_n, 0)
        AS random_expected_illicit,

        LEAST(review_n, illicit_n)
        AS perfect_max_illicit

    FROM per_time_budget
),

aggregated_baseline AS (
    SELECT
        budget_order,
        budget_name,
        COUNT(*) AS time_steps_evaluated,
        SUM(known_label_n) AS total_known_label_n,
        SUM(illicit_n) AS total_illicit_n,
        SUM(review_n) AS total_review_n,
        SUM(random_expected_illicit)
            AS random_expected_illicit,
        SUM(perfect_max_illicit)
            AS perfect_max_illicit

    FROM per_time_baseline
    GROUP BY budget_order, budget_name
)

SELECT CONCAT(
    'budget_policy=', budget_name,
    ', time_steps_evaluated=',
    time_steps_evaluated,
    ', total_known_label_n=',
    FORMAT(total_known_label_n, 0),
    ', total_illicit_n=',
    FORMAT(total_illicit_n, 0),
    ', total_review_n=',
    FORMAT(total_review_n, 0),

    ', random_expected_illicit=',
    ROUND(random_expected_illicit, 2),

    ', random_expected_capture_rate=',
    ROUND(
        100.0 * random_expected_illicit
        / NULLIF(total_illicit_n, 0),
        2
    ),
    '%',

    ', random_expected_precision=',
    ROUND(
        100.0 * random_expected_illicit
        / NULLIF(total_review_n, 0),
        2
    ),
    '%',

    ', perfect_max_illicit=',
    FORMAT(perfect_max_illicit, 0),

    ', perfect_max_capture_rate=',
    ROUND(
        100.0 * perfect_max_illicit
        / NULLIF(total_illicit_n, 0),
        2
    ),
    '%',

    ', perfect_max_precision=',
    ROUND(
        100.0 * perfect_max_illicit
        / NULLIF(total_review_n, 0),
        2
    ),
    '%'
) AS per_time_budget_aggregate_baseline

FROM aggregated_baseline
ORDER BY budget_order;
