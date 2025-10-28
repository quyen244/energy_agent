function simResults = runLoop(cells, ues, simParams, ESAgent, seed)
    simTime = simParams.simTime;
    timeStep = simParams.timeStep;
    numSteps = simTime / timeStep;
    
    simResults = struct();
    simResults.handoverEvents = struct('ueId', {}, 'cellSource', {}, 'cellTarget', {}, ...
                    'rsrpSource', {}, 'rsrpTarget', {}, ...
                    'rsrqSource', {}, 'rsrqTarget', {}, ...
                    'sinrSource', {}, 'sinrTarget', {}, ...
                    'a3Offset', {}, 'ttt', {}, ...
                    'hoSuccess', {}, 'timestamp', {});
    
    simResults.energyMetrics = struct('time', {}, 'totalEnergy', {}, 'instantaneousPower', {}, 'activeCells', {}, ...
                        'avgDropRate', {}, 'avgLatency', {}, ...
                    'totalTraffic', {}, 'kpiViolations', {}, 'connectedUEs', {}, ...
                    'connectionRate', {}, 'totalHandovers', {}, 'successRate', {}, 'cpuViolations', {}, 'prbViolations', {}, ...
                    'maxCpuUsage', {}, 'maxPrbUsage', {});
    
    simResults.cellStates = struct('time', {}, 'cellParams', {}, 'cumulativeEnergy', {});
    simResults.ueTrajectories = cell(numSteps, 1);
    
    totalHandovers = 0;
    successfulHandovers = 0;
    
    fprintf('Running energy saving simulation for %d steps...\n', numSteps);
    numSteps = round(simTime / timeStep);
    simResults.cellStates = repmat(struct('time', 0, 'cellParams', []), numSteps, 1);
    kpiViolations = 0;
    cumulativeEnergyConsumption = 0; % Track total energy from start (kWh)
    ESAgent.start_scenario();
    for step = 1:numSteps
        currentTime = step * timeStep;
        
        ues = updateUEMobility(ues, timeStep, currentTime, seed);
        
        [ues, cells] = updateTrafficGeneration(ues, cells, currentTime, simParams);
        
        ues = updateSignalMeasurements(ues, cells, simParams.rsrpMeasurementThreshold, currentTime, seed);

        ues = handleDisconnectedUEs(ues, cells, simParams, timeStep, currentTime);
        
        cells = updateCellResourceUsage(cells, ues);
        ues = updateUEDropEvents(ues, cells, simParams.ueLogFile, currentTime);

        totalCurrentPower = 0;
        for cellIdx = 1:length(cells)
            totalCurrentPower = totalCurrentPower + cells(cellIdx).energyConsumption;
        end

        timeHours = timeStep / 3600;
        energyThisStep = (totalCurrentPower / 1000) * timeHours; % kWh
        cumulativeEnergyConsumption = cumulativeEnergyConsumption + energyThisStep;
        [cells, ues] = energySavingDecision(cells, simParams, ues, ESAgent, currentTime);
        [handoverEvents, ues] = checkHandoverEvents(ues, cells, currentTime, simParams, seed);
        
        for eventIdx = 1:length(handoverEvents)
            hoEvent = handoverEvents(eventIdx);
            
            targetCellIdx = find([cells.id] == hoEvent.cellTarget, 1);
            if ~isempty(targetCellIdx)
                totalHandovers = totalHandovers + 1;
                if hoEvent.hoSuccess
                    successfulHandovers = successfulHandovers + 1;
                end
                
                simResults.handoverEvents(end+1) = hoEvent;
                
                hoEventData = struct(...
                    'ue_id', hoEvent.ueId, ...
                    'rsrp_source', hoEvent.rsrpSource, ...
                    'rsrp_target', hoEvent.rsrpTarget, ...
                    'rsrq_source', hoEvent.rsrqSource, ...
                    'rsrq_target', hoEvent.rsrqTarget, ...
                    'sinr_source', hoEvent.sinrSource, ...
                    'sinr_target', hoEvent.sinrTarget, ...
                    'a3_offset', hoEvent.a3Offset, ...
                    'ttt', hoEvent.ttt, ...
                    'cell_source', hoEvent.cellSource, ...
                    'cell_target', hoEvent.cellTarget, ...
                    'ho_success', hoEvent.hoSuccess ...
                );
                logHandoverEvent(simParams.handoverLogFile, currentTime, hoEventData);
            else
                fprintf('Handover failed: Target cell %d is inactive\n', hoEvent.cellTarget);
                totalHandovers = totalHandovers + 1;
            end
        end
        
        ueState = captureUEState(ues, currentTime);
        simResults.ueTrajectories{step} = ueState;
        
        if mod(step, 10) == 0
            energyMetrics = computeEnergySavingMetrics(ues, cells, simParams);
            energyMetrics.time = currentTime;
            energyMetrics.totalEnergy = cumulativeEnergyConsumption;
            energyMetrics.instantaneousPower = totalCurrentPower;
            energyMetrics.totalHandovers = totalHandovers;
            energyMetrics.successRate = successfulHandovers / max(1, totalHandovers);
            simResults.energyMetrics(end+1) = energyMetrics;
            logMsg = sprintf('Step %d/%d: Total Energy: %.3f kWh, Total Current Power: %.1f kW, Drop Rate: %.2f%%%%', ...
                step, numSteps, cumulativeEnergyConsumption, totalCurrentPower/1000, ...
                energyMetrics.avgDropRate);
            fprintf(logMsg + "\n");

            if energyMetrics.avgDropRate > simParams.dropCallThreshold
                fprintf('❌ Drop rate violation: %.2f%% > %.0f%%\n', energyMetrics.avgDropRate, simParams.dropCallThreshold);
                kpiViolations = kpiViolations + 1;
            end

            if energyMetrics.avgLatency > simParams.latencyThreshold
                fprintf('❌ Latency violation: %.1f ms > %.0f ms\n', energyMetrics.avgLatency, simParams.latencyThreshold);
                kpiViolations = kpiViolations + 1;
            end

            if energyMetrics.cpuViolations > 0
                fprintf('❌ CPU usage violations: %d cells > %.0f%% (Max: %.1f%%)\n', energyMetrics.cpuViolations, simParams.cpuThreshold, energyMetrics.maxCpuUsage);
                kpiViolations = kpiViolations + energyMetrics.cpuViolations;
            end

            if energyMetrics.prbViolations > 0
                fprintf('❌ PRB usage violations: %d cells > %.0f%% (Max: %.1f%%)\n', energyMetrics.prbViolations, simParams.prbThreshold, energyMetrics.maxPrbUsage);
                kpiViolations = kpiViolations + energyMetrics.prbViolations;
            end

            if energyMetrics.maxCpuUsage == 0
                fprintf('No active cells detected\n')
                kpiViolations = kpiViolations + 1;
            end

            if energyMetrics.maxPrbUsage == 0
                fprintf('No active cells detected\n')
                kpiViolations = kpiViolations + 1;
            end

            logToFile(simParams.logFile, currentTime, logMsg);
        end
        

        cellParams = arrayfun(@(c) struct('id', c.id, ...
            'cpuUsage', c.cpuUsage, 'prbUsage', c.prbUsage, 'energyConsumption', c.energyConsumption), cells);

        simResults.cellStates(step).time = currentTime;
        simResults.cellStates(step).cellParams = cellParams;
        simResults.cellStates(step).cumulativeEnergy = cumulativeEnergyConsumption;
    end
    ESAgent.end_scenario();
    
    simResults.totalSimulationTime = simTime;
    simResults.totalHandovers = totalHandovers;
    simResults.finalSuccessRate = successfulHandovers / max(1, totalHandovers);
    simResults.cells = cells;
    simResults.ues = ues;
    simResults.simParams = simParams;
    
    finalMetrics = computeEnergySavingMetrics(ues, cells, simParams);
    simResults.finalEnergyConsumption = cumulativeEnergyConsumption;
    simResults.finalDropRate = finalMetrics.avgDropRate;
    simResults.finalLatency = finalMetrics.avgLatency;

    fprintf('\n=== Energy Saving Simulation Results ===\n');
    fprintf('Total Energy Consumption: %.3f kWh\n', cumulativeEnergyConsumption);
    fprintf('Final Power Draw: %.1f kW\n', totalCurrentPower/1000);
    fprintf('Final Active Cells: %d/%d\n', finalMetrics.activeCells, length(cells));
    fprintf('Drop Call Rate: %.2f%% (Target: ≤%.0f%%)\n', finalMetrics.avgDropRate, simParams.dropCallThreshold);
    fprintf('Average Latency: %.1f ms (Target: ≤%.0f ms)\n', finalMetrics.avgLatency, simParams.latencyThreshold);
    fprintf('CPU Usage Violations: %d (Max: %.1f%%)\n', finalMetrics.cpuViolations, finalMetrics.maxCpuUsage);
    fprintf('PRB Usage Violations: %d (Max: %.1f%%)\n', finalMetrics.prbViolations, finalMetrics.maxPrbUsage);
    fprintf('Handovers: %d (Success Rate: %.2f%%)\n', totalHandovers, simResults.finalSuccessRate * 100);
    
    % In the final metrics section, replace the KPI violation checking:
    if finalMetrics.avgDropRate > simParams.dropCallThreshold
        fprintf('❌ Drop rate violation: %.2f%% > %.0f%%\n', finalMetrics.avgDropRate, simParams.dropCallThreshold);
        kpiViolations = kpiViolations + 1;
    end
    if finalMetrics.avgLatency > simParams.latencyThreshold
        fprintf('❌ Latency violation: %.1f ms > %.0f ms\n', finalMetrics.avgLatency, simParams.latencyThreshold);
        kpiViolations = kpiViolations + 1;
    end
    if finalMetrics.cpuViolations > 0
        fprintf('❌ CPU usage violations: %d cells > %.0f%% (Max: %.1f%%)\n', finalMetrics.cpuViolations, simParams.cpuThreshold, finalMetrics.maxCpuUsage);
        kpiViolations = kpiViolations + finalMetrics.cpuViolations;
    end
    if finalMetrics.prbViolations > 0
        fprintf('❌ PRB usage violations: %d cells > %.0f%% (Max: %.1f%%)\n', finalMetrics.prbViolations, simParams.prbThreshold, finalMetrics.maxPrbUsage);
        kpiViolations = kpiViolations + finalMetrics.prbViolations;
    end 
    if finalMetrics.maxCpuUsage == 0
        fprintf('No active cells detected\n')
        kpiViolations = kpiViolations + 1;
    end
    if finalMetrics.maxPrbUsage == 0
        fprintf('No active cells detected\n')
        kpiViolations = kpiViolations + 1;
    end
    
    if kpiViolations == 0
        fprintf('✅ All KPIs met successfully!\n');
    else
        fprintf('❌ %d KPI violations detected\n', kpiViolations);
    end
    
    simResults.kpiViolations = kpiViolations;
    simResults.E_thisinh = cumulativeEnergyConsumption;     
    simResults.violated  = (kpiViolations > 0);   

    if ~isempty(ESAgent) && ESAgent.isInitialized
        finalState = createRLState(cells, ues, simTime, simParams);
        if ~isempty(ESAgent.lastState) && ~isempty(ESAgent.lastAction)
            ESAgent.updateAgent(ESAgent.lastState, ESAgent.lastAction, finalState, true);
        end            
    end
end