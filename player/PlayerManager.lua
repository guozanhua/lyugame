-- PlayerManager.lua
local skynet = require "skynet" 
require "skynet.manager"

local datacenter = require "datacenter"

local tinsert = table.insert
local tremove = table.remove

local web_service = ...

local player_list = {}
local player_outline_pool = {}

local CMD = {}

local player_seed = 100000

function relogin( name, p )
	
end
--[[addPlayer
	pinfo
		- player_id, 
		- player_name 
		- room_info
			- room_id 
			- room_sn
		- player_ws
		- player_sn
		- player_account
]]
function CMD.addPlayer( pinfo )
	if player_list[ pinfo.player_id ] == nil then
		player_list[ pinfo.player_id ] = pinfo
	end
end

-- 检查用户名是否重复，如不重复返回 player seed id
function CMD.checkPlayerName( name )
	-- for k,p in pairs(player_outline_pool) do
	-- 	if p.player_name == name then
	-- 		relogin( name, p )
	-- 	end
	-- end
	for id,p in pairs(player_list) do
		if p.player_name == name then
			return 1
		end
	end
	player_seed = player_seed + 1
	return player_seed
end

function CMD.delPlayer( player_id )
	local pinfo = player_list[ player_id ]
	tinsert( player_outline_pool, pinfo )
	if #player_outline_pool > 50 then
		player_outline_pool[1] = nil
		tremove( player_outline_pool, 1 )
	end
	player_list[ player_id ] = nil
end

--[[getPlayerSN
	return 0 :offline >0:player_sn
]]
function CMD.getPlayerSN( player_id )
	local pinfo = player_list[ player_id ]
	local sn = 0
	if pinfo then
		sn = pinfo.player_sn
	end
	return sn
end

function CMD.getPlayerSNByAccount( player_account )
	local sn = 0
	for id,pinfo in pairs(player_list) do
		if pinfo.player_account == player_account then
			sn = pinfo.player_sn
			break
		end
	end
	return sn
end

-- t type: default 0 全体 1 大厅 
function CMD.broadcast( t, pkg )
	for id,p in pairs( player_list ) do
		if t == 0 or ( t == 1 and p.roomid == 0 ) then
			skynet.call( web_service, "lua", "send", p.player_ws, pkg )
		end
	end
end

function CMD.test_1( ... )
	print("aaaaaaaaaa")
end

--[[
	player manager part-time service manager

	close function call other service close function, other service return back ServerCloseBack
	after all service close, player manager save player data, and exit self

	now has 
]]
function CMD.ServiceClose()
	datacenter.set("ServerState", 0)
	skynet.send( ".RoomManager", "lua", "ServiceClose" )

	skynet.send( web_service, "lua", "ServiceClose" )
	return 0
end

function checkPlayer()
	local canclose = true
	for k,v in pairs(player_list) do
		if v then
			canclose = false
		end
	end
	if canclose then
		skynet.timeout(5*100, function( ... )
			skynet.exit()	
		end)
	else
		skynet.timeout(5*100, function( ... )
			checkPlayer()
		end)
	end
end

function ServiceExit( ... )
	for id,p in pairs( player_list ) do
		skynet.call( p.player_sn, "lua", "beforeDisconnect" )
	end
	
	checkPlayer()
end
--[[
	info 
		from 
			1 RoomManager
			2 WebService
	Ldatabase exit by debug console
]]
local service_list = { [1] = false, [2] = false, }
function CMD.ServerCloseBack(info)
	service_list[info.from] = true

	local canclose = true
	for k,v in pairs(service_list) do
		if v == false then
			canclose = false
		end
	end
	if canclose then
		ServiceExit()
	end
end

skynet.start(function(  )
	skynet.dispatch( "lua", function(_,_, command, ...)
		local f = CMD[command]
		local r = f(...)
		if r then
			skynet.ret(skynet.pack(r))
		end
	end)
	skynet.register(".PlayerManager")
end)