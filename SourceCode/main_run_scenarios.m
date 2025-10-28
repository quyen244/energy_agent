function main_run_scenarios()
% Runs all scenarios and outputs energies.txt

    % Get all JSON files from scenarios folder
    scenario_folder = 'scenarios';
    if ~exist(scenario_folder, 'dir')
        error('Scenarios folder "%s" not found', scenario_folder);
    end
    
    % Find all .json files in the scenarios folder
    json_files = dir(fullfile(scenario_folder, '*.json'));
    
    if isempty(json_files)
        error('No JSON scenario files found in "%s" folder', scenario_folder);
    end
    
    % Dynamically create suite based on found files
    suite = [];
    for i = 1:length(json_files)
        % Extract scenario name (remove .json extension)
        [~, scenario_name, ~] = fileparts(json_files(i).name);
        
        % Add to suite
        suite = [suite; struct('name', scenario_name, 'seed', 42)];
    end
    
    fprintf('Found %d scenario files:\n', length(suite));
    for i = 1:length(suite)
        fprintf('  %d. %s\n', i, suite(i).name);
    end
    
    % % Add simulation path if needed
    % if exist('simulation', 'dir')
    %     addpath('simulation');
    % end
    
    % Run benchmark suite
    results = runBenchmarkSuite(suite);
    
    fprintf('\nenergies.txt generated with %d values\n', length(results.energies));
    
    % Display energy values for verification
    fprintf('\nEnergy values written to energies.txt:\n');
    for i = 1:length(results.energies)
        fprintf('  Scenario %d (%s): %.6f kWh\n', i, suite(i).name, results.energies(i));
    end
        
end