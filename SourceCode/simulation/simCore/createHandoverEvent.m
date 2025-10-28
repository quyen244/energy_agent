function hoEvent = createHandoverEvent(ue, neighbor, servingCell, currentTime, hoSuccess)
    hoEvent = struct();
    hoEvent.ueId = ue.id;
    hoEvent.cellSource = servingCell.id;
    hoEvent.cellTarget = neighbor.cellId;
    hoEvent.rsrpSource = ue.rsrp;
    hoEvent.rsrpTarget = neighbor.rsrp;
    hoEvent.rsrqSource = ue.rsrq;
    hoEvent.rsrqTarget = neighbor.rsrq;
    hoEvent.sinrSource = ue.sinr;
    hoEvent.sinrTarget = neighbor.sinr;
    hoEvent.a3Offset = servingCell.a3Offset;
    hoEvent.ttt = servingCell.ttt;
    hoEvent.hoSuccess = hoSuccess;
    hoEvent.timestamp = currentTime;
end