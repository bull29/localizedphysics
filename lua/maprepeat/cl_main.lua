MapRepeat.CelledEnts = MapRepeat.CelledEnts or {}
MapRepeat.Hooks = {}
function MapRepeat.AddHook(a,b,c) -- If MapRepeat is active, add the hooks
	MapRepeat.Hooks[a] = MapRepeat.Hooks[a] or {}
	MapRepeat.Hooks[a][b] = c
end
function MapRepeat.InstallHooks() -- If MapRepeat is active, install the hooks
	for a,t in pairs(MapRepeat.Hooks) do
		for b,c in pairs(t) do
			hook.Add(a,b,c)
		end
	end
end
net.Receive("maprepeat_install",function() -- Receive message from server telling us to install
	MapRepeat.InstallHooks()
end)
net.Receive("maprepeat_uninstall",function() -- Receive message from server telling us to uninstall
	MapRepeat = nil
end)
net.Receive("maprepeat_num",function() -- Receive message from server telling us info_maprepeat values
	local k = net.ReadString()
	MapRepeat.Sync[k] = net.ReadFloat()
end)
net.Receive("maprepeat_rgen",function() -- Receive message from server telling us what was randomly generated and where
	local k = net.ReadInt(16)
	if IsValid(Entity(k)) then k = Entity(k) end
	local rg = {}
	local sz = net.ReadInt(16)
	rg.r = net.ReadInt(16)
	local i
	for i=1,sz do -- Get all of the cells in which the ent is in
		rg[i] = {}
		rg[i][1] = net.ReadString() -- X
		rg[i][2] = net.ReadString() -- Y
		rg[i][3] = net.ReadString() -- Z
	end
	MapRepeat.RGen[k] = rg
end)
net.Receive("maprepeat_space",function() -- Receive message from server telling us how far up space is
	local s = net.ReadInt(16)
	MapRepeat.Space = s
end)
net.Receive("maprepeat_cell",function() -- Receive message from server telling us about our cell that we're in
	if !MapRepeat then return end
	local e = net.ReadInt(16)
	if IsValid(Entity(e)) then e = Entity(e) end
	local c = net.ReadString()
	--print(tostring(e) .. "->CELL: " .. c)
	if type(MapRepeat.CelledEnts[e]) == 'string' then
		MapRepeat.Cells[MapRepeat.CelledEnts[e]][e] = nil
	end
	MapRepeat.Cells[c] = MapRepeat.Cells[c] or {}
	MapRepeat.Cells[c][e] = true
	MapRepeat.CelledEnts[e] = true
end)
net.Receive("maprepeat_setcell",function() -- Receive message from server telling us about our new cell
	if !MapRepeat then return end
	local e = net.ReadInt(16) -- Set e equal to the entity
	if IsValid(Entity(e)) then e = Entity(e) end -- If it's valid, make sure it's an entity
	local c = net.ReadString() -- New cell's string
	if type(MapRepeat.CelledEnts[e]) == 'string' then -- If the entity's type is a string
		MapRepeat.Cells[MapRepeat.CelledEnts[e]][e] = nil -- Set its cell to nil
		if IsEntity(e) then
			MapRepeat.Cells[MapRepeat.CelledEnts[e]][e:EntIndex()] = nil -- Update cell data
		end
	end
	MapRepeat.Cells[c] = MapRepeat.Cells[c] or {} -- Script error prevention
	MapRepeat.Cells[c][e] = true -- Set the cell to have the entity
	MapRepeat.CelledEnts[e] = c -- Set the entity to be in the cell
	if e == LocalPlayer() then
		local ct = MapRepeat.CellToArray(c)
		e.Cell = Vector(ct[1],ct[2],ct[3]) -- Set its .Cell value
		e.CellStr = c -- Set its .CellStr value
	end
end)
function MapRepeat.DrawCell(x,y,z) -- Render the cell on our screen!
	local s = MapRepeat.Sync
	local l,r,t,b,u,d = s.left, s.right, s.top, s.bottom, s.up, s.down
	local w = (r or 0) - (l or 0)
	local h = (b or 0) - (t or 0)
	local v = (u or 0) - (d or 0)
	if s.tilemap == 1 then -- Coming soon(???)
		local e = Entity(0)
		e:SetRenderOrigin(Vector(x*w,y*h,z*v))
		e:DrawModel()
		--e:SetRenderOrigin(vector_origin)
	end
	local pl = LocalPlayer() -- The client!
	if !pl.Cell then 
		pl.Cell = Vector(0,0,0) 
		pl.CellStr = "0 0 0"
	end
	cam.Start3D(RealEyePos()-Vector(x*w,y*h,z*v),RenderAngles()) -- Start rendering
		local c = (x+pl.Cell.x)..' '..(y+pl.Cell.y)..' '..(z+pl.Cell.z) -- Make it a string
		if !(MapRepeat.Cells[c] and MapRepeat.Cells[c].gen) then -- If the cell doesn't exist
			MapRepeat.GenCell(c) -- Generate it
		end
		for k,v in pairs(MapRepeat.Cells[c]) do -- Get all of the cells
			if tonumber(k) and IsValid(Entity(tonumber(k))) then -- If the entities are valid
				MapRepeat.Cells[c][Entity(tonumber(k))] = v -- Set the entity's cell
			end
			if k == NULL then
				MapRepeat.Cells[c][k] = nil
			end
		end
		for k,v in pairs(MapRepeat.Cells[c]) do
			if tonumber(k) == 'number' and IsValid(Entity(tonumber(k))) then
				MapRepeat.Cells[c][k] = nil
				k = Entity(k)
			end
			if type(k) == 'Entity' and IsValid(k) and v then
				(k.Draw or k.DrawModel)(k)
				if k.MRNoDraw then
					k:SetNoDraw(false)
					k.MRNoDraw = false
				end
			end
		end
	cam.End3D()
end
/*MapRepeat.AddHook("PostDraw2DSkyBox","DR_MRSkybox",function() -- Rendering space
	if !MapRepeat.Space then return end
	local fogmode = render.GetFogMode() -- If there's fog, save it
	local pl = LocalPlayer() -- The client!
	if !pl.Cell then
		pl.Cell = Vector(0,0,0)
	end
	if(pl.Cell.z >= MapRepeat.Space) then -- If we're in/higher than the cell space starts
	render.OverrideDepthEnable(true,false)
	
	cam.Start3D(Vector(0,0,0),RenderAngles()) -- Render space!
		render.SetMaterial(Material("maprepeater/space"))  -- Set the texture
		render.DrawBox(Vector(0,0,-512),Angle(0,0,0),Vector(-512,-512,0),Vector(512,512,0),Color(10,10,10,255),0)
		render.DrawBox(Vector(0,0,512),Angle(0,0,0),Vector(512,512,0),Vector(-512,-512,0),Color(10,10,10,255),0)
		render.DrawBox(Vector(0,-512,0),Angle(0,0,0),Vector(-512,0,-512),Vector(512,0,512),Color(10,10,10,255),0)
		render.DrawBox(Vector(0,512,0),Angle(0,0,0),Vector(512,0,512),Vector(-512,0,-512),Color(10,10,10,255),0)
		render.DrawBox(Vector(512,0,0),Angle(0,0,0),Vector(0,512,512),Vector(0,-512,-512),Color(10,10,10,255),0)
		render.DrawBox(Vector(-512,0,0),Angle(0,0,0),Vector(0,-512,-512),Vector(0,512,512),Color(10,10,10,255),0)
		render.FogMode(0) -- Turn off fog
	cam.End3D()
	
	render.OverrideDepthEnable(false,false)
	elseif(fogmode) then -- If we're not in space and the map has fog
		render.FogMode(fogmode) -- Return it!
	end
end)*/
local ignored_ents = {}
ignored_ents["viewmodel"] = true
ignored_ents["class CLuaEffect"] = true
MapRepeat.AddHook("RenderScene","SL_MRScene",function() -- Render everything in our cell!
	local pl = LocalPlayer() -- The client!
	if !pl.Cell then 
		pl.Cell = Vector(0,0,0) 
		pl.CellStr = "0 0 0"
	end
	if !(MapRepeat.Cells[pl.CellStr] and MapRepeat.Cells[pl.CellStr].gen) then -- If the player's cell doesn't exist
		MapRepeat.GenCell(pl.CellStr) -- Generate it
	end
	for _,e in pairs(ents.GetAll()) do -- Find all of the entities
		if !ignored_ents[e:GetClass()] and (e:GetOwner() != LocalPlayer() or e:GetClass() != "physgun_beam") then -- If it's not to be ignored
			if !(MapRepeat.CelledEnts[e] or MapRepeat.CelledEnts[e:EntIndex()] or MapRepeat.RGen[e] or MapRepeat.RGen[e:EntIndex()]) then -- If it's not in RGen or CelledEnts
				MapRepeat.Cells["0 0 0"][e] = true -- Set its cell to 0 0 0
				MapRepeat.CelledEnts[e] = "0 0 0" -- Set its string cell to "0 0 0"
			elseif MapRepeat.CelledEnts[e:EntIndex()] then -- If it IS in CelledEnts
				local old = MapRepeat.CelledEnts[e:EntIndex()]
				MapRepeat.CelledEnts[e:EntIndex()] = nil -- Set its CelledEnts to nil
				MapRepeat.CelledEnts[e] = old
			end
			if MapRepeat.CelledEnts[e] or MapRepeat.RGen[e] or MapRepeat.RGen[e:EntIndex()] then
				if !(MapRepeat.Cells[pl.CellStr][e] or MapRepeat.Cells[pl.CellStr][e:EntIndex()]) then
					e:SetNoDraw(true)
					e.MRNoDraw = true
				elseif e.MRNoDraw then
					e:SetNoDraw(false)
					e.MRNoDraw = false
				end
			end
		end
	end
end)
MapRepeat.AddHook("PostDrawOpaqueRenderables","SL_MRDraw",function() -- Render the cells around 0 0 0
	local s = MapRepeat.Sync
	local l,r,f,b,u,d = s.left, s.right, s.top, s.bottom, s.up, s.down
	local left,right,front,back,up,down
	--sides
	if l then 
		left = math.floor(16384/math.abs(l))
		for i=1,left do MapRepeat.DrawCell(0,-i,0) 
	end end
	if r then 
		right = math.floor(16384/math.abs(r))
		for i=1,right do MapRepeat.DrawCell(0,i,0) 
	end end
	if f then 
		front = math.floor(16384/math.abs(f))
		for i=1,front do MapRepeat.DrawCell(i,0,0) 
	end end
	if b then 
		back = math.floor(16384/math.abs(b))
		for i=1,back do MapRepeat.DrawCell(-i,0,0) 
	end end
	if u then 
		up = math.floor(16384/math.abs(u))
		for i=1,up do MapRepeat.DrawCell(0,0,i) 
	end end
	if d then 
		down = math.floor(16384/math.abs(d))
		for i=1,down do MapRepeat.DrawCell(i,0,-1) 
	end end
	--2D corners (XY)
	if l and f then 
		for i=1,left do MapRepeat.DrawCell(1,-i,0) end 
		for i=1,front do MapRepeat.DrawCell(i,-1,0) end 
	end
	if r and f then 
		for i=1,right do MapRepeat.DrawCell(1,i,0) end 
		for i=1,front do MapRepeat.DrawCell(i,1,0) end 
	end
	if l and b then 
		for i=1,left do MapRepeat.DrawCell(-1,-i,0) end 
		for i=1,back do MapRepeat.DrawCell(i,-1,0) end 
	end
	if r and b then 
		for i=1,right do MapRepeat.DrawCell(-1,i,0) end 
		for i=1,back do  MapRepeat.DrawCell(-i,1,0) end 
	end
	--2D corners (XZ)
	if b and d then 
		for i=1,back do MapRepeat.DrawCell(-b,0,-1) end
		for i=1,down do MapRepeat.DrawCell(-1,0,-i) end
	end
	if f and d then 
		for i=1,front do MapRepeat.DrawCell(i,0,-1) end
		for i=1,down do MapRepeat.DrawCell(1,0,-i) end
	end
	if b and u then 
		for i=1,back do MapRepeat.DrawCell(-i,0,1) end
		for i=1,up do MapRepeat.DrawCell(-1,0,i) end
	end
	if f and u then 
		for i=1,front do MapRepeat.DrawCell(i,0,1) end
		for i=1,up do MapRepeat.DrawCell(1,0,i) end
	end
	--2D corners (YZ)
	if l and d then 
		for i=1,left do MapRepeat.DrawCell(0,-i,-1) end
		for i=1,down do MapRepeat.DrawCell(0,-1,-i) end
	end
	if r and d then 
		for i=1,right do MapRepeat.DrawCell(0,i,-1) end
		for i=1,down do MapRepeat.DrawCell(0,1,-i) end
	end
	if l and u then 
		for i=1,left do MapRepeat.DrawCell(0,-i,1) end
		for i=1,up do MapRepeat.DrawCell(0,-1,i) end
	end
	if r and u then 
		for i=1,right do MapRepeat.DrawCell(0,i,1) end
		for i=1,up do MapRepeat.DrawCell(0,1,i) end 
	end
	--3D corners (+Z)
	if l and f and u then 
		for i=1,left do MapRepeat.DrawCell(1,-i,1) end
		for i=1,front do MapRepeat.DrawCell(i,-1,1) end
		for i=1,up do MapRepeat.DrawCell(1,-1,i) end
	end
	if r and f and u then 
		for i=1,right do MapRepeat.DrawCell(1,i,1) end
		for i=1,front do MapRepeat.DrawCell(i,1,1) end
		for i=1,up do MapRepeat.DrawCell(1,1,i) end
	end
	if l and b and u then 
		for i=1,left do MapRepeat.DrawCell(-1,-i,1) end
		for i=1,back do MapRepeat.DrawCell(-i,-1,1) end
		for i=1,up do MapRepeat.DrawCell(-1,-1,i) end
	end
	if r and b and u then 
		for i=1,right do MapRepeat.DrawCell(-1,i,1) end
		for i=1,back do MapRepeat.DrawCell(-i,1,1) end
		for i=1,up do MapRepeat.DrawCell(-1,1,i) end
	end
	--3D corners (-Z)
	if l and f and d then 
		for i=1,left do MapRepeat.DrawCell(1,-i,-1) end
		for i=1,front do MapRepeat.DrawCell(i,-1,-1) end
		for i=1,down do MapRepeat.DrawCell(1,-1,-i) end
	end
	if r and f and d then 
		for i=1,right do MapRepeat.DrawCell(1,i,-1) end
		for i=1,front do MapRepeat.DrawCell(i,1,-1) end
		for i=1,down do MapRepeat.DrawCell(1,1,-i)  end
	end
	if l and b and d then 
		for i=1,left do MapRepeat.DrawCell(-1,-i,-1) end
		for i=1,back do MapRepeat.DrawCell(-i,-1,-1) end
		for i=1,down do MapRepeat.DrawCell(-1,-1,-i) end
	end
	if r and b and d then 
		for i=1,right do MapRepeat.DrawCell(-1,i,-1) end
		for i=1,back do MapRepeat.DrawCell(-i,1,-1) end
		for i=1,down do MapRepeat.DrawCell(-1,1,-i) end
	end
end)
MapRepeat.AddHook("ShouldCollide","SL_MRCollideCL",function(e1,e2) -- Should we collide with this ent?
	if GravHull.SHIPCONTENTS[LocalPlayer()] then return end -- If we're in a Grav Hull, then no
    if e1 == LocalPlayer() then
		if !(MapRepeat.Cells[e1.CellStr or "0 0 0"]) then return true end
        if !(MapRepeat.Cells[e1.CellStr or "0 0 0"][e2] or MapRepeat.Cells[e1.CellStr or "0 0 0"][e2:EntIndex()]) then return false end
    elseif e2 == LocalPlayer() then
		if !(MapRepeat.Cells[e2.CellStr or "0 0 0"]) then return true end
        if !(MapRepeat.Cells[e2.CellStr or "0 0 0"][e1] or MapRepeat.Cells[e2.CellStr or "0 0 0"][e1:EntIndex()]) then return false end
    end
end)
MapRepeat.AddHook("PhysgunPickup","SL_MRPickup",function(pl,e)
	if !(MapRepeat.Cells[pl.CellStr or "0 0 0"][e] or MapRepeat.Cells[pl.CellStr or "0 0 0"][e:EntIndex()]) then return false end -- If the entity is not in our cell, don't let us pick it up
	if MapRepeat.CelledEnts[e] == true then return false end
end)
local VEC = FindMetaTable("Vector")
if !VEC.RealToScreen then VEC.RealToScreen = VEC.ToScreen end -- Stack overflow prevention
function VEC:ToScreen() -- Overrides Vector:ToScreen()
	if !MapRepeat then return self:RealToScreen() end
	local cell,pos = MapRepeat.PosToCell(self)
	return pos:RealToScreen()
end
if !RealEyePos then RealEyePos = EyePos end -- Stack overrflow prevention
function EyePos() -- Overrides EyePos()
	if !MapRepeat then return RealEyePos() end
	return MapRepeat.CellToPos(RealEyePos(),LocalPlayer().CellStr)
end
