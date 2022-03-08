local packageName = "Extra Extensions"

local assert = assert
local type = type

local devLog = console.devLog
local file_Exists = file.Exists

local color_red = Color( "#FF4040" )
local color_blue = Color( "#80A6FF" )

--[[-------------------------------------------------------------------------
    Web Material
---------------------------------------------------------------------------]]

if CLIENT then

    local fastBuffer = {}
    local createMaterial = nil
    do
        local baseMaterialData = {
            ["$basetexture"] = "color/white",
            ["$vertexcolor"] = 1,
            ["$realheight"] = 32,
            ["$realwidth"] = 32,
            ["$alpha"] = 0
        }

        local util_CRC = util.CRC
        local CreateMaterial = CreateMaterial
        createMaterial = function( url, shader, materialParameters )
            local name = "web_material_" .. util_CRC( url )
            local material = CreateMaterial( name, type( shader ) == "string" and shader or "UnlitGeneric", type(materialParameters) == "table" and table.Merge(table.Copy(baseMaterialData), materialParameters) or baseMaterialData )
            fastBuffer[ name ] = material
            return material
        end
    end

    local _Material = environment.saveFunc( "Material", Material )
    local buildMaterial = nil
    do
        local math_floor = math.floor
        local materialBuilder = {
            ["ITexture"] = function( material, key, value )
                material:SetTexture( key, value )
            end,
            ["VMatrix"] = function( material, key, value )
                material:SetMatrix( key, value )
            end,
            ["Vector"] = function( material, key, value )
                material:SetVector( key, value )
            end,
            ["number"] = function( material, key, value )
                if ( math_floor( value ) == value ) then
                    material:SetInt( key, value )
                else
                    material:SetFloat( key, value )
                end
            end
        }

        buildMaterial = function( material, dataPath, parameters )
            local try = _Material( "data/" .. dataPath, parameters )
            for key, value in pairs( try:GetKeyValues() ) do
                local action = materialBuilder[ type( value ) ]
                if (action != nil) then
                    action( material, key, value )
                end
            end

            return material
        end
    end

    local materialsPath = "gpm_http/materials"
    if not file.IsDir( materialsPath, "DATA" ) then
        file.CreateDir( materialsPath, "DATA" )
    end

    local function getSavedMateral( url, parameters, shader, materialParameters )
        local fastMaterial = fastBuffer[ url ]
        if (fastMaterial != nil) then
            return fastMaterial
        end

        local path = materialsPath .. "/" .. url:getFileFromURL( true )
        if file_Exists( path, "DATA" ) then
            return buildMaterial( createMaterial( url, shader, materialParameters ), path, parameters )
        end
    end

    do

        local ismaterial = ismaterial
        local file_Write = file.Write
        local http_Fetch = http.Fetch
        local game_ready_run = game_ready.run
        local http_isSuccess = http.isSuccess

        function Material( url, parameters, callback, shader, materialParameters )
            if not url:isURL() then
                return _Material( url, parameters )
            end

            local savedMaterial = getSavedMateral( url, parameters, shader, materialParameters )
            if (savedMaterial != nil) then
                if type( callback ) == "function" then
                    callback( savedMaterial )
                end

                return savedMaterial
            end

            local material = createMaterial( url, shader, materialParameters )
            game_ready_run(function()
                local filename = url:getFileFromURL( true )
                devLog( "Started download: '", color_blue, filename, console.getColor(), "'" ):setTag( packageName )

                http_Fetch( url, function( data, size, headers, code )
                    if http_isSuccess( code ) then

                        local contentType = headers["Content-Type"]
                        if (data:sub( 2, 4 ):lower() == "png" or contentType == "image/png" and "png") or (data:sub( 7, 10 ):lower() == "jfif" or data:sub( 7, 10 ):lower() == "exif" or contentType == "image/jpeg" and "jpg") then
                            local dataPath = materialsPath .. "/" .. filename
                            file_Write( dataPath, data )

                            buildMaterial( material, dataPath, parameters )
                            devLog("Material from `", color_blue, url, console.getColor(), "` downloaded. Saved in `data/" .. dataPath .. "`"):setTag( packageName )
                            if type( callback ) == "function" then
                                callback( material )
                            end
                        else
                            devLog( "'", color_blue, filename, console.getColor(), "' - is not an image!" ):setTag( packageName )
                        end

                    else
                        local cColor = console.getColor()
                        devLog( "An error code '", color_red, code, cColor, "' was received while downloading: '", color_blue, filename, cColor, "'" ):setTag( packageName )
                    end
                end,
                function( err )
                    devLog( "Failed to download image from '", color_blue, url, console.getColor(), "'. Reason: ", color_red, reason ):setTag( packageName )
                    if ismaterial( material ) then
                        material:SetInt( "$alpha", 1 )
                        fastBuffer[ url ] = nil
                    end
                end, nil, 120 )
            end)

            return material
        end
    end

end

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

PLAYER["SourceNick"] = environment.saveFunc( "PLAYER.Nick", PLAYER.Nick )

function PLAYER:Nick()
	return self:GetNWString( "__nickname", self:SourceNick() )
end

PLAYER["Name"] = PLAYER["Nick"]

if CLIENT then
    PLAYER["GetName"] = PLAYER["Nick"]
else
    PLAYER["GetName"] = ENTITY["GetName"]

    local team_GetColor = team.GetColor
    function PLAYER:SetNick( str )
        assert( type( str ) == "string", "bad argument #1 (string expected)" )
        local pColor = team_GetColor( self:Team() )
        local cColor = console.getColor()
        devLog( "Player (" .. self:EntIndex() .. ") Nickname changed: '", pColor, self:Nick(), cColor, "' -> '", pColor, str, cColor, "'" ):setTag( packageName )
        self:SetNWString( "__nickname", str )
    end

end