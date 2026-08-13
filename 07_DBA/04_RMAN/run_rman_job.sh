#!/bin/bash
#
# Script  : run_rman_job.sh
# Project : Oracle Banking Database - DBA Lab
# Purpose : Executes an RMAN command file with timestamped logging and error checks.
# Run As  : Oracle software owner
# Usage   : ./run_rman_job.sh <rman_script.rman>
# Example : ./run_rman_job.sh 02_full_database_backup.rman
#
# Notes
# -----
# - ORACLE_SID and ORACLE_HOME must be configured before execution.
# - RMAN connects to the target database using operating-system authentication.
# - Log files are written under the logs directory beside this script.

set -u
set -o pipefail

print_usage() {
    echo "Usage: $0 <rman_script.rman>"
    echo "Example: $0 02_full_database_backup.rman"
}

fail() {
    echo "ERROR: $1" >&2
    exit "${2:-1}"
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" \
    || fail "Cannot determine the script directory." 8

readonly PROJECT_DIR="${SCRIPT_DIR}"
readonly LOG_DIR="${PROJECT_DIR}/logs"
readonly ERROR_PATTERN='RMAN-00569|RMAN-00558|RMAN-01009|RMAN-03002|ORA-[0-9]{5}|LRM-[0-9]{5}|SP2-[0-9]{4}'

if [ "$#" -ne 1 ]; then
    print_usage
    exit 1
fi

readonly SCRIPT_NAME="$1"
if [ "$(basename -- "${SCRIPT_NAME}")" != "${SCRIPT_NAME}" ]; then
    fail "Provide only a file name from the RMAN module directory." 2
fi

case "${SCRIPT_NAME}" in
    *.rman) ;;
    *) fail "The input file must have a .rman extension." 2 ;;
esac

readonly SCRIPT_PATH="${PROJECT_DIR}/${SCRIPT_NAME}"

[ -f "${SCRIPT_PATH}" ] || fail "RMAN script not found: ${SCRIPT_PATH}" 3
[ -r "${SCRIPT_PATH}" ] || fail "RMAN script is not readable: ${SCRIPT_PATH}" 4

[ -n "${ORACLE_SID:-}" ] || fail "ORACLE_SID is not set." 5
[ -n "${ORACLE_HOME:-}" ] || fail "ORACLE_HOME is not set." 6
[ -x "${ORACLE_HOME}/bin/rman" ] || fail "RMAN executable not found: ${ORACLE_HOME}/bin/rman" 7

mkdir -p "${LOG_DIR}" || fail "Cannot create log directory: ${LOG_DIR}" 8

readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly JOB_NAME="$(basename "${SCRIPT_NAME}" .rman)"
readonly LOG_FILE="${LOG_DIR}/${JOB_NAME}_${TIMESTAMP}.log"

echo "============================================================"
echo "RMAN Job Started : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Oracle SID       : ${ORACLE_SID}"
echo "Script           : ${SCRIPT_PATH}"
echo "Log File         : ${LOG_FILE}"
echo "============================================================"

set +e
"${ORACLE_HOME}/bin/rman" target / \
    cmdfile="${SCRIPT_PATH}" \
    log="${LOG_FILE}"
readonly RMAN_EXIT_CODE=$?
set -e

if grep -Eiq "${ERROR_PATTERN}" "${LOG_FILE}"; then
    readonly LOG_ERROR_FOUND=1
else
    readonly LOG_ERROR_FOUND=0
fi

echo
echo "============================================================"
echo "RMAN Job Finished: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "RMAN Exit Code   : ${RMAN_EXIT_CODE}"
echo "Log Error Check  : $([ "${LOG_ERROR_FOUND}" -eq 0 ] && echo "PASSED" || echo "FAILED")"
echo "============================================================"

if [ "${RMAN_EXIT_CODE}" -ne 0 ] || [ "${LOG_ERROR_FOUND}" -ne 0 ]; then
    echo
    echo "RMAN job failed. Matching error lines:"
    grep -Ein "${ERROR_PATTERN}" "${LOG_FILE}" || true
    echo
    echo "Review the complete log: ${LOG_FILE}"
    exit 10
fi

echo
echo "RMAN job completed successfully."
echo "Log saved to: ${LOG_FILE}"
exit 0
