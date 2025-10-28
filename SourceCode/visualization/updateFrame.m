function updateFrame(fig)
    % Update the visualization for current frame
    
    animData = getappdata(fig, 'animData');
    uePositions = getappdata(fig, 'uePositions');
    sites = getappdata(fig, 'sites');
    cells = getappdata(fig, 'cells');
    coverageData = getappdata(fig, 'coverageData');
    simResults = getappdata(fig, 'simResults');
    numSteps = getappdata(fig, 'numSteps');
    ax = getappdata(fig, 'ax');
    frameText = getappdata(fig, 'frameText');

    currentFrame = animData.currentFrame;
    currentTimeData = uePositions{currentFrame};
    
    % Update frame counter
    set(frameText, 'String', sprintf('Frame: %d / %d', animData.currentFrame, numSteps));
    
    % Clear and redraw
    cla(ax);
    hold(ax, 'on');
    
    % Store current axis limits
    if animData.currentFrame > 1
        xlim_curr = xlim(ax);
        ylim_curr = ylim(ax);
    end
    
    % Color map for sites
    numSites = length(sites);
    colors = lines(numSites);
    
    % Plot coverage contours if enabled (unchanged)
    if animData.showCoverage
        for cellIdx = 1:length(cells)
            currentCell = cells(cellIdx);
            siteId = currentCell.siteId;
            
            coverage = coverageData{cellIdx};
            
            % Check if coverage data is valid
            if isfield(coverage, 'RSRP') && ~isempty(coverage.RSRP) && ...
               isfield(coverage, 'X') && ~isempty(coverage.X) && ...
               isfield(coverage, 'Y') && ~isempty(coverage.Y)
                
                rsrpLevels = [-100, -90, -80, -70];
                rsrpMin = min(coverage.RSRP(:));
                rsrpMax = max(coverage.RSRP(:));
                
                % Only keep levels that are within the RSRP range
                validLevels = rsrpLevels(rsrpLevels > rsrpMin & rsrpLevels < rsrpMax);
                
                % Only plot contours if we have valid levels
                if ~isempty(validLevels) && length(validLevels) >= 2
                    try
                        contour(ax, coverage.X, coverage.Y, coverage.RSRP, validLevels, ...
                               'Color', colors(siteId, :), 'LineWidth', 0.8, 'LineStyle', '--');
                    catch ME
                        warning('Failed to plot contours for cell %d: %s', currentCell.id, ME.message);
                    end
                elseif ~isempty(validLevels) && isscalar(validLevels)
                    try
                        contour(ax, coverage.X, coverage.Y, coverage.RSRP, validLevels, ...
                            'Color', colors(siteId, :), 'LineWidth', 0.8, 'LineStyle', '--');
                    catch ME
                        continue;
                    end
                end
            end
        end
    end
    
    % Plot sites and sectors (with active/inactive visuals)
    for siteIdx = 1:length(sites)
        site = sites(siteIdx);
        siteColor = colors(siteIdx, :);
     
        siteCells = cells([cells.siteId] == siteIdx);
        for sectorIdx = 1:length(siteCells)
            currentCell = siteCells(sectorIdx);

            % Check if this is an omnidirectional indoor cell
            isOmnidirectional = isfield(currentCell, 'isOmnidirectional') && currentCell.isOmnidirectional;
            
            if isOmnidirectional
                % Indoor omnidirectional cell - position at site location
                cellPosX = site.x;
                cellPosY = site.y;
                
               
                drawColor = siteColor;
                fillAlpha = 0.20;
                
                % Draw omnidirectional coverage circle
                if animData.showCoverage
                    theta = linspace(0, 2*pi, 60);
                    circleRadius = 60; % Indoor coverage radius
                    circleX = cellPosX + circleRadius * cos(theta);
                    circleY = cellPosY + circleRadius * sin(theta);
                    plot(ax, circleX, circleY, '--', 'Color', drawColor, 'LineWidth', 1);
                    
                    % Fill circle with transparency
                    patch(ax, circleX, circleY, drawColor, 'EdgeColor', 'none', 'FaceAlpha', fillAlpha);
                end
                
                % Cell hub marker (larger for omnidirectional)
                markerSize = 15;
                plot(ax, cellPosX, cellPosY, 'o', 'MarkerSize', markerSize, ...
                    'MarkerFaceColor', drawColor, 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
                
                % Cell label positioned directly above the cell
                if animData.showLabels
                    labelX = cellPosX;
                    labelY = cellPosY; % Fixed offset above cell
                    text(ax, labelX, labelY, sprintf('C%d', currentCell.id), ...
                        'FontSize', 9, 'Color', 'white', 'FontWeight', 'bold', ...
                        'BackgroundColor', drawColor, 'EdgeColor', 'black', ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                end    
            else
                sectorRadius = 30; 
                azimuthRad = currentCell.azimuth * pi / 180;
                cellPosX = site.x + sectorRadius * cos(azimuthRad);
                cellPosY = site.y + sectorRadius * sin(azimuthRad);
            
                sectorLength = 150;
                
                % Beam coverage area (3dB beamwidth ~65 degrees for typical antenna)
                beamAngle = 32.5 * pi / 180; % Half of 65 degrees
                beam1X = cellPosX + sectorLength * 0.8 * cos(azimuthRad - beamAngle);
                beam1Y = cellPosY + sectorLength * 0.8 * sin(azimuthRad - beamAngle);
                beam2X = cellPosX + sectorLength * 0.8 * cos(azimuthRad + beamAngle);
                beam2Y = cellPosY + sectorLength * 0.8 * sin(azimuthRad + beamAngle);
                
               
                % Active cell visual
                drawColor = siteColor;
                fillAlpha = 0.20;
                lineStyle = '--';
                
                % Beam edge lines (use drawColor and lineStyle)
                plot(ax, [cellPosX, beam1X], [cellPosY, beam1Y], ...
                    'Color', drawColor, 'LineWidth', 1, 'LineStyle', lineStyle);
                plot(ax, [cellPosX, beam2X], [cellPosY, beam2Y], ...
                    'Color', drawColor, 'LineWidth', 1, 'LineStyle', lineStyle);
                
                % Draw sector coverage arc as a filled patch to indicate active/inactive
                if animData.showCoverage
                    theta = linspace(azimuthRad - beamAngle, azimuthRad + beamAngle, 40);
                    arcRadius = sectorLength * 0.8;
                    arcX = cellPosX + arcRadius * cos(theta);
                    arcY = cellPosY + arcRadius * sin(theta);
                    % Close the polygon (center -> arc -> center)
                    px = [cellPosX, arcX, cellPosX];
                    py = [cellPosY, arcY, cellPosY];
                    % Draw patch with no edge and set alpha
                    patch(ax, px, py, drawColor, 'EdgeColor', 'none', 'FaceAlpha', fillAlpha);
                    
                    % Optional arc outline for clarity (use slightly darker line)
                    plot(ax, arcX, arcY, 'LineStyle', '-', 'Color', max(0, drawColor*0.7), 'LineWidth', 0.6);
                end
                
                % Cell hub marker (small filled circle) to indicate on/off
                markerSize = 12;
                plot(ax, cellPosX, cellPosY, 'o', 'MarkerSize', markerSize, ...
                    'MarkerFaceColor', drawColor, 'MarkerEdgeColor', 'k', 'LineWidth', 0.8);
                
                % Cell label with better positioning and adaptive background
                if animData.showLabels
                    labelX = cellPosX + 25 * cos(azimuthRad);
                    labelY = cellPosY + 25 * sin(azimuthRad);
                    % Make label background the same drawColor (darker if inactive)
                    textColor = 'white';
                    text(ax, labelX, labelY, sprintf('C%d', currentCell.id), ...
                        'FontSize', 9, 'Color', textColor, 'FontWeight', 'bold', ...
                        'BackgroundColor', drawColor, 'EdgeColor', 'black', ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
                end
            end
        end
    end
    
    % Plot UEs
    if isfield(currentTimeData, 'ueStates') && ~isempty(currentTimeData.ueStates)
        ueStates = currentTimeData.ueStates;
        for ueIdx = 1:length(ueStates)
            ue = ueStates(ueIdx);
            % Plot UE based on stored state
            if isfield(ue, 'servingCell') && ue.servingCell > 0
                % Connected UE
                servingCellIdx = find([cells.id] == ue.servingCell, 1);
                if ~isempty(servingCellIdx)
                    servingCell = cells(servingCellIdx);
                    servingColor = colors(servingCell.siteId, :);
                    
                    % Plot UE marker
                    plot(ax, ue.x, ue.y, 'o', 'MarkerSize', 8, 'MarkerFaceColor', servingColor, 'MarkerEdgeColor', 'k');
                    
                    % Display RSRP information
                    if isfield(ue, 'rsrp')
                        text(ax, ue.x, ue.y, sprintf('UE%d→C%d\n%.0fdBm', ue.id, ue.servingCell, ue.rsrp), ...
                            'FontSize', 7, 'Color', servingColor, ...
                            'EdgeColor', servingColor, ...
                            'HorizontalAlignment', 'center');
                    end
                    
                    if animData.showConnections
                        servingCell = cells([cells.id] == ue.servingCell);
                        if ~isempty(servingCell)
                            servingCell = servingCell(1);
                            servingSite = sites(servingCell.siteId);
                            
                            % Check if serving cell is omnidirectional
                            isOmnidirectional = isfield(servingCell, 'isOmnidirectional') && servingCell.isOmnidirectional;
                            
                            if isOmnidirectional
                                % Connect to site center for omnidirectional cells
                                cellPosX = servingSite.x;
                                cellPosY = servingSite.y;
                            else
                                % Connect to sector position for directional cells
                                sectorRadius = 30;
                                azimuthRad = servingCell.azimuth * pi / 180;
                                cellPosX = servingSite.x + sectorRadius * cos(azimuthRad);
                                cellPosY = servingSite.y + sectorRadius * sin(azimuthRad);
                            end
                            
                            line(ax, [ue.x, cellPosX], [ue.y, cellPosY], ...
                                'LineStyle', '-', 'Color', servingColor, 'LineWidth', 2);
                            
                            % Add directional arrow on the connection line
                            arrowPos = 0.7; % Position arrow 70% along the line
                            arrowX = ue.x + arrowPos * (cellPosX - ue.x);
                            arrowY = ue.y + arrowPos * (cellPosY - ue.y);
                            plot(ax, arrowX, arrowY, '>', 'Color', servingColor, 'MarkerSize', 6, 'LineWidth', 1.5);
                        end
                    end
                end
            else
                % Disconnected UE
                plot(ax, ue.x, ue.y, 'x', 'MarkerSize', 10, 'MarkerEdgeColor', 'r', 'LineWidth', 3);
                if animData.showLabels && isfield(ue, 'id')
                    text(ax, ue.x, ue.y, sprintf('UE%d', ue.id), ...
                        'FontSize', 8, 'Color', 'r', 'FontWeight', 'bold', ...
                        'BackgroundColor', 'white', 'EdgeColor', 'r');
                end
            end
        end
    end
    
    % Add title with time information
    currentTime = (animData.currentFrame-1) * 1; % Assuming 1 second time step
    title(ax, sprintf('5G Network Topology - Time: %d seconds (Frame %d/%d)', ...
          currentTime, animData.currentFrame, numSteps), 'FontSize', 14, 'FontWeight', 'bold');
    
    % Set axis properties
    xlabel(ax, 'X Position (m)', 'FontSize', 12);
    ylabel(ax, 'Y Position (m)', 'FontSize', 12);
    grid(ax, 'on');
    axis(ax, 'equal');
    
    if animData.currentFrame == 1 || ~exist('xlim_curr', 'var')
        % Calculate bounds from sites and add margin
        siteX = [sites.x];
        siteY = [sites.y];
        margin = max(abs([siteX, siteY])) * 0.2; % 20% margin
        
        xlim_curr = [min(siteX) - margin, max(siteX) + margin];
        ylim_curr = [min(siteY) - margin, max(siteY) + margin];
    end

    xlim(ax, xlim_curr);
    ylim(ax, ylim_curr);
    % Add statistics and legend if available
    if isfield(simResults, 'performanceMetrics') && ~isempty(simResults.performanceMetrics)
        % Find the closest performance metric entry
        metricTimes = [simResults.performanceMetrics.time];
        [~, closestIdx] = min(abs(metricTimes - currentTime));
        
        if closestIdx <= length(simResults.performanceMetrics)
            metric = simResults.performanceMetrics(closestIdx);
            totalHOs = metric.totalHandovers;
            successRate = metric.successRate * 100;
            avgRSRP = metric.avgRSRP;
            avgSINR = metric.avgSINR;
            
            stats_text = sprintf(['Network Statistics:\n' ...
                                 'Total Handovers: %d\n' ...
                                 'Success Rate: %.1f%%\n' ...
                                 'Avg RSRP: %.1f dBm\n' ...
                                 'Avg SINR: %.1f dB'], ...
                                 totalHOs, successRate, avgRSRP, avgSINR);
            
            text(ax, 0.02, 0.98, stats_text, 'Units', 'normalized', ...
                 'VerticalAlignment', 'top', 'FontSize', 10, ...
                 'BackgroundColor', 'none', 'EdgeColor', 'black', ...
                 'Margin', 5);
        end
    end
    
    % Add legend for RSRP levels
    legend_text = {'RSRP > -70 dBm (Excellent)', ...
                   'RSRP > -85 dBm (Good)', ...
                   'RSRP > -100 dBm (Fair)', ...
                   'RSRP ≤ -100 dBm (Poor)'};
    text(ax, 0.98, 0.98, 'Signal Quality:', 'Units', 'normalized', ...
         'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', ...
         'FontSize', 10, 'FontWeight', 'bold', ...
         'BackgroundColor', 'none', 'EdgeColor', 'black', 'Margin', 3);
    
    for i = 1:length(legend_text)
        text(ax, 0.98, 0.94 - (i-1)*0.04, legend_text{i}, 'Units', 'normalized', ...
             'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', ...
             'FontSize', 9, 'BackgroundColor', 'none', 'EdgeColor', 'none');
    end
    
    hold(ax, 'off');
    drawnow;
end
