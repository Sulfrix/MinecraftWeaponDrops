if (SERVER) then return end

function mcdrop(ply, cmd, args)
    net.Start("mcitem_playerdrop")
    net.SendToServer()
end

concommand.Add("mcitem_drop", mcdrop, nil, "Drops your active weapon.")