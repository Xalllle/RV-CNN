# -*- coding: utf-8 -*-
"""
Created on Fri Jan 31 16:45:42 2025

@author: Alex
"""

import picture_generator
import random
import math
import mnist_data_interpreter
import time
from file_loader import read_file


class neuron():
    def __init__(self, weight, bias):
        self.weight = weight
        self.bias = bias
    def reshape_matrix(self, size):
        matrix = []
        for i in range(size):
            row = self.weight[i * size : (i + 1) * size]
            matrix.append(row)
        self.weight = matrix
        
def convolve(input_image, weight_matrix, bias):
    size_a = len(input_image)
    size_b = len(weight_matrix)

    result_size = size_a - size_b + 1

    feature_map = [[0.0 for _ in range(result_size)] for _ in range(result_size)]

    for i in range(result_size):
        for j in range(result_size):
            for m in range(size_b):
                for n in range(size_b):
                    feature_map[i][j] += float(input_image[i + m][j + n]) * float(weight_matrix[m][n])
            feature_map[i][j] += float(bias) # Ensure bias is also a float

    return feature_map

def relu(feature_map):
    #Removes all values lower than zero in a matrix
    output_feature_map = [[0 for _ in range(len(feature_map))] for _ in range(len(feature_map))]
    i = 0
    while i < len(feature_map):
        j = 0
        while j < len(feature_map[0]):
            if feature_map[i][j] < 0:
                output_feature_map[i][j] = 0
                j += 1
            else:
                output_feature_map[i][j] = feature_map[i][j]
                j += 1
        i += 1  
    return output_feature_map

def flatten(feature_maps_list):
    output_matrix = []
    for i in feature_maps_list:
        for m in i:
            for n in m:
                output_matrix.append(n)
    return output_matrix

def fully_connected(flattened_layer, weights, bias):
    activation = 0
    a = 0
    while a < len(flattened_layer):
        activation += flattened_layer[a] * weights[a]
        a += 1
    activation += bias
    return activation

def max_pooling(input_matrix):
  input_size = len(input_matrix)
  output_size = input_size // 2
  output_matrix = [[0 for _ in range(output_size)] for _ in range(output_size)]
  for i in range(output_size):
    for j in range(output_size):
      window = [[input_matrix[2 * i][2 * j], input_matrix[2 * i][2 * j + 1]], [input_matrix[2 * i + 1][2 * j], input_matrix[2 * i + 1][2 * j + 1]]]
      max_val = window[0][0]
      for row in window:
        for val in row:
          if val > max_val:
            max_val = val
      output_matrix[i][j] = max_val
  return output_matrix
    

def normalize(in_matrix):
    #Divides all of the numbers in a matrix by the highest number in the matrix
    '''
    max_value = 0
    for sublist in in_matrix:
        if max(sublist) > max_value:
            #max_value = max(sublist)
    '''
    max_value = 255
    out_matrix = [[0 for _ in range(len(in_matrix[0]))] for _ in range(len(in_matrix))]
    i=0
    j=0
    while i < len(in_matrix):
        while j < len(in_matrix[i]):
            if max_value != 0:
                out_matrix[i][j] = round(in_matrix[i][j]/max_value,2)
            else:
                out_matrix[i][j] = 0
            
            j += 1
    
        j = 0
        i += 1
    return out_matrix

def softmax(x):
  exp_x = [2.71828**val for val in x]
  sum_exp_x = sum(exp_x)
  return [val / sum_exp_x for val in exp_x]

    
def check_prediction(output, target_number):
  if output[0] > output[1]:
    predicted_number = 0
  else:
    predicted_number = 1

  if predicted_number == target_number:
    return 1
  else:
    return 0

if __name__== "__main__":
    '''
    Initialize trained values
    '''
    conv_layer_1_bias = read_file('train_data\conv_layer_1_bias.txt')
    conv_layer_1_weight = read_file('train_data\conv_layer_1_weight.txt')
    
    dense_layer_2_bias = read_file('train_data\dense_layer_2_bias.txt')
    dense_layer_2_weight = read_file('train_data\dense_layer_2_weight.txt')
    
    output_layer_3_bias = read_file('train_data\output_layer_3_bias.txt')
    output_layer_3_weight = read_file('train_data\output_layer_3_weight.txt')
    
    mnist_list = mnist_data_interpreter.read('mnist_train.csv')
    
    
    start_time = time.time()
    iteration = 0
    correct_number = 0
    for number in mnist_list:
        target_number = number[0]
        input_image = normalize(number[1])
        
    
        '''
        Convolutional Layer (5 kernels)
        '''
        convolutional_neurons = []
        i = 0
        while i < 5:
            convolutional_neurons.append(neuron(conv_layer_1_weight[9*i:9+9*i], conv_layer_1_bias[i]))
            convolutional_neurons[i].reshape_matrix(3)
            i += 1
    
        convolved_matrices = []
        i = 0
        while i < 5:
            convolved_matrices.append(relu(convolve(input_image, convolutional_neurons[i].weight, convolutional_neurons[i].bias)))
            i += 1
    
        """
        Pooling Layer
        """
    
        pooled_matrices = []
        i = 0
        while i < 5:
            pooled_matrices.append(max_pooling(convolved_matrices[i]))
            i += 1
    
    
        """
        Flattening Layer
        """
    
        flattened_layer = flatten(pooled_matrices)
        
        """
        Fully Connected Layer
        """
        
        dense_layer_2_neurons = []
        i = 0
        while i < 10:
            dense_layer_2_neurons.append(neuron(dense_layer_2_weight[845*i:845+845*i], dense_layer_2_bias[i]))
            i += 1
        
        fully_connected_layer = []
        i = 0
        while i < 10:
            fully_connected_layer.append(max(0,fully_connected(flattened_layer, dense_layer_2_neurons[i].weight, dense_layer_2_neurons[i].bias)))
            i += 1
         
        """
        Output Layer
        """
        output_layer_3_neurons = []
        i = 0
        while i < 2:
            output_layer_3_neurons.append(neuron(output_layer_3_weight[10*i:10+10*i], output_layer_3_bias[i]))
            i += 1
        
        output_layer = []
        i = 0
        while i < 2:
            output_layer.append(fully_connected(fully_connected_layer, output_layer_3_neurons[i].weight, output_layer_3_neurons[i].bias))
            i += 1
        final_output = softmax(output_layer)
        
        if(check_prediction(final_output, target_number) == 1):
            correct_number += 1
        iteration += 1
        accuracy = int((correct_number/iteration)*100)
        print("Iteration: ", iteration, " Accuracy = ", accuracy, "%")
        
    
    
    end_time = time.time()
    elapsed_time = end_time - start_time
    print("Elapsed Time: ", elapsed_time, " Accuracy: ", accuracy)

    

    
