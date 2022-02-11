local packageName = PKG and PKG["name"]

local assert = assert
local type = type

local devLog = console.devLog
local file_Exists = file.Exists

local color_blue = Color( "#80A6FF" )

--[[-------------------------------------------------------------------------
    Mdls pre-caching
---------------------------------------------------------------------------]]

do
    environment.saveFunc( "Model", Model )

    local precacheLimit = 4096
    local precached_mdls = {}

    local util_PrecacheModel = util.PrecacheModel
    function Model( path )
        assert( type( path ) == "string", "bad argument #1 (string expected)" )
        assert( precacheLimit > 0, "Model precache limit reached! ( > 4096 )" )

        if (precached_mdls[path] == nil) and file_Exists( path, "GAME" ) then
            devLog( "Model Precached -> ", color_blue, path ):setTag( packageName )
            precacheLimit = precacheLimit - 1
            precached_mdls[path] = true

            util_PrecacheModel( path )
        end

        return path
    end

end

--[[-------------------------------------------------------------------------
    Sounds pre-caching
---------------------------------------------------------------------------]]

do

    local world = nil
    hook.Add("InitPostEntity", "Base Extensions:PrecacheSound", function()
        world = game.GetWorld()
    end)

    local precached_sounds = {}
    local util_PrecacheSound = environment.saveFunc( "util.PrecacheSound", util.PrecacheSound )

    function util.PrecacheSound( path )
        assert( type( path ) == "string", "bad argument #1 (string expected)" )

        if (path == "") then
            return path
        end

        if (precached_sounds[path] == nil) and file_Exists( path, "GAME" ) then
            devLog( "Sound Precached -> ", color_blue, path ):setTag( packageName )
            precached_sounds[path] = true

            if (world ~= nil) then
                world:EmitSound( path, 0, 100, 0 )
            end
        end

        return util_PrecacheSound( path )
    end

end

--[[-------------------------------------------------------------------------
    Player Meta Name Extensions
---------------------------------------------------------------------------]]

local ENTITY = FindMetaTable( "Entity" )
local PLAYER = FindMetaTable( "Player" )

PLAYER["GetName"] = ENTITY["GetName"]
PLAYER["SourceNick"] = environment.saveFunc( "PLAYER.Nick", PLAYER.Nick )

function PLAYER:Nick()
	return self:GetNWString( "__nickname", self:SourceNick() )
end

PLAYER["Name"] = PLAYER["Nick"]

if SERVER then

    local team_GetClass = team.GetClass
    function PLAYER:SetNick( str )
        assert( type( str ) == "string", "bad argument #1 (string expected)" )
        devLog( "Player (" .. self:EntIndex() .. ") New nickname -> ", team_GetClass( self:Team() ), path ):setTag( packageName )
        self:SetNWString( "__nickname", str )
    end

end