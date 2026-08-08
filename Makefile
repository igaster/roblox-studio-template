.PHONY: serve test

serve: ## Start Rojo server
	rojo serve default.project.json

test: ## Run headless Lune unit tests
	lune run tests/run.lua
