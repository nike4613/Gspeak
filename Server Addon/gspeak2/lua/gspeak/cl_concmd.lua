
local function RequestBroadcast(ply, state)
  if ply:IsAdmin() then
    print("Requesting broadcast state change")
    net.Start("gspeak_broadcast")
      net.WriteBool(value)
    net.SendToServer()
  else
    print("Not an admin!")
  end
end

concommand.Add("gs_broadcast", function(ply, cmd, args) -- main implementation
  if #args ~= 1 or (args[1] ~= "1" and args[1] ~= "0") then
    print("Incorrect arguments. Give 1 to turn on broadcast, 0 to turn it off.")
    return
  end

  RequestBroadcast(ply, args[1] == "1")
end, nil, "Allows server admins to broadcast to all GSpeak users.")

concommand.Add("+gs_broadcast", function(ply)
  RequestBroadcast(ply, true)
end, nil, "Enables GSpeak broadcasting")
concommand.Add("-gs_broadcast", function(ply)
  RequestBroadcast(ply, true)
end, nil, "Disables GSpeak broadcasting")
