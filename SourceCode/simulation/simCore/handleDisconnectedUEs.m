function ues = handleDisconnectedUEs(ues, cells, simParams, timeStep, currentTime)  
    disconnectionTimeout = 5.0; 
    connectionTimeout = 2.0;   
    hysteresisMargin = 3.0;      
    
    for ueIdx = 1:length(ues)
        ue = ues(ueIdx);
        
        if ~isnan(ue.servingCell)
            if ~isnan(ue.rsrp) && ue.rsrp < (simParams.rsrpServingThreshold - hysteresisMargin)
                if ue.disconnectionTimer == 0
                    ue.disconnectionTimer = disconnectionTimeout;
                else
                    ue.disconnectionTimer = ue.disconnectionTimer - timeStep;
                    
                    if ue.disconnectionTimer <= 0
                        logMsg = sprintf('Step %d/%d: UE %d disconnected from cell %d (RSRP: %.1f dBm)\n', ...
                            timeStep, simParams.simTime, ue.id, ue.servingCell, ue.rsrp);
                        fprintf(logMsg);
                        logToFile(simParams.ueLogFile, currentTime, logMsg);
                        ue.servingCell = NaN;
                        ue.rsrp = NaN;
                        ue.rsrq = NaN;
                        ue.sinr = NaN;
                        ue.disconnectionTimer = 0;
                        ue.connectionTimer = 0;
                        ue.sessionActive = false;
                        ue.trafficDemand = 0;
                        ue.dropCount = ue.dropCount + 1;
                    end
                end
            else
                ue.disconnectionTimer = 0;
            end
        end
        
        if isnan(ue.servingCell)
            bestCell = findBestCellForConnection(ue, simParams.rsrpServingThreshold + hysteresisMargin, cells);
            
            if ~isempty(bestCell)
                if ue.connectionTimer == 0
                    ue.connectionTimer = connectionTimeout;
                else
                    ue.connectionTimer = ue.connectionTimer - timeStep;
                    
                    if ue.connectionTimer <= 0
                        currentBestCell = findBestCellForConnection(ue, simParams.rsrpServingThreshold + hysteresisMargin, cells);
                        if ~isempty(currentBestCell) && currentBestCell.cellId == bestCell.cellId
                            ue.servingCell = bestCell.cellId;
                            ue.rsrp = bestCell.rsrp;
                            ue.rsrq = bestCell.rsrq;
                            ue.sinr = bestCell.sinr;
                            ue.connectionTimer = 0;
                        else
                            ue.connectionTimer = 0; 
                        end
                    end
                end
            else
                ue.connectionTimer = 0; 
            end
        end
        
        ues(ueIdx) = ue;
    end
end