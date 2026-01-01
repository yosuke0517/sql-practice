.PHONY: db\:restart db\:start db\:stop db\:logs db\:connect

db\:restart:
	@echo "Stopping and removing containers and volumes..."
	docker compose down -v
	@echo "Starting services..."
	docker compose up -d
	@echo "Waiting for MySQL to be ready..."
	@sleep 10
	@docker compose logs mysql | tail -10

db\:start:
	docker compose up -d

db\:stop:
	docker compose down

db\:logs:
	docker compose logs -f mysql

db\:connect:
	mysql -h127.0.0.1 -uroot -proot sql_practice
