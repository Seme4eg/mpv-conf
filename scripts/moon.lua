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
local chapter = {
  list = {},
  current_i = nil, -- currently playing one
  selected_i = nil, -- currently being hovered by user
  count = nil,
}

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
      if chapterTitle then table.insert(chaptersArr, chapterTitle) end
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

  local function pointer(c)
    return (c == chapter.list[chapter.selected_i])
      and opts.pointer_icon or '  '
  end

  -- form search string and put it always on top
  osd_msg = get_styles('search') ..
    -- TODO: setup blinking _
    chapter.selected_i .. '/' .. chapter.count .. '   Select chapter: ' .. osd_msg_end

  for _,v in ipairs(chapter.list) do
    local style = (chapter.list[chapter.current_i] == v) and 'current' or 'text'
    osd_msg = osd_msg .. get_styles(style) .. pointer(v) .. v .. osd_msg_end
  end

  assdraw.data = osd_msg
end

local function init_keybindings()



  local function change_selected_index(num)
    chapter.selected_i = chapter.selected_i + num
    if chapter.selected_i < 1 then chapter.selected_i = chapter.count
    elseif chapter.selected_i > chapter.count then chapter.selected_i = 1 end
    set_menu_content()
    assdraw:update()
  end

  mp.add_forced_key_binding(opts.up_binding,     "move_up",   function() change_selected_index(-1) end, {repeatable=true})
  mp.add_forced_key_binding(opts.down_binding,   "move_down", function() change_selected_index(1)  end, {repeatable=true})
  mp.add_forced_key_binding(opts.select_binding, "select",    function()
                              Toggle_chapters_menu()
                              -- .. and we subtract one index when we set to mp
                              mp.set_property_native("chapter", chapter.selected_i - 1)
  end)

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
end

local function chapter_info_update()
  chapter.list = get_chapters()
  chapter.count = tonumber(mp.get_property("chapter-list/count"))

  if chapter.count == 0 then return nil end

  -- so we add one index when we get from mp
  chapter.current_i = mp.get_property_native("chapter") + 1
  chapter.selected_i = chapter.current_i

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
