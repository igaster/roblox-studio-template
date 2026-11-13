# Framework root. Games live in games/<name>/, each with its own Makefile (make serve, test,
# claude… run from the game folder). From here, GAME=<name> (or the active game in
# .local/active-game) forwards those commands to that game.
.PHONY: new-game games serve test test-all balance sim verify claude

GAME ?= $(shell cat .local/active-game 2>/dev/null)

new-game: ## Create games/$(NAME) from template/ (its own git repo; nothing committed)
	@bash scripts/new-game.sh $(NAME)

games: ## List the games
	@ls -1 games 2>/dev/null || echo "No games yet: make new-game NAME=<kebab-case-name>"

serve test test-all balance sim claude:
	@if [ -z "$(GAME)" ]; then echo "Which game? make $@ GAME=<name> (see: make games)"; exit 1; fi
	@$(MAKE) --no-print-directory -C games/$(GAME) $@

verify: ## Check toolchain, Rojo server and Studio connection
	@bash scripts/verify.sh
