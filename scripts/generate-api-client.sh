#!/bin/bash
# Generate API client code from OpenAPI specification
# Uses openapi-generator-cli to generate Dart/Flutter client

set -e

SPEC_FILE="api-spec/openapi.json"
OUTPUT_DIR="lib/api/generated"

if [ ! -f "$SPEC_FILE" ]; then
    echo "❌ OpenAPI spec not found at $SPEC_FILE"
    echo "Run: ./scripts/fetch-api-spec.sh first"
    exit 1
fi

echo "🔧 Generating Dart API client for Flutter..."
echo "📦 Using openapi-generator-cli with dart-dio generator"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Generate Dart client with openapi-generator-cli
npx @openapitools/openapi-generator-cli generate \
    -i "$SPEC_FILE" \
    -g dart-dio \
    -o "$OUTPUT_DIR" \
    --additional-properties=pubName=pocket_guide_api \
    --additional-properties=useEnumExtension=true \
    --additional-properties=ensureUniqueParams=true \
    --additional-properties=legacyDiscriminatorBehavior=false

echo ""
echo "✅ Dart client generated at $OUTPUT_DIR"
echo ""
echo "🔧 Fixing SDK version and running build_runner..."

# Fix SDK version to match main project
sed -i '' "s/sdk: '>=2.18.0 <4.0.0'/sdk: ^3.11.0/" "$OUTPUT_DIR/pubspec.yaml"

# Fix TourDetail metadata assignment issue
sed -i '' 's/result.metadata = valueDes;/result.metadata.replace(valueDes);/' "$OUTPUT_DIR/lib/src/model/tour_detail.dart"

# Install dependencies and run build_runner
cd "$OUTPUT_DIR"
flutter pub get > /dev/null 2>&1
flutter pub run build_runner build --delete-conflicting-outputs > /dev/null 2>&1
cd - > /dev/null

echo "✅ Build runner completed"
echo ""
echo "📝 Import and use: import 'package:pocket_guide_mobile/api/generated/lib/pocket_guide_api.dart';"
echo ""
echo "🎉 Generation complete!"
echo ""
echo "Next steps:"
echo "  1. Run 'flutter pub get' to install generated dependencies"
echo "  2. Use the generated API client in your Flutter app"
