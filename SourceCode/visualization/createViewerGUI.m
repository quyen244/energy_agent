function createViewerGUI(simResults, uePositions, numSteps, sites, cellPositions, ...
                        cells, coverageData, xMin, xMax, yMin, yMax)
    
    % Create main figure
    fig = figure('Name', '5G Network Interactive Viewer', ...
                 'NumberTitle', 'off', ...
                 'Position', [100, 100, 1400, 900], ...
                 'KeyPressFcn', @keyPressCallback, ...
                 'CloseRequestFcn', @closeCallback);
    
    % Create UI panels
    mainPanel = uipanel('Parent', fig, 'Position', [0.15, 0, 0.85, 1]);
    controlPanel = uipanel('Parent', fig, 'Position', [0, 0, 0.15, 1], ...
                          'Title', 'Controls', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Create axes for animation
    ax = axes('Parent', mainPanel, 'Position', [0.08, 0.15, 0.85, 0.75]);
    
    % Animation state variables
    animData = struct();
    animData.currentFrame = 1;
    animData.isPlaying = false;
    animData.fps = 5; % Default frames per second
    animData.playTimer = [];
    animData.showCoverage = false;
    animData.showConnections = true;
    animData.showLabels = true;
    
    % Store data in figure
    setappdata(fig, 'animData', animData);
    setappdata(fig, 'uePositions', uePositions);
    setappdata(fig, 'numSteps', numSteps);
    setappdata(fig, 'sites', sites);
    setappdata(fig, 'cellPositions', cellPositions);
    setappdata(fig, 'cells', cells);
    setappdata(fig, 'coverageData', coverageData);
    setappdata(fig, 'simResults', simResults);
    setappdata(fig, 'plotLimits', [xMin, xMax, yMin, yMax]);
    setappdata(fig, 'ax', ax);
    
    % Create control buttons and sliders
    yPos = 0.95;
    buttonHeight = 0.03;
    buttonWidth = 0.8;
    spacing = 0.01;
    
    % Frame control
    uicontrol('Parent', controlPanel, 'Style', 'text', ...
              'String', 'Frame Control', 'FontWeight', 'bold', ...
              'Units', 'normalized', 'Position', [0.1, yPos-0.02, 0.8, 0.03]);
    yPos = yPos - 0.05;
    
    % Current frame display
    frameText = uicontrol('Parent', controlPanel, 'Style', 'text', ...
                         'String', sprintf('Frame: 1 / %d', numSteps), ...
                         'Units', 'normalized', 'Position', [0.1, yPos, 0.8, 0.03]);
    setappdata(fig, 'frameText', frameText);
    yPos = yPos - 0.05;
    
    % Frame slider
    frameSlider = uicontrol('Parent', controlPanel, 'Style', 'slider', ...
                           'Min', 1, 'Max', numSteps, 'Value', 1, ...
                           'Units', 'normalized', 'Position', [0.1, yPos, 0.8, 0.04], ...
                           'Callback', @frameSliderCallback);
    setappdata(fig, 'frameSlider', frameSlider);
    yPos = yPos - 0.05;
    
    % Navigation buttons
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', '⏮ First', 'Units', 'normalized', ...
              'Position', [0.1, yPos, buttonWidth/2-0.01, buttonHeight], ...
              'Callback', @firstFrameCallback);
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', '⏪ Prev', 'Units', 'normalized', ...
              'Position', [0.5, yPos, buttonWidth/2, buttonHeight], ...
              'Callback', @prevFrameCallback);
    yPos = yPos - buttonHeight - spacing;
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', '⏩ Next', 'Units', 'normalized', ...
              'Position', [0.1, yPos, buttonWidth/2-0.01, buttonHeight], ...
              'Callback', @nextFrameCallback);
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', '⏭ Last', 'Units', 'normalized', ...
              'Position', [0.5, yPos, buttonWidth/2, buttonHeight], ...
              'Callback', @lastFrameCallback);
    yPos = yPos - buttonHeight - spacing*2;
    
    % Playback controls
    uicontrol('Parent', controlPanel, 'Style', 'text', ...
              'String', 'Playback', 'FontWeight', 'bold', ...
              'Units', 'normalized', 'Position', [0.1, yPos, 0.8, 0.03]);
    yPos = yPos - 0.05;
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
          'String', '▶ Play', 'Units', 'normalized', ...
          'Position', [0.1, yPos, buttonWidth/2-0.01, buttonHeight], ...
          'Callback', @playOnlyCallback);

    % Pause button (right)
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
            'String', '⏸ Pause', 'Units', 'normalized', ...
            'Position', [0.5, yPos, buttonWidth/2, buttonHeight], ...
            'Callback', @pauseOnlyCallback);

    yPos = yPos - buttonHeight - spacing;
    
    % Speed control
    uicontrol('Parent', controlPanel, 'Style', 'text', ...
              'String', 'Speed (fps)', 'Units', 'normalized', ...
              'Position', [0.1, yPos, 0.8, 0.03]);
    yPos = yPos - 0.04;
    
    speedSlider = uicontrol('Parent', controlPanel, 'Style', 'slider', ...
                           'Min', 0.5, 'Max', 10, 'Value', 5, ...
                           'Units', 'normalized', 'Position', [0.1, yPos, 0.8, 0.04], ...
                           'Callback', @speedCallback);
    yPos = yPos - 0.05;
    
    % View controls
    uicontrol('Parent', controlPanel, 'Style', 'text', ...
              'String', 'View Options', 'FontWeight', 'bold', ...
              'Units', 'normalized', 'Position', [0.1, yPos, 0.8, 0.03]);
    yPos = yPos - 0.05;
    
    % Checkboxes for display options
    coverageCheck = uicontrol('Parent', controlPanel, 'Style', 'checkbox', ...
                             'String', 'Coverage', 'Value', 1, ...
                             'Units', 'normalized', 'Position', [0.1, yPos, 0.8, 0.04], ...
                             'Callback', @coverageCallback);
    yPos = yPos - 0.05;
    
    connectionCheck = uicontrol('Parent', controlPanel, 'Style', 'checkbox', ...
                               'String', 'Connections', 'Value', 1, ...
                               'Units', 'normalized', 'Position', [0.1, yPos, 0.8, 0.04], ...
                               'Callback', @connectionCallback);
    yPos = yPos - 0.05;
    
    labelCheck = uicontrol('Parent', controlPanel, 'Style', 'checkbox', ...
                          'String', 'Labels', 'Value', 1, ...
                          'Units', 'normalized', 'Position', [0.1, yPos, 0.8, 0.04], ...
                          'Callback', @labelCallback);
    yPos = yPos - 0.05;
    
    % Zoom controls
    uicontrol('Parent', controlPanel, 'Style', 'text', ...
              'String', 'Zoom Controls', 'FontWeight', 'bold', ...
              'Units', 'normalized', 'Position', [0.1, yPos, 0.8, 0.03]);
    yPos = yPos - 0.05;
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', '🔍+ Zoom In', 'Units', 'normalized', ...
              'Position', [0.1, yPos, buttonWidth, buttonHeight], ...
              'Callback', @zoomInCallback);
    yPos = yPos - buttonHeight - spacing;
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', '🔍- Zoom Out', 'Units', 'normalized', ...
              'Position', [0.1, yPos, buttonWidth, buttonHeight], ...
              'Callback', @zoomOutCallback);
    yPos = yPos - buttonHeight - spacing;
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', '🏠 Fit All', 'Units', 'normalized', ...
              'Position', [0.1, yPos, buttonWidth, buttonHeight], ...
              'Callback', @fitAllCallback);
    yPos = yPos - buttonHeight - spacing*2;
    
    % Export controls
    uicontrol('Parent', controlPanel, 'Style', 'text', ...
              'String', 'Export', 'FontWeight', 'bold', ...
              'Units', 'normalized', 'Position', [0.1, yPos, 0.8, 0.03]);
    yPos = yPos - 0.05;
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', '💾 Save Frame', 'Units', 'normalized', ...
              'Position', [0.1, yPos, buttonWidth, buttonHeight], ...
              'Callback', @saveFrameCallback);
    yPos = yPos - buttonHeight - spacing;
    
    uicontrol('Parent', controlPanel, 'Style', 'pushbutton', ...
              'String', '🎬 Export GIF', 'Units', 'normalized', ...
              'Position', [0.1, yPos, buttonWidth, buttonHeight], ...
              'Callback', @exportGifCallback);
    
    % Enable zoom and pan
    zoom(ax, 'on');
    pan(ax, 'on');
    
    % Initial plot
    updateFrame(fig);
    
    % Callback functions
    function keyPressCallback(src, event)
        switch event.Key
            case 'rightarrow'
                nextFrameCallback();
            case 'leftarrow'
                prevFrameCallback();            
            case 'home'
                firstFrameCallback();
            case 'end'
                lastFrameCallback();
            case 'equal' % Plus key
                zoomInCallback();
            case 'hyphen' % Minus key
                zoomOutCallback();
            case 'r'
                fitAllCallback();
            case 'c'
                animData = getappdata(fig, 'animData');
                animData.showCoverage = ~animData.showCoverage;
                setappdata(fig, 'animData', animData);
                set(coverageCheck, 'Value', animData.showCoverage);
                updateFrame(fig);
            case 'l'
                animData = getappdata(fig, 'animData');
                animData.showConnections = ~animData.showConnections;
                setappdata(fig, 'animData', animData);
                set(connectionCheck, 'Value', animData.showConnections);
                updateFrame(fig);
            case 't'
                animData = getappdata(fig, 'animData');
                animData.showLabels = ~animData.showLabels;
                setappdata(fig, 'animData', animData);
                set(labelCheck, 'Value', animData.showLabels);
                updateFrame(fig);
        end
    end
    
    function frameSliderCallback(src, ~)
        animData = getappdata(fig, 'animData');
        animData.currentFrame = round(get(src, 'Value'));
        setappdata(fig, 'animData', animData);
        updateFrame(fig);
    end
    
    function firstFrameCallback(~, ~)
        animData = getappdata(fig, 'animData');
        animData.currentFrame = 1;
        setappdata(fig, 'animData', animData);
        updateFrame(fig);
        set(frameSlider, 'Value', 1);
    end
    
    function prevFrameCallback(~, ~)
        animData = getappdata(fig, 'animData');
        if animData.currentFrame > 1
            animData.currentFrame = animData.currentFrame - 1;
            setappdata(fig, 'animData', animData);
            updateFrame(fig);
            set(frameSlider, 'Value', animData.currentFrame);
        end
    end
    
    function nextFrameCallback(~, ~)
        animData = getappdata(fig, 'animData');
        numSteps = getappdata(fig, 'numSteps');
        if animData.currentFrame < numSteps
            animData.currentFrame = animData.currentFrame + 1;
            setappdata(fig, 'animData', animData);
            updateFrame(fig);
            set(frameSlider, 'Value', animData.currentFrame);
        end
    end
    
    function lastFrameCallback(~, ~)
        numSteps = getappdata(fig, 'numSteps');
        animData = getappdata(fig, 'animData');
        animData.currentFrame = numSteps;
        setappdata(fig, 'animData', animData);
        updateFrame(fig);
        set(frameSlider, 'Value', numSteps);
    end
    
   
    function playOnlyCallback(~, ~)
    animData = getappdata(fig, 'animData');
    if animData.isPlaying, return; end % already playing

    % stop old timer if any
    t = getappdata(fig, 'playTimer');
    if ~isempty(t) && isvalid(t)
        stop(t); delete(t);
    end

    animData.isPlaying = true;
    period = 1 / max(0.01, animData.fps);
    t = timer( ...
        'ExecutionMode', 'fixedRate', ...
        'Period', period, ...
        'BusyMode', 'drop', ...
        'TimerFcn', @(~,~) advanceFrame(fig) ...
    );
    setappdata(fig, 'playTimer', t);
    setappdata(fig, 'animData', animData);
    start(t);
end

function pauseOnlyCallback(~, ~)
    animData = getappdata(fig, 'animData');
    t = getappdata(fig, 'playTimer');
    if ~isempty(t) && isvalid(t)
        stop(t); delete(t);
        rmappdata(fig, 'playTimer');
    end
    animData.isPlaying = false;
    setappdata(fig, 'animData', animData);
end

    function advanceFrame(fig)
        if ~isvalid(fig), return; end
        animData = getappdata(fig,'animData');
        numSteps = getappdata(fig,'numSteps');

        animData.currentFrame = animData.currentFrame + 1;
        if animData.currentFrame > numSteps
            animData.currentFrame = 1;
        end

        setappdata(fig,'animData',animData);
        updateFrame(fig);

        s = getappdata(fig,'frameSlider');
        if isvalid(s)
            set(s,'Value', animData.currentFrame);
        end
    end

    function speedCallback(src, ~)
    fig = ancestor(src,'figure');
    animData = getappdata(fig,'animData');

    % update fps
    animData.fps = get(src,'Value');
    setappdata(fig,'animData',animData);

    % if playing, restart stored timer with new period
    if animData.isPlaying
        % stop any stored timer
        tOld = getappdata(fig, 'playTimer');
        if ~isempty(tOld) && isvalid(tOld)
            try stop(tOld); catch; end
            try delete(tOld); catch; end
            rmappdata(fig, 'playTimer');
        end

        period = 1 / max(0.01, animData.fps);
        tNew = timer( ...
            'ExecutionMode', 'fixedRate', ...
            'Period', period, ...
            'BusyMode', 'drop', ...
            'TimerFcn', @(~,~) advanceFrame(fig) ...
        );
        setappdata(fig, 'playTimer', tNew);
        start(tNew);
    end
end


    
    function coverageCallback(src, ~)
        animData = getappdata(fig, 'animData');
        animData.showCoverage = get(src, 'Value');
        setappdata(fig, 'animData', animData);
        updateFrame(fig);
    end
    
    function connectionCallback(src, ~)
        animData = getappdata(fig, 'animData');
        animData.showConnections = get(src, 'Value');
        setappdata(fig, 'animData', animData);
        updateFrame(fig);
    end
    
    function labelCallback(src, ~)
        animData = getappdata(fig, 'animData');
        animData.showLabels = get(src, 'Value');
        setappdata(fig, 'animData', animData);
        updateFrame(fig);
    end
    
    function zoomInCallback(~, ~)
        ax = getappdata(fig, 'ax');
        xlim_curr = xlim(ax);
        ylim_curr = ylim(ax);
        zoom_factor = 0.7;
        
        x_center = mean(xlim_curr);
        y_center = mean(ylim_curr);
        x_range = diff(xlim_curr) * zoom_factor / 2;
        y_range = diff(ylim_curr) * zoom_factor / 2;
        
        xlim(ax, [x_center - x_range, x_center + x_range]);
        ylim(ax, [y_center - y_range, y_center + y_range]);
    end
    
    function zoomOutCallback(~, ~)
        ax = getappdata(fig, 'ax');
        xlim_curr = xlim(ax);
        ylim_curr = ylim(ax);
        zoom_factor = 1.4;
        
        x_center = mean(xlim_curr);
        y_center = mean(ylim_curr);
        x_range = diff(xlim_curr) * zoom_factor / 2;
        y_range = diff(ylim_curr) * zoom_factor / 2;
        
        xlim(ax, [x_center - x_range, x_center + x_range]);
        ylim(ax, [y_center - y_range, y_center + y_range]);
    end
    
    function fitAllCallback(~, ~)
        ax = getappdata(fig, 'ax');
        plotLimits = getappdata(fig, 'plotLimits');
        xlim(ax, [plotLimits(1), plotLimits(2)]);
        ylim(ax, [plotLimits(3), plotLimits(4)]);
    end
    
    function saveFrameCallback(~, ~)
        animData = getappdata(fig, 'animData');
        filename = sprintf('frame_%04d.png', animData.currentFrame);
        [file, path] = uiputfile('*.png', 'Save Frame As', filename);
        if file ~= 0
            saveas(fig, fullfile(path, file));
            fprintf('Frame saved as: %s\n', fullfile(path, file));
        end
    end
    
    function exportGifCallback(~, ~)
        [file, path] = uiputfile('*.gif', 'Export Animation As', 'network_animation.gif');
        if file ~= 0
            exportToGif(fig, fullfile(path, file));
        end
    end
    
    function closeCallback(src, ~)
    try
        t = getappdata(src, 'playTimer');
        if ~isempty(t) && isvalid(t)
            stop(t);
            delete(t);
        end
    catch ME
        fprintf('Warning during timer cleanup: %s\n', ME.message);
    end

    if isvalid(src)
        delete(src);
    end
end


end