-- TODO:
-- throw an error in console if any of required handlers were not passed


local mp = require 'mp'
-- local msg = require 'mp.msg'
local utils = require 'mp.utils'

local assdraw = require 'mp.assdraw'

local searcher = {
  line = '',
  cursor = 1,
  history = {},
  history_pos = 1,
  key_bindings = {},
  insert_mode = false,
  styles = {
    font_size = 18,
  },
  handlers = {},
}

--[[
  The below code is a modified implementation of text input from mpv's console.lua:
  https://github.com/mpv-player/mpv/blob/87c9eefb2928252497f6141e847b74ad1158bc61/player/lua/console.lua

  I was too lazy to list all modifications i've done to the script, but if u
  rly need to see those - do diff with the code in the above link..
]]--

-------------------------------------------------------------------------------
--                          START ORIGINAL MPV CODE                          --
-------------------------------------------------------------------------------

-- Copyright (C) 2019 the mpv developers
--
-- Permission to use, copy, modify, and/or distribute this software for any
-- purpose with or without fee is hereby granted, provided that the above
-- copyright notice and this permission notice appear in all copies.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
-- WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
-- MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
-- SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
-- WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
-- OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
-- CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

function searcher:detect_platform()
  local o = {}
  -- Kind of a dumb way of detecting the platform but whatever
  if mp.get_property_native('options/vo-mmcss-profile', o) ~= o then
    return 'windows'
  elseif mp.get_property_native('options/macos-force-dedicated-gpu', o) ~= o then
    return 'macos'
  elseif os.getenv('WAYLAND_DISPLAY') then
    return 'wayland'
  end
  return 'x11'
end

-- Escape a string for verbatim display on the OSD
function searcher:ass_escape(str)
  -- There is no escape for '\' in ASS (I think?) but '\' is used verbatim if
  -- it isn't followed by a recognised character, so add a zero-width
  -- non-breaking space
  str = str:gsub('\\', '\\\239\187\191')
  str = str:gsub('{', '\\{')
  str = str:gsub('}', '\\}')
  -- Precede newlines with a ZWNBSP to prevent ASS's weird collapsing of
  -- consecutive newlines
  str = str:gsub('\n', '\239\187\191\\N')
  -- Turn leading spaces into hard spaces to prevent ASS from stripping them
  str = str:gsub('\\N ', '\\N\\h')
  str = str:gsub('^ ', '\\h')
  return str
end

-- Render the REPL and console as an ASS OSD
function searcher:update()
  local ass = assdraw.ass_new()

  local style =
    '{\\r\\fs' .. self.styles.font_size .. '\\bord1}'

  -- Create the cursor glyph as an ASS drawing. ASS will draw the cursor
  -- inline with the surrounding text, but it sets the advance to the width
  -- of the drawing. So the cursor doesn't affect layout too much, make it as
  -- thin as possible and make it appear to be 1px wide by giving it 0.5px
  -- horizontal borders.
  local cheight = self.styles.font_size * 8
  local cglyph = '{\\r' ..
    '{\\1a&H44&\\3a&H44&\\4a&H99&' ..
    '\\1c&Heeeeee&\\3c&Heeeeee&\\4c&H000000&' ..
    '\\xbord0.5\\ybord0\\xshad0\\yshad1\\p4\\pbo24}' ..
    'm 0 0 l 1 0 l 1 ' .. cheight .. ' l 0 ' .. cheight ..
    '{\\p0}'
  local before_cur = self:ass_escape(self.line:sub(1, self.cursor - 1))
  local after_cur = self:ass_escape(self.line:sub(self.cursor))

  ass:new_event()
  ass:an(1)
  ass:append(style .. before_cur .. cglyph .. style .. after_cur)

  -- Redraw the cursor with the REPL text invisible. This will make the
  -- cursor appear in front of the text.
  -- ass:new_event()
  -- ass:an(1)
  -- ass:append(style .. '{\\alpha&HFF&}> ' .. before_cur)
  -- ass:append(cglyph)
  -- ass:append(style .. '{\\alpha&HFF&}' .. after_cur)

  self.handlers.input(ass.text, before_cur..after_cur)

  -- return ass.text
end

-- Naive helper function to find the next UTF-8 character in 'str' after 'pos'
-- by skipping continuation bytes. Assumes 'str' contains valid UTF-8.
function searcher:next_utf8(str, pos)
  if pos > str:len() then return pos end
  repeat
    pos = pos + 1
  until pos > str:len() or str:byte(pos) < 0x80 or str:byte(pos) > 0xbf
  return pos
end

-- As above, but finds the previous UTF-8 charcter in 'str' before 'pos'
function searcher:prev_utf8(str, pos)
  if pos <= 1 then return pos end
  repeat
    pos = pos - 1
  until pos <= 1 or str:byte(pos) < 0x80 or str:byte(pos) > 0xbf
  return pos
end

-- Insert a character at the current cursor position (any_unicode)
function searcher:handle_char_input(c)
  if self.insert_mode then
    self.line = self.line:sub(1, self.cursor - 1) .. c .. self.line:sub(self:next_utf8(self.line, self.cursor))
  else
    self.line = self.line:sub(1, self.cursor - 1) .. c .. self.line:sub(self.cursor)
  end
  self.cursor = self.cursor + #c
  self:update()
end

-- Remove the character behind the cursor (Backspace)
function searcher:handle_backspace()
  if self.cursor <= 1 then return end
  local prev = self:prev_utf8(self.line, self.cursor)
  self.line = self.line:sub(1, prev - 1) .. self.line:sub(self.cursor)
  self.cursor = prev
  self:update()
end

-- Remove the character in front of the cursor (Del)
function searcher:handle_del()
  if self.cursor > self.line:len() then return end
  self.line = self.line:sub(1, self.cursor - 1) .. self.line:sub(self:next_utf8(self.line, self.cursor))
  self:update()
end

-- Toggle insert mode (Ins)
function searcher:handle_ins()
  self.insert_mode = not self.insert_mode
end

-- Move the cursor to the next character (Right)
function searcher:next_char()
  self.cursor = self:next_utf8(self.line, self.cursor)
  self:update()
end

-- Move the cursor to the previous character (Left)
function searcher:prev_char()
  self.cursor = self:prev_utf8(self.line, self.cursor)
  self:update()
end

-- Clear the current line (Ctrl+C)
function searcher:clear()
  self.line = ''
  self.cursor = 1
  self.insert_mode = false
  self.history_pos = #self.history + 1
  self:update()
end

-- TODO: bind this to C-h maybe
function searcher:help_command(param)
  local cmdlist = mp.get_property_native('command-list')
  local output = ''
  if param == '' then
    output = 'Available commands:\n'
    for _, cmd in ipairs(cmdlist) do
      output = output  .. '  ' .. cmd.name
    end
    output = output .. '\n'
    output = output .. 'Use "help command" to show information about a command.\n'
    output = output .. "ESC or Ctrl+d exits the console.\n"
  else
    local cmd = nil
    for _, curcmd in ipairs(cmdlist) do
      if curcmd.name:find(param, 1, true) then
        cmd = curcmd
        if curcmd.name == param then
          break -- exact match
        end
      end
    end
    output = output .. 'Command "' .. cmd.name .. '"\n'
    for _, arg in ipairs(cmd.args) do
      output = output .. '    ' .. arg.name .. ' (' .. arg.type .. ')'
      if arg.optional then
        output = output .. ' (optional)'
      end
      output = output .. '\n'
    end
    if cmd.vararg then
      output = output .. 'This command supports variable arguments.\n'
    end
  end
  -- log_add('', output)
end

-- Run the current command and clear the line (Enter)
function searcher:handle_enter()
  if self.line == '' then
    return
  end
  if self.history[#self.history] ~= self.line then
    self.history[#self.history + 1] = self.line
  end

  -- match "help [<text>]", return <text> or "", strip all whitespace
  local help = self.line:match('^%s*help%s+(.-)%s*$') or
    (self.line:match('^%s*help$') and '')
  if help then
    self:help_command(help)
  else
    mp.command(self.line)
  end

  self:clear()
end

-- Go to the specified position in the command history
function searcher:go_history(new_pos)
  local old_pos = self.history_pos
  self.history_pos = new_pos

  -- Restrict the position to a legal value
  if self.history_pos > #self.history + 1 then
    self.history_pos = #self.history + 1
  elseif self.history_pos < 1 then
    self.history_pos = 1
  end

  -- Do nothing if the history position didn't actually change
  if self.history_pos == old_pos then
    return
  end

  -- If the user was editing a non-history line, save it as the last history
  -- entry. This makes it much less frustrating to accidentally hit Up/Down
  -- while editing a line.
  if old_pos == #self.history + 1 and self.line ~= '' and self.history[#self.history] ~= self.line then
    self.history[#self.history + 1] = self.line
  end

  -- Now show the history line (or a blank line for #history + 1)
  if self.history_pos <= #self.history then
    self.line = self.history[self.history_pos]
  else
    self.line = ''
  end
  self.cursor = self.line:len() + 1
  self.insert_mode = false
  self:update()
end

-- Go to the specified relative position in the command history (Up, Down)
function searcher:move_history(amount)
  self:go_history(self.history_pos + amount)
end

-- Go to the first command in the command history (PgUp)
function searcher:handle_pgup()
  self:go_history(1)
end

-- Stop browsing history and start editing a blank line (PgDown)
function searcher:handle_pgdown()
  self:go_history(#self.history + 1)
end

-- Move to the start of the current word, or if already at the start, the start
-- of the previous word. (Ctrl+Left)
function searcher:prev_word()
  -- This is basically the same as next_word() but backwards, so reverse the
  -- string in order to do a "backwards" find. This wouldn't be as annoying
  -- to do if Lua didn't insist on 1-based indexing.
  self.cursor = self.line:len() - select(2, self.line:reverse():find('%s*[^%s]*', self.line:len() - self.cursor + 2)) + 1
  self:update()
end

-- Move to the end of the current word, or if already at the end, the end of
-- the next word. (Ctrl+Right)
function searcher:next_word()
  self.cursor = select(2, self.line:find('%s*[^%s]*', self.cursor)) + 1
  self:update()
end

-- Move the cursor to the beginning of the line (HOME)
function searcher:go_home()
  self.cursor = 1
  self:update()
end

-- Move the cursor to the end of the line (END)
function searcher:go_end()
  self.cursor = self.line:len() + 1
  self:update()
end

-- Delete from the cursor to the beginning of the word (Ctrl+Backspace)
function searcher:del_word()
  local before_cur = self.line:sub(1, self.cursor - 1)
  local after_cur = self.line:sub(self.cursor)

  before_cur = before_cur:gsub('[^%s]+%s*$', '', 1)
  self.line = before_cur .. after_cur
  self.cursor = before_cur:len() + 1
  self:update()
end

-- Delete from the cursor to the end of the word (Ctrl+Del)
function searcher:del_next_word()
  if self.cursor > self.line:len() then return end

  local before_cur = self.line:sub(1, self.cursor - 1)
  local after_cur = self.line:sub(self.cursor)

  after_cur = after_cur:gsub('^%s*[^%s]+', '', 1)
  self.line = before_cur .. after_cur
  self:update()
end

-- Delete from the cursor to the end of the line (Ctrl+K)
function searcher:del_to_eol()
  self.line = self.line:sub(1, self.cursor - 1)
  self:update()
end

-- Delete from the cursor back to the start of the line (Ctrl+U)
function searcher:del_to_start()
  self.line = self.line:sub(self.cursor)
  self.cursor = 1
  self:update()
end

-- Returns a string of UTF-8 text from the clipboard (or the primary selection)
function searcher:get_clipboard(clip)
  -- Pick a better default font for Windows and macOS
  local platform = self:detect_platform()

  if platform == 'x11' then
    local res = utils.subprocess({
        args = { 'xclip', '-selection', clip and 'clipboard' or 'primary', '-out' },
        playback_only = false,
    })
    if not res.error then
      return res.stdout
    end
  elseif platform == 'wayland' then
    local res = utils.subprocess({
        args = { 'wl-paste', clip and '-n' or  '-np' },
        playback_only = false,
    })
    if not res.error then
      return res.stdout
    end
  elseif platform == 'windows' then
    local res = utils.subprocess({
        args = { 'powershell', '-NoProfile', '-Command', [[& {
                Trap {
                    Write-Error -ErrorRecord $_
                    Exit 1
                }

                $clip = ""
                if (Get-Command "Get-Clipboard" -errorAction SilentlyContinue) {
                    $clip = Get-Clipboard -Raw -Format Text -TextFormatType UnicodeText
                } else {
                    Add-Type -AssemblyName PresentationCore
                    $clip = [Windows.Clipboard]::GetText()
                }

                $clip = $clip -Replace "`r",""
                $u8clip = [System.Text.Encoding]::UTF8.GetBytes($clip)
                [Console]::OpenStandardOutput().Write($u8clip, 0, $u8clip.Length)
            }]] },
        playback_only = false,
    })
    if not res.error then
      return res.stdout
    end
  elseif platform == 'macos' then
    local res = utils.subprocess({
        args = { 'pbpaste' },
        playback_only = false,
    })
    if not res.error then
      return res.stdout
    end
  end
  return ''
end

-- Paste text from the window-system's clipboard. 'clip' determines whether the
-- clipboard or the primary selection buffer is used (on X11 and Wayland only.)
function searcher:paste(clip)
  local text = self:get_clipboard(clip)
  local before_cur = self.line:sub(1, self.cursor - 1)
  local after_cur = self.line:sub(self.cursor)
  self.line = before_cur .. text .. after_cur
  self.cursor = self.cursor + text:len()
  self:update()
end

-- List of input bindings. This is a weird mashup between common GUI text-input
-- bindings and readline bindings.
function searcher:get_bindings()
  local bindings = {
    { 'ctrl+[',      function() self:exit() end                 },
    { 'ctrl+g',      function() self:exit() end                 },
    { 'esc',         function() self:exit() end                 },
    { 'enter',       function() self:handle_enter() end         },
    { 'kp_enter',    function() self:handle_enter() end         },
    { 'ctrl+m',      function() self:handle_enter() end         },
    { 'bs',          function() self:handle_backspace() end     },
    { 'shift+bs',    function() self:handle_backspace() end     },
    { 'ctrl+h',      function() self:handle_backspace() end     },
    { 'del',         function() self:handle_del() end           },
    { 'shift+del',   function() self:handle_del() end           },
    { 'ins',         function() self:handle_ins() end           },
    { 'shift+ins',   function() self:paste(false) end           },
    { 'mbtn_mid',    function() self:paste(false) end           },
    { 'left',        function() self:prev_char() end            },
    { 'ctrl+b',      function() self:prev_char() end            },
    { 'right',       function() self:next_char() end            },
    { 'ctrl+f',      function() self:next_char() end            },
    { 'up',          function() self:move_history(-1) end       },
    { 'alt+p',       function() self:move_history(-1) end       },
    { 'wheel_up',    function() self:move_history(-1) end       },
    { 'down',        function() self:move_history(1) end        },
    { 'alt+n',       function() self:move_history(1) end        },
    { 'wheel_down',  function() self:move_history(1) end        },
    { 'wheel_left',  function() end                             },
    { 'wheel_right', function() end                             },
    { 'ctrl+left',   function() self:prev_word() end            },
    { 'alt+b',       function() self:prev_word() end            },
    { 'ctrl+right',  function() self:next_word() end            },
    { 'alt+f',       function() self:next_word() end            },
    { 'ctrl+a',      function() self:go_home() end              },
    { 'home',        function() self:go_home() end              },
    { 'ctrl+e',      function() self:go_end() end               },
    { 'end',         function() self:go_end() end               },
    { 'pgup',        function() self:handle_pgup() end          },
    { 'pgdwn',       function() self:handle_pgdown() end        },
    { 'ctrl+c',      function() self:clear() end                },
    { 'ctrl+d',      function() self:handle_del() end           },
    { 'ctrl+u',      function() self:del_to_start() end         },
    { 'ctrl+v',      function() self:paste(true) end            },
    { 'meta+v',      function() self:paste(true) end            },
    { 'ctrl+bs',     function() self:del_word() end             },
    { 'ctrl+w',      function() self:del_word() end             },
    { 'ctrl+del',    function() self:del_next_word() end        },
    { 'alt+d',       function() self:del_next_word() end        },
    { 'kp_dec',      function() self:handle_char_input('.') end },
  }

  for i = 0, 9 do
    bindings[#bindings + 1] =
      {'kp' .. i, function() self:handle_char_input('' .. i) end}
  end

  return bindings
end

function searcher:text_input(info)
  if info.key_text and (info.event == "press" or info.event == "down"
                        or info.event == "repeat")
  then
    self:handle_char_input(info.key_text)
  end
end

function searcher:define_key_bindings()
  if #self.key_bindings > 0 then
    return
  end
  for _, bind in ipairs(self:get_bindings()) do
    -- Generate arbitrary name for removing the bindings later.
    local name = "search_" .. (#self.key_bindings + 1)
    self.key_bindings[#self.key_bindings + 1] = name
    mp.add_forced_key_binding(bind[1], name, bind[2], {repeatable = true})
  end
  mp.add_forced_key_binding("any_unicode", "search_input", function (...)
                              self:text_input(...)
  end, {repeatable = true, complex = true})
  self.key_bindings[#self.key_bindings + 1] = "search_input"
end

function searcher:undefine_key_bindings()
  for _, name in ipairs(self.key_bindings) do
    mp.remove_key_binding(name)
  end
  self.key_bindings = {}
end

-------------------------------------------------------------------------------
--                           END ORIGINAL MPV CODE                           --
-------------------------------------------------------------------------------

function searcher:init(input_fn, submit_fn, exit_fn, styles)
  self.handlers = {input = input_fn, submit = submit_fn, exit = exit_fn}

  for i,v in pairs(styles or {}) do self.styles[i] = v end

  self:define_key_bindings()
end

function searcher:exit()
  self:undefine_key_bindings()
  self.handlers.exit()
  collectgarbage()
end

return searcher
