# Quick Start - API Client Setup

This guide helps you set up the auto-generated API client for the Pocket Guide mobile app.

## Prerequisites

1. ✅ Backend API running at `http://localhost:8000`
2. ✅ Node.js installed (v16+)
3. ✅ npm or yarn installed
4. ✅ **NO JAVA REQUIRED!** (uses JavaScript-native code generator)

## Setup Steps (5 minutes)

### 1. Install Dependencies

```bash
cd pocket-guide-mobile-app
npm install
```

### 2. Fetch API Specification

Make sure the backend API is running, then:

```bash
npm run fetch-api
```

You should see:
```
📡 Fetching OpenAPI spec from http://localhost:8000/openapi.json...
✅ OpenAPI spec saved to api-spec/openapi.json
📋 API Version: 1.0.0
📋 Total Endpoints: 24
```

### 3. Generate Type-Safe API Client

```bash
npm run generate-api
```

This will create:
- `src/api/generated/` - Type-safe API client
- Full TypeScript types for all requests/responses
- Auto-complete support in your IDE

### 4. Test the Setup

Create a test file `src/test-api.ts`:

```typescript
import { HttpClient } from './api/generated/http-client'
import { Tours } from './api/generated/Tours'

const httpClient = new HttpClient({
  baseURL: 'http://localhost:8000'
})

const toursApi = new Tours(httpClient)

// Test API call
toursApi.listToursToursGet({ city: 'rome', limit: 5, offset: 0 })
  .then(response => {
    console.log('✅ API Working! Tours:', response.data.tours?.length || 0)
  })
  .catch(error => {
    console.error('❌ API Error:', error.message)
  })
```

Run it:
```bash
npx ts-node src/test-api.ts
```

## That's It! 🎉

You now have a fully type-safe API client. Check out:
- `README.md` - Full documentation
- `src/api/example-usage.ts` - Code examples

## Daily Workflow

When the backend API changes:

```bash
# Update everything in one command
npm run update-api

# Or step by step:
npm run fetch-api      # Fetch latest spec
npm run generate-api   # Regenerate client
```

## Common Issues

**Problem**: `fetch-api` fails with connection error
**Solution**: Make sure backend API is running at `http://localhost:8000`

**Problem**: Generated code has TypeScript errors
**Solution**: Run `npm run update-api` to get the latest spec

**Problem**: API call returns 404
**Solution**: Check the endpoint exists in the OpenAPI spec at `api-spec/openapi.json`

## Next Steps

1. Read `README.md` for detailed usage examples
2. Check `src/api/example-usage.ts` for code patterns
3. Start building your mobile app screens!
4. Import and use the generated API client:

```typescript
import { HttpClient } from './api/generated/http-client'
import { Tours, Pois, Tour, ComboTickets } from './api/generated'
import type { TourGenerationRequest, TourResponse } from './api/generated/data-contracts'
```

## Questions?

- Backend API docs: http://localhost:8000/docs
- OpenAPI spec: `api-spec/openapi.json`
- Generated client: `src/api/generated/`
