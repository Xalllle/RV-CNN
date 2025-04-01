#include <vector>
#include <fstream>
#include <string>
#include <sstream>
#include <cmath>
#include <numeric>
#include <iostream>
#include <iomanip>
#include <algorithm>
#include <limits>

using namespace std;

using Matrix = vector<vector<double>>;
using Vector = vector<double>;
using DataPair = pair<int, Matrix>;
using DataList = vector<DataPair>;

Vector read_file(const string& filepath) {
    ifstream file(filepath);
    string line;
    Vector result;
    while (getline(file, line)) {
        if (!line.empty()) {
            result.push_back(round(stod(line) * 10.0) / 10.0);
        }
    }
    return result;
}

DataList read_csv(const string& file_path) {
    ifstream file(file_path);
    string line;
    DataList data_list;
    getline(file, line);

    while (getline(file, line)) {
        stringstream ss(line);
        string cell;
        Vector row_values;

        getline(ss, cell, ',');
        int label = stoi(cell);

        if (label == 0 || label == 1) {
            row_values.push_back(static_cast<double>(label));
            while (getline(ss, cell, ',')) {
                row_values.push_back(stod(cell));
            }

            Matrix matrix(28, Vector(28));
            for (int i = 0; i < 28; ++i) {
                for (int j = 0; j < 28; ++j) {
                    matrix[i][j] = row_values[1 + i * 28 + j];
                }
            }
            data_list.push_back({label, matrix});
        }
    }
    return data_list;
}


struct Neuron {
    Vector weight;
    double bias;
    Matrix weight_matrix;

    Neuron(const Vector& w, double b) : weight(w), bias(b) {}

    void reshape_matrix(int size) {
        weight_matrix.assign(size, Vector(size));
        for (int i = 0; i < size; ++i) {
            for (int j = 0; j < size; ++j) {
                weight_matrix[i][j] = weight[i * size + j];
            }
        }
    }
};


Matrix convolve(const Matrix& input_image, const Matrix& weight_matrix, double bias) {
    int size_a = input_image.size();
    int size_b = weight_matrix.size();
    int result_size = size_a - size_b + 1;

    Matrix feature_map(result_size, Vector(result_size, 0.0));

    for (int i = 0; i < result_size; ++i) {
        for (int j = 0; j < result_size; ++j) {
            double sum = 0.0;
            for (int m = 0; m < size_b; ++m) {
                for (int n = 0; n < size_b; ++n) {
                    sum += input_image[i + m][j + n] * weight_matrix[m][n];
                }
            }
            feature_map[i][j] = sum + bias;
        }
    }
    return feature_map;
}

Matrix relu(const Matrix& feature_map) {
    int rows = feature_map.size();
    int cols = (rows > 0) ? feature_map[0].size() : 0;
    Matrix output_feature_map(rows, Vector(cols));

    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < cols; ++j) {
            output_feature_map[i][j] = max(0.0, feature_map[i][j]);
        }
    }
    return output_feature_map;
}


Matrix max_pooling(const Matrix& input_matrix) {
    int input_size = input_matrix.size();
    int output_size = input_size / 2;
    Matrix output_matrix(output_size, Vector(output_size));

    for (int i = 0; i < output_size; ++i) {
        for (int j = 0; j < output_size; ++j) {
            double max_val = input_matrix[2 * i][2 * j];
            max_val = max(max_val, input_matrix[2 * i][2 * j + 1]);
            max_val = max(max_val, input_matrix[2 * i + 1][2 * j]);
            max_val = max(max_val, input_matrix[2 * i + 1][2 * j + 1]);
            output_matrix[i][j] = max_val;
        }
    }
    return output_matrix;
}

Vector flatten(const vector<Matrix>& feature_maps_list) {
    Vector output_vector;
    for (const auto& matrix : feature_maps_list) {
        for (const auto& row : matrix) {
            output_vector.insert(output_vector.end(), row.begin(), row.end());
        }
    }
    return output_vector;
}

double fully_connected(const Vector& flattened_layer, const Vector& weights, double bias) {
    double activation = 0.0;
    for (size_t i = 0; i < flattened_layer.size(); ++i) {
        activation += flattened_layer[i] * weights[i];
    }
    activation += bias;
    return activation;
}


Matrix normalize(const Matrix& in_matrix) {
    double max_value = 0.0;
     if (in_matrix.empty() || in_matrix[0].empty()) {
        return in_matrix;
    }

    for (const auto& row : in_matrix) {
        for (double val : row) {
            if (val > max_value) {
                max_value = val;
            }
        }
    }

    int rows = in_matrix.size();
    int cols = in_matrix[0].size();
    Matrix out_matrix(rows, Vector(cols));

    for (int i = 0; i < rows; ++i) {
        for (int j = 0; j < cols; ++j) {
            if (max_value != 0.0) {
                out_matrix[i][j] = round((in_matrix[i][j] / max_value) * 100.0) / 100.0;
            } else {
                out_matrix[i][j] = 0.0;
            }
        }
    }
    return out_matrix;
}

Vector softmax(const Vector& x) {
    Vector exp_x;
    double sum_exp_x = 0.0;
    for (double val : x) {
        double exp_val = exp(val);
        exp_x.push_back(exp_val);
        sum_exp_x += exp_val;
    }

    Vector result;
     if (sum_exp_x == 0) {
        return Vector(x.size(), 0.0);
     }
    for (double val : exp_x) {
        result.push_back(val / sum_exp_x);
    }
    return result;
}


int check_prediction(const Vector& output, int target_number) {
    int predicted_number = (output[0] > output[1]) ? 0 : 1;
    return (predicted_number == target_number) ? 1 : 0;
}

int main() {
    Vector conv_layer_1_bias = read_file("train_data/conv_layer_1_bias.txt");
    Vector conv_layer_1_weight = read_file("train_data/conv_layer_1_weight.txt");

    Vector dense_layer_2_bias = read_file("train_data/dense_layer_2_bias.txt");
    Vector dense_layer_2_weight = read_file("train_data/dense_layer_2_weight.txt");

    Vector output_layer_3_bias = read_file("train_data/output_layer_3_bias.txt");
    Vector output_layer_3_weight = read_file("train_data/output_layer_3_weight.txt");

    DataList mnist_list = read_csv("mnist_train.csv");

    int iteration = 0;
    int correct_number = 0;
    double accuracy = 0.0;

    for (const auto& number_data : mnist_list) {
         if (iteration >= 12665) break;

        int target_number = number_data.first;
        Matrix input_image = normalize(number_data.second);

        vector<Neuron> convolutional_neurons;
        for (int i = 0; i < 5; ++i) {
             Vector weights_slice(conv_layer_1_weight.begin() + 9 * i, conv_layer_1_weight.begin() + 9 + 9 * i);
            convolutional_neurons.emplace_back(weights_slice, conv_layer_1_bias[i]);
            convolutional_neurons.back().reshape_matrix(3);
        }

        vector<Matrix> convolved_matrices;
        for (int i = 0; i < 5; ++i) {
            convolved_matrices.push_back(relu(convolve(input_image, convolutional_neurons[i].weight_matrix, convolutional_neurons[i].bias)));
        }

        vector<Matrix> pooled_matrices;
        for (int i = 0; i < 5; ++i) {
            pooled_matrices.push_back(max_pooling(convolved_matrices[i]));
        }

        Vector flattened_layer = flatten(pooled_matrices);

        vector<Neuron> dense_layer_2_neurons;
         int dense_weight_size = 845;
        for (int i = 0; i < 10; ++i) {
             if(dense_layer_2_weight.size() < dense_weight_size * i + dense_weight_size || dense_layer_2_bias.size() <= i){
                 cerr << "Error: Index out of bounds for dense layer weights/bias. Iteration: " << i << endl;
                 return 1;
             }
             Vector weights_slice(dense_layer_2_weight.begin() + dense_weight_size * i, dense_layer_2_weight.begin() + dense_weight_size + dense_weight_size * i);
            dense_layer_2_neurons.emplace_back(weights_slice, dense_layer_2_bias[i]);
        }


        Vector fully_connected_layer;
        for (int i = 0; i < 10; ++i) {
            double activation = fully_connected(flattened_layer, dense_layer_2_neurons[i].weight, dense_layer_2_neurons[i].bias);
            fully_connected_layer.push_back(max(0.0, activation));
        }

        vector<Neuron> output_layer_3_neurons;
        int output_weight_size = 10;
        for (int i = 0; i < 2; ++i) {
            if(output_layer_3_weight.size() < output_weight_size*i + output_weight_size || output_layer_3_bias.size() <=i) {
                 cerr << "Error: Index out of bounds for output layer weights/bias. Iteration: " << i << endl;
                 return 1;
            }
            Vector weights_slice(output_layer_3_weight.begin() + output_weight_size * i, output_layer_3_weight.begin() + output_weight_size + output_weight_size * i);
            output_layer_3_neurons.emplace_back(weights_slice, output_layer_3_bias[i]);
        }

        Vector output_layer;
        for (int i = 0; i < 2; ++i) {
             output_layer.push_back(fully_connected(fully_connected_layer, output_layer_3_neurons[i].weight, output_layer_3_neurons[i].bias));
        }

        Vector final_output = softmax(output_layer);

        if (!final_output.empty()){
             correct_number += check_prediction(final_output, target_number);
        }
        iteration++;
        if (iteration > 0) {
             accuracy = round(((double)correct_number / iteration) * 10000.0) / 100.0;
        }
        cout << "Iteration: " << iteration << " Accuracy = " << fixed << setprecision(2) << accuracy << "%" << endl;
    }

    cout << "Final Accuracy: " << fixed << setprecision(2) << accuracy << "%" << endl;

    return 0;
}