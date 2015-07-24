GravHull = {}
local GH = GravHull
if SERVER then
	GH.DebugOverrideCV = CreateConVar("ghd_debugoverrides","1", FCVAR_ARCHIVE)
end

------------------------------------------------------------------------------------------
-- Name: Initialize
-- Desc: Load all other files depending on their file name prefix.
------------------------------------------------------------------------------------------
function GH:Initialize()	
	local Folder = "gravityhull/"
	for k,v in pairs(file.Find(Folder .. "*.lua","LUA")) do
		if v:sub(0,3) == "sv_" then
			if SERVER then
				include(Folder .. v)
			end
		elseif v:sub(0,3) == "sh_" then
			if SERVER then
				AddCSLuaFile(Folder .. v)
			end
			include(Folder .. v)
		elseif v:sub(0,3) == "cl_" then
			if SERVER then
				AddCSLuaFile(Folder .. v)
			else
				include(Folder .. v)
			end
		end
	end
end
GH:Initialize()