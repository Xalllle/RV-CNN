# -*- coding: utf-8 -*-
"""
Created on Fri Jan 31 16:45:42 2025

@author: Alex
"""

import picture_generator

edge_detection = [[-1, 0, 1],
                  [-1, 0, 1],
                  [-1, 0, 1]]

point_detection = [[1, 1, 1],
                  [1, 0, 0],
                  [1, 0, 0]]

input_image = [[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
                [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]

def nmax(num_list):
    #Finds the maximum value in a list
    highest_value = 0
    for value in num_list:
        if value > highest_value:
            highest_value = value
    return highest_value
    
def normalize (in_matrix):
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
            out_matrix[i][j] = in_matrix[i][j]/max_value
            
            j += 1
    
        j = 0
        i += 1
    return out_matrix

def convolve(input_image, filter_matrix):
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
                    sum_number = filter_matrix[x][y] * input_image[x+i][y+j]
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



            
    

    
