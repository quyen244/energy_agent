function configTopologyAnimation(inputFilename, outputFilename, newDelayTime)
    reduceGifDelayTime(inputFilename, outputFilename, newDelayTime);
end

function reduceGifDelayTime(inputFilename, outputFilename, newDelayTime)
    % Reduce delay time of existing GIF
    % Input: inputFilename - existing GIF file
    %        outputFilename - new GIF file (optional)
    %        newDelayTime - new delay time in seconds (optional, default 0.01)
    
    if nargin < 2
        [~, name, ~] = fileparts(inputFilename);
        outputFilename = [name '_superfast.gif'];
    end
    
    if nargin < 3
        newDelayTime = 0.2;
    end
    
    fprintf('Reading GIF: %s\n', inputFilename);
    
    % Get GIF info
    info = imfinfo(inputFilename);
    numFrames = length(info);
    
    fprintf('Processing %d frames...\n', numFrames);
    
    % Write new GIF with reduced delay time
    for i = 1:numFrames
        % Read each frame with its colormap
        [currentFrame, cm] = imread(inputFilename, 'gif', i);
        fprintf('Processing frame %d/%d...\n', i, numFrames);
        % Write frame with new delay time
        if i == 1
            imwrite(currentFrame, cm, outputFilename, 'gif', ...
                    'Loopcount', inf, 'DelayTime', newDelayTime);
        else
            imwrite(currentFrame, cm, outputFilename, 'gif', ...
                    'WriteMode', 'append', 'DelayTime', newDelayTime);
        end
    end
    
    fprintf('Fast GIF saved as: %s\n', outputFilename);
    fprintf('New delay time: %.3f seconds per frame\n', newDelayTime);
    fprintf('Total animation duration: %.2f seconds\n', numFrames * newDelayTime);
end