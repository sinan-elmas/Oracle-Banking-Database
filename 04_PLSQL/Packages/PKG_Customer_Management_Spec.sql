-- ============================================================================
-- Package Specification: PKG_CUSTOMER_MANAGEMENT
-- Project              : Oracle Banking Database
-- Database             : Oracle AI Database 26ai Enterprise Edition
-- Version              : 23.26.1.0.0
-- Schema               : BANKING_DB
--
-- Purpose
--   Defines the public interface for customer registration, maintenance,
--   status management, and customer information retrieval.
--
-- Responsibilities
--   * Register individual and corporate customers
--   * Maintain customer status
--   * Retrieve customer information
--   * Validate customer-related business rules
--
-- Transaction Policy
--   * This package does not issue COMMIT or ROLLBACK.
--   * Transaction control remains with the calling application or script.
--
-- Dependencies
--   * CUSTOMERS and related master tables
--   * PKG_AUDIT
--   * PKG_ERROR_LOG
-- ============================================================================

create or replace PACKAGE pkg_customer_management AS

    PROCEDURE create_individual_customer (
        p_first_name   IN  individual_customers.first_name%TYPE,
        p_last_name    IN  individual_customers.last_name%TYPE,
        p_national_id  IN  individual_customers.national_id%TYPE,
        p_birth_date   IN  individual_customers.birth_date%TYPE,
        p_customer_id  OUT customers.customer_id%TYPE,
        p_customer_no  OUT customers.customer_no%TYPE
    );

    PROCEDURE create_corporate_customer (
        p_company_id           IN  corporate_customers.company_id%TYPE,
        p_tax_number           IN  corporate_customers.tax_number%TYPE,
        p_registration_number  IN  corporate_customers.registration_number%TYPE,
        p_customer_id          OUT customers.customer_id%TYPE,
        p_customer_no          OUT customers.customer_no%TYPE
    );

    PROCEDURE update_customer_status (
        p_customer_id IN customers.customer_id%TYPE,
        p_new_status  IN customers.status%TYPE
    );

    PROCEDURE get_customer_info (
        p_customer_id IN  customers.customer_id%TYPE,
        p_result      OUT SYS_REFCURSOR
    );

END pkg_customer_management;
