function metrics = computeEnergySavingMetrics(ues, cells, simParams)
    totalEnergy = 0;
    activeCells = 0;
    totalDropRate = 0;
    totalLatency = 0;
    totalTraffic = 0;
    connectedUEs = 0;
    cpuViolations = 0;
    prbViolations = 0;
    maxCpuUsage = 0;
    maxPrbUsage = 0;

    for cellIdx = 1:length(cells)
        if cells(cellIdx).cpuUsage > simParams.cpuThreshold
            cpuViolations = cpuViolations + 1;
        end
        if cells(cellIdx).prbUsage > simParams.prbThreshold
            prbViolations = prbViolations + 1;
        end
        maxCpuUsage = max(maxCpuUsage, cells(cellIdx).cpuUsage);
        maxPrbUsage = max(maxPrbUsage, cells(cellIdx).prbUsage);
    end
        
    for cellIdx = 1:length(cells)
        totalEnergy = totalEnergy + cells(cellIdx).energyConsumption;
        
        activeCells = activeCells + 1;
        totalDropRate = totalDropRate + cells(cellIdx).dropRate;
        totalLatency = totalLatency + cells(cellIdx).avgLatency;
        
        totalTraffic = totalTraffic + cells(cellIdx).currentLoad;
    end
    
    for ueIdx = 1:length(ues)
        if ~isnan(ues(ueIdx).servingCell) && ues(ueIdx).servingCell > 0
            connectedUEs = connectedUEs + 1;
        end
    end
    
    metrics = struct();
    metrics.totalEnergy = totalEnergy;
    metrics.activeCells = activeCells;
    metrics.avgDropRate = totalDropRate / max(1, activeCells);
    metrics.avgLatency = totalLatency / max(1, activeCells);
    metrics.totalTraffic = totalTraffic;
    metrics.connectedUEs = connectedUEs;
    metrics.connectionRate = (connectedUEs / length(ues)) * 100;
    metrics.cpuViolations = cpuViolations;
    metrics.prbViolations = prbViolations;
    metrics.maxCpuUsage = maxCpuUsage;
    metrics.maxPrbUsage = maxPrbUsage;
    
    kpiViolations = 0;
    if metrics.avgDropRate > simParams.dropCallThreshold
        kpiViolations = kpiViolations + 1;
    end
    if metrics.avgLatency > simParams.latencyThreshold
        kpiViolations = kpiViolations + 1;
    end
    
    metrics.kpiViolations = kpiViolations;
end