function ues = initializeUEs(simParams, sites, seed)
    ueRng = RandStream('mt19937ar', 'Seed', seed + 2000);
    prevStream = RandStream.setGlobalStream(ueRng);

    initializers = getUEInitializers();
    
    if isfield(initializers, simParams.deploymentScenario)
        ues = initializers.(simParams.deploymentScenario)(simParams, sites, seed);
    else
        warning('Unknown deployment scenario: %s. Using default initialization.', simParams.deploymentScenario);
        ues = initializers.default(simParams, sites, seed);
    end

    RandStream.setGlobalStream(prevStream);
    fprintf('Initialized %d UEs for %s scenario\n', length(ues), simParams.deploymentScenario);
end

function initializers = getUEInitializers()    
    initializers = struct();
    initializers.indoor_hotspot = @initializeIndoorHotspotUEs;
    initializers.dense_urban = @initializeDenseUrbanUEs;
    initializers.rural = @initializeRuralUEs;
    initializers.urban_macro = @initializeUrbanMacroUEs;
    initializers.high_speed = @initializeHighSpeedUEs;
    initializers.extreme_rural = @initializeExtremeRuralUEs; 
    initializers.default = @initializeDefaultUEs;
end

function ues = initializeIndoorHotspotUEs(simParams, sites, seed)    
    numUEs = simParams.numUEs;
    mobilityConfig = getIndoorMobilityConfig();
    spatialConfig = getIndoorSpatialConfig();
    
    ues = [];
    for ueIdx = 1:numUEs
        position = generateIndoorPosition(spatialConfig, sites);
        mobilityParams = selectMobilityPattern(mobilityConfig);
        
        newUE = createUEStruct(ueIdx, position.x, position.y, ...
                              mobilityParams.velocity, mobilityParams.direction, ...
                              mobilityParams.pattern, simParams, seed);
        
        if isempty(ues)
            ues = newUE;
        else
            ues(end+1) = newUE;
        end
    end
end

function ues = initializeDenseUrbanUEs(simParams, sites, seed)    
    numUEs = simParams.numUEs;
    indoorRatio = getFieldOrDefault(simParams, 'indoorRatio', 0.8);
    
    indoorUEs = round(numUEs * indoorRatio);
    outdoorUEs = numUEs - indoorUEs;
    
    ues = [];
    ueIdx = 1;
    
    % Indoor UEs
    indoorConfig = getDenseUrbanIndoorConfig(simParams);
    for i = 1:indoorUEs
        position = generateUrbanPosition(sites, indoorConfig.positioning);
        mobilityParams = selectMobilityPattern(indoorConfig.mobility);
        
        newUE = createUEStruct(ueIdx, position.x, position.y, ...
                              mobilityParams.velocity, mobilityParams.direction, ...
                              mobilityParams.pattern, simParams, seed);
        
        if isempty(ues)
            ues = newUE;
        else
            ues(end+1) = newUE;
        end
        ueIdx = ueIdx + 1;
    end
    
    outdoorConfig = getDenseUrbanOutdoorConfig(simParams);
    for i = 1:outdoorUEs
        position = generateUrbanPosition(sites, outdoorConfig.positioning);
        mobilityParams = selectMobilityPattern(outdoorConfig.mobility);
        
        newUE = createUEStruct(ueIdx, position.x, position.y, ...
                              mobilityParams.velocity, mobilityParams.direction, ...
                              mobilityParams.pattern, simParams, seed);
        
        if isempty(ues)
            ues = newUE;
        else
            ues(end+1) = newUE;
        end
        ueIdx = ueIdx + 1;
    end
end

function ues = initializeRuralUEs(simParams, sites, seed)    
    numUEs = simParams.numUEs;
    mobilityConfig = getRuralMobilityConfig(simParams);
    spatialConfig = getRuralSpatialConfig(simParams);
    
    ues = [];
    for ueIdx = 1:numUEs
        position = generateRuralPosition(sites, spatialConfig);
        mobilityParams = selectMobilityPattern(mobilityConfig);
        
        newUE = createUEStruct(ueIdx, position.x, position.y, ...
                              mobilityParams.velocity, mobilityParams.direction, ...
                              mobilityParams.pattern, simParams, seed);
        
        if isempty(ues)
            ues = newUE;
        else
            ues(end+1) = newUE;
        end
    end
end

function ues = initializeUrbanMacroUEs(simParams, sites, seed)    
    numUEs = simParams.numUEs;
    mobilityConfig = getUrbanMacroMobilityConfig(simParams);
    spatialConfig = getUrbanMacroSpatialConfig(simParams);
    
    ues = [];
    for ueIdx = 1:numUEs
        position = generateUrbanMacroPosition(sites, spatialConfig);
        mobilityParams = selectMobilityPattern(mobilityConfig);
        
        newUE = createUEStruct(ueIdx, position.x, position.y, ...
                              mobilityParams.velocity, mobilityParams.direction, ...
                              mobilityParams.pattern, simParams, seed);
        
        if isempty(ues)
            ues = newUE;
        else
            ues(end+1) = newUE;
        end
    end
end

function ues = initializeHighSpeedUEs(simParams, sites, seed)
    numUEs = simParams.numUEs;
    trainLength = getFieldOrDefault(simParams, 'trainLength', 200);
    trackLength = getFieldOrDefault(simParams, 'trackLength', 10000);
    
    trainStartX = -trackLength / 2;
    trainY = 0; 
    
    % Velocity: 500 km/h = 138.89 m/s
    velocity = simParams.ueSpeed / 3.6;
    
    ues = [];
    for ueIdx = 1:numUEs
        positionInTrain = (ueIdx - 1) / max(1, numUEs - 1) * trainLength;
        x = trainStartX + positionInTrain;
        y = trainY + (rand() - 0.5) * 4; % Small variation across train width (~4m)
        
        newUE = createUEStruct(ueIdx, x, y, ...
                              velocity, 0, ... % Direction = 0 (along positive x-axis)
                              'high_speed_train', simParams, seed);
        
        newUE.inTrain = true;
        newUE.trainStartX = trainStartX;
        newUE.trackLength = trackLength;
        newUE.positionInTrain = positionInTrain;
        
        if isempty(ues)
            ues = newUE;
        else
            ues(end+1) = newUE;
        end
    end
end

function ues = initializeExtremeRuralUEs(simParams, sites, seed)    
    numUEs = simParams.numUEs;
    mobilityConfig = getExtremeRuralMobilityConfig(simParams);
    spatialConfig = getExtremeRuralSpatialConfig(simParams);
    
    ues = [];
    for ueIdx = 1:numUEs
        position = generateExtremeRuralPosition(sites, spatialConfig);
        mobilityParams = selectMobilityPattern(mobilityConfig);
        
        newUE = createUEStruct(ueIdx, position.x, position.y, ...
                              mobilityParams.velocity, mobilityParams.direction, ...
                              mobilityParams.pattern, simParams, seed);
        
        if isempty(ues)
            ues = newUE;
        else
            ues(end+1) = newUE;
        end
    end
end

function ues = initializeDefaultUEs(simParams, sites, seed)    
    numUEs = simParams.numUEs;
    mobilityConfig = getDefaultMobilityConfig(simParams);
    spatialConfig = getDefaultSpatialConfig(simParams);
    
    ues = [];
    for ueIdx = 1:numUEs
        position = generateDefaultPosition(sites, spatialConfig);
        mobilityParams = selectMobilityPattern(mobilityConfig);
        
        newUE = createUEStruct(ueIdx, position.x, position.y, ...
                              mobilityParams.velocity, mobilityParams.direction, ...
                              mobilityParams.pattern, simParams, seed);
        
        if isempty(ues)
            ues = newUE;
        else
            ues(end+1) = newUE;
        end
    end
end

function config = getIndoorMobilityConfig()    
    config = struct();
    config.patterns = {'stationary', 'slow_walk', 'normal_walk'};
    config.velocities = [0, 0.5, 1.5];
    config.weights = [0.4, 0.4, 0.2];
end

function config = getIndoorSpatialConfig()    
    config = struct();
    config.bounds = struct('minX', 10, 'maxX', 110, 'minY', 5, 'maxY', 45);
    config.avoidanceRadius = 5; 
    config.maxAttempts = 100;
end

function config = getDenseUrbanIndoorConfig(simParams)
    config = struct();
    config.mobility = struct();
    config.mobility.patterns = {'indoor_pedestrian'};
    config.mobility.velocities = [simParams.ueSpeed / 3.6];
    config.mobility.weights = [1.0];
    
    config.positioning = struct();
    config.positioning.maxDistance = 30;
    config.positioning.distribution = 'normal';
end

function config = getDenseUrbanOutdoorConfig(simParams)    
    config = struct();
    config.mobility = struct();
    config.mobility.patterns = {'outdoor_vehicle'};
    config.mobility.velocities = [getFieldOrDefault(simParams, 'outdoorSpeed', 30) / 3.6];
    config.mobility.weights = [1.0];
    
    config.positioning = struct();
    config.positioning.minDistance = 50;
    config.positioning.maxDistance = 150;
    config.positioning.distribution = 'uniform';
end

function config = getRuralMobilityConfig(simParams)    
    config = struct();
    config.patterns = {'stationary', 'pedestrian', 'slow_vehicle', 'fast_vehicle'};
    config.velocities = [0, 1.0, simParams.ueSpeed/3.6, simParams.ueSpeed/3.6];
    config.weights = [0.1, 0.4, 0.3, 0.2];
end

function config = getRuralSpatialConfig(simParams)    
    config = struct();
    config.maxRadius = simParams.isd * 3; 
    config.distribution = 'clustered_uniform'; 
    config.clusterProbability = 0.6;
    config.clusterRadius = 200;
end

function config = getUrbanMacroMobilityConfig(simParams)
    config = struct();
    config.patterns = {'pedestrian', 'slow_vehicle', 'vehicle'};
    config.velocities = [1.5, simParams.ueSpeed/3.6, simParams.ueSpeed/3.6];
    config.weights = [0.6, 0.2, 0.2]; 
end

function config = getUrbanMacroSpatialConfig(simParams)
    config = struct();
    config.maxRadius = simParams.cellRadius * 1.5;
    config.distribution = 'mixed';
    config.indoorRatio = getFieldOrDefault(simParams, 'indoorRatio', 0.8);
end

function config = getExtremeRuralMobilityConfig(simParams)    
    config = struct();
    config.patterns = {'stationary', 'slow_vehicle', 'fast_vehicle', 'extreme_vehicle'};
    config.velocities = [0, 10.0, 25.0, simParams.ueSpeed/3.6];  % Up to 160 km/h
    config.weights = [0.2, 0.3, 0.3, 0.2];
end

function config = getExtremeRuralSpatialConfig(simParams)    
    config = struct();
    config.maxRadius = simParams.cellRadius * 0.8;  % Very large coverage area
    config.distribution = 'very_sparse';
    config.clusterProbability = 0.9;  % Low clustering
    config.clusterRadius = 500;  % Larger clusters
end

function config = getDefaultMobilityConfig(simParams)
    config = struct();
    config.patterns = {'stationary', 'pedestrian', 'slow_vehicle', 'fast_vehicle', 'vehicle'};
    config.velocities = [0, 1.5, 5.0, 15.0, 10.0];
    config.weights = [0.2, 0.2, 0.2, 0.2, 0.2];
end

function config = getDefaultSpatialConfig(simParams)    
    config = struct();
    config.maxRadius = simParams.isd * sqrt(simParams.numSites) / (2 * pi);
    config.distribution = 'uniform';
end

function position = generateIndoorPosition(spatialConfig, sites)    
    bounds = spatialConfig.bounds;
    avoidanceRadius = spatialConfig.avoidanceRadius;
    maxAttempts = spatialConfig.maxAttempts;
    
    validPosition = false;
    attempts = 0;
    
    while ~validPosition && attempts < maxAttempts
        x = bounds.minX + rand() * (bounds.maxX - bounds.minX);
        y = bounds.minY + rand() * (bounds.maxY - bounds.minY);
        
        validPosition = true;
        for siteIdx = 1:length(sites)
            distance = sqrt((x - sites(siteIdx).x)^2 + (y - sites(siteIdx).y)^2);
            if distance < avoidanceRadius
                validPosition = false;
                break;
            end
        end
        attempts = attempts + 1;
    end
    
    if ~validPosition
        x = (bounds.minX + bounds.maxX) / 2;
        y = (bounds.minY + bounds.maxY) / 2;
    end
    
    position = struct('x', x, 'y', y);
end

function position = generateUrbanPosition(sites, posConfig)    
    siteIdx = randi(length(sites));
    site = sites(siteIdx);
    
    angle = rand() * 2 * pi;
    
    if strcmp(posConfig.distribution, 'normal')
        distance = abs(randn()) * posConfig.maxDistance;
    else
        minDist = getFieldOrDefault(posConfig, 'minDistance', 0);
        maxDist = posConfig.maxDistance;
        distance = minDist + rand() * (maxDist - minDist);
    end
    
    x = site.x + distance * cos(angle);
    y = site.y + distance * sin(angle);
    
    position = struct('x', x, 'y', y);
end

function position = generateRuralPosition(sites, spatialConfig)    
    if rand() < spatialConfig.clusterProbability
        siteIdx = randi(length(sites));
        site = sites(siteIdx);
        
        angle = rand() * 2 * pi;
        distance = rand() * spatialConfig.clusterRadius;
        
        x = site.x + distance * cos(angle);
        y = site.y + distance * sin(angle);
    else
        angle = rand() * 2 * pi;
        radius = spatialConfig.maxRadius * sqrt(rand());
        
        x = radius * cos(angle);
        y = radius * sin(angle);
    end
    
    position = struct('x', x, 'y', y);
end

function position = generateUrbanMacroPosition(sites, spatialConfig)    
    if rand() < spatialConfig.indoorRatio
        siteIdx = randi(length(sites));
        site = sites(siteIdx);
        
        angle = rand() * 2 * pi;
        distance = abs(randn()) * (spatialConfig.maxRadius * 0.3);
        
        x = site.x + distance * cos(angle);
        y = site.y + distance * sin(angle);
    else
        angle = rand() * 2 * pi;
        radius = spatialConfig.maxRadius * sqrt(rand());
        
        x = radius * cos(angle);
        y = radius * sin(angle);
    end
    
    position = struct('x', x, 'y', y);
end

function position = generateExtremeRuralPosition(sites, spatialConfig)    
    % Very sparse distribution - users can be very far from sites
    if rand() < spatialConfig.clusterProbability
        % Small cluster near a random site
        siteIdx = randi(length(sites));
        site = sites(siteIdx);
        
        angle = rand() * 2 * pi;
        distance = rand() * spatialConfig.clusterRadius;
        
        x = site.x + distance * cos(angle);
        y = site.y + distance * sin(angle);
    else
        % Random position in very large area
        angle = rand() * 2 * pi;
        radius = spatialConfig.maxRadius * sqrt(rand());  % Uniform in area
        
        x = radius * cos(angle);
        y = radius * sin(angle);
    end
    
    position = struct('x', x, 'y', y);
end

function position = generateDefaultPosition(sites, spatialConfig)    
    angle = rand() * 2 * pi;
    radius = spatialConfig.maxRadius * sqrt(rand());
    
    x = radius * cos(angle);
    y = radius * sin(angle);
    
    position = struct('x', x, 'y', y);
end

function mobilityParams = selectMobilityPattern(mobilityConfig)    
    randVal = rand();
    cumWeights = cumsum(mobilityConfig.weights);
    patternIdx = find(randVal <= cumWeights, 1);
    
    mobilityParams = struct();
    mobilityParams.pattern = mobilityConfig.patterns{patternIdx};
    mobilityParams.velocity = mobilityConfig.velocities(patternIdx);
    mobilityParams.direction = rand() * 2 * pi;
end

function ue = createUEStruct(ueId, x, y, velocity, direction, mobilityPattern, simParams, seed)    
    ue = struct(...
        'id', ueId, ...
        'x', x, ...
        'y', y, ...
        'velocity', velocity, ...
        'direction', direction, ...
        'mobilityPattern', mobilityPattern, ...
        'servingCell', NaN, ...
        'rsrp', NaN, ...
        'rsrq', NaN, ...
        'sinr', NaN, ...
        'neighborMeasurements', [], ...
        'hoTimer', 0, ...
        'stepCounter', 0, ...
        'lastDirectionChange', 0, ...
        'pauseTimer', 0, ...
        'connectionTimer', 0, ...
        'disconnectionTimer', 0, ...
        'lastServingRsrp', NaN, ...
        'trafficDemand', 0, ...
        'qosLatency', 0, ...
        'sessionActive', false, ...
        'dropCount', 0, ...
        'rngS', seed + ueId * 100, ...
        'deploymentScenario', simParams.deploymentScenario, ...
        'handoverHistory', struct('ueId', {}, 'cellSource', {}, 'cellTarget', {}, ...
                     'rsrpSource', {}, 'rsrpTarget', {}, ...
                     'rsrqSource', {}, 'rsrqTarget', {}, ...
                     'sinrSource', {}, 'sinrTarget', {}, ...
                     'a3Offset', {}, 'ttt', {}, ...
                     'hoSuccess', {}, 'timestamp', {}) ...
    );
end

function value = getFieldOrDefault(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end