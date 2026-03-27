.PHONY: db-init db-create db-migrate db-seed db-apply db-verify db-drop db-recreate db-reset-test

DB_NAME ?= guiderx_mvp
SCHEMA_PATH ?= Implementation_instructions/sql_schema.sql
TEST_DB_NAME ?= guiderx_mvp_test
MIGRATIONS_DIR ?= db/migrations
SEEDS_DIR ?= db/seeds

db-init: db-create db-migrate db-seed db-verify

db-create:
	@echo "Initializing database: $(DB_NAME)"
	@if psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$(DB_NAME)'" | grep -q 1; then \
		echo "Database $(DB_NAME) already exists"; \
	else \
		echo "Creating database $(DB_NAME)"; \
		createdb $(DB_NAME); \
	fi

db-migrate:
	@echo "Applying migrations from $(MIGRATIONS_DIR)"
	@for file in $$(ls "$(MIGRATIONS_DIR)"/*.sql | sort); do \
		echo "Applying $$file"; \
		psql -v ON_ERROR_STOP=1 -d $(DB_NAME) -f "$$file"; \
	done

db-seed:
	@echo "Applying seeds from $(SEEDS_DIR)"
	@for file in $$(ls "$(SEEDS_DIR)"/*.sql | sort); do \
		echo "Applying $$file"; \
		psql -v ON_ERROR_STOP=1 -d $(DB_NAME) -f "$$file"; \
	done

db-apply: db-migrate

db-verify:
	@echo "Verifying table count"
	@psql -d $(DB_NAME) -c "SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema='public';"

db-drop:
	@echo "Dropping database: $(DB_NAME)"
	@dropdb --if-exists $(DB_NAME)

db-recreate: db-drop
	@$(MAKE) db-init

db-reset-test:
	@echo "Resetting test database: $(TEST_DB_NAME)"
	@dropdb --if-exists $(TEST_DB_NAME)
	@createdb $(TEST_DB_NAME)
	@$(MAKE) db-migrate DB_NAME=$(TEST_DB_NAME)
	@$(MAKE) db-seed DB_NAME=$(TEST_DB_NAME)
