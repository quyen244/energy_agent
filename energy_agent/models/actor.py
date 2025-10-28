import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np


class Actor(nn.Module):
    """
    Actor network for PPO agent
    Outputs continuous actions (power ratios) for each cell
    Uses Gaussian policy with learned standard deviation
    """
    
    def __init__(self, state_dim, action_dim, hidden_dim=256, activation='relu'):
        """
        Initialize Actor network
        
        Args:
            state_dim (int): Dimension of input state
            action_dim (int): Dimension of output action
            hidden_dim (int): Hidden layer dimension
            activation (str): Activation function type
        """
        super(Actor, self).__init__()
        
        self.state_dim = state_dim
        self.action_dim = action_dim
        self.hidden_dim = hidden_dim
        
        # Choose activation function
        if activation == 'relu':
            self.activation_fn = F.relu
        elif activation == 'tanh':
            self.activation_fn = torch.tanh
        elif activation == 'elu':
            self.activation_fn = F.elu
        else:
            self.activation_fn = F.relu
        
        # Network layers
        self.fc1 = nn.Linear(state_dim, hidden_dim)
        self.fc2 = nn.Linear(hidden_dim, hidden_dim)
        self.fc3 = nn.Linear(hidden_dim, hidden_dim // 2)
        
        # Action mean head
        self.action_mean = nn.Linear(hidden_dim // 2, action_dim)
        
        # Action standard deviation head (learnable)
        self.action_logstd = nn.Linear(hidden_dim // 2, action_dim)
        
        # Initialize weights
        self.init_weights()
    
    def init_weights(self):
        """Initialize network weights using orthogonal initialization"""
        for layer in [self.fc1, self.fc2, self.fc3]:
            nn.init.orthogonal_(layer.weight, gain=np.sqrt(2))
            nn.init.zeros_(layer.bias)
        
        # Initialize action mean with smaller weights for stability
        nn.init.orthogonal_(self.action_mean.weight, gain=0.01)
        nn.init.zeros_(self.action_mean.bias)
        
        # Initialize log std to produce reasonable initial exploration
        nn.init.constant_(self.action_logstd.weight, 0.0)
        nn.init.constant_(self.action_logstd.bias, -0.5)  # Initial std ≈ 0.6
    
    def forward(self, state):
        """
        Forward pass through actor network
        
        Args:
            state (torch.Tensor): Input state tensor
            
        Returns:
            tuple: (action_mean, action_logstd)
        """
        # Forward through shared layers
        x = self.activation_fn(self.fc1(state))
        x = self.activation_fn(self.fc2(x))
        x = self.activation_fn(self.fc3(x))
        
        # Compute action mean (bounded to [0, 1] using sigmoid)
        action_mean = torch.sigmoid(self.action_mean(x))
        
        # Compute action log standard deviation (bounded for stability)
        action_logstd = torch.clamp(self.action_logstd(x), min=-20, max=2)
        
        return action_mean, action_logstd
