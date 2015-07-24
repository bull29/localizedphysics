MapRepeat.Sync = MapRepeat.Sync or {}
MapRepeat.RGen = MapRepeat.RGen or {}
MapRepeat.Cells = MapRepeat.Cells or {}
function MapRepeat.CellToArray(cell)
	if !cell then return end
	local c = {}
	local i = string.find(cell,' ')
	c[1] = string.sub(cell,1,i-1)
	c[2] = string.sub(cell,i+1,string.find(cell,' ',i+1)-1)
	c[3] = string.sub(cell,string.find(cell,' ',i+1)+1)
	return c
end
local srv_genned = {}
function MapRepeat.GenCell(cell)
	if !cell then return end
	local c = MapRepeat.CellToArray(cell)
	MapRepeat.Cells[cell] = MapRepeat.Cells[cell] or {}
	if MapRepeat.Cells[cell].gen then return end
	MapRepeat.Cells[cell].gen = true
	for e,t in pairs(MapRepeat.RGen) do
		for k,v in pairs(t) do
			if type(v) == 'table' then
				local pass = true
				local send = false
				local p = {false,false,false}
				for i=1,3 do
					local token = string.sub(v[i],1,1)
					if token == '%' and CLIENT then
						if !srv_genned[cell] then
							RunConsoleCommand("sl_mr_gencell",cell)
							srv_genned[cell] = true
						end
						pass = false
					elseif token == '%' and SERVER then
						pass = (math.random(1,100) < (tonumber(string.sub(v[i],2)) or 0))
						send = true
						p[i] = true
					end 
				end
				if	pass and 
				    ((v[1] == c[1]) or (v[1] == '?') or p[1]) and
					((v[2] == c[2]) or (v[2] == '?') or p[2]) and
					((v[3] == c[3]) or (v[3] == '?') or p[3]) then
					if send then
						MapRepeat.AddCell(e,cell)
					else
						MapRepeat.Cells[cell][e] = true
						if SERVER and e and e != NULL then
							e.Cells = e.Cells or {}
							e.Cells[#e.Cells+1] = cell
						end
					end
				end
			end
		end
	end
end
function MapRepeat.InCell(e,cell)
	if !IsEntity(e) then return end
	if SERVER then 
		if !e.Cells then return false end
		for _,c in pairs(e.Cells) do
			if c == cell then return true end
		end
		return false
	else return (MapRepeat.Cells[cell] and (MapRepeat.Cells[cell][e] or MapRepeat.Cells[cell][e:EntIndex()])) or MapRepeat.CelledEnts[e] == cell or MapRepeat.CelledEnts[e:EntIndex()] == cell end
end
function MapRepeat.CellToPos(_pos,cell)
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
function MapRepeat.PosToCell(_pos,_pos2)
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
if !util.RealTraceLine then
	util.RealTraceLine = util.TraceLine
end
function util.TraceLine(_tr)
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