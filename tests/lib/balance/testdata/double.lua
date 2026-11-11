-- Worker for the Parallel check in BalanceLib.spec.lua: prints its job's value doubled, as JSON.
local process = require("@lune/process")
local serde = require("@lune/serde")
local job = serde.decode("json", process.args[1])
print(serde.encode("json", { value = job.value * 2 }))
