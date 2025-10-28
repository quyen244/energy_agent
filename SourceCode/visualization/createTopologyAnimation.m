function createTopologyAnimation(simResults) 
    fprintf('Creating interactive topology viewer...\n');
    
    if ~isfield(simResults, 'cells') || ~isfield(simResults, 'ues')
        error('simResults must contain cells and ues fields');
    end

    cells = simResults.cells;
    uePositions = simResults.ueTrajectories;
    numSteps = length(uePositions);
    
    [sites, cellPositions] = calculateSiteAndCellPositions(cells);
    
    allSiteX = [sites.x];
    allSiteY = [sites.y];
    ueX = []; ueY = [];

    for step = 1:numSteps
        stepData = uePositions{step};
        if ~isempty(stepData) && isfield(stepData, 'ueStates')
            for i = 1:length(stepData.ueStates)
                ueX = [ueX, stepData.ueStates(i).x];
                ueY = [ueY, stepData.ueStates(i).y];
            end
        end
    end
    
    xMin = min([allSiteX, ueX]) - 200;
    xMax = max([allSiteX, ueX]) + 200;
    yMin = min([allSiteY, ueY]) - 200;
    yMax = max([allSiteY, ueY]) + 200;
    
    % Pre-calculate coverage contours
    coverageData = cell(length(cells), 1);
    for cellIdx = 1:length(cells)
        [coverageData{cellIdx}.X, coverageData{cellIdx}.Y, coverageData{cellIdx}.RSRP] = ...
            calculateCoverageContour(cells(cellIdx), sites, xMin, xMax, yMin, yMax);
    end
    
    % Create the interactive viewer
    createViewerGUI(simResults, uePositions, numSteps, sites, cellPositions, ...
                   cells, coverageData, xMin, xMax, yMin, yMax);
end

function [sites, cellPositions] = calculateSiteAndCellPositions(cells)
    % Calculate both site positions and individual cell positions
    
    siteIds = unique([cells.siteId]);
    sites = struct('id', {}, 'x', {}, 'y', {});
    cellPositions = struct('id', {}, 'x', {}, 'y', {});
    
    % Calculate site positions (centers)
    for i = 1:length(siteIds)
        siteId = siteIds(i);
        siteCells = cells([cells.siteId] == siteId);
        
        % Calculate site center as average of sector positions
        siteX = mean([siteCells.x]);
        siteY = mean([siteCells.y]);
        
        sites(i) = struct('id', siteId, 'x', siteX, 'y', siteY);
    end
    
    % Store individual cell positions
    for i = 1:length(cells)
        cellPositions(i) = struct('id', cells(i).id, 'x', cells(i).x, 'y', cells(i).y);
    end
end

function [X, Y, RSRP] = calculateCoverageContour(cell, sites, xMin, xMax, yMin, yMax)
    % Create grid for coverage calculation using proper path loss
    
    gridRes = 40; % Grid resolution (reduced for performance)
    x = linspace(xMin, xMax, gridRes);
    y = linspace(yMin, yMax, gridRes);
    [X, Y] = meshgrid(x, y);
    
    % Use actual cell position for coverage calculation
    cellX = cell.x;
    cellY = cell.y;
    
    % Calculate RSRP at each grid point using same path loss as simulation
    RSRP = zeros(size(X));
    for i = 1:numel(X)
        distance = sqrt((X(i) - cellX)^2 + (Y(i) - cellY)^2);
        if distance < 10
            distance = 10; % Minimum distance
        end
        
        % Calculate angle from cell to grid point
        angle = atan2(Y(i) - cellY, X(i) - cellX) * 180/pi;
        if angle < 0
            angle = angle + 360;
        end
        
        % Apply antenna gain based on cell type
        if isfield(cell, 'isOmnidirectional') && cell.isOmnidirectional
            % Omnidirectional: constant gain in all directions
            antennaGain = 0; % 0 dB gain for omnidirectional
        else
            % Directional: apply 3dB beamwidth pattern
            cellAzimuth = cell.azimuth;
            angleDiff = abs(angle - cellAzimuth);
            if angleDiff > 180
                angleDiff = 360 - angleDiff;
            end
            
            % 3dB beamwidth of ~65 degrees (typical sector antenna)
            if angleDiff <= 32.5
                antennaGain = 0; % Maximum gain in main lobe
            else
                % Simplified pattern: -20dB outside main lobe
                antennaGain = -20;
            end
        end
        
        % Use same path loss calculation as simulation
        fc = cell.frequency / 1e9; % Convert to GHz
        pathLoss = 28.0 + 22*log10(distance) + 20*log10(fc);
        RSRP(i) = cell.txPower - pathLoss + antennaGain;
    end
end
