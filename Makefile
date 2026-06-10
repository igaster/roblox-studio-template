.PHONY: help serve serve-lobby build build-lobby

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

.DEFAULT_GOAL := help

serve: ## Start Rojo server for the game place
	rojo serve default.project.json

serve-lobby: ## Start Rojo server for the lobby place
	rojo serve lobby.project.json

build: ## Build the game place to game.rbxl
	rojo build default.project.json -o game.rbxl

build-lobby: ## Build the lobby place to lobby.rbxl
	rojo build lobby.project.json -o lobby.rbxl
