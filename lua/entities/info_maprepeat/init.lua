ENT.Base = "base_point"
ENT.Type = "point"

function ENT:KeyValue(k,v)
	MapRepeat.SetNumber(string.lower(k), tonumber(v))
end
function ENT:Initialize()
	MapRepeat.InstallHooks()
end