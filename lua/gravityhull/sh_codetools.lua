--Used by the fixed lists to optimize lookup
function kv_swap(tbl)
	local out = {}
	for k,v in pairs(tbl) do
		out[v] = k
	end
	return out
end