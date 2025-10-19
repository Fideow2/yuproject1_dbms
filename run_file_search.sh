#!/bin/bash
if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi
set -euo pipefail
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
cd "$SCRIPT_DIR"
CSV_FILE="${CSV_FILE:-1_data/movies.csv}"
COLUMN="${COLUMN:-title}"
DEFAULT_KEYWORDS=("XXX" "STAR")
RUNS="${RUNS:-3}"
CASE_SENSITIVE="${CASE_SENSITIVE:-0}"
LIMIT="${LIMIT:-}"
LOG_FILE="${LOG_FILE:-file_search_results.log}"
JAVA_OUT_DIR="${JAVA_OUT_DIR:-out}"
CPP_BUILD_DIR="${CPP_BUILD_DIR:-build}"
CPP_BIN="${CPP_BIN:-${CPP_BUILD_DIR}/file_search_standalone}"
JAVA_SRC="3_java_src/FileSearchStandalone.java"
CPP_SRC="3_cpp_src/file_search_standalone.cpp"
info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; }
append_log() { echo -e "$*" >> "$LOG_FILE"; }
run_and_log() {
  append_log "\$ $1"
  "${@:2}" 2>&1 | tee -a "$LOG_FILE"
}
usage() {
  cat <<EOF
Usage: $(basename "$0") [keyword1 keyword2 ...]

Environment overrides:
  CSV_FILE=<path>          CSV file with header (default: 1_data/movies.csv)
  COLUMN=<name>            Header column to search (default: title)
  RUNS=<N>                 Number of runs per keyword (default: 3)
  CASE_SENSITIVE=1         Enable case-sensitive matching (default: off)
  LIMIT=<N>                Scan only first N data rows (default: unset)
  LOG_FILE=<path>          Output log file (default: file_search_results.log)

Examples:
  $(basename "$0")                   # runs with defaults: keywords [XXX STAR], 3 runs
  $(basename "$0") XXX               # run only "XXX"
  RUNS=5 $(basename "$0") STAR       # run "STAR" for 5 repetitions
  CASE_SENSITIVE=1 $(basename "$0")  # case-sensitive runs
  LIMIT=500000 $(basename "$0")      # limit scans for quicker trials
EOF
}
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
KEYWORDS=()
if [[ "$#" -gt 0 ]]; then
  KEYWORDS=("$@")
else
  KEYWORDS=("${DEFAULT_KEYWORDS[@]}")
fi
if [[ ! -f "$CSV_FILE" ]]; then
  error "CSV file not found: $CSV_FILE"
  exit 1
fi
if [[ ! -f "$JAVA_SRC" ]]; then
  error "Java source not found: $JAVA_SRC"
  exit 1
fi
if [[ ! -f "$CPP_SRC" ]]; then
  warn "C++ source not found: $CPP_SRC (C++ tests will be skipped)"
fi
info "Appending results to: $LOG_FILE"
{
  echo "================================================================================"
  echo "[run_file_search.sh] $(date -Iseconds)"
  echo "Repo root     : $SCRIPT_DIR"
  echo "CSV file      : $CSV_FILE"
  echo "Column        : $COLUMN"
  echo "Runs per kw   : $RUNS"
  echo "Case-sensitive: $CASE_SENSITIVE"
  echo "Limit         : ${LIMIT:-<unset>}"
  echo "--- System ---"
  uname -a || true
  echo "--- Java ---"
  (java -version) 2>&1 | sed 's/^/  /' || true
  (javac -version) 2>&1 | sed 's/^/  /' || true
  echo "--- g++ ---"
  (g++ --version | head -n1) 2>/dev/null | sed 's/^/  /' || echo "  g++ not found or unavailable"
  echo "--- CSV stats ---"
  (wc -l "$CSV_FILE" | sed 's/^/  /') || true
  echo "================================================================================"
} >> "$LOG_FILE"
info "Compiling Java: $JAVA_SRC"
mkdir -p "$JAVA_OUT_DIR"
javac -d "$JAVA_OUT_DIR" "$JAVA_SRC"
append_log ""
append_log "---- Java compile complete ----"
append_log "  Source: $JAVA_SRC"
append_log "  Out   : $JAVA_OUT_DIR"
CPP_AVAILABLE=0
if [[ -f "$CPP_SRC" ]]; then
  if command -v g++ >/dev/null 2>&1; then
    info "Compiling C++: $CPP_SRC"
    mkdir -p "$CPP_BUILD_DIR"
    g++ -O2 -std=c++17 -o "$CPP_BIN" "$CPP_SRC"
    CPP_AVAILABLE=1
    append_log ""
    append_log "---- C++ compile complete ----"
    append_log "  Source: $CPP_SRC"
    append_log "  Bin   : $CPP_BIN"
  else
    warn "g++ not found; skipping C++ runs."
    append_log ""
    append_log "---- C++ compile skipped (g++ not found) ----"
  fi
fi
CASE_FLAG=()
if [[ "$CASE_SENSITIVE" == "1" ]]; then
  CASE_FLAG=(--case-sensitive)
fi
LIMIT_FLAG=()
if [[ -n "${LIMIT:-}" ]]; then
  LIMIT_FLAG=(--limit "$LIMIT")
fi
COLUMN_FLAG=(--column "$COLUMN")
for kw in "${KEYWORDS[@]}"; do
  append_log ""
  append_log "================================================================================"
  append_log "[Keyword] $kw"
  append_log "================================================================================"
  for ((i=1; i<=RUNS; i++)); do
    append_log ""
    append_log "[Java] Run #$i - keyword: $kw"
    CMD_JAVA="java -cp $JAVA_OUT_DIR FileSearchStandalone --file $CSV_FILE --keyword \"$kw\" ${CASE_FLAG[*]} ${LIMIT_FLAG[*]} ${COLUMN_FLAG[*]}"
    JAVA_ARGS=(java -cp "$JAVA_OUT_DIR" FileSearchStandalone --file "$CSV_FILE" --keyword "$kw" ${CASE_FLAG[@]+"${CASE_FLAG[@]}"} ${LIMIT_FLAG[@]+"${LIMIT_FLAG[@]}"} ${COLUMN_FLAG[@]+"${COLUMN_FLAG[@]}"} )
    run_and_log "$CMD_JAVA" "${JAVA_ARGS[@]}"
  done
  if [[ "$CPP_AVAILABLE" -eq 1 ]]; then
    for ((i=1; i<=RUNS; i++)); do
      append_log ""
      append_log "[C++] Run #$i - keyword: $kw"
      CMD_CPP="$CPP_BIN --file $CSV_FILE --keyword \"$kw\" ${CASE_FLAG[*]} ${LIMIT_FLAG[*]} ${COLUMN_FLAG[*]}"
      CPP_ARGS=("$CPP_BIN" --file "$CSV_FILE" --keyword "$kw" ${CASE_FLAG[@]+"${CASE_FLAG[@]}"} ${LIMIT_FLAG[@]+"${LIMIT_FLAG[@]}"} ${COLUMN_FLAG[@]+"${COLUMN_FLAG[@]}"} )
      run_and_log "$CMD_CPP" "${CPP_ARGS[@]}"
    done
  else
    append_log ""
    append_log "[C++] Skipped (binary unavailable)"
  fi
done
append_log ""
append_log "################# File-side experiments completed at $(date -Iseconds) #################"
info "All done. Results appended to: $LOG_FILE"
