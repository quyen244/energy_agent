function exportToGif(fig, filename)
    % Export the current animation to GIF
    
    fprintf('Exporting animation to GIF: %s\n', filename);
    
    % Get animation data
    numSteps = getappdata(fig, 'numSteps');
    animData = getappdata(fig, 'animData');
    originalFrame = animData.currentFrame;
    
    % Animation parameters
    frameSkip = max(1, floor(numSteps/100)); % Limit to ~100 frames max
    delayTime = 0.2; % Delay between frames in seconds
    
    % Create progress dialog
    progressDlg = waitbar(0, 'Exporting frames to GIF...', 'Name', 'Export Progress');
    
    try
        frameCount = 0;
        for step = 1:frameSkip:numSteps
            frameCount = frameCount + 1;
            
            % Update frame
            animData.currentFrame = step;
            setappdata(fig, 'animData', animData);
            updateFrame(fig);
            
            % Capture frame
            frame = getframe(fig);
            im = frame2im(frame);
            [imind, cm] = rgb2ind(im, 256);
            
            % Write to GIF file
            if frameCount == 1
                imwrite(imind, cm, filename, 'gif', 'Loopcount', inf, ...
                        'DelayTime', delayTime);
            else
                imwrite(imind, cm, filename, 'gif', 'WriteMode', 'append', ...
                        'DelayTime', delayTime);
            end
            
            % Update progress
            progress = frameCount / ceil(numSteps/frameSkip);
            waitbar(progress, progressDlg, ...
                   sprintf('Exporting frame %d/%d', frameCount, ceil(numSteps/frameSkip)));
            
            % Check if user cancelled
            if ~ishandle(progressDlg)
                break;
            end
        end
        
        % Close progress dialog
        if ishandle(progressDlg)
            close(progressDlg);
        end
        
        % Restore original frame
        animData.currentFrame = originalFrame;
        setappdata(fig, 'animData', animData);
        updateFrame(fig);
        
        fprintf('GIF export completed: %s\n', filename);
        fprintf('Total frames: %d\n', frameCount);
        fprintf('Animation duration: %.1f seconds\n', frameCount * delayTime);
        
    catch ME
        % Close progress dialog on error
        if ishandle(progressDlg)
            close(progressDlg);
        end
        
        % Restore original frame
        animData.currentFrame = originalFrame;
        setappdata(fig, 'animData', animData);
        updateFrame(fig);
        
        fprintf('Error during GIF export: %s\n', ME.message);
        rethrow(ME);
    end
end