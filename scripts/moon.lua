-- script:
-- - init()
--   + get_chapters_info() -> gets all chapters & current chapter
--   + extended_menu init()
-- - and stores only those 2
-- - submit() -> ... -> get_chapters_info() -> extended_menu:update/init()
-- - filter_fn(list)

-- extended menu:
-- - init(list, [current], on_submit, [filter_fn]) # filter_fn cuz data might have
--   different fields and /maybe/ make default one
--   + sets list
--   + =current=? -> update inner prop 'pointer_id' with set_pointer()
-- - data:
--   + pointer_index
--   + current_index
--   + list obj (full, filtered, current (any way to remove last?))
-- - *one* =update()= -> =query= changed? -> no?-just rerender assdraw;
--   yes?-=filter_list()= and then rerender assdraw
-- - manages =C-j/k=
-- - /questions/:
--   - should have =get_pointer()= func to call it whenever main script event
--     =on_submit()= is fired

-- NOTES:
-- - refresh =list= from /extended_menu/? -> pass =refresh_fn= to extended_menu:init()


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

-- TODO: better way of using assdraw?:
-- local assdraw = require 'mp.assdraw'
-- or
-- mp.set_ods_ass(0, 0, msg)
-- or
-- https://mpv.io/manual/master/#lua-scripting-mp-create-osd-overlay(format)
local assdraw = mp.create_osd_overlay("ass-events")

local opts = {
  -- key bindings
  toggle_menu_binding = "g",
  up_binding          = "Ctrl+k",
  down_binding        = "Ctrl+j",
  select_binding      = "ENTER",

  pointer_icon = "▶ ",
  font_size = 18,
  current_color = "aaaaaa"
}

-- REVIEW: works?
(require 'mp.options').read_options(opts, mp.get_script_name())

-- GLOBAL vars
local is_shown = false
local search = {
  query = '', -- actual search string
  placeholder = '' -- just a visual part of search (includes cursor and styles)
}
local chapter = {
  full_list = {},
  filtered_list = {},
  current_i = nil, -- currently playing one
  selected_i = nil, -- currently being hovered by user
  count = nil,
}

-- FIXME: how to make this function a variable in the above object?
function chapter:current_list()
  return next(self.filtered_list) and self.filtered_list or self.full_list
end

local function get_chapters()
  local chaptersCount = mp.get_property("chapter-list/count")
  if chaptersCount == 0 then
    -- TODO: if there are no chapters - draw a menu with 'no chaps' text
    -- styled differently
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

local function clear_keybindings()
  mp.remove_key_binding("move_up")
  mp.remove_key_binding("move_down")
  mp.remove_key_binding("select")
  mp.remove_key_binding("escape")
end

local function set_menu_content()
  local osd_msg = ''
  local styles = {
    -- Values in tables below accordingly: alignment, border, color
    search = {7, 1, '2153b0', 18},
    -- REVIEW: better name for that list? plain? just_text? common?
    text = {7, 1, 'ffffff', 18},
    current = {7, 1, 'aaaaaa', 18},
    -- 'hover' = {7, 1, 'aaaaaa'},
  }
  -- to reset text color after each iteration
	local osd_msg_end = "\\h\\N\\N{\\1c&HFFFFFF}"

  local function get_styles(style)
    -- ASS tags documentation here - https://aegi.vmoe.info/docs/3.0/ASS_Tags/
    local style_str = "{\\an%f}{\\bord%f}{\\1c&H%s}{\\fs%f}"
    return string.format(style_str, table.unpack(styles[style]))
  end

  local function pointer(i)
    return (i == chapter.selected_i) and opts.pointer_icon or '  '
  end

  -- form search string and put it always on top
  osd_msg = get_styles('search') ..
    chapter.selected_i .. '/' .. chapter.count ..
    '   Select chapter: ' .. search.placeholder .. osd_msg_end

  for i,v in ipairs(chapter:current_list()) do
    local style = (chapter.current_i == v.index) and 'current' or 'text'
    osd_msg = osd_msg .. get_styles(style) .. pointer(i) .. v.title .. osd_msg_end
  end

  assdraw.data = osd_msg
end

local function filter_list()
  local list = {}
  for _,v in ipairs(chapter.full_list) do
    if not not string.find(v.title, search.query) then table.insert(list, v) end
  end
  chapter.filtered_list = list
  chapter.selected_i = next(chapter:current_list())
end

local function init_keybindings()
  local function handle_search(placeholder, query)
    search.placeholder = placeholder
    search.query = query
    filter_list()
    set_menu_content()
    assdraw:update()
  end

  local function handle_submit(text) mp.msg.info(text, 'sub') end

  searcher:init(handle_search, handle_submit, Toggle_chapters_menu)

  local function change_selected_index(num)
    chapter.selected_i = chapter.selected_i + num
    if chapter.selected_i < 1 then chapter.selected_i = chapter.count
    elseif chapter.selected_i > chapter.count then chapter.selected_i = 1 end
    set_menu_content()
    assdraw:update()
  end

  mp.add_forced_key_binding(opts.up_binding,     "move_up",   function() change_selected_index(-1) end, {repeatable=true})
  mp.add_forced_key_binding(opts.down_binding,   "move_down", function() change_selected_index(1) end, {repeatable=true})
  mp.add_forced_key_binding(opts.select_binding, "select",    function()
                              -- .. and we subtract one index when we set to mp
                              mp.set_property_native("chapter", chapter:current_list()[chapter.selected_i].index - 1)
                              Toggle_chapters_menu()
  end)

end

local function reset_selected()
  -- so we add one index when we get from mp
  chapter.selected_i = chapter.current_i
end

-- FIXME: find a way to make this func local and not break the code
function Toggle_chapters_menu()
  if is_shown then
    is_shown = false
    assdraw:remove()
    clear_keybindings()
  else
    is_shown = true
    assdraw:update()
    init_keybindings()
  end

  search = {
    query = '',
    placeholder = ''
  }
  chapter.filtered_list = {}
  reset_selected()
end

local function chapter_info_update()
  chapter.full_list = get_chapters()
  -- REVIEW: maybe get rid of it? and call #full_list whenever i need it?
  chapter.count = tonumber(mp.get_property("chapter-list/count"))

  if chapter.count == 0 then return nil end

  -- so we add one index when we get from mp
  chapter.current_i = mp.get_property_native("chapter") + 1
  reset_selected()

  set_menu_content()
end

-- keybind to launch menu
mp.add_key_binding(opts.toggle_menu_binding, "chapters-menu", Toggle_chapters_menu)

-- REVIEW: is there always one tsar' function? how ppl are 'initing' their
-- scripts is anyone using some kind of 'init' function and how?

-- REVIEW: where is 'a good place' to define all those observers and listeners?
mp.register_event("file-loaded", chapter_info_update)
mp.observe_property("chapter-list/count", "number", chapter_info_update)
mp.observe_property("chapter", "number", chapter_info_update)
