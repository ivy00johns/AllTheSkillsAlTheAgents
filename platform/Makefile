COMPOSE_FILE=infra/compose.local.yml

.PHONY: check-prereqs infra-up infra-down infra-logs validate-schemas

check-prereqs:
	bash scripts/check-prereqs.sh

infra-up:
	docker compose -f $(COMPOSE_FILE) up -d

infra-down:
	docker compose -f $(COMPOSE_FILE) down

infra-logs:
	docker compose -f $(COMPOSE_FILE) logs -f

validate-schemas:
	node scripts/validate-schemas.mjs
