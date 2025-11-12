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
sql_dir="/workspace/sql"

# collect files into an array so we can test for emptiness
files=( "$sql_dir"/query*.sql )

if [ ${#files[@]} -eq 0 ]; then
  echo "No query*.sql files found in $sql_dir" >&2
  exit 1
fi

for query_file in "${files[@]}"; do
  test_name=$(basename "$query_file" .sql)
  expected_file="$sql_dir/expected_sql1.csv"

  echo "🧪 Running ${test_name}.sql"

  docker exec oracle-db sqlplus "$ORACLE_USER/$ORACLE_PASS" <<EOF > /workspace/result_sql1.csv
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 VERIFY OFF ECHO OFF
@/workspace/sql/${test_name}.sql
EXIT;
EOF

  sed -i 's/^[[:space:]]*//;s/[[:space:]]*$//' /workspace/result_sql1.csv

  if diff -q /workspace/result_sql1.csv expected_sql1.csv > /dev/null; then
    echo "✅ ${test_name} passed"
  else
    echo "❌ ${test_name} failed"
    diff /workspace/result_sql1.csv expected_sql1.csv || true
    exit 1
  fi
done
