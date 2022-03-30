-- display chapter on osd and easily switch between chapters by click on title
-- of chapter

-- Possible TODO:
-- add timeout functionality? for now i don't c any reason for CHAPTERS menu
--   but in case u gonna add those - look at how it was coded in yt-quality
-- make it possible to bind several kbds to 'close' event
--   like in SimpleHistory line 357 function does
--   mp.add_forced_key_binding(opts.toggle_menu_binding, "escape", destroy)


local mp = require 'mp' -- isn't actually required, mp still gonna be defined
-- local msg = require 'mp.msg'

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"})..package.path
local searcher = require "moon-searcher"

local opts = {
  toggle_menu_binding = "g",
  up_binding          = "Ctrl+k",
  down_binding        = "Ctrl+j",
}

local chapter = {list = {}, current_i = nil}

-- REVIEW: works?
(require 'mp.options').read_options(opts, mp.get_script_name())

local function get_chapters()
  local chaptersCount = mp.get_property("chapter-list/count")
  if chaptersCount == 0 then
    return nil
  else
    local chaptersArr = {}

    -- We need to start from 0 here cuz mp returns titles starting with 0
    for i=0, chaptersCount do
      local chapterTitle = mp.get_property_native("chapter-list/"..i.."/title")
      if chapterTitle then
        table.insert(chaptersArr, {index = i + 1, title = chapterTitle})
      end
    end

    return chaptersArr
  end
end

local function submit(val)
  -- .. and we subtract one index when we set to mp
  mp.set_property_native("chapter", val.index - 1)
end

local function chapter_info_update()
  chapter.list = get_chapters()

  -- so we add one index when we get from mp
  chapter.current_i = mp.get_property_native("chapter") + 1
end

-- keybind to launch menu
mp.add_key_binding(opts.toggle_menu_binding, "chapters-menu", searcher:init(chapter, submit))

-- REVIEW: where is 'a good place' to define all those observers and listeners?
mp.register_event("file-loaded", chapter_info_update)
mp.observe_property("chapter-list/count", "number", chapter_info_update)
mp.observe_property("chapter", "number", chapter_info_update)
