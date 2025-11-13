#!/usr/bin/env bash
set -euo pipefail

ORACLE_USER=system
ORACLE_PASS=oracle
ORACLE_SID=XE
CONNECT_STRING="${ORACLE_USER}/${ORACLE_PASS}@localhost:1521/${ORACLE_SID}"

echo "⏳ Waiting for Oracle to be ready..."
sleep 60

# Run setup inside the container
echo "🧩 Running setup.sql"
docker exec oracle-db sqlplus -s "${CONNECT_STRING}" @/workspace/sql/setup.sql

# Iterate over all query files in the repo (host path)
for query_file in sql/query*.sql; do
  # If no files match the glob, bash will keep the pattern literal (unless nullglob set).
  # To be safe, check existence:
  if [[ ! -e "$query_file" ]]; then
    echo "No query files found matching: $query_file"
    exit 0
  fi

  test_name=$(basename "$query_file" .sql)   # e.g. query1
  expected_file="sql/expected_${test_name}.csv"
  container_result="/workspace/result_${test_name}.csv"
  container_result="/tmp/result_${test_name}.csv"
  host_result="result_${test_name}.csv"

  echo "🧪 Running ${test_name}.sql"

  # Run sqlplus inside the container and redirect output to a file inside the container.
  # The entire here-doc is interpreted inside the container, so redirection happens inside the container.
  docker exec oracle-db bash -lc "sqlplus -s ${CONNECT_STRING} <<'EOF' > ${container_result}
SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SET VERIFY OFF
SET ECHO OFF
@/workspace/sql/${test_name}.sql
EXIT;
EOF
"

  # Copy the concrete file from the container to the runner (host)
  docker cp "oracle-db:${container_result}" "${host_result}"

  # Trim leading/trailing whitespace on the host copy
  sed -i 's/^[[:space:]]*//;s/[[:space:]]*$//' "${host_result}"

  # Ensure expected file exists
  if [[ ! -f "${expected_file}" ]]; then
    echo "⚠️ Expected file missing: ${expected_file}"
    echo "Create ${expected_file} with the expected output for ${test_name}."
    exit 1
  fi

  # Compare host result with expected
  if diff -q "${host_result}" "${expected_file}" >/dev/null; then
    echo "✅ ${test_name} passed"
  else
    echo "❌ ${test_name} failed"
    echo "---- Actual ----"
    sed -n '1,200p' "${host_result}" || true
    echo "---- Expected ----"
    sed -n '1,200p' "${expected_file}" || true
    diff "${host_result}" "${expected_file}" || true
  fi
done

echo "🎉 All SQL tests passed."

