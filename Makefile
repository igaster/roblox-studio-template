.PHONY: serve test test-all balance sim verify

# Rokit installs tools in ~/.rokit/bin; fall back to it when a shell's PATH lacks it.
LUNE ?= $(shell command -v lune 2>/dev/null || echo $(HOME)/.rokit/bin/lune)
ROJO ?= $(shell command -v rojo 2>/dev/null || echo $(HOME)/.rokit/bin/rojo)
export LUNE # tests/lib/balance/Parallel starts worker processes with it

serve: ## Start Rojo server
	$(ROJO) serve default.project.json

test: ## Run headless Lune unit tests, skipping *.slow.spec.lua (ARGS=--verbose prints every passing check)
	$(LUNE) run tests/run.lua $(ARGS)

test-all: ## Run every Lune test, including slow simulation specs
	$(LUNE) run tests/run.lua --slow $(ARGS)

balance: ## Run the game's balance report against its baseline, if it has one (tests/sim/eval.lua --check); flags via ARGS="..."
	@if [ -f tests/sim/eval.lua ]; then $(LUNE) run tests/sim/eval.lua --check $(ARGS); \
	else echo "No balance report yet (tests/sim/eval.lua): see the roblox-game-modeling skill."; fi

sim: balance ## Old name of balance

verify: ## Check toolchain, Rojo server and Studio connection
	@bash scripts/verify.sh
