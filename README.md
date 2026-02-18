# Pocket Guide Mobile App

Cross-platform mobile application for customized tour generation.

## Project Structure

```
pocket-guide-mobile-app/
├── api-spec/
│   └── openapi.json          # OpenAPI specification from backend
├── scripts/
│   ├── fetch-api-spec.sh     # Fetch latest API spec
│   └── generate-api-client.sh # Generate type-safe client
├── src/
│   └── api/
│       └── generated/        # Auto-generated API client (gitignored)
└── package.json
```

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Fetch Latest API Spec

Make sure the backend API is running at `http://localhost:8000`, then:

```bash
npm run fetch-api
```

Or from a different URL:
```bash
API_URL=https://api.pocket-guide.com npm run fetch-api
```

### 3. Generate API Client

Generate TypeScript client (NO JAVA REQUIRED!):
```bash
npm run generate-api
```

This uses `swagger-typescript-api` - a JavaScript-native code generator.

### 4. Update Everything (Recommended Workflow)

Fetch the latest spec and regenerate client in one command:
```bash
npm run update-api
```

## Usage in App Code

### React Native / TypeScript Example

```typescript
import { HttpClient } from './api/generated/http-client'
import { Tour } from './api/generated/Tour'
import { Tours } from './api/generated/Tours'
import type { TourGenerationRequest } from './api/generated/data-contracts'

// Create HTTP client
const httpClient = new HttpClient({
  baseURL: 'https://api.pocket-guide.com',
  // Add auth headers if needed
  // headers: { 'Authorization': 'Bearer token' }
})

// Create API instances
const tourApi = new Tour(httpClient)
const toursApi = new Tours(httpClient)

// Generate a tour (fully type-safe!)
const request: TourGenerationRequest = {
  city: 'rome',
  days: 3,
  interests: ['history', 'art'],
  provider: 'anthropic',
  pace: 'normal',
  language: 'en',
  save: true
}

try {
  const response = await tourApi.generateTourTourGeneratePost(request)
  console.log('Tour ID:', response.data.tour_id)
  console.log('Itinerary:', response.data.itinerary)
} catch (error) {
  console.error('Failed to generate tour:', error)
}

// Get tour by ID
const tour = await toursApi.getTourDetailToursTourIdGet('rome-tour-20260217-123456-abc123')

// List all tours
const tours = await toursApi.listToursToursGet({ city: 'rome', limit: 10 })
```

### More Examples

See `src/api/example-usage.ts` for complete examples including:
- Tour generation with all parameters
- POI management and transcripts
- Combo ticket lookups
- React Native custom hooks
- Error handling patterns
- Batch operations

## API Spec Updates

The OpenAPI spec should be updated whenever the backend API changes:

1. Backend team updates the API and deploys
2. Mobile team runs `npm run update-api`
3. Review generated code changes
4. Update mobile app code if needed
5. Commit the new `api-spec/openapi.json` (NOT the generated code)

## Benefits of This Approach

✅ **Type Safety**: Full TypeScript/Dart type checking
✅ **Auto-Complete**: IDE knows all API endpoints and models
✅ **Single Source of Truth**: Backend defines API contract
✅ **No Manual Updates**: Changes sync automatically
✅ **Error Prevention**: Compile-time errors for API mismatches
✅ **Documentation**: Generated code includes JSDoc/DartDoc comments

## Development Workflow

1. **Backend changes API** → Updates FastAPI code
2. **Mobile fetches spec** → `npm run fetch-api`
3. **Mobile regenerates client** → `npm run generate-api`
4. **TypeScript compiler** → Shows errors if breaking changes
5. **Mobile developer** → Fixes code to match new API
6. **Commit** → Only commit `api-spec/openapi.json`, not generated code

## Current API Status

- **API Version**: 1.0.0
- **Total Endpoints**: 24
- **Base URL**: `http://localhost:8000` (development)
- **Documentation**: `http://localhost:8000/docs` (Swagger UI)

## Available Endpoints

Key endpoints in the generated client:

- `tourGeneratePost()` - Generate a new tour
- `toursGet()` - List all tours
- `toursTourIdGet()` - Get tour details
- `toursTourIdReplacePoiPost()` - Replace POI in tour
- `poisCityGet()` - List POIs for a city
- `poisCityPoiIdGet()` - Get POI details
- `poisCityPoiIdTranscriptGet()` - Get POI transcript
- `comboTicketsGet()` - List combo tickets
- And more...

## Troubleshooting

**Q: Generated code has errors?**
A: Make sure you're using the latest API spec. Run `npm run update-api`

**Q: API call returns 404?**
A: Check the base URL configuration. Development uses `localhost:8000`, production will be different.

**Q: Need authentication?**
A: Add headers in Configuration:
```typescript
const config = new Configuration({
  basePath: 'https://api.pocket-guide.com',
  baseOptions: {
    headers: { 'Authorization': `Bearer ${token}` }
  }
})
```

**Q: Want to customize generated code?**
A: Don't edit generated files directly. They'll be overwritten. Instead, create wrapper functions in your own code.

## License

Same as main Pocket Guide project
