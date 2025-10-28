function simResults = simulate5GNetwork(simParams, ESAgent, seed)
    baseDir = fileparts(mfilename('fullpath'));  
    addpath(fullfile(baseDir, 'simCore'));        
    addpath(fullfile(baseDir, 'utils'));
    addpath(fullfile(baseDir, 'agents'));
    
    fprintf('Deployment: %s\n', simParams.deploymentScenario);
    fprintf('Sites: %d, Frequency: %.1f GHz, ISD: %.1f m\n', ...
            simParams.numSites, simParams.carrierFrequency/1e9, simParams.isd);

    sites = createLayout(simParams, seed);
    cells = configureCells(sites, simParams);
    ues = initializeUEs(simParams, sites, seed);

    simResults = runLoop(cells, ues, simParams, ESAgent, seed);
    fprintf('Simulation completed!\n');
end