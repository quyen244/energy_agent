function simParams = loadScenarioConfig(scenarioInput)
    baseDir = fileparts(mfilename('fullpath'));
    scenariosDir = fullfile(baseDir, 'scenarios');
    
    nameMap = getScenarioNameMappings();
    
    jsonPath = resolveScenarioPath(scenarioInput, scenariosDir, nameMap);
    
    simParams = loadAndParseConfig(jsonPath);
    
    simParams = validateAndEnhanceConfig(simParams);
    
    fprintf('Loaded scenario: %s\n', simParams.name);
end

function nameMap = getScenarioNameMappings()    
    nameMap = containers.Map();
    
    % 3GPP Standard scenarios
    nameMap('indoor_hotspot') = 'indoor_hotspot.json';
    nameMap('dense_urban') = 'dense_urban.json';
    nameMap('rural') = 'rural.json';
    nameMap('urban_macro') = 'urban_macro.json';
    nameMap('high_speed') = 'high_speed.json';
    nameMap('extreme_rural') = 'extreme_rural.json'; 
end

function jsonPath = resolveScenarioPath(scenarioInput, scenariosDir, nameMap)    
    if isfile(scenarioInput)
        jsonPath = scenarioInput;
    elseif nameMap.isKey(scenarioInput)
        jsonPath = fullfile(scenariosDir, nameMap(scenarioInput));
    else
        candidate = fullfile(scenariosDir, [scenarioInput '.json']);
        if isfile(candidate)
            jsonPath = candidate;
        else
            availableScenarios = strjoin(keys(nameMap), ', ');
            error('ScenarioConfig:UnknownScenario', ...
                  'Unknown scenario: %s\nAvailable scenarios: %s\nOr provide a valid JSON file path', ...
                  scenarioInput, availableScenarios);
        end
    end
    
    if ~isfile(jsonPath)
        error('ScenarioConfig:FileNotFound', 'JSON scenario file not found: %s', jsonPath);
    end
end

function simParams = loadAndParseConfig(jsonPath)    
    try
        raw = fileread(jsonPath);
        cfg = jsondecode(raw);
        simParams = convertJSONToParams(cfg);
    catch ME
        if strcmp(ME.identifier, 'MATLAB:jsondecode:InvalidJSON')
            error('ScenarioConfig:InvalidJSON', 'Invalid JSON format in file: %s', jsonPath);
        elseif strcmp(ME.identifier, 'MATLAB:fileread:cannotOpenFile')
            error('ScenarioConfig:CannotRead', 'Cannot read file: %s', jsonPath);
        else
            error('ScenarioConfig:ParseError', 'Failed to parse JSON file %s: %s', jsonPath, ME.message);
        end
    end
end

function simParams = convertJSONToParams(cfg)
    
    simParams = struct();
    
    simParams.name = getFieldOrDefault(cfg, 'name', 'Unnamed Scenario');
    simParams.description = getFieldOrDefault(cfg, 'description', 'No description provided');
    simParams.deploymentScenario = getFieldOrDefault(cfg, 'deploymentScenario', 'custom');
    
    simParams = addNetworkTopologyParams(simParams, cfg);
    
    simParams = addRFParams(simParams, cfg);
    
    simParams = addUserParams(simParams, cfg);
    
    simParams = addPowerParams(simParams, cfg);
    
    simParams = addSimulationParams(simParams, cfg);
    
    simParams = addThresholdParams(simParams, cfg);
    
    simParams = addTrafficParams(simParams, cfg);
    
    simParams = addScenarioSpecificParams(simParams, cfg);
end

function simParams = addNetworkTopologyParams(simParams, cfg)
    simParams.numSites = getFieldOrDefault(cfg, 'numSites', 7);
    simParams.numSectors = getFieldOrDefault(cfg, 'numSectors', 3);
    simParams.isd = getFieldOrDefault(cfg, 'isd', 200);
    simParams.antennaHeight = getFieldOrDefault(cfg, 'antennaHeight', 25);
    simParams.cellRadius = getFieldOrDefault(cfg, 'cellRadius', 200);
end

function simParams = addRFParams(simParams, cfg)
    simParams.carrierFrequency = getFieldOrDefault(cfg, 'carrierFrequency', 3.5e9);
    simParams.systemBandwidth = getFieldOrDefault(cfg, 'systemBandwidth', 100e6);
end

function simParams = addUserParams(simParams, cfg)
    simParams.numUEs = getFieldOrDefault(cfg, 'numUEs', 210);
    simParams.ueSpeed = getFieldOrDefault(cfg, 'ueSpeed', 3);
    simParams.indoorRatio = getFieldOrDefault(cfg, 'indoorRatio', 0.8);
    simParams.outdoorSpeed = getFieldOrDefault(cfg, 'outdoorSpeed', 30);
end

function simParams = addPowerParams(simParams, cfg)
    simParams.minTxPower = getFieldOrDefault(cfg, 'minTxPower', 30);
    simParams.maxTxPower = getFieldOrDefault(cfg, 'maxTxPower', 46);
    simParams.basePower = getFieldOrDefault(cfg, 'basePower', 800);
    simParams.idlePower = getFieldOrDefault(cfg, 'idlePower', 200);
end

function simParams = addSimulationParams(simParams, cfg)
    simParams.simTime = getFieldOrDefault(cfg, 'simTime', 600);
    simParams.timeStep = getFieldOrDefault(cfg, 'timeStep', 1);
end

function simParams = addThresholdParams(simParams, cfg)
    simParams.rsrpServingThreshold = getFieldOrDefault(cfg, 'rsrpServingThreshold', -110);
    simParams.rsrpTargetThreshold = getFieldOrDefault(cfg, 'rsrpTargetThreshold', -100);
    simParams.rsrpMeasurementThreshold = getFieldOrDefault(cfg, 'rsrpMeasurementThreshold', -115);
    simParams.dropCallThreshold = getFieldOrDefault(cfg, 'dropCallThreshold', 1);
    simParams.latencyThreshold = getFieldOrDefault(cfg, 'latencyThreshold', 50);
    simParams.cpuThreshold = getFieldOrDefault(cfg, 'cpuThreshold', 80);
    simParams.prbThreshold = getFieldOrDefault(cfg, 'prbThreshold', 80);
end

function simParams = addTrafficParams(simParams, cfg)    
    simParams.trafficLambda = getFieldOrDefault(cfg, 'trafficLambda', 30);
    simParams.peakHourMultiplier = getFieldOrDefault(cfg, 'peakHourMultiplier', 1.5);
end

function simParams = addScenarioSpecificParams(simParams, cfg)    
    if isfield(cfg, 'layout')
        simParams.layout = cfg.layout;
    end
    
    if isfield(cfg, 'userDistribution')
        simParams.userDistribution = cfg.userDistribution;
    end
    
    if isfield(cfg, 'mobilityModel')
        simParams.mobilityModel = cfg.mobilityModel;
    end
    
    if isfield(cfg, 'maxRadius')
        simParams.maxRadius = cfg.maxRadius;
    end

     % High speed specific parameters
    if isfield(cfg, 'trainLength')
        simParams.trainLength = cfg.trainLength;
    end
    
    if isfield(cfg, 'trackLength')
        simParams.trackLength = cfg.trackLength;
    end
end

function simParams = validateAndEnhanceConfig(simParams)    
    validateBasicParams(simParams);
    
    simParams = addDerivedParams(simParams);
    
    simParams = configureLogging(simParams);
end

function validateBasicParams(simParams)    
    % Check required fields
    requiredFields = {'deploymentScenario', 'numSites', 'numUEs', 'simTime'};
    for i = 1:length(requiredFields)
        field = requiredFields{i};
        if ~isfield(simParams, field)
            error('ScenarioConfig:MissingField', 'Required field missing: %s', field);
        end
    end
    
    % Validate ranges
    if simParams.numSites <= 0
        error('ScenarioConfig:InvalidValue', 'numSites must be positive');
    end
    
    if simParams.numUEs <= 0
        error('ScenarioConfig:InvalidValue', 'numUEs must be positive');
    end
    
    if simParams.simTime <= 0
        error('ScenarioConfig:InvalidValue', 'simTime must be positive');
    end
    
    if simParams.timeStep <= 0 || simParams.timeStep > simParams.simTime
        error('ScenarioConfig:InvalidValue', 'timeStep must be positive and less than simTime');
    end
end

function simParams = addDerivedParams(simParams)    
    simParams.totalSteps = ceil(simParams.simTime / simParams.timeStep);
    
    switch simParams.deploymentScenario
        case 'indoor_hotspot'
            simParams.maxRadius = getFieldOrDefault(simParams, 'maxRadius', 100);
        case 'dense_urban'
            simParams.maxRadius = getFieldOrDefault(simParams, 'maxRadius', 500);
        case 'rural'
            simParams.maxRadius = getFieldOrDefault(simParams, 'maxRadius', 2000);
        case 'urban_macro'
            simParams.maxRadius = getFieldOrDefault(simParams, 'maxRadius', 800);
        case 'high_speed'
            simParams.maxRadius = getFieldOrDefault(simParams, 'maxRadius', 1500);
            simParams.trainLength = getFieldOrDefault(simParams, 'trainLength', 200);
            simParams.trackLength = getFieldOrDefault(simParams, 'trackLength', 10000);
        case 'extreme_rural'  % ADD THIS CASE
            simParams.maxRadius = getFieldOrDefault(simParams, 'maxRadius', 50000);
    end
    
    
    simParams.expectedCells = simParams.numSites * simParams.numSectors;
end

function simParams = configureLogging(simParams)    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    logFileName = sprintf('%s_%s.log', simParams.deploymentScenario, timestamp);
    
    simParams.logFile = logFileName;
    simParams.enableLogging = true;
    simParams.logLevel = getFieldOrDefault(simParams, 'logLevel', 'INFO');
end

function value = getFieldOrDefault(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end