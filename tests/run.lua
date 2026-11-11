--!strict
-- Entry point for the headless Lune tests (framework file):
--
--   lune run tests/run.lua    (from the project root; `make test` runs it)
--
-- Runs the framework's checks, then the game's tests (tests/game.lua), and exits 1 if any failed.

local H = require("./harness")

require("./framework")
require("./game")

H.finish()
