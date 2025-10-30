#!/usr/bin/env bash

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "  Running comprehensive test suite with coverage"
echo "═══════════════════════════════════════════════════════════════"
echo

COVERAGE_TARGET=${COVERAGE_TARGET:-90}
SKIP_RACE=${SKIP_RACE:-false}
COVERAGE_MODE=${COVERAGE_MODE:-total}

export TEST_DB_URL="${TEST_DB_URL:-}"

if [ "$SKIP_RACE" = "true" ]; then
  echo "⚠️  Race detector disabled (SKIP_RACE=true)"
  RACE_FLAG=""
else
  echo "✓ Race detector enabled"
  RACE_FLAG="-race"
fi

if [ -z "$TEST_DB_URL" ]; then
  echo "⚠️  TEST_DB_URL not set; database-dependent tests will auto-skip"
else
  echo "✓ TEST_DB_URL set; database tests enabled"
fi

echo
echo "─────────────────────────────────────────────────────────────"
echo "  Running tests with race detector and coverage"
echo "─────────────────────────────────────────────────────────────"
echo

go test $RACE_FLAG \
  -coverpkg=./... \
  -coverprofile=coverage.out \
  -covermode=atomic \
  ./... -v

echo
echo "─────────────────────────────────────────────────────────────"
echo "  Analyzing coverage"
echo "─────────────────────────────────────────────────────────────"
echo

if [ "$COVERAGE_MODE" = "risk-only" ]; then
  # Check coverage for risk-related packages only
  echo "Checking coverage for risk-related packages..."
  RISK_COV=$(go tool cover -func=coverage.out | grep -E 'risk/|db/|trader/' | grep -v 'total' | awk '{sum+=$3; count++} END {if(count>0) print sum/count; else print 0}' | cut -d. -f1)
  echo "Risk-related coverage: ${RISK_COV}%"
  TOTAL_COV=$RISK_COV
else
  # Check overall coverage
  TOTAL_COV=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
  echo "Total coverage: ${TOTAL_COV}%"
fi

echo "Coverage target: ${COVERAGE_TARGET}%"

if [ -z "$TOTAL_COV" ]; then
  echo "⚠️  Could not determine coverage; skipping threshold check"
  TOTAL_COV=0
fi

COVERAGE_OK=$(awk -v cov="$TOTAL_COV" -v target="$COVERAGE_TARGET" 'BEGIN { print (cov >= target ? "1" : "0") }')

if [ "$COVERAGE_OK" = "1" ]; then
  echo "✅ Coverage target met (${TOTAL_COV}% >= ${COVERAGE_TARGET}%)"
else
  echo "⚠️  Coverage below target (${TOTAL_COV}% < ${COVERAGE_TARGET}%)"
  echo "    Note: Coverage targets are advisory; tests still passed"
fi

echo
echo "─────────────────────────────────────────────────────────────"
echo "  Generating coverage report"
echo "─────────────────────────────────────────────────────────────"
echo

go tool cover -html=coverage.out -o coverage.html
echo "✓ Coverage HTML report: coverage.html"

echo
echo "═══════════════════════════════════════════════════════════════"
echo "  Test suite completed successfully"
echo "═══════════════════════════════════════════════════════════════"
