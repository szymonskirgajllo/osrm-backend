require("lib/access")
require("lib/maxspeed")

-- Begin of globals
barrier_whitelist = { [""] = true, ["bollard"] = true, ["entrance"] = true, ["cattle_grid"] = true, ["border_control"] = true, ["toll_booth"] = true, ["sally_port"] = true, ["gate"] = true, ["no"] = true}
access_tag_whitelist = { ["yes"] = true, ["permissive"] = true, ["designated"] = true	}
access_tag_blacklist = { ["no"] = true, ["private"] = true, ["agricultural"] = true, ["forestery"] = true }
access_tag_restricted = { ["destination"] = true, ["delivery"] = true }
access_tags_hierachy = { "bicycle", "vehicle", "access" }
cycleway_tags = {["track"]=true,["lane"]=true,["opposite"]=true,["opposite_lane"]=true,["opposite_track"]=true,["share_busway"]=true,["sharrow"]=true,["shared"]=true }
service_tag_restricted = { ["parking_aisle"] = true }
restriction_exception_tags = { "bicycle", "vehicle", "access" }

default_speed = 10

walking_speed = 2

bicycle_speeds = { 
	["cycleway"] = default_speed * 1.2,
	["primary"] = default_speed,
	["primary_link"] = default_speed,
	["secondary"] = default_speed,
	["secondary_link"] = default_speed,
	["tertiary"] = default_speed,
	["tertiary_link"] = default_speed,
	["residential"] = default_speed,
	["unclassified"] = default_speed,
	["living_street"] = default_speed,
	["road"] = default_speed,
	["service"] = default_speed,
	["track"] = default_speed * 0.2,
	["path"] = default_speed * 0.2
	--["footway"] = 12,
	--["pedestrian"] = 12,
}

pedestrian_speeds = { 
	["footway"] = walking_speed,
	["pedestrian"] = walking_speed
}

railway_speeds = { 
	["train"] = 10,
	["railway"] = 10,
	["subway"] = 10,
	["light_rail"] = 10,
	["monorail"] = 10,
	["tram"] = 10
}

platform_speeds = { 
	["platform"] = walking_speed
}

amenity_speeds = { 
	["parking"] = 10,
	["parking_entrance"] = 10
}

man_made_speeds = { 
	["pier"] = walking_speed
}

route_speeds = { 
	["ferry"] = 5
}

surface_speeds = { 
	["cobblestone:flattened"] = default_speed*0.8,
	["paving_stones"] = default_speed*0.8,
	["compacted"] = default_speed*0.2,
	["cobblestone"] = default_speed*0.2,
	["unpaved"] = default_speed*0.2,
	["fine_gravel"] = default_speed*0.2,
	["gravel"] = default_speed*0.2,
	["pebbelstone"] = default_speed*0.2,
	["ground"] = default_speed*0.2,
	["dirt"] = default_speed*0.2,
	["earth"] = default_speed*0.2,
	["grass"] = default_speed*0.2,
	["mud"] = default_speed*0.1,
	["sand"] = default_speed*0.1	
}

take_minimum_of_speeds 	= true
obey_oneway 			= true
obey_bollards 			= false
use_restrictions 		= true
ignore_areas 			= true -- future feature
traffic_signal_penalty 	= 5
u_turn_penalty 			= 40
use_turn_restrictions   = false
turn_penalty 			= 120
turn_bias               = 1.4
use_route_relations     = true

-- End of globals

--modes
mode_normal = 1
mode_pushing = 2
mode_ferry = 3
mode_train = 4

    
function get_exceptions(vector)
	for i,v in ipairs(restriction_exception_tags) do 
		vector:Add(v)
	end
end

function node_function (node)
	local barrier = node.tags:Find ("barrier")
	local access = Access.find_access_tag(node, access_tags_hierachy)
	local traffic_signal = node.tags:Find("highway")
	
	-- flag node if it carries a traffic light	
	if traffic_signal == "traffic_signals" then
		node.traffic_light = true
	end
	
	-- parse access and barrier tags
	if access and access ~= "" then
		if access_tag_blacklist[access] then
			node.bollard = true
		else
			node.bollard = false
		end
	elseif barrier and barrier ~= "" then
		if barrier_whitelist[barrier] then
			node.bollard = false
		else
			node.bollard = true
		end
	end
	
	return true
end

function way_function (way, routes)
	-- initial routability check, filters out buildings, boundaries, etc
	local highway = way.tags:Find("highway")
	local route = way.tags:Find("route")
	local man_made = way.tags:Find("man_made")
	local railway = way.tags:Find("railway")
	local amenity = way.tags:Find("amenity")
	local public_transport = way.tags:Find("public_transport")
    if (not highway or highway == '') and 
		(not route or route == '') and 
		(not railway or railway=='') and 
		(not amenity or amenity=='') and
		(not man_made or man_made=='') and
    	(not public_transport or public_transport=='')
    	then
    	return false
    end
    
    -- don't route on ways or railways that are still under construction
    if highway=='construction' or railway=='construction' then
        return false
    end
    
	-- access
 	local access = Access.find_access_tag(way, access_tags_hierachy)
    if access_tag_blacklist[access] then
		return false
    end


	-- other tags
	local name = way.tags:Find("name")
	local ref = way.tags:Find("ref")
	local junction = way.tags:Find("junction")
	local maxspeed = parseMaxspeed(way.tags:Find ( "maxspeed") )
	local maxspeed_forward = parseMaxspeed(way.tags:Find( "maxspeed:forward"))
	local maxspeed_backward = parseMaxspeed(way.tags:Find( "maxspeed:backward"))
	local barrier = way.tags:Find("barrier")
	local oneway = way.tags:Find("oneway")
	local onewayClass = way.tags:Find("oneway:bicycle")
	local cycleway = way.tags:Find("cycleway")
	local cycleway_left = way.tags:Find("cycleway:left")
	local cycleway_right = way.tags:Find("cycleway:right")
	local duration	= way.tags:Find("duration")
	local service	= way.tags:Find("service")
	local area = way.tags:Find("area")
	local foot = way.tags:Find("foot")
	local surface = way.tags:Find("surface")
	local foot_forward = way.tags:Find("foot:forward")
	local foot_backward = way.tags:Find("foot:backward")
	local bicycle = way.tags:Find("bicycle")

		
	way.mode = mode_normal
	
	-- speed
    if route_speeds[route] then
		-- ferries (doesn't cover routes tagged using relations)
    	way.mode = mode_ferry
		way.ignore_in_grid = true
		if durationIsValid(duration) then
			way.duration = math.max( 1, parseDuration(duration) )
		else
		 	way.speed = route_speeds[route]
		end
	elseif platform_speeds[railway] then
		-- railway platforms (old tagging scheme)
		way.speed = platform_speeds[railway]
	elseif platform_speeds[public_transport] then
		-- public_transport platforms (new tagging platform)
		way.speed = platform_speeds[public_transport]
    elseif railway_speeds[railway] then
	 	-- railways
		if access and access_tag_whitelist[access] then
        	way.mode = mode_train
			way.speed = railway_speeds[railway]		
		end
	elseif amenity_speeds[amenity] then
		-- parking areas
		way.speed = amenity_speeds[amenity]
	elseif bicycle_speeds[highway] then
		-- regular ways
      	way.speed = bicycle_speeds[highway]
	elseif access_tag_whitelist[access] then
	    -- unknown way, but valid access tag
		way.speed = default_speed
	else
	    -- biking not allowed, maybe we can push our bike?
	    -- essentially requires pedestrian profiling, for example foot=no mean we can't push a bike
        if foot ~= 'no' then
	        if pedestrian_speeds[highway] then
	            -- pedestrian-only ways and areas
        		way.speed = pedestrian_speeds[highway]
            	way.mode = mode_pushing
        	elseif man_made and man_made_speeds[man_made] then
            	-- man made structures
            	way.speed = man_made_speeds[man_made]
            	way.mode = mode_pushing
            elseif foot == 'yes' then
                way.speed = walking_speed
            	way.mode = mode_pushing
            elseif foot_forward == 'yes' then
                way.forward.speed = walking_speed
            	way.forward.mode = mode_pushing
            	way.backward.mode = 0
            elseif foot_backward == 'yes' then
                way.backward.speed = walking_speed
            	way.backward.mode = mode_pushing
            	way.forward.mode = 0
            end
        end
    end
		
	-- direction
	local impliedOneway = false
	if junction == "roundabout" or highway == "motorway_link" or highway == "motorway" then
		impliedOneway = true
	end
	
	if onewayClass == "yes" or onewayClass == "1" or onewayClass == "true" then
    	way.backward.mode = 0
	elseif onewayClass == "no" or onewayClass == "0" or onewayClass == "false" then
	    -- prevent implied oneway
	elseif onewayClass == "-1" then
    	way.forward.mode = 0
	elseif oneway == "no" or oneway == "0" or oneway == "false" then
	    -- prevent implied oneway
	elseif string.find(cycleway, "opposite") == 1 then
		if impliedOneway then
        	way.forward.mode = 0
        	way.backward.mode = mode_normal
		end
	elseif cycleway_tags[cycleway_left] and cycleway_tags[cycleway_right] then
	    -- prevent implied
	elseif cycleway_tags[cycleway_left] then
		if impliedOneway then
        	way.forward.mode = 0
        	way.backward.mode = mode_normal
		end
	elseif cycleway_tags[cycleway_right] then
		if impliedOneway then
        	way.forward.mode = mode_normal
        	way.backward.mode = 0
		end
	elseif oneway == "-1" then
		way.forward.mode = 0
	elseif oneway == "yes" or oneway == "1" or oneway == "true" or impliedOneway then
	    way.backward.mode = 0
    end	
  
	-- dismount
	if bicycle == "dismount" then
        way.mode = mode_pushing
        way.speed = walking_speed
	end

	-- pushing bikes
	if bicycle_speeds[highway] or pedestrian_speeds[highway] then
	    if foot ~= "no" then
	        if junction ~= "roundabout" then
            	if way.backward.mode == 0 then
            	    way.backward.speed = walking_speed
                	way.backward.mode = mode_pushing
                elseif way.forward.mode == 0 then
                    way.forward.speed = walking_speed
                	way.forward.mode = mode_pushing
            	end
            end
        end
    end
	
	-- cycleway speed
	if way.forward.mode == mode_normal then
	    if cycleway_tags[cycleway_right] then
    		way.forward.speed = bicycle_speeds["cycleway"]
    	elseif cycleway_tags[cycleway] then
    		way.forward.speed = bicycle_speeds["cycleway"]
        end
    end
	if way.backward.mode == mode_normal then
    	if cycleway_tags[cycleway_left] then
    		way.backward.speed = bicycle_speeds["cycleway"]
        elseif cycleway_tags[cycleway] then
    		way.backward.speed = bicycle_speeds["cycleway"]
    	end
    end
    
    -- routes
    local factor_forward = 1.0
    local factor_backward = 1.0
    local ncn_name = nil
    local rcn_name = nil
    local lcn_name = nil
    while true do
    	local role, route = routes:Next()
        if route==nil then
            break
        end   
        if route.tags:Find("route")=='bicycle' then
            network = route.tags:Find("network")
            local factor = nil
            local route_name = route.tags:Find("name")
            -- until we have separate speed/impedance, we have to use speed,
            -- even though it will make travel times unrealistic
            if network == "ncn" then
                factor = 1.05
                ncn_name = route_name
            elseif network == "rcn" then
                factor = 1.1
                rcn_name = route_name
            elseif network == "lcn" then
                factor = 1.15
                lcn_name = route_name
            end
            if factor then
                if role ~= "backward" then
        		    factor_forward = math.max( factor_forward, factor )
        		end
        		if role ~= "forward" then
        		    factor_backward = math.max( factor_backward, factor )
                end
            end
        end
	end
	if way.forward.mode == mode_normal then
	    way.forward.speed = way.forward.speed*factor_forward
	end
	if way.backward.mode == mode_normal then
        way.backward.speed = way.backward.speed*factor_backward
    end
    
    -- name
	if "" ~= name and "" ~= ref and name ~= ref then
		way.name = name .. ' / ' .. ref
    elseif "" ~= name and route_name and name ~= route_name then
		way.name = name .. ' / ' .. route_name
    elseif "" ~= ref then
    	way.name = ref
	elseif "" ~= name then
		way.name = name
    elseif lcn_name then
        way.name = lcn_name
    elseif rcn_name then
        way.name = rcn_name
    elseif ncn_name then
        way.name = ncn_name
    else
		way.name = "{highway:"..highway.."}"	-- if no name exists, use way type
		                                        -- this encoding scheme is excepted to be a temporary solution
    end

    -- surfaces
    if surface_speeds[surface] then
        way.forward.speed = math.min(way.forward.speed, surface_speeds[surface])
        way.backward.speed  = math.min(way.backward.speed, surface_speeds[surface])
    end

	-- maxspeed
    MaxSpeed.limit( way, maxspeed, maxspeed_forward, maxspeed_backward )
    	
	return true
end

function turn_function (angle)
    -- compute turn penalty as angle^2, with a left/right bias
    k = turn_penalty/(90.0*90.0)
	if angle>=0 then
	    return angle*angle*k/turn_bias
	else
	    return angle*angle*k*turn_bias
    end
end
