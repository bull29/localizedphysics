MapRepeat.Sync = MapRepeat.Sync or {}
MapRepeat.RGen = MapRepeat.RGen or {}
MapRepeat.Cells = MapRepeat.Cells or {}
function MapRepeat.CellToArray(cell) -- Get values from the cell
	if !cell then return end
	local c = {}
	local i = string.find(cell,' ') -- Find the spaces in between the numbers we want
	c[1] = string.sub(cell,1,i-1) -- Kind of hacky way to get the X
 	c[2] = string.sub(cell,i+1,string.find(cell,' ',i+1)-1) -- Getting pretty hacky to find Y
	c[3] = string.sub(cell,string.find(cell,' ',i+1)+1) -- Hackasaurus Rex to get Z
	return c
end
local srv_genned = {}
function MapRepeat.GenCell(cell) -- Generate the cell!
	if !cell then return end
	local c = MapRepeat.CellToArray(cell) -- Get the values from the cell
	MapRepeat.Cells[cell] = MapRepeat.Cells[cell] or {} -- Script error prevention
	if MapRepeat.Cells[cell].gen then return end -- If the cell is labelled as generated, ignore it
	MapRepeat.Cells[cell].gen = true -- Label the cell as generated (stop the cell from being genned again)
	for e,t in pairs(MapRepeat.RGen) do -- For all of the entities, run RGen
		for k,v in pairs(t) do
			if type(v) == 'table' then -- If the value is a table (which we want)
				local pass = true -- Random variable that only superllama knows about #1
				local send = false -- Random variable that only superllama knows about #2
				local p = {false,false,false} -- Random table that only superllama knows about
				for i=1,3 do -- For loop to get the three values, X Y and Z
					local token = string.sub(v[i],1,1) -- Find X Y and Z
					if token == '%' and CLIENT then -- If it's a random chance, run the following on client
						if !srv_genned[cell] then -- If it's not already generated
							RunConsoleCommand("sl_mr_gencell",cell) -- Generate it
							srv_genned[cell] = true -- Label it as generated
						end
						pass = false -- Set random variable that only superllama knows about #1 to false
					elseif token == '%' and SERVER then -- If it's a random chance, run on server:
						pass = (math.random(1,100) < (tonumber(string.sub(v[i],2)) or 0)) -- Do random chance
						send = true -- Set random variable that only superllama knows about #2 to true
						p[i] = true -- Set random table that only superllama knows about to true
					end 
				end
				if	pass and -- If random variable that only superllama knows about #1 is true/more than 0
				    ((v[1] == c[1]) or (v[1] == '?') or p[1]) and -- If X is a number, ?, or percent
					((v[2] == c[2]) or (v[2] == '?') or p[2]) and -- If Y is a number, ?, or percent
					((v[3] == c[3]) or (v[3] == '?') or p[3]) then -- If Z is a number, ?, or percent
					if send then -- If random variable that only superllama knows about is set to true/more than 0
						MapRepeat.AddCell(e,cell) -- Add the cell
					else -- If not,
						MapRepeat.Cells[cell][e] = true -- Set ent to be in the cell
						if SERVER and e and e != NULL then 
							e.Cells = e.Cells or {} -- Script error prevention
							e.Cells[#e.Cells+1] = cell -- Go to next index.
						end
					end
				end
			end
		end
	end
end
function MapRepeat.InCell(e,cell) --  Is this ent in this cell?
	if !IsEntity(e) then return end
	if SERVER then 
		if !e.Cells then return false end -- If the ent doesn't have a cell, say no
		for _,c in pairs(e.Cells) do
			if c == cell then return true end -- If the ent's cell matches the other argument, say yes
		end
		return false -- But...also say no(???)
	else return (MapRepeat.Cells[cell] and (MapRepeat.Cells[cell][e] or MapRepeat.Cells[cell][e:EntIndex()])) or MapRepeat.CelledEnts[e] == cell or MapRepeat.CelledEnts[e:EntIndex()] == cell end
	-- ^Really hacky stuff don't worry about it
end
function MapRepeat.CellToPos(_pos,cell) -- Get what cell the position is in
	local pos = _pos
	local c = MapRepeat.CellToArray(cell)
	if !c then return pos end
	local s = MapRepeat.Sync
	local cx = (s.right or 0) - (s.left or 0)
	local cy = (s.bottom or 0) - (s.top or 0)
	local cz = (s.up or 0) - (s.down or 0)
	pos.x = pos.x + (cx * (tonumber(c[1]) or 0))
	pos.y = pos.y + (cy * (tonumber(c[2]) or 0))
	pos.z = pos.z + (cz * (tonumber(c[3]) or 0))
	return pos
end
function MapRepeat.PosToCell(_pos,_pos2) -- Get the position relative to the cell
	local pos,pos2 = _pos,_pos2
	local s = MapRepeat.Sync
	local cx = (s.right or 0) - (s.left or 0)
	local cy = (s.bottom or 0) - (s.top or 0)
	local cz = (s.up or 0) - (s.down or 0)
	local x,y,z
	if pos.x >= 0 then x = math.floor((pos.x+(s.right or 0))/cx)
	else x = math.ceil((pos.x+(s.left or 0))/cx) end
	if pos.y >= 0 then y = math.floor((pos.y+(s.bottom or 0))/cy)
	else y = math.ceil((pos.y+(s.top or 0))/cy) end
	if pos.z >= 0 then z = math.floor((pos.z+(s.up or 0))/cz)
	else z = math.ceil((pos.z+(s.down or 0))/cz) end
	pos.x = pos.x - (cx * x)
	pos.y = pos.y - (cy * y)
	pos.z = pos.z - (cz * z)
	if pos2 then
		pos2.x = pos2.x - (cx * x)
		pos2.y = pos2.y - (cy * y)
		pos2.z = pos2.z - (cz * z)
	end
	if x == -0 then x = 0 end
	if y == -0 then y = 0 end
	if z == -0 then z = 0 end
	return x..' '..y..' '..z, pos,pos2
end
if !util.RealTraceLine then -- If the function is broken or disabled, use the usual one
	util.RealTraceLine = util.TraceLine
end
function util.TraceLine(_tr) -- Override for TraceLine
	if !MapRepeat then
		util.TraceLine = util.RealTraceLine
		return util.TraceLine(_tr)
	end
	local tr,cell = _tr,nil
	local s = MapRepeat.Sync
	cell,tr.start,tr.endpos = MapRepeat.PosToCell(tr.start,tr.endpos)
	for _,e in pairs(ents.GetAll()) do
		if !MapRepeat.InCell(e,cell) && (CLIENT or e:GetMoveType() != MOVETYPE_NONE) then
			if type(tr.filter) != 'table' then tr.filter = {tr.filter} end
			tr.filter[#tr.filter+1] = e
		end
	end
	local tro = util.RealTraceLine(tr)
	tro.HitPos = MapRepeat.CellToPos(tro.HitPos,cell)
	tro.StartPos = tr.start
	return tro
end

--
-- WE NEED MORE UTIL TRACES SIR, WE NEED MORE.
--

/*if !util.RealTraceEntity then
	util.RealTraceEntity = util.TraceEntity
end
function util.TraceEntity(te)
	if !MapRepeat then
		util.TraceEntity = util.RealTraceEntity
		return util.TraceEntity(te)
	end

	cell,te.start,te.endpos = MapRepeat.PosToCell(te.start,te.endpos)
	for _,e in pairs(ents.GetAll()) do
		if !MapRepeat.InCell(e,cell) && (CLIENT or e:GetMoveType() != MOVETYPE_NONE) then
			if type(te.filter) != 'table' then te.filter = {te.filter} end
			te.filter[#te.filter+1] = e
		end
	end
	
	local teo = util.RealTraceEntity(te)
	teo.HitPos = MapRepeat.CellToPos(teo.HitPos,cell)
	teo.StartPos = te.start
	return teo
end*/

if !util.RealTraceHull then
	util.RealTraceHull = util.TraceHull
end
function util.TraceHull(th)
	if !MapRepeat then
		util.TraceHull = util.RealTraceHull
		return util.TraceHull(th)
	end

	cell,th.start,th.endpos = MapRepeat.PosToCell(th.start,th.endpos)
	
	local tho = util.RealTraceHull( {
	start = th.start,
	endpos = th.endpos,
	filter = function(e)
		if(type(th.filter) == 'function') then
			pass = th.filter(e)
		else
			pass = table.HasValue(th.filter,e)
		end
		return MapRepeat.InCell(e,cell) && pass
	end,
	mins = th.mins,
	maxs = th.maxs,
	} )
	
	return tho
end

if !RealCleanUpMap then
	RealCleanUpMap = game.CleanUpMap
end
function game.CleanUpMap(send, filters)
	if !MapRepeat then return game.CleanUpMap(send,filters)end
	if type(filters) != 'table' then filters = {filters} end
	if !table.HasValue(filters,"func_brush") then filters[#filters+1] = "func_brush" end
	return RealCleanUpMap(send, filters)
end
