# Reduced CNN Code
###Imports
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras.datasets import mnist
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Flatten, Dense

(train_images, train_labels), (test_images, test_labels) = mnist.load_data() # MNIST numbers dataset

train_images = train_images.reshape((60000, 28, 28))
test_images = test_images.reshape((10000, 28, 28))
train_images = train_images.astype('float32') / 255 #Grayscale values
test_images = test_images.astype('float32') / 255 #Grayscale values

# Training Set
train_images = train_images[:100] #must match the number of testing labels
test_images = test_images[:50] #must match the number of  testing labels

# Testing Set
train_labels = train_labels[:100]
test_labels = test_labels[:50]

############################################################ MAIN ML CODE ############################################################
# Define the model as a function
model = tf.keras.Sequential([
    tf.keras.layers.DepthwiseConv2D((3,3), activation='relu', padding='same',input_shape=(28,28,1)),  # Efficient conv layer
    tf.keras.layers.Flatten(),  
    tf.keras.layers.Dense(24, activation='relu'),  # Hidden layer
    tf.keras.layers.Dense(10, activation ='softmax')  # Output layer for 10 digits
])

model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

#Train the model
history = model.fit(train_images, train_labels, epochs=10, batch_size=5, validation_data=(test_images, test_labels))

### Compile and fit will likely need removal for RISC-V implementation, we can use pretrained weights and just add them to the RISC V model

############################################################ END ML CODE ############################################################