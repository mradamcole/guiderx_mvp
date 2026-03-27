# GuideRx MVP

GuideRx MVP is a clinical evidence platform focused on cannabis-related interventions, designed to support safer, explainable treatment recommendations with a strong regulatory and audit trail foundation.

## What this project does

- Ingests and normalizes medical terminology (ICD-11, SNOMED-CT, RxNorm, and custom concepts).
- Tracks publications, studies, trial arms, products, ingredients, dosing, outcomes, and adverse events.
- Scores evidence quality using configurable frameworks (for example, GRADE-like dimensions such as bias and consistency).
- Produces clinician-facing recommendations that are context-aware, rule-driven, and linked to supporting evidence.
- Captures LLM generation provenance and decision traceability to support SaMD Class II defensibility.

## Current repository focus

The primary artifact in this repository is a PostgreSQL schema located at `Implementation_instructions/sql_schema.sql`.

## Technology Stack

This project currently uses the following technology stack, and future development should prefer these tools by default unless there is a strong, explicit reason to change:

- **Language/runtime**: TypeScript on Node.js (`src/**/*.ts`, `tsconfig.json`)
- **API framework**: Express (`express`)
- **Database**: PostgreSQL (`pg` driver, SQL migrations/seeds)
- **Validation**: Zod (`zod`)
- **Configuration**: dotenv (`dotenv`, `.env`)
- **Dev execution**: tsx (`tsx watch` for local development)
- **Testing**: Vitest + Supertest (`vitest`, `supertest`)
- **Build**: TypeScript compiler (`tsc`)
- **Database workflow**: Make-based commands (`make db-migrate`, `make db-seed`, `make db-init`, `make db-reset-test`)

Stack preference policy for contributors:

- Prefer TypeScript/Node/Express for services and APIs.
- Prefer PostgreSQL-first schema design with SQL migrations and SQL seed scripts.
- Prefer Zod for request and payload validation.
- Prefer Vitest + Supertest for automated testing.
- Prefer extending existing Make/NPM scripts over introducing parallel tooling.

## Instantiate the database (local)

### Quick start (one command)

From the repo root, run:

`make db-init`

This will:

- Create database `guiderx_mvp` if missing
- Apply `Implementation_instructions/sql_schema.sql`
- Print a table count verification query result

You can override defaults:

- `make db-init DB_NAME=my_db`
- `make db-migrate DB_NAME=my_db`
- `make db-seed DB_NAME=my_db`

### Manual setup

Use these steps to create a local PostgreSQL database and apply the schema manually.

1. Install PostgreSQL (includes `psql`):
   - macOS (Homebrew): `brew install postgresql`
2. Start PostgreSQL:
   - `brew services start postgresql@18`
   - If you installed a different major version, replace `@18` accordingly (for example `postgresql@17`).
3. Create a database:
   - `createdb guiderx_mvp`
4. Apply the schema:
   - `psql -d guiderx_mvp -f "Implementation_instructions/sql_schema.sql"`
5. Verify tables were created:
   - `psql -d guiderx_mvp -c "SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema='public';"`

Expected result: `table_count` should be greater than 0 (currently 37 with the provided schema).

### Re-run behavior

`Implementation_instructions/sql_schema.sql` is written to be re-runnable (idempotent) for local/dev setup. Reapplying it should produce notices for existing objects but not fail.

## Mock medicinal cannabis seed data

Use the mock seed script to populate a demo catalog of medicinal cannabis products, product compositions, study arms/doses, recommendations, safety rules, and evidence traces.

Apply seed data after applying the schema:

- `psql -d guiderx_mvp -f "Implementation_instructions/mock_medicinal_cannabis_seed.sql"`

Seed assumptions:

- Data is synthetic and intended for demos/testing only.
- Product formats/routes/units are standardized by convention in the seed script comments.
- Inserts are idempotent using deterministic UUIDs and `ON CONFLICT DO NOTHING`.
- Scope is focused on intervention/CDS demo flows, not full publication/outcome graph coverage.

### Notes

- The schema uses the `uuid-ossp` extension and creates it automatically (`CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`).
- Use `Implementation_instructions/sql_schema.sql` as the canonical schema for this repo.
- Use `Implementation_instructions/mock_medicinal_cannabis_seed.sql` to quickly load demo medicinal cannabis records.
- `Implementation_instructions/chatgpt-cannabis_eri_schema.sql` is an alternative design and is not the primary implementation target.

## Migration and seed workflow

The repository now includes a versioned migration and seed path for controlled schema evolution.

- Migration files: `db/migrations/*.sql`
- Seed files: `db/seeds/*.sql`

Core commands:

- `make db-migrate` - apply all migrations in order
- `make db-seed` - apply all seed scripts in order
- `make db-init` - create DB (if needed), migrate, seed, verify
- `make db-reset-test` - recreate test DB, migrate, seed

That schema defines a layered data model:

1. **Reference & terminology**: canonical concepts and relationships.
2. **Publication & study**: papers, authors, registries, and study metadata.
3. **Intervention & outcomes**: products, doses, trial arms, efficacy, and harms.
4. **Quality & aggregation**: risk of bias, pooled findings, and evidence scoring.
5. **CDS (clinical decision support)**: recommendation logic, patient context, safety alerts, and explanations.
6. **Regulatory traceability**: evidence trace links and LLM run metadata for reproducibility.

## API/service layer

A minimal TypeScript/Express backend is included under `src/` for:

- evidence ingestion (`POST /api/ingestion/evidence`)
- recommendation generation (`POST /api/recommendations/generate`)
- recommendation retrieval (`GET /api/recommendations/instances/:instanceId`)

### Configuration and environment

Application configuration is centralized in `src/config.ts` (ports, CORS origin, LLM routes/models, retry and timeout defaults).

Copy `.env.example` to `.env` and set only secrets:

- `DATABASE_URL` - PostgreSQL connection URL (include credentials if needed)
- `OPENAI_API_KEY` - OpenAI API key for configured OpenAI LLM routes
- `ANTHROPIC_API_KEY` - Anthropic API key for configured Anthropic LLM routes

### Run locally

1. `npm install`
2. `make db-init`
3. `npm run dev`

Health endpoint:

- `GET /health`

Admin endpoints:

- `GET /api/admin/db-status`
- `GET /api/admin/papers`
- `POST /api/admin/papers`
- `POST /api/admin/papers/extract` (multipart upload, extracts draft fields with LLM)

### Central LLM router

Use `src/llm/index.ts` (`llmRouter`) for all LLM calls. Routing behavior is configured in `src/config.ts` under `appConfig.llm.routes` so model/provider selection stays in one place.

## Admin console (separate frontend)

A separate React + Vite admin app is available in `admin-console/`.

### Environment variables

Copy `admin-console/.env.example` to `admin-console/.env`:

- `VITE_API_BASE_URL` - backend API URL (default `http://localhost:3000`)

### Run locally

From the repo root, in one terminal run the API:

1. `npm run dev`

In another terminal run the admin console:

1. `cd admin-console`
2. `npm install`
3. `npm run dev`

To auto-fill the add-paper form from an uploaded file, ensure the configured LLM provider API key is set in backend `.env` (for example `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` depending on `src/config.ts` route config).

### Clinician console (separate frontend)

A separate React + Vite clinician app scaffold is available in `clinician-console/`.

This app currently includes:

- Demo/fake SSO screen with Google, Apple, and Microsoft buttons (no real auth)
- Placeholder post-login landing state for adding clinician wireframe screens
- Same frontend stack/tooling conventions as `admin-console/`

In another terminal run the clinician console:

1. `cd clinician-console`
2. `npm install`
3. `npm run dev`

By default this starts on `http://localhost:5174`. The admin console includes a header link to open this clinician app.

If you use the repo service helper, `npm run services:start` now starts:

- backend API
- admin frontend
- clinician frontend

## Validation and tests

Automated tests include:

- DB referential/cascade checks around recommendation graph tables
- end-to-end ingestion -> recommendation generation -> trace retrieval

Run:

- `npm run build`
- `npm test`

The test runner resets and rehydrates `guiderx_mvp_test` via migrations and seeds before tests execute.

## Why this matters

Healthcare decision support systems need to be transparent, reproducible, and clinically grounded. This project structures evidence end-to-end so recommendations can be explained, audited, and tied back to source literature.

## Next steps (suggested)

- Add authentication/authorization and request-level audit metadata.
- Add richer recommendation rule evaluation (priority/conflict resolution).
- Add OpenAPI docs and environment-specific deployment profiles.
