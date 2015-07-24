local GH = GravHull
include('sh_codetools.lua')
GH.HULLS = {} --contains all hull props, used to stop multiple designations
GH.GHOSTS = {} --contains all hull ghosts, used for garbage collection.
GH.SHIPS = {} --a list of all current ships, keyed by their master dampener
GH.Transition = {} --a list of functions to call for certain classes when they are eaten
GH.PHYSGHOSTS = {} --a list of dual-state objects inside or outside a ship
GH.ROCKETHAX = {} --a list of rockets to hax
GH.copyValues = {} --PUT VARIOUS ENTITY VARIABLES IN HERE
hook.Add("Initialize","GravhullTag",function()
	if !string.find(GetConVarString("sv_tags"),"gravhull") then
		RunConsoleCommand("sv_tags",GetConVarString("sv_tags") .. ",gravhull")
	end
end)
cvars.AddChangeCallback("ghd_debugoverrides",function()
	Msg("Gravity Hull Designator - Debug Mode Toggled\nNOTE: Use debug mode if you're getting null entity errors to see where they are coming from. This may lag.")
	GH.DebugOverride = GH.DebugOverrideCV:GetBool()
	GH.GenSimpleOverrides()
end)
------------------------------------------------------------------------------------------
-- Name: UnHull
-- Desc: Removes a gravity hull.
------------------------------------------------------------------------------------------
function GH.UnHull(ent)
	if !GH.SHIPS[ent] then return end
	for _,e in pairs(GH.SHIPS[ent].Contents) do
		GH.ShipSpit(ent,e)
	end
	for _,e in pairs(GH.SHIPS[ent].Hull) do
		GH.HULLS[e] = nil
		if IsValid(e.Ghost) then
			e.Ghost:DontDeleteOnRemove(e)
			e.Ghost:Remove()
		end
	end
	--take out the trash
	for _,e in pairs(GH.GHOSTS) do
		if IsValid(e) and (!IsValid(e.MyShip) or !GH.SHIPS[e.MyShip]) then
			e:Remove()
		end
	end
	GH.SHIPS[ent] = nil
end
------------------------------------------------------------------------------------------
-- Name: ShipObject
-- Desc: Send an object to the client.
------------------------------------------------------------------------------------------
function GH.ShipObject(p,y,h,e,g)
	umsg.Start("sl_ship_object")
		umsg.Short(p:EntIndex())
		umsg.Bool(y)
		umsg.Bool(h)
		if e then
			umsg.Short(e:EntIndex())
			umsg.Short(g:EntIndex())
		end
	umsg.End()
end
function GH.ClientGhost(ent,ge,e)
	GH.ShipObject(ge,true,true,ent,e)
	if (IsValid(ge)) then
		ge:RealSetColor(Color(255,255,255,255))
		ge:RealSetMaterial("models/effects/vol_light001")
	end
end
------------------------------------------------------------------------------------------
-- Name: GhostSetup
-- Desc: Used when creating a hull ghost.
------------------------------------------------------------------------------------------
function GH.GhostSetup(ent,e,ge,pos,nrm)
	local ang 
	if !nrm then nrm = Vector(0,0,1) end
	ge:SetModel(e:GetModel())
	e.Ghost = ge
	if ent == e then
		ge:SetRealPos(pos)
		ge:SetAngles(e:AlignAngles(nrm:Angle(),Vector(0,0,1):Angle()))
	else
		if IsValid(ent.Ghost) then
			ge:SetRealPos(ent.Ghost:RealLocalToWorld(ent:RealWorldToLocal(e:GetRealPos())))
			ge:SetAngles(ent.Ghost:RealLocalToWorldAngles(ent:RealWorldToLocalAngles(e:GetRealAngles())))
		else
			local gpos,gang = LocalToWorld(e:GetRealPos(),e:GetRealAngles(),ent:GetRealPos(),ent:GetRealAngles())
			gpos,gang = WorldToLocal(gpos,gang,ent.Ghost:GetRealPos(),ent.Ghost:GetRealAngles())
			ge:SetRealPos(gpos)
			ge:SetAngles(gang)
		end
		e:CallOnRemove("GHUpdateHull",GH.UpdateHull,ent)
	end
	ge:DeleteOnRemove(e)
	ge:Spawn()
	ge:SetColor(Color(0,0,0,0)) --temp invisibility until the client sees us
	ge:DrawShadow(false)
	ge:SetCollisionGroup(e:GetCollisionGroup())
	timer.Simple(0,function() GH.ClientGhost(ent,ge,e) end) --true invisibility
	local gep = ge:GetPhysicsObject()
	if gep:IsValid() then 
		gep:EnableMotion(false)
		gep:SetMass(50000) --the "solid" effect
	end
	if e.IsNotSolid then ge:SetNotSolid(true) end
	for _,v in pairs(GH.copyValues) do
		ge[v] = e[v]
	end
	e:DeleteOnRemove(ge)
	ge.MyShip = ent
end
------------------------------------------------------------------------------------------
-- Entity Removal Hooks
-- Desc: Fixes for removing things, as well as the explosion fix
------------------------------------------------------------------------------------------
hook.Add("EntityRemoved","SLDestroyShip",function(ent)
	if GH.SHIPS[ent] then GH.UnHull(ent) end
end)
local explosive_models = kv_swap{
	"models/props_c17/oildrum001_explosive.mdl",
	"models/props_phx/mk-82.mdl",
	"models/props_phx/oildrum001_explosive.mdl",
	"models/props_phx/torpedo.mdl",
	"models/props_phx/ww2bomb.mdl",
	"models/props_phx/misc/flakshell_big.mdl",
	"models/props_phx/amraam.mdl",
	"models/props_phx/cannonball.mdl",
	"models/props_phx/ball.mdl",
	"models/props_junk/gascan001a.mdl",
	"models/props_junk/propane_tank001a.mdl",
}
hook.Add("EntityRemoved","SLBarrelFix",function(ent)
xpcall(function()
	if ent.InShip && ((ent:GetClass() == "prop_physics" && ent:Health() <= 0 && explosive_models[ent:GetModel()]) || ent:GetClass() == "npc_grenade_frag") then
		umsg.Start("sl_ship_explosion")
			umsg.Vector(ent:GetPos())
			umsg.Vector(ent:GetRealPos())
		umsg.End()
	end
end,ErrorNoHalt)
end)
hook.Add("ValidHull","NoPhysbox",function(ent)
	if string.find(ent:GetClass(),"physbox") then return false end
end)
------------------------------------------------------------------------------------------
-- Name: ConstrainedEntities
-- Desc: Get all entities that are actually physically constrained to ent (not nocollide)
------------------------------------------------------------------------------------------
function GH.ConstrainedEntities(ent)
	local out = {[ent] = ent}
	local tbtab = {{ent,1}}
	if ent.Constraints then
		while #tbtab > 0 do
			local bd = tbtab[#tbtab]
			local bde = bd[1]
			local bdc = bde.Constraints[bd[2]]
			local ce
			if bdc then
				if bde == bdc.Ent1 then
					ce = bdc.Ent2
				else
					ce = bdc.Ent1
				end
			end
			if bd[2] > #bde.Constraints then --last constraint for this entity
				tbtab[#tbtab] = nil --pop from the stack
			elseif !IsValid(bdc) or !IsValid(ce) or bdc:GetClass() == "phys_keepupright" or bdc:GetClass() == "logic_collision_pair" then --NULL, skip
				bd[2] = bd[2] + 1 --next constraint
			else --not keep upright or no collide
				if !out[ce] then
					tbtab[#tbtab+1] = {ce,1}
				else
					bd[2] = bd[2] + 1 --next constraint
				end
				out[bde] = bde
				out[ce] = ce
			end
		end
	end
	return out
end
------------------------------------------------------------------------------------------
-- Name: RegisterHull(Entity, Vertical Protrusion Factor, Gravity Percentage)
-- Desc: Begin designation of a hull-- call UpdateHull(ent) to fill in the rest.
------------------------------------------------------------------------------------------
function GH.RegisterHull(ent,vpf,grav)
	GravHull.SHIPS[ent] = {Hull = {}, Ghosts = {}, Contents = {}, Parts = {}, FloorDist = vpf, Gravity = grav}
end
------------------------------------------------------------------------------------------
-- Name: UpdateHull
-- Desc: Create or update a gravity hull's ghost, including moving parts.
------------------------------------------------------------------------------------------
function GH.UpdateHull(ent,gravnormal)
	if !(IsValid(ent) and GH.SHIPS[ent]) then return end
	local xcon = GH.ConstrainedEntities(ent) --this is just for the update check
	local gents = GH.SHIPS[ent].Ghosts
    local welds = {[ent] = ent}
    local parts = {}
    local tbtab = {{ent,1}}
    local weldpass = false
	--THE HULL SCANNER
	-------------------
	--Adds any prop connected solidly to ent as part of its hull,
	--and any prop connected with a nonsolid constraint to the parts list.
	--Also adds other constrained hulls as special parts.
	if ent.Constraints then
		while #tbtab > 0 do
			local bd = tbtab[#tbtab]
			local bde = bd[1]
			local bdc = bde.Constraints[bd[2]]
			local ce
			if bdc then
				if bde == bdc.Ent1 then
					ce = bdc.Ent2
				else
					ce = bdc.Ent1
				end
			end
			if bd[2] > #bde.Constraints then --last constraint for this entity
				tbtab[#tbtab] = nil --pop from the stack
				if #tbtab == 0 and !weldpass then
					weldpass = true
					tbtab = {{ent,1}}
				end
			elseif !IsValid(bdc) or !IsValid(ce) then --NULL, skip
				bd[2] = bd[2] + 1 --next constraint
			elseif GH.HULLS[ce] and !GH.SHIPS[ent].Hull[ce] and bdc:GetClass() != "logic_collision_pair" then --connecting another hull ghost, not a nocollide
				bd[2] = bd[2] + 1 --next constraint
				parts[ce] = ce --add to the parts list
			elseif bdc:GetClass() == "phys_constraint" then --weld/nail
				if weldpass then
					if !welds[ce] then
						tbtab[#tbtab+1] = {ce,1}
					else
						bd[2] = bd[2] + 1 --next constraint
					end
					parts[bde] = nil
					parts[ce] = nil
					welds[bde] = bde
					welds[ce] = ce
				else
					if !parts[ce] then
						tbtab[#tbtab+1] = {ce,1}
					else
						bd[2] = bd[2] + 1 --next constraint
					end
					parts[bde] = bde
					parts[ce] = ce
				end
			elseif !weldpass and bdc:GetClass() != "phys_keepupright" and bdc:GetClass() != "logic_collision_pair" then --not keep upright or no collide, must be a nonfixed constraint
				if !parts[ce] then
					tbtab[#tbtab+1] = {ce,1}
				else
					bd[2] = bd[2] + 1 --next constraint
				end
				parts[bde] = bde
				parts[ce] = ce
			else --some other constraint
				bd[2] = bd[2] + 1 --skip, go to the next constraint
			end
		end
	end
	for k,e in pairs(welds) do
		if !(IsValid(e) && e:GetModel() && e:GetMoveType() == MOVETYPE_VPHYSICS && e:GetPhysicsObjectCount() == 1 && hook.Call("ValidHull",nil,e) != false) then
			welds[k]=nil
		end
	end
	local pos = vector_origin
	local rad = 0
	local amt = 0
	for _,p in pairs(welds) do
		if IsValid(p) then
			pos = pos + p:GetRealPos()
			amt = amt + 1
		end
	end
	if amt > 0 then pos = pos / amt end
	for _,p in pairs(welds) do
		if IsValid(p) then
			local mrad = p:GetRealPos():Distance(pos) + p:BoundingRadius()
			if mrad > rad then rad = mrad end
		end
	end
	local npos = GH.SHIPS[ent].NPos or GH.FindNowhere(rad)
	for k,e in pairs(GH.SHIPS[ent].Hull) do
		if !welds[e] then
			GH.HULLS[e] = nil
			GH.SHIPS[ent].Hull[k] = nil
			if IsValid(e) and IsValid(e.Ghost) then
				e.Ghost:DontDeleteOnRemove(e)
				e.Ghost:Remove() --WHO YOU GONNA CALL?
			end
		end
	end
	for _,e in pairs(GH.SHIPS[ent].Parts) do
		if !parts[e] && IsValid(e.SLMyGhost) then
			GH.DisablePhysGhost(e,e.SLMyGhost)
		end
	end
	if !IsValid(GH.SHIPS[ent].MainGhost) then
		local mg = ents.Create("prop_physics")
		GH.GhostSetup(ent,ent,mg,npos,gravnormal)
		GH.GHOSTS[mg] = mg
		GH.HULLS[ent] = ent
		gents[mg] = ent
		GH.SHIPS[ent].MainGhost = mg
	end
	for _,e in pairs(welds) do
		if ent != e and !IsValid(GH.HULLS[e]) and IsValid(e) then --if something's already part of a hull, don't ghost it
			local ge = ents.Create("prop_physics")
			GH.GhostSetup(ent,e,ge,npos,gravnormal)
			GH.GHOSTS[ge] = ge
			GH.HULLS[e] = e
			gents[ge] = e
			if ent == e then
				GH.SHIPS[ent].MainGhost = ge
			end
		end
	end
	for _,e in pairs(parts) do
		GH.PhysGhost(ent,e).Permanent = true
	end
	GH.SHIPS[ent].Hull = welds
	GH.SHIPS[ent].Parts = parts
	GH.SHIPS[ent].Welds = xcon
	GH.SHIPS[ent].NPos = npos
	GH.SHIPS[ent].Ghosts = gents
	GH.SHIPS[ent].Center = ent:RealWorldToLocal(pos)
	GH.SHIPS[ent].Radius = rad
	GH.SHIPS[ent].Volume = {}
end
------------------------------------------------------------------------------------------
-- Name: FindNowhere
-- Desc: Find a place to put the ghost ship.
------------------------------------------------------------------------------------------
function GH.FindNowhere(rad)
	local nowhere = vector_origin
	--local skycam = ents.FindByClass("sky_camera")[1]
	--if IsValid(skycam) then skycam = skycam:GetRealPos() else skycam = nil end
	while !((util.PointContents(nowhere) == CONTENTS_EMPTY or util.PointContents(nowhere) == CONTENTS_TESTFOGVOLUME) and 
			!util.TraceHull{start=nowhere,endpos=nowhere,mins=Vector(1,1,1)*-rad,maxs=Vector(1,1,1)*rad,mask = MASK_SOLID + CONTENTS_WATER}.Hit and --HIT EVERYTHING
			hook.Call("AllowGhostSpot",nil,nowhere,rad) != false)do--and (!skycam or util.RealTraceLine{start=nowhere,endpos=skycam,mask=MASK_NPCWORLDSTATIC}.Hit)) do
		nowhere = Vector(math.random(-16384,16384),math.random(-16384,16384),math.random(-16384,16384))
	end
	return nowhere
end
------------------------------------------------------------------------------------------
-- Name: sl_antiteleport
-- Desc: Used by the client to stop SetPos packet loss
------------------------------------------------------------------------------------------
concommand.Add("sl_antiteleport",function(p)
	if !p.AntiTeleportPos then return end
	if (p:GetRealPos():Distance(p.AntiTeleportPos) > 3000) and !p:InVehicle() then
		p:SetRealPos(p.AntiTeleportPos)
		SendUserMessage("sl_antiteleport_cl",p,p.AntiTeleportPos) --pingpong until they're where they should be
	else
		p.AntiTeleportPos = nil
	end
end)
------------------------------------------------------------------------------------------
-- Name: sl_external_use
-- Desc: Sent by the client to use an object while inside a hull
------------------------------------------------------------------------------------------
concommand.Add("sl_external_use",function(p)
	if !(p.InShip and GH.SHIPS[p.InShip]) then return end
	local tr = p:GetEyeTrace()
	if p:GetPos():Distance(tr.HitPos) < 140 && tr.Entity.InShip != p.InShip then
		local e = tr.Entity
		if e:IsVehicle() then
			timer.Simple(0.2,function() p.EnterVehicle(p,e) end)
		elseif e.Use then
			e:Use(p,p,1,0)
		else
			e:Fire("Use","1",0)
		end
		sound.Play("common/wpn_select.wav",e:GetPos(),60,100)
	end
end)
------------------------------------------------------------------------------------------
-- Name: SLToolFix
-- Desc: Stops tools on physghosts, then manually recreates it with a transformed trace
------------------------------------------------------------------------------------------
hook.Add("CanTool","SLToolFix",function(pl,tr,tm,nope)
	if nope == "SLToolFix" then return end
	local can = hook.Call("CanTool",GAMEMODE,pl,tr,tm,"SLToolFix")
	if !can then return false end
	if IsValid(tr.Entity) and tr.Entity.SLIsGhost and IsValid(tr.Entity.SLMyGhost) and IsValid(tr.Entity.SLMyGhost.InShip) then --hit a physghost that's in a ship
		local tool = pl:GetActiveWeapon():GetToolObject()
		local dofx = false
		local ttr = GH.GetInteriorEyeTrace(tr.Entity.SLMyGhost.InShip, pl)
		if hook.Call("CanTool",GAMEMODE,pl,ttr,tm,"SLToolFix") == false then return end
		if !pl:KeyDownLast(IN_ATTACK) and pl:KeyDown(IN_ATTACK) then 
			dofx = tool:LeftClick(ttr)
		elseif !pl:KeyDownLast(IN_ATTACK2) and pl:KeyDown(IN_ATTACK2) then
			dofx = tool:RightClick(ttr)
		elseif !pl:KeyDownLast(IN_RELOAD) and pl:KeyDown(IN_RELOAD) then
			dofx = tool:Reload(ttr)
		end
		if dofx then
			umsg.Start("sl_fake_tooltrace")
				umsg.Entity(pl:GetActiveWeapon())
				umsg.Entity(tr.Entity)
				umsg.Vector(tr.HitPos)
				umsg.Vector(tr.HitNormal)
				umsg.Short(tr.PhysicsBone)
			umsg.End()
		end
		return false --don't do the normal tool stuff
	end
end)
------------------------------------------------------------------------------------------
-- Name: AntiTeleport
-- Desc: Start the AntiTeleport handshake
------------------------------------------------------------------------------------------
function GH.AntiTeleport(p,ppos)
	if !p:Alive() or p:InVehicle() then return end
	p.AntiTeleportPos = ppos
	SendUserMessage("sl_antiteleport_cl",p,p.AntiTeleportPos)
end
local never_eat = kv_swap{
	"physgun_beam"
}
function GH.Transition:gmod_hoverball(old,new,oldpos,oldang)
	self.dt.TargetZ = new:LocalToWorld(old:WorldToLocal(Vector(oldpos.x,oldpos.y,self.dt.TargetZ))).z
end
function GH.Transition:rpg_missile()
	local ply = GH.ROCKETHAX[self] or self:GetOwner()
	if IsValid(ply) and (ply.InShip or self.InShip) then
		GH.ROCKETHAX[self] = ply
		self:SetOwner(NULL)
		self.Attacker = ply
	else
		GH.ROCKETHAX[self] = nil
		self:SetOwner(ply)
	end
end
local function FixMass(p)
	if p.HeldBone and p.OldMass and p:GetPhysicsObjectNum(p.HeldBone):IsValid() then
		p:GetPhysicsObjectNum(p.HeldBone):SetMass(p.OldMass)
		if IsValid(p.SLMyGhost) and p.SLMyGhost:GetPhysicsObjectNum(p.HeldBone):IsValid() then
			p.SLMyGhost:GetPhysicsObjectNum(p.HeldBone):SetMass(p.OldMass)
		end
	end
end
NO_VEL = 1
------------------------------------------------------------------------------------------
-- Name: ShipEat
-- Desc: Put an entity inside a ship.
------------------------------------------------------------------------------------------
function GH.ShipEat(e,p,nm)
	if !GH.SHIPS[e] then return end
	if !IsValid(p) then return end
	if p.SLIsGhost then return end
	if p:IsWorld() then return end
	if p.InShip == e then return end
	if never_eat[p:GetClass()] then return end
	local g = GH.SHIPS[e].MainGhost
	p.InShip = e
	GH.SHIPS[e].Contents[p] = p
	local oldpos,oldang = p:GetRealPos(),p:GetRealAngles()
	if (nm!=true) or (e:GetPos() and !e.UsedFakePos) then
		if p:IsPlayer() then
			if IsValid(p.Holding) then
				FixMass(p.Holding)
				p:Freeze(true)
				timer.Simple(0.02,function() p:Freeze(false) end)
				if p.Holding.SLIsGhost then
					GH.DisablePhysGhost(p.Holding,p.Holding.SLMyGhost)
				end
			end
			local ppos = g:RealLocalToWorld(e:RealWorldToLocal(p:GetRealPos()+p:OBBCenter()))
			ppos = util.TraceLine{start = ppos, endpos = ppos+Vector(0,0,p:OBBMaxs().z)}.HitPos-Vector(0,0,p:OBBMaxs().z)
			ppos = util.TraceLine{start = ppos, endpos = ppos-p:OBBCenter()}.HitPos
			p.OldGravity = p:GetGravity()
			if GH.SHIPS[e].Gravity == 0 then --fixes the "can't have 0 gravity" problem
				p:SetGravity(0.0000001)
			else
				p:SetGravity((GH.SHIPS[e].Gravity or 100) / 100)
			end
			p:SetRealPos(ppos)
			GH.AntiTeleport(p,ppos)
			if nm == 1 then
				p:SetLocalVelocity(g:RealLocalToWorld(e:RealWorldToLocal(p:GetRealVelocity()+e:GetRealPos()))-g:GetRealPos())
			else
				p:SetLocalVelocity(g:RealLocalToWorld(e:RealWorldToLocal((p:GetRealVelocity()-e:GetRealVelocity())+e:GetRealPos()))-g:GetRealPos())
			end
			local pa = g:RealLocalToWorldAngles(e:RealWorldToLocalAngles(p:EyeAngles()))
			p:SetEyeAngles(pa)
			p.SLRollFix = true
			if IsValid(p.RocketHax) then
				GH.ROCKETHAX[p.RocketHax] = p
				p.RocketHax:SetOwner(NULL)
				p.RocketHax.Attacker = ply
			end
		elseif p:IsNPC() then
			p:SetRealPos(g:RealLocalToWorld(e:RealWorldToLocal(p:GetRealPos()+p:OBBCenter()))-p:OBBCenter())
			p:SetLocalVelocity(g:RealLocalToWorld(e:RealWorldToLocal(p:GetRealVelocity()+e:GetRealPos()))-g:GetRealPos())
		else
			local i
			local pv,pp,pa = {},{},{}
			for i=1,p:GetPhysicsObjectCount() do
				local po = p:GetPhysicsObjectNum(i-1)
				if po:IsValid() then
					if nm == 1 then
						pv[i] = g:RealLocalToWorld(e:RealWorldToLocal(po:GetVelocity()+e:GetRealPos()))-g:GetRealPos()
					else
						pv[i] = g:RealLocalToWorld(e:RealWorldToLocal((po:GetVelocity()-e:GetRealVelocity())+e:GetRealPos()))-g:GetRealPos()
					end
					if (p:GetPhysicsObjectCount() > 1) then
						pp[i] = g:RealLocalToWorld(e:RealWorldToLocal(po:GetPos()))
						pa[i] = g:RealLocalToWorldAngles(e:RealWorldToLocalAngles(po:GetAngle()))
					end
				end
			end
			p:SetRealPos(g:RealLocalToWorld(e:RealWorldToLocal(p:GetRealPos())))
			p:SetAngles(g:RealLocalToWorldAngles(e:RealWorldToLocalAngles(p:GetRealAngles())))
			if p:GetPhysicsObjectCount() > 1 then
				for i=1,p:GetPhysicsObjectCount() do
					local po = p:GetPhysicsObjectNum(i-1)
					if (po:IsValid()) then
						po:SetPos(pp[i])
						po:SetAngle(pa[i])
					end
				end
			end
			for i=1,p:GetPhysicsObjectCount() do
				local po = p:GetPhysicsObjectNum(i-1)
				if po:IsValid() then
					po:SetVelocity(pv[i])
				end
			end
			local pg = GH.PHYSGHOSTS[p]
			if IsValid(p.HeldBy) && p.HeldBy.InShip != e then
				FixMass(p)
				GH.PhysGhost(e,p).Expire = CurTime()+0.5
				p.HeldBy:Freeze(true)
				local phb = p.HeldBy
				timer.Simple(0.02,function() phb:Freeze(false) end)
			elseif IsValid(pg) && IsValid(pg.HeldBy) && pg.HeldBy.InShip == e then
				FixMass(pg)
				GH.DisablePhysGhost(p,pg)
				pg.HeldBy:Freeze(true)
				local phb = pg.HeldBy
				timer.Simple(0.02,function() phb:Freeze(false) end)
			end
		end
	end
	GH.ShipObject(p,true,false,e,g)
	if GH.Transition[p:GetClass()] then GH.Transition[p:GetClass()](p,e,g,oldpos,oldang) end
	hook.Call("EnterShip",nil,p,e,g,oldpos,oldang)
end
------------------------------------------------------------------------------------------
-- Name: ShipSpit
-- Desc: Remove an entity from a ship.
------------------------------------------------------------------------------------------
function GH.ShipSpit(e,p,nm,nog,nt)
	if !GH.SHIPS[e] then return end
	local g = GH.SHIPS[e].MainGhost
	if !IsValid(p) then return end
	if p.SLIsGhost then return end
	GH.SHIPS[e].Contents[p] = nil
	local oldpos,oldang = p:GetRealPos(),p:GetRealAngles()
	if p:IsPlayer() then
		if IsValid(p.Holding) then
			FixMass(p.Holding)
			p:Freeze(true)
			timer.Simple(0.02,function() p:Freeze(false) end)
		end
		p:SetGravity(p.OldGravity)
		p.OldGravity = nil
		local ppos,pang = WorldToLocal(p:GetRealPos()+p:OBBCenter(), p:EyeAngles(), g:GetRealPos(), g:GetRealAngles())
		ppos,pang = LocalToWorld(ppos,pang,e:GetPos(),e:GetAngles())
		ppos = util.TraceLine{start = ppos, endpos = ppos+Vector(0,0,p:OBBMaxs().z)}.HitPos-Vector(0,0,p:OBBMaxs().z)
		ppos = util.TraceLine{start = ppos, endpos = ppos-p:OBBCenter()}.HitPos
		p.InShip = nil
		p:SetPos(ppos)
		if !nt then
			GH.AntiTeleport(p,ppos)
		end
		local pvel = WorldToLocal(p:GetRealVelocity(),Angle(0,0,0),vector_origin,g:GetRealAngles())
		pvel = LocalToWorld(pvel,Angle(0,0,0),vector_origin,e:GetAngles())
		p:SetLocalVelocity(pvel+e:GetVelocity())
		p:SetEyeAngles(pang)
		p.SLRollFix = true
	elseif p:IsNPC() then
		p:SetRealPos(e:LocalToWorld(g:WorldToLocal(p:GetRealPos()+p:OBBCenter()))-p:OBBCenter())
	else
		local i
		local pv,pp,pa = {},{},{}
		for i=1,p:GetPhysicsObjectCount() do
			local po = p:GetPhysicsObjectNum(i-1)
			if po:IsValid() then
				pv[i] = e:RealLocalToWorld(g:RealWorldToLocal(po:GetVelocity()+g:GetRealPos()))-e:GetRealPos()
				if (p:GetPhysicsObjectCount() > 1) then
					pp[i], pa[i] = WorldToLocal(po:GetPos(),po:GetAngle(),g:GetRealPos(),g:GetRealAngles())
					pp[i], pa[i] = LocalToWorld(pp[i], pa[i], e:GetPos(), e:GetAngles())
				end
			end
		end
		local ppos,pang = WorldToLocal(p:GetRealPos(),p:GetRealAngles(),g:GetRealPos(),g:GetRealAngles())
		ppos,pang = LocalToWorld(ppos,pang,e:GetPos(),e:GetAngles())
		p:SetRealPos(ppos)
		p:SetAngles(pang)
		if p:GetPhysicsObjectCount() > 1 then
			for i=1,p:GetPhysicsObjectCount() do
				local po = p:GetPhysicsObjectNum(i-1)
				if (po:IsValid()) then
					po:SetPos(pp[i])
					po:SetAngle(pa[i])
				end
			end
		end
		for i=1,p:GetPhysicsObjectCount() do
			local po = p:GetPhysicsObjectNum(i-1)
			if po:IsValid() then
				po:SetVelocity(pv[i]+e:GetVelocity())
			end
		end
		if !nog then
			local pg = GH.PHYSGHOSTS[p]
			if IsValid(p.HeldBy) && p.HeldBy.InShip == e then
				FixMass(p)
				p.InShip = nil
				GH.PhysGhost(e,p).Expire = CurTime()+0.5
				p.HeldBy:Freeze(true)
				local phb = p.HeldBy
				timer.Simple(0.02,function() phb:Freeze(false) end)
			elseif IsValid(pg) && IsValid(pg.HeldBy) && !pg.HeldBy.InShip then
				FixMass(pg)
				GH.DisablePhysGhost(p,pg)
				pg.HeldBy:Freeze(true)
				local phb = pg.HeldBy
				timer.Simple(0.02,function() phb:Freeze(false) end)
			end
		end
	end
	p.InShip = nil
	if IsValid(e.InShip) and GH.SHIPS[e.InShip] then
		GH.ShipEat(e.InShip,p)
	else
		local do_send = true
		for ent,d in pairs(GH.SHIPS) do --check for other cantidates
			ent.SLLastFind[#ent.SLLastFind+1] = p --tell every ship that we MIGHT be near them
			if e != ent and GH.TryEat(ent,p,d) then
				do_send = false
				break
			end
		end
		if do_send then
			GH.ShipObject(p,false,false)
		end
	end
	if GH.Transition[p:GetClass()] then GH.Transition[p:GetClass()](p,g,e,oldpos,oldang) end
	hook.Call("ExitShip",nil,p,e,g,oldpos,oldang)
end
local NotRagdolls = {}
function GH.IsRagdoll(p)
	if NotRagdolls[p:GetClass()] then return false end
	if p:GetPhysicsObjectCount() <= 1 then return false end
	if p:IsVehicle() then return false end
	return true
end
local function GhostDelete(ent)
	local re = ent.SLMyGhost
	GH.PHYSGHOSTS[re] = nil
	if IsValid(re) then
		re.SLMyGhost = nil
		re.SLHull = nil
	end
end
local dont_ghost = kv_swap{"sbep_elev_system","func_physbox"}
hook.Add("CanPhysghost","BrokenGhosts",function(ent,p)
	if dont_ghost[p:GetClass()] then return false end
end)
------------------------------------------------------------------------------------------
-- Name: PhysGhost
-- Desc: Create a Physghost for a prop.
------------------------------------------------------------------------------------------
function GH.PhysGhost(ent,p)
	if ent == p then return {} end
	if p.SLIsGhost then return {} end
	local data = GH.SHIPS[ent]
	if !(IsValid(p) and IsValid(ent) and !p:IsPlayer() and !p:IsNPC() and !ent.MyShip and ent:GetMoveType() == MOVETYPE_VPHYSICS and data and hook.Call("CanPhysghost",nil,ent,p) != false) then return {} end
	if p.InShip == ent then --inside, make a physghost outside
		local mg = data.MainGhost
		if !IsValid(mg) then return {} end
		if !IsValid(p.SLMyGhost) then p.SLMyGhost = nil end
		local g = p.SLMyGhost or (GH.IsRagdoll(p) and ents.Create("prop_ragdoll") or ents.Create("prop_physics"))
		g.InShip = nil
		g:SetRealPos(ent:RealLocalToWorld(mg:RealWorldToLocal(p:GetRealPos())))
		local i
		g:SetAngles(ent:RealLocalToWorldAngles(mg:RealWorldToLocalAngles(p:GetRealAngles())))
		g:SetModel(p:GetModel())
		p:DeleteOnRemove(g)
		g:CallOnRemove("GhostDelete",GhostDelete,g)
		p.SLHull = mg
		g.SLHull = ent
		g.SLIsGhost = true
		if IsValid(p:GetPhysicsAttacker()) then
			g:SetPhysicsAttacker(p:GetPhysicsAttacker())
		end
		g:SetOwner(p:GetOwner())
		g.Owner = p.Owner
		g.Spawner = p.Spawner
		if !p.SLMyGhost then g:Spawn() end
		p.SLMyGhost = g
		g.SLMyGhost = p
		g:SetSolid(p:GetSolid())
		g:SetMoveType(p:GetMoveType())
		g:SetCollisionGroup(p:GetCollisionGroup())
		if p:GetPhysicsObjectCount() > 1 then
			for i=1,p:GetPhysicsObjectCount() do
				local po = p:GetPhysicsObjectNum(i-1)
				local gp = g:GetPhysicsObjectNum(i-1)
				if (gp && po && gp:IsValid() && po:IsValid()) then
					gp:SetPos(ent:RealLocalToWorld(mg:WorldToLocal(po:GetPos())))
					gp:SetAngle(ent:RealLocalToWorldAngles(mg:WorldToLocalAngles(po:GetAngle())))
				end
			end
		end
		for i=1,p:GetPhysicsObjectCount() do
			local po = p:GetPhysicsObjectNum(i-1)
			local gp = g:GetPhysicsObjectNum(i-1)
			if gp && po && gp:IsValid() && po:IsValid() then
				gp:EnableGravity(false)
				gp:EnableCollisions(true)
				gp:EnableMotion(po:IsMoveable())
			end
		end
		g:SetRenderMode(RENDERMODE_NONE)
		g:DrawShadow(false)
		GH.PHYSGHOSTS[p] = g --register as a physghost
		hook.Call("OnCreatePhysghost",nil,ent,p,g)
		return g
	else --outside, make a physghost inside
		local mg = data.MainGhost
		if !IsValid(mg) then return {} end
		if !IsValid(p.SLMyGhost) then p.SLMyGhost = nil end
		local g = p.SLMyGhost or (GH.IsRagdoll(p) and ents.Create("prop_ragdoll") or ents.Create("prop_physics"))
		g:SetPos(mg:LocalToWorld(ent:RealWorldToLocal(p:GetRealPos())))
		local i
		g:SetAngles(mg:LocalToWorldAngles(ent:RealWorldToLocalAngles(p:GetRealAngles())))
		g:SetModel(p:GetModel())
		p:DeleteOnRemove(g)
		g:CallOnRemove("GhostDelete",GhostDelete,g)
		p.SLHull = ent
		g.SLHull = mg
		g.SLIsGhost = true
		if !p.SLMyGhost then g:Spawn() end
		p.SLMyGhost = g
		g.SLMyGhost = p
		if IsValid(p:GetPhysicsAttacker()) then
			g:SetPhysicsAttacker(p:GetPhysicsAttacker())
		end
		g:SetOwner(p:GetOwner())
		g.Owner = p.Owner
		g.Spawner = p.Spawner
		g:SetSolid(p:GetSolid())
		g:SetMoveType(p:GetMoveType())
		g:SetCollisionGroup(p:GetCollisionGroup())
		g:SetRenderMode(RENDERMODE_NONE)
		g:DrawShadow(false)
		if p:GetPhysicsObjectCount() > 1 then
			for i=1,p:GetPhysicsObjectCount() do
				local po = p:GetPhysicsObjectNum(i-1)
				local gp = g:GetPhysicsObjectNum(i-1)
				if (gp && po && gp:IsValid() && po:IsValid()) then
					gp:SetPos(mg:RealLocalToWorld(ent:RealWorldToLocal(po:GetPos())))
					gp:SetAngle(mg:RealLocalToWorldAngles(ent:RealWorldToLocalAngles(po:GetAngle())))
				end
			end
		end
		for i=1,p:GetPhysicsObjectCount() do
			local po = p:GetPhysicsObjectNum(i-1)
			local gp = g:GetPhysicsObjectNum(i-1)
			if gp && po && gp:IsValid() and po:IsValid() then
				gp:EnableGravity(false)
				gp:EnableCollisions(true)
				gp:EnableMotion(po:IsMoveable())
			end
		end
		g.InShip = ent
		GH.PHYSGHOSTS[p] = g --register as a physghost
		hook.Call("OnCreatePhysghost",nil,ent,p,g)
		return g
	end
end
local ShipVol_MinRadius = 130
local ShipVol_Res = 30
local OBBPadding = 8
function GetCorners(p)
	local a,b,c,o = p:OBBMins(),p:OBBMaxs(),p:OBBCenter(),OBBPadding
	if math.abs(b.z-a.z) < ShipVol_MinRadius then
		return {
			Vector(a.x+o,a.y+o,c.z),
			Vector(b.x-o,a.y+o,c.z),
			Vector(b.x-o,b.y-o,c.z),
			Vector(a.x+o,b.y-o,c.z),
			Vector(b.x-o,b.y-o,c.z),
		}
	else
		return {
			a,//or(a.x,a.y,a.z),
			Vector(b.x-o,a.y+o,a.z+o),
			Vector(b.x-o,b.y-o,a.z+o),
			Vector(a.x+o,b.y-o,a.z+o),
			Vector(b.x-o,b.y-o,a.z+o),
			Vector(b.x-o,a.y+o,b.z-o),
			Vector(b.x-o,b.y-o,b.z-o),
			Vector(a.x+o,b.y-o,b.z-o),
			Vector(b.x-o,b.y-o,b.z-o),
			b,//or(b.x,b.y,b.z),
		}
	end
end
------------------------------------------------------------------------------------------
-- Name: EntInShip
-- Desc: Check if the entity is in the ship by performing several PointInShip calls
------------------------------------------------------------------------------------------
function GH.EntInShip(e,p,_ie)
	local data = GH.SHIPS[e]
	local ie = _ie or e
	if !(IsValid(e) and data and IsValid(p)) then return end
	local obc = LocalToWorld(p:OBBCenter(),Angle(0,0,0),vector_origin,p:GetRealAngles())
	local out = false
	if p.InShip == e then
		out = GH.PointInShip(e,data.MainGhost:RealWorldToLocal(p:GetRealPos()+obc))
	else
		out = GH.PointInShip(e,ie:RealWorldToLocal(p:GetRealPos()+obc))
	end
	if out and !GH.IsRagdoll(p) and p:BoundingRadius() > ShipVol_MinRadius then
		p.SLCorners = p.SLCorners or GetCorners(p)
		for _,v in pairs(p.SLCorners) do
			local pos,ang = LocalToWorld(v,Angle(0,0,0),vector_origin,p:GetRealAngles())
			if p.InShip == e then
				out = GH.PointInShip(e,data.MainGhost:RealWorldToLocal(p:GetRealPos()+pos))
			else
				out = GH.PointInShip(e,ie:RealWorldToLocal(p:GetRealPos()+pos))
			end
			if !out then break end
		end
	end
	return out
end
------------------------------------------------------------------------------------------
-- Name: PointInShip
-- Desc: Determine if a point is inside a ship, uses traces and a volume map
------------------------------------------------------------------------------------------
function GH.PointInShip(e,iv)
	local data = GH.SHIPS[e]
	local mg = data.MainGhost
	local v = iv - mg:OBBCenter()
	if !(IsValid(e) and data) then return end
	local lv = Vector(math.Round(v.x/ShipVol_Res),math.Round(v.y/ShipVol_Res),math.Round(v.z/ShipVol_Res))
	local key = lv.x .. ' ' .. lv.y .. ' ' .. lv.z
	if (data.Volume[key] == nil) then
		local wv = mg:RealLocalToWorld(mg:OBBCenter()+(lv*ShipVol_Res))
		local filt = {}
		table.Add(filt,data.Contents)
		table.Add(filt,GH.PHYSGHOSTS)
		local floortr = util.RealTraceLine{start = wv, endpos = wv-Vector(0,0,data.Radius*2), filter = filt}
		if data.Ghosts[floortr.Entity] then -- FLOOR
			if floortr.HitPos:Distance(floortr.StartPos) > data.FloorDist then
				local otherdirs = {
					Vector(0,0,data.Radius*2), --up
					Vector(-data.Radius*2,0,0), --left
					Vector(data.Radius*2,0,0), --right
					Vector(0,-data.Radius*2,0), --back
					Vector(0,data.Radius*2,0) -- forward
				}
				for _,od in pairs(otherdirs) do
					if data.Ghosts[util.TraceLine({start = wv, endpos = wv+od, filter = filt},true).Entity] then -- WALL OR CEILING = YEP
						data.Volume[key] = true
						return true
					end
				end
			else
				data.Volume[key] = true
				return true
			end
		end
		data.Volume[key] = false
		return false
	else
		return data.Volume[key]
	end
end
------------------------------------------------------------------------------------------
-- Name: DisablePhysGhost
-- Desc: Remove a Physghost without destroying it.
------------------------------------------------------------------------------------------
function GH.DisablePhysGhost(p,g)
	if IsValid(p) and IsValid(g) and g.SLIsGhost then
		g:SetSolid(SOLID_NONE)
		g:SetMoveType(MOVETYPE_NONE)
		GH.PHYSGHOSTS[p] = nil
	end
end
------------------------------------------------------------------------------------------
-- Name: GetExteriorEyeTrace
-- Desc: Determine what a player would be looking at were they not in a ship
------------------------------------------------------------------------------------------
function GH.GetExteriorEyeTrace(p)
	if !p:IsPlayer() then return {} end
	if !(IsValid(p.InShip) and GH.SHIPS[p.InShip]) then return p:RealEyeTrace() end
	local ship = p.InShip
	local ghost = GH.SHIPS[ship].MainGhost
	--do the actual trace now
	if !(IsValid(ghost) && IsValid(ship)) then return {} end
	local strt = ship:RealLocalToWorld(ghost:RealWorldToLocal(p:EyePos()))
	local endp = ship:RealLocalToWorld(ghost:RealWorldToLocal(p:EyePos()+p:RealAimVector()*4096))
	return util.TraceLine{start = strt, endpos = endp, filter = p}
end
------------------------------------------------------------------------------------------
-- Name: GetInteriorEyeTrace
-- Desc: Determine what a player would be looking at were they in a ship
------------------------------------------------------------------------------------------
function GH.GetInteriorEyeTrace(e,p)
	if !(IsValid(e) and GH.SHIPS[e] and p:IsPlayer()) then return {} end
	local ghost = GH.SHIPS[e].MainGhost
	--do the actual trace now
	if !(IsValid(ghost) && IsValid(e)) then return {} end
	local strt = p:EyePos()
	local endp = p:EyePos()+p:RealAimVector()*4096
	if p.InShip != e then 
		strt = WorldToLocal(strt,Angle(0,0,0),e:GetPos(),e:GetAngles())
		strt = ghost:RealLocalToWorld(strt)
		endp = WorldToLocal(endp,Angle(0,0,0),e:GetPos(),e:GetAngles())
		endp = ghost:RealLocalToWorld(endp)
	end
	return util.TraceLine{start = strt, endpos = endp, filter = p}
end
hook.Add("SetupPlayerVisibility","SLShipVis",function(ply)
xpcall(function()
	if IsValid(ply.InShip) then
		AddOriginToPVS(ply:GetPos())
	end
	for e,dat in pairs(GH.SHIPS) do
		if IsValid(dat.MainGhost) then
			AddOriginToPVS(dat.MainGhost:GetRealPos())
		end
		if IsValid(e) and e:WaterLevel() > 1 then
			AddOriginToPVS(e:GetPos())
		end
	end
end,ErrorNoHalt)
end)
--BULLET INFLICTOR FIXES
hook.Add("EntityTakeDamage","SLInflictorFix",function(ent,dmg)
	local inf = dmg:GetInflictor()
	if inf.Inflictor then dmg:SetInflictor(inf.Inflictor) end
	if inf.Attacker then dmg:SetAttacker(inf.Attacker) end
end)
local nexttick = 0
local numticks = 0
local a0 = Angle(0,0,0)
local ignore_in_contraption = kv_swap{
	"gmod_thruster","gmod_hoverball","gmod_turret"
}
------------------------------------------------------------------------------------------
-- Name: ShouldEat
-- Desc: return whether an entity is even a cantidate for being put in a ship the normal way.
------------------------------------------------------------------------------------------
function GH.ShouldEat(ent,p,data)
	return !(!IsValid(p) or p.InShip == ent or p.MyShip == ent or data.Hull[p] or data.Welds[p] or p:IsWorld() or p.SLIsGhost or p.SLLastTick[ent] == numticks or p == GH.BulletGhost or
			p:GetMoveType() == MOVETYPE_NONE or !p:GetPhysicsObject():IsValid() or p:GetPhysicsObject():IsAsleep() or !p:GetPhysicsObject():IsMoveable() or IsValid(p:GetParent()) or
			(p:IsPlayer() and !p:Alive()))
end
------------------------------------------------------------------------------------------
-- Name: TryEat
-- Desc: Eat an object into a ship if it's inside the hull boundaries.
------------------------------------------------------------------------------------------
function GH.TryEat(ent,p,data)
	local out = false
	if MapRepeat and !MapRepeat.SameCell(ent,p) then return false end
	if type(p.SLLastTick) != 'table' then p.SLLastTick = {} end
	if GH.ShouldEat(ent,p,data) then
		if p:IsConstrained() then --ENTIRE CONTRAPTIONS MUST BE MOVED ALL AT ONCE
			local pcon = GH.ConstrainedEntities(p)
			local doit = true
			local isship = false
			for _,con in pairs(pcon) do
				con.SLLastTick = con.SLLastTick or {}
				con.SLLastTick[ent] = numticks
				if con==ent or (doit and !ignore_in_contraption[con:GetClass()] and !GH.EntInShip(ent,con)) then 
					doit = false
				end
			end
			if doit then
				for _,con in pairs(pcon) do
					GH.ShipEat(ent,con) --do it all at once
					out = true
				end
			end
		elseif GH.EntInShip(ent,p) then --If the ent is physically in the ship
			GH.ShipEat(ent,p) --teleport it to the clone
			out = true
		end
		p.SLLastTick[ent] = numticks
	end
	return out
end
------------------------------------------------------------------------------------------
-- Name: TrySpit
-- Desc: Spit an object out of a ship if it's not inside the hull boundaries.
------------------------------------------------------------------------------------------
function GH.TrySpit(k,ent,p,data)
	if IsValid(p) and p.InShip == ent and !p.SLIsGhost and p != GH.BulletGhost then
		if p:IsPlayer() and !p:Alive() then
			GH.ShipSpit(ent,p) --SPIT OUT ALL THE DEAD PEOPLE O.o
		elseif !p:GetPhysicsObject():IsValid() or (!p:GetPhysicsObject():IsAsleep() and p:GetPhysicsObject():IsMoveable()) and p.SLLastInTick != numticks then --either doesn't have a physobj or its physobj is awake and unfrozen
			if p:IsConstrained() then --ENTIRE CONTRAPTIONS MUST BE MOVED ALL AT ONCE
				local pcon = GH.ConstrainedEntities(p)
				local doit = false
				local isship = false
				for _,con in pairs(pcon) do
					con.SLLastInTick = numticks
					if con.MyShip then isship = true end
					if !isship and !doit and !ignore_in_contraption[con:GetClass()] and !GH.EntInShip(ent,con) then --something is sticking out
						doit = true
					end
				end
				if doit and !isship then
					for _,con in pairs(pcon) do
						GH.ShipSpit(ent,con) --all at once.
					end
				end
			elseif !GH.EntInShip(ent,p) then
				GH.ShipSpit(ent,p)
			end
		end
		p.SLLastInTick = numticks
	end
end
------------------------------------------------------------------------------------------
-- Name: PhysGhostTick
-- Desc: Process a physghost pair.
------------------------------------------------------------------------------------------
function GH.PhysGhostTick(p,g)
	if IsValid(p) and IsValid(g) then
		if g.Expire and !g.Permanent and CurTime() > g.Expire then --obai mr ghost (we'll let him live in case we need him again)
			GH.DisablePhysGhost(p,g)
		else
			--calculate stuff
			local ph,gh = p.SLHull,g.SLHull
			if (IsValid(ph) && IsValid(gh)) then
				--do stuff
				local gbang = gh:RealLocalToWorldAngles(ph:RealWorldToLocalAngles(p:GetRealAngles()))
				local gbpos = gh:RealLocalToWorld(ph:RealWorldToLocal(p:GetRealPos()))
				local i
				for i=1,p:GetPhysicsObjectCount() do
					local pp,gp = p:GetPhysicsObjectNum(i-1),g:GetPhysicsObjectNum(i-1)
					local gpos = gh:RealLocalToWorld(ph:RealWorldToLocal(pp:GetPos()))
					local gang = gh:RealLocalToWorldAngles(ph:RealWorldToLocalAngles(pp:GetAngles()))
					if pp and gp and pp:IsValid() and gp:IsValid() then
						local gvel = pp:LocalToWorld(gp:WorldToLocal(gp:GetVelocity()+gp:GetPos()))-pp:GetPos()
						if (gp:IsMoveable() && !pp:IsMoveable()) then pp:EnableMotion(true) end
						if (IsValid(g.HeldBy) and g.HeldBone == i-1) or gp:HasGameFlag(4) then --safe to assume it's being physgunned-- that means we obey the ghost
							/*if (gp:GetMass() < 500) then --if its mass is low enough that it moves too slow
								g.OldBoneMass = gp:GetMass() --record the old mass
								gp:SetMass(500) --change the mass to something draggable
								g.FixBoneMass = g.HeldBone --and tell the "let go" hook to fix it later
							end*/
							gp:EnableCollisions(true)
							pp:SetVelocity((gp:GetPos() - gpos) + gvel) --apply vel changes to the nonghost
							pp:AddAngleVelocity(vector_origin-pp:GetAngleVelocity()) --nullify angular velocity
							pp:AddAngleVelocity(gp:GetAngleVelocity()) --inherit ghost's angvel
							gp:AddAngleVelocity(vector_origin-gp:GetAngleVelocity()) --nullify ghost's angvel
							g.Expire = CurTime()+0.5
						else --freely moving, so obey the nonghost
							g:SetRealPos(gbpos) --update the base location
							gp:SetVelocity(pp:GetVelocity())
							gp:SetPos(gpos) --update the ghost's location
							if p.InShip then
								gp:EnableCollisions(false)
							end
							gp:AddAngleVelocity(vector_origin-gp:GetAngleVelocity())
							gp:AddVelocity(vector_origin) --nullify the ghosts's velocity to avoid spazz
						end
						--NO SLEEPING KTHX
						pp:Wake()
						gp:Wake()
						pp:SetMass(gp:GetMass()) --make sure this thing feels like it's in a physgun
						gp:SetPos(gpos) --update the bone's location
						gp:SetAngles(gang) --update the bone's angles
					end
				end
				g:SetMaxHealth(10000)
				g:SetHealth(10000) --don't let it explode
				g:SetRealPos(gbpos) --update the ghost's location
				g:SetAngles(gbang) --update the ghost's angles
				g:SetRenderMode(RENDERMODE_NONE)
			end
		end
	else
		GH.PHYSGHOSTS[p] = nil
	end
end
------------------------------------------------------------------------------------------
-- Name: PlayerEyeGhosts
-- Desc: Summons physghosts for any illusionary object the player is looking at.
------------------------------------------------------------------------------------------
function GH.PlayerEyeGhosts(p)
	local e = GH.GetExteriorEyeTrace(p).Entity
	if IsValid(p.InShip) and IsValid(e) and !(e.MyShip == p.InShip or e.InShip == p.InShip or GH.SHIPS[p.InShip].Welds[e] or e:IsWorld() or e:IsNPC()) then
		if IsValid(GH.PHYSGHOSTS[e]) && GH.PHYSGHOSTS[e].InShip == p.InShip then
			GH.PHYSGHOSTS[e].Expire = CurTime()+0.5
		else
			GH.PhysGhost(p.InShip,e).Expire = CurTime()+0.5 
		end
	elseif IsValid(e) and IsValid(e.Ghost) and IsValid(e.Ghost.MyShip) and GH.SHIPS[e.Ghost.MyShip] and p.InShip != e.Ghost.MyShip then
		local ph = e.Ghost.MyShip
		local ie = GH.GetInteriorEyeTrace(ph,p).Entity --lol it says php and the variable is IE, what a coincidence
		if IsValid(ie) and ie.InShip == ph and !(ie.SLIsGhost and ie.SLMyGhost.InShip == p.InShip) then
			if IsValid(GH.PHYSGHOSTS[ie]) && GH.PHYSGHOSTS[ie].InShip == ph then
				GH.PHYSGHOSTS[ie].Expire = CurTime()+0.5
			else
				GH.PhysGhost(ie.InShip,ie).Expire = CurTime()+0.5
			end
		end
	elseif IsValid(p.InShip) then
		local ph = p.InShip
		local ie = GH.GetInteriorEyeTrace(ph,p).Entity
		if IsValid(ie) and ie.InShip == ph then
			if IsValid(GH.PHYSGHOSTS[ie]) && GH.PHYSGHOSTS[ie].InShip == ph then
				GH.PHYSGHOSTS[ie].Expire = CurTime()+0.5
			else
				GH.PhysGhost(ie.InShip,ie).Expire = CurTime()+0.5
			end
		end
	end
end
------------------------------------------------------------------------------------------
-- Name: RocketFly
-- Desc: Manually sets the velocities of rpg_missiles so they obey external aim.
------------------------------------------------------------------------------------------
function GH.RocketFly(r,p)
	if !(IsValid(r) and IsValid(p)) then GH.ROCKETHAX[r] = nil; return end
	local tr = util.TraceLine{start = p:GetShootPos(), endpos = p:GetShootPos() + p:GetAimVector()*16384, filter = {r,p}}
	local dst = tr.HitPos - tr.HitNormal
	if r.InShip and GH.SHIPS[r.InShip] then
		dst = GH.SHIPS[r.InShip].MainGhost:LocalToWorld(r.InShip:WorldToLocal(dst))
	end
	local nrm = (dst - r:GetRealPos()):Normalize()
	local ang = r:GetRealAngles()
	local nang = nrm:Angle()
	ang.p = math.ApproachAngle(ang.p,nang.p,(nang.p-ang.p)/8)
	ang.y = math.ApproachAngle(ang.y,nang.y,(nang.y-ang.y)/8)
	ang.r = math.ApproachAngle(ang.r,nang.r,(nang.r-ang.r)/8)
	r:SetAngles(ang)
	r:SetVelocity(r:GetForward()*1500-r:GetVelocity())
end
------------------------------------------------------------------------------------------
-- Name: SLShipTick
-- Desc: Think hook that handles hulls and physghosts
------------------------------------------------------------------------------------------
hook.Add("Think","SLShipTick",function()
xpcall(function()
	--external physghost summoning
	for _,p in pairs(player.GetAll()) do
		GH.PlayerEyeGhosts(p)
	end
	--update the physghosts
	for p,g in pairs(GH.PHYSGHOSTS) do
		--check stuff
		GH.PhysGhostTick(p,g)
	end
	--hax the rockets
	for r,p in pairs(GH.ROCKETHAX) do
		GH.RocketFly(r,p)
	end
	--scary discovery stuff hurr durr
	if CurTime() > nexttick then
		numticks = (numticks > 4 and 0 or numticks + 1)
		nexttick = CurTime()+0.2
		for ent,data in pairs(GH.SHIPS) do
			if IsValid(ent) and IsValid(data.MainGhost) then
				if numticks == 3 then
					if table.Count(data.Welds) != table.Count(GH.ConstrainedEntities(ent)) then
						GH.UpdateHull(ent) --reconstruct the ghosts if any constraints are changed
					end
				end
				local pos,rad = ent:RealLocalToWorld(data.Center),data.Radius
				ent.SLLastFind = (numticks > 0 and ent.SLLastFind or ents.RealFindInSphere(pos,rad+300))
				for _,p in pairs(ent.SLLastFind) do
					GH.TryEat(ent,p,data)
				end
				for k,p in pairs(data.Contents) do
					GH.TrySpit(k,ent,p,data)
				end
			end
		end
	end
end,ErrorNoHalt)
end)
------------------------------------------------------------------------------------------
-- Name: SLSpawn
-- Desc: Hook for created entities to automatically place them in the right hull/cell
------------------------------------------------------------------------------------------
local function SLSpawn(ent,two)
xpcall(function()
	if !IsValid(ent) then return end
	ent:SetCustomCollisionCheck(true)
	if ent.SLIsGhost then return end
	local ply = ent:GetOwner()
	if !IsValid(ply) then ply = ent:GetPhysicsAttacker() end
	if !IsValid(ply) then ply = ent.Owner or ent.Spawner end
	if !IsValid(ply) then ply = ((ent.Constraints||{})[1]||{}).Ent2 end --extremely hacky way to find prop spawner parent
	if !IsValid(ply) then ply = (((ent.OnDieFunctions||{}).GetCountUpdate||{}).Args||{})[1] end --extremely hacky way to find out who spawned this
	if ent:GetClass() == "rpg_missile" and IsValid(ply) then
		ply.RocketHax = ent
	end
	if IsValid(ply) and MapRepeat then
		if !ply.Cells then MapRepeat.SetCell(ply,"0 0 0") end
		MapRepeat.SetCell(ent,ply.Cells[1])
	elseif MapRepeat and ent:IsWeapon() then
		print(ent)
		MapRepeat.ClaimWep(ent)
	end
	if IsValid(ply) and GH.SHIPS[ply.InShip or ply.MyShip] then
		local ship = (ply.InShip or ply.MyShip)
		//if GH.EntInShip(
		if GH.EntInShip(ship,ent) then
			local ea = ent:GetAngles()
			GH.ShipEat(ship,ent,NO_VEL)
			if ent:GetClass() == "prop_physics" then
				ent:SetAngles(ea)
			end
		elseif IsValid(ent:GetOwner()) then
			GH.ShipEat(ship,ent,true)
		end
	elseif !two then
		timer.Simple(0,function() SLSpawn(ent,true) end)
	end
end,ErrorNoHalt)
end
hook.Add("OnEntityCreated","SLSpawn",SLSpawn)
------------------------------------------------------------------------------------------
-- Vehicle Hooks
-- Desc: Hook vehicles and provide needed functionality
------------------------------------------------------------------------------------------
hook.Add("CanPlayerEnterVehicle","SLVehicleEnterFix",function(ply,car)
	if (ply.InShip && !car.InShip) then
		GH.ShipSpit(ply.InShip,ply)
	end
end)
hook.Add("PlayerLeaveVehicle","SLVehicleFix",function(ply,car)
	if (car.InShip && !ply.InShip) then
		GH.ShipEat(car.InShip,ply,true)
	end
end)
------------------------------------------------------------------------------------------
-- Name: SLDeath
-- Desc: Remove dead players from ships
------------------------------------------------------------------------------------------
hook.Add("PlayerDeath","SLDeath",function(ply)
	if (IsValid(ply) && IsValid(ply.InShip)) then
		xpcall(GH.ShipSpit,ErrorNoHalt,ply.InShip,ply)
	end
end)
------------------------------------------------------------------------------------------
-- Physgun/Collision Hooks
-- Desc: Hook the physgun and collision and provide needed functionality
------------------------------------------------------------------------------------------
hook.Add("OnPhysgunFreeze","PhysGhostFreeze",function(wep,phy,ent,ply)
	if (IsValid(ent) && IsValid(ent.SLMyGhost)) then ent.SLMyGhost:GetPhysicsObject():EnableMotion(false) end
end)
hook.Add("PhysgunPickup","NoGrab",function(ply,ent)
	if IsValid(ent) && IsValid(ply) then
		if !IsValid(ply.InShip) then ply.InShip = nil end
		if !IsValid(ent.InShip) then ent.InShip = nil end
		if ply.InShip != ent.InShip then
			return false
		end
		if IsValid(ent.MyShip) and GH.SHIPS[ent.MyShip] then --indicates that it's a ghost hull and shouldn't be moved
			return false
		end
	end
end)
hook.Add("PhysgunPickup","HeldBy",function(ply,ent)
	if IsValid(ent) && IsValid(ply) then
		ent.HeldBy = ply
		ent.HeldBone = ply:RealEyeTrace().PhysicsBone
		if ent:GetPhysicsObjectNum(ent.HeldBone) then
			ent.OldMass = ent:GetPhysicsObjectNum(ent.HeldBone):GetMass()
		end
		ply.Holding = ent
	end
end)
hook.Add("PhysgunDrop","HeldBy",function(ply,ent)
	if IsValid(ent) && IsValid(ply) then
		ent.HeldBy = nil
		ent.HeldBone = nil
		ply.Holding = nil
		if ent.FixBoneMass and ent.OldBoneMass then
			ent:GetPhysicsObjectNum(ent.FixBoneMass):SetMass(ent.OldBoneMass)
		end
	end
end)
hook.Add("CanPlayerUnfreeze","NoUnfreeze",function(ply,ent)
	if ply.InShip != ply:GetEyeTrace(true,true).Entity.InShip then
		return false
	end
	if IsValid(ent.MyShip) and GH.SHIPS[ent.MyShip] then --indicates that it's a ghost hull and shouldn't be moved
		return false
	end
end)
hook.Add("ShouldCollide","SLShipCollide",function(en1,en2)
	local out = nil
xpcall(function()
	if en1 == GH.BulletGhost or en2 == GH.BulletGhost then return end
	if !(en1:IsWorld() or en2:IsWorld()) then
		local e1,e2 = en1,en2
		if IsValid(e1.MyShip) and GH.SHIPS[e1.MyShip] and --ghost hull, should only collide with ghost children.
		!(e2.InShip == e1.MyShip) then --not a ghost child so don't collide, period.
			out = false
			return
		end
		if IsValid(e1.InShip) and GH.SHIPS[e1.InShip] and --ghost child, should only collide with hulls and other children.
		!(e2.MyShip == e1.InShip or e2.InShip == e1.InShip) then --not a ghost child or hull, so don't collide, period.
			out = false
			return
		end
		local e1,e2 = en2,en1
		if IsValid(e1.MyShip) and GH.SHIPS[e1.MyShip] and --ghost hull, should only collide with ghost children.
		!(e2.InShip == e1.MyShip) then --not a ghost child so don't collide, period.
			out = false
			return
		end
		if IsValid(e1.InShip) and GH.SHIPS[e1.InShip] and --ghost child, should only collide with hulls and other children.
		!(e2.MyShip == e1.InShip or e2.InShip == e1.InShip) then --not a ghost child or hull, so don't collide, period.
			out = false
			return
		end
	end
end,ErrorNoHalt)
	return out
end)
------------------------------------------------------------------------------------------
-- Name: SLClientData
-- Desc: Send a newly joining client any usermessages that it missed before
------------------------------------------------------------------------------------------
function SLClientData(ply)
	for ent,data in pairs(GH.SHIPS) do
		for k,v in pairs(data.Ghosts) do
			ply:ShipObject(k,true,true,ent,v)
		end
		for k,v in pairs(data.Contents) do
			ply:ShipObject(v,true,false,ent,data.MainGhost)
		end
	end
end
hook.Add("PlayerInitialSpawn","SLInitialSpawn",SLClientData)