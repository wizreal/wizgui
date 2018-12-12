gui = require 'gui'
--gui.style.font = love.graphics.newFont("assets/fonts/OpenSans-Regular.ttf", 14)

gui.style.border = {0.2, 0.23, 0.24}

function love.load()
  love.keyboard.setKeyRepeat(true)

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
    --[[if scrollgroup.scrollh then
      scrollgroup.scrollh.values.max = math.max(scrollgroup:getmaxw() - scrollgroup.pos.w, 0)
      scrollgroup.scrollh.values.current = math.min(scrollgroup.scrollh.values.current, scrollgroup.scrollh.values.max)
    end--]]
  end

  scrollgroup = gui:scrollgroup(nil, {0, 0, window1.pos.w - window1.style.padding, window1.pos.h}, window1, 'vertical')
  
  for i=1, 40 do
    textlabel = gui:text('Text label '..i, {0, 0}, nil, true)
    scrollgroup:addchild(textlabel, 'vertical')
  end

  -- text input
  input = gui:input(nil, {window1.style.padding, window1.style.padding, scrollgroup.pos.w - gui.style.padding * 2, scrollgroup.style.padding})
  input.done = function(self)
    gui:feedback('I say '..self.value)
    self.value = ''
    self.gui:unfocus()
  end
  scrollgroup:addchild(input, 'vertical')

  window2 = gui:window('Another', {530, 250, 200, 200}, nil, 'none')
  gui:rem(window2.resizeelement)
  window2.resizeelement = nil
  window2.titlebar.tip = 'tooltip text'

end

function love.update(dt)
  gui:update(dt)
end
function love.draw()
  love.graphics.setColor(0.2, 0.4, 0.4, 1)
  love.graphics.rectangle("fill", 0, 0, 800, 600)

  gui:draw()

  if gui.mousein then
    love.graphics.setColor({1,1,1})
    local t = gui.mousein.etype
    if gui.mousein.label then t = t..' '..gui.mousein.label end
    love.graphics.print(t, 400, 10)
  end

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print("FPS: "..tostring(love.timer.getFPS( )), 710, 10)
end
function love.keypressed(key, code)
  if gui.focus then
    gui:keypressed(key, code)
  else
    if key == 'return' or key == 'kpenter' then
      --input:focus()
    else
      gui:feedback(key)
    end
  end
end
function love.textinput(t)
  if gui.focus then
    gui:textinput(t)
  end
end
function love.mousepressed(x, y, button, istouch, presses)
  gui:mousepressed(x, y, button, istouch, presses)
end
function love.mousereleased(x, y, button, istouch, presses)
  gui:mousereleased(x, y, button, istouch, presses)
end
function love.wheelmoved(x, y)
  gui:wheelmoved(x, y)
end


function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end
