--!strict
-- Outcome metrics for balance evaluation (framework, game-agnostic). They read a run
-- summary the game's adapter produces:
--   { lossRound = number?, firstTroubleRound = number?, purchases = { {kind, option} } }
-- "Trouble" is the game's first sign of failure (a leak, a lost life, a hit to the core).

local Metrics = {}

-- Rounds between the first trouble and the loss. Short means a cliff.
function Metrics.cliffLength(run: any): number?
	if not (run.lossRound and run.firstTroubleRound) then
		return nil
	end
	return run.lossRound - run.firstTroubleRound
end

-- Share of purchases per option (e.g. per unit type), optionally for one kind only.
-- Returns { [option] = share 0..1 } and the total count.
function Metrics.pickRates(purchases: { any }, kind: string?): ({ [string]: number }, number)
	local counts, total = {}, 0
	for _, purchase in ipairs(purchases) do
		if kind == nil or purchase.kind == kind then
			counts[purchase.option] = (counts[purchase.option] or 0) + 1
			total += 1
		end
	end
	local rates = {}
	for option, count in pairs(counts) do
		rates[option] = count / total
	end
	return rates, total
end

-- How much worse the outcome gets without an option: baseline loss round minus the loss
-- round with the option removed. Larger means the option matters more.
function Metrics.ablationLoss(baseline: any, without: any, cap: number): number
	return (baseline.lossRound or cap) - (without.lossRound or cap)
end

-- The option ranked first by `score` in each probe, from { [probe] = { [option] = score } }.
function Metrics.bestPerProbe(scores: { [string]: { [string]: number } }): { [string]: string }
	local best = {}
	for probe, byOption in pairs(scores) do
		local top, topScore = nil, -math.huge
		for option, score in pairs(byOption) do
			if score > topScore or (score == topScore and top ~= nil and option < top) then
				top, topScore = option, score
			end
		end
		best[probe] = top
	end
	return best
end

return Metrics
