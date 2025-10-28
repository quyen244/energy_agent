function ues = updateUEMobility(ues, timeStep, currentTime, seed, simParams)
    for ueIdx = 1:length(ues)
        ue = ues(ueIdx);
        
        mobilityRng = RandStream('mt19937ar', 'Seed', ue.rngS + floor(currentTime * 1000));
        prevStream = RandStream.setGlobalStream(mobilityRng);
        
        ue.stepCounter = ue.stepCounter + 1;
        
        ue = updateUEPosition(ue, timeStep, currentTime);
        
        if exist('simParams', 'var') && isfield(simParams, 'deploymentScenario')
            ue = enforceScenarioBounds(ue, simParams);
        end
        
        RandStream.setGlobalStream(prevStream);
        ues(ueIdx) = ue;
    end
end

function ue = updateUEPosition(ue, timeStep, currentTime)    
    mobilityHandlers = getMobilityHandlers();
    
    if isfield(mobilityHandlers, ue.mobilityPattern)
        ue = mobilityHandlers.(ue.mobilityPattern)(ue, timeStep, currentTime);
    else
        warning('Unknown mobility pattern: %s. Using pedestrian model.', ue.mobilityPattern);
        ue = mobilityHandlers.pedestrian(ue, timeStep, currentTime);
    end
end

function handlers = getMobilityHandlers()
    handlers = struct();
    handlers.stationary = @handleStationaryMobility;
    handlers.pedestrian = @handlePedestrianMobility;
    handlers.slow_walk = @handleSlowWalkMobility;
    handlers.normal_walk = @handleNormalWalkMobility;
    handlers.fast_walk = @handleFastWalkMobility;
    handlers.slow_vehicle = @handleSlowVehicleMobility;
    handlers.fast_vehicle = @handleFastVehicleMobility;
    handlers.indoor_pedestrian = @handleIndoorPedestrianMobility;
    handlers.indoor_mobile = @handleIndoorMobileMobility;
    handlers.outdoor_vehicle = @handleOutdoorVehicleMobility;
    handlers.vehicle = @handleVehicleMobility;
    handlers.high_speed_train = @handleHighSpeedTrainMobility;
    handlers.extreme_vehicle = @handleExtremeVehicleMobility;
end


function ue = handleStationaryMobility(ue, timeStep, currentTime)    
    if rand() < 0.05 % 5% chance of small movement
        ue.x = ue.x + (rand() - 0.5) * 2; % ±1m
        ue.y = ue.y + (rand() - 0.5) * 2;
    end
end

function ue = handlePedestrianMobility(ue, timeStep, currentTime)    
    distance = ue.velocity * timeStep;
    
    if ue.pauseTimer > 0
        ue.pauseTimer = ue.pauseTimer - timeStep;
    elseif rand() < 0.1 % 10% chance to pause
        ue.pauseTimer = 5 + rand() * 10; % Pause 5-15 seconds
    elseif rand() < 0.3 % 30% chance to change direction
        ue.direction = ue.direction + (rand() - 0.5) * pi;
        ue = moveUE(ue, distance);
    else
        ue = moveUE(ue, distance);
    end
end

function ue = handleFastVehicleMobility(ue, timeStep, currentTime)    
    distance = ue.velocity * timeStep;    
    if currentTime - ue.lastDirectionChange > 40 + rand() * 20
        ue.direction = ue.direction + (rand() - 0.5) * pi/4;
        ue.lastDirectionChange = currentTime;
    end
    
    ue = moveUE(ue, distance);
end

function ue = handleIndoorPedestrianMobility(ue, timeStep, currentTime)    
    distance = ue.velocity * timeStep;
    
    if ue.pauseTimer > 0
        ue.pauseTimer = ue.pauseTimer - timeStep;
    elseif rand() < 0.15 % 15% chance to pause
        ue.pauseTimer = 2 + rand() * 8; % Pause 2-10 seconds
    elseif rand() < 0.4 % 40% chance to change direction
        ue.direction = ue.direction + (rand() - 0.5) * pi; % ±90°
        ue = moveUE(ue, distance);
    else
        ue = moveUE(ue, distance);
    end
end

function ue = handleIndoorMobileMobility(ue, timeStep, currentTime)    
    distance = ue.velocity * timeStep;
    
    if rand() < 0.2 
        ue.direction = ue.direction + (rand() - 0.5) * pi;
    end
    
    ue = moveUE(ue, distance);
end

function ue = handleOutdoorVehicleMobility(ue, timeStep, currentTime)    
    distance = ue.velocity * timeStep;
    
    if currentTime - ue.lastDirectionChange > 30 + rand() * 20
        ue.direction = ue.direction + (rand() - 0.5) * pi/6;
        ue.lastDirectionChange = currentTime;
    end
    
    ue = moveUE(ue, distance);
end

function ue = handleVehicleMobility(ue, timeStep, currentTime)
    distance = ue.velocity * timeStep;
    
    if currentTime - ue.lastDirectionChange > 25 + rand() * 15
        ue.direction = ue.direction + (rand() - 0.5) * pi/3;
        ue.lastDirectionChange = currentTime;
    end
    
    ue = moveUE(ue, distance);
end

function ue = handleHighSpeedTrainMobility(ue, timeStep, currentTime)    
    if ~isfield(ue, 'inTrain') || ~ue.inTrain
        ue = handleFastVehicleMobility(ue, timeStep, currentTime);
        return;
    end
    
    distance = ue.velocity * timeStep;
    ue.x = ue.x + distance; % Move along x-axis
    
    if rand() < 0.05
        ue.y = ue.y + (rand() - 0.5) * 0.5;
        trainY = 0; 
        ue.y = max(trainY - 2, min(trainY + 2, ue.y));
    end
    
    trackEndX = ue.trainStartX + ue.trackLength;
    if ue.x >= trackEndX
        % Wrap around or reverse direction (depending on scenario needs)
        % For continuous simulation, wrap to start
        ue.x = ue.trainStartX + ue.positionInTrain;
    end
end

function ue = moveUE(ue, distance)    
    ue.x = ue.x + distance * cos(ue.direction);
    ue.y = ue.y + distance * sin(ue.direction);
end

function ue = enforceScenarioBounds(ue, simParams)    
    boundaryHandlers = getBoundaryHandlers();
    
    if isfield(boundaryHandlers, simParams.deploymentScenario)
        ue = boundaryHandlers.(simParams.deploymentScenario)(ue, simParams);
    else
        ue = boundaryHandlers.default(ue, simParams);
    end
    
    ue.direction = mod(ue.direction, 2*pi);
end

function handlers = getBoundaryHandlers()    
    handlers = struct();
    handlers.indoor_hotspot = @enforceIndoorBounds;
    handlers.dense_urban = @enforceUrbanBounds;
    handlers.rural = @enforceRuralBounds;
    handlers.urban_macro = @enforceUrbanMacroBounds;
    handlers.high_speed = @enforceHighSpeedBounds;
    handlers.extreme_rural = @enforceExtremeRuralBounds; 
    handlers.default = @enforceDefaultBounds;
end

function ue = enforceIndoorBounds(ue, simParams)
% Indoor building bounds (120m x 50m office)
    
    bounds = struct('minX', 5, 'maxX', 115, 'minY', 5, 'maxY', 45);
    
    if ue.x <= bounds.minX
        ue.x = bounds.minX + 1;
        ue.direction = pi - ue.direction;
    elseif ue.x >= bounds.maxX
        ue.x = bounds.maxX - 1;
        ue.direction = pi - ue.direction;
    end
    
    if ue.y <= bounds.minY
        ue.y = bounds.minY + 1;
        ue.direction = -ue.direction;
    elseif ue.y >= bounds.maxY
        ue.y = bounds.maxY - 1;
        ue.direction = -ue.direction;
    end
end

function ue = enforceUrbanBounds(ue, simParams)    
    maxRadius = getFieldOrDefault(simParams, 'maxRadius', 500);
    distance = sqrt(ue.x^2 + ue.y^2);
    
    if distance > maxRadius
        angle = atan2(ue.y, ue.x);
        ue.x = (maxRadius - 10) * cos(angle);
        ue.y = (maxRadius - 10) * sin(angle);
        ue.direction = angle + pi + (rand() - 0.5) * pi/2;
    end
end

function ue = enforceRuralBounds(ue, simParams)    
    maxRadius = getFieldOrDefault(simParams, 'maxRadius', 2000);
    distance = sqrt(ue.x^2 + ue.y^2);
    
    if distance > maxRadius
        angle = atan2(ue.y, ue.x);
        ue.x = (maxRadius - 50) * cos(angle);
        ue.y = (maxRadius - 50) * sin(angle);
        ue.direction = angle + pi + (rand() - 0.5) * pi/4;
    end
end

function ue = enforceUrbanMacroBounds(ue, simParams)    
    maxRadius = getFieldOrDefault(simParams, 'maxRadius', 800);
    distance = sqrt(ue.x^2 + ue.y^2);
    
    if distance > maxRadius
        angle = atan2(ue.y, ue.x);
        ue.x = (maxRadius - 20) * cos(angle);
        ue.y = (maxRadius - 20) * sin(angle);
        ue.direction = angle + pi + (rand() - 0.5) * pi/3;
    end
end

function ue = enforceHighSpeedBounds(ue, simParams)    
    if ~isfield(ue, 'inTrain') || ~ue.inTrain
        ue = enforceDefaultBounds(ue, simParams);
        return;
    end
    
    trackLength = getFieldOrDefault(simParams, 'trackLength', 10000);
    trainStartX = ue.trainStartX;
    trackEndX = trainStartX + trackLength;
    
    if ue.x > trackEndX
        excessDistance = ue.x - trackEndX;
        ue.x = trainStartX + excessDistance;
    elseif ue.x < trainStartX
        ue.x = trainStartX; % Should not happen in normal operation
    end
    
    trainCenterY = 0;
    trainWidth = 4; % ±2m
    if abs(ue.y - trainCenterY) > trainWidth/2
        ue.y = trainCenterY + sign(ue.y - trainCenterY) * trainWidth/2;
    end
end

function ue = enforceExtremeRuralBounds(ue, simParams)    
    maxRadius = getFieldOrDefault(simParams, 'maxRadius', 50000);
    distance = sqrt(ue.x^2 + ue.y^2);
    
    if distance > maxRadius
        angle = atan2(ue.y, ue.x);
        ue.x = (maxRadius - 100) * cos(angle);
        ue.y = (maxRadius - 100) * sin(angle);
        ue.direction = angle + pi + (rand() - 0.5) * pi/6;
    end
end

function ue = enforceDefaultBounds(ue, simParams)    
    maxBound = 1000;
    if abs(ue.x) > maxBound || abs(ue.y) > maxBound
        ue.x = min(max(ue.x, -maxBound), maxBound);
        ue.y = min(max(ue.y, -maxBound), maxBound);
        ue.direction = ue.direction + pi + (rand() - 0.5) * pi/4;
    end
end

function value = getFieldOrDefault(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end

function ue = handleSlowWalkMobility(ue, timeStep, currentTime)    
    distance = ue.velocity * timeStep;
    
    if rand() < 0.3 % 30% chance to change direction
        ue.direction = ue.direction + (rand() - 0.5) * pi/2; % ±45°
    end
    
    ue = moveUE(ue, distance);
end

function ue = handleNormalWalkMobility(ue, timeStep, currentTime)    
    distance = ue.velocity * timeStep;
    
    if rand() < 0.4 % 40% chance to change direction
        ue.direction = ue.direction + (rand() - 0.5) * pi/2; % ±45°
    end
    
    ue = moveUE(ue, distance);
end

function ue = handleFastWalkMobility(ue, timeStep, currentTime)    
    distance = ue.velocity * timeStep;
    
    if rand() < 0.2 % 20% chance to change direction
        ue.direction = ue.direction + (rand() - 0.5) * pi/4; % ±22.5°
    end
    
    ue = moveUE(ue, distance);
end

function ue = handleSlowVehicleMobility(ue, timeStep, currentTime)    
    distance = ue.velocity * timeStep;
    
    % Change direction less frequently than pedestrians
    if currentTime - ue.lastDirectionChange > 20 + rand() * 30
        ue.direction = ue.direction + (rand() - 0.5) * pi/2;
        ue.lastDirectionChange = currentTime;
    end

    ue = moveUE(ue, distance);
end

function ue = handleExtremeVehicleMobility(ue, timeStep, currentTime)    
    distance = ue.velocity * timeStep;
    
    % Very infrequent direction changes for highway/wilderness travel
    if currentTime - ue.lastDirectionChange > 60 + rand() * 60
        ue.direction = ue.direction + (rand() - 0.5) * pi/8;  % Small turns
        ue.lastDirectionChange = currentTime;
    end
    
    ue = moveUE(ue, distance);
end