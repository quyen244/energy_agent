function simResults = run5GSimulation(scenarioInput, seed)
    if nargin < 1 || isempty(scenarioInput)
        scenarioInput = 'indoor_hotspot';
    end
    if nargin < 2 || isempty(seed)
        seed = 42;
    end

    rng(seed, 'twister');

    simParams = loadScenarioConfig(scenarioInput);

    if ~exist('logs', 'dir')
        mkdir('logs');
    end
    
    timestamp = datestr(datetime('now'), 'yyyymmdd_HHMMSS');
    
    simParams.logFile = sprintf('logs/%s_energy_saving.log', timestamp);
    simParams.ueLogFile = sprintf('logs/%s_ue.log', timestamp);
    simParams.cellLogFile = sprintf('logs/%s_cell.log', timestamp);
    simParams.agentLogFile = sprintf('logs/%s_agent.log', timestamp);
    simParams.handoverLogFile = sprintf('logs/%s_handover.log', timestamp);

    try
        fid = fopen(simParams.logFile, 'w');
        if fid == -1
            error('Could not create log file: %s', simParams.logFile);
        end
        fprintf(fid, 'Simulation started: %s\n', datestr(now));
        fclose(fid);
        
        try
            ESAgent = ESInterface('n_cells', simParams.numSites * simParams.numSectors, ...
                'max_time', simParams.simTime / simParams.timeStep, 'num_ue', simParams.numUEs);
        catch
            fprintf('Failed to initialize ESAgent with GPU, terminating simulation\n');
            simResults = [];
            return;
        end

        simResults = simulate5GNetwork(simParams, ESAgent, seed);
    catch ME
        fprintf('Simulation failed: %s\n', ME.message);
        rethrow(ME);
    end
end