function sites = createLayout(simParams, seed)
    siteRng = RandStream('mt19937ar', 'Seed', seed + 1000);
    prevStream = RandStream.setGlobalStream(siteRng);

    layoutCreators = getLayoutCreators();
    
    if isfield(layoutCreators, simParams.deploymentScenario)
        sites = layoutCreators.(simParams.deploymentScenario)(simParams, seed);
    else
        warning('Unknown deployment scenario: %s. Using default hexagonal layout.', simParams.deploymentScenario);
        sites = createHexLayout(simParams.numSites, simParams.isd, seed);
    end

    RandStream.setGlobalStream(prevStream);
    fprintf('Created %d sites for %s scenario\n', length(sites), simParams.deploymentScenario);
end

function creators = getLayoutCreators()
    creators = struct();
    creators.indoor_hotspot = @createIndoorLayout;
    creators.dense_urban = @createDenseUrbanLayout;
    creators.rural = @createRuralLayout;
    creators.urban_macro = @createUrbanMacroLayout;
    creators.high_speed = @createHighSpeedLayout;
    creators.extreme_rural = @createExtremeRuralLayout;
end

function sites = createIndoorLayout(simParams, seed)
    config = getScenarioConfig('indoor_hotspot');
    sites = createGridLayout(simParams.numSites, config.dimensions, config.gridSize, 'indoor_trxp');
end

function sites = createDenseUrbanLayout(simParams, seed)    
    macroSites = createHexLayout(simParams.numSites, simParams.isd, seed);
    
    sites = macroSites;
end

function sites = createRuralLayout(simParams, seed)    
    sites = createHexLayout(simParams.numSites, simParams.isd, seed);
    
    for i = 1:length(sites)
        sites(i).type = 'rural_macro';
    end
end

function sites = createUrbanMacroLayout(simParams, seed)    
    sites = createHexLayout(simParams.numSites, simParams.isd, seed);
    
    for i = 1:length(sites)
        sites(i).type = 'urban_macro';
    end
end

function sites = createHighSpeedLayout(simParams, seed)
    isd = simParams.isd;
    
    numSites = simParams.numSites;
    
    startPos = -(numSites - 1) * isd / 2;
    
    sites = struct('id', {}, 'x', {}, 'y', {}, 'type', {});
    
    for i = 1:numSites
        xPos = startPos + (i - 1) * isd;
        yPos = 100; 
        
        sites(i) = struct(...
            'id', i, ...
            'x', xPos, ...
            'y', yPos, ...
            'type', 'high_speed_rrh' ...
        );
    end
end

function sites = createExtremeRuralLayout(simParams, seed)    
    sites = createHexLayout(simParams.numSites, simParams.isd, seed);
    
    for i = 1:length(sites)
        sites(i).type = 'extreme_rural_macro';
    end
end

function sites = createGridLayout(numSites, dimensions, gridSize, siteType)    
    floorWidth = dimensions.width;
    floorHeight = dimensions.height;
    cols = gridSize.cols;
    rows = gridSize.rows;
    
    xSpacing = floorWidth / (cols + 1);
    ySpacing = floorHeight / (rows + 1);
    
    sites = struct('id', {}, 'x', {}, 'y', {}, 'type', {});
    siteIdx = 1;
    
    for row = 1:rows
        for col = 1:cols
            if siteIdx <= numSites
                sites(siteIdx) = struct(...
                    'id', siteIdx, ...
                    'x', col * xSpacing, ...
                    'y', row * ySpacing, ...
                    'type', siteType ...
                );
                siteIdx = siteIdx + 1;
            end
        end
    end
end

function sites = createHexLayout(numSites, isd, seed)    
    rng(seed + 1000, 'twister');
    
    sites = struct('id', {}, 'x', {}, 'y', {}, 'type', {});
    
    sites(1) = struct('id', 1, 'x', 0, 'y', 0, 'type', 'macro');
    
    if numSites == 1
        return;
    end
    
    siteIdx = 2;
    ring = 1;
    maxRings = 5;
    
    while siteIdx <= numSites && ring <= maxRings
        ringSites = createHexRing(ring, isd, siteIdx);
        
        for i = 1:length(ringSites)
            if siteIdx <= numSites
                sites(siteIdx) = ringSites(i);
                siteIdx = siteIdx + 1;
            end
        end
        ring = ring + 1;
    end
    
    sites = fillRemainingSites(sites, numSites, siteIdx, isd);
end

function ringSites = createHexRing(ring, isd, startIdx)    
    ringSites = struct('id', {}, 'x', {}, 'y', {}, 'type', {});
    siteIdx = startIdx;
    ringIdx = 1;
    
    for side = 0:5
        for pos = 0:(ring-1)
            angle = side * pi/3;
            x = isd * ring * cos(angle) + pos * isd * cos(angle + pi/3);
            y = isd * ring * sin(angle) + pos * isd * sin(angle + pi/3);
            
            ringSites(ringIdx) = struct('id', siteIdx, 'x', x, 'y', y, 'type', 'macro');
            siteIdx = siteIdx + 1;
            ringIdx = ringIdx + 1;
        end
    end
end

function sites = fillRemainingSites(sites, numSites, currentIdx, isd)    
    while currentIdx <= numSites
        angle = rand() * 2 * pi;
        distance = isd + rand() * (isd * 2);
        x = distance * cos(angle);
        y = distance * sin(angle);
        
        sites(currentIdx) = struct('id', currentIdx, 'x', x, 'y', y, 'type', 'macro');
        currentIdx = currentIdx + 1;
    end
end

function config = getScenarioConfig(scenarioType)    
    configs = struct();
    
    configs.indoor_hotspot = struct(...
        'dimensions', struct('width', 120, 'height', 50), ...
        'gridSize', struct('cols', 4, 'rows', 3) ...
    );
    
    configs.micro_placement = struct(...
        'minDistance', 20, ...
        'maxDistance', 100 ...
    );
    
    if isfield(configs, scenarioType)
        config = configs.(scenarioType);
    else
        error('Unknown scenario type: %s', scenarioType);
    end
end