import numpy as np
from collections import deque, namedtuple


# Define transition structure
Transition = namedtuple('Transition', [
    'state', 'action', 'reward', 'next_state', 'done', 'log_prob', 'value'
])


class TransitionBuffer:
    """
    Experience replay buffer for PPO agent
    Stores transitions and provides batch sampling for training
    """
    
    def __init__(self, capacity=2048):
        """
        Initialize transition buffer
        
        Args:
            capacity (int): Maximum number of transitions to store
        """
        self.capacity = capacity
        self.buffer = deque(maxlen=capacity)
        self.position = 0
    
    def add(self, transition):
        """
        Add a transition to the buffer
        
        Args:
            transition (Transition): Transition tuple to add
        """
        if not isinstance(transition, Transition):
            raise TypeError("Expected Transition namedtuple")
        
        self.buffer.append(transition)
        self.position = (self.position + 1) % self.capacity
    
    def get_all(self):
        """
        Get all transitions in the buffer
        
        Returns:
            list: List of all transitions
        """
        return list(self.buffer)
    
    def sample(self, batch_size):
        """
        Sample a batch of transitions randomly
        
        Args:
            batch_size (int): Number of transitions to sample
            
        Returns:
            list: List of sampled transitions
        """
        if len(self.buffer) < batch_size:
            return list(self.buffer)
        
        indices = np.random.choice(len(self.buffer), batch_size, replace=False)
        return [self.buffer[i] for i in indices]
    
    def get_last_n(self, n):
        """
        Get the last n transitions
        
        Args:
            n (int): Number of recent transitions to get
            
        Returns:
            list: List of last n transitions
        """
        if n >= len(self.buffer):
            return list(self.buffer)
        
        return list(self.buffer)[-n:]
    
    def clear(self):
        """Clear all transitions from buffer"""
        self.buffer.clear()
        self.position = 0
    
    def __len__(self):
        """Get number of transitions in buffer"""
        return len(self.buffer)
    
    def is_full(self):
        """Check if buffer is at capacity"""
        return len(self.buffer) == self.capacity
    
    def get_statistics(self):
        """
        Get buffer statistics
        
        Returns:
            dict: Buffer statistics including reward stats
        """
        if len(self.buffer) == 0:
            return {
                'size': 0,
                'capacity': self.capacity,
                'is_full': False,
                'avg_reward': 0.0,
                'min_reward': 0.0,
                'max_reward': 0.0
            }
        
        rewards = [t.reward for t in self.buffer]
        
        return {
            'size': len(self.buffer),
            'capacity': self.capacity,
            'is_full': self.is_full(),
            'avg_reward': np.mean(rewards),
            'min_reward': np.min(rewards),
            'max_reward': np.max(rewards),
            'std_reward': np.std(rewards)
        }