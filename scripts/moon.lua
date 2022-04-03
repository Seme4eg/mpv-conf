-- display chapter on osd and easily switch between chapters by click on title
-- of chapter

-- Possible TODO:
--   like in SimpleHistory line 357 function does
--   mp.add_forced_key_binding(opts.toggle_menu_binding, "escape", destroy)


local mp = require 'mp' -- isn't actually required, mp still gonna be defined
-- local msg = require 'mp.msg'

local opts = {
  toggle_menu_binding = "g",
}

-- REVIEW: works?
(require 'mp.options').read_options(opts, mp.get_script_name())

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"})..package.path
local searcher = require "moon-searcher"

-- You can freely redefine moon-searcher methods:
-- - submit(val) -- assuming you passed correct 'data' format to init() will
--    return data[i], which shall contain full list
-- - filter() - data might have different fields so there might be a need to
--    write a custom filter func, last 2 string of it whould be exact same as
--    in default filter func
local chapter_menu = searcher:new()

local chapter = {list = {}, current_i = 0}

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

local function compose_data()
  -- in order to not store composing functions in moon-searcher and managing
  -- different field handling you need to compose data list in main script
  -- and paste all lists to moon-searcher in unified format {index, content}
  -- TODO: write this func looking at search-page KEYBINDS:search function
end

local function chapter_info_update()
  chapter.list = get_chapters()

  if not #chapter.list then return end

  -- tho list might b already present, but 'chapter' still might b nil
  -- and we also add one index when we get from mp
  chapter.current_i = (mp.get_property_native("chapter") or 0) + 1
end

-- REVIEW: where is 'a good place' to define all those observers and listeners?
mp.register_event("file-loaded", chapter_info_update)
mp.observe_property("chapter-list/count", "number", chapter_info_update)
mp.observe_property("chapter", "number", chapter_info_update)

-- keybind to launch menu
mp.add_key_binding(opts.toggle_menu_binding, "chapters-menu", function()
                     chapter_menu:init(chapter)
end)
