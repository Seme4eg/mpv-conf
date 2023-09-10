-- source: https://github.com/oltodosel/mpv-scripts/blob/master/pause-indicator.lua

local ov = mp.create_osd_overlay('ass-events')
-- TODO: how to more reliably center icon in center and not hardcode it?
ov.data = [[{\an5\p1\alpha&H79\1c&Hffffff&\3a&Hff\pos(100,100)}]] ..
    [[m-85 -45 l 2 2 l -85 45]]

mp.observe_property('pause', 'bool', function(_, paused)
  mp.add_timeout(0.1, function()
    if paused then
      ov:update()
    else
      ov:remove()
    end
  end)
end)
