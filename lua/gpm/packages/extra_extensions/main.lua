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
            devLog( "Model Precached -> ", color_blue, path ):setTag( "Extra Extensions" ):setSeparator()
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

        if (precached_sounds[path] == nil) and file_Exists( path, "GAME" ) then
            devLog( "Sound Precached -> ", color_blue, path ):setTag( "Extra Extensions" ):setSeparator()
            precached_sounds[path] = true

            if (world ~= nil) then
                world:EmitSound( path, 0, 100, 0 )
            end
        end

        return util_PrecacheSound( path )
    end

end
