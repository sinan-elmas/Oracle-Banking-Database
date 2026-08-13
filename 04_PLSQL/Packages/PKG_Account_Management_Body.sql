-- ============================================================================
-- Package Body         : PKG_ACCOUNT_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Implements account lifecycle operations and related business validations.
--
-- Implementation Notes
--   * Uses private helper functions for reference-data validation.
--   * Serializes account opening for the same customer to prevent duplicate
--     account sequence values.
--   * Generates project-standard account numbers and IBAN values.
--   * Records successful business actions through PKG_AUDIT.
--   * Records unexpected errors through PKG_ERROR_LOG.
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
-- ============================================================================

create or replace PACKAGE BODY pkg_account_management AS

----------------------------------------------------------------------------
    -- Private Constants
    ----------------------------------------------------------------------------

    c_status_active  CONSTANT accounts.status%TYPE := 'ACTIVE';
    c_status_blocked CONSTANT accounts.status%TYPE := 'BLOCKED';
    c_status_closed  CONSTANT accounts.status%TYPE := 'CLOSED';


    ----------------------------------------------------------------------------
    -- Private Helper Functions
    ----------------------------------------------------------------------------

    FUNCTION customer_exists(
        p_customer_id IN customers.customer_id%TYPE
    ) RETURN BOOLEAN
    IS
        v_count PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO v_count
          FROM customers
         WHERE customer_id = p_customer_id;

        RETURN v_count > 0;
    END customer_exists;


    FUNCTION customer_is_active(
        p_customer_id IN customers.customer_id%TYPE
    ) RETURN BOOLEAN
    IS
        v_status customers.status%TYPE;
    BEGIN
        SELECT status
          INTO v_status
          FROM customers
         WHERE customer_id = p_customer_id;

        RETURN UPPER(TRIM(v_status)) = c_status_active;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END customer_is_active;


    FUNCTION account_type_exists(
        p_account_type_id IN account_types.account_type_id%TYPE
    ) RETURN BOOLEAN
    IS
        v_count PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO v_count
          FROM account_types
         WHERE account_type_id = p_account_type_id;

        RETURN v_count > 0;
    END account_type_exists;


    FUNCTION currency_exists(
        p_currency_id IN currencies.currency_id%TYPE
    ) RETURN BOOLEAN
    IS
        v_count PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO v_count
          FROM currencies
         WHERE currency_id = p_currency_id;

        RETURN v_count > 0;
    END currency_exists;


    FUNCTION branch_exists(
        p_branch_id IN branches.branch_id%TYPE
    ) RETURN BOOLEAN
    IS
        v_count PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO v_count
          FROM branches
         WHERE branch_id = p_branch_id;

        RETURN v_count > 0;
    END branch_exists;


    ----------------------------------------------------------------------------
    -- Returns the next account sequence number for a customer.
    --
    -- Example:
    --   AC00010013-1
    --   AC00010013-2
    --   AC00010013-3
    --
    --   Next sequence number = 4
    ----------------------------------------------------------------------------

    FUNCTION get_next_account_sequence(
        p_customer_id IN customers.customer_id%TYPE
    ) RETURN PLS_INTEGER
    IS
        v_next_sequence PLS_INTEGER;
    BEGIN
        SELECT NVL(
                   MAX(
                       TO_NUMBER(
                           SUBSTR(
                               account_number,
                               INSTR(account_number, '-', -1) + 1
                           )
                       )
                   ),
                   0
               ) + 1
          INTO v_next_sequence
          FROM accounts
         WHERE customer_id = p_customer_id;

        RETURN v_next_sequence;
    END get_next_account_sequence;


    ----------------------------------------------------------------------------
    -- Generates an account number according to the project format.
    --
    -- Format:
    --   AC + 8-digit customer ID + '-' + account sequence
    --
    -- Example:
    --   AC00010013-3
    ----------------------------------------------------------------------------

    FUNCTION generate_account_number(
        p_customer_id IN customers.customer_id%TYPE,
        p_sequence_no IN PLS_INTEGER
    ) RETURN accounts.account_number%TYPE
    IS
        v_account_number accounts.account_number%TYPE;
    BEGIN
        v_account_number :=
               'AC'
            || LPAD(TO_CHAR(p_customer_id), 8, '0')
            || '-'
            || TO_CHAR(p_sequence_no);

        RETURN v_account_number;
    END generate_account_number;


    ----------------------------------------------------------------------------
    -- Generates an IBAN according to the existing project data format.
    --
    -- Format:
    --   TR + 4-digit account sequence + 14-digit customer ID
    --
    -- Example:
    --   TR000300000000010013
    ----------------------------------------------------------------------------

    FUNCTION generate_iban(
        p_customer_id IN customers.customer_id%TYPE,
        p_sequence_no IN PLS_INTEGER
    ) RETURN accounts.iban%TYPE
    IS
        v_iban accounts.iban%TYPE;
    BEGIN
        v_iban :=
               'TR'
            || LPAD(TO_CHAR(p_sequence_no), 4, '0')
            || LPAD(TO_CHAR(p_customer_id), 14, '0');

        RETURN v_iban;
    END generate_iban;


    ----------------------------------------------------------------------------
    -- Public Procedure: OPEN_ACCOUNT
    ----------------------------------------------------------------------------

    PROCEDURE open_account(
        p_customer_id        IN  accounts.customer_id%TYPE,
        p_branch_id          IN  accounts.branch_id%TYPE,
        p_account_type_id    IN  accounts.account_type_id%TYPE,
        p_currency_id        IN  accounts.currency_id%TYPE,
        p_initial_balance    IN  accounts.balance%TYPE DEFAULT 0,
        p_created_by         IN  accounts.created_by%TYPE DEFAULT NULL,
        p_account_id         OUT accounts.account_id%TYPE,
        p_account_number     OUT accounts.account_number%TYPE,
        p_iban               OUT accounts.iban%TYPE
    )
    IS
        v_customer_status  customers.status%TYPE;
        v_sequence_no      PLS_INTEGER;
        v_sequence_no_sql  NUMBER;
        v_initial_balance  accounts.balance%TYPE;
        v_created_by       accounts.created_by%TYPE;
        v_audit_data       CLOB;
        v_context_data     CLOB;
    BEGIN
        ------------------------------------------------------------------------
        -- Initialize OUT parameters
        ------------------------------------------------------------------------

        p_account_id     := NULL;
        p_account_number := NULL;
        p_iban           := NULL;


        ------------------------------------------------------------------------
        -- Validate required parameters
        ------------------------------------------------------------------------

        IF p_customer_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20210,
                'Customer ID cannot be null.'
            );
        END IF;


        IF p_branch_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20211,
                'Branch ID cannot be null.'
            );
        END IF;


        IF p_account_type_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20212,
                'Account type ID cannot be null.'
            );
        END IF;


        IF p_currency_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20213,
                'Currency ID cannot be null.'
            );
        END IF;


        IF p_initial_balance IS NULL THEN
            v_initial_balance := 0;
        ELSE
            v_initial_balance := p_initial_balance;
        END IF;


        IF v_initial_balance < 0 THEN
            RAISE_APPLICATION_ERROR(
                -20214,
                'Initial balance cannot be negative.'
            );
        END IF;


        ------------------------------------------------------------------------
        -- Lock the customer row.
        --
        -- This serializes simultaneous account-opening operations for the same
        -- customer and prevents duplicate account sequence numbers.
        ------------------------------------------------------------------------

        BEGIN
            SELECT status
              INTO v_customer_status
              FROM customers
             WHERE customer_id = p_customer_id
               FOR UPDATE;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20215,
                    'Customer does not exist.'
                );
        END;


        ------------------------------------------------------------------------
        -- Validate customer status
        ------------------------------------------------------------------------

        IF UPPER(TRIM(v_customer_status)) <> c_status_active THEN
            RAISE_APPLICATION_ERROR(
                -20216,
                'A new account can only be opened for an active customer.'
            );
        END IF;


        ------------------------------------------------------------------------
        -- Validate branch
        ------------------------------------------------------------------------

        IF NOT branch_exists(p_branch_id) THEN
            RAISE_APPLICATION_ERROR(
                -20217,
                'Branch does not exist.'
            );
        END IF;


        ------------------------------------------------------------------------
        -- Validate account type
        ------------------------------------------------------------------------

        IF NOT account_type_exists(p_account_type_id) THEN
            RAISE_APPLICATION_ERROR(
                -20218,
                'Account type does not exist.'
            );
        END IF;


        ------------------------------------------------------------------------
        -- Validate currency
        ------------------------------------------------------------------------

        IF NOT currency_exists(p_currency_id) THEN
            RAISE_APPLICATION_ERROR(
                -20219,
                'Currency does not exist.'
            );
        END IF;


        ------------------------------------------------------------------------
        -- Determine the effective application user
        ------------------------------------------------------------------------

        v_created_by :=
            NVL(
                TRIM(p_created_by),
                SYS_CONTEXT('USERENV', 'SESSION_USER')
            );


        ------------------------------------------------------------------------
        -- Generate account identifiers
        ------------------------------------------------------------------------

        v_sequence_no :=
            get_next_account_sequence(
                p_customer_id => p_customer_id
            );

        v_sequence_no_sql := v_sequence_no;


        p_account_number :=
            generate_account_number(
                p_customer_id => p_customer_id,
                p_sequence_no => v_sequence_no
            );


        p_iban :=
            generate_iban(
                p_customer_id => p_customer_id,
                p_sequence_no => v_sequence_no
            );


        ------------------------------------------------------------------------
        -- Insert the account
        --
        -- ACCOUNT_ID is an identity column and is generated by Oracle.
        ------------------------------------------------------------------------

        INSERT INTO accounts (
            customer_id,
            branch_id,
            account_type_id,
            currency_id,
            account_number,
            iban,
            balance,
            status,
            opening_date,
            closing_date,
            created_at,
            created_by,
            updated_at,
            updated_by
        )
        VALUES (
            p_customer_id,
            p_branch_id,
            p_account_type_id,
            p_currency_id,
            p_account_number,
            p_iban,
            v_initial_balance,
            c_status_active,
            TRUNC(SYSDATE),
            NULL,
            SYSTIMESTAMP,
            v_created_by,
            NULL,
            NULL
        )
        RETURNING account_id
             INTO p_account_id;


        ------------------------------------------------------------------------
        -- Prepare audit information
        ------------------------------------------------------------------------

        SELECT JSON_OBJECT(
                   'account_id'       VALUE p_account_id,
                   'customer_id'      VALUE p_customer_id,
                   'branch_id'        VALUE p_branch_id,
                   'account_type_id'  VALUE p_account_type_id,
                   'currency_id'      VALUE p_currency_id,
                   'account_number'   VALUE p_account_number,
                   'iban'             VALUE p_iban,
                   'balance'          VALUE v_initial_balance,
                   'status'           VALUE c_status_active,
                   'opening_date'     VALUE TO_CHAR(
                                                 TRUNC(SYSDATE),
                                                 'YYYY-MM-DD'
                                             ),
                   'created_by'       VALUE v_created_by
                   RETURNING CLOB
               )
          INTO v_audit_data
          FROM dual;


        SELECT JSON_OBJECT(
                   'customer_account_sequence' VALUE v_sequence_no_sql,
                   'session_user'              VALUE SYS_CONTEXT(
                                                         'USERENV',
                                                         'SESSION_USER'
                                                     ),
                   'client_identifier'         VALUE SYS_CONTEXT(
                                                         'USERENV',
                                                         'CLIENT_IDENTIFIER'
                                                     ),
                   'module'                    VALUE SYS_CONTEXT(
                                                         'USERENV',
                                                         'MODULE'
                                                     )
                   RETURNING CLOB
               )
          INTO v_context_data
          FROM dual;


        ------------------------------------------------------------------------
        -- Write audit record
        --
        -- No COMMIT is used. The account insert and audit record remain within
        -- the caller's transaction.
        ------------------------------------------------------------------------

        pkg_audit.log_action(
            p_action_type    => 'INSERT',
            p_entity_name    => 'ACCOUNTS',
            p_entity_id      => TO_CHAR(p_account_id),
            p_operation_name => 'PKG_ACCOUNT_MANAGEMENT.OPEN_ACCOUNT',
            p_old_data       => NULL,
            p_new_data       => v_audit_data,
            p_context_data   => v_context_data
        );

   EXCEPTION
        WHEN OTHERS THEN
            --------------------------------------------------------------------
            -- Build error context as SQL JSON and store it in a CLOB variable.
            --------------------------------------------------------------------

            SELECT JSON_OBJECT(
                       'customer_id'     VALUE p_customer_id,
                       'branch_id'       VALUE p_branch_id,
                       'account_type_id' VALUE p_account_type_id,
                       'currency_id'     VALUE p_currency_id,
                       'initial_balance' VALUE p_initial_balance,
                       'account_number'  VALUE p_account_number,
                       'iban'            VALUE p_iban
                       RETURNING CLOB
                   )
              INTO v_context_data
              FROM dual;


            --------------------------------------------------------------------
            -- PKG_ERROR_LOG uses an autonomous transaction.
            -- Re-raise the original exception after logging.
            --------------------------------------------------------------------

            pkg_error_log.log_error(
                p_operation_name => 'PKG_ACCOUNT_MANAGEMENT.OPEN_ACCOUNT',
                p_entity_name    => 'ACCOUNTS',
                p_entity_id      => CASE
                                        WHEN p_account_id IS NOT NULL
                                        THEN TO_CHAR(p_account_id)
                                        ELSE NULL
                                    END,
                p_context_data   => v_context_data,
                p_severity       => 'ERROR'
            );

            RAISE;
    END open_account;


    ----------------------------------------------------------------------------
    -- Public Procedure: UPDATE_ACCOUNT_STATUS
    ----------------------------------------------------------------------------

    PROCEDURE update_account_status(
    p_account_id IN accounts.account_id%TYPE,
    p_new_status IN accounts.status%TYPE,
    p_updated_by IN accounts.updated_by%TYPE DEFAULT NULL
)
IS
    v_old_status       accounts.status%TYPE;
    v_new_status       accounts.status%TYPE;
    v_balance          accounts.balance%TYPE;
    v_old_closing_date accounts.closing_date%TYPE;
    v_new_closing_date accounts.closing_date%TYPE;
    v_updated_by       accounts.updated_by%TYPE;

    v_old_data         CLOB;
    v_new_data         CLOB;
    v_context_data     CLOB;
BEGIN
    ------------------------------------------------------------------------
    -- Validate required parameters
    ------------------------------------------------------------------------

    IF p_account_id IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20220,
            'Account ID cannot be null.'
        );
    END IF;


    IF p_new_status IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20222,
            'Account status cannot be null.'
        );
    END IF;


    v_new_status := UPPER(TRIM(p_new_status));


    ------------------------------------------------------------------------
    -- Validate requested account status
    ------------------------------------------------------------------------

    IF v_new_status NOT IN ('ACTIVE', 'BLOCKED', 'CLOSED') THEN
        RAISE_APPLICATION_ERROR(
            -20222,
            'Invalid account status. Allowed values: ACTIVE, BLOCKED, CLOSED.'
        );
    END IF;


    ------------------------------------------------------------------------
    -- Lock and retrieve the account
    ------------------------------------------------------------------------

    BEGIN
        SELECT status,
               balance,
               closing_date
          INTO v_old_status,
               v_balance,
               v_old_closing_date
          FROM accounts
         WHERE account_id = p_account_id
           FOR UPDATE;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20221,
                'Account does not exist.'
            );
    END;


    v_old_status := UPPER(TRIM(v_old_status));


    ------------------------------------------------------------------------
    -- Validate status transition
    ------------------------------------------------------------------------

    IF v_old_status = v_new_status THEN
        RAISE_APPLICATION_ERROR(
            -20223,
            'Account is already in the requested status.'
        );
    END IF;


    IF v_old_status = 'CLOSED' THEN
        RAISE_APPLICATION_ERROR(
            -20224,
            'A closed account cannot be reopened or blocked.'
        );
    END IF;


    IF v_new_status = 'CLOSED'
       AND NVL(v_balance, 0) <> 0
    THEN
        RAISE_APPLICATION_ERROR(
            -20225,
            'An account with a non-zero balance cannot be closed.'
        );
    END IF;


    ------------------------------------------------------------------------
    -- Determine closing date
    ------------------------------------------------------------------------

    IF v_new_status = 'CLOSED' THEN
        v_new_closing_date := TRUNC(SYSDATE);
    ELSE
        v_new_closing_date := NULL;
    END IF;


    ------------------------------------------------------------------------
    -- Determine the effective application user
    ------------------------------------------------------------------------

    v_updated_by :=
        NVL(
            TRIM(p_updated_by),
            SYS_CONTEXT('USERENV', 'SESSION_USER')
        );


    ------------------------------------------------------------------------
    -- Prepare old audit information
    ------------------------------------------------------------------------

    SELECT JSON_OBJECT(
               'account_id'   VALUE p_account_id,
               'status'       VALUE v_old_status,
               'balance'      VALUE v_balance,
               'closing_date' VALUE CASE
                                        WHEN v_old_closing_date IS NOT NULL
                                        THEN TO_CHAR(
                                                 v_old_closing_date,
                                                 'YYYY-MM-DD'
                                             )
                                        ELSE NULL
                                    END,
               'updated_by'   VALUE v_updated_by
               RETURNING CLOB
           )
      INTO v_old_data
      FROM dual;


    ------------------------------------------------------------------------
    -- Update account status
    ------------------------------------------------------------------------

    UPDATE accounts
       SET status       = v_new_status,
           closing_date = v_new_closing_date,
           updated_at   = SYSTIMESTAMP,
           updated_by   = v_updated_by
     WHERE account_id = p_account_id;


    ------------------------------------------------------------------------
    -- Prepare new audit information
    ------------------------------------------------------------------------

    SELECT JSON_OBJECT(
               'account_id'   VALUE p_account_id,
               'status'       VALUE v_new_status,
               'balance'      VALUE v_balance,
               'closing_date' VALUE CASE
                                        WHEN v_new_closing_date IS NOT NULL
                                        THEN TO_CHAR(
                                                 v_new_closing_date,
                                                 'YYYY-MM-DD'
                                             )
                                        ELSE NULL
                                    END,
               'updated_by'   VALUE v_updated_by
               RETURNING CLOB
           )
      INTO v_new_data
      FROM dual;


    SELECT JSON_OBJECT(
               'status_transition' VALUE v_old_status || ' -> ' ||
                                         v_new_status,
               'session_user'      VALUE SYS_CONTEXT(
                                             'USERENV',
                                             'SESSION_USER'
                                         ),
               'client_identifier' VALUE SYS_CONTEXT(
                                             'USERENV',
                                             'CLIENT_IDENTIFIER'
                                         ),
               'module'            VALUE SYS_CONTEXT(
                                             'USERENV',
                                             'MODULE'
                                         )
               RETURNING CLOB
           )
      INTO v_context_data
      FROM dual;


    ------------------------------------------------------------------------
    -- Write audit record
    --
    -- No COMMIT is used. The account update and audit record remain within
    -- the caller's transaction.
    ------------------------------------------------------------------------

    pkg_audit.log_action(
        p_action_type    => 'UPDATE',
        p_entity_name    => 'ACCOUNTS',
        p_entity_id      => TO_CHAR(p_account_id),
        p_operation_name => 'PKG_ACCOUNT_MANAGEMENT.UPDATE_ACCOUNT_STATUS',
        p_old_data       => v_old_data,
        p_new_data       => v_new_data,
        p_context_data   => v_context_data
    );

EXCEPTION
    WHEN OTHERS THEN
        --------------------------------------------------------------------
        -- Build error context
        --------------------------------------------------------------------

        SELECT JSON_OBJECT(
                   'account_id'      VALUE p_account_id,
                   'requested_status' VALUE p_new_status,
                   'current_status'   VALUE v_old_status,
                   'balance'          VALUE v_balance,
                   'updated_by'       VALUE p_updated_by
                   RETURNING CLOB
               )
          INTO v_context_data
          FROM dual;


        --------------------------------------------------------------------
        -- PKG_ERROR_LOG uses an autonomous transaction.
        -- Re-raise the original exception after logging.
        --------------------------------------------------------------------

        pkg_error_log.log_error(
            p_operation_name =>
                'PKG_ACCOUNT_MANAGEMENT.UPDATE_ACCOUNT_STATUS',
            p_entity_name    => 'ACCOUNTS',
            p_entity_id      => CASE
                                    WHEN p_account_id IS NOT NULL
                                    THEN TO_CHAR(p_account_id)
                                    ELSE NULL
                                END,
            p_context_data   => v_context_data,
            p_severity       => 'ERROR'
        );

        RAISE;
END update_account_status;


    ----------------------------------------------------------------------------
    -- Public Procedure: GET_ACCOUNT_INFO
    ----------------------------------------------------------------------------

    PROCEDURE get_account_info(
    p_account_id IN  accounts.account_id%TYPE,
    p_result     OUT SYS_REFCURSOR
    )
    IS
        v_account_count PLS_INTEGER;
        v_context_data  CLOB;
    BEGIN
    ------------------------------------------------------------------------
    -- Validate required parameter
    ------------------------------------------------------------------------

    IF p_account_id IS NULL THEN
        RAISE_APPLICATION_ERROR(
            -20230,
            'Account ID cannot be null.'
        );
    END IF;


    ------------------------------------------------------------------------
    -- Validate account existence
    ------------------------------------------------------------------------

    SELECT COUNT(*)
      INTO v_account_count
      FROM accounts
     WHERE account_id = p_account_id;


    IF v_account_count = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20231,
            'Account does not exist.'
        );
    END IF;


    ------------------------------------------------------------------------
    -- Return detailed account information
    ------------------------------------------------------------------------

    OPEN p_result FOR
        SELECT
            a.account_id,
            a.account_number,
            a.iban,

            a.customer_id,
            c.customer_no,
            c.customer_type,
            c.status AS customer_status,

            CASE
                WHEN c.customer_type = 'I' THEN
                    TRIM(
                        NVL(ic.first_name, '') || ' ' ||
                        NVL(ic.last_name, '')
                    )

                WHEN c.customer_type = 'C' THEN
                    co.company_name

                ELSE
                    NULL
            END AS customer_name,

            a.branch_id,
            b.branch_code,
            b.branch_name,

            a.account_type_id,
            atp.type_name AS account_type_name,

            a.currency_id,
            TRIM(cur.currency_code) AS currency_code,
            cur.currency_name,
            cur.symbol AS currency_symbol,

            a.balance,
            a.status AS account_status,
            a.opening_date,
            a.closing_date,

            a.created_at,
            a.created_by,
            a.updated_at,
            a.updated_by

        FROM accounts a

        JOIN customers c
          ON c.customer_id = a.customer_id

        LEFT JOIN individual_customers ic
          ON ic.customer_id = c.customer_id
         AND c.customer_type = 'I'

        LEFT JOIN corporate_customers cc
          ON cc.customer_id = c.customer_id
         AND c.customer_type = 'C'

        LEFT JOIN companies co
          ON co.company_id = cc.company_id

        JOIN branches b
          ON b.branch_id = a.branch_id

        JOIN account_types atp
          ON atp.account_type_id = a.account_type_id

        JOIN currencies cur
          ON cur.currency_id = a.currency_id

        WHERE a.account_id = p_account_id;

    EXCEPTION
        WHEN OTHERS THEN
            --------------------------------------------------------------------
            -- Build error context
            --------------------------------------------------------------------

            SELECT JSON_OBJECT(
                       'account_id' VALUE p_account_id
                       RETURNING CLOB
                   )
              INTO v_context_data
              FROM dual;


        --------------------------------------------------------------------
        -- PKG_ERROR_LOG uses an autonomous transaction.
        -- Re-raise the original exception after logging.
        --------------------------------------------------------------------

        pkg_error_log.log_error(
            p_operation_name =>
                'PKG_ACCOUNT_MANAGEMENT.GET_ACCOUNT_INFO',
            p_entity_name    => 'ACCOUNTS',
            p_entity_id      => CASE
                                    WHEN p_account_id IS NOT NULL
                                    THEN TO_CHAR(p_account_id)
                                    ELSE NULL
                                END,
            p_context_data   => v_context_data,
            p_severity       => 'ERROR'
        );

        RAISE;
    END get_account_info;


    ----------------------------------------------------------------------------
    -- Public Function: GET_AVAILABLE_BALANCE
    ----------------------------------------------------------------------------

    FUNCTION get_available_balance(
        p_account_id IN accounts.account_id%TYPE
    )
    RETURN accounts.balance%TYPE
    IS
        v_balance accounts.balance%TYPE;
    BEGIN
        IF p_account_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20232,
                'Account ID cannot be null.'
            );
        END IF;

        BEGIN
            SELECT balance
            INTO v_balance
            FROM accounts
            WHERE account_id = p_account_id;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20233,
                    'Account not found.'
                );
        END;

        RETURN v_balance;

    EXCEPTION
    WHEN OTHERS THEN
        PKG_ERROR_LOG.LOG_ERROR(
            p_operation_name => 'GET_AVAILABLE_BALANCE',
            p_entity_name    => 'ACCOUNTS',
            p_entity_id      => TO_CHAR(p_account_id),
            p_context_data   => JSON_OBJECT(
                                    'sqlcode' VALUE SQLCODE,
                                    'sqlerrm' VALUE SQLERRM
                                ),
            p_severity       => 'ERROR'
        );

            RAISE;
    END get_available_balance;


END pkg_account_management;
