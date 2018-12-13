local utf8 = require("utf8")

-- объект для удобства
local Object = {}
Object.__index = Object
function Object:new()
end
function Object:extend()
  local cls = {}
  for k, v in pairs(self) do
    if k:find("__") == 1 then
      cls[k] = v
    end
  end
  cls.__index = cls
  cls.super = self
  setmetatable(cls, self)
  return cls
end
function Object:implement(...)
  for _, cls in pairs({...}) do
    for k, v in pairs(cls) do
      if self[k] == nil and type(v) == "function" then
        self[k] = v
      end
    end
  end
end
function Object:is(T)
  local mt = getmetatable(self)
  while mt do
    if mt == T then
      return true
    end
    mt = getmetatable(mt)
  end
  return false
end
function Object:__tostring()
  return "Object"
end
function Object:__call(...)
  local obj = setmetatable({}, self)
  obj:new(...)
  return obj
end

-- общие функции
local function withinrect(pos, rect)
	pos = pos.pos or pos
	rect = rect.pos or rect
	if pos.x >= rect.x and pos.x <= (rect.x + rect.w) and pos.y >= rect.y and pos.y < (rect.y + rect.h) then return true end
	return false
end
local function getindex(tab, val)
	for i, v in pairs(tab) do if v == val then return i end end
end
local function clone(t)
	local c = {}
	for i, v in pairs(t) do
		if v then
			if type(v) == 'table' then c[i] = clone(v) else c[i] = v end
		end
	end
	return setmetatable(c, getmetatable(t))
end

local gui = Object:extend()
gui.style = {
	padding = 20,
	font = love.graphics.newFont(14),
	fg = {1, 1, 1},
	bg = {0, 0, 0, .7},
	border = {0.5, 0.5, 0.5},
	border_hl = {0.7, 0.9, 0.7},
	border_radius = 3,
	default = {.3, .3, .3},
	hilite = {.5, .5, .5},
	focus = {.7, .7, .7},
}
function gui:new()
	self.elements = {}
	self.mousein = nil
	self.focus = nil
	self.drag = nil
end
function gui:tracktotop_(parent)
	if parent.children then
		for i, child in ipairs(parent.children) do
			if child.totop then
				table.insert(parent.children, table.remove(parent.children, getindex(parent.children, child)))
				self:tracktotop_(child)
			end
		end
	end
end
-- верхние элементы проходим, помещаем totop наверх, для каждого вызываем tracktotop_
function gui:tracktotop()
	if self.elements then
		for i, child in ipairs(self.elements) do
			if not child.parent then --только у верхних элементов
				if child.totop then
					table.insert(self.elements, table.remove(self.elements, getindex(self.elements, child)))
				end
				self:tracktotop_(child)
			end
		end
	end
end
function gui:add(element)
	table.insert(self.elements, element)
	if element.parent then element.parent:addchild(element) end
	self:tracktotop() --обрабатываем totop элементы
	return element
end
function gui:rem(element)
	if element.parent then element.parent:remchild(element) end
	while #element.children > 0 do
		for i, child in ipairs(element.children) do self:rem(child) end
	end
	if element == self.mousein then self.mousein = nil end
	if element == self.drag then self.drag = nil end
	if element == self.focus then self:unfocus() end
	return table.remove(self.elements, getindex(self.elements, element))
end
function gui:setfocus(element)
	if element then
		self.focus = element
	end
end
function gui:unfocus()
	self.focus = nil
end
function gui:pos(...) --передаем x,y,w,h в любой комбинации или объект с .pos, получаем таблицу {x=, y=, w=, h=}
	local t = {}
	local arg = {...}
	if #arg == 1 and type(arg[1]) == 'table' then
		arg = arg[1]
	end
	arg = arg or {}
	arg = arg.pos or arg
	
	t.x = arg.x or arg[1] or 0
	t.y = arg.y or arg[2] or 0
	t.w = arg.w or arg[3] or gui.style.padding
	t.h = arg.h or arg[4] or gui.style.padding

	return t
end

gui.element = Object:extend()
function gui.element:new(gui, etype, label, pos, parent)
	assert(gui[etype], 'element.etype must be an existing element type')
	assert(type(label) == 'string' or type(label) == 'number' or not label, 'element.label must be of type string or number')
	assert(type(pos) == 'table' or not pos, 'element.pos must be of type table or nil')
	assert((type(parent) == 'table' and parent:is(gui.element)) or not parent, 'element.parent must be of type element or nil')

	self.pos =gui:pos(pos)
	self.etype = etype
	self.label = label
	self.display = true
	self.dt = 0
	self.parent = parent
	self.children = {}
	self.gui = gui
	if parent then self.style = setmetatable({}, {__index = parent.style})
	else self.style = setmetatable({}, {__index = gui.style}) end

	gui:add(self)
	--print('new element', self.etype, dump(self.pos))
end
function gui.element:getpos(scissor)
	local pos = self.gui:pos(self)
	if self.parent then
		ppos, scissor = self.parent:getpos()
		
		--pos = pos + ppos
		pos.x = pos.x + ppos.x
		pos.y = pos.y + ppos.y
		--
		if self.parent.havescroll and not self.float then
			scissor = clone(self.parent:getpos())
			if self.parent.scrollv then pos.y = pos.y - self.parent.scrollv.values.current end
			if self.parent.scrollh then pos.x = pos.x - self.parent.scrollh.values.current end
		end
	end
	return pos, scissor
end
function gui.element:containspoint(point)
	local pos = point.pos or point
	return withinrect(pos, self:getpos())
end
function gui.element:getparent()
	--if self.parent then return self.parent:getparent()
	--else return self end

  if not self.parent then return self end

  local parent = self.parent
  local found
  while parent do
  	found = parent
    parent = parent.parent or nil
  end

  return found
end
function gui.element:getdeltacoords()
  -- ищем разницу к координатам по родителям
  local dx, dy = 0, 0
  local parent = self.parent
  while parent do
    dx = dx + parent.pos.x
    dy = dy + parent.pos.y
    parent = parent.parent or nil
  end
  return {x = dx, y = dy}
end
function gui.element:getmaxw()
	local maxw = 0
	for i, child in ipairs(self.children) do
		if not child.float and child.pos.x + child.pos.w > maxw then maxw = child.pos.x + child.pos.w end
	end
	return maxw
end
function gui.element:getmaxh()
	local maxh = 0
	for i, child in ipairs(self.children) do
		if not child.float and child.pos.y + child.pos.h > maxh then maxh = child.pos.y + child.pos.h end
	end
	return maxh
end
--добавляет вложенные элементы стакая их по правилам с учетом их размеров и скролла в родителе
function gui.element:addchild(child, autostack)
	if autostack then
		if type(autostack) == 'number' or autostack == 'grid' then 
			local limitx = (type(autostack) == 'number' and autostack) or self.pos.w
			local maxx, maxy = 0, 0
			for i, element in ipairs(self.children) do
				--if element ~= self.scrollh and element ~= self.scrollv then
				if not element.float then
					if element.pos.y > maxy then maxy = element.pos.y end
					if element.pos.x + element.pos.w + child.pos.w <= limitx then maxx = element.pos.x + element.pos.w
					else maxx, maxy = 0, element.pos.y + element.pos.h end
				end
			end
			child.pos.x, child.pos.y = maxx, maxy
		elseif autostack == 'horizontal' then child.pos.x = self:getmaxw()
		elseif autostack == 'vertical' then child.pos.y = self:getmaxh() end
	end
	
	table.insert(self.children, child)
	child.parent = self

	--если есть скролбары - обновляем максимальные значения
	if self.scrollh then self.scrollh.values.max = math.max(self:getmaxw() - self.pos.w, 0) end
	if self.scrollv then self.scrollv.values.max = math.max(self:getmaxh() - self.pos.h, 0) end

	return child
end
function gui.element:remchild(child)
	child.pos = child:getpos()
	table.remove(self.children, getindex(self.children, child))
	child.parent = nil
end
function gui.element:replace(replacement)
	self.gui.elements[getindex(self.gui.elements, self)] = replacement
	return replacement
end
function gui.element:getlevel()
	for i, element in pairs(self.gui.elements) do
		if element == self then return i end
	end
end
function gui.element:setlevel(level) --без указания level помещает элемент поверх
	if level then
		table.insert(self.gui.elements, level, table.remove(self.gui.elements, getindex(self.gui.elements, self)))
		for i, child in ipairs(self.children) do child:setlevel(level + i) end
	else
		table.insert(self.gui.elements, table.remove(self.gui.elements, getindex(self.gui.elements, self)))
		for i, child in ipairs(self.children) do child:setlevel() end

		self.gui:tracktotop() --обрабатываем totop элементы
	end
end
function gui.element:show()
	self.display = true
	for i, child in pairs(self.children) do child:show() end
end
function gui.element:hide()
	self.display = false
	for i, child in pairs(self.children) do child:hide() end
end
function gui.element:focus()
	self.gui:setfocus(self)
end
function gui.element:drawshape(pos)
	pos = pos or self:getpos()
	self:rect(pos)
end
function gui.element:rect(pos)
	pos = self.gui:pos(pos.pos or pos or self.pos)

	love.graphics.setColor(self.style.bg)
  if self.style.border_radius then love.graphics.rectangle('fill', pos.x, pos.y, pos.w, pos.h, self.style.border_radius) else love.graphics.rectangle('fill', pos.x, pos.y, pos.w, pos.h) end
  
  if self.style.border then
  	love.graphics.setColor(self.style.border)
  	if self.style.border_radius then love.graphics.rectangle('line', pos.x, pos.y, pos.w, pos.h, self.style.border_radius) else love.graphics.rectangle('fill', pos.x, pos.y, pos.w, pos.h) end
  end

end
function gui.element:drawimg(pos)
	love.graphics.setColor({1, 1, 1, 1})
	love.graphics.draw(self.img, (pos.x + (pos.w / 2)) - (self.img:getWidth()) / 2, (pos.y + (pos.h / 2)) - (self.img:getHeight() / 2))
end

gui.hidden = gui.element:extend()
function gui.hidden:new(gui, label, pos, parent)
	gui.hidden.super.new(self, gui, 'hidden', label, pos, parent)
end
function gui.hidden:draw()
end

gui.text = gui.element:extend()
function gui.text:new(gui, label, pos, parent, autosize)
	gui.text.super.new(self, gui, 'text', label, pos, parent)
	if autosize then
		self.pos.w = self.style.font:getWidth(label) + (self.style.padding / 2)
		self.autosize = autosize
	end
	--element:setfont(element.style.font)
end
function gui.text:draw(pos)
	love.graphics.setColor(self.style.fg)
	if self.autosize then love.graphics.print(self.label, pos.x + (self.style.padding / 4), pos.y + ((self.style.padding - self.style.font:getHeight('dp')) / 2))
	else love.graphics.printf(self.label, pos.x + (self.style.padding / 4), pos.y + ((self.style.padding - self.style.font:getHeight('dp')) / 2), (self.autosize and pos.w) or  pos.w - (self.style.padding / 2), 'left') end
end

gui.button = gui.element:extend()
function gui.button:new(gui, label, pos, parent)
	gui.button.super.new(self, gui, 'button', label, pos, parent)
end
function gui.button:draw(pos)
	if self.parent and self.value == self.parent.value then
		if self == self.gui.mousein then love.graphics.setColor(self.style.focus)
		else love.graphics.setColor(self.style.hilite) end
	else
		if self == self.gui.mousein then love.graphics.setColor(self.style.hilite)
		else love.graphics.setColor(self.style.default) end
	end
	self:drawshape(pos)
	love.graphics.setColor(self.style.fg)

	if self.img then self:drawimg(pos) end
	if self.label then love.graphics.print(self.label, (pos.x + (pos.w / 2)) - (self.style.font:getWidth(self.label) / 2), (self.img and pos.y + ((self.style.padding - self.style.font:getHeight(self.label)) / 2)) or (pos.y + (pos.h / 2)) - (self.style.font:getHeight(self.label) / 2)) end
end

gui.group = gui.element:extend()
function gui.group:new(gui, label, pos, parent)
	gui.group.super.new(self, gui, 'group', label, pos, parent)
end
function gui.group:draw(pos)
	love.graphics.setColor(self.style.bg)
	self:drawshape(pos)
	if self.label then
		love.graphics.setColor(self.style.fg)
		love.graphics.print(self.label, pos.x + ((pos.w - self.style.font:getWidth(self.label)) / 2), pos.y + ((self.style.padding - self.style.font:getHeight('dp')) / 2))
	end
end

gui.collapsegroup = gui.group:extend()
function gui.collapsegroup:new(gui, label, pos, parent)
	gui.collapsegroup.super.new(self, gui, label, pos, parent)
	self.view = true
	self.orig = clone(self.pos)
	self.toggle = function(self)
		self.view = not self.view
		self.pos.h = (self.view and self.orig.h) or self.style.padding
		for i, child in ipairs(self.children) do
			if child ~= self.control then
				if self.view then child:show() else child:hide() end
			end
		end
		self.control.label = (self.view and '-') or '='
	end
	self.control = gui:button('-', {self.pos.w - self.style.padding}, self)
	self.control.click = function(self)
		self.parent:toggle()
	end
end

--пункт выпадашек
gui.option = gui.button:extend()
function gui.option:new(gui, label, pos, parent, value)
	gui.option.super.new(self, gui, label, pos, parent)
	self.value = value
	self.click = function(self) self.parent.value = self.value end
end

--скроллбар
gui.scroll = gui.element:extend()
function gui.scroll:new(gui, label, pos, parent, values)
	gui.scroll.super.new(self, gui, 'scroll', label, pos, parent)
	self.values = self:scrollvalues(values)
	self.float = true --можно рисовать за пределами элемента со скроллом
end
function gui.scroll:update(dt)
	local mouse = {}
	mouse.x, mouse.y = love.mouse.getPosition()
	if withinrect({x = mouse.x, y = mouse.y}, self:getpos()) then self.gui.mousein = self end
end
function gui.scroll:step(step)
	if step > 0 then self.values.current = math.max(self.values.current - self.values.step, self.values.min)
	elseif step < 0 then self.values.current = math.min(self.values.current + self.values.step, self.values.max)
	end
end
function gui.scroll:drag(x, y)
	local pos = self:getpos()
	self.values.current = self.values.min + ((self.values.max - self.values.min) * ((self.values.axis == 'vertical' and ((math.min(math.max(pos.y, y), (pos.y + pos.h)) - pos.y) / pos.h)) or ((math.min(math.max(pos.x, x), (pos.x + pos.w)) - pos.x) / pos.w)))
end
function gui.scroll:wheelup()
	if self.values.axis == 'horizontal' then self:step(-1) else self:step(1) end
end
function gui.scroll:wheeldown()
	if self.values.axis == 'horizontal' then self:step(1) else self:step(-1) end
end
function gui.scroll:keypress(key, code)
	if key == 'left' and self.values.axis == 'horizontal' then
		self:step(1)
	elseif key == 'right' and self.values.axis == 'horizontal' then
		self:step(-1)
	elseif key == 'up' and self.values.axis == 'vertical' then
		self:step(-1)
	elseif key == 'down' and self.values.axis == 'vertical' then
		self:step(1)
	elseif key == 'tab' and self.next and self.next.etype then
		self.next:focus()
	elseif key == 'escape' then
		self.gui:unfocus()
	end
end
function gui.scroll:done()
	self.gui:unfocus()
end
function gui.scroll:draw(pos)
	if self == self.gui.mousein or self == self.gui.drag or self == self.gui.focus then love.graphics.setColor(self.style.default)
	else love.graphics.setColor(self.style.bg) end

	self:rect(pos)

	if self == self.gui.mousein or self == self.gui.drag or self == self.gui.focus then love.graphics.setColor(self.style.fg)
	else love.graphics.setColor(self.style.hilite) end

	handlepos = self.gui:pos({x = (self.values.axis == 'horizontal' and math.min(pos.x + (pos.w - self.style.padding), math.max(pos.x, pos.x + (pos.w * (self.values.current / (self.values.max - self.values.min))) - (self.style.padding / 2)))) or pos.x, y = (self.values.axis == 'vertical' and math.min(pos.y + (pos.h - self.style.padding), math.max(pos.y, pos.y + (pos.h * (self.values.current / (self.values.max - self.values.min))) - (self.style.padding / 2)))) or pos.y, w = self.style.padding, h = self.style.padding, r = pos.r})
	self:drawshape(handlepos)
	
	if self.label then
		love.graphics.setColor(self.style.fg)
		love.graphics.print(self.label, (self.values.axis == 'horizontal' and pos.x - ((self.style.padding / 2) + self.style.font:getWidth(self.label))) or pos.x + ((pos.w - self.style.font:getWidth(self.label)) / 2), (self.values.axis == 'vertical' and (pos.y + pos.h) + ((self.style.padding - self.style.font:getHeight('dp')) / 2)) or pos.y + ((self.style.padding - self.style.font:getHeight('dp')) / 2))
	end

end
function gui.scroll:scrollvalues(values)
	local val = {}
	val.min = values.min or values[1] or 0
	val.max = values.max or values[2] or 0
	val.current = values.current or values[3] or val.min
	val.step = values.step or values[4] or self.style.padding
	val.axis = values.axis or values[5] or 'vertical'
	return val
end

gui.scrollgroup = gui.element:extend()
function gui.scrollgroup:new(gui, label, pos, parent, axis)
	axis = axis or 'both'
	gui.scrollgroup.super.new(self, gui, 'scrollgroup', label, pos, parent)
	self.maxh = 0
	if axis ~= 'horizontal' then
		self.scrollv = gui:scroll(nil, {x = self.pos.w, y = 0, w = self.style.padding, h = self.pos.h}, self, {0, 0, 0, self.style.padding, 'vertical'})
	end
	if axis ~= 'vertical' then
		self.scrollh = gui:scroll(nil, {x = 0, y = self.pos.h, w = self.pos.w, h = self.style.padding}, self, {0, 0, 0, self.style.padding, 'horizontal'})
	end
	self.havescroll = true --элемент имеет скроллбары
end
function gui.scrollgroup:draw(pos)
	--love.graphics.setColor(self.style.bg)
	--self:drawshape(pos)
	if self.label then
		love.graphics.setColor(self.style.fg)
		love.graphics.print(self.label, pos.x + ((pos.w - self.style.font:getWidth(self.label)) / 2), pos.y + ((self.style.padding - self.style.font:getHeight(self.label)) / 2))
	end
end
function gui.scrollgroup:positioncontrols()
	--размеры поменялись, выставляем скролбары
	if self.scrollv then
		self.scrollv.pos.h = self.pos.h
		self.scrollv.pos.x = self.pos.w
	end
	if self.scrollh then
		self.scrollh.pos.w = self.pos.w
		self.scrollh.pos.y = self.pos.h
	end
end

--окно с заголовком, кнопкой закрыть, областью для растягивания
gui.window = gui.element:extend()
function gui.window:new(gui, label, pos, parent)
	gui.window.super.new(self, gui, 'window', label, pos, parent)
	self.drag = true

	self.closebutton = gui:button('x', {x = self.pos.w, y = 0, w = self.style.padding, h = self.style.padding}, self)
	self.closebutton.float = true --можно рисовать за пределами родителя
	self.closebutton.click = function(self, x, y)
		self.parent:hide()
	end
	self.resizeelement = gui:windowdrag('/', {x = self.pos.w, y = self.pos.h, w = self.style.padding, h = self.style.padding}, self)
	self.resizeelement.float = true --можно рисовать за пределами родителя
	self.resizeelement.totop = true --стараемся держать его поверх других

	label = label or ' '

	self.titlebar = gui:windowtitle(label, {x = 0, y = -self.style.padding, w = self.pos.w, h = self.style.padding}, self)
	self.titlebar.float = true --можно рисовать за пределами родителя
	self.titlebar.drag = function(self, mx, my)
		self.parent.pos.x = mx - self.offset.x
		self.parent.pos.y = my + self.pos.h - self.offset.y
	end
	
	self:positioncontrols() --теперь выстраиваем элементы управления

	self.resizeelement.drag = function(self, mx, my)
		--меняем размеры родительского окна
		self.parent.pos.w = mx - self.offset.x - self.parent.pos.x + (self.parent.pos.w - self.pos.x)
		self.parent.pos.h = my - self.offset.y - self.parent.pos.y + (self.parent.pos.h - self.pos.y)
		--меньше минимального размера? меняем
		if self.parent.minw and self.parent.pos.w < self.parent.minw then
			self.parent.pos.w = self.parent.minw
		end
		if self.parent.minh and self.parent.pos.h < self.parent.minh then
			self.parent.pos.h = self.parent.minh
		end
		--больше максимального размера? меняем
		if self.parent.maxw and self.parent.pos.w > self.parent.maxw then
			self.parent.pos.w = self.parent.maxw
		end
		if self.parent.maxh and self.parent.pos.h > self.parent.maxh then
			self.parent.pos.h = self.parent.maxh
		end
		self.parent:positioncontrols() --размеры окна поменяли, теперь управляющие элементы расставим

		if type(self.parent.resize) == 'function' then self.parent:resize() end --resize вызываем если есть
	end
end
--расставляем контролы по размерам окна
function gui.window:positioncontrols()

	if self.resizeelement then self.resizeelement.pos = {x = self.pos.w - self.style.padding, y = self.pos.h - self.style.padding, w = self.style.padding, h = self.style.padding} end
	if self.titlebar then self.titlebar.pos = {x = 0, y = -self.style.padding, w = self.pos.w - self.style.padding, h = self.style.padding} end
	if self.closebutton then
		self.closebutton.pos = {x = self.pos.w - self.style.padding, y = -self.style.padding, w = self.style.padding, h = self.style.padding}
	else
		self.titlebar.pos.w = self.pos.w
	end

end
function gui.window:draw(pos)
	love.graphics.setColor(self.style.bg)
	self:drawshape(pos)
end

--заголовок для окон
gui.windowtitle = gui.element:extend()
function gui.windowtitle:new(gui, label, pos, parent)
	gui.windowtitle.super.new(self, gui, 'windowtitle', label, pos, parent)
end
function gui.windowtitle:draw(pos)
  self:drawshape(pos)
  love.graphics.setColor(self.style.fg)
  love.graphics.print(self.label, pos.x + self.style.padding/2, pos.y + ((self.style.padding - self.style.font:getHeight(self.label)) / 2))
end

--drag для окон
gui.windowdrag = gui.button:extend()
function gui.windowdrag:new(gui, label, pos, parent)
	gui.option.super.new(self, gui, 'windowdrag', pos, parent)
end
function gui.windowdrag:draw(pos)
  --self:drawshape(pos)
  love.graphics.setColor(self.style.border_hl)
  --love.graphics.print(self.label, pos.x + self.style.padding/2, pos.y + ((self.style.padding - self.style.font:getHeight(self.label)) / 2))
  love.graphics.line(pos.x, pos.y + pos.h, pos.x + pos.w, pos.y + pos.h)
  love.graphics.line(pos.x + pos.w, pos.y, pos.x + pos.w, pos.y + pos.h)
end

gui.input = gui.element:extend()
function gui.input:new(gui, label, pos, parent, value)
	gui.window.super.new(self, gui, 'input', label, pos, parent)
	self.value = (value and tostring(value)) or ''
	self.cursor = self.value:len()
	self.cursorlife = 0
end
function gui.input:update()
	if self.gui.focus == self then
		if self.cursorlife < 1 then self.cursorlife = 0
		else self.cursorlife = self.cursorlife + dt end
	end
end
function gui.input:drawshape(pos)
	love.graphics.setColor(self.style.bg)
  if self.style.border_radius then love.graphics.rectangle('fill', pos.x, pos.y, pos.w, pos.h, self.style.border_radius) else love.graphics.rectangle('fill', pos.x, pos.y, pos.w, pos.h) end

  if self.style.border then
  	if self == self.gui.focus or self == self.gui.mousein then
  		love.graphics.setColor(self.style.border_hl)
		else
			love.graphics.setColor(self.style.border)
		end
		if self.style.border_radius then love.graphics.rectangle('line', pos.x, pos.y, pos.w, pos.h, self.style.border_radius) else love.graphics.rectangle('fill', pos.x, pos.y, pos.w, pos.h) end
  end
end
function gui.input:draw(pos)
	self:drawshape(pos)

	love.graphics.setColor(self.style.fg)
	local str = tostring(self.value)
	if self.maskinput then
		str = string.rep(self.maskinput, utf8.len(str))
	end

	--убираем символы с начала строки по одному пока строка не влезет
	local offset = 0
	while self.style.font:getWidth(str) > pos.w - (self.style.padding / 2) do
		local byteoffset = utf8.offset(str, 2)
		str = string.sub(str, byteoffset)
		--str = str:sub(2)
		--offset = offset + 1
	end

	love.graphics.print(str, pos.x + (self.style.padding / 4), pos.y + ((pos.h - self.style.font:getHeight('dp')) / 2))
	if self == self.gui.focus and self.cursorlife < 0.5 then
		local cursorx = ((pos.x + (self.style.padding / 4)) + self.style.font:getWidth(str:sub(1, self.cursor - offset)))
		love.graphics.line(cursorx, pos.y + (self.style.padding / 8), cursorx, (pos.y + pos.h) - (self.style.padding / 8))
	end
	if self.label then
		love.graphics.setColor(self.style.fg)
		love.graphics.print(self.label, pos.x - ((self.style.padding / 2) + self.style.font:getWidth(self.label)), pos.y + ((self.pos.h - self.style.font:getHeight('dp')) / 2))
	end
end
function gui.input:click() self:focus() end
function gui.input:done() self.gui:unfocus() end
function gui.input:keypress(key, code)
	--if key == 'space' then key = ' ' end --пробельчик
	if key == 'backspace' then
		--self.value = self.value:sub(1, self.cursor - 1)..self.value:sub(self.cursor + 1)
		local byteoffset = utf8.offset(self.value, -1)
		if byteoffset then self.value = string.sub(self.value, 1, byteoffset - 1) end
		self.cursor = math.max(0, self.cursor - 1)
	elseif key == 'delete' then
		self.value = self.value:sub(1, self.cursor)..self.value:sub(self.cursor + 2)
		self.cursor = math.min(self.value:len(), self.cursor)
	elseif key == 'left' then
		self.cursor = math.max(0, self.cursor - 1)
	elseif key == 'right' then
		self.cursor = math.min(self.value:len(), self.cursor + 1)
	elseif key == 'home' then
		self.cursor = 0
	elseif key == 'end' then
		self.cursor = self.value:len()
	elseif key == 'tab' and self.next and self.next.elementtype then
		self.next:focus()
	elseif key == 'escape' then
		self.Gspot:unfocus()
	elseif string.len(key) == 1 then
		--self.value = self.value:sub(1, self.cursor)..key..self.value:sub(self.cursor + 1)
		--self.cursor = self.cursor + 1
	end
	if type(self.change) == 'function' then self:change() end --change вызываем если есть
end
function gui.input:textinput(t)
	self.value = self.value:sub(1, self.cursor)..t..self.value:sub(self.cursor + 1)
	self.cursor = self.cursor + string.len(t)
end

gui.feedback = gui.element:extend()
function gui.feedback:new(gui, label, pos, parent, autopos)
	pos = pos or {}
	autopos = (autopos == nil and true) or autopos
	if autopos then
		for i, element in ipairs(gui.elements) do
			if element.etype == 'feedback' and element.autopos then element.pos.y = element.pos.y + element.style.padding end
		end
	end
	pos.x = pos.x or pos[1] or 0
	pos.y = pos.y or pos[2] or 0
	pos.w = 0
	pos.h = 0
	
	gui.feedback.super.new(self, gui, 'feedback', label, pos, parent)

	self.style.fg = {1, 1, 1, 1}
	self.alpha = 1
	self.life = 5
	self.autopos = autopos
end
function gui.feedback:update(dt)
	self.alpha = self.alpha - ((1 * dt) / self.life)
	if self.alpha < 0 then
		self.gui:rem(self)
		return
	end
	local color = self.style.fg
	self.style.fg = {color[1], color[2], color[3], self.alpha}
end
function gui.feedback:draw(pos)
	love.graphics.setColor(self.style.fg)
	love.graphics.print(self.label, pos.x + (self.style.padding / 4), pos.y + ((self.style.padding - self.style.font:getHeight('dp')) / 2))
end

function gui:update(dt)
	--self.mousedt = self.mousedt + dt
	local mouse = {}
	mouse.x, mouse.y = love.mouse.getPosition()
	local mousein = self.mousein
	self.mousein = false
	self.mouseover = false
	if self.drag then
		local element = self.drag
		if love.mouse.isDown(1) then
			if type(element.drag) == 'function' then element:drag(mouse.x, mouse.y)
			else
				local parentpos = element:getdeltacoords()
				element.pos.x = mouse.x - element.offset.x - parentpos.x
				element.pos.y = mouse.y - element.offset.y - parentpos.y
			end
		elseif love.mouse.isDown(2) then
			if type(element.rdrag) == 'function' then element:rdrag(mouse.x, mouse.y)
			else
				element.pos.x = mouse.x - element.offset.x
				element.pos.y = mouse.y - element.offset.y
			end
		end
		for i, bucket in ipairs(self.elements) do
			if bucket ~= element and bucket:containspoint(mouse) then self.mouseover = bucket end
		end
	end
	for i, element in ipairs(self.elements) do
		if element.display then
			if element.update then
				if element.updateinterval then
					element.dt = element.dt + dt
					if element.dt >= element.updateinterval then
						element.dt = 0
						element:update(dt)
					end
				else element:update(dt) end
			end
			if element:containspoint(mouse) then
				--if element.parent and element.parent:is(gui.scrollgroup) and element ~= element.parent.scrollv and element ~= element.parent.scrollh then
				if element.parent and element.parent.havescroll and not element.float then
					if element.parent:containspoint(mouse) then self.mousein = element end
				else self.mousein = element end
			end
		end
	end
	if self.mousein ~= mousein then
		if self.mousein and self.mousein.enter then self.mousein:enter() end
		if mousein and mousein.leave then mousein:leave() end
	end
end

function gui:draw()
	local ostyle = {}
	ostyle.font = love.graphics.getFont()
	ostyle.r, ostyle.g, ostyle.b, ostyle.a = love.graphics.getColor()
	ostyle.scissor = {}
	ostyle.scissor.x, ostyle.scissor.y, ostyle.scissor.w, ostyle.scissor.h = love.graphics.getScissor()

	for i, element in ipairs(self.elements) do
		if element.display then
			local pos, scissor = element:getpos()
			if scissor then love.graphics.setScissor(scissor.x, scissor.y, scissor.w, scissor.h) end
			love.graphics.setFont(element.style.font)
			element:draw(pos)
			if ostyle.scissor.x then love.graphics.setScissor(ostyle.scissor.x, ostyle.scissor.y, ostyle.scissor.w, ostyle.scissor.h)
			else love.graphics.setScissor() end
		end
	end

	--тултип
	if self.mousein and self.mousein.tip then
		local element = self.mousein
		local pos = element:getpos()
		
		--local tippos = {x = pos.x + (self.style.padding / 2), y = pos.y + (self.style.padding / 2), w = element.style.font:getWidth(element.tip) + self.style.padding, h = self.style.padding}
		local mouse = {}
		mouse.x, mouse.y = love.mouse.getPosition()
		local tippos = {x = mouse.x + 4, y = mouse.y + 4, w = element.style.font:getWidth(element.tip) + self.style.padding, h = self.style.padding}

		love.graphics.setColor(self.style.bg)
		self.mousein:rect({x = math.max(0, math.min(tippos.x, love.graphics.getWidth() - (element.style.font:getWidth(element.tip) + self.style.padding))), y = math.max(0, math.min(tippos.y, love.graphics.getHeight() - self.style.padding)), w = tippos.w, h = tippos.h})
		love.graphics.setColor(self.style.fg)
		love.graphics.print(element.tip, math.max(self.style.padding / 2, math.min(tippos.x + (self.style.padding / 2), love.graphics.getWidth() - (element.style.font:getWidth(element.tip) + (self.style.padding / 2)))), math.max((self.style.padding - element.style.font:getHeight(element.tip)) / 2, math.min(tippos.y + ((self.style.padding - element.style.font:getHeight('dp')) / 2), (love.graphics.getHeight() - self.style.padding) + ((self.style.padding - element.style.font:getHeight('dp')) / 2))))
	end

	love.graphics.setFont(ostyle.font)
	love.graphics.setColor(ostyle.r, ostyle.g, ostyle.b, ostyle.a)
	if ostyle.scissor.x then love.graphics.setScissor(ostyle.scissor.x, ostyle.scissor.y, ostyle.scissor.w, ostyle.scissor.h)
	else love.graphics.setScissor() end

end

function gui:mousepressed(x, y, button, istouch, presses)
	self:unfocus()
	if self.mousein then
		local element = self.mousein
		if element.etype ~= 'hidden' then element:getparent():setlevel() end
		if element.drag then
			self.drag = element
			element.offset = {x = x - element:getpos().x, y = y - element:getpos().y}
			
			--local parentpos = element:getparent():getpos()
			--element.offset = {x = x - element:getpos().x - parentpos.x, y = y - element:getpos().y - parentpos.y}


			--local parentpos = element:getdeltacoords()
			--element.offset = {x = x - element:getpos().x + parentpos.x, y = y - element:getpos().y + parentpos.y}

			--print(x, y, dump(element.offset))
		end
		if button == 1 then
			--if self.mousedt < self.dblclickinterval and element.dblclick then element:dblclick(x, y, button)
			if presses > 1 and element.dblclick then element:dblclick(x, y, button)
			elseif element.click then element:click(x, y) end
		elseif button == 2 and element.rclick then element:rclick(x, y)
		--elseif button == 'wu' and element.wheelup then element:wheelup(x, y)
		--elseif button == 'wd' and element.wheeldown then element:wheeldown(x, y)
		end
	end
	self.mousedt = 0
end

function gui:mousereleased(x, y, button, istouch, presses)
	if self.drag then
		local element = self.drag
		if button == 2 then
			if element.rdrop then element:rdrop(self.mouseover) end
			if self.mouseover and self.mouseover.rcatch then self.mouseover:rcatch(element.id) end
		else
			if element.drop then element:drop(self.mouseover) end
			if self.mouseover and self.mouseover.catch then self.mouseover:catch(element) end
		end
	end
	self.drag = nil
end

function gui:wheelmoved(x, y)
	self:unfocus()
	if self.mousein then
		local element = self.mousein
		if element.etype ~= 'hidden' then element:getparent():setlevel() end

		local mx, my = love.mouse.getPosition()

		if y > 0 and element.wheelup then element:wheelup(mx, my)
		elseif y < 0 and element.wheeldown then element:wheeldown(mx, my)
		end
	end
end

function gui:keypressed(key, code)
	if self.focus then
		if (key == 'return' or key == 'kpenter') and self.focus.done then self.focus:done() end
		if self.focus and self.focus.keypress then self.focus:keypress(key, code) end
	end
end
function gui:textinput(t)
	if self.focus and self.focus.textinput then self.focus:textinput(t) end
end


return gui()
