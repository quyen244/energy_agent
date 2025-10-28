function cells = configureCells(sites, simParams)
    cells = [];
    cellIdx = 1;    
    configurators = getCellConfigurators();
        
    for siteIdx = 1:length(sites)
        site = sites(siteIdx);
        
        cellConfig = getCellConfigurationForSite(site, simParams, configurators);
        
        sectorsCreated = createSectorsForSite(site, cellConfig, cellIdx, simParams);
        
        for i = 1:length(sectorsCreated)
            if isempty(cells)
                cells = sectorsCreated(i);
            else
                cells(end+1) = sectorsCreated(i);
            end
        end
        
        cellIdx = cellIdx + length(sectorsCreated);
    end    
end

function configurators = getCellConfigurators()
    configurators = struct();
    configurators.indoor_trxp = @getIndoorCellConfig;
    configurators.macro = @getMacroCellConfig;
    configurators.micro = @getMicroCellConfig;
    configurators.rural_macro = @getRuralMacroCellConfig;
    configurators.urban_macro = @getUrbanMacroCellConfig;
    configurators.high_speed_rrh = @getHighSpeedCellConfig;
    configurators.extreme_rural_macro = @getExtremeRuralMacroCellConfig;
end

function cellConfig = getCellConfigurationForSite(site, simParams, configurators)    
    if isfield(site, 'type') && isfield(configurators, site.type)
        cellConfig = configurators.(site.type)(simParams, site);
    else
        switch simParams.deploymentScenario
            case 'indoor_hotspot'
                cellConfig = configurators.indoor_trxp(simParams, site);
            case 'dense_urban'
                cellConfig = configurators.macro(simParams, site);
            case 'rural'
                cellConfig = configurators.rural_macro(simParams, site);
            case 'urban_macro'
                cellConfig = configurators.urban_macro(simParams, site);
            case 'high_speed'
                cellConfig = configurators.high_speed_rrh(simParams, site); 
            case 'extreme_rural' 
                cellConfig = configurators.extreme_rural_macro(simParams, site);
            otherwise
                cellConfig = configurators.macro(simParams, site);
        end
    end
end

function sectors = createSectorsForSite(site, cellConfig, startCellIdx, simParams)    
    numSectors = determineNumSectors(site, simParams);
    sectors = [];
    
    for sectorIdx = 1:numSectors
        azimuth = calculateSectorAzimuth(sectorIdx, numSectors);
        
        newCell = createCellStruct(...
            startCellIdx + sectorIdx - 1, ...
            site, ...
            sectorIdx, ...
            azimuth, ...
            cellConfig, ...
            numSectors == 1 ...
        );
        
        if isempty(sectors)
            sectors = newCell;
        else
            sectors(end+1) = newCell;
        end
    end
end

function numSectors = determineNumSectors(site, simParams)    
    if strcmp(simParams.deploymentScenario, 'indoor_hotspot')
        numSectors = 1; % Indoor TRxPs are omnidirectional
    elseif strcmp(simParams.deploymentScenario, 'high_speed')
        numSectors = 2; % High speed uses 2 sectors (bidirectional along track)
    elseif isfield(site, 'type') && strcmp(site.type, 'micro')
        numSectors = 1; % Micro cells are typically omnidirectional
    else
        numSectors = getFieldOrDefault(simParams, 'numSectors', 3);
    end
end

function azimuth = calculateSectorAzimuth(sectorIdx, numSectors)
    azimuth = (sectorIdx - 1) * (360 / numSectors);
end

function cell = createCellStruct(cellId, site, sectorId, azimuth, config, isOmnidirectional)    
    cell = struct(...
        'id', cellId, ...
        'siteId', site.id, ...
        'sectorId', sectorId, ...
        'azimuth', azimuth, ...
        'x', site.x, ...
        'y', site.y, ...
        'frequency', config.frequency, ...
        'antennaHeight', config.antennaHeight, ...
        'txPower', config.initialTxPower, ...
        'minTxPower', config.minTxPower, ...
        'maxTxPower', config.maxTxPower, ...
        'cellRadius', config.cellRadius, ...
        'cpuUsage', 0, ...
        'prbUsage', 0, ...
        'energyConsumption', config.basePower, ...
        'baseEnergyConsumption', config.basePower, ...
        'idleEnergyConsumption', config.idlePower, ...
        'maxCapacity', config.maxCapacity, ...
        'currentLoad', 0, ...
        'connectedUEs', [], ...
        'ttt', getFieldOrDefault(config, 'ttt', 8), ...
        'a3Offset', getFieldOrDefault(config, 'a3Offset', 8), ...
        'isOmnidirectional', isOmnidirectional, ...
        'siteType', site.type ...
    );
end

function cellConfig = getIndoorCellConfig(simParams, site)
    
    cellConfig = struct();
    cellConfig.frequency = simParams.carrierFrequency;
    cellConfig.antennaHeight = getFieldOrDefault(simParams, 'antennaHeight', 3);
    cellConfig.initialTxPower = 23;
    cellConfig.minTxPower = getFieldOrDefault(simParams, 'minTxPower', 20);
    cellConfig.maxTxPower = getFieldOrDefault(simParams, 'maxTxPower', 30);
    cellConfig.cellRadius = getFieldOrDefault(simParams, 'cellRadius', 50);
    cellConfig.basePower = getFieldOrDefault(simParams, 'basePower', 400);
    cellConfig.idlePower = getFieldOrDefault(simParams, 'idlePower', 100);
    cellConfig.maxCapacity = 50;
    cellConfig.ttt = 4;
    cellConfig.a3Offset = 6;
end

function cellConfig = getMacroCellConfig(simParams, site)    
    cellConfig = struct();
    cellConfig.frequency = simParams.carrierFrequency;
    cellConfig.antennaHeight = getFieldOrDefault(simParams, 'antennaHeight', 25);
    cellConfig.initialTxPower = 43;
    cellConfig.minTxPower = getFieldOrDefault(simParams, 'minTxPower', 30);
    cellConfig.maxTxPower = getFieldOrDefault(simParams, 'maxTxPower', 46);
    cellConfig.cellRadius = getFieldOrDefault(simParams, 'cellRadius', 200);
    cellConfig.basePower = getFieldOrDefault(simParams, 'basePower', 800);
    cellConfig.idlePower = getFieldOrDefault(simParams, 'idlePower', 200);
    cellConfig.maxCapacity = 200;
    cellConfig.ttt = 8;
    cellConfig.a3Offset = 8;
end

function cellConfig = getMicroCellConfig(simParams, site)    
    cellConfig = struct();
    cellConfig.frequency = simParams.carrierFrequency;
    cellConfig.antennaHeight = 10;
    cellConfig.initialTxPower = 30;
    cellConfig.minTxPower = 20;
    cellConfig.maxTxPower = 38;
    cellConfig.cellRadius = 50;
    cellConfig.basePower = 200;
    cellConfig.idlePower = 50;
    cellConfig.maxCapacity = 100;
    cellConfig.ttt = 6; 
    cellConfig.a3Offset = 6;
end

function cellConfig = getRuralMacroCellConfig(simParams, site)    
    cellConfig = struct();
    cellConfig.frequency = simParams.carrierFrequency;
    cellConfig.antennaHeight = getFieldOrDefault(simParams, 'antennaHeight', 35);
    cellConfig.initialTxPower = 46; 
    cellConfig.minTxPower = getFieldOrDefault(simParams, 'minTxPower', 35);
    cellConfig.maxTxPower = getFieldOrDefault(simParams, 'maxTxPower', 49);
    cellConfig.cellRadius = getFieldOrDefault(simParams, 'cellRadius', 1000);
    cellConfig.basePower = getFieldOrDefault(simParams, 'basePower', 1200);
    cellConfig.idlePower = getFieldOrDefault(simParams, 'idlePower', 300);
    cellConfig.maxCapacity = 150; 
    cellConfig.ttt = 12; 
    cellConfig.a3Offset = 10;
end

function cellConfig = getUrbanMacroCellConfig(simParams, site)    
    cellConfig = struct();
    cellConfig.frequency = simParams.carrierFrequency;
    cellConfig.antennaHeight = getFieldOrDefault(simParams, 'antennaHeight', 25);
    cellConfig.initialTxPower = 43;
    cellConfig.minTxPower = getFieldOrDefault(simParams, 'minTxPower', 30);
    cellConfig.maxTxPower = getFieldOrDefault(simParams, 'maxTxPower', 46);
    cellConfig.cellRadius = getFieldOrDefault(simParams, 'cellRadius', 300);
    cellConfig.basePower = getFieldOrDefault(simParams, 'basePower', 1000);
    cellConfig.idlePower = getFieldOrDefault(simParams, 'idlePower', 250);
    cellConfig.maxCapacity = 250;
    cellConfig.ttt = 8;
    cellConfig.a3Offset = 8;
end

function cellConfig = getHighSpeedCellConfig(simParams, site)
    cellConfig = struct();
    cellConfig.frequency = simParams.carrierFrequency;
    cellConfig.antennaHeight = getFieldOrDefault(simParams, 'antennaHeight', 35);
    cellConfig.initialTxPower = 46; 
    cellConfig.minTxPower = getFieldOrDefault(simParams, 'minTxPower', 40);
    cellConfig.maxTxPower = getFieldOrDefault(simParams, 'maxTxPower', 49);
    cellConfig.cellRadius = getFieldOrDefault(simParams, 'cellRadius', 1000);
    cellConfig.basePower = getFieldOrDefault(simParams, 'basePower', 1200);
    cellConfig.idlePower = getFieldOrDefault(simParams, 'idlePower', 300);
    cellConfig.maxCapacity = 300; 
    cellConfig.ttt = 0.04;
    cellConfig.a3Offset = 3;
end

function cellConfig = getExtremeRuralMacroCellConfig(simParams, site)    
    cellConfig = struct();
    cellConfig.frequency = simParams.carrierFrequency;
    cellConfig.antennaHeight = getFieldOrDefault(simParams, 'antennaHeight', 45);
    cellConfig.initialTxPower = 46;
    cellConfig.minTxPower = getFieldOrDefault(simParams, 'minTxPower', 43);
    cellConfig.maxTxPower = getFieldOrDefault(simParams, 'maxTxPower', 49);
    cellConfig.cellRadius = getFieldOrDefault(simParams, 'cellRadius', 50000);  % 50 km
    cellConfig.basePower = getFieldOrDefault(simParams, 'basePower', 1500);
    cellConfig.idlePower = getFieldOrDefault(simParams, 'idlePower', 400);
    cellConfig.maxCapacity = 100;  % Lower capacity due to sparse users
    cellConfig.ttt = 16;  % Longer TTT for extreme distances
    cellConfig.a3Offset = 12;  % Larger offset
end

function value = getFieldOrDefault(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end