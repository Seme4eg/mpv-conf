local mp = require 'mp' -- isn't actually required, mp still gonna be defined

-- should not be altered here, edit options in corresponding .conf file
local opts = {
  toggle_menu_binding = 'k',
  lines_to_show = 17, -- NOT including search line
  pause_on_start = true,
  resume_on_exit = "only-if-was-paused", -- another possible value is true

  font_size=21,
  line_bottom_margin = 1, -- basically space between lines


  -- not rly worth putting in .conf file --------------------------------------

  search_heading = 'Select chapter',
  -- field to compare with when searching for 'current value' by 'current_i'
  index_field = 'index',
  -- fields to use when searching for string match / any other custom searching
  -- if value has 0 length, then search list item itself
  filter_by_fields = {'content'},
}

(require 'mp.options').read_options(opts, mp.get_script_name())

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"})..package.path
local em = require "extended-menu"

-- You can freely redefine extended-menu methods:
-- - submit(val) -- assuming you passed correct 'data' format to init() will
--    return data[i], which shall contain full list
-- - filter() - data might have different fields so there might be a need to
--    write a custom filter func. It accepts optional 'query' param, otherwise
--    takes current user input. But it MUST return filtered table the SAME
--    format as initial list.
-- - search_method(str) - search method to use given string (line). Must return
--    nil or any non-nil value.
-- - get_line(index, value) - function that composes an individual line, must
--    return String. Beware tho, if you gonna be using assdraw functionality
--    there - do not apply something like pos, alignment, \n and similar styles
local chapter_menu = em:new(opts)

local chapter = {list = {}, current_i = nil}

local function get_chapters()
  local chaptersCount = mp.get_property("chapter-list/count")
  if chaptersCount == 0 then
    return {}
  else
    local chaptersArr = {}

    -- We need to start from 0 here cuz mp returns titles starting with 0
    for i=0, chaptersCount do
      local chapterTitle = mp.get_property_native("chapter-list/"..i.."/title")
      if chapterTitle then
        table.insert(chaptersArr, {index = i + 1, content = chapterTitle})
      end
    end

    return chaptersArr
  end
end

function chapter_menu:submit(val)
  -- .. and we subtract one index when we set to mp
  mp.set_property_native("chapter", val.index - 1)
end

local function chapter_info_update()
  chapter.list = get_chapters()

  if not #chapter.list then return end

  -- tho list might b already present, but 'chapter' still might b nil
  -- and we also add one index when we get from mp
  chapter.current_i = (mp.get_property_native("chapter") or 0) + 1
end

mp.register_event("file-loaded", chapter_info_update)
mp.observe_property("chapter-list/count", "number", chapter_info_update)
mp.observe_property("chapter", "number", chapter_info_update)

-- keybind to launch menu
mp.add_key_binding(opts.toggle_menu_binding, "chapters-menu", function()
                     chapter_menu:init(chapter)
end)
