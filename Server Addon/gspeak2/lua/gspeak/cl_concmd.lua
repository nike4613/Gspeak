

concommand.Add("gs_broadcast", function(ply, cmd, args) -- main implementation
  if #args ~= 1 or (args[1] ~= "1" and args[1] ~= "0") then
    print("Incorrect arguments. Give 1 to turn on broadcast, 0 to turn it off.")
    return
  end

  local value = args[1] == "1"

  if ply:IsAdmin() then
    print("Requesting broadcast state change")
    net.Start("gspeak_broadcast")
      net.WriteBool(value)
    net.SendToServer()
  else
    print("Not an admin!")
  end
end, nil, "Allows server admins to broadcast to all GSpeak users.")
