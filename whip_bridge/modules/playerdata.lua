if IsDuplicityVersion() then return end

QBX = QBX or {}
QBX.PlayerData = exports.qbx_core:GetPlayerData() or {}

RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
    QBX.PlayerData = data
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    QBX.PlayerData = {}
end)
