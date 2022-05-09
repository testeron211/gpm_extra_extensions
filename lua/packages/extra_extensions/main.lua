local packageName = "Extra Extensions"
local logger = GPM.Logger( packageName )

--[[-------------------------------------------------------------------------
    Web Material
---------------------------------------------------------------------------]]
do

    local material_func = environment.saveFunc( "Material", Material )

    local web_material = {}
    web_material.__index = web_material

    web_material.BaseData = {
        ["$basetexture"] = "debugempty",
        ["$vertexcolor"] = 1,
        ["$realheight"] = 32,
        ["$realwidth"] = 32,
        ["$alpha"] = 0
    }

    -- Name
    function web_material:GetName()
        return self.Name or "N/A"
    end

    do
        local util_CRC = util.CRC
        function web_material:SetName( str )
            self.Name = util_CRC( str )
        end
    end

    -- Init
    do
        local table_Copy = table.Copy
        function web_material:Init()
            self.Data = table_Copy( self.BaseData )
        end
    end

    if (CLIENT) then
        -- Shader
        function web_material:GetShader()
            return self.Shader or "UnlitGeneric"
        end

        function web_material:SetShader( str )
            self.Shader = str
        end

        -- InitMaterial
        local CreateMaterial = CreateMaterial
        function web_material:InitMaterial()
            self.Material = CreateMaterial( self:GetName(), self:GetShader(), self.Data )
        end
    end

    -- URL
    function web_material:GetURL()
        return self.URL
    end

    function web_material:SetURL( url )
        self:SetName( url )
        self.URL = url
    end

    -- Path
    function web_material:GetPath()
        return self.Path or self.BaseData["$basetexture"]
    end

    function web_material:SetPath( str )
        self.Path = "data/" .. str
    end

    -- Material
    function web_material:GetMaterial()
        return self.Material
    end

    function web_material:SetMaterial( mat )
        self.Material = mat
    end

    -- pngParameters

    function web_material:GetPNGParameters()
        return self.pngParameters or ""
    end

    function web_material:SetPNGParameters( str )
        self.pngParameters = str
    end

    -- Rebuild
    do

        local math_floor = math.floor
        local switch = switch
        local pairs = pairs
        local type = type

        local server_material = "models/wireframe"

        local cases = {
            ["itexture"] = function( self, key, value )
                self:SetTexture( key, value )
            end,
            ["vmatrix"] = function( self, key, value )
                self:SetMatrix( key, value )
            end,
            ["vector"] = function( self, key, value )
                self:SetVector( key, value )
            end,
            ["number"] = function( self, key, value )
                if ( math_floor( value ) == value ) then
                    self:SetInt( key, value )
                else
                    self:SetFloat( key, value )
                end
            end
        }

        function web_material:Rebuild()
            local material = self:GetMaterial() or material_func( server_material )
            for key, value in pairs( material_func( self:GetPath(), self:GetPNGParameters() or "" ):GetKeyValues() ) do
                switch( type( value ):lower(), cases, material, key, value )
            end
        end

    end

    -- Download
    do

        local materials_folder = "gpm_http/materials"
        if not file.IsDir( materials_folder, "DATA" ) then
            file.CreateDir( materials_folder, "DATA" )
        end

        local file_Delete = file.Delete
        local http_Download = http.Download

        function web_material:Download()
            http_Download( self:GetURL(), function( path, binary, headers )
                self:SetPath( path )
                local contentType = headers["Content-Type"]
                if (binary:sub( 2, 4 ):lower() == "png" or contentType == "image/png" and "png") or (binary:sub( 7, 10 ):lower() == "jfif" or binary:sub( 7, 10 ):lower() == "exif" or contentType == "image/jpeg" and "jpg") then
                    self:Rebuild()
                    return
                end

                file_Delete( self:GetPath() )
                logger:warn( "{1} is not image! Removing...", self:GetPath() )
            end, function()
                local material = self:GetMaterial()
                if (material ~= nil) then
                    material:SetInt( "$alpha", 1 )
                end
            end, materials_folder )
        end

    end


    function web_material:__tostring()
        return "Web Material [" .. self:GetName() .. "]"
    end

    local web_materials = {}
    local setmetatable = setmetatable

    function Material( materialName, pngParameters, isModelMaterial )
        if materialName:IsURL() then
            if (web_materials[ materialName ] == nil) then
                local web_material = setmetatable( {}, web_material )
                web_materials[ materialName ] = web_material

                web_material:Init()
                web_material:SetName( materialName:getFileFromURL( true ) )

                if (isModelMaterial) then
                    web_material:SetShader( "VertexLitGeneric" )
                    web_material.Data["$model"] = 1
                end

                if (CLIENT) then
                    web_material:InitMaterial()
                end

                web_material:SetPNGParameters( pngParameters )
                web_material:SetURL( materialName )
                web_material:Download()

                return web_material:GetMaterial()
            end

            local web_material = web_materials[ materialName ]
            if (pngParameters ~= web_material:GetPNGParameters()) then
                web_material:SetPNGParameters( pngParameters )
                web_material:Rebuild()
            end

            return web_material:GetMaterial()
        end

        return material_func( materialName, pngParameters )
    end

end

--[[-------------------------------------------------------------------------
    Player Meta Extensions
---------------------------------------------------------------------------]]
do

    local PLAYER = FindMetaTable( "Player" )

    --[[-------------------------------------------------------------------------
        Player Nickname
    ---------------------------------------------------------------------------]]

    do

        -- `string` PLAYER:SourceNick() - Returns original player nickname as `string`
        PLAYER.SourceNick = environment.saveFunc( "PLAYER.Nick", PLAYER.Nick )

        -- `string` PLAYER:Nick() - Returns player nickname as `string`
        function PLAYER:Nick()
            return self:GetNWString( "__nickname", self:SourceNick() )
        end

        -- `string` PLAYER:Name() - Returns player nickname as `string`
        PLAYER.Name = PLAYER.Nick

        -- `string` PLAYER:GetName() - On client that player nickname, on server that player mapping entity name
        PLAYER.GetName = (CLIENT) and PLAYER.Nick or FindMetaTable( "Entity" ).GetName

        -- PLAYER:SetNick( `string` nickname ) - Sets globaly player nickname
        if (SERVER) then

            local nicknames = {}
            function PLAYER:SetNick( nickname )
                logger:info( "Player ({1}), nickname changed: '{2}' -> '{3}'", self:EntIndex(), self:Nick(), nickname )
                self:SetNWString( "__nickname", (nickname == nil) and self:SourceNick() or nickname )

                if self:IsBot() then return end
                nicknames[ self:SteamID64() ] = nickname
            end

            hook.Add("PlayerInitialSpawn", "CustomNicknames", function( ply )
                local nickname = nicknames[ ply:SteamID64() ]
                if (nickname ~= nil) then
                    ply:SetNick( nickname )
                end
            end)

        end

    end

    --[[-------------------------------------------------------------------------
        PLAYER:IsListenServerHost Extension
    ---------------------------------------------------------------------------]]
    do

        if (CLIENT) then

            if game.SinglePlayer() then
                function PLAYER:IsListenServerHost()
                    return true
                end
            else
                if game.IsDedicated() then
                    function PLAYER:IsListenServerHost()
                        return false
                    end
                else
                    function PLAYER:IsListenServerHost()
                        return self:GetNWBool( "__islistenserverhost", false )
                    end
                end
            end

        end

        if (SERVER) and not game.SinglePlayer() and not game.IsDedicated() then
            hook.Add("PlayerInitialSpawn", "IsListenServerHost", function( ply )
                if ply:IsListenServerHost() then
                    ply:SetNWBool( "__islistenserverhost", true )
                    hook.Remove( "PlayerInitialSpawn", "PLAYER:IsListenServerHost()" )
                end
            end)
        end

    end

    --[[-------------------------------------------------------------------------
        PLAYER:ConCommand( `string` cmd ) F*** Rubat Fix
    ---------------------------------------------------------------------------]]

    do

        local net_string = "Player@ConCommand"

        if (SERVER) then

            local net_WriteString = net.WriteString
            local net_Start = net.Start
            local net_Send = net.Send

            function PLAYER:ConCommand( cmd )
                logger:debug( "ConCommand '{1}' runned on '{2}'", cmd, ply )
                net_Start( net_string )
                    net_WriteString( cmd )
                net_Send( self )
            end

        end

        if (CLIENT) then

            local net_ReadString = net.ReadString
            local net_Receive = net.Receive

            hook.Add("PlayerInitialized", net_string, function( ply )
                net_Receive(net_string, function()
                    ply:ConCommand( net_ReadString() )
                end)
            end)

        end

    end

end