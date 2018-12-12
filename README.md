# wizgui
gui library for love2d based on trubblegum/Gspot

```lua
--window
  window1 = gui:window('Window', {50, 50, 300, 300}, nil, 'none')
  window1.minw = 128
  window1.minh = 64
  window1.resize = function(self)
    input.pos.w = input.parent.pos.w - input.parent.style.padding * 2
    scrollgroup.pos.w = window1.pos.w - window1.style.padding
    scrollgroup.pos.h = window1.pos.h
    scrollgroup:positioncontrols()

    if scrollgroup.scrollv then
      scrollgroup.scrollv.values.max = math.max(scrollgroup:getmaxh() - scrollgroup.pos.h, 0)
      scrollgroup.scrollv.values.current = math.min(scrollgroup.scrollv.values.current, scrollgroup.scrollv.values.max)
    end
  end

  scrollgroup = gui:scrollgroup(nil, {0, 0, window1.pos.w - window1.style.padding, window1.pos.h}, window1, 'vertical')
  
  for i=1, 40 do
    textlabel = gui:text('Text label '..i, {0, 0}, nil, true)
    scrollgroup:addchild(textlabel, 'vertical')
  end

  -- text input
  input = gui:input(nil, {window1.style.padding, window1.style.padding, scrollgroup.pos.w - gui.style.padding * 2, scrollgroup.style.padding})
  input.done = function(self)
    gui:feedback('I say '..self.value) --interface feedback
    self.value = ''
    self.gui:unfocus()
  end
  scrollgroup:addchild(input, 'vertical')

  window2 = gui:window('Another', {530, 250, 200, 200}, nil, 'none')
  gui:rem(window2.resizeelement)
  window2.resizeelement = nil
  window2.titlebar.tip = 'tooltip text' --element tooltip
```
