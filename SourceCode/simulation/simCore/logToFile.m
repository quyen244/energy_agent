function logToFile(logFile, currentTime, message)
    try
        fid = fopen(logFile, 'a');
        if fid ~= -1
            fprintf(fid, '[%.3f] %s', currentTime, message);
            fclose(fid);
        end
    catch
    end
end