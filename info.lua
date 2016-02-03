local TOOLTIP_LENGTH = 30

local private, public = {}, {}
Aux.info = public

function public.inventory_index(slot)
    local inventory_index_map = {
        INVTYPE_AMMO = {0},
        INVTYPE_HEAD = {1},
        INVTYPE_NECK = {2},
        INVTYPE_SHOULDER = {3},
        INVTYPE_BODY = {4},
        INVTYPE_CHEST = {5},
        INVTYPE_ROBE = {5},
        INVTYPE_WAIST = {6},
        INVTYPE_LEGS = {7},
        INVTYPE_FEET = {8},
        INVTYPE_WRIST = {9},
        INVTYPE_HAND = {10},
        INVTYPE_FINGER = {11, 12},
        INVTYPE_TRINKET = {13, 14},
        INVTYPE_CLOAK = {15},
        INVTYPE_2HWEAPON = {16, 17},
        INVTYPE_WEAPONMAINHAND = {16, 17},
        INVTYPE_WEAPON = {16, 17},
        INVTYPE_WEAPONOFFHAND = {16, 17},
        INVTYPE_HOLDABLE = {16, 17},
        INVTYPE_SHIELD = {16, 17},
        INVTYPE_RANGED = {18},
        INVTYPE_RANGEDRIGHT = {18},
        INVTYPE_TABARD = {19},
    }

    return unpack(inventory_index_map[slot] or {})
end

function public.container_item(bag, slot)
	local hyperlink = GetContainerItemLink(bag, slot)
	
	if not hyperlink then
		return
    end

    local item_id, suffix_id, unique_id, enchant_id = private.parse_hyperlink(hyperlink)
    local item_info = public.item(item_id, suffix_id, unique_id, enchant_id)

    local texture, count, locked, quality, readable, lootable = GetContainerItemInfo(bag, slot) -- quality not working?
    local tooltip = public.tooltip(function(tt) tt:SetBagItem(bag, slot) end)

    return {
        item_id = item_id,
        suffix_id = suffix_id,
        unique_id = unique_id,
        enchant_id = enchant_id,

        hyperlink = hyperlink,
        itemstring = item_info.itemstring,
        item_key = item_id..':'..suffix_id,

        name = item_info.name,
        texture = texture,
        level = item_info.level,
        type = item_info.type,
        subtype = item_info.subtype,
        quality = item_info.quality,
        max_stack = item_info.max_stack,

        count = count,
        locked = locked,
        readable = readable,
        lootable = lootable,

        tooltip = tooltip,
        charges = private.item_charges(tooltip),
    }
end

function public.auction_sell_item()
	local name, texture, stack_size, quality, usable, vendor_price = GetAuctionSellItemInfo()

	if name then

        local unit_vendor_price = vendor_price / stack_size
        local tooltip = public.tooltip(function(tt) tt:SetAuctionSellItem() end)

		return {
			name = name,
			texture = texture,
            quality = quality,

			stack_size = stack_size,
			usable = usable,
            unit_vendor_price = unit_vendor_price,
            tooltip = tooltip,
            charges = private.item_charges(tooltip),
		}
	end
end

function public.auction(index, type)
    type = type or 'list'

	local hyperlink = GetAuctionItemLink(type, index)
	
	if not hyperlink then
		return
	end

    local item_id, suffix_id, unique_id, enchant_id = private.parse_hyperlink(hyperlink)
    local item_info = public.item(item_id, suffix_id, unique_id, enchant_id)

    local name, texture, count, quality, usable, level, start_price, min_increment, buyout_price, high_bid, high_bidder, owner, sale_status = GetAuctionItemInfo(type, index)

	local duration = GetAuctionItemTimeLeft(type, index)
    local tooltip = public.tooltip(function(tt) tt:SetAuctionItem(type, index) end)
    local charges = private.item_charges(tooltip)
    local aux_quantity = charges or count
    local bid_price = (high_bid > 0 and high_bid or start_price) + min_increment

    return {
        item_id = item_id,
        suffix_id = suffix_id,
        unique_id = unique_id,
        enchant_id = enchant_id,

        hyperlink = hyperlink,
        itemstring = item_info.itemstring,
        item_key = item_id..':'..suffix_id,
        signature = Aux.util.join({item_id, suffix_id, unique_id, enchant_id, aux_quantity, start_price, buyout_price}, ':'), -- not unique!
        search_signature = Aux.util.join({item_id, suffix_id, enchant_id, buyout_price, bid_price, aux_quantity, duration, owner or ''}, ':'),

        name = name,
        texture = texture,
        level = item_info.level,
        type = item_info.type,
        subtype = item_info.subtype,
        quality = quality,
        max_stack = item_info.max_stack,

        count = count,
        min_bid = start_price, -- deprecated
        start_price = start_price,
        high_bid = high_bid,
        current_bid = high_bid, -- deprecated
        min_increment = min_increment,
        bid_price = bid_price,
        buyout_price = buyout_price,
        unit_bid_price = bid_price / aux_quantity,
        unit_buyout_price = buyout_price / aux_quantity,
        high_bidder = high_bidder,
        owner = owner,
        sale_status = sale_status,
        duration = duration,
        usable = usable,
        tooltip = tooltip,
        charges = charges,
        aux_quantity = aux_quantity,

        EnhTooltip_info = {
            name = name,
            hyperlink = hyperlink,
            quality = quality,
            count = aux_quantity,
        },
    }
end

function public.reanchor_tooltip()
    if private.anchor_cursor then
        this:ClearAllPoints()
        local x, y = GetCursorPosition()
        x, y = x / UIParent:GetEffectiveScale() + private.x_offset, y / UIParent:GetEffectiveScale() + private.y_offset
        this:SetPoint('TOP', UIParent, 'BOTTOMLEFT', x, y)
    end
end

function public.set_tooltip(itemstring, EnhTooltip_info, owner, anchor, x_offset, y_offset)
    if anchor == 'ANCHOR_CURSOR' and (x_offset or y_offset) then
        private.anchor_cursor = true
        private.x_offset = x_offset
        private.y_offset = y_offset
        anchor = 'TOP'
    else
        private.anchor_cursor = false
    end

    GameTooltip:SetOwner(owner, anchor)
    GameTooltip:SetHyperlink(itemstring)

    local item_id = tonumber(({strfind(itemstring, '^item:(%d+)')})[3])
    local item_info = Aux.static.item_info(item_id)
    local index1, index2 = public.inventory_index(item_info.slot)

    if index1 then
        ShoppingTooltip1:SetOwner(GameTooltip, 'ANCHOR_BOTTOMRIGHT')
        ShoppingTooltip1:SetInventoryItem('player', index1)
        ShoppingTooltip1:SetAlpha(0)
        Aux.control.on_next_update(function()
            ShoppingTooltip1:SetPoint('TOPLEFT', GameTooltip, 'TOPRIGHT', 0, -10)
            ShoppingTooltip1:SetAlpha(1)
        end)

        if index2 then
            ShoppingTooltip2:SetOwner(ShoppingTooltip1, 'ANCHOR_BOTTOMRIGHT')
            ShoppingTooltip2:SetInventoryItem('player', index2)
            ShoppingTooltip2:SetAlpha(0)
            Aux.control.on_next_update(function()
                ShoppingTooltip2:SetPoint('TOPLEFT', ShoppingTooltip1, 'TOPRIGHT')
                ShoppingTooltip2:SetAlpha(1)
            end)
        end
    end

	if EnhTooltip and EnhTooltip_info then
		EnhTooltip.TooltipCall(GameTooltip, EnhTooltip_info.name, EnhTooltip_info.hyperlink, EnhTooltip_info.quality, EnhTooltip_info.count)
	end
end

function public.tooltip_match(patterns, tooltip)
    return Aux.util.all(patterns, function(pattern)
        return Aux.util.any(tooltip, function(line)
            local left_match = line[1].text and strfind(strupper(line[1].text), strupper(pattern), 1, true)
            local right_match = line[2].text and strfind(strupper(line[2].text), strupper(pattern), 1, true)
            return left_match or right_match
        end)
    end)
end

function public.tooltip(setter)
	for i = 1, TOOLTIP_LENGTH do
		getglobal('AuxInfoTooltipTextLeft'..i):SetText()
		getglobal('AuxInfoTooltipTextRight'..i):SetText()
	end
	
	AuxInfoTooltip:SetOwner(UIParent, 'ANCHOR_NONE')
	setter(AuxInfoTooltip)
	AuxInfoTooltip:Show()
	
	local tooltip = {}
	for i = 1, TOOLTIP_LENGTH do
		local left, right = {}, {}
		
		left.text = getglobal('AuxInfoTooltipTextLeft'..i):GetText()
		left.color = { getglobal('AuxInfoTooltipTextLeft'..i):GetTextColor() }
		
		right.text = getglobal('AuxInfoTooltipTextRight'..i):GetText()
		right.color = { getglobal('AuxInfoTooltipTextRight'..i):GetTextColor() }
		
		tinsert(tooltip, {left or '', right or ''})
	end
	
	for i = 1, TOOLTIP_LENGTH do
		getglobal('AuxInfoTooltipTextLeft'..i):SetText()
		getglobal('AuxInfoTooltipTextRight'..i):SetText()
	end
	
	return tooltip
end

function private.item_charges(tooltip)
	for _, line in ipairs(tooltip) do
		local _, _, left_charges_string = strfind(line[1].text or '', "^(%d+) Charges")
		local _, _, right_charges_string = strfind(line[2].text or '', "^(%d+) Charges$")
		local charges = tonumber(left_charges_string) or tonumber(right_charges_string)
		if charges then
			return charges
		end
	end
end

function public.item_key(hyperlink)
    local item_id, suffix_id = private.parse_hyperlink(hyperlink)
    return item_id..':'..suffix_id
end

function private.parse_hyperlink(hyperlink)
    local _, _, item_id, enchant_id, suffix_id, unique_id, name = strfind(hyperlink, '|Hitem:(%d+):(%d+):(%d+):(%d+)|h[[]([^]]+)[]]|h')
    return tonumber(item_id) or 0, tonumber(suffix_id) or 0, tonumber(unique_id) or 0, tonumber(enchant_id) or 0, name
end

function public.itemstring(item_id, suffix_id, unique_id, enchant_id)
    return 'item:'..(item_id or 0)..':'..(enchant_id or 0)..':'..(suffix_id or 0)..':'..(unique_id or 0)
end

function public.item(item_id, suffix_id, unique_id, enchant_id)
    local itemstring = 'item:'..(item_id or 0)..':'..(enchant_id or 0)..':'..(suffix_id or 0)..':'..(unique_id or 0)
    local name, itemstring, quality, level, class, subclass, max_stack, slot, texture = GetItemInfo(itemstring)
    return name and {
        itemstring = itemstring,
        name = name,
        texture = texture,
        quality = quality,
        level = level,
        slot = slot,
        class = class,
        subclass = subclass,
        max_stack = max_stack,
    }
end
