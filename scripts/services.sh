#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="${ROOT_DIR}/.run"
LOG_DIR="${ROOT_DIR}/.logs"

BACKEND_PID_FILE="${RUN_DIR}/backend.pid"
FRONTEND_PID_FILE="${RUN_DIR}/frontend.pid"
CLINICIAN_FRONTEND_PID_FILE="${RUN_DIR}/clinician-frontend.pid"
BACKEND_LOG_FILE="${LOG_DIR}/backend.log"
FRONTEND_LOG_FILE="${LOG_DIR}/frontend.log"
CLINICIAN_FRONTEND_LOG_FILE="${LOG_DIR}/clinician-frontend.log"

usage() {
  echo "Usage: ./scripts/services.sh {start|stop|restart|status}"
}

is_running() {
  local pid="$1"
  kill -0 "${pid}" >/dev/null 2>&1
}

start_service() {
  local name="$1"
  local workdir="$2"
  local command="$3"
  local pid_file="$4"
  local log_file="$5"

  if [[ -f "${pid_file}" ]]; then
    local existing_pid
    existing_pid="$(<"${pid_file}")"
    if is_running "${existing_pid}"; then
      echo "${name} is already running (pid ${existing_pid})"
      return 0
    fi
    rm -f "${pid_file}"
  fi

  echo "Starting ${name}..."
  (
    cd "${workdir}"
    nohup ${command} >>"${log_file}" 2>&1 &
    echo $! >"${pid_file}"
  )

  local new_pid
  new_pid="$(<"${pid_file}")"
  echo "${name} started (pid ${new_pid})"
}

stop_service() {
  local name="$1"
  local pid_file="$2"

  if [[ ! -f "${pid_file}" ]]; then
    echo "${name} is not running"
    return 0
  fi

  local pid
  pid="$(<"${pid_file}")"

  if ! is_running "${pid}"; then
    echo "${name} was not running (cleaning stale pid file)"
    rm -f "${pid_file}"
    return 0
  fi

  echo "Stopping ${name} (pid ${pid})..."
  kill "${pid}" >/dev/null 2>&1 || true

  local attempts=0
  while is_running "${pid}" && [[ ${attempts} -lt 20 ]]; do
    sleep 0.2
    attempts=$((attempts + 1))
  done

  if is_running "${pid}"; then
    echo "${name} did not stop gracefully; force killing..."
    kill -9 "${pid}" >/dev/null 2>&1 || true
  fi

  rm -f "${pid_file}"
  echo "${name} stopped"
}

status_service() {
  local name="$1"
  local pid_file="$2"

  if [[ ! -f "${pid_file}" ]]; then
    echo "${name}: stopped"
    return 0
  fi

  local pid
  pid="$(<"${pid_file}")"
  if is_running "${pid}"; then
    echo "${name}: running (pid ${pid})"
  else
    echo "${name}: stopped (stale pid file)"
  fi
}

main() {
  local action="${1:-}"
  mkdir -p "${RUN_DIR}" "${LOG_DIR}"

  case "${action}" in
    start)
      start_service "backend" "${ROOT_DIR}" "npm run dev" "${BACKEND_PID_FILE}" "${BACKEND_LOG_FILE}"
      start_service "frontend" "${ROOT_DIR}/admin-console" "npm run dev" "${FRONTEND_PID_FILE}" "${FRONTEND_LOG_FILE}"
      start_service "clinician-frontend" "${ROOT_DIR}/clinician-console" "npm run dev" "${CLINICIAN_FRONTEND_PID_FILE}" "${CLINICIAN_FRONTEND_LOG_FILE}"
      ;;
    stop)
      stop_service "clinician-frontend" "${CLINICIAN_FRONTEND_PID_FILE}"
      stop_service "frontend" "${FRONTEND_PID_FILE}"
      stop_service "backend" "${BACKEND_PID_FILE}"
      ;;
    restart)
      "$0" stop
      "$0" start
      ;;
    status)
      status_service "backend" "${BACKEND_PID_FILE}"
      status_service "frontend" "${FRONTEND_PID_FILE}"
      status_service "clinician-frontend" "${CLINICIAN_FRONTEND_PID_FILE}"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
