local mp = require 'mp' -- isn't actually required, mp still gonna be defined

-- should not be altered here, edit options in corresponding .conf file
local opts = {
  toggle_menu_binding = 't',
  lines_to_show = 17, -- NOT including search line
  pause_on_start = true,
  resume_on_exit = "only-if-was-paused", -- another possible value is true

  font_size=21,
  line_bottom_margin = 1, -- basically space between lines

  -- not rly worth putting in .conf file --------------------------------------
  search_heading = 'M-x',
}

(require 'mp.options').read_options(opts, mp.get_script_name())

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"})..package.path
local em = require "extended-menu"

-- You can freely redefine extended-menu methods:
-- - submit(val) -- assuming you passed correct 'data' format to init() will
--    return data[i], which shall contain full list
-- - filter() - data might have different fields so there might be a need to
--    write a custom filter func. It accepts optional 'query' param, otherwise
--    takes current user input. But it MUST return filtered table the same
--    format as initial list - {{index, content}, {index, content}, ..}
local chapter_menu = em:new(opts)

local cmd_list = {list = {}, current_i = nil}


function chapter_menu:submit(val)
  -- .. and we subtract one index when we set to mp
  mp.set_property_native("chapter", val.index - 1)
end

local function get_cmd_list()
  -- in order to not store composing functions in moon-searcher and managing
  -- different field handling you need to compose data list in main script
  -- and paste all lists to moon-searcher in unified format {index, content}

  local bindings = mp.get_property_native("chapter-list/count")

  local chaptersArr = {}

  -- We need to start from 0 here cuz mp returns titles starting with 0
  for _,kbd in ipairs(bindings) do
    -- to be done
  end

  cmd_list.list = chaptersArr
end

mp.register_event("file-loaded", get_cmd_list)

-- keybind to launch menu
mp.add_key_binding(opts.toggle_menu_binding, "M-x", function()
                     chapter_menu:init(cmd_list)
end)
