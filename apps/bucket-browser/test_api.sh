#!/bin/bash
# Simple smoke test for the Bucket Browser.

set -e

API_URL="${API_URL:-http://localhost:8080}"

echo "Testing Bucket Browser at $API_URL"
echo "========================================"

echo ""
echo "1. Health check..."
curl -s "$API_URL/health" | jq .

echo ""
echo "2. Readiness check (needs a reachable bucket)..."
curl -s "$API_URL/ready" | jq .

echo ""
echo "3. Bucket listing (HTML) — first lines..."
curl -s "$API_URL/" | head -20

echo ""
echo "========================================"
echo "Open $API_URL/ in a browser to explore the bucket."
