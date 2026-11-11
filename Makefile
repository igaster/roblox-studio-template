.PHONY: serve test sim verify

# Rokit installs tools in ~/.rokit/bin; fall back to it when a shell's PATH lacks it.
LUNE ?= $(shell command -v lune 2>/dev/null || echo $(HOME)/.rokit/bin/lune)
ROJO ?= $(shell command -v rojo 2>/dev/null || echo $(HOME)/.rokit/bin/rojo)

serve: ## Start Rojo server
	$(ROJO) serve default.project.json

test: ## Run headless Lune unit tests (ARGS=--verbose prints every passing check)
	$(LUNE) run tests/run.lua $(ARGS)

sim: ## Run the game's balance simulator, if it has one (tests/balance_sim.lua); flags via ARGS="..."
	@if [ -f tests/balance_sim.lua ]; then $(LUNE) run tests/balance_sim.lua $(ARGS); \
	else echo "No balance simulator yet (tests/balance_sim.lua): see the roblox-test skill."; fi

verify: ## Check toolchain, Rojo server and Studio connection
	@bash scripts/verify.sh
