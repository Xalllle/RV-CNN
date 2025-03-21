# Reduced CNN Code
###Imports
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras.datasets import mnist
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Flatten, Dense

(train_images, train_labels), (test_images, test_labels) = mnist.load_data() # MNIST numbers dataset

# Reshape images for CNN
train_images = train_images.reshape((60000, 28, 28))
test_images = test_images.reshape((10000, 28, 28))

# Normalize images to grayscale values
train_images = train_images.astype('float32') / 255
test_images = test_images.astype('float32') / 255

# Filter for only 0s and 1s in the training set
train_filter = (train_labels == 0) | (train_labels == 1)
train_images, train_labels = train_images[train_filter], train_labels[train_filter]

# Filter for only 0s and 1s in the testing set
test_filter = (test_labels == 0) | (test_labels == 1)
test_images, test_labels = test_images[test_filter], test_labels[test_filter]

# Subsample to reduce data size (optional)
train_images = train_images[:1000]
test_images = test_images[:500]
train_labels = train_labels[:1000]
test_labels = test_labels[:500]

############################################################ MAIN ML CODE ############################################################
# Define the model as a function
model = tf.keras.Sequential([
    tf.keras.layers.Conv2D(filters=5, kernel_size=(3,3), activation='relu', input_shape=(28,28,1)),
    tf.keras.layers.MaxPooling2D((2,2)),
    tf.keras.layers.Flatten(),  
    tf.keras.layers.Dense(10, activation='relu'),  # Hidden layer
    tf.keras.layers.Dense(2, activation ='softmax')  # Output layer for 2 digits
])

model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])

#Train the model
history = model.fit(train_images, train_labels, epochs=10, batch_size=5, validation_data=(test_images, test_labels))

### Compile and fit will likely need removal for RISC-V implementation, we can use pretrained weights and just add them to the RISC V model

# Export weights as readable text files
for i, layer in enumerate(model.layers):
    weights = layer.get_weights()
    if weights:  # Only export if the layer has weights
        np.savetxt(f"weights_layer_{i}.txt", weights[0].flatten(), fmt="%.6f")  # Kernel weights
        if len(weights) > 1:
            np.savetxt(f"bias_layer_{i}.txt", weights[1].flatten(), fmt="%.6f")  # Bias weights

############################################################ END ML CODE ############################################################