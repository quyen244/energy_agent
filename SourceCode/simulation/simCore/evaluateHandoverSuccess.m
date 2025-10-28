function hoSuccess = evaluateHandoverSuccess(ue, neighbor, servingCell, targetCell, currentTime, seed)
    hoRng = RandStream('mt19937ar', 'Seed', seed + ue.id + neighbor.cellId + floor(currentTime));
    prevStream = RandStream.setGlobalStream(hoRng);
    
    baseSuccessProb = 0.98; 
    
    if servingCell.txPower <= servingCell.minTxPower + 2
        sourcePowerPenalty = (servingCell.minTxPower + 2 - servingCell.txPower) * 0.15;
        baseSuccessProb = baseSuccessProb - sourcePowerPenalty;
    end
    
    if targetCell.txPower <= targetCell.minTxPower + 3
        targetPowerPenalty = (targetCell.minTxPower + 3 - targetCell.txPower) * 0.10;
        baseSuccessProb = baseSuccessProb - targetPowerPenalty;
    end
    
    if neighbor.rsrp >= -75
        signalBonus = 0.02;
    elseif neighbor.rsrp >= -85
        signalBonus = 0.01;
    elseif neighbor.rsrp >= -95
        signalBonus = 0.0;
    elseif neighbor.rsrp >= -105
        signalBonus = -0.05; 
    else
        signalBonus = -0.15; 
    end
    
    if neighbor.sinr >= 15
        sinrBonus = 0.02;
    elseif neighbor.sinr >= 5
        sinrBonus = 0.01;
    elseif neighbor.sinr >= 0
        sinrBonus = 0.0;
    elseif neighbor.sinr >= -5
        sinrBonus = -0.03;
    else
        sinrBonus = -0.10; 
    end
    
    if servingCell.txPower <= servingCell.minTxPower + 1 && targetCell.txPower <= targetCell.minTxPower + 1
        baseSuccessProb = baseSuccessProb - 0.20; 
    end
    
    if targetCell.cpuUsage > 85 || targetCell.prbUsage > 85
        congestionPenalty = 0.05;
        baseSuccessProb = baseSuccessProb - congestionPenalty;
    end
    
    finalSuccessProb = baseSuccessProb + signalBonus + sinrBonus;
    finalSuccessProb = max(0.25, min(0.98, finalSuccessProb));
    
    hoSuccess = rand() < finalSuccessProb;
    
    RandStream.setGlobalStream(prevStream);
end