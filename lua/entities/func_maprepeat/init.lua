ENT.Base = "base_brush"
ENT.Type = "brush"

function ENT:KeyValue(k,v)
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
		local p = ent:GetRealPos()
		print("old real pos: " .. tostring(p))
		p[self.Dir] = p[self.Dir] + (self.Out - self.In)
		print("new real pos: " .. tostring(p))
		if ent:IsPlayer() then
			if ent:InVehicle() then return end
			local v = ent:GetVelocity()
			ent.SkipStart = true
			ent:SetRealPos(p)
			GravHull.AntiTeleport(ent,p)
			ent:SetLocalVelocity(v)
		else
			local pv,pp = {},{}
			local i
			for i=1,ent:GetPhysicsObjectCount() do
				local po = ent:GetPhysicsObjectNum(i-1)
				if po:IsValid() then
					pp[i] = po:RealGetPos() or p:GetRealPos()
					print("old pp["..tostring(i).."]: "..tostring(pp[i]))
					pp[i][self.Dir] = pp[i][self.Dir] + (self.Out - self.In)
					print("new pp["..tostring(i).."]: "..tostring(pp[i]))
					pv[i] = po:GetVelocity()
				end
			end
			ent.SkipStart = true
			ent:SetRealPos(p)
			for i=1,ent:GetPhysicsObjectCount() do
				local po = ent:GetPhysicsObjectNum(i-1)
				if po:IsValid() then
					po:RealSetPos(pp[i])
					po:SetVelocity(pv[i])
				end
			end
		end
		if !(ent.Cells and ent.Cells[1]) then ent.Cells = {"0 0 0"} end
		print("old cell: "..ent.Cells[1])
		local ct = MapRepeat.CellToArray(ent.Cells[1])
		local i = (self.Dir == 'x' and 1) or (self.Dir == 'y' and 2) or (self.Dir == 'z' and 3)
		if i then
			ct[i] = ct[i] + (self.In > self.Out and 1 or -1)
			local ctc = ct[1]..' '..ct[2]..' '..ct[3]
			MapRepeat.SetCell(ent,ctc)
			print("new cell: "..ctc)
			if ent:IsVehicle() and ent:GetDriver() != NULL then
				ent:GetDriver().SkipStart = true
				MapRepeat.SetCell(ent:GetDriver(),ctc)
				for _,wep in pairs(ent:GetDriver():GetWeapons()) do
					MapRepeat.SetCell(wep,ctc)
				end
			elseif GravHull and GravHull.SHIPS and GravHull.SHIPS[ent] then
				for k,p in pairs(GravHull.SHIPS[ent].Contents) do
					MapRepeat.SetCell(p,ctc)
					if p:IsPlayer() then
						for _,wep in pairs(p:GetWeapons()) do
							MapRepeat.SetCell(wep,ctc)
						end
					end
				end
			end
		end
		if (MapRepeat.Transition[ent:GetClass()]) then 
			MapRepeat.Transition[ent:GetClass()](ent,self.Dir,self.In,self.Out)
		end
	end
end

local function MR_Teleport(self,ent)
	if ent:GetMoveType() != MOVETYPE_NONE && ent:GetMoveType() != MOVETYPE_PUSH && CurTime() > (ent.NextTeleport or 0) then
		print("TELEPORT "..tostring(ent).." along "..self.Dir .. " by "..tostring(self.In > self.Out and 1 or -1))
		local sys = GravHull.ConstrainedEntities(ent)
		for _,v in pairs(sys) do
			print("Touch: "..tostring(v))
			v.NextTeleport = CurTime() + 0.1
			MR_Touch(self,v)
		end
	end
end

function ENT:StartTouch(ent)
	self.NextTouch = CurTime()+0.5
	if ent.SkipStart then
		ent.SkipStart = nil
		return
	end
	MR_Teleport(self,ent)
end
function ENT:Touch(ent)
	if (self.NextTouch or 0) > CurTime() then return end
	self.NextTouch = CurTime()+0.5
	if ent:GetMoveType() != MOVETYPE_NONE && ent:GetMoveType() != MOVETYPE_PUSH then
		if !ent.MRLastPos then ent.MRLastPos = ent:GetRealPos(); return end
		if (self.In > self.Out and ent:GetRealPos()[self.Dir] > ent.MRLastPos[self.Dir])
		or (self.In < self.Out and ent:GetRealPos()[self.Dir] < ent.MRLastPos[self.Dir]) then
			MR_Teleport(self,ent)
		end
		ent.MRLastPos = ent:GetRealPos()
	end
end