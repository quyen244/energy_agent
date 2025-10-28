function [handoverEvents, ues] = checkHandoverEvents(ues, cells, currentTime, simParams, seed)
    handoverEvents = struct('ueId', {}, 'cellSource', {}, 'cellTarget', {}, ...
                            'rsrpSource', {}, 'rsrpTarget', {}, ...
                            'rsrqSource', {}, 'rsrqTarget', {}, ...
                            'sinrSource', {}, 'sinrTarget', {}, ...
                            'a3Offset', {}, 'ttt', {}, ...
                            'hoSuccess', {}, 'timestamp', {});
    
    for ueIdx = 1:length(ues)
        ue = ues(ueIdx);
        if isnan(ue.servingCell) 
            continue;
        end
        
        servingCellIdx = find([cells.id] == ue.servingCell, 1);
        if isempty(servingCellIdx)
            continue;
        end
        servingCell = cells(servingCellIdx);
        
        if isnan(ue.rsrp) || ue.rsrp < simParams.rsrpServingThreshold
            bestCell = findBestCellForConnection(ue, simParams.rsrpTargetThreshold, cells);
            if ~isempty(bestCell)
                ue.servingCell = bestCell.cellId;
                ue.rsrp = bestCell.rsrp;
                ue.rsrq = bestCell.rsrq;
                ue.sinr = bestCell.sinr;
            else
                ue.servingCell = NaN;
            end
            ues(ueIdx) = ue;
            continue;
        end
        
        for neighIdx = 1:length(ue.neighborMeasurements)
            neighbor = ue.neighborMeasurements(neighIdx);
            
            if neighbor.cellId == ue.servingCell
                continue; 
            end
            
            if neighbor.rsrp < simParams.rsrpTargetThreshold
                continue; 
            end

            targetCellIdx = find([cells.id] == neighbor.cellId, 1);
            if isempty(targetCellIdx)
                continue;
            end
            targetCell = cells(targetCellIdx);
            
            a3Condition = neighbor.rsrp > (ue.rsrp + servingCell.a3Offset) && ...
                         neighbor.rsrp >= simParams.rsrpTargetThreshold;
            
            if a3Condition
                if ue.hoTimer == 0
                    ue.hoTimer = currentTime;
                end
                
                if (currentTime - ue.hoTimer) >= (servingCell.ttt / 1000)
                    hoSuccess = evaluateHandoverSuccess(ue, neighbor, servingCell, targetCell, currentTime, seed);
                    hoEvent = createHandoverEvent(ue, neighbor, servingCell, currentTime, hoSuccess);
                    handoverEvents(end+1) = hoEvent;
                    
                    if hoSuccess
                        ue.servingCell = neighbor.cellId;
                        ue.rsrp = neighbor.rsrp;
                        ue.rsrq = neighbor.rsrq;
                        ue.sinr = neighbor.sinr;
                    end
                    
                    ue.handoverHistory(end+1) = hoEvent;
                    ue.hoTimer = 0;
                    break;
                end
            else
                ue.hoTimer = 0;
            end
        end
        
        ues(ueIdx) = ue;
    end
end