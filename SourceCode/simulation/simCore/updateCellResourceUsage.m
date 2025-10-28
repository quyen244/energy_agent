function cells = updateCellResourceUsage(cells, ues)
    for cellIdx = 1:length(cells)
        connectedUEs = [];
        totalTrafficDemand = 0;
        totalSinr = 0;
        validSinrCount = 0;
        
        for ueIdx = 1:length(ues)
            if ues(ueIdx).servingCell == cells(cellIdx).id
                connectedUEs(end+1) = ueIdx;
                totalTrafficDemand = totalTrafficDemand + ues(ueIdx).trafficDemand;
                
                if ~isnan(ues(ueIdx).sinr)
                    totalSinr = totalSinr + ues(ueIdx).sinr;
                    validSinrCount = validSinrCount + 1;
                end
            end
        end
        
        cells(cellIdx).connectedUEs = connectedUEs;
        cells(cellIdx).currentLoad = totalTrafficDemand;
        
        loadRatio = min(1.0, totalTrafficDemand / cells(cellIdx).maxCapacity);
        numUEs = length(connectedUEs);
        
        powerRatio = (cells(cellIdx).txPower - cells(cellIdx).minTxPower) / ...
                    (cells(cellIdx).maxTxPower - cells(cellIdx).minTxPower);
        
        baseCpu = 10 + powerRatio * 5;
        perUECpu = numUEs * 2.5;
        loadCpu = loadRatio * 50;
        cells(cellIdx).cpuUsage = min(95, baseCpu + perUECpu + loadCpu);
        
        baseUrb = numUEs * 3;
        loadPrb = loadRatio * 60;
        cells(cellIdx).prbUsage = min(95, baseUrb + loadPrb);
        
        baseEnergy = cells(cellIdx).baseEnergyConsumption;
        txPowerConsumption = 10^((cells(cellIdx).txPower - 30)/10);
        perUEEnergy = numUEs * 15;
        loadEnergy = loadRatio * 200;
        cells(cellIdx).energyConsumption = baseEnergy + txPowerConsumption + perUEEnergy + loadEnergy;
        
        if numUEs > 0 && validSinrCount > 0
            avgSinr = totalSinr / validSinrCount;
            cells(cellIdx).avgSinr = avgSinr;
        else
            cells(cellIdx).avgSinr = 0;
        end
        
        baseDropRate = 0.1; 
        
        if cells(cellIdx).txPower <= cells(cellIdx).minTxPower + 1
            powerDropPenalty = (cells(cellIdx).minTxPower + 1 - cells(cellIdx).txPower + 1) * 4.0; 
        elseif cells(cellIdx).txPower <= cells(cellIdx).minTxPower + 3
            powerDropPenalty = (cells(cellIdx).minTxPower + 3 - cells(cellIdx).txPower) * 1.5; 
        else
            powerDropPenalty = 0;
        end
        
        % Congestion factors
        congestionFactor = 0;
        if cells(cellIdx).cpuUsage > 90
            congestionFactor = congestionFactor + (cells(cellIdx).cpuUsage - 90) * 0.4;
        elseif cells(cellIdx).cpuUsage > 85
            congestionFactor = congestionFactor + (cells(cellIdx).cpuUsage - 85) * 0.2;
        end
        
        if cells(cellIdx).prbUsage > 90
            congestionFactor = congestionFactor + (cells(cellIdx).prbUsage - 90) * 0.3;
        elseif cells(cellIdx).prbUsage > 85
            congestionFactor = congestionFactor + (cells(cellIdx).prbUsage - 85) * 0.15;
        end
        
        % Signal quality factor
        signalFactor = 0;
        if validSinrCount > 0
            if avgSinr < 0
                signalFactor = signalFactor + abs(avgSinr) * 0.2; % 0.2% per dB below 0
            elseif avgSinr < 5
                signalFactor = signalFactor + (5 - avgSinr) * 0.1; % 0.1% per dB below 5
            end
        end
        
        cells(cellIdx).dropRate = min(25.0, baseDropRate + powerDropPenalty + congestionFactor + signalFactor);
        
        baseLatency = 10;
        loadLatency = loadRatio * 25;
        ueLatency = min(15, numUEs * 0.8);
        
        % Power latency penalty
        if cells(cellIdx).txPower <= cells(cellIdx).minTxPower + 1
            powerLatencyPenalty = (cells(cellIdx).minTxPower + 1 - cells(cellIdx).txPower + 1) * 15; % 15ms per dB
        elseif cells(cellIdx).txPower <= cells(cellIdx).minTxPower + 3
            powerLatencyPenalty = (cells(cellIdx).minTxPower + 3 - cells(cellIdx).txPower) * 8; % 8ms per dB
        else
            powerLatencyPenalty = (1 - powerRatio) * 3; % Small penalty for other power levels
        end
        
        cells(cellIdx).avgLatency = baseLatency + loadLatency + ueLatency + powerLatencyPenalty;
    end
end