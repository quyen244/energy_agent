
function [cells, ues] = energySavingDecision(cells, simParams, ues, ESAgent, currentTime)
    if nargin < 5
        currentTime = 0;
    end
    
    fprintf('Running Energy Saving xApp decision with power control...\n');
    
    prevState = [];
    if ~isempty(ESAgent) && ESAgent.isInitialized && ~isempty(ESAgent.lastState)
        prevState = ESAgent.lastState;
    end
    
    currentState = createRLState(cells, ues, currentTime, simParams);
    if ~isempty(ESAgent) && ESAgent.isInitialized
        actions = ESAgent.getAction(currentState, currentTime);

        
        for cellIdx = 1:length(cells)
            cellId = cells(cellIdx).id;
            actionField = sprintf('cell_%d_power_ratio', cellId);
            
            if isfield(actions, actionField)
                powerRatio = actions.(actionField);                
                newTxPower = cells(cellIdx).minTxPower + powerRatio * (cells(cellIdx).maxTxPower - cells(cellIdx).minTxPower);
                prevTxPower = cells(cellIdx).txPower;
                cells(cellIdx).txPower = newTxPower;
                
                if newTxPower <= cells(cellIdx).minTxPower + 1 
                    logMsg = sprintf('Step %d/%d: RL Agent: Setting cell %d to minimum power (%.1f dBm)\n', currentTime, simParams.simTime, cellId, newTxPower);
                    fprintf(logMsg);
                    if ~isempty(simParams.agentLogFile)
                        logToFile(simParams.agentLogFile, currentTime, logMsg);
                    end
                elseif abs(newTxPower - prevTxPower) >= 0.001 
                    logMsg = sprintf('Step %d/%d: RL Agent: Adjusting cell %d power from %.1f to %.1f dBm\n', currentTime, simParams.simTime, cellId, prevTxPower, newTxPower);
                    fprintf(logMsg);
                    if ~isempty(simParams.agentLogFile)
                        logToFile(simParams.agentLogFile, currentTime, logMsg);
                    end
                end
            end
        end
        
        if ~isempty(prevState)
            newState = createRLState(cells, ues, currentTime, simParams);            
            isDone = (currentTime >= simParams.simTime);
            ESAgent.updateAgent(prevState, ESAgent.lastAction,newState, isDone);
        end
    else
        fprintf('RL Agent not initialized. Skipping power adjustment.\n');
    end
end