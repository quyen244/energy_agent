function state = createRLState(cells, ues, currentTime, simParams)
    % Basic simulation info
    state.simulation = struct();
    state.simulation.totalCells = length(cells);
    state.simulation.totalUEs = length(ues);
    state.simulation.simTime = simParams.simTime;
    state.simulation.timeStep = simParams.timeStep;
    state.simulation.timeProgress = currentTime / simParams.simTime;
    state.simulation.carrierFrequency = simParams.carrierFrequency;
    state.simulation.isd = simParams.isd;
    state.simulation.minTxPower = simParams.minTxPower;
    state.simulation.maxTxPower = simParams.maxTxPower;
    state.simulation.basePower = simParams.basePower;
    state.simulation.idlePower = simParams.idlePower;
    state.simulation.dropCallThreshold = simParams.dropCallThreshold;
    state.simulation.latencyThreshold = simParams.latencyThreshold;
    state.simulation.cpuThreshold = simParams.cpuThreshold;
    state.simulation.prbThreshold = simParams.prbThreshold;
    state.simulation.trafficLambda = simParams.trafficLambda;
    state.simulation.peakHourMultiplier = simParams.peakHourMultiplier;
    
    state.network = struct();
    energyMetrics = computeEnergySavingMetrics(ues, cells, simParams);
    
    metricFields = fieldnames(energyMetrics);
    for i = 1:length(metricFields)
        state.network.(metricFields{i}) = energyMetrics.(metricFields{i});
    end
    
    totalTxPower = 0;
    avgPowerRatio = 0;
    
    for cellIdx = 1:length(cells)
        totalTxPower = totalTxPower + cells(cellIdx).txPower;
        if cells(cellIdx).maxTxPower > cells(cellIdx).minTxPower
            powerRatio = (cells(cellIdx).txPower - cells(cellIdx).minTxPower) / ...
                        (cells(cellIdx).maxTxPower - cells(cellIdx).minTxPower);
            avgPowerRatio = avgPowerRatio + powerRatio;
        end
    end
    
    state.network.totalTxPower = totalTxPower;
    state.network.avgPowerRatio = avgPowerRatio / max(1, length(cells));
    
    % Per-cell detailed information
    state.cells = struct();
    for cellIdx = 1:length(cells)
        cell = cells(cellIdx);
        cellKey = sprintf('cell_%d', cell.id);
        
        % Basic cell properties
        state.cells.(cellKey) = struct();
        state.cells.(cellKey).id = cell.id;
        state.cells.(cellKey).siteId = cell.siteId;
        state.cells.(cellKey).sectorId = cell.sectorId;
        state.cells.(cellKey).x = cell.x;
        state.cells.(cellKey).y = cell.y;
        state.cells.(cellKey).frequency = cell.frequency;
        state.cells.(cellKey).cellRadius = cell.cellRadius;
        
        % Power and energy information
        state.cells.(cellKey).txPower = cell.txPower;
        state.cells.(cellKey).energyConsumption = cell.energyConsumption;
        
        % Operational status
        state.cells.(cellKey).cpuUsage = cell.cpuUsage;
        state.cells.(cellKey).prbUsage = cell.prbUsage;
        state.cells.(cellKey).maxCapacity = cell.maxCapacity;
        state.cells.(cellKey).currentLoad = cell.currentLoad;
        
        % Handover parameters
        state.cells.(cellKey).ttt = cell.ttt;
        state.cells.(cellKey).a3Offset = cell.a3Offset;
        
        % Connected UEs information
        state.cells.(cellKey).numConnectedUEs = length(cell.connectedUEs);
        state.cells.(cellKey).connectedUEsList = cell.connectedUEs;
        
        % Calculate cell-specific metrics from connected UEs
        connectedUEsRSRP = [];
        connectedUEsRSRQ = [];
        connectedUEsSINR = [];
        connectedUEsTraffic = 0;
        activeSessions = 0;
        
        for ueIdx = 1:length(ues)
            if ~isnan(ues(ueIdx).servingCell) && ues(ueIdx).servingCell == cell.id
                if ~isnan(ues(ueIdx).rsrp)
                    connectedUEsRSRP(end+1) = ues(ueIdx).rsrp;
                end
                if ~isnan(ues(ueIdx).rsrq)
                    connectedUEsRSRQ(end+1) = ues(ueIdx).rsrq;
                end
                if ~isnan(ues(ueIdx).sinr)
                    connectedUEsSINR(end+1) = ues(ueIdx).sinr;
                end
                connectedUEsTraffic = connectedUEsTraffic + ues(ueIdx).trafficDemand;
                if ues(ueIdx).sessionActive
                    activeSessions = activeSessions + 1;
                end
            end
        end
        
        % Store aggregated UE metrics for this cell
        state.cells.(cellKey).avgRSRP = nanmean(connectedUEsRSRP);
        state.cells.(cellKey).minRSRP = nanmin(connectedUEsRSRP);
        state.cells.(cellKey).maxRSRP = nanmax(connectedUEsRSRP);
        state.cells.(cellKey).stdRSRP = nanstd(connectedUEsRSRP);
        
        state.cells.(cellKey).avgRSRQ = nanmean(connectedUEsRSRQ);
        state.cells.(cellKey).minRSRQ = nanmin(connectedUEsRSRQ);
        state.cells.(cellKey).maxRSRQ = nanmax(connectedUEsRSRQ);
        state.cells.(cellKey).stdRSRQ = nanstd(connectedUEsRSRQ);
        
        state.cells.(cellKey).avgSINR = nanmean(connectedUEsSINR);
        state.cells.(cellKey).minSINR = nanmin(connectedUEsSINR);
        state.cells.(cellKey).maxSINR = nanmax(connectedUEsSINR);
        state.cells.(cellKey).stdSINR = nanstd(connectedUEsSINR);
        
        state.cells.(cellKey).totalTrafficDemand = connectedUEsTraffic;
        state.cells.(cellKey).activeSessions = activeSessions;
        state.cells.(cellKey).loadRatio = state.cells.(cellKey).currentLoad / max(1, state.cells.(cellKey).maxCapacity);     
    end
        
    
    state.associations = struct();
    state.associations.cellUEMatrix = zeros(length(cells), length(ues));
    for ueIdx = 1:length(ues)
        if ~isnan(ues(ueIdx).servingCell) && ues(ueIdx).servingCell > 0
            cellIdx = find([cells.id] == ues(ueIdx).servingCell, 1);
            if ~isempty(cellIdx)
                state.associations.cellUEMatrix(cellIdx, ueIdx) = 1;
            end
        end
    end
end