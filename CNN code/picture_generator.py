from PIL import Image
import numpy as np

def matrix_to_bw_image(matrix, output_file='output_image.png', scale_factor=10):
    """
    Converts an n x n matrix with values between 0 and 1 into a black and white image.

    :param matrix: 2D list or numpy array with values between 0 and 1.
    :param output_file: Path for the output image file.
    :param scale_factor: Factor by which to scale the image for better viewing.
    """
    # Ensure the matrix is a numpy array for easier manipulation
    matrix = np.array(matrix)

    # Validate matrix values
    if not np.all((0 <= matrix) & (matrix <= 1)):
        raise ValueError("Matrix values must be between 0 and 1.")

    # Scale matrix to 0-255 grayscale values
    grayscale_matrix = (matrix * 255).astype(np.uint8)

    # Create an image from the matrix
    img = Image.fromarray(grayscale_matrix, mode='L')

    # Scale the image up by the scale factor
    width, height = img.size
    img = img.resize((width * scale_factor, height * scale_factor), Image.NEAREST)

    # Save the image
    img.save(output_file)
    print(f"Image saved as '{output_file}'")

