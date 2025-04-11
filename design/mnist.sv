class MnistData;

  localparam int IMG_MAGIC_NUM = 32'h00000803;
  localparam int LBL_MAGIC_NUM = 32'h00000801;

  string image_file_path;
  string label_file_path;

  int unsigned num_images;
  int unsigned img_rows;
  int unsigned img_cols;
  int unsigned num_labels;

  byte unsigned images [][][];
  byte unsigned labels [];

  function new(string img_path = "train-images.idx3-ubyte",
               string lbl_path = "train-labels.idx1-ubyte");
    this.image_file_path = img_path;
    this.label_file_path = lbl_path;
  endfunction

  function automatic int read_int32_big_endian(int file_desc);
    byte unsigned b[4];
    int unsigned val;
    int status;
    status = $fread(b, file_desc);
    if (status != 4) begin
      $error("MNIST Loader: Failed to read 4 bytes for int32.");
      return -1;
    end
    val = {b[0], b[1], b[2], b[3]};
    return val;
  endfunction

  task load_data();
    int img_file;
    int lbl_file;
    int magic_num, count, rows, cols;
    int i, r, c;
    int status;
    byte unsigned pixel_val;
    byte unsigned label_val;

    img_file = $fopen(image_file_path, "rb");
    lbl_file = $fopen(label_file_path, "rb");

    if (img_file == 0 || lbl_file == 0) begin
      $error("MNIST Loader: Could not open image or label file.");
      if (img_file != 0) $fclose(img_file);
      if (lbl_file != 0) $fclose(lbl_file);
      return;
    end

    magic_num = read_int32_big_endian(img_file);
    if (magic_num != IMG_MAGIC_NUM) begin
        $warning("MNIST Loader: Image file magic number mismatch. Expected %h, got %h", IMG_MAGIC_NUM, magic_num);
    end
    this.num_images = read_int32_big_endian(img_file);
    this.img_rows   = read_int32_big_endian(img_file);
    this.img_cols   = read_int32_big_endian(img_file);


    magic_num = read_int32_big_endian(lbl_file);
     if (magic_num != LBL_MAGIC_NUM) begin
        $warning("MNIST Loader: Label file magic number mismatch. Expected %h, got %h", LBL_MAGIC_NUM, magic_num);
    end
    this.num_labels = read_int32_big_endian(lbl_file);

    if (this.num_images != this.num_labels) begin
      $error("MNIST Loader: Number of images (%0d) does not match number of labels (%0d).", this.num_images, this.num_labels);
      $fclose(img_file);
      $fclose(lbl_file);
      return;
    end

    $display("MNIST Loader: Loading %0d images (%0d x %0d) and %0d labels.", this.num_images, this.img_rows, this.img_cols, this.num_labels);

    this.images = new[this.num_images];
    this.labels = new[this.num_labels];

    for (i = 0; i < this.num_images; i++) begin
      this.images[i] = new[this.img_rows];

      status = $fread(label_val, lbl_file);
      if (status != 1) begin
          $error("MNIST Loader: Failed reading label for index %0d", i);
          break;
      end
      this.labels[i] = label_val;

      for (r = 0; r < this.img_rows; r++) begin
        this.images[i][r] = new[this.img_cols];
        for (c = 0; c < this.img_cols; c++) begin
           status = $fread(pixel_val, img_file);
           if (status != 1) begin
               $error("MNIST Loader: Failed reading pixel (%0d, %0d) for image %0d", r, c, i);
               i = this.num_images; // break outer loop
               r = this.img_rows;   // break middle loop
               break;              // break inner loop
           end
           this.images[i][r][c] = pixel_val;
        end
      end

      if (i % 1000 == 999) begin
          $display("MNIST Loader: Loaded %0d images...", i+1);
      end

    end

    $display("MNIST Loader: Finished loading data.");
    $fclose(img_file);
    $fclose(lbl_file);

  endtask

endclass

// --- Example Testbench Module ---
module tb_mnist_loader;

  MnistData mnist_train;
  MnistData mnist_test;

  initial begin
    // --- Load Training Data ---
    // Replace with the actual path to your *uncompressed* training files
    mnist_train = new("train-images-idx3-ubyte", "train-labels-idx1-ubyte");
    mnist_train.load_data();

    // --- Load Test Data ---
    // Replace with the actual path to your *uncompressed* test files
    mnist_test = new("t10k-images-idx3-ubyte", "t10k-labels-idx1-ubyte");
    mnist_test.load_data();

    // --- Example Usage ---
    if (mnist_train.num_images > 0 && mnist_test.num_images > 0) begin
      $display("--- Example Data ---");
      $display("Training Image 0 Label: %d", mnist_train.labels[0]);
      // Display the first 5x5 part of the first training image
      $display("Training Image 0 (Top-Left 5x5):");
      for (int r = 0; r < 5; r++) begin
        string row_str = "";
        for (int c = 0; c < 5; c++) begin
          row_str = $sformatf("%s %3d", row_str, mnist_train.images[0][r][c]);
        end
        $display("%s", row_str);
      end

      $display("Test Image 10 Label: %d", mnist_test.labels[10]);
    end else begin
        $error("Data loading failed or resulted in zero images.");
    end

    $finish;
  end

endmodule