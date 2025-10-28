function [ues, cells] = updateTrafficGeneration(ues, cells, currentTime, simParams)
    peakHourFactor = simParams.peakHourMultiplier;
    lambda = simParams.trafficLambda * peakHourFactor;
    
    % Reset cell loads
    for cellIdx = 1:length(cells)
        cells(cellIdx).currentLoad = 0;
        cells(cellIdx).connectedUEs = [];
    end
    
    % Generate traffic for each UE
    for ueIdx = 1:length(ues)
        if ~isnan(ues(ueIdx).servingCell) && ues(ueIdx).servingCell > 0
            % Generate Poisson traffic demand
            trafficDemand = poissrnd(lambda/length(ues)); % Distribute total trafficwha
            ues(ueIdx).trafficDemand = trafficDemand;
            ues(ueIdx).sessionActive = trafficDemand > 0;
            
            % Add to serving cell load
            servingCellIdx = find([cells.id] == ues(ueIdx).servingCell, 1);
            if ~isempty(servingCellIdx)
                cells(servingCellIdx).currentLoad = cells(servingCellIdx).currentLoad + trafficDemand;
                cells(servingCellIdx).connectedUEs(end+1) = ues(ueIdx).id;
            end
        else
            ues(ueIdx).trafficDemand = 0;
            ues(ueIdx).sessionActive = false;
        end
    end
end