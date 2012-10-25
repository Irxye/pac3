local L = pace.LanguageString

local PANEL = {}

PANEL.ClassName = "tree"
PANEL.Base = "DTree"

function PANEL:Init()
	DTree.Init(self)

	self:SetLineHeight(18)
	self:SetIndentSize(2)

	self.parts = {}
	
	self:Populate()
	
	pace.tree = self
end

do
	local pnl = NULL

	function PANEL:Think(...)	
		pnl = vgui.GetHoveredPanel() or NULL
				
		if pnl:IsValid() then
			local pnl = pnl:GetParent()
			
			if pnl and pnl.part and pnl.part:IsValid() then
				pace.Call("HoverPart", pnl.part)
			end
		end	
		
				
		if DTree.Think then
			return DTree.Think(self, ...)
		end
	end
end

function PANEL:OnMousePressed(mc)
	if mc == MOUSE_RIGHT then
		pace.Call("NewPartMenu")
	end
end

function PANEL:SetModel(path)
	local pnl = vgui.Create("DModelPanel", self)
		pnl:SetModel(path or "")
		pnl:SetSize(16, 16)
		
		if pnl.Entity and pnl.Entity:IsValid() then
			local mins, maxs = pnl.Entity:GetRenderBounds()
			pnl:SetCamPos(mins:Distance(maxs) * Vector(0.75, 0.75, 0.5) * 15)
			pnl:SetLookAt((maxs + mins) / 2)
			pnl:SetFOV(3)
		end

		pnl.SetImage = function() end
		pnl.GetImage = function() end

	self.Icon:Remove()
	self.Icon = pnl
end

local function install_drag(node)
	node:SetDraggableName("pac3")
	
	function node:OnDrop(child)
		-- we're hovering on the label, not the actual node
		-- so get the parent node instead
		child = child:GetParent().part
		
		if child and child:IsValid() then
			if self.part and self.part:IsValid() then
				self.part:SetParent(child)
			end
		end
		
		return self
	end
end

local function install_expand(node)
	local old = node.SetExpanded
	node.SetExpanded = function(self, b, ...)
		if self.part and self.part:IsValid() then
			self.part:SetEditorExpand(b)
		end
		
		return old(self, b, ...)
	end
end

local fix_folder_funcs = function(tbl) 
	tbl.MakeFolder = function() end
	tbl.FilePopulateCallback = function() end
	tbl.FilePopulate = function() end
	tbl.PopulateChildren = function() end
	tbl.PopulateChildrenAndSelf = function() end
	return tbl
end

local function node_layout(self, ...)
	DTree_Node.PerformLayout(self, ...)
	if self.Label then
		self.Label:SetFont(pace.CurrentFont)
		if pace.ShadowedFonts[pace.CurrentFont] then
			self.Label:SetTextColor(derma.Color("text_bright", self, color_white))
		else
			self.Label:SetTextColor(derma.Color("text_dark", self, color_black))
		end
	end			
end

-- a hack, because creating a new node button will mess up the layout
function PANEL:AddNode(...)

	local node = fix_folder_funcs(DTree.AddNode(self, ...))
	install_expand(node)
	install_drag(node)
	node.SetModel = self.SetModel
		
	node.AddNode = function(...)
		local node_ = fix_folder_funcs(DTree_Node.AddNode(...))
		install_expand(node_)
		install_drag(node_)
		node_.SetModel = self.SetModel

		node_.AddNode = node.AddNode
		
		node_.PerformLayout = node_layout
		
		return node_
	end
	
	node.PerformLayout = node_layout	
		
	return node
end

local enable_model_icons = CreateClientConVar("pac_editor_model_icons", "1")

function PANEL:PopulateParts(node, parts, children)
	parts = table.ClearKeys(parts)
	
	local tbl = {}
	
	table.sort(parts, function(a,b) 
		return a and b and a:GetName() < b:GetName() 
	end)
	
	for key, val in pairs(parts) do
		if not val:HasChildren() then
			table.insert(tbl, val)
		end
	end
	
	for key, val in pairs(parts) do
		if val:HasChildren() then
			table.insert(tbl, val)
		end
	end
	
	for key, part in ipairs(tbl) do
		key = part.Id
				
		if not part:HasParent() or children then
			local part_node
			
			if IsValid(part.editor_node) then
				part_node = part.editor_node
			elseif IsValid(self.parts[key]) then
				part_node = self.parts[key]
			else
				part_node = node:AddNode(part:GetName())
			end
			
			part_node:SetTooltip(part:GetDescription())
			
			part.editor_node = part_node
			part_node.part = part
			
			self.parts[key] = part_node

			part_node.DoClick = function()
				if part:IsValid() then
					pace.Call("PartSelected", part)
					return true
				end
			end
			
			part_node.DoRightClick = function()
				if part:IsValid() then
					pace.Call("PartMenu", part)
					pace.Call("PartSelected", part)
					part_node:InternalDoClick()
					return true
				end
			end
			
			if enable_model_icons:GetBool() and part.ClassName == "model" and part.GetModel then
				part_node:SetModel(part:GetModel())
			else
				part_node.Icon:SetImage(pace.PartIcons[part.ClassName] or "gui/silkicons/plugin")
			end
			
			self:PopulateParts(part_node, part:GetChildren(), true)			
		
			if part.newly_created then
				part_node:SetSelected(true)
				if part:HasParent() and part.Parent.editor_node then
					part.Parent.editor_node:SetExpanded(true)
				end
				part.newly_created = nil
			else
				part_node:SetSelected(false)
				part_node:SetExpanded(part:GetEditorExpand())
			end
		end
	end
end

function PANEL:SelectPart(part)
	for key, node in pairs(self.parts) do
		if not node.part or not node.part:IsValid() then
			node:Remove()
			self.parts[key] = nil
		else
			if node.part == part then
				node:SetSelected(true)
			else
				node:SetSelected(false)
			end
		end
	end
end

function PANEL:Populate()

	self:SetLineHeight(18)
	self:SetIndentSize(2)
	
	for key, node in pairs(self.parts) do
		if not node.part or not node.part:IsValid() then
			node:Remove()
			self.parts[key] = nil
		end
	end
	
	--[[self.m_pSelectedItem = nil
	
	for key, node in pairs(self:GetItems()) do
		node:Remove()
	end]]
	
	self:PopulateParts(self, pac.GetParts(true))
	
	self:InvalidateLayout()
end

pace.RegisterPanel(PANEL)

function debug.trace()	
	MsgN("")
    MsgN("Trace: " )
	
	for level = 1, math.huge do
		local info = debug.getinfo(level, "Sln")
		
		if info then
			if info.what == "C" then
				MsgN(level, "\tC function")
			else
				MsgN(string.format("\t%i: Line %d\t\"%s\"\t%s", level, info.currentline, info.name or "unknown", info.short_src or ""))
			end
		else
			break
		end
    end

    MsgN("")
end

local function remove_node(obj)
	if (obj.editor_node or NULL):IsValid() then
		obj.editor_node:SetForceShowExpander()
		obj.editor_node:GetRoot().m_pSelectedItem = nil
		obj.editor_node:Remove()
		pace.RefreshTree()
	end
end

hook.Add("pac_OnPartRemove", "pace_remove_tree_nodes", remove_node)

local function remove_node(part, localplayer)
	if localplayer then
		pace.RefreshTree()
	end
end
hook.Add("pac_OnPartCreated", "pace_create_tree_nodes", create_node)

function pace.RefreshTree()
	if pace.tree:IsValid() then
		timer.Create("pace_refresh_tree",  0.01, 1, function()
			if pace.tree:IsValid() then
				pace.tree:Populate()
				pace.tree.RootNode:SetExpanded(true, true) -- why do I have to do this`?
			end
		end)
	end
end
