#!/bin/bash
# Fetch the latest OpenAPI specification from the backend API

set -e

API_URL="${API_URL:-http://localhost:8000}"
SPEC_FILE="api-spec/openapi.json"

echo "📡 Fetching OpenAPI spec from $API_URL/openapi.json..."

if curl -f -s "$API_URL/openapi.json" -o "$SPEC_FILE"; then
    echo "✅ OpenAPI spec saved to $SPEC_FILE"

    # Extract version and endpoint count
    VERSION=$(cat "$SPEC_FILE" | python3 -c "import sys, json; print(json.load(sys.stdin)['info']['version'])" 2>/dev/null || echo "unknown")
    ENDPOINTS=$(cat "$SPEC_FILE" | python3 -c "import sys, json; print(len(json.load(sys.stdin)['paths']))" 2>/dev/null || echo "unknown")

    echo "📋 API Version: $VERSION"
    echo "📋 Total Endpoints: $ENDPOINTS"
else
    echo "❌ Failed to fetch OpenAPI spec. Is the API server running at $API_URL?"
    exit 1
fi
