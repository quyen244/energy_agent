import numpy as np

class StateNormalizer:
    """Handles state normalization with running statistics"""
    
    def __init__(self, state_dim, epsilon=1e-8, n_cells=10):
        self.state_dim = state_dim
        self.epsilon = epsilon
        self.n_cells = n_cells

        # Simulation features normalization bounds (first 17 features)
        self.simulation_bounds = {
            'totalCells': [1, 50],               # number of cells
            'totalUEs': [1, 500],                # number of UEs
            'simTime': [600, 3600],              # simulation time
            'timeStep': [1, 10],                 # time step
            'timeProgress': [0, 1],              # progress ratio
            'carrierFrequency': [700e6, 6e9],    # frequency Hz
            'isd': [100, 2000],                  # inter-site distance
            'minTxPower': [0, 46],               # dBm
            'maxTxPower': [0, 46],              # dBm
            'basePower': [100, 100000],            # watts
            'idlePower': [50, 50000],              # watts
            'dropCallThreshold': [1, 10],        # percentage
            'latencyThreshold': [10, 100],       # ms
            'cpuThreshold': [70, 95],            # percentage
            'prbThreshold': [70, 95],            # percentage
            'trafficLambda': [0.1, 10],          # traffic rate
            'peakHourMultiplier': [1, 5]         # multiplier
        }
        
        # Network features normalization bounds (next 14 features)
        self.network_bounds = {
            'totalEnergy': [0, 10000],           # kWh
            'activeCells': [0, 50],              # number of cells
            'avgDropRate': [0, 20],              # percentage
            'avgLatency': [0, 200],              # ms
            'totalTraffic': [0, 5000],           # traffic units
            'connectedUEs': [0, 500],            # number of UEs
            'connectionRate': [0, 100],         # percentage
            'cpuViolations': [0, 10000],            # number of violations
            'prbViolations': [0, 10000],            # number of violations
            'maxCpuUsage': [0, 100],             # percentage
            'maxPrbUsage': [0, 100],             # percentage
            'kpiViolations': [0, 10000],          # number of violations
            'totalTxPower': [0, 1000],           # total power
            'avgPowerRatio': [0, 1]              # ratio
        }
        
        # Cell features normalization bounds (12 features per cell)
        self.cell_bounds = {
            'cpuUsage': [0, 100],                # percentage
            'prbUsage': [0, 100],                # percentage
            'currentLoad': [0, 1000],            # load units
            'maxCapacity': [0, 1000],            # capacity units
            'numConnectedUEs': [0, 50],          # number of UEs
            'txPower': [0, 46],                  # dBm
            'energyConsumption': [0, 5000],      # watts
            'avgRSRP': [-140, -70],              # dBm
            'avgRSRQ': [-20, 0],                 # dB
            'avgSINR': [-10, 30],                # dB
            'totalTrafficDemand': [0, 500],      # traffic units
            'loadRatio': [0, 1]                  # ratio
        }
    
    def normalize(self, state_vector):
        """
        Normalize state vector to [0, 1] range
        
        State structure:
        [sim_1, ..., sim_17,              # Index 0-16 (17 features)
         net_1, ..., net_14,              # Index 17-30 (14 features)
         c1_f1, c2_f1, ..., cn_f1,       # cpuUsage for all cells
         c1_f2, c2_f2, ..., cn_f2,       # prbUsage for all cells
         ...                              # etc for all 12 cell features
         c1_f12, c2_f12, ..., cn_f12]    # loadRatio for all cells
        """
        normalized = np.zeros_like(state_vector)
        
        # Normalize simulation features (indices 0-16)
        simulation_keys = list(self.simulation_bounds.keys())
        for i, key in enumerate(simulation_keys):
            if i < len(state_vector):
                min_val, max_val = self.simulation_bounds[key]
                normalized[i] = self._normalize_value(state_vector[i], min_val, max_val)
        
        # Normalize network features (indices 17-30)
        network_keys = list(self.network_bounds.keys())
        for i, key in enumerate(network_keys):
            global_idx = 17 + i
            if global_idx < len(state_vector):
                min_val, max_val = self.network_bounds[key]
                normalized[global_idx] = self._normalize_value(state_vector[global_idx], min_val, max_val)
        
        # Normalize cell features (indices 31 onwards)
        cell_keys = list(self.cell_bounds.keys())
        start_idx = 31  # After simulation (17) and network (14) features
        
        for feat_idx, key in enumerate(cell_keys):
            min_val, max_val = self.cell_bounds[key]
            
            # Normalize all cells for this feature
            for cell_idx in range(self.n_cells):
                global_idx = start_idx + feat_idx * self.n_cells + cell_idx
                if global_idx < len(state_vector):
                    normalized[global_idx] = self._normalize_value(
                        state_vector[global_idx], min_val, max_val)
        
        return normalized
    
    def _normalize_value(self, value, min_val, max_val):
        """Normalize single value to [0, 1] range"""
        if max_val == min_val:
            return 0.5  # Default middle value
        return np.clip((value - min_val) / (max_val - min_val), 0.0, 1.0)
    
    def update_stats(self, state_vector):
        pass