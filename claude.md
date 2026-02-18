- Project Purpose
	- Mobile app (iOS & Android) for the Pocket Guide tour generator
	- Provides customized, not standardized, tour experiences for travelers
	- Consumes API from pocket-guide backend repository

- Technology Stack
	- Cross-platform: React Native or Flutter (TBD)
	- Type-safe API client auto-generated from OpenAPI spec
	- Backend API: pocket-guide repository (FastAPI)

- API Integration
	- NEVER manually write API types or interfaces
	- ALWAYS use auto-generated client from OpenAPI spec
	- Update API client by running: npm run update-api
	- Commit api-spec/openapi.json, NOT generated code

- Development Principles
	- Always open a new branch for new feature development
	- Always push commits to remote feature branch regularly
	- Never directly commit to main branch
	- Always wait for explicit instruction before merging to main
	- Keep mobile app and backend API in sync via OpenAPI spec

- Code Organization
	- src/api/generated/ - Auto-generated API client (gitignored)
	- src/api/ - Custom API wrappers and hooks
	- src/screens/ - App screens/pages
	- src/components/ - Reusable UI components
	- src/utils/ - Helper functions
