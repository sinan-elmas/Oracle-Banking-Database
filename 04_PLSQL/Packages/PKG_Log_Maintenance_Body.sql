-- ============================================================================
-- Package Body         : PKG_LOG_MAINTENANCE
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Implements operational log reporting and controlled retention maintenance.
--
-- Implementation Notes
--   * Validates retention and batch-size parameters.
--   * Uses BULK COLLECT and FORALL with SAVE EXCEPTIONS for batched purging.
--   * Records row-level purge failures through PKG_ERROR_LOG.
--   * Records completed purge operations through PKG_AUDIT.
--   * Returns summary information for AUDIT_LOGS and ERROR_LOGS.
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Purge operations participate in the caller's transaction.
--
-- Dependencies
--   * AUDIT_LOGS
--   * ERROR_LOGS
--   * PKG_AUDIT
--   * PKG_ERROR_LOG
-- ============================================================================

create or replace PACKAGE BODY pkg_log_maintenance AS

    c_min_retention_days CONSTANT PLS_INTEGER := 1;
    c_max_batch_size     CONSTANT PLS_INTEGER := 10000;

    e_bulk_errors EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_bulk_errors, -24381);


    ----------------------------------------------------------------------------
    -- Validates common purge parameters.
    ----------------------------------------------------------------------------
    PROCEDURE validate_purge_parameters (
        p_retention_days IN PLS_INTEGER,
        p_batch_size     IN PLS_INTEGER
    )
    IS
    BEGIN
        IF p_retention_days IS NULL
           OR p_retention_days < c_min_retention_days
        THEN
            RAISE_APPLICATION_ERROR(
                -20800,
                'Retention days must be at least 1.'
            );
        END IF;

        IF p_batch_size IS NULL
           OR p_batch_size < 1
           OR p_batch_size > c_max_batch_size
        THEN
            RAISE_APPLICATION_ERROR(
                -20801,
                'Batch size must be between 1 and 10000.'
            );
        END IF;
    END validate_purge_parameters;


    ----------------------------------------------------------------------------
    -- Returns summary information for both operational log tables.
    ----------------------------------------------------------------------------
    PROCEDURE get_log_summary (
        p_result OUT SYS_REFCURSOR
    )
    IS
    BEGIN
        OPEN p_result FOR
            SELECT 'AUDIT_LOGS' AS table_name,
                   COUNT(*) AS total_rows,
                   MIN(logged_at) AS oldest_logged_at,
                   MAX(logged_at) AS newest_logged_at,
                   SUM(
                       CASE
                           WHEN logged_at <
                                SYSTIMESTAMP - NUMTODSINTERVAL(30, 'DAY')
                           THEN 1
                           ELSE 0
                       END
                   ) AS rows_older_than_30_days,
                   SUM(
                       CASE
                           WHEN logged_at <
                                SYSTIMESTAMP - NUMTODSINTERVAL(90, 'DAY')
                           THEN 1
                           ELSE 0
                       END
                   ) AS rows_older_than_90_days
              FROM audit_logs

            UNION ALL

            SELECT 'ERROR_LOGS' AS table_name,
                   COUNT(*) AS total_rows,
                   MIN(logged_at) AS oldest_logged_at,
                   MAX(logged_at) AS newest_logged_at,
                   SUM(
                       CASE
                           WHEN logged_at <
                                SYSTIMESTAMP - NUMTODSINTERVAL(30, 'DAY')
                           THEN 1
                           ELSE 0
                       END
                   ) AS rows_older_than_30_days,
                   SUM(
                       CASE
                           WHEN logged_at <
                                SYSTIMESTAMP - NUMTODSINTERVAL(90, 'DAY')
                           THEN 1
                           ELSE 0
                       END
                   ) AS rows_older_than_90_days
              FROM error_logs;

    EXCEPTION
        WHEN OTHERS THEN
            IF p_result%ISOPEN THEN
                CLOSE p_result;
            END IF;

            pkg_error_log.log_error(
                p_operation_name => 'PKG_LOG_MAINTENANCE.GET_LOG_SUMMARY',
                p_entity_name    => 'LOG_TABLES',
                p_entity_id      => NULL,
                p_context_data   => JSON_OBJECT(
                                        'sqlcode' VALUE SQLCODE,
                                        'sqlerrm' VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END get_log_summary;


    ----------------------------------------------------------------------------
    -- Deletes old audit rows in batches.
    ----------------------------------------------------------------------------
    PROCEDURE purge_audit_logs (
        p_retention_days IN  PLS_INTEGER DEFAULT 90,
        p_batch_size     IN  PLS_INTEGER DEFAULT 1000,
        p_deleted_count  OUT PLS_INTEGER,
        p_failed_count   OUT PLS_INTEGER
    )
    IS
        TYPE t_id_table IS TABLE OF audit_logs.audit_log_id%TYPE;

        l_ids          t_id_table;
        l_cutoff_time  TIMESTAMP(6);
        l_batch_deleted PLS_INTEGER;

        CURSOR c_old_audit_logs (
            p_cutoff_time TIMESTAMP
        )
        IS
            SELECT audit_log_id
              FROM audit_logs
             WHERE logged_at < p_cutoff_time
             ORDER BY audit_log_id;
    BEGIN
        p_deleted_count := 0;
        p_failed_count  := 0;

        validate_purge_parameters(
            p_retention_days => p_retention_days,
            p_batch_size     => p_batch_size
        );

        l_cutoff_time :=
            SYSTIMESTAMP - NUMTODSINTERVAL(p_retention_days, 'DAY');

        OPEN c_old_audit_logs(l_cutoff_time);

        LOOP
            FETCH c_old_audit_logs
            BULK COLLECT INTO l_ids
            LIMIT p_batch_size;

            EXIT WHEN l_ids.COUNT = 0;

            l_batch_deleted := 0;

            BEGIN
                FORALL i IN 1 .. l_ids.COUNT SAVE EXCEPTIONS
                    DELETE FROM audit_logs
                     WHERE audit_log_id = l_ids(i);

                l_batch_deleted := SQL%ROWCOUNT;
                p_deleted_count := p_deleted_count + l_batch_deleted;

            EXCEPTION
                WHEN e_bulk_errors THEN
                    l_batch_deleted := SQL%ROWCOUNT;
                    p_deleted_count := p_deleted_count + l_batch_deleted;
                    p_failed_count :=
                        p_failed_count + SQL%BULK_EXCEPTIONS.COUNT;

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
                        pkg_error_log.log_error(
                            p_operation_name =>
                                'PKG_LOG_MAINTENANCE.PURGE_AUDIT_LOGS',
                            p_entity_name    => 'AUDIT_LOGS',
                            p_entity_id      =>
                                TO_CHAR(
                                    l_ids(
                                        SQL%BULK_EXCEPTIONS(j).ERROR_INDEX
                                    )
                                ),
                            p_context_data   => JSON_OBJECT(
                                                    'error_index'
                                                        VALUE SQL%BULK_EXCEPTIONS(j).ERROR_INDEX,
                                                    'error_code'
                                                        VALUE SQL%BULK_EXCEPTIONS(j).ERROR_CODE,
                                                    'error_message'
                                                        VALUE SQLERRM(
                                                            -SQL%BULK_EXCEPTIONS(j).ERROR_CODE
                                                        ),
                                                    'cutoff_time'
                                                        VALUE TO_CHAR(
                                                            l_cutoff_time,
                                                            'YYYY-MM-DD HH24:MI:SS.FF6'
                                                        )
                                                    RETURNING VARCHAR2
                                                ),
                            p_severity       => 'ERROR'
                        );
                    END LOOP;
            END;
        END LOOP;

        CLOSE c_old_audit_logs;

        pkg_audit.log_action(
            p_action_type    => 'DELETE',
            p_entity_name    => 'AUDIT_LOGS',
            p_entity_id      => NULL,
            p_operation_name => 'PURGE_AUDIT_LOGS',
            p_old_data       => NULL,
            p_new_data       => NULL,
            p_context_data   => JSON_OBJECT(
                                    'retention_days' VALUE p_retention_days,
                                    'batch_size'     VALUE p_batch_size,
                                    'cutoff_time'    VALUE TO_CHAR(
                                                        l_cutoff_time,
                                                        'YYYY-MM-DD HH24:MI:SS.FF6'
                                                    ),
                                    'deleted_count' VALUE p_deleted_count,
                                    'failed_count'  VALUE p_failed_count
                                    RETURNING VARCHAR2
                                )
        );

        IF p_failed_count > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20802,
                'Audit log purge completed with row-level failures. ' ||
                'Deleted=' || p_deleted_count ||
                ', Failed=' || p_failed_count || '.'
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            IF c_old_audit_logs%ISOPEN THEN
                CLOSE c_old_audit_logs;
            END IF;

            pkg_error_log.log_error(
                p_operation_name => 'PKG_LOG_MAINTENANCE.PURGE_AUDIT_LOGS',
                p_entity_name    => 'AUDIT_LOGS',
                p_entity_id      => NULL,
                p_context_data   => JSON_OBJECT(
                                        'retention_days' VALUE p_retention_days,
                                        'batch_size'     VALUE p_batch_size,
                                        'deleted_count'  VALUE p_deleted_count,
                                        'failed_count'   VALUE p_failed_count,
                                        'sqlcode'        VALUE SQLCODE,
                                        'sqlerrm'        VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END purge_audit_logs;


    ----------------------------------------------------------------------------
    -- Deletes old error rows in batches.
    ----------------------------------------------------------------------------
    PROCEDURE purge_error_logs (
        p_retention_days IN  PLS_INTEGER DEFAULT 90,
        p_batch_size     IN  PLS_INTEGER DEFAULT 1000,
        p_deleted_count  OUT PLS_INTEGER,
        p_failed_count   OUT PLS_INTEGER
    )
    IS
        TYPE t_id_table IS TABLE OF error_logs.error_log_id%TYPE;

        l_ids           t_id_table;
        l_cutoff_time   TIMESTAMP(6);
        l_batch_deleted PLS_INTEGER;

        CURSOR c_old_error_logs (
            p_cutoff_time TIMESTAMP
        )
        IS
            SELECT error_log_id
              FROM error_logs
             WHERE logged_at < p_cutoff_time
             ORDER BY error_log_id;
    BEGIN
        p_deleted_count := 0;
        p_failed_count  := 0;

        validate_purge_parameters(
            p_retention_days => p_retention_days,
            p_batch_size     => p_batch_size
        );

        l_cutoff_time :=
            SYSTIMESTAMP - NUMTODSINTERVAL(p_retention_days, 'DAY');

        OPEN c_old_error_logs(l_cutoff_time);

        LOOP
            FETCH c_old_error_logs
            BULK COLLECT INTO l_ids
            LIMIT p_batch_size;

            EXIT WHEN l_ids.COUNT = 0;

            l_batch_deleted := 0;

            BEGIN
                FORALL i IN 1 .. l_ids.COUNT SAVE EXCEPTIONS
                    DELETE FROM error_logs
                     WHERE error_log_id = l_ids(i);

                l_batch_deleted := SQL%ROWCOUNT;
                p_deleted_count := p_deleted_count + l_batch_deleted;

            EXCEPTION
                WHEN e_bulk_errors THEN
                    l_batch_deleted := SQL%ROWCOUNT;
                    p_deleted_count := p_deleted_count + l_batch_deleted;
                    p_failed_count :=
                        p_failed_count + SQL%BULK_EXCEPTIONS.COUNT;

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
                        pkg_error_log.log_error(
                            p_operation_name =>
                                'PKG_LOG_MAINTENANCE.PURGE_ERROR_LOGS',
                            p_entity_name    => 'ERROR_LOGS',
                            p_entity_id      =>
                                TO_CHAR(
                                    l_ids(
                                        SQL%BULK_EXCEPTIONS(j).ERROR_INDEX
                                    )
                                ),
                            p_context_data   => JSON_OBJECT(
                                                    'error_index'
                                                        VALUE SQL%BULK_EXCEPTIONS(j).ERROR_INDEX,
                                                    'error_code'
                                                        VALUE SQL%BULK_EXCEPTIONS(j).ERROR_CODE,
                                                    'error_message'
                                                        VALUE SQLERRM(
                                                            -SQL%BULK_EXCEPTIONS(j).ERROR_CODE
                                                        ),
                                                    'cutoff_time'
                                                        VALUE TO_CHAR(
                                                            l_cutoff_time,
                                                            'YYYY-MM-DD HH24:MI:SS.FF6'
                                                        )
                                                    RETURNING VARCHAR2
                                                ),
                            p_severity       => 'ERROR'
                        );
                    END LOOP;
            END;
        END LOOP;

        CLOSE c_old_error_logs;

        pkg_audit.log_action(
            p_action_type    => 'DELETE',
            p_entity_name    => 'ERROR_LOGS',
            p_entity_id      => NULL,
            p_operation_name => 'PURGE_ERROR_LOGS',
            p_old_data       => NULL,
            p_new_data       => NULL,
            p_context_data   => JSON_OBJECT(
                                    'retention_days' VALUE p_retention_days,
                                    'batch_size'     VALUE p_batch_size,
                                    'cutoff_time'    VALUE TO_CHAR(
                                                        l_cutoff_time,
                                                        'YYYY-MM-DD HH24:MI:SS.FF6'
                                                    ),
                                    'deleted_count' VALUE p_deleted_count,
                                    'failed_count'  VALUE p_failed_count
                                    RETURNING VARCHAR2
                                )
        );

        IF p_failed_count > 0 THEN
            RAISE_APPLICATION_ERROR(
                -20803,
                'Error log purge completed with row-level failures. ' ||
                'Deleted=' || p_deleted_count ||
                ', Failed=' || p_failed_count || '.'
            );
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            IF c_old_error_logs%ISOPEN THEN
                CLOSE c_old_error_logs;
            END IF;

            pkg_error_log.log_error(
                p_operation_name => 'PKG_LOG_MAINTENANCE.PURGE_ERROR_LOGS',
                p_entity_name    => 'ERROR_LOGS',
                p_entity_id      => NULL,
                p_context_data   => JSON_OBJECT(
                                        'retention_days' VALUE p_retention_days,
                                        'batch_size'     VALUE p_batch_size,
                                        'deleted_count'  VALUE p_deleted_count,
                                        'failed_count'   VALUE p_failed_count,
                                        'sqlcode'        VALUE SQLCODE,
                                        'sqlerrm'        VALUE SQLERRM
                                        RETURNING VARCHAR2
                                    ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END purge_error_logs;

END pkg_log_maintenance;
