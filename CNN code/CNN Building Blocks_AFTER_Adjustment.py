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
        

        
        
def convolve(input_image, weight_matrix, bias, filter_matrix):
    #Convolves two matrices
    square_iterator_size = len(input_image) - (len(filter_matrix) - 1)
    feature_map = [[0 for _ in range(square_iterator_size)] for _ in range(square_iterator_size)]
    i = 0
    while i < square_iterator_size:
        j = 0
        while j < square_iterator_size:
            sum_number = 0
            x = 0
            while x < len(filter_matrix):
                y = 0
                while y < len(filter_matrix[0]):
                    sum_number = (filter_matrix[x][y] * weight_matrix[x][y] * input_image[x+i][y+j]) + bias
                    feature_map[i][j] += sum_number 
                    y += 1
                
                x += 1
                sum_number = 0
            j += 1
        i += 1
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

def max_pooling(feature_map):
    size = math.floor(len(feature_map[0])/2)
    output_feature_map = [[0 for _ in range(size)] for _ in range(size)]
    i = 0
    while i < size:
        j = 0
        while j < size:

            output_feature_map[i][j] = max([feature_map[i][j],feature_map[2*i+1][2*j],feature_map[2*i][2*j+1],feature_map[2*i+1][2*j+1]])
            j += 1
        i += 1
    return output_feature_map
    



def sigmoid(x):
    if type(x) == list:
        result = []
        for row in x:
            new_row = []
            for val in row:
                new_row.append(round((1 / (1 + math.exp(-val))),2))
                result.append(new_row)
        return result
    elif type(x) == float:
        return round((1 / (1 + math.exp(-x))),2)

if __name__== "__main__":
    start_time = time.time()
    
    #mnist_list = mnist_data_interpreter.read('mnist_train.csv')
    #input_image = normalize([[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 51, 159, 253, 159, 50, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 48, 238, 252, 252, 252, 237, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 54, 227, 253, 252, 239, 233, 252, 57, 6, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 60, 224, 252, 253, 252, 202, 84, 252, 253, 122, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 163, 252, 252, 252, 253, 252, 252, 96, 189, 253, 167, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 51, 238, 253, 253, 190, 114, 253, 228, 47, 79, 255, 168, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 48, 238, 252, 252, 179, 12, 75, 121, 21, 0, 0, 253, 243, 50, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 38, 165, 253, 233, 208, 84, 0, 0, 0, 0, 0, 0, 253, 252, 165, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 7, 178, 252, 240, 71, 19, 28, 0, 0, 0, 0, 0, 0, 253, 252, 195, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 57, 252, 252, 63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 253, 252, 195, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 198, 253, 190, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 253, 196, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 76, 246, 252, 112, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 253, 252, 148, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 85, 252, 230, 25, 0, 0, 0, 0, 0, 0, 0, 0, 7, 135, 253, 186, 12, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 85, 252, 223, 0, 0, 0, 0, 0, 0, 0, 0, 7, 131, 252, 225, 71, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 85, 252, 145, 0, 0, 0, 0, 0, 0, 0, 48, 165, 252, 173, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 86, 253, 225, 0, 0, 0, 0, 0, 0, 114, 238, 253, 162, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 85, 252, 249, 146, 48, 29, 85, 178, 225, 253, 223, 167, 56, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 85, 252, 252, 252, 229, 215, 252, 252, 252, 196, 130, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 28, 199, 252, 252, 253, 252, 252, 233, 145, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 25, 128, 252, 253, 252, 141, 37, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]])
    
    '''
    Initialize trained values
    '''
    conv_layer_1_bias = read_file('train_data\conv_layer_1_bias.txt')
    conv_layer_1_weight = read_file('train_data\conv_layer_1_weight.txt')
    
    dense_layer_2_bias = read_file('train_data\dense_layer_2_bias.txt')
    dense_layer_2_weight = read_file('train_data\dense_layer_2_weight.txt')
    
    output_layer_3_bias = read_file('train_data\output_layer_3_bias.txt')
    output_layer_3_weight = read_file('train_data\output_layer_3_weight.txt')


    '''
    Initialize convolutional neurons
    '''
    convolutional_neurons = []
    i = 0
    while i < 5:
        convolutional_neurons.append(neuron(conv_layer_1_weight[9*i:9+9*i], conv_layer_1_bias[i]))
        print(conv_layer_1_weight[9*i:9+9*i], conv_layer_1_bias[i])
        i += 1




    end_time = time.time()
    elapsed_time = end_time - start_time
    print(f"Elapsed time: {elapsed_time:.4f} seconds")
    
    
    '''
    Picture Generation
    '''
    '''
    i = 0
    while i < len(layer_2_feature_maps):        
        picture_generator.matrix_to_bw_image(normalize(layer_2_feature_maps[i]), output_file=str(i) + ".png", scale_factor=10)
        i += 1
    '''
    

    
