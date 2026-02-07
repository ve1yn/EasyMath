--!strict
--@author: v_eiyn/ve1yn/veiyn
--@version: 1.0.5


local EasyMath = {}

for _, child in ipairs(script.Parent.Modules:GetChildren()) do
	if child:IsA("ModuleScript") then
		local ok, module = pcall(require, child)

		if ok then
			EasyMath[child.Name] = module
		else
			warn("[EasyMath] Failed to load module:", child.Name, module)
		end
	end
end

return EasyMath
