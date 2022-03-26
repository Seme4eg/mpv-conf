-- display chapter on osd and easily switch between chapters by click on title
-- of chapter

-- Possible TODO:
-- add timeout functionality? for now i don't c any reason for CHAPTERS menu
--   but in case u gonna add those - look at how it was coded in yt-quality
-- make it possible to bind several kbds to 'close' event
--   like in SimpleHistory line 357 function does
--   mp.add_forced_key_binding(opts.toggle_menu_binding, "escape", destroy)


local mp = require 'mp'
local msg = require 'mp.msg'

-- TODO: better way of using assdraw?:
-- local assdraw = require 'mp.assdraw'
-- or https://mpv.io/manual/master/#lua-scripting-mp-create-osd-overlay(format)
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

-- TODO: how to obtain script name?
(require 'mp.options').read_options(opts, "moon")

-- GLOBAL vars
local is_shown = false
local chapter = {
  list = {},
  current_i = nil, -- currently playing one
  selected_i = nil, -- currently being hovered by user
  count = nil,
}

function Get_chapters()
  local chaptersCount = mp.get_property("chapter-list/count")
  if chaptersCount == 0 then
    -- TODO: if there are no chapters - draw a menu with 'no chaps' text
    -- styled differently
    return nil
  else
    local chaptersArr = {}

    for i=0, chaptersCount do
      local chapterTitle = mp.get_property_native("chapter-list/"..i.."/title")
      if chapterTitle then table.insert(chaptersArr, chapterTitle) end
    end

    return chaptersArr
  end
end

function Toggle_menu()
  if is_shown then
    is_shown = false
    assdraw:remove()
    Clear_keybindings()
  else
    is_shown = true
    assdraw:update()
    Init_keybindings()
  end
end

function Init_keybindings()
  local function change_selected_index(num)
    chapter.selected_i = chapter.selected_i + num
    if chapter.selected_i < 1 then chapter.selected_i = chapter.count
    elseif chapter.selected_i > chapter.count then chapter.selected_i = 1 end
    Set_menu_content()
    assdraw:update()
  end

  mp.add_forced_key_binding(opts.up_binding,     "move_up",   function() change_selected_index(-1) end, {repeatable=true})
  mp.add_forced_key_binding(opts.down_binding,   "move_down", function() change_selected_index(1)  end, {repeatable=true})
  mp.add_forced_key_binding(opts.select_binding, "select",    function()
                              Toggle_menu()
                              mp.set_property_native("chapter", chapter.selected_i)
  end)

end

function Clear_keybindings()
  mp.remove_key_binding("move_up")
  mp.remove_key_binding("move_down")
  mp.remove_key_binding("select")
  mp.remove_key_binding("escape")
end

function Set_menu_content()
  local function font_color(c)
    return (chapter.list[chapter.current_i] == c)
      and opts.current_color or "FFFFFF"
  end

  local function pointer(c)
    return (c == chapter.list[chapter.selected_i])
      and opts.pointer_icon or '  '
  end

  local posY = 50
  local assdrawdata = ""

  for _,v in ipairs(chapter.list) do
    assdrawdata = assdrawdata..
      -- REVIEW: put position values in opts? any1 needs it?
      "{\\pos(50, "..posY..")}"..     -- position
      "{\\bord1}"..                   -- border size
      "{\\c&H"..font_color(v).."&}".. -- font color
      "{\\fs"..opts.font_size.."}"..  -- font size
      "{\\p0}"..                      -- end of modifiers
      pointer(v)..v.."\n"

    posY = posY + opts.font_size
  end

  assdraw.data = assdrawdata
end

function Chapter_info_update()
  chapter.list = Get_chapters()
  chapter.count = tonumber(mp.get_property("chapter-list/count"))

  if chapter.count == 0 then return nil end

  chapter.current_i = mp.get_property_native("chapter")
  chapter.selected_i = chapter.current_i

  Set_menu_content()
end

-- keybind to launch menu
mp.add_key_binding(opts.toggle_menu_binding, "chapters-menu", Toggle_menu)

-- REVIEW: is there always one tsar' function? how ppl are 'initing' their
-- scripts is anyone using some kind of 'init' function and how?

-- TODO: where is 'a good place' to define all those observers and listeners?
mp.register_event("file-loaded", Chapter_info_update)
mp.observe_property("chapter-list/count", "number", Chapter_info_update)
mp.observe_property("chapter", "number", Chapter_info_update)
