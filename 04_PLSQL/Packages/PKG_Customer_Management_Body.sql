-- ============================================================================
-- Package Body         : PKG_CUSTOMER_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Implements customer registration, status management, and customer
--   information retrieval.
--
-- Implementation Notes
--   * Supports individual and corporate customer registration.
--   * Generates project-standard customer numbers.
--   * Validates identity, company, tax, and registration data.
--   * Applies controlled customer status transitions.
--   * Records successful business actions through PKG_AUDIT.
--   * Records unexpected errors through PKG_ERROR_LOG.
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
-- ============================================================================

create or replace PACKAGE BODY pkg_customer_management AS

    ------------------------------------------------------------------
    -- Package constants
    ------------------------------------------------------------------

    c_customer_type_individual CONSTANT customers.customer_type%TYPE :=
        'I';

    c_customer_type_corporate CONSTANT customers.customer_type%TYPE :=
        'C';

    c_status_active CONSTANT customers.status%TYPE :=
        'ACTIVE';

    c_status_blocked CONSTANT customers.status%TYPE :=
        'BLOCKED';

    c_status_closed CONSTANT customers.status%TYPE :=
        'CLOSED';

    c_entity_customers CONSTANT VARCHAR2(30) :=
        'CUSTOMERS';

    c_op_create_individual CONSTANT VARCHAR2(100) :=
        'Create Individual Customer';

    c_op_create_corporate CONSTANT VARCHAR2(100) :=
        'Create Corporate Customer';

    c_op_update_status CONSTANT VARCHAR2(100) :=
        'Update Customer Status';


    c_op_get_customer_info CONSTANT VARCHAR2(100) :=
        'Get Customer Information';


    ------------------------------------------------------------------
    -- Private helper functions
    ------------------------------------------------------------------

    FUNCTION generate_customer_no
        RETURN customers.customer_no%TYPE
    IS
    BEGIN
        RETURN 'CUST'
               || LPAD(
                      seq_customer_no.NEXTVAL,
                      6,
                      '0'
                  );
    END generate_customer_no;


    FUNCTION national_id_exists (
        p_national_id IN individual_customers.national_id%TYPE
    ) RETURN BOOLEAN
    IS
        l_dummy PLS_INTEGER;
    BEGIN
        SELECT 1
        INTO l_dummy
        FROM individual_customers
        WHERE national_id = p_national_id;

        RETURN TRUE;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END national_id_exists;


    FUNCTION corporate_company_exists (
        p_company_id IN corporate_customers.company_id%TYPE
    ) RETURN BOOLEAN
    IS
        l_dummy PLS_INTEGER;
    BEGIN
        SELECT 1
        INTO l_dummy
        FROM corporate_customers
        WHERE company_id = p_company_id;

        RETURN TRUE;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END corporate_company_exists;


    FUNCTION tax_number_exists (
        p_tax_number IN corporate_customers.tax_number%TYPE
    ) RETURN BOOLEAN
    IS
        l_dummy PLS_INTEGER;
    BEGIN
        SELECT 1
        INTO l_dummy
        FROM corporate_customers
        WHERE tax_number = p_tax_number;

        RETURN TRUE;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END tax_number_exists;


    FUNCTION registration_number_exists (
        p_registration_number
            IN corporate_customers.registration_number%TYPE
    ) RETURN BOOLEAN
    IS
        l_dummy PLS_INTEGER;
    BEGIN
        SELECT 1
        INTO l_dummy
        FROM corporate_customers
        WHERE registration_number = p_registration_number;

        RETURN TRUE;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END registration_number_exists;


    ------------------------------------------------------------------
    -- Create individual customer
    ------------------------------------------------------------------

    PROCEDURE create_individual_customer (
        p_first_name   IN  individual_customers.first_name%TYPE,
        p_last_name    IN  individual_customers.last_name%TYPE,
        p_national_id  IN  individual_customers.national_id%TYPE,
        p_birth_date   IN  individual_customers.birth_date%TYPE,
        p_customer_id  OUT customers.customer_id%TYPE,
        p_customer_no  OUT customers.customer_no%TYPE
    )
    IS
        l_first_name
            individual_customers.first_name%TYPE;

        l_last_name
            individual_customers.last_name%TYPE;

        l_national_id
            individual_customers.national_id%TYPE;
    BEGIN
        p_customer_id := NULL;
        p_customer_no := NULL;

        l_first_name  := TRIM(p_first_name);
        l_last_name   := TRIM(p_last_name);
        l_national_id := TRIM(p_national_id);

        IF l_first_name IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20101,
                'First name cannot be null.'
            );
        END IF;

        IF l_last_name IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20102,
                'Last name cannot be null.'
            );
        END IF;

        IF l_national_id IS NULL
           OR NOT REGEXP_LIKE(
               l_national_id,
               '^[0-9]{11}$'
           )
        THEN
            RAISE_APPLICATION_ERROR(
                -20103,
                'National ID must contain exactly 11 digits.'
            );
        END IF;

        IF p_birth_date IS NOT NULL
           AND p_birth_date >= TRUNC(SYSDATE)
        THEN
            RAISE_APPLICATION_ERROR(
                -20104,
                'Birth date must be earlier than today.'
            );
        END IF;

        IF national_id_exists(l_national_id) THEN
            RAISE_APPLICATION_ERROR(
                -20105,
                'A customer with this National ID already exists.'
            );
        END IF;

        IF LENGTH(l_first_name) > 50 THEN
            RAISE_APPLICATION_ERROR(
                -20106,
                'First name cannot exceed 50 characters.'
            );
        END IF;

        IF LENGTH(l_last_name) > 50 THEN
            RAISE_APPLICATION_ERROR(
                -20107,
                'Last name cannot exceed 50 characters.'
            );
        END IF;

        p_customer_no := generate_customer_no;

        INSERT INTO customers (
            customer_no,
            customer_type,
            status,
            created_by
        )
        VALUES (
            p_customer_no,
            c_customer_type_individual,
            c_status_active,
            SYS_CONTEXT('USERENV', 'SESSION_USER')
        )
        RETURNING customer_id
        INTO p_customer_id;

        INSERT INTO individual_customers (
            customer_id,
            first_name,
            last_name,
            national_id,
            birth_date,
            created_by
        )
        VALUES (
            p_customer_id,
            l_first_name,
            l_last_name,
            l_national_id,
            p_birth_date,
            SYS_CONTEXT('USERENV', 'SESSION_USER')
        );

        pkg_audit.log_action(
            p_action_type    => 'INSERT',
            p_entity_name    => c_entity_customers,
            p_entity_id      => TO_CHAR(p_customer_id),
            p_operation_name => c_op_create_individual,
            p_new_data       => JSON_OBJECT(
                'customer_id'
                    VALUE p_customer_id,
                'customer_no'
                    VALUE p_customer_no,
                'customer_type'
                    VALUE c_customer_type_individual,
                'status'
                    VALUE c_status_active,
                'first_name'
                    VALUE l_first_name,
                'last_name'
                    VALUE l_last_name,
                'national_id'
                    VALUE l_national_id,
                'birth_date'
                    VALUE TO_CHAR(
                        p_birth_date,
                        'YYYY-MM-DD'
                    )
                RETURNING VARCHAR2
            )
        );

    EXCEPTION
        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name => c_op_create_individual,
                p_entity_name    => c_entity_customers,
                p_entity_id      => TO_CHAR(p_customer_id),
                p_context_data   => JSON_OBJECT(
                    'national_id'
                        VALUE l_national_id,
                    'first_name'
                        VALUE p_first_name,
                    'last_name'
                        VALUE p_last_name
                    RETURNING VARCHAR2
                ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END create_individual_customer;


    ------------------------------------------------------------------
    -- Create corporate customer
    ------------------------------------------------------------------

    PROCEDURE create_corporate_customer (
        p_company_id           IN  corporate_customers.company_id%TYPE,
        p_tax_number           IN  corporate_customers.tax_number%TYPE,
        p_registration_number  IN  corporate_customers.registration_number%TYPE,
        p_customer_id          OUT customers.customer_id%TYPE,
        p_customer_no          OUT customers.customer_no%TYPE
    )
    IS
        l_tax_number
            corporate_customers.tax_number%TYPE;

        l_registration_number
            corporate_customers.registration_number%TYPE;

        l_company_status
            companies.status%TYPE;

        l_company_name
            companies.company_name%TYPE;
    BEGIN
        p_customer_id := NULL;
        p_customer_no := NULL;

        l_tax_number :=
            TRIM(p_tax_number);

        l_registration_number :=
            UPPER(TRIM(p_registration_number));

        IF p_company_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20111,
                'Company ID cannot be null.'
            );
        END IF;

        BEGIN
            SELECT company_name,
                   status
            INTO l_company_name,
                 l_company_status
            FROM companies
            WHERE company_id = p_company_id;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20112,
                    'Company not found.'
                );
        END;

        IF l_company_status <> c_status_active THEN
            RAISE_APPLICATION_ERROR(
                -20113,
                'Company must be active.'
            );
        END IF;

        IF l_tax_number IS NULL
           OR NOT REGEXP_LIKE(
               l_tax_number,
               '^[0-9]{10,11}$'
           )
        THEN
            RAISE_APPLICATION_ERROR(
                -20114,
                'Tax number must contain 10 or 11 digits.'
            );
        END IF;

        IF l_registration_number IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20115,
                'Registration number cannot be null.'
            );
        END IF;

        IF corporate_company_exists(p_company_id) THEN
            RAISE_APPLICATION_ERROR(
                -20116,
                'A corporate customer already exists for this company.'
            );
        END IF;

        IF tax_number_exists(l_tax_number) THEN
            RAISE_APPLICATION_ERROR(
                -20117,
                'A corporate customer with this tax number already exists.'
            );
        END IF;

        IF registration_number_exists(
            l_registration_number
        ) THEN
            RAISE_APPLICATION_ERROR(
                -20118,
                'A corporate customer with this registration number already exists.'
            );
        END IF;

        IF LENGTH(l_registration_number) > 50 THEN
            RAISE_APPLICATION_ERROR(
                -20119,
                'Registration number cannot exceed 50 characters.'
            );
        END IF;

        IF NOT REGEXP_LIKE(
            l_registration_number,
            '^[A-Z0-9-]+$'
        )
        THEN
            RAISE_APPLICATION_ERROR(
                -20120,
                'Registration number may contain only letters, digits, and hyphens.'
            );
        END IF;

        p_customer_no := generate_customer_no;

        INSERT INTO customers (
            customer_no,
            customer_type,
            status,
            created_by
        )
        VALUES (
            p_customer_no,
            c_customer_type_corporate,
            c_status_active,
            SYS_CONTEXT('USERENV', 'SESSION_USER')
        )
        RETURNING customer_id
        INTO p_customer_id;

        INSERT INTO corporate_customers (
            customer_id,
            company_id,
            tax_number,
            registration_number,
            created_by
        )
        VALUES (
            p_customer_id,
            p_company_id,
            l_tax_number,
            l_registration_number,
            SYS_CONTEXT('USERENV', 'SESSION_USER')
        );

        pkg_audit.log_action(
            p_action_type    => 'INSERT',
            p_entity_name    => c_entity_customers,
            p_entity_id      => TO_CHAR(p_customer_id),
            p_operation_name => c_op_create_corporate,
            p_new_data       => JSON_OBJECT(
                'customer_id'
                    VALUE p_customer_id,
                'customer_no'
                    VALUE p_customer_no,
                'customer_type'
                    VALUE c_customer_type_corporate,
                'status'
                    VALUE c_status_active,
                'company_id'
                    VALUE p_company_id,
                'company_name'
                    VALUE l_company_name,
                'tax_number'
                    VALUE l_tax_number,
                'registration_number'
                    VALUE l_registration_number
                RETURNING VARCHAR2
            )
        );

    EXCEPTION
        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name => c_op_create_corporate,
                p_entity_name    => c_entity_customers,
                p_entity_id      => TO_CHAR(p_customer_id),
                p_context_data   => JSON_OBJECT(
                    'company_id'
                        VALUE p_company_id,
                    'tax_number'
                        VALUE l_tax_number,
                    'registration_number'
                        VALUE l_registration_number
                    RETURNING VARCHAR2
                ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END create_corporate_customer;


    ------------------------------------------------------------------
    -- Update customer status
    ------------------------------------------------------------------

    PROCEDURE update_customer_status (
        p_customer_id IN customers.customer_id%TYPE,
        p_new_status  IN customers.status%TYPE
    )
    IS
        l_current_status
            customers.status%TYPE;

        l_new_status
            customers.status%TYPE;

        l_customer_no
            customers.customer_no%TYPE;
    BEGIN
        l_new_status :=
            UPPER(TRIM(p_new_status));

        IF p_customer_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20121,
                'Customer ID cannot be null.'
            );
        END IF;

        IF l_new_status IS NULL
           OR l_new_status NOT IN (
               c_status_active,
               c_status_blocked,
               c_status_closed
           )
        THEN
            RAISE_APPLICATION_ERROR(
                -20122,
                'Customer status must be ACTIVE, BLOCKED, or CLOSED.'
            );
        END IF;

        BEGIN
            SELECT customer_no,
                   status
            INTO l_customer_no,
                 l_current_status
            FROM customers
            WHERE customer_id = p_customer_id
            FOR UPDATE;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20123,
                    'Customer not found.'
                );
        END;

        IF l_current_status = l_new_status THEN
            RAISE_APPLICATION_ERROR(
                -20124,
                'Customer already has the requested status.'
            );
        END IF;

        IF l_current_status = c_status_closed THEN
            RAISE_APPLICATION_ERROR(
                -20125,
                'A closed customer cannot be reactivated or blocked.'
            );
        END IF;

        UPDATE customers
        SET status     = l_new_status,
            updated_at = CURRENT_TIMESTAMP,
            updated_by = SYS_CONTEXT(
                'USERENV',
                'SESSION_USER'
            )
        WHERE customer_id = p_customer_id;

        pkg_audit.log_action(
            p_action_type    => 'UPDATE',
            p_entity_name    => c_entity_customers,
            p_entity_id      => TO_CHAR(p_customer_id),
            p_operation_name => c_op_update_status,
            p_old_data       => JSON_OBJECT(
                'customer_id'
                    VALUE p_customer_id,
                'customer_no'
                    VALUE l_customer_no,
                'status'
                    VALUE l_current_status
                RETURNING VARCHAR2
            ),
            p_new_data       => JSON_OBJECT(
                'customer_id'
                    VALUE p_customer_id,
                'customer_no'
                    VALUE l_customer_no,
                'status'
                    VALUE l_new_status
                RETURNING VARCHAR2
            ),
            p_context_data   => JSON_OBJECT(
                'transition'
                    VALUE l_current_status
                          || ' -> '
                          || l_new_status
                RETURNING VARCHAR2
            )
        );

    EXCEPTION
        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name => c_op_update_status,
                p_entity_name    => c_entity_customers,
                p_entity_id      => TO_CHAR(p_customer_id),
                p_context_data   => JSON_OBJECT(
                    'customer_id'
                        VALUE p_customer_id,
                    'requested_status'
                        VALUE p_new_status,
                    'normalized_status'
                        VALUE l_new_status,
                    'current_status'
                        VALUE l_current_status
                    RETURNING VARCHAR2
                ),
                p_severity       => 'ERROR'
            );

            RAISE;
    END update_customer_status;


    ------------------------------------------------------------------
    -- Get customer information
    ------------------------------------------------------------------

    PROCEDURE get_customer_info (
        p_customer_id IN  customers.customer_id%TYPE,
        p_result      OUT SYS_REFCURSOR
    )
    IS
        l_customer_exists PLS_INTEGER;
    BEGIN
        IF p_customer_id IS NULL THEN
            RAISE_APPLICATION_ERROR(
                -20131,
                'Customer ID cannot be null.'
            );
        END IF;

        BEGIN
            SELECT 1
            INTO l_customer_exists
            FROM customers
            WHERE customer_id = p_customer_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(
                    -20132,
                    'Customer not found.'
                );
        END;

        OPEN p_result FOR
            WITH
            account_summary AS (
                SELECT
                    customer_id,
                    COUNT(*) AS total_accounts,
                    NVL(SUM(balance), 0) AS total_balance
                FROM accounts
                WHERE customer_id = p_customer_id
                GROUP BY customer_id
            ),
            card_summary AS (
                SELECT
                    a.customer_id,
                    COUNT(c.card_id) AS total_cards
                FROM accounts a
                JOIN cards c
                  ON c.account_id = a.account_id
                WHERE a.customer_id = p_customer_id
                GROUP BY a.customer_id
            ),
            transaction_summary AS (
                SELECT
                    customer_id,
                    COUNT(*) AS total_transactions,
                    MAX(transaction_date) AS last_transaction_date
                FROM (
                    SELECT
                        a.customer_id,
                        t.transaction_id,
                        t.transaction_date
                    FROM accounts a
                    JOIN transactions t
                      ON t.source_account_id = a.account_id
                    WHERE a.customer_id = p_customer_id

                    UNION

                    SELECT
                        a.customer_id,
                        t.transaction_id,
                        t.transaction_date
                    FROM accounts a
                    JOIN transactions t
                      ON t.target_account_id = a.account_id
                    WHERE a.customer_id = p_customer_id
                )
                GROUP BY customer_id
            ),
            beneficiary_summary AS (
                SELECT
                    customer_id,
                    COUNT(*) AS total_beneficiaries
                FROM beneficiaries
                WHERE customer_id = p_customer_id
                GROUP BY customer_id
            )
            SELECT
                c.customer_id,
                c.customer_no,
                c.customer_type,
                c.status,
                c.created_at,
                ic.first_name,
                ic.last_name,
                ic.national_id,
                ic.birth_date,
                cmp.company_name,
                cc.tax_number,
                cc.registration_number,
                NVL(acc.total_accounts, 0) AS total_accounts,
                NVL(acc.total_balance, 0) AS total_balance,
                NVL(crd.total_cards, 0) AS total_cards,
                NVL(txn.total_transactions, 0) AS total_transactions,
                txn.last_transaction_date,
                NVL(ben.total_beneficiaries, 0) AS total_beneficiaries
            FROM customers c
            LEFT JOIN individual_customers ic
              ON ic.customer_id = c.customer_id
            LEFT JOIN corporate_customers cc
              ON cc.customer_id = c.customer_id
            LEFT JOIN companies cmp
              ON cmp.company_id = cc.company_id
            LEFT JOIN account_summary acc
              ON acc.customer_id = c.customer_id
            LEFT JOIN card_summary crd
              ON crd.customer_id = c.customer_id
            LEFT JOIN transaction_summary txn
              ON txn.customer_id = c.customer_id
            LEFT JOIN beneficiary_summary ben
              ON ben.customer_id = c.customer_id
            WHERE c.customer_id = p_customer_id;

    EXCEPTION
        WHEN OTHERS THEN
            pkg_error_log.log_error(
                p_operation_name => c_op_get_customer_info,
                p_entity_name    => c_entity_customers,
                p_entity_id      => TO_CHAR(p_customer_id),
                p_context_data   => JSON_OBJECT(
                    'customer_id' VALUE p_customer_id
                    RETURNING VARCHAR2
                ),
                p_severity       => 'ERROR'
            );
            RAISE;
    END get_customer_info;

END pkg_customer_management;
