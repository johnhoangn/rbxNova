-- Ship service client, keeps track of and controls the user's ship
-- NPC Vessel control may be done with a neural network... We'll see as development continues
--
-- Dynamese (Enduo)
-- 07.20.2021



local ShipService = {Priority = 80}
local EntityService, MetronomeService, Network, FakeCAS

local Mouse
local UserShip, ProcessJobID


-- Own ship updater job
-- @param dt <float>
local function ProcessUserShip(dt)
    UserShip:UpdatePhysics(dt)
end


-- Receives the ship provided to us by the server
-- If the base had not replicated yet, we return false
--  which leads to the server to retrying 
-- @param dt <float>
-- @param base <Model>
local function ReceiveShip(dt, base)
    return ShipService:SetShip(base)
end


-- Grabs our ship entity from EntityService, saves it, and starts processing physics
-- @param base <Model>
-- @returns <boolean> success
function ShipService:SetShip(base)
    if (base == nil) then
        warn("Base nil! Not replicated yet?")
        return false
    end

    local ship = EntityService:GetEntity(base, true)

    if (ship ~= nil) then
        UserShip = ship
        ProcessJobID = MetronomeService:BindToFrequency(60, ProcessUserShip)
        self.ShipCreated:Fire(base)

        self.LocalPlayer.Character.PrimaryPart.Anchored = true
        workspace.CurrentCamera.CameraSubject = base

        self:EnableControls(true)

        return true
    else
        return false
    end
end


-- Retrieves the user's ship
-- @returns <EntityShip>
function ShipService:GetShip()
    return UserShip
end


-- Destroys the user's ship
function ShipService:RemoveShip()
    if (UserShip ~= nil) then
        self:EnableControls(false)
        MetronomeService:Unbind(ProcessJobID)
        UserShip:Destroy()
        UserShip = nil
        ProcessJobID = nil
    end
end


-- Binds or unbinds user input to the user's ship
-- TODO: Determine input method
-- @param state <boolean>
function ShipService:EnableControls(state)
    if (state) then
        local inputStates = {
            W = false;
            S = false;
            A = false;
            D = false;

            LMB = false;
            RMB = false;
        }

        FakeCAS:BindAction("ThrottleMax", function(_, state)
            inputStates.W = state == Enum.UserInputState.Begin

            if (inputStates.W) then
                UserShip:SetThrottle(1)
            else
                UserShip:SetThrottle(inputStates.S and -1 or 0)
            end
        end, Enum.KeyCode.W)

        FakeCAS:BindAction("ThrottleMin", function(_, state)
            inputStates.S = state == Enum.UserInputState.Begin

            if (inputStates.S) then
                UserShip:SetThrottle(-1)
            else
                UserShip:SetThrottle(inputStates.W and 1 or 0)
            end
        end, Enum.KeyCode.S)

        FakeCAS:BindAction("Steer", function(_, state)
            inputStates.LMB = state == Enum.UserInputState.Begin

            if (inputStates.LMB) then
                local release, conn

                conn = game:GetService("RunService").Stepped:Connect(function(et, dt)
                    UserShip:SetSteer(Mouse.Hit.p)
                end)

                release = Mouse.Button1Up:Connect(function()
                    conn:Disconnect()
                    release:Disconnect()
                    UserShip:SetSteer(nil)
                end)
            end

        end, Enum.UserInputType.MouseButton1)

    else
        FakeCAS:UnbindAction("ThrottleMax")
        FakeCAS:UnbindAction("ThrottleMin")
        FakeCAS:UnbindAction("Steer")
    end

    self.ControlsEnabled = state
end


function ShipService:EngineInit()
    EntityService = self.Services.EntityService
    MetronomeService = self.Services.MetronomeService
    Network = self.Services.Network
    FakeCAS = self.Modules.FakeCAS

    Mouse = self.LocalPlayer:GetMouse()

    self.ShipCreated = self.Classes.Signal.new()
    self.ControlsEnabled = false
end


function ShipService:EngineStart()
    Network:HandleRequestType(Network.NetRequestType.ShipControl, ReceiveShip)
end


return ShipService