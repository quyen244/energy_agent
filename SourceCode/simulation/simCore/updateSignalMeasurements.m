function ues = updateSignalMeasurements(ues, cells, rsrpMeasurementThreshold, currentTime, seed)
    for ueIdx = 1:length(ues)
        ue = ues(ueIdx);
        
        measurements = struct('cellId', {}, 'rsrp', {}, 'rsrq', {}, 'sinr', {});
        
        for cellIdx = 1:length(cells)
            cell = cells(cellIdx);
            
            distance = sqrt((ue.x - cell.x)^2 + (ue.y - cell.y)^2);
            pathLoss = calculatePathLoss(distance, cell.frequency, ue.id, currentTime, seed);

            rsrpRng = RandStream('mt19937ar', 'Seed', seed + 6000 + ue.id + cell.id + floor(currentTime * 100));
            prevStream = RandStream.setGlobalStream(rsrpRng);

            rsrp = cell.txPower - pathLoss + randn() * 1.5; 
            
            if cell.txPower <= cell.minTxPower + 2
                powerPenalty = (cell.minTxPower + 2 - cell.txPower) * 8; 
                rsrp = rsrp - powerPenalty;
                
                rsrp = rsrp + randn() * 3;
            end
            
            if rsrp >= (rsrpMeasurementThreshold - 5)
                rssi = rsrp + 10*log10(12) + randn() * 0.5;
                rsrq = max(-20, min(-3, 10*log10(12) + rsrp - rssi));
                
                baseSinr = rsrp - (-110);
                if cell.txPower <= cell.minTxPower + 2
                    sinrPenalty = (cell.minTxPower + 2 - cell.txPower) * 6; % 6dB SINR penalty
                    baseSinr = baseSinr - sinrPenalty;
                end
                sinr = baseSinr + randn() * 2;
                
                measurements(end+1) = struct(...
                    'cellId', cell.id, ...
                    'rsrp', rsrp, ...
                    'rsrq', rsrq, ...
                    'sinr', sinr ...
                );
            end
            RandStream.setGlobalStream(prevStream);
        end
        
        if isempty(measurements)
            ue.servingCell = NaN;
            ue.rsrp = NaN;  
            ue.rsrq = NaN;
            ue.sinr = NaN;
            ue.neighborMeasurements = [];
            ues(ueIdx) = ue;
            continue;
        end

        servingCellMeasurement = [];
        for measIdx = 1:length(measurements)
            if measurements(measIdx).cellId == ue.servingCell
                servingCellMeasurement = measurements(measIdx);
                break;
            end
        end
        
        if ~isempty(servingCellMeasurement)
            ue.rsrp = servingCellMeasurement.rsrp;
            ue.rsrq = servingCellMeasurement.rsrq;
            ue.sinr = servingCellMeasurement.sinr;
        else
            ue.servingCell = NaN;
            ue.rsrp = NaN;
            ue.rsrq = NaN;
            ue.sinr = NaN;
        end
        
        ue.neighborMeasurements = measurements;
        ues(ueIdx) = ue;
    end
end