.PHONY: serve test test-all sim verify

# Rokit installs tools in ~/.rokit/bin; fall back to it when a shell's PATH lacks it.
LUNE ?= $(shell command -v lune 2>/dev/null || echo $(HOME)/.rokit/bin/lune)
ROJO ?= $(shell command -v rojo 2>/dev/null || echo $(HOME)/.rokit/bin/rojo)

serve: ## Start Rojo server
	$(ROJO) serve default.project.json

test: ## Run headless Lune unit tests, skipping *.slow.spec.lua (ARGS=--verbose prints every passing check)
	$(LUNE) run tests/run.lua $(ARGS)

test-all: ## Run every Lune test, including slow simulation specs
	$(LUNE) run tests/run.lua --slow $(ARGS)

sim: ## Run the game's balance simulator, if it has one (tests/balance_sim.lua); flags via ARGS="..."
	@if [ -f tests/balance_sim.lua ]; then $(LUNE) run tests/balance_sim.lua $(ARGS); \
	else echo "No balance simulator yet (tests/balance_sim.lua): see the roblox-test skill."; fi

verify: ## Check toolchain, Rojo server and Studio connection
	@bash scripts/verify.sh
