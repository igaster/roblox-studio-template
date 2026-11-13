# Game commands, included by each game's Makefile (games/<name>/Makefile) and run from the
# game root. FACTORY is the framework root as seen from the game (../.. by default).
FACTORY ?= ../..
FRAMEWORK_ROOT := $(abspath $(FACTORY))
export FRAMEWORK_ROOT # tests/framework.lua and the balance toolkit find framework files with it

# Rokit installs tools in ~/.rokit/bin; fall back to it when a shell's PATH lacks it.
LUNE ?= $(shell command -v lune 2>/dev/null || echo $(HOME)/.rokit/bin/lune)
ROJO ?= $(shell command -v rojo 2>/dev/null || echo $(HOME)/.rokit/bin/rojo)
export LUNE # tests/lib/balance/Parallel starts worker processes with it

.PHONY: serve test test-all balance sim verify claude

serve: ## Start Rojo server for this game
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
	@bash $(FRAMEWORK_ROOT)/scripts/verify.sh

claude: ## Start Claude Code in this game with the framework loaded (ARGS="..." passes flags)
	claude --plugin-dir $(FRAMEWORK_ROOT)/plugins/roblox-framework --mcp-config $(FRAMEWORK_ROOT)/.mcp.json $(ARGS)
