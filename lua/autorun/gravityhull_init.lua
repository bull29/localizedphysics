//NOTE: MAP REPEATER IS AN UNSTABLE PROTOTYPE. USE AT YOUR OWN RISK BY UNCOMMENTING THE FOLLOWING LINE:



include("gravityhull/init.lua")
if AllowMapRepeat then include("maprepeat/init.lua") end
if SERVER then
	AddCSLuaFile("gravityhull/init.lua")
	if AllowMapRepeat then AddCSLuaFile("maprepeat/init.lua") end
	AddCSLuaFile("autorun/gravityhull_init.lua")
end