table.Merge(TOOL,{
	Name = "Localized Physics",
	Category = "Construction",
	ClientConVar = {
		floordist = 0,
		gravnormal = 0,
		gravity = 100,
	}
})
if CLIENT then
	language.Add("Tool.localphysics.name", "Localized Physics (Gravity Hull 1.4)!")
	language.Add("Tool.localphysics.desc", "This tool is a (semi)fixed version of Gravity Hull Designator. Intended for developer use only.")
	language.Add("Tool.localphysics.0", "Fire at a prop or entity to create a local physics system. Right click at a prop to remove the system.")
	language.Add("Hint_ghd", "Check your chatbox for instructions.")
else
	concommand.Add("ghd_help",function(p)
		p:SendHint("ghd",0)
		p:ChatPrint("There are enough bugs in this to feed an ant-eater for life.")
		p:ChatPrint("You can help by contributing to the Github of the tool, as I am neither the best or most experienced coder.")
		p:ChatPrint("")
		p:ChatPrint("Use this tool on any surface to create the physics system.")
		p:ChatPrint("If you use it on a box upper surface walk on it. you will notice your weapons becomes invisible. I am trying to fix this.")
		p:ChatPrint("Notice that you will stay relative to the object, including when nocliping and walking.")
		p:ChatPrint("Change the Gravity Percentage slider to define how much gravity pulls on players, NPCs and objects. This version works for NPCs as well!")
	end)
end
function TOOL.BuildCPanel(cp)
	cp:AddControl("Header",{Text = "#Tool.localphysics.name", Description = "#Tool.localphysics.desc"})
	cp:AddControl("Slider",{Label = "Vertical Protrusion Factor", Description = "The minimum distance from the floor that walls or a ceiling is required to keep entities inside the hull.",
	                        Type = "Integer", Min = 0, Max = 300, Command = "localphysics_floordist"})
	cp:AddControl("Checkbox",{Label = "Hit Surface Defines Floor", Description = "If checked, the surface shot by the tool will determine which way 'up' is. Otherwise it counts up as up, meaning your camera will be straight on a diagonal surface.",
							  Command = "localphysics_gravnormal"})
	cp:AddControl("Slider",{Label = "Gravity Percentage", Description = "The percentage of normal gravity to apply to players and objects inside. Works with players and other objects! Works for NPCs.",
							Type = "Integer", Min = 0, Max = 500, Command = "localphysics_gravity"})
	cp:AddControl("Button",{Label = "Help", Description = "Brief help/FAQ", Command = "ghd_help"})
	cp:AddControl("Button",{Label = "Fix Camera", Description = "If you're teleporting to the sky when you enter a ship, click this until it works. Works just like Gravity Hull!", Command = "ghd_fixcamera"})
end
--Designate Hull
function TOOL:LeftClick(tr)
	local ent = tr.Entity
	if CLIENT then return IsValid(ent) and !GravHull.GHOSTHULLS[ent] end
	if !(IsValid(ent) and ent:GetMoveType() == MOVETYPE_VPHYSICS and !GravHull.HULLS[ent]) then return false end
	GravHull.RegisterHull(ent,self:GetClientNumber("floordist"),self:GetClientNumber("gravity"))
	if self:GetClientNumber("gravnormal") > 0 then
		GravHull.UpdateHull(ent,tr.HitNormal)
	else
		GravHull.UpdateHull(ent)
	end
	self:GetOwner():ChatPrint("You created a local physics system!")
	return true
end
--Remove Hull
function TOOL:RightClick(tr)
	local ent = tr.Entity
	if CLIENT then return IsValid(ent) end
	if IsValid(ent) and ent:GetMoveType() == MOVETYPE_VPHYSICS then
		if !GravHull.SHIPS[ent] then
			ent = ent.MyShip or (ent.Ghost and ent.Ghost.MyShip)
		end
	else
		return false
	end
	if !IsValid(ent) then return false end
	self:GetOwner():ChatPrint("You removed a local physics system!")
	GravHull.UnHull(ent)
	return true
end
function TOOL:Reload(tr)
	//idk this is for later
end
function TOOL:Think(tr)
	//idk this is for later
end
