#!/bin/bash
# Generate API client code from OpenAPI specification
# Uses swagger-typescript-api (JavaScript-native, no Java required!)

set -e

SPEC_FILE="api-spec/openapi.json"
OUTPUT_DIR="src/api/generated"

if [ ! -f "$SPEC_FILE" ]; then
    echo "❌ OpenAPI spec not found at $SPEC_FILE"
    echo "Run: ./scripts/fetch-api-spec.sh first"
    exit 1
fi

echo "🔧 Generating TypeScript API client..."
echo "📦 Using swagger-typescript-api (no Java required!)"

# Generate TypeScript client with swagger-typescript-api
npx swagger-typescript-api generate \
    --path "$SPEC_FILE" \
    --output "$OUTPUT_DIR" \
    --name "api-client.ts" \
    --axios \
    --modular \
    --extract-request-params \
    --extract-request-body \
    --single-http-client \
    --unwrap-response-data \
    --clean-output

echo ""
echo "✅ TypeScript client generated at $OUTPUT_DIR"
echo "📝 Import and use: import { Api } from './api/generated/api-client'"
echo ""
echo "🎉 Generation complete!"
