import pandas as pd

def read(file_path):
    """
    Reads the mnist_train.csv file, filters for labels 0 and 1, and returns 
    the data as a list of lists, where the pixel data is a nested list (28x28).

    Args:
        file_path (str): The path to the mnist_train.csv file.

    Returns:
        list: A list of lists, where each inner list represents a row 
              and has the structure [label, nested_list_28x28].
              Returns None if an error occurs.
    Raises FileNotFoundError if file_path is invalid.
    """
    try:
        df = pd.read_csv(file_path)
        mask = (df.iloc[:, 0] == 0) | (df.iloc[:, 0] == 1)
        filtered_df = df[mask]

        data_list = []
        for _, row in filtered_df.iterrows():
            label = int(row[0])
            pixels = row[1:].tolist()  # Get pixel values as a flat list

            # Reshape into a nested list (28x28)
            matrix = []
            for i in range(0, len(pixels), 28):
                matrix.append(pixels[i:i + 28])

            data_list.append([label, matrix])

        return data_list

    except FileNotFoundError:
        raise FileNotFoundError(f"File not found: {file_path}")
    except Exception as e:
        print(f"An error occurred: {e}")
        return None

