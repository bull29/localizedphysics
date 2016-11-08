MapRepeat.Sync = MapRepeat.Sync or {}
MapRepeat.RGen = MapRepeat.RGen or {}
MapRepeat.Cells = MapRepeat.Cells or {}
function MapRepeat.CellToArray(cell) -- Get values from the cell
	if !cell then return end
	local c = {}
	local i = string.find(cell,' ') -- Find the spaces in between the numbers we want
	c[1] = string.sub(cell,1,i-1) -- Find X
 	c[2] = string.sub(cell,i+1,string.find(cell,' ',i+1)-1) -- Find Y
	c[3] = string.sub(cell,string.find(cell,' ',i+1)+1) -- Find Z
	return c
end
local srv_genned = {} -- Make an empty table
function MapRepeat.GenCell(cell) -- Generate the cell!
	if !cell then return end -- If invalid cell, abort
	local c = MapRepeat.CellToArray(cell) -- Get the values from the cell
	MapRepeat.Cells[cell] = MapRepeat.Cells[cell] or {} -- Script error prevention
	if MapRepeat.Cells[cell].gen then return end -- If the cell has already been generated, abort
	MapRepeat.Cells[cell].gen = true -- Stop the cell from being generated again (related to the above line^)
	for e,t in pairs(MapRepeat.RGen) do -- If we need to randomly generate
		for k,v in pairs(t) do
			if type(v) == 'table' then -- If the value is a table (which we want)
				local pass = true -- First pass
				local send = false -- Default send to false
				local p = {false,false,false} -- X Y and Z haven't been set up yet.
				for i=1,3 do -- For loop to get the three values, X Y and Z
					local token = string.sub(v[i],1,1) -- Find X Y and Z
					if token == '%' and CLIENT then -- If it's a random chance, run the following on client
						if !srv_genned[cell] then -- If it's not already generated
							RunConsoleCommand("sl_mr_gencell",cell) -- Generate it
							srv_genned[cell] = true -- Label it as generated
						end
						pass = false -- Reset pass
					elseif token == '%' and SERVER then -- If it's a random chance, run on server:
						pass = (math.random(1,100) < (tonumber(string.sub(v[i],2)) or 0)) -- Do random chance
						send = true -- Set up send
						p[i] = true -- Value has been set (X Y or Z)
					end 
				end
				if pass and -- If we've done the first pass
				    ((v[1] == c[1]) or (v[1] == '?') or p[1]) and -- If X is a number, ?, or has been RGen'd
					((v[2] == c[2]) or (v[2] == '?') or p[2]) and -- If Y is a number, ?, or has been RGen'd
					((v[3] == c[3]) or (v[3] == '?') or p[3]) then -- If Z is a number, ?, or has been RGen'd
					if send then -- If we can send
						MapRepeat.AddCell(e,cell) -- Add the cell
					else -- If not,
						MapRepeat.Cells[cell][e] = true -- Set ent to be in the cell
						if SERVER and e and e != NULL then -- If e isn't invalid, run serverside:
							e.Cells = e.Cells or {} -- Script error prevention
							e.Cells[#e.Cells+1] = cell -- Add to cell table
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
			if c == cell then return true end -- If the ent's cell matches the cell table, say yes
		end
		return false -- Otherwise, say no
	else return (MapRepeat.Cells[cell] and (MapRepeat.Cells[cell][e] or MapRepeat.Cells[cell][e:EntIndex()])) or MapRepeat.CelledEnts[e] == cell or MapRepeat.CelledEnts[e:EntIndex()] == cell end
	-- ^Crazy stuff to find out the cell
end
function MapRepeat.CellToPos(_pos,cell) -- Get position in cell
	local pos = _pos
	local c = MapRepeat.CellToArray(cell) -- Get cell values
	if !c then return pos end -- If the cell has no values, just return pos
	local s = MapRepeat.Sync
	local cx = (s.right or 0) - (s.left or 0) -- Right/Left
	local cy = (s.bottom or 0) - (s.top or 0) -- Bottom/Top
	local cz = (s.up or 0) - (s.down or 0) -- Up/Down
	pos.x = pos.x + (cx * (tonumber(c[1]) or 0))
	pos.y = pos.y + (cy * (tonumber(c[2]) or 0))
	pos.z = pos.z + (cz * (tonumber(c[3]) or 0))
	return pos
end
function MapRepeat.PosToCell(_pos,_pos2) -- Get the cell the position is in
	local pos,pos2 = _pos,_pos2
	local s = MapRepeat.Sync
	local cx = (s.right or 0) - (s.left or 0) -- Right/Left
	local cy = (s.bottom or 0) - (s.top or 0) -- Bottom/Top
	local cz = (s.up or 0) - (s.down or 0) -- Up/Down
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
	return x..' '..y..' '..z, pos,pos2 -- Return cell number as a string and the two positions
end
if !util.RealTraceLine then -- If we don't know what RealTraceLine is
	util.RealTraceLine = util.TraceLine -- RealTraceLine is just a duplicate of TraceLine
end
function util.TraceLine(_tr) -- Override for TraceLine
	if !MapRepeat then -- If MapRepeat isn't active
		util.TraceLine = util.RealTraceLine -- Reset to normal TraceLine
		return util.TraceLine(_tr) -- Perform normal TraceLine
	end
	local tr,cell = _tr,nil
	local s = MapRepeat.Sync
	cell,tr.start,tr.endpos = MapRepeat.PosToCell(tr.start,tr.endpos) -- Get cell the TraceLine is in
	for _,e in pairs(ents.GetAll()) do -- Get all entities
		if !MapRepeat.InCell(e,cell) && (CLIENT or e:GetMoveType() != MOVETYPE_NONE) then -- If the entity isn't in your cell
			if type(tr.filter) != 'table' then tr.filter = {tr.filter} end 
			tr.filter[#tr.filter+1] = e -- Add the entity to the filters list (so it won't hit stuff not in its cell)
		end
	end
	local tro = util.RealTraceLine(tr) -- Make a new trace so we don't stack overflow
	tro.HitPos = MapRepeat.CellToPos(tro.HitPos,cell)
	tro.StartPos = tr.start
	return tro -- Return the TraceLine with the new filters
end

--
-- WE NEED MORE UTIL TRACES SIR, WE NEED MORE.
--

if !util.RealTraceEntity then -- If we don't know what RealTraceEntity
	util.RealTraceEntity = util.TraceEntity -- RealTraceEntity is just a duplicate of TraceEntity
end
function util.TraceEntity(te,ent) -- Override  for TraceEntity
	if !MapRepeat then -- If MapRepeat isn't active
		util.TraceEntity = util.RealTraceEntity -- Reset to normal TraceEntity
		return util.TraceEntity(te,ent) -- Perform normal TraceEntity
	end
	
	cell,te.start,te.endpos = MapRepeat.PosToCell(te.start,te.endpos) -- Get the cell the TraceEntity is in
	for _,e in pairs(ents.GetAll()) do -- Get all entities
		if !MapRepeat.InCell(e,cell) then -- If the entity isnt in your cell
			if type(te.filter) != 'table' then te.filter = {te.filter} end
				te.filter[#te.filter+1] = e -- Add the entities to the filters list
		end
	end
	
	local teo = util.RealTraceEntity(te,ent) -- Make a new trace so we don't stack overflow
	teo.HitPos = MapRepeat.CellToPos(teo.HitPos,cell)
	teo.StartPos = te.start
	return teo -- Return TraceEntity with the new filters
end

if !util.RealTraceHull then -- If we don't know what RealTraceHull is
	util.RealTraceHull = util.TraceHull -- RealTraceHull is just a duplicate of TraceHull
end
function util.TraceHull(th) -- Override for TraceHull
	if !MapRepeat then -- If MapRepeat isn't active
		util.TraceHull = util.RealTraceHull -- Reset to normal TraceHull
		return util.TraceHull(th) -- Perform normal TraceHull
	end

	cell,th.start,th.endpos = MapRepeat.PosToCell(th.start,th.endpos) -- Get the cell the TraceHull is in
	
	local tho = util.RealTraceHull( { -- Make a new trace so we don't stack overflow
	start = th.start,
	endpos = th.endpos,
	filter = function(e)
		if(type(th.filter) == 'function') then -- Function to add entities to new filter
			pass = th.filter(e)
		else
			pass = table.HasValue(th.filter,e)
		end
		return MapRepeat.InCell(e,cell) && pass
	end,
	mins = th.mins,
	maxs = th.maxs,
	} )
	
	return tho -- Return TraceHull with new filters
end

if !util.RealQuickTrace then -- If we don't know what RealQuickTrace is
	util.RealQuickTrace = util.QuickTrace -- RealQuickTrace is just a duplicate of QuickTrace
end
function util.QuickTrace(origin,dir,filter) -- Override for QuickTrace
	if !MapRepeat then -- If MapRepeat isn't active
		util.QuickTrace = util.RealQuickTrace -- Reset to normal QuickTrace
		return util.QuickTrace(origin,dir,filter) -- Perform normal QuickTrace
	end

	cell = MapRepeat.PosToCell(origin,dir*2147483647) -- Find cell the QuickTrace is in 
	local nfilter = {} -- Make a new filter
	
	for _,e in pairs(ents.GetAll()) do -- Get all entities
		if !MapRepeat.InCell(e,cell) then -- If the entity isn't in your cell
			nfilter[#nfilter+1] = e -- Add it to the filters
		end
	end	

	local qto = util.RealQuickTrace(origin,dir,nfilter) -- Make a new trace so we don't stack overflow
	
	return qto -- Return QuickTrace with new filters
end

if !RealCleanUpMap then -- If we don't know what RealCleanUpMap is
	RealCleanUpMap = game.CleanUpMap -- RealCleanUpMap is just a duplicate of CleanUpMap
end
function game.CleanUpMap(send, filters) -- Override for CleanUpMap
	if !MapRepeat then -- If MapRepeat isn't active
		game.CleanUpMap = RealCleanUpMap -- Reset to normal CleanUpMap
		return game.CleanUpMap(send,filters) -- Perform normal CleanUpMap
	end
	if type(filters) != 'table' then filters = {filters} end -- If the filters aren't a table, set them to a table
	if !table.HasValue(filters,"func_brush") then filters[#filters+1] = "func_brush" end -- Add all func_brushes to the filters
	return RealCleanUpMap(send, filters) -- Return CleanUpMap with the new filters
end
