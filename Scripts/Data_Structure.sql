CREATE DATABASE IF NOT EXISTS elliptic_project;
USE elliptic_project;
SELECT DATABASE();

USE elliptic_project;

CREATE TABLE IF NOT EXISTS txs_classes (
    txId BIGINT,
    class TINYINT
);

CREATE TABLE IF NOT EXISTS txs_edges (
    txId1 BIGINT,
    txId2 BIGINT
);

USE elliptic_project;

CREATE TABLE txs_features (
    tx_id BIGINT,
    time_step TINYINT UNSIGNED,

    local_feature_1 DOUBLE, local_feature_2 DOUBLE, local_feature_3 DOUBLE,
    local_feature_4 DOUBLE, local_feature_5 DOUBLE, local_feature_6 DOUBLE,
    local_feature_7 DOUBLE, local_feature_8 DOUBLE, local_feature_9 DOUBLE,
    local_feature_10 DOUBLE, local_feature_11 DOUBLE, local_feature_12 DOUBLE,
    local_feature_13 DOUBLE, local_feature_14 DOUBLE, local_feature_15 DOUBLE,
    local_feature_16 DOUBLE, local_feature_17 DOUBLE, local_feature_18 DOUBLE,
    local_feature_19 DOUBLE, local_feature_20 DOUBLE, local_feature_21 DOUBLE,
    local_feature_22 DOUBLE, local_feature_23 DOUBLE, local_feature_24 DOUBLE,
    local_feature_25 DOUBLE, local_feature_26 DOUBLE, local_feature_27 DOUBLE,
    local_feature_28 DOUBLE, local_feature_29 DOUBLE, local_feature_30 DOUBLE,
    local_feature_31 DOUBLE, local_feature_32 DOUBLE, local_feature_33 DOUBLE,
    local_feature_34 DOUBLE, local_feature_35 DOUBLE, local_feature_36 DOUBLE,
    local_feature_37 DOUBLE, local_feature_38 DOUBLE, local_feature_39 DOUBLE,
    local_feature_40 DOUBLE, local_feature_41 DOUBLE, local_feature_42 DOUBLE,
    local_feature_43 DOUBLE, local_feature_44 DOUBLE, local_feature_45 DOUBLE,
    local_feature_46 DOUBLE, local_feature_47 DOUBLE, local_feature_48 DOUBLE,
    local_feature_49 DOUBLE, local_feature_50 DOUBLE, local_feature_51 DOUBLE,
    local_feature_52 DOUBLE, local_feature_53 DOUBLE, local_feature_54 DOUBLE,
    local_feature_55 DOUBLE, local_feature_56 DOUBLE, local_feature_57 DOUBLE,
    local_feature_58 DOUBLE, local_feature_59 DOUBLE, local_feature_60 DOUBLE,
    local_feature_61 DOUBLE, local_feature_62 DOUBLE, local_feature_63 DOUBLE,
    local_feature_64 DOUBLE, local_feature_65 DOUBLE, local_feature_66 DOUBLE,
    local_feature_67 DOUBLE, local_feature_68 DOUBLE, local_feature_69 DOUBLE,
    local_feature_70 DOUBLE, local_feature_71 DOUBLE, local_feature_72 DOUBLE,
    local_feature_73 DOUBLE, local_feature_74 DOUBLE, local_feature_75 DOUBLE,
    local_feature_76 DOUBLE, local_feature_77 DOUBLE, local_feature_78 DOUBLE,
    local_feature_79 DOUBLE, local_feature_80 DOUBLE, local_feature_81 DOUBLE,
    local_feature_82 DOUBLE, local_feature_83 DOUBLE, local_feature_84 DOUBLE,
    local_feature_85 DOUBLE, local_feature_86 DOUBLE, local_feature_87 DOUBLE,
    local_feature_88 DOUBLE, local_feature_89 DOUBLE, local_feature_90 DOUBLE,
    local_feature_91 DOUBLE, local_feature_92 DOUBLE, local_feature_93 DOUBLE,

    aggregate_feature_1 DOUBLE, aggregate_feature_2 DOUBLE, aggregate_feature_3 DOUBLE,
    aggregate_feature_4 DOUBLE, aggregate_feature_5 DOUBLE, aggregate_feature_6 DOUBLE,
    aggregate_feature_7 DOUBLE, aggregate_feature_8 DOUBLE, aggregate_feature_9 DOUBLE,
    aggregate_feature_10 DOUBLE, aggregate_feature_11 DOUBLE, aggregate_feature_12 DOUBLE,
    aggregate_feature_13 DOUBLE, aggregate_feature_14 DOUBLE, aggregate_feature_15 DOUBLE,
    aggregate_feature_16 DOUBLE, aggregate_feature_17 DOUBLE, aggregate_feature_18 DOUBLE,
    aggregate_feature_19 DOUBLE, aggregate_feature_20 DOUBLE, aggregate_feature_21 DOUBLE,
    aggregate_feature_22 DOUBLE, aggregate_feature_23 DOUBLE, aggregate_feature_24 DOUBLE,
    aggregate_feature_25 DOUBLE, aggregate_feature_26 DOUBLE, aggregate_feature_27 DOUBLE,
    aggregate_feature_28 DOUBLE, aggregate_feature_29 DOUBLE, aggregate_feature_30 DOUBLE,
    aggregate_feature_31 DOUBLE, aggregate_feature_32 DOUBLE, aggregate_feature_33 DOUBLE,
    aggregate_feature_34 DOUBLE, aggregate_feature_35 DOUBLE, aggregate_feature_36 DOUBLE,
    aggregate_feature_37 DOUBLE, aggregate_feature_38 DOUBLE, aggregate_feature_39 DOUBLE,
    aggregate_feature_40 DOUBLE, aggregate_feature_41 DOUBLE, aggregate_feature_42 DOUBLE,
    aggregate_feature_43 DOUBLE, aggregate_feature_44 DOUBLE, aggregate_feature_45 DOUBLE,
    aggregate_feature_46 DOUBLE, aggregate_feature_47 DOUBLE, aggregate_feature_48 DOUBLE,
    aggregate_feature_49 DOUBLE, aggregate_feature_50 DOUBLE, aggregate_feature_51 DOUBLE,
    aggregate_feature_52 DOUBLE, aggregate_feature_53 DOUBLE, aggregate_feature_54 DOUBLE,
    aggregate_feature_55 DOUBLE, aggregate_feature_56 DOUBLE, aggregate_feature_57 DOUBLE,
    aggregate_feature_58 DOUBLE, aggregate_feature_59 DOUBLE, aggregate_feature_60 DOUBLE,
    aggregate_feature_61 DOUBLE, aggregate_feature_62 DOUBLE, aggregate_feature_63 DOUBLE,
    aggregate_feature_64 DOUBLE, aggregate_feature_65 DOUBLE, aggregate_feature_66 DOUBLE,
    aggregate_feature_67 DOUBLE, aggregate_feature_68 DOUBLE, aggregate_feature_69 DOUBLE,
    aggregate_feature_70 DOUBLE, aggregate_feature_71 DOUBLE, aggregate_feature_72 DOUBLE,

    in_txs_degree INT UNSIGNED,
    out_txs_degree INT UNSIGNED,
    total_BTC DECIMAL(20,8),
    fees DECIMAL(20,8),
    size INT UNSIGNED,
    num_input_addresses INT UNSIGNED,
    num_output_addresses INT UNSIGNED,
    in_BTC_min DECIMAL(20,8),
    in_BTC_max DECIMAL(20,8),
    in_BTC_mean DECIMAL(20,8),
    in_BTC_median DECIMAL(20,8),
    in_BTC_total DECIMAL(20,8),
    out_BTC_min DECIMAL(20,8),
    out_BTC_max DECIMAL(20,8),
    out_BTC_mean DECIMAL(20,8),
    out_BTC_median DECIMAL(20,8),
    out_BTC_total DECIMAL(20,8)
);

SELECT
    table_name,
    COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'elliptic_project'
  AND table_name IN ('txs_classes', 'txs_edges', 'txs_features')
GROUP BY table_name
ORDER BY table_name;



SELECT
    TABLE_NAME,
    COLUMN_NAME,
    CONSTRAINT_NAME,
    REFERENCED_TABLE_NAME,
    REFERENCED_COLUMN_NAME
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'elliptic_project'
  AND (
      CONSTRAINT_NAME = 'PRIMARY'
      OR REFERENCED_TABLE_NAME IS NOT NULL
  )
ORDER BY TABLE_NAME, CONSTRAINT_NAME, ORDINAL_POSITION;