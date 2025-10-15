# Inception Project Makefile

# Paths
COMPOSE_FILE = srcs/docker-compose.yml
DATA_DIR = /Users/nemo/data

# Colors for output
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
NC = \033[0m # No Color

.PHONY: all up down clean fclean re logs status help setup

# Default target
all: setup up

# Create necessary directories and start services
setup:
	@echo "$(YELLOW)Creating data directories...$(NC)"
	@mkdir -p $(DATA_DIR)/mysql
	@mkdir -p $(DATA_DIR)/wordpress
	@echo "$(GREEN)Data directories created!$(NC)"

# Start all services
up: setup
	@echo "$(YELLOW)Starting Inception services...$(NC)"
	docker compose -f $(COMPOSE_FILE) up -d --build
	@echo "$(GREEN)Services started successfully!$(NC)"

# Stop services
down:
	@echo "$(YELLOW)Stopping services...$(NC)"
	docker compose -f $(COMPOSE_FILE) down
	@echo "$(GREEN)Services stopped!$(NC)"

# Stop services and remove volumes
clean: down
	@echo "$(YELLOW)Removing volumes...$(NC)"
	docker compose -f $(COMPOSE_FILE) down -v
	@echo "$(GREEN)Volumes removed!$(NC)"

# Complete cleanup: stop services, remove volumes, images, and data
fclean: clean
	@echo "$(RED)Performing complete cleanup...$(NC)"
	@docker system prune -af --volumes
	@sudo rm -rf $(DATA_DIR)/mysql/*
	@sudo rm -rf $(DATA_DIR)/wordpress/*
	@echo "$(GREEN)Complete cleanup finished!$(NC)"

# Restart everything
re: fclean all

# Show logs
logs:
	docker compose -f $(COMPOSE_FILE) logs -f

# Show status of containers
status:
	@echo "$(YELLOW)Container Status:$(NC)"
	@docker compose -f $(COMPOSE_FILE) ps
	@echo "\n$(YELLOW)Images:$(NC)"
	@docker images | grep -E "(nginx|wordpress|mariadb|alpine)"
