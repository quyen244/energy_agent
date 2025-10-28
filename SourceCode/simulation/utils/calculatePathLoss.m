function pathLoss = calculatePathLoss(distance, frequency, ueId, currentTime, seed)
    plSeed = seed + 5000 + ueId + floor(currentTime * 100);
    plRng = RandStream('mt19937ar', 'Seed', plSeed);
    prevStream = RandStream.setGlobalStream(plRng);

    if distance < 10
        distance = 10; 
    end
    
    fc = frequency / 1e9; 
    hBS = 25; 
    hUT = 1.5;
    
    if distance <= 18
        pLOS = 1;
    else
        pLOS = 18/distance + exp(-distance/36) * (1 - 18/distance);
    end
    
    if rand() < pLOS
        pathLoss = 32.4 + 21*log10(distance) + 20*log10(fc);
    else
        pathLoss = 35.3*log10(distance) + 22.4 + 21.3*log10(fc) - 0.3*(hUT-1.5);
    end
    
    shadowFading = randn() * 4;
    pathLoss = pathLoss + shadowFading;

    RandStream.setGlobalStream(prevStream); 
end