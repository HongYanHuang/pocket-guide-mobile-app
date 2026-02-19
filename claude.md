- Project Purpose
	- Mobile app (iOS & Android) for the Pocket Guide tour generator
	- Provides customized, not standardized, tour experiences for travelers
	- Consumes API from pocket-guide backend repository

- Technology Stack
	- Cross-platform: Flutter with Dart
	- Type-safe API client auto-generated from OpenAPI spec
	- HTTP client: Dio (Flutter's powerful HTTP client)
	- Backend API: pocket-guide repository (FastAPI)

- API Integration
	- NEVER manually write API types or interfaces
	- ALWAYS use auto-generated client from OpenAPI spec
	- Update API client by running: npm run update-api
	- Commit api-spec/openapi.json, NOT generated code
	- Generated client uses dart-dio generator from openapi-generator-cli

- Development Principles
	- Always open a new branch for new feature development
	- Always push commits to remote feature branch regularly
	- Never directly commit to main branch
	- Always wait for explicit instruction before merging to main
	- Keep mobile app and backend API in sync via OpenAPI spec
	- Use Flutter's hot reload for fast development iteration

- Code Organization
	- lib/api/generated/ - Auto-generated API client (gitignored)
	- lib/api/ - Custom API wrappers and services
	- lib/screens/ - App screens/pages
	- lib/widgets/ - Reusable UI widgets
	- lib/models/ - Data models (non-API)
	- lib/services/ - Business logic and state management
	- lib/utils/ - Helper functions
