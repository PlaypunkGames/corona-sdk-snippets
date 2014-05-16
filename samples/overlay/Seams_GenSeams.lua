--- Seam-generation phase of the seam-carving demo.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local abs = math.abs
local huge = math.huge
local random = math.random
local sort = table.sort
local sqrt = math.sqrt

-- Modules --
local buttons = require("ui.Button")
local hungarian = require("graph_ops.hungarian")

-- Corona modules --
local composer = require("composer")

--
local Scene = composer.newScene()

--
local function BeginSeam (indices, params, n, bitmap, inc, left_to_right, mark_used)
	local buf, x, y, used, dx, dy = {}, 0, 0, mark_used and {}

	if left_to_right then
		buf.nseams, dx, dy = params.vertn, 1, 0
	else
		buf.nseams, dx, dy = params.horzn, 0, 1
	end

	for i = 1, n do
		local r, g, b = random(), random(), random()

		indices[i], buf[i] = i, { (i - 1) * inc + 1, cost = 0, prev = 0, r = r, g = g, b = b }

		bitmap:SetPixel(x, y, r, g, b)

		x, y = x + dx, y + dy
	end

	for i = 1, used and n or 0 do
		used[i * inc] = i
	end

	return buf, used
end

--
local function ClearExtraneousSeams (params, bufs, used, bitmap, n, other)
	params.funcs.SetStatus("Cleaning up seams")

	local iw, values = params.iw, params.energy

	for i = bufs.nseams + 1, n do
		local buf = bufs[i]

		for j = 1, #buf do
			local index = buf[j]
			local im1, oi = index - 1, other and used[index]
			local x = im1 % iw
			local y = (im1 - x) / iw

			--
			if oi then
				local obuf = other[oi]

				bitmap:SetPixel(x, y, obuf.r, obuf.g, obuf.b)
			else
				used[index] = false

				bitmap:SetPixel(x, y, params.gray(values[buf[j]]))
			end
		end
	end

	bitmap:WaitForPendingSets()
end

-- Calculates the energy difference when moving to a new position
local function GetEnergyDiff (values, index, energy)
	return index > 0 and abs(values[index] - energy) or 1e12
end

--
local function GetBestEdge (values, pref, alt1, alt2, energy)
	local best = pref and GetEnergyDiff(values, pref, energy) or huge
	local dalt1 = alt1 and GetEnergyDiff(values, alt1, energy) or huge
	local dalt2 = alt2 and GetEnergyDiff(values, alt2, energy) or huge

	if dalt1 < best then
		pref, best = alt1, dalt1
	end

	if dalt2 < best then
		pref = alt2
	end

	return pref
end

-- Calculates the energy for the different edges a seam may try
local function GetEdgesEnergy (values, i, finc, pinc, n, offset)
	local index = offset + (i - 1) * pinc
	local ahead, energy = index + finc, values[index]
	local diag1 = i > 1 and ahead - pinc
	local diag2 = i < n and ahead + pinc

	return ahead, diag1, diag2, energy
end

-- Populates a row of the cost matrix
local function LoadCosts (values, costs, ahead, diag1, diag2, energy, ri)
	if diag1 then
		costs[ri + 1], ri = GetEnergyDiff(values, diag1, energy), ri + 1
	end

	costs[ri + 1], ri = GetEnergyDiff(values, ahead, energy), ri + 1

	if diag2 then
		costs[ri + 1], ri = GetEnergyDiff(values, diag2, energy), ri + 1
	end

	return ri
end

-- Solves a row's seam assignments, updating total energy
local function SolveAssignment (indices, values, costs, opts, buf, n, inc, offset)
	hungarian.Run_Tridiagonal(costs, opts)

	local assignment = opts.into

	for i = 1, n do
		local at, into = assignment[indices[i]], buf[i]
		local index = offset + (at - 1) * inc

		indices[i], into[#into + 1] = at, index

		local energy = values[index]

		into.cost, into.prev = into.cost + abs(energy - into.prev), energy
	end
end

-- Compare seams by cost
local function CostComp (a, b)
	return a.cost < b.cost
end

--
local function UpdateSeams (indices, bufs, n, bitmap, coord, left_to_right, used)
	--
	coord = coord - 1

	if left_to_right then
		for i = 1, n do
			local buf = bufs[i]

			bitmap:SetPixel(indices[i] - 1, coord, buf.r, buf.g, buf.b)
		end
	else
		for i = 1, n do
			local buf = bufs[i]

			bitmap:SetPixel(coord, indices[i] - 1, buf.r, buf.g, buf.b)
		end	
	end

	--
	for i = 1, used and n or 0 do
		used[bufs[i][coord]] = i
	end
end

--
function Scene:show (event)
	if event.phase == "did" then
		local params = event.params
		local funcs, image = params.funcs, params.bitmap

		--
		self.view:insert(image)

		--
		local finc, fn, fstr = params.iw, params.ih, "Carving: row %i of %i"
		local pinc, pn, pstr = 1, params.iw, "Carving: column %i of %i"
		local indices, method = {}, params.method

		if method == "horizontal" then
			finc, pinc, fn, pn, fstr, pstr = pinc, finc, pn, fn, pstr, fstr
		end

		--
		buttons.Button(self.view, nil, params.ok_x, params.cancel_y, 100, 40, function()
			funcs.Cancel()
			funcs.ShowOverlay("samples.overlay.Seams_Energy", params)
		end, "Cancel")
--[[
		local save = buttons.Button(self.view, nil, params.ok_x, params.ok_y, 100, 40, function()
			funcs.Cancel()

			-- ? (probably has to be inside the action, or at least forward declare a lot of stuff)
			-- go to... where?
		end, "Save")
]]
		--
		funcs.Action(function()
			-- Dimension 1: Begin a seam at each index along the first dimension, flagging each such
			-- index as used. Choose a random color to plot the seam.
			local buf1, used = BeginSeam(indices, params, pn, image, pinc, method == "vertical", true)

			-- Proceed along the other dimension, following paths of low-cost difference.
			local offset, values, two_seams = 1, params.energy, params.two_seams
			local assignment, costs = two_seams and { into = {}, yfunc = funcs.TryToYield }, two_seams and {}

			for coord = 2, fn do
				funcs.SetStatus(fstr, coord, fn)

				local cost_index = 0

				for i = 1, pn do
					local ahead, diag1, diag2, energy = GetEdgesEnergy(values, i, finc, pinc, pn, offset)

					-- If doing a two-seams approach, load a row of the cost matrix. Otherwise, advance
					-- each index to the best of its three edges in the next column or row.
					if two_seams then
						cost_index = LoadCosts(values, costs, ahead, diag1, diag2, energy, cost_index)
					else
						diag1 = not used[diag1] and diag1
						ahead = not used[ahead] and ahead

						local at, buf = GetBestEdge(values, ahead, diag1, diag2, energy), buf1[i]

						indices[i], buf[#buf + 1], used[at] = at - offset, at, i
					end
				end

				-- In the two-seams approach, having set all the costs up, solve the column or row.
				if two_seams then
					SolveAssignment(indices, values, costs, assignment, buf1, pn, pinc, offset + finc)
				end

				-- Advance, update the seam graphics, and pause if necessary.
				offset = offset + finc

				UpdateSeams(indices, buf1, pn, image, coord, method == "vertical", used)

				funcs.TryToYield()
			end

			-- Pick the lowest-cost seams and restore the image underneath the rest.
			sort(buf1, CostComp)

			ClearExtraneousSeams(params, buf1, used, image, pn)

			-- Dimension 2: Begin a seam at each index along the second dimension; usage flags are
			-- unnecessary on this pass. Choose a random color to plot the seam.
			local buf2 = BeginSeam(indices, params, fn, image, finc, method ~= "vertical")

			-- If doing a two-seams approach, initialize the seam index state with the indices of the
			-- positions just found. Load costs as before and solve for this dimension.
			if two_seams then
				offset = 1

				for coord = 2, pn do
					funcs.SetStatus(pstr, coord, pn)

					local cost_index = 0

					for i = 1, fn do
						local ahead, diag1, diag2, energy = GetEdgesEnergy(values, i, pinc, finc, fn, offset)

						-- Load the cost matrix as was done earlier, but omit any diagonal edges (by assigning
						-- impossibly high costs) that already came into use in the other dimension, as those
						-- can potentially lead to seams crossing twice, and thus an inconsistent index map,
						-- q.v. the appendix in the Avidan & Shamir paper.
						if diag1 and used[diag1] then
							diag1 = -1
						end

						if diag2 and used[diag2] then
							diag2 = -1
						end

						cost_index = LoadCosts(values, costs, ahead, diag1, diag2, energy, cost_index)
					end

					-- Solve the column or row. Advance, update the seam graphics, and pause if necessary.
					offset = offset + pinc

					SolveAssignment(indices, values, costs, assignment, buf2, fn, finc, offset)
					UpdateSeams(indices, buf2, fn, image, coord, method ~= "vertical")

					funcs.TryToYield()
				end

			-- Otherwise, this dimension is just a row or column.
			else
				for i = 1, pn do			
					funcs.SetStatus(pstr, i, pn)

					local index, buf = indices[i], buf2[i]

					buf[#buf + 1] = pinc
					buf[#buf + 1] = fn

					buf.prev = values[index]

					for _ = 2, fn do
						local energy = values[index + pinc]

						buf.cost, buf.prev, index = buf.cost + abs(energy - buf.prev), energy, index + pinc
					end

					funcs.TryToYield()
				end
			end

			-- Pick the lowest-cost seams and restore the image underneath the rest.
			sort(buf2, CostComp)

			ClearExtraneousSeams(params, buf2, used, image, fn, buf1) -- Cleanup probably pointless...

			-- Present carve options.
			params.buf1, params.buf2 = buf1, buf2

			funcs.ShowOverlay("samples.overlay.Seams_Carve", params)
		end)()
	end
end

Scene:addEventListener("show")

return Scene