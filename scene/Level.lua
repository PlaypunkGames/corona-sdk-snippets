--- Level scene.
--
-- This is the "in-game" scene. The scene expects event.params == _which_, corresponding
-- to the @{corona_boilerplate.game.loop.LoadLevel} parameter.
--
-- TODO: Mention leave_menus

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
local button = require("corona_ui.widgets.button")
local game_loop = require("corona_boilerplate.game.loop")
local prompts = require("corona_ui.patterns.prompts")
local scenes = require("corona_utils.scenes")
local timers = require("corona_utils.timers")

-- Corona globals --
local display = display
local native = native
local Runtime = Runtime

-- Corona modules --
local composer = require("composer")

-- Level scene --
local Scene = composer.newScene()

-- Alert handler, to cancel dialog if level ends first --
local Alert

-- Overlay arguments --
local Args = { isModal = true }

-- Post-overlay action --
local OnDone, Arg

-- Scene listener: double check on quit requests and show modal overlays
local function Listen (what, arg1, arg2, arg3)
	-- Message: Wants To Go Back
	if what == "message:wants_to_go_back" then
		Alert = prompts.ProceedAnyway({
			choices = "ok_cancel", title = "Hey!", message = "Do you really want to quit?",
			proceed = game_loop.UnloadLevel
		}, "quit")

	-- Message: Hide Overlay
	elseif what == "message:hide_overlay" and OnDone then
		timers.Defer(function()
			OnDone(Arg)

			OnDone, Arg = nil
		end)

	-- Message: Show Overlay
	-- arg1: Overlay name
	-- arg2: On-done logic
	-- arg3: On-done argument
	elseif what == "message:show_overlay" then
		OnDone, Arg = arg2, arg3

		composer.showOverlay(arg1, Args)
	end
end

-- Create Scene --
function Scene:create ()
	scenes.Alias("Level")
end

Scene:addEventListener("create")

-- Show Scene --
function Scene:show (event)
	if event.phase == "did" then
		--
		Runtime:dispatchEvent{ name = "leave_menus" } -- OKAY??? (TODO: seems to have worked fine, but look into "will")

		game_loop.LoadLevel(self.view, event.params)
	end
end

Scene:addEventListener("show")

-- Hide Scene --
function Scene:hide (event)
	if event.phase == "did" then
		display.remove(self.m_exit)

		self.m_exit = nil
	else
		if Alert then
			native.cancelAlert(Alert)

			Alert = nil
		end

		scenes.SetListenFunc(nil)
	end
end

Scene:addEventListener("hide")

-- Listen to events.
for k, v in pairs{
	-- Enter Level --
	enter_level = function()
		scenes.SetListenFunc(Listen) -- TODO: Timing not QUITE right...
	end,

	-- Things Loaded --
	things_loaded = function(level)
		-- If coming from the map editor, this is only a test: add a quick exit button.
		if scenes.ComingFrom() == "Editor" then
			Scene.m_exit = button.Button_XY(level.hud_group, "from_right -15", "below 15", 50, 40, scenes.WantsToGoBack, "X")
		end
	end
} do
	Runtime:addEventListener(k, v)
end

return Scene