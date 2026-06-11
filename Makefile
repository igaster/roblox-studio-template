.PHONY: help serve build

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

.DEFAULT_GOAL := help

serve: ## Start Rojo server
	rojo serve default.project.json

build: ## Build the place to game.rbxl
	rojo build default.project.json -o game.rbxl
