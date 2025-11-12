#!/usr/bin/env bash
set -e

ORACLE_USER=system
ORACLE_PASS=oracle
ORACLE_SID=XE
CONNECT_STRING="$ORACLE_USER/$ORACLE_PASS@localhost:1521/$ORACLE_SID"

echo "⏳ Waiting for Oracle to be ready..."
sleep 60

# Run setup
echo "🧩 Running setup.sql"
docker exec oracle-db sqlplus "$ORACLE_USER/$ORACLE_PASS" @/workspace/sql/setup.sql

# Iterate over all query files
for query_file in /workspace/sql/query*.sql; do
  test_name=$(basename "$query_file" .sql)
  expected_file="/workspace/sql/expected_${test_name}.csv"
  echo "🧪 Running ${test_name}.sql"

  docker exec oracle-db sqlplus "$ORACLE_USER/$ORACLE_PASS" <<EOF > /workspace/result_${test_name}.csv
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 VERIFY OFF ECHO OFF
@/workspace/sql/${test_name}.sql
EXIT;
EOF

  sed -i 's/^[[:space:]]*//;s/[[:space:]]*$//' /workspace/result_${test_name}.csv

  if diff -q /workspace/result_${test_name}.csv "$expected_file" > /dev/null; then
    echo "✅ ${test_name} passed"
  else
    echo "❌ ${test_name} failed"
    diff /workspace/result_${test_name}.csv "$expected_file" || true
    exit 1
  fi
done
