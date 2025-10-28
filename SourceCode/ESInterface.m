classdef ESInterface < handle
    % MATLAB-Python bridge for RL-based Energy Saving Agent with Power Control
    % Provides interface between 5G simulation environment and Python RL agent
    
    properties
        pythonAgent     % Python RL ESAgent object
        isInitialized   % Flag to track initialization
        nCells          % Number of cells in the network
        nUEs            % Number of UEs in the network
        maxTime         % Maximum simulation time steps
        currentStep     % Current simulation step
        lastState       % Last state sent to agent
        lastAction      % Last action from agent
        stepCount       % Steps in current episode
    end
    
    methods
        function obj = ESInterface(varargin)
            % Constructor for ES RL interface with power control
            p = inputParser;
            addParameter(p, 'n_cells', 5);
            addParameter(p, 'max_time', 600);
            addParameter(p, 'num_ue', 80);
            parse(p, varargin{:});
            
            obj.nCells = p.Results.n_cells;
            obj.nUEs = p.Results.num_ue;
            obj.maxTime = p.Results.max_time;
            obj.currentStep = 0;
            obj.stepCount = 0;
            obj.lastState = [];
            obj.lastAction = [];

            try
                energy_agent_module = py.importlib.reload(py.importlib.import_module('energy_agent'));
                
                % Create Python RL Agent instance
                obj.pythonAgent = energy_agent_module.RLAgent(...
                    pyargs('n_cells', int32(obj.nCells), ...
                        'n_ues', int32(obj.nUEs), ...
                        'max_time', int64(obj.maxTime)));
                
                obj.isInitialized = true;
                fprintf('RL Power Control ES interface initialized: %d cells, %d UEs, %d time steps\n', ...
                    obj.nCells, obj.nUEs, obj.maxTime);
                
            catch ME
                fprintf('Failed to initialize RL Power Control ES interface: %s\n', ME.message);
                obj.isInitialized = false;
                rethrow(ME);
            end
        end

        function start_scenario(obj)
            if ~obj.isInitialized, return; end
            
            try
                obj.currentStep = 0;
                obj.stepCount = 0;
                obj.lastState = [];
                obj.lastAction = [];
                
                obj.pythonAgent.start_scenario();
                fprintf('Started new power control scenario (episode)\n');
                
            catch ME
                fprintf('Error starting power control scenario: %s\n', ME.message);
            end
        end

        function end_scenario(obj)
            if ~obj.isInitialized, return; end
            
            try
                obj.pythonAgent.end_scenario();                
            catch ME
                fprintf('Error ending power control scenario: %s\n', ME.message);
            end
        end
        
        function actions = getAction(obj, state, currentTime)
            actions = struct();
            if ~obj.isInitialized
                return;
            end
            
            try
                fprintf('Getting RL power control action at time %d (step %d)\n', currentTime, obj.currentStep);
                pyState = obj.convertStateToRL(state, currentTime); 
                obj.lastState = pyState;
                
                pyAction = obj.pythonAgent.get_action(pyState);
                actions = obj.convertActionFromRL(pyAction);
                obj.lastAction = actions;

                obj.currentStep = obj.currentStep + 1;
                
            catch ME
                fprintf('Error getting RL power control action: %s\n', ME.message);
            end
        end
        
        function updateAgent(obj, state, action, nextState, done)
            if ~obj.isInitialized, return; end

            try
                if isa(state, 'py.numpy.ndarray')
                    pyState = state;
                else
                    pyState = obj.convertStateToRL(state, max(0, obj.currentStep - 1));
                end

                if isa(action, 'py.numpy.ndarray')
                    pyAction = action;
                else
                    pyAction = obj.convertActionToRL(action);
                end

                if isa(nextState, 'py.numpy.ndarray')
                    pyNextState = nextState;
                else
                    pyNextState = obj.convertStateToRL(nextState, obj.currentStep);
                end

                isDone = false;  % Never pass done=true during scenario steps
                
                obj.pythonAgent.update(pyState, pyAction, pyNextState, logical(isDone));

                obj.stepCount = obj.stepCount + 1;

            catch ME
                fprintf('Error updating RL power control agent: %s\n', ME.message);
            end
        end

        function pyState = convertStateToRL(obj, state, currentTime)
            % Convert simulation state to RL state format - NO normalization here
            % All normalization should be handled by the Python RL Agent
            
            % Extract simulation information features from state.simulation
            simulationFeatures = [
                state.simulation.totalCells,
                state.simulation.totalUEs,
                state.simulation.simTime,
                state.simulation.timeStep,
                state.simulation.timeProgress,
                state.simulation.carrierFrequency,
                state.simulation.isd,
                state.simulation.minTxPower,
                state.simulation.maxTxPower,
                state.simulation.basePower,
                state.simulation.idlePower,
                state.simulation.dropCallThreshold,
                state.simulation.latencyThreshold,
                state.simulation.cpuThreshold,
                state.simulation.prbThreshold,
                state.simulation.trafficLambda,
                state.simulation.peakHourMultiplier
            ];
            

            networkFeatures = [];
            
            % Get all field names from state.network and extract their values
            networkFields = fieldnames(state.network);
            for i = 1:length(networkFields)
                fieldName = networkFields{i};
                fieldValue = state.network.(fieldName);
                
                % Handle scalar values
                if isscalar(fieldValue) && isnumeric(fieldValue)
                    networkFeatures(end+1) = fieldValue;
                elseif isscalar(fieldValue) && islogical(fieldValue)
                    networkFeatures(end+1) = double(fieldValue);
                end
            end
            
            % Per-cell features - extract from state.cells structure
            cellNames = fieldnames(state.cells);
            cellFeatures = zeros(obj.nCells, 12); % Increased feature count
            
            for i = 1:min(length(cellNames), obj.nCells)
                cellKey = cellNames{i};
                cell = state.cells.(cellKey);
                
                cellFeatures(i, :) = [
                    cell.cpuUsage,
                    cell.prbUsage,
                    cell.currentLoad,
                    cell.maxCapacity,
                    cell.numConnectedUEs,
                    cell.txPower,
                    cell.energyConsumption,
                    cell.avgRSRP,
                    cell.avgRSRQ,
                    cell.avgSINR,
                    cell.totalTrafficDemand,
                    cell.loadRatio
                ];
            end
            
            % Handle NaN values by replacing with defaults
            simulationFeatures(isnan(simulationFeatures) | isinf(simulationFeatures)) = 0;
            networkFeatures(isnan(networkFeatures) | isinf(networkFeatures)) = 0;
            cellFeatures(isnan(cellFeatures) | isinf(cellFeatures)) = 0;
            
            % Combine all features into single vector
            stateVector = [simulationFeatures(:); networkFeatures(:); cellFeatures(:)];
            
            % Convert to Python numpy array
            pyState = py.numpy.array(stateVector);
        end
        
        function actions = convertActionFromRL(obj, pyAction)
            % Convert RL action to simulation format (power ratios instead of binary)
            try
                actionArray = double(py.array.array('d', pyAction));
                
                if length(actionArray) == obj.nCells
                    actions = struct();
                    for i = 1:obj.nCells
                        % Clamp power ratio to [0, 1] range
                        powerRatio = max(0, min(1, actionArray(i)));
                        actions.(sprintf('cell_%d_power_ratio', i)) = powerRatio;
                    end
                else
                    fprintf('Warning: RL action length %d does not match number of cells %d\n', ...
                        length(actionArray), obj.nCells);
                end
                
            catch ME
                fprintf('Error converting power control action: %s\n', ME.message);
            end
        end
        
        function pyAction = convertActionToRL(obj, action)
            % Convert simulation action to RL format
            actionVector = zeros(obj.nCells, 1);
            
            for i = 1:obj.nCells
                fieldName = sprintf('cell_%d_power_ratio', i);
                if isfield(action, fieldName)
                    actionVector(i) = double(action.(fieldName));
                else
                    actionVector(i) = 1.0; % Default to maximum power
                end
            end
            
            pyAction = py.numpy.array(actionVector);
        end
        
        function stats = getTrainingStats(obj)
            if ~obj.isInitialized
                stats = struct();
                return;
            end
            
            try
                pyStats = obj.pythonAgent.get_stats();
                stats = obj.convertFromPythonDict(pyStats);
                
            catch ME
                fprintf('Error getting power control training stats: %s\n', ME.message);
                stats = struct('error', ME.message);
            end
        end
        
        function setTrainingMode(obj, training)
            if ~obj.isInitialized, return; end
            
            try
                obj.pythonAgent.set_training_mode(logical(training));
            catch ME
                fprintf('Error setting power control training mode: %s\n', ME.message);
            end
        end
        
        function matlabStruct = convertFromPythonDict(obj, pyDict)
            matlabStruct = struct();
            
            if isempty(pyDict) || isa(pyDict, 'py.NoneType')
                return;
            end
            
            try
                keysList = py.list(pyDict.keys());
                keys = cell(keysList);
                
                for i = 1:length(keys)
                    key = char(keys{i});
                    matlabKey = matlab.lang.makeValidName(key);
                    value = pyDict{keys{i}};
                    
                    if isa(value, 'py.NoneType')
                        matlabStruct.(matlabKey) = [];
                    elseif isa(value, 'py.bool')
                        matlabStruct.(matlabKey) = logical(value);
                    elseif isa(value, 'py.int') || isa(value, 'py.float')
                        matlabStruct.(matlabKey) = double(value);
                    elseif isa(value, 'py.str')
                        matlabStruct.(matlabKey) = char(value);
                    elseif isa(value, 'py.numpy.ndarray')
                        matlabStruct.(matlabKey) = double(value);
                    elseif isa(value, 'py.list')
                        listData = cell(value);
                        if ~isempty(listData) && all(cellfun(@isnumeric, listData))
                            matlabStruct.(matlabKey) = cell2mat(listData);
                        else
                            matlabStruct.(matlabKey) = listData;
                        end
                    else
                        matlabStruct.(matlabKey) = double(value);
                    end
                end
            catch ME
                fprintf('Warning: Error converting Python dict: %s\n', ME.message);
            end
        end
        
        function delete(obj)
            % Destructor
            try
                if obj.isInitialized && ~isempty(obj.pythonAgent)
                    obj.pythonAgent = [];
                end
            catch
                % Ignore cleanup errors
            end
        end
    end
end
% Helper function
function result = ternary(condition, trueValue, falseValue)
    if condition
        result = trueValue;
    else
        result = falseValue;
    end
end