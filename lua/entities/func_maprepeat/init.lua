ENT.Base = "base_brush"
ENT.Type = "brush"

function ENT:KeyValue(k,v) -- Get the keyvalues
	self.KV = self.KV or {}
	self.KV[string.lower(k)] = v
end

function ENT:Initialize()
	local kv = self.KV
	self.Dir = string.lower(kv.direction)
	self.In, self.Out = kv["in"] or 0,kv["out"] or 0
	self.Space = kv.space
end

local function MR_Touch(self,ent)
	if ent:GetMoveType() != MOVETYPE_NONE && ent:GetMoveType() != MOVETYPE_PUSH then
		local p = ent:GetRealPos() -- Find old position
		print("old real pos: " .. tostring(p)) -- Print old position
		p[self.Dir] = p[self.Dir] + (self.Out - self.In) -- Get new position
		print("new real pos: " .. tostring(p)) -- Print new position
		if ent:IsPlayer() then
			if ent:InVehicle() then return end -- If it's a player in a vehicle, don't do anything with them.
			local v = ent:GetVelocity() -- Get the velocity
			ent.SkipStart = true -- Ignore touch
			ent:SetRealPos(p) -- Set real position
			GravHull.AntiTeleport(ent,p) -- Anti teleport
			ent:SetLocalVelocity(v) -- Set velocity
		else
			local pv,pp = {},{} -- Make some empty tables
			local i -- Make a variable	
			for i=1,ent:GetPhysicsObjectCount() do -- Find the number of the physics objects
				local po = ent:GetPhysicsObjectNum(i-1) -- Get the physic object numbers
				if po:IsValid() then
					pp[i] = po:RealGetPos() or p:GetRealPos() -- Find old position
					print("old pp["..tostring(i).."]: "..tostring(pp[i])) -- Print old position
					pp[i][self.Dir] = pp[i][self.Dir] + (self.Out - self.In) -- Find new position
					print("new pp["..tostring(i).."]: "..tostring(pp[i])) -- Print new position
					pv[i] = po:GetVelocity() -- Get the velocity
				end
			end
			ent.SkipStart = true -- Ignore touch
			
			local children = ent:GetChildren()
			if(table.Count(children) > 0) then
				for i=1,table.Count(children) do
					if children[i]:IsValid() then
						children[i].SkipStart = true
					end
				end
			end
			
			if ent:IsVehicle() then	ent:RealVSetPos(p) else	ent:SetRealPos(p) end -- Set the position
			for i=1,ent:GetPhysicsObjectCount() do -- Find the number of the physics objects 
				local po = ent:GetPhysicsObjectNum(i-1) -- Get the physics object number
				if po:IsValid() then
					po:RealSetPos(pp[i]) -- Set its position
					po:SetVelocity(pv[i]) -- Set its velocity
				end
			end
		end
		if !(ent.Cells and ent.Cells[1]) then ent.Cells = {"0 0 0"} end -- If no cells, assume cell 0 0 0
		print("old cell: "..ent.Cells[1]) -- Print old cell
		local ct = MapRepeat.CellToArray(ent.Cells[1]) -- Get information from cell
		local i = (self.Dir == 'x' and 1) or (self.Dir == 'y' and 2) or (self.Dir == 'z' and 3) -- Set up direction
		if i then
			ct[i] = ct[i] + (self.In > self.Out and 1 or -1) -- Find which way we're going and add it to the table.
			local ctc = ct[1]..' '..ct[2]..' '..ct[3] -- Find x y and z of the cell
			MapRepeat.SetCell(ent,ctc) -- Set the cell
			
			for i=1,table.Count(ent:GetChildren()) do
				MapRepeat.SetCell(ent:GetChildren()[i],ctc)
			end
			
			print("new cell: "..ctc) -- Print new cell
			if(ent:IsPlayer()) then -- If it's a player changing cells
				for _,wep in pairs(ent:GetWeapons()) do -- Find their weapons
					MapRepeat.SetCell(wep,ctc) -- Set the weapons' cell
				end
			end
			if ent:IsVehicle() and ent:GetDriver() != NULL then -- If it's a vehicle with a driver
				ent:GetDriver().SkipStart = true -- Set the driver to skip teleport
				MapRepeat.SetCell(ent:GetDriver(),ctc) -- Set the driver's cell
				for _,wep in pairs(ent:GetDriver():GetWeapons()) do -- Find the driver's weapons
					MapRepeat.SetCell(wep,ctc) -- Set the weapons' cell
				end
			elseif GravHull and GravHull.SHIPS and GravHull.SHIPS[ent] then -- If it's a GHD
				for k,p in pairs(GravHull.SHIPS[ent].Contents) do -- Find its contents
					MapRepeat.SetCell(p,ctc) -- Set contents' cell
					if p:IsPlayer() then -- If it's a player
						for _,wep in pairs(p:GetWeapons()) do -- Find their weapons
							MapRepeat.SetCell(wep,ctc) -- Set the weapons' cell
						end
					end
				end
			end
		end
		if (MapRepeat.Transition[ent:GetClass()]) then  -- If it's transitioning (Unknown what this is. Could not find any source)
			MapRepeat.Transition[ent:GetClass()](ent,self.Dir,self.In,self.Out) -- Set up the transition
		end
	end
end

local function MR_Teleport(self,ent)
	if ent:GetMoveType() != MOVETYPE_NONE && ent:GetMoveType() != MOVETYPE_PUSH && CurTime() > (ent.NextTeleport or 0) then
		print("TELEPORT "..tostring(ent).." along "..self.Dir .. " by "..tostring(self.In > self.Out and 1 or -1)) -- Print direction
		local sys = GravHull.ConstrainedEntities(ent) -- Get constraints (run through GHD's constraint finder)
		for _,v in pairs(sys) do
			print("Touch: "..tostring(v)) -- Print the touch
			v.NextTeleport = CurTime() + 0.1 -- Set up anti-spam
			MR_Touch(self,v) -- Run Touch
		end
	end
end

function ENT:StartTouch(ent)
	self.NextTouch = CurTime()+0.5 -- Anti-touch spam
	if ent.SkipStart then
		ent.SkipStart = nil -- If skipstart is true, then don't teleport.
		return
	end
	MR_Teleport(self,ent) -- Teleport the entity
end
function ENT:Touch(ent)
	if (self.NextTouch or 0) > CurTime() then return end  -- If the anti-touch spam is in effect, ignore the input
	self.NextTouch = CurTime()+0.5  -- Anti-touch spam
	if ent:GetMoveType() != MOVETYPE_NONE && ent:GetMoveType() != MOVETYPE_PUSH then
		if !ent.MRLastPos then ent.MRLastPos = ent:GetRealPos(); return end
		if (self.In > self.Out and ent:GetRealPos()[self.Dir] > ent.MRLastPos[self.Dir])
		or (self.In < self.Out and ent:GetRealPos()[self.Dir] < ent.MRLastPos[self.Dir]) then
			MR_Teleport(self,ent) -- Teleport the entity
		end
		ent.MRLastPos = ent:GetRealPos() -- Update LastPos
	end
end
