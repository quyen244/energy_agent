function results = runBenchmarkSuite(suite)
% Inputs:
%   suite: struct array with fields:
%       .name       - string or char, scenario short name or json path
%       .seed       - numeric seed (optional; default 42 if missing)
%
% Outputs:
%   Also writes energies.txt file with k energy values

    if ~isstruct(suite) || isempty(suite)
        error('Provide a non-empty struct array "suite" with fields name and optional seed.');
    end

    N = numel(suite);
    
    energies_output = zeros(N, 1);

    fprintf('\n=== Running Benchmark Suite (%d scenarios) ===\n', N);

    for i = 1:N
        s = suite(i);
        if ~isfield(s, 'seed') || isempty(s.seed); s.seed = 42; end

        fprintf('\n--- Scenario %d/%d: %s ---\n', i, N, string(s.name));
        
        try
            simResults = run5GSimulation(s.name, s.seed);
            if simResults.kpiViolations > 0
                fprintf('⚠️  Scenario %s has %d KPI violations.\n', string(s.name), simResults.kpiViolations);
                energies_output(i) = 0;
            else
                energies_output(i) = simResults.finalEnergyConsumption; % Convert to kWh
            end
        catch ME
            fprintf('Error in scenario %s: %s\n', string(s.name), ME.message);
        end
    end
    results = struct('energies', energies_output);
    write_energies_file(energies_output);
end

function write_energies_file(energies)
    filename = 'energies.txt';
    try
        fid = fopen(filename, 'w');
        if fid == -1
            error('Cannot open %s for writing', filename);
        end
        
        for i = 1:length(energies)
            fprintf(fid, '%.6f\n', energies(i));
        end
        
        fclose(fid);
        fprintf('\nWritten %d energy values to %s\n', length(energies), filename);
    catch ME
        fprintf('Error writing %s: %s\n', filename, ME.message);
        if exist('fid', 'var') && fid ~= -1
            fclose(fid);
        end
    end
end
