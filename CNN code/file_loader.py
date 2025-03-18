# -*- coding: utf-8 -*-
"""
Created on Tue Mar 11 17:09:48 2025

@author: Alex
"""
def read_file(filepath):
    with open(filepath, 'r') as file:
        lines = file.readlines()
        return [float(line.strip()) for line in lines]

