-- client
local cacheManager = {}
local cacheSelector
local pCache, caches, lended
local numCaches, cacheSize
local debrisFolder = workspace:FindFirstChild("Debris")


local function NewPartCacheFolder()
	local f = Instance.new("Folder")

	f.Name = "PartCaches"
	f.Parent = debrisFolder

	return f
end


-- Retrieves a part instance from the cache
-- @returns <BasePart>
function cacheManager:GetPart()
	local i, selectedCache, part

	repeat
		i = cacheSelector:NextInteger(1, numCaches)
		selectedCache = caches[i]
		if selectedCache.num == 0 then 
			selectedCache = nil
		end
	until selectedCache

	part = selectedCache.heap:GetPart()
	lended[part] = i

	return part
end


-- Returns a part instance to the cache
-- @param part <BasePart>
function cacheManager:Cache(part)
	assert(lended[part], 'Attempt to cache non partcache instance')

	caches[lended[part]].heap:ReturnPart(part)	
	lended[part] = nil
end


-- CONFIG
-- Multiple caches so each list is shorter
numCaches = 2
cacheSize = 200

cacheSelector = Random.new()
pCache = require(script.Parent.PartCache)
caches = {}
lended = {}

for i = 1, numCaches do
	caches[i] = {
		heap = pCache.new(
			Instance.new("Part"),
			cacheSize, 
			debrisFolder:FindFirstChild("PartCaches") or NewPartCacheFolder()
		);
		num = cacheSize;
	}
end


return cacheManager
