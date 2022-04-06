local mp = require 'mp' -- isn't actually required, mp still gonna be defined
local assdraw = require 'mp.assdraw'

-- should not be altered here, edit options in corresponding .conf file
local opts = {
  toggle_menu_binding = 't',
  lines_to_show = 17, -- NOT including search line
  pause_on_start = true,
  resume_on_exit = "only-if-was-paused", -- another possible value is true

  font_size=21,
  line_bottom_margin = 1, -- basically space between lines

  strip_cmd_at = 65,

  -- not rly worth putting in .conf file --------------------------------------

  search_heading = 'M-x',
  -- fields to use when searching for string match / any other custom searching
  -- if value has 0 length, then search list item itself
  filter_by_fields = {'cmd'},
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

local data = {list = {}}

function chapter_menu:submit(val)
  -- .. and we subtract one index when we set to mp
  mp.msg.info(#val.cmd, 'dmg len')
end

-- this function needs to be part of 'chapter_menu' to get access to 'self'
function chapter_menu:get_cmd_list()
  -- in order to not store composing functions in moon-searcher and managing
  -- different field handling you need to compose data list in main script
  -- and paste all lists to moon-searcher in unified format {index, content}

  local bindings = mp.get_property_native("input-bindings")

  table.sort(bindings, function(i, j)
               return tonumber(i.priority) > tonumber(j.priority)
  end)

  for _,v in ipairs(bindings) do
    for _,v1 in ipairs(bindings) do
      if v.key == v1.key and v.priority < v1.priority then
        v.shadowed = true
        break
      end
    end
  end

  data.list = bindings

  -- We need to start from 0 here cuz mp returns titles starting with 0
  -- for i, binding in ipairs(bindings) do
  -- end
end

-- redefine get_line
function em:get_line(_, v) -- [i]ndex [v]alue
    local a = assdraw.ass_new()
    -- 20 is just a hardcoded value, cuz i don't think any keybinding string
    -- length might exceed this value
    local comment_offset = opts.strip_cmd_at + 20

    local cmd = v.cmd

    -- strip cmd if more than 'len'
    if #cmd > opts.strip_cmd_at then
      cmd = string.sub(cmd, 1, opts.strip_cmd_at - 3) .. '...'
    end

    -- we need to count length of strings without escaping chars, so we
    -- calculate this variable before defining excaped strings
    local cmdkbd_len = #(cmd .. v.key) + 3 -- 3 is ' ()'

    cmd = self:ass_escape(cmd)
    local key = self:ass_escape(v.key)
    local comment = self:ass_escape(v.comment or '')

    local function get_spaces(num)
      local s = ''
      for _=1,num do s = s .. '\\h' end
      return s
    end

    if comment and comment:find('show the') then
      -- mp.msg.info(cmd, key, comment, 'BUG')
      mp.msg.info(#cmd, #v.cmd, 'BUG')
    end

    -- handle inactive keybindings
    if v.shadowed or v.priority == -1 then
      local why_inactive = (v.priority == -1)
        and 'inactive keybinding'
        or 'that binding is currently shadowed by another one'

      a:append(self:get_font_color('comment'))
      a:append(cmd)
      a:append('\\h(' .. key .. ')')
      -- REVIEW: maybe move substitution to 'get_spaces'?
      a:append(get_spaces(comment_offset - cmdkbd_len))
      a:append('(' .. why_inactive .. ')')
      return a.text
    end

    a:append(self:get_font_color('default'))
    a:append(cmd)
    -- a:append('\\h(' .. v.priority .. ')')
    a:append(self:get_font_color('search'))
    a:append('\\h(' .. key .. ')')
    a:append(self:get_font_color('comment'))
    a:append(get_spaces(comment_offset - cmdkbd_len))
    a:append(comment and comment or '')
    return a.text
end

mp.register_event("file-loaded", function() chapter_menu:get_cmd_list() end)

-- keybind to launch menu
mp.add_key_binding(opts.toggle_menu_binding, "M-x", function()
                     chapter_menu:init(data)
end)
