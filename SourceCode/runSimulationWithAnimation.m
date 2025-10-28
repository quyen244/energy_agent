% Usage example function - add this to your main simulation
function runSimulationWithAnimation(scenarioName)
  if nargin < 1
      scenarioName = 'indoor_hotspot'; % Default scenario
  end
  
  % addpath('visualization'); % Ensure the visualization folder is in the path
  % addpath('simulation')
  % Run your existing simulation
  % simResults = run5GSimulation('indoor_hotspot', 42); % Example scenario and seed
  simResults = run5GSimulation(scenarioName, 42); % Example scenario and seed
  
  % Create basic topology animation
  createTopologyAnimation(simResults);
  
  fprintf('\nBoth animations have been created successfully!\n');
  fprintf('Files created:\n');
  fprintf('  - network_topology.gif (simple visualization)\n');
end