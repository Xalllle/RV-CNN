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



class neuron():
    '''
    Neurons should be initialized in the main program block
    Stage => The stage that the neuron is in
    Bias => The bias factor when calculating the activation function (randomized)
    Weight => The factor that the parts of the filter in multiplied by (same size as filter) (randomized)
    Activation => Function that determines output of neuron (calculated with weight and bias)
    Description => Whether the neuron is a filter (kernel), pooling layer, or fully connected neuron.
    Info => Information used by the function. For kernel it should be type of filer, for pooling it can 
    be left blank, and for fully connected it is left blank.
    '''
    def __init__(self, stage, description, info):
        self.stage = stage
        self.bias = random.randrange(-100,101)/100 #generates a random bias
        self.type = description
        if self.type == "Kernel":
            self.weight = random_3x3_matrix() #generates a random weight
            self.info = kernel(info)
        elif self.type == "Output":
            self.info = info #The input size of the neuron, will be the length of the flattened hidden layer
            self.weight = [round(random.uniform(-1, 1),2) for _ in range(info)]
    def operate(self, input_image):
        '''
        Convolves the input image with the kernel selected at the object instantiation, then applies relu on it.
        '''
        if self.type == "Kernel":
            self.feature_map = normalize(sigmoid(convolve(input_image, self.weight, self.bias, self.info)))
        elif self.type == "Output":
            self.activation = weighted_sum_flat(input_image, self.weight) + self.bias
    
        
        
def random_3x3_matrix():
    '''
    Initially used, created issues with empty matrices
    '''
    matrix = []
    for _ in range(3):
        row = []
        for _ in range(3):
            row.append(random.randrange(-100, 101) / 100)  # Corrected range
        matrix.append(row)
    return matrix



def kernel(variety):
    kernel = [[0 for _ in range(3)] for _ in range(3)]

    if variety == "Prewitt Horizontal":
        kernel = [[-1,0,1],
                  [-1,0,1],
                  [-1,0,1]]
    elif variety == "Prewitt Vertical":
        kernel = [[1,1,1],
                  [0,0,0],
                  [-1,-1,-1]]
    elif variety == "Sobel Horizontal":
        kernel = [[-1,0,1],
                  [-2,0,2],
                  [-1,0,1]]
    elif variety == "Sobel Vertical":
        kernel = [[1,2,1],
                  [0,0,0],
                  [-1,-2,-1]]
    elif variety == "Laplacian":
        kernel = [[-1,-1,-1],
                  [-1,8,-1],
                  [-1,-1,-1]]
    else:
        raise ValueError('the specified filter \'' + str(variety) + 
                    '\' does not exist')
    return kernel

def weighted_sum_flat(in_matrix, weight_matrix):
    sum_out = 0
    i = 0
    while i < len(in_matrix):
        sum_out += in_matrix[i]*weight_matrix[i]
        i += 1
    return sum_out

def nmax(num_list):
    #Finds the maximum value in a list
    highest_value = 0
    for value in num_list:
        if value > highest_value:
            highest_value = value
    return highest_value
    
def normalize(in_matrix):
    #Divides all of the numbers in a matrix by the highest number in the matrix
    max_value = 0
    for sublist in in_matrix:
        if nmax(sublist) > max_value:
            max_value = nmax(sublist)
    out_matrix = [[0 for _ in range(len(in_matrix[0]))] for _ in range(len(in_matrix))]
    i=0
    j=0
    while i < len(in_matrix):
        while j < len(in_matrix):
            if max_value != 0:
                out_matrix[i][j] = round(in_matrix[i][j]/max_value,2)
            else:
                out_matrix[i][j] = 0
            
            j += 1
    
        j = 0
        i += 1
    return out_matrix

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

            output_feature_map[i][j] = nmax([feature_map[i][j],feature_map[2*i+1][2*j],feature_map[2*i][2*j+1],feature_map[2*i+1][2*j+1]])
            j += 1
        i += 1
    return output_feature_map
    



def sigmoid(x):
  result = []
  for row in x:
    new_row = []
    for val in row:
      new_row.append(1 / (1 + math.exp(-val)))
    result.append(new_row)
  return result

if __name__== "__main__":
    start_time = time.time()
    '''
    Initialize first layer of neurons as convolutional neurons
    '''
    #mnist_list = mnist_data_interpreter.read('mnist_train.csv')
    
    input_image = normalize([[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 51, 159, 253, 159, 50, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 48, 238, 252, 252, 252, 237, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 54, 227, 253, 252, 239, 233, 252, 57, 6, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 60, 224, 252, 253, 252, 202, 84, 252, 253, 122, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 163, 252, 252, 252, 253, 252, 252, 96, 189, 253, 167, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 51, 238, 253, 253, 190, 114, 253, 228, 47, 79, 255, 168, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 48, 238, 252, 252, 179, 12, 75, 121, 21, 0, 0, 253, 243, 50, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 38, 165, 253, 233, 208, 84, 0, 0, 0, 0, 0, 0, 253, 252, 165, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 7, 178, 252, 240, 71, 19, 28, 0, 0, 0, 0, 0, 0, 253, 252, 195, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 57, 252, 252, 63, 0, 0, 0, 0, 0, 0, 0, 0, 0, 253, 252, 195, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 198, 253, 190, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 253, 196, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 76, 246, 252, 112, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 253, 252, 148, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 85, 252, 230, 25, 0, 0, 0, 0, 0, 0, 0, 0, 7, 135, 253, 186, 12, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 85, 252, 223, 0, 0, 0, 0, 0, 0, 0, 0, 7, 131, 252, 225, 71, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 85, 252, 145, 0, 0, 0, 0, 0, 0, 0, 48, 165, 252, 173, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 86, 253, 225, 0, 0, 0, 0, 0, 0, 114, 238, 253, 162, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 85, 252, 249, 146, 48, 29, 85, 178, 225, 253, 223, 167, 56, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 85, 252, 252, 252, 229, 215, 252, 252, 252, 196, 130, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 28, 199, 252, 252, 253, 252, 252, 233, 145, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 25, 128, 252, 253, 252, 141, 37, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]])
    
    layer_1 = []
    layer_1.append(neuron(1, "Kernel", "Prewitt Horizontal"))
    layer_1.append(neuron(1, "Kernel", "Prewitt Vertical"))
    layer_1.append(neuron(1, "Kernel", "Sobel Horizontal"))
    layer_1.append(neuron(1, "Kernel", "Sobel Vertical"))
    layer_1.append(neuron(1, "Kernel", "Laplacian"))
    
    
    
    '''
    Initialize second layer of neurons as convolutional neurons
    '''
    
    layer_2 = []
    layer_2.append(neuron(2, "Kernel", "Prewitt Horizontal"))
    layer_2.append(neuron(2, "Kernel", "Prewitt Vertical"))
    layer_2.append(neuron(2, "Kernel", "Sobel Horizontal"))
    layer_2.append(neuron(2, "Kernel", "Sobel Vertical"))
    layer_2.append(neuron(2, "Kernel", "Laplacian"))
    
    '''
    Initialize output layer neurons
    '''
    output_layer = []
    output_layer.append(neuron(3, "Output", 3025)) #Detects 0
    output_layer.append(neuron(3, "Output", 3025)) #Detects 1
    
    '''
    First Layer: Convolution
    '''
    layer_1_feature_maps = []
    x = 0
    for n in layer_1:
        n.operate(input_image)
        layer_1_feature_maps.append(n.feature_map)
        
    '''
    Second Layer: Pooling Layer
    '''
    
    i = 0
    while i < len(layer_1):
        layer_1[i].feature_map = max_pooling(layer_1[i].feature_map)
        i += 1
         
    '''
    Third Layer: Convolution
    '''
    layer_2_feature_maps = []
    for n in layer_1:
        for m in layer_2:
            m.operate(n.feature_map)
            layer_2_feature_maps.append(m.feature_map)
            x += 1
            
    '''
    Fourth Layer: Fully Connected (flattening occurs here as well)
    '''
    flattened_output = flatten(layer_2_feature_maps)
    for n in output_layer:
        n.operate(flattened_output)
        print(n.activation)







    end_time = time.time()
    elapsed_time = end_time - start_time
    print(f"Elapsed time: {elapsed_time:.4f} seconds")
    
    
    '''
    Picture Generation
    '''
    i = 0
    while i < len(layer_2_feature_maps):        
        picture_generator.matrix_to_bw_image(layer_2_feature_maps[i], output_file=str(i) + ".png", scale_factor=10)
        i += 1
    

    
