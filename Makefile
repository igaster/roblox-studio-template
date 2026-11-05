.PHONY: serve test test-all balance

serve: ## Start Rojo server
	rojo serve default.project.json

test: ## Run headless Lune unit tests (fast; skips *.slow.spec.lua)
	lune run tests/suite.lua

test-all: ## Run every Lune spec, including the slow simulation specs
	lune run tests/suite.lua --slow

balance: ## Balance report, if the game has one (tests/sim/eval.lua; game-modeling skill)
	@if [ -f tests/sim/eval.lua ]; then lune run tests/sim/eval.lua --check; else echo "No balance report (tests/sim/eval.lua) in this game."; fi
