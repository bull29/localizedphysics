MapRepeat.CelledEnts = MapRepeat.CelledEnts or {}
MapRepeat.Hooks = {}
function MapRepeat.AddHook(a,b,c)
	MapRepeat.Hooks[a] = MapRepeat.Hooks[a] or {}
	MapRepeat.Hooks[a][b] = c
end
function MapRepeat.InstallHooks()
	for a,t in pairs(MapRepeat.Hooks) do
		for b,c in pairs(t) do
			hook.Add(a,b,c)
		end
	end
end
net.Receive("maprepeat_install",function()
	MapRepeat.InstallHooks()
end)
net.Receive("maprepeat_uninstall",function()
	MapRepeat = nil
end)
net.Receive("maprepeat_num",function()
	local k = net.ReadString()
	MapRepeat.Sync[k] = net.ReadFloat()
end)
net.Receive("maprepeat_rgen",function()
	local k = net.ReadInt(16)
	if IsValid(Entity(k)) then k = Entity(k) end
	local rg = {}
	local sz = net.ReadInt(16)
	rg.r = net.ReadInt(16)
	local i
	for i=1,sz do
		rg[i] = {}
		rg[i][1] = net.ReadString()
		rg[i][2] = net.ReadString()
		rg[i][3] = net.ReadString()
	end
	MapRepeat.RGen[k] = rg
end)
net.Receive("maprepeat_space",function() --SPACE
	local s = net.ReadFloat()
	MapRepeat.Space = s
end)
net.Receive("maprepeat_cell",function()
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
net.Receive("maprepeat_setcell",function()
	if !MapRepeat then return end
	local e = net.ReadInt(16)
	if IsValid(Entity(e)) then e = Entity(e) end
	local c = net.ReadString()
	if type(MapRepeat.CelledEnts[e]) == 'string' then
		MapRepeat.Cells[MapRepeat.CelledEnts[e]][e] = nil
		if IsEntity(e) then
			MapRepeat.Cells[MapRepeat.CelledEnts[e]][e:EntIndex()] = nil
		end
	end
	MapRepeat.Cells[c] = MapRepeat.Cells[c] or {}
	MapRepeat.Cells[c][e] = true
	MapRepeat.CelledEnts[e] = c
	if e == LocalPlayer() then
		local ct = MapRepeat.CellToArray(c)
		e.Cell = Vector(ct[1],ct[2],ct[3])
		e.CellStr = c
	end
end)

function MapRepeat.DrawCell(x,y,z)
	local s = MapRepeat.Sync
	local l,r,t,b,u,d = s.left, s.right, s.top, s.bottom, s.up, s.down
	local w = (r or 0) - (l or 0)
	local h = (b or 0) - (t or 0)
	local v = (u or 0) - (d or 0)
	if s.tilemap == 1 then -- 
		
	end 
	local pl = LocalPlayer()
	if !pl.Cell then 
		pl.Cell = Vector(0,0,0) 
		pl.CellStr = "0 0 0"
	end
	cam.Start3D(RealEyePos()-Vector(x*w,y*h,z*v),RenderAngles())
		local c = (x+pl.Cell.x)..' '..(y+pl.Cell.y)..' '..(z+pl.Cell.z)
		if !(MapRepeat.Cells[c] and MapRepeat.Cells[c].gen) then
			MapRepeat.GenCell(c)
		end
		for k,v in pairs(MapRepeat.Cells[c]) do
			if tonumber(k) and Entity(tonumber(k)):IsValid() then
				MapRepeat.Cells[c][Entity(tonumber(k))] = v
			end
			if k == NULL then
				MapRepeat.Cells[c][k] = nil
			end
		end
		for k,v in pairs(MapRepeat.Cells[c]) do
			if tonumber(k) == 'number' and Entity(tonumber(k)):IsValid() then
				MapRepeat.Cells[c][k] = nil
				k = Entity(k)
			end
			if type(k) == 'Entity' and k:IsValid() and v then
				(k.Draw or k.DrawModel)(k)
				if k.MRNoDraw then
					k:SetNoDraw(false)
					k.MRNoDraw = false
				end
			end
		end
	cam.End3D()
end
MapRepeat.AddHook("PostDraw2DSkyBox","DR_MRSkybox",function() --SPAACE!
	if !MapRepeat.Space then return end
	local fogmode = render.GetFogMode()
	local pl = LocalPlayer()
	if !pl.Cell then
		pl.Cell = Vector(0,0,0)
	end
	if(pl.Cell.z >= MapRepeat.Space) then
	local mul = pl.Cell.z
	render.OverrideDepthEnable(true,false)
	
	cam.Start3D(Vector(0,0,0),RenderAngles())
		render.SetMaterial(Material("maprepeater/space"))
		render.DrawBox(Vector(0,0,-512),Angle(0,0,0),Vector(-512,-512,0),Vector(512,512,0),Color(10,10,10,255),0)
		render.DrawBox(Vector(0,0,512),Angle(0,0,0),Vector(512,512,0),Vector(-512,-512,0),Color(10,10,10,255),0)
		render.DrawBox(Vector(0,-512,0),Angle(0,0,0),Vector(-512,0,-512),Vector(512,0,512),Color(10,10,10,255),0)
		render.DrawBox(Vector(0,512,0),Angle(0,0,0),Vector(512,0,512),Vector(-512,0,-512),Color(10,10,10,255),0)
		render.DrawBox(Vector(512,0,0),Angle(0,0,0),Vector(0,512,512),Vector(0,-512,-512),Color(10,10,10,255),0)
		render.DrawBox(Vector(-512,0,0),Angle(0,0,0),Vector(0,-512,-512),Vector(0,512,512),Color(10,10,10,255),0)
		render.FogMode(0)
	cam.End3D()
	
	render.OverrideDepthEnable(false,false)
	elseif(fogmode) then
		render.FogMode(fogmode)
	end
end)
local ignored_ents = {}
ignored_ents["viewmodel"] = true
ignored_ents["class CLuaEffect"] = true
MapRepeat.AddHook("RenderScene","SL_MRScene",function()
	local pl = LocalPlayer()
	if !pl.Cell then 
		pl.Cell = Vector(0,0,0) 
		pl.CellStr = "0 0 0"
	end
	if !(MapRepeat.Cells[pl.CellStr] and MapRepeat.Cells[pl.CellStr].gen) then
		MapRepeat.GenCell(pl.CellStr)
	end
	for _,e in pairs(ents.GetAll()) do
		if !ignored_ents[e:GetClass()] and (e:GetOwner() != LocalPlayer() or e:GetClass() != "physgun_beam") then
			if !(MapRepeat.CelledEnts[e] or MapRepeat.CelledEnts[e:EntIndex()] or MapRepeat.RGen[e] or MapRepeat.RGen[e:EntIndex()]) then
				MapRepeat.Cells["0 0 0"][e] = true
				MapRepeat.CelledEnts[e] = "0 0 0"
			elseif MapRepeat.CelledEnts[e:EntIndex()] then
				local old = MapRepeat.CelledEnts[e:EntIndex()]
				MapRepeat.CelledEnts[e:EntIndex()] = nil
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
MapRepeat.AddHook("PostDrawOpaqueRenderables","SL_MRDraw",function()
	local s = MapRepeat.Sync
	if (tonumber(s.cube) or 0) > 0 then
		for x = -s.cube,s.cube do
			for y = -s.cube,s.cube do
				for z = -s.cube,s.cube do
					if !(x == 0 && y == 0 && z == 0) then
						MapRepeat.DrawCell(x,y,z)
					end
				end
			end
		end
		return
	end

	local l = s.left
	local r = s.right
	local t = s.top
	local b = s.bottom
	local u = s.up
	local d = s.down
	--sides
	if l then MapRepeat.DrawCell(-1,0,0) end
	if r then MapRepeat.DrawCell(1,0,0) end
	if t then MapRepeat.DrawCell(0,-1,0) end
	if b then MapRepeat.DrawCell(0,1,0) end
	if u then MapRepeat.DrawCell(0,0,1) end
	if d then MapRepeat.DrawCell(0,0,-1) end
	--2D corners (XY)
	if l and t then MapRepeat.DrawCell(-1,-1,0) end
	if r and t then MapRepeat.DrawCell(1,-1,0) end
	if l and b then MapRepeat.DrawCell(-1,1,0) end
	if r and b then MapRepeat.DrawCell(1,1,0) end
	--2D corners (XZ)
	if l and d then MapRepeat.DrawCell(-1,0,-1) end
	if r and d then MapRepeat.DrawCell(1,0,-1) end
	if l and u then MapRepeat.DrawCell(-1,0,1) end
	if r and u then MapRepeat.DrawCell(1,0,1) end
	--2D corners (YZ)
	if l and d then MapRepeat.DrawCell(0,-1,-1) end
	if r and d then MapRepeat.DrawCell(0,1,-1) end
	if l and u then MapRepeat.DrawCell(0,-1,1) end
	if r and u then MapRepeat.DrawCell(0,1,1) end
	--3D corners (+Z)
	if l and t and u then MapRepeat.DrawCell(-1,-1,1) end
	if r and t and u then MapRepeat.DrawCell(1,-1,1) end
	if l and b and u then MapRepeat.DrawCell(-1,1,1) end
	if r and b and u then MapRepeat.DrawCell(1,1,1) end
	--3D corners (-Z)
	if l and t and d then MapRepeat.DrawCell(-1,-1,-1) end
	if r and t and d then MapRepeat.DrawCell(1,-1,-1) end
	if l and b and d then MapRepeat.DrawCell(-1,1,-1) end
	if r and b and d then MapRepeat.DrawCell(1,1,-1) end
end)
MapRepeat.AddHook("ShouldCollide","SL_MRCollideCL",function(e1,e2)
	if GravHull.SHIPCONTENTS[LocalPlayer()] then return end
    if e1 == LocalPlayer() then
		if !(MapRepeat.Cells[e1.CellStr or "0 0 0"]) then return true end
        if !(MapRepeat.Cells[e1.CellStr or "0 0 0"][e2] or MapRepeat.Cells[e1.CellStr or "0 0 0"][e2:EntIndex()]) then return false end
    elseif e2 == LocalPlayer() then
		if !(MapRepeat.Cells[e2.CellStr or "0 0 0"]) then return true end
        if !(MapRepeat.Cells[e2.CellStr or "0 0 0"][e1] or MapRepeat.Cells[e2.CellStr or "0 0 0"][e1:EntIndex()]) then return false end
    end
end)
MapRepeat.AddHook("PhysgunPickup","SL_MRPickup",function(pl,e)
	if !(MapRepeat.Cells[pl.CellStr or "0 0 0"][e] or MapRepeat.Cells[pl.CellStr or "0 0 0"][e:EntIndex()]) then return false end
	if MapRepeat.CelledEnts[e] == true then return false end
end)
local VEC = FindMetaTable("Vector")
if !VEC.RealToScreen then VEC.RealToScreen = VEC.ToScreen end
function VEC:ToScreen()
	if !MapRepeat then return self:RealToScreen() end
	local cell,pos = MapRepeat.PosToCell(self)
	return pos:RealToScreen()
end
if !RealEyePos then RealEyePos = EyePos end
function EyePos()
	if !MapRepeat then return RealEyePos() end
	return MapRepeat.CellToPos(RealEyePos(),LocalPlayer().CellStr)
end
