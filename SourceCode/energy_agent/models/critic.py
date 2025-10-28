import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np


class Critic(nn.Module):
    """
    Critic network for PPO agent
    Estimates state values for policy gradient methods
    """
    
    def __init__(self, state_dim, hidden_dim=256, activation='relu'):
        """
        Initialize Critic network
        
        Args:
            state_dim (int): Dimension of input state
            hidden_dim (int): Hidden layer dimension
            activation (str): Activation function type
        """
        super(Critic, self).__init__()
        
        self.state_dim = state_dim
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
        self.value_head = nn.Linear(hidden_dim // 2, 1)
        
        # Initialize weights
        self.init_weights()
    
    def init_weights(self):
        """Initialize network weights using orthogonal initialization"""
        for layer in [self.fc1, self.fc2, self.fc3]:
            nn.init.orthogonal_(layer.weight, gain=np.sqrt(2))
            nn.init.zeros_(layer.bias)
        
        # Initialize value head with smaller weights
        nn.init.orthogonal_(self.value_head.weight, gain=1.0)
        nn.init.zeros_(self.value_head.bias)
    
    def forward(self, state):
        """
        Forward pass through critic network
        
        Args:
            state (torch.Tensor): Input state tensor
            
        Returns:
            torch.Tensor: Estimated state value
        """
        x = self.activation_fn(self.fc1(state))
        x = self.activation_fn(self.fc2(x))
        x = self.activation_fn(self.fc3(x))
        
        value = self.value_head(x)
        
        return value