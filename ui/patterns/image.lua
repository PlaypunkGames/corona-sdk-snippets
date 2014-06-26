--- Some useful UI patterns based on images.

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

-- Modules --
local png = require("image_ops.png")

-- Corona globals --
local display = display
local system = system

-- Exports --
local M = {}

--- DOCME
-- @pgroup group
-- @uint w Thumbnail width...
-- @uint h ...and height.
-- @ptable[opt] opts
-- @treturn DisplayGroup Thumbnail.
function M.Thumbnail (group, w, h, opts)
	local Thumbnail = display.newGroup()

	group:insert(Thumbnail)

	--
	local color, image = display.newRect(Thumbnail, 0, 0, w, h)
	local frame = not (opts and opts.no_frame) and display.newRect(Thumbnail, 0, 0, w, h)

--	if opts then
		color:setFillColor{ type = "gradient", color1 = { 0, 0, 1 }, color2 = { .3 }, direction = "down" }

		if frame then
			frame:setFillColor(0, 0)

			frame.strokeWidth = 3
		end
--	end
	-- ^^ TODO: Make these configurable...

	--- Clears the thumbnail image, if any.
	function Thumbnail:Clear ()
		display.remove(image)

		image = nil
	end

	--- DOCME
	-- @string name Image filename.
	-- @param[opt=system.ResourceDirectory] base Base directory.
	-- @treturn boolean If true, the image was set.
	function Thumbnail:SetImage (name, base)
		base = base or system.ResourceDirectory

		local exists, iw, ih = png.GetInfo(system.pathForFile(name, base))

		if exists then
			display.remove(image)

			if iw <= w and ih <= h then
				image = display.newImage(self, name, base)
			else
				image = display.newImageRect(self, name, base, w, h)
			end

			image.x, image.y = color.x, color.y

			-- Keep the frame in front of the new image.
			if frame then
				frame:toBack()
			end
		end

		return exists
	end

	return Thumbnail
end

-- Export the module.
return M