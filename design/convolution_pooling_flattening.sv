module cnn_conv_pool_flat
#(
    parameter int INPUT_WIDTH      = 8,  // Input feature map width
    parameter int INPUT_HEIGHT     = 8,  // Input feature map height
    parameter int INPUT_DATA_WIDTH = 8,  // Bit width for input data

    parameter int KERNEL_WIDTH      = 3,  // Kernel width
    parameter int KERNEL_HEIGHT     = 3,  // Kernel height
    parameter int KERNEL_DATA_WIDTH = 8,  // Bit width for kernel weights

    parameter int CONV_STRIDE       = 1,  // Convolution stride

    parameter int POOL_SIZE         = 2,  // Pooling window size (POOL_SIZE x POOL_SIZE)
    parameter int POOL_STRIDE       = 2,  // Pooling stride

    // Calculated Parameters
    parameter int CONV_OUT_WIDTH  = (INPUT_WIDTH - KERNEL_WIDTH) / CONV_STRIDE + 1,
    parameter int CONV_OUT_HEIGHT = (INPUT_HEIGHT - KERNEL_HEIGHT) / CONV_STRIDE + 1,
    parameter int POOL_OUT_WIDTH  = (CONV_OUT_WIDTH - POOL_SIZE) / POOL_STRIDE + 1,
    parameter int POOL_OUT_HEIGHT = (CONV_OUT_HEIGHT - POOL_SIZE) / POOL_STRIDE + 1,
    parameter int FLAT_SIZE       = POOL_OUT_WIDTH * POOL_OUT_HEIGHT,
    parameter int KERNEL_FLAT_SIZE = KERNEL_WIDTH * KERNEL_HEIGHT,
    parameter int INPUT_FLAT_SIZE  = INPUT_WIDTH * INPUT_HEIGHT,

    // Accumulator needs more bits
    parameter int ACCUM_WIDTH     = INPUT_DATA_WIDTH + KERNEL_DATA_WIDTH + $clog2(KERNEL_FLAT_SIZE),
    // Output data width - Assume max pooling keeps the convoluted data width
    // If activation/scaling occurs, this might change.
    parameter int OUTPUT_DATA_WIDTH = ACCUM_WIDTH
)
(
    input logic clk,
    input logic rst_n,

    // Input Data Interface
    input logic                       in_valid,
    input logic signed [INPUT_DATA_WIDTH-1:0] in_data, // Pixel or kernel data
    output logic                      in_ready,

    // Output Data Interface
    output logic                      out_valid,
    output logic signed [OUTPUT_DATA_WIDTH-1:0] out_data,
    input logic                       out_ready
);

    // Type definitions
    typedef logic signed [INPUT_DATA_WIDTH-1:0]  input_map_pixel_t;
    typedef logic signed [KERNEL_DATA_WIDTH-1:0] kernel_weight_t;
    typedef logic signed [ACCUM_WIDTH-1:0]       conv_pixel_t; // Convolution result type
    typedef logic signed [OUTPUT_DATA_WIDTH-1:0] pool_pixel_t; // Pooling result type

    // Internal Storage
    input_map_pixel_t input_map [INPUT_HEIGHT-1:0][INPUT_WIDTH-1:0];
    kernel_weight_t   kernel    [KERNEL_HEIGHT-1:0][KERNEL_WIDTH-1:0];
    conv_pixel_t      conv_out  [CONV_OUT_HEIGHT-1:0][CONV_OUT_WIDTH-1:0];
    pool_pixel_t      pool_out  [POOL_OUT_HEIGHT-1:0][POOL_OUT_WIDTH-1:0];

    // Minimum value for MAX Pooling initialization
    localparam signed [OUTPUT_DATA_WIDTH-1:0] MIN_POOL_VAL = -'sd( (1 << (OUTPUT_DATA_WIDTH-1)) );

    // State Machine
    typedef enum logic [2:0] {
        IDLE,
        LOAD_INPUT,
        LOAD_KERNEL,
        CONVOLVE_MAC, // Multiply-Accumulate step
        CONVOLVE_WRITE, // Write result and advance output pixel indices
        POOL_READ,   // Read conv data and compare
        POOL_WRITE,  // Write result and advance output pixel indices
        FLATTEN      // Read from pool_out and output
    } state_t;

    state_t current_state, next_state;

    // Counters and Indices
    logic [$clog2(INPUT_FLAT_SIZE)-1:0] load_input_cnt;
    logic [$clog2(KERNEL_FLAT_SIZE)-1:0] load_kernel_cnt;

    logic [$clog2(CONV_OUT_HEIGHT)-1:0] conv_r_idx; // Conv output row
    logic [$clog2(CONV_OUT_WIDTH)-1:0]  conv_c_idx; // Conv output col
    logic [$clog2(KERNEL_HEIGHT)-1:0]   k_r_idx;    // Kernel row for MAC
    logic [$clog2(KERNEL_WIDTH)-1:0]    k_c_idx;    // Kernel col for MAC
    conv_pixel_t                        conv_accumulator; // Register for MAC result

    logic [$clog2(POOL_OUT_HEIGHT)-1:0] pool_r_idx; // Pool output row
    logic [$clog2(POOL_OUT_WIDTH)-1:0]  pool_c_idx; // Pool output col
    logic [$clog2(POOL_SIZE)-1:0]       p_r_idx;    // Pool window row index
    logic [$clog2(POOL_SIZE)-1:0]       p_c_idx;    // Pool window col index
    pool_pixel_t                        max_pool_val; // Register for max value in window

    logic [$clog2(FLAT_SIZE)-1:0]       flat_idx;   // Flattened output index

    // Internal Signals / Flags
    logic load_input_done;
    logic load_kernel_done;
    logic conv_mac_done;  // MAC for one output pixel finished
    logic conv_all_done;  // All conv output pixels calculated
    logic pool_compare_done; // Comparison for one pool window finished
    logic pool_all_done;  // All pool output pixels calculated
    logic flatten_all_done; // All flattened pixels sent

    logic out_fire; // Transfer signal for output stage: out_valid && out_ready

    //--------------------------------------------------------------------------
    // Combinational Logic: Next State, Flags, Outputs
    //--------------------------------------------------------------------------
    always_comb begin
        // Default assignments
        next_state = current_state;
        in_ready = 1'b0;
        out_valid = 1'b0;
        out_data = '0;

        // Calculate intermediate values needed for decisions
        int current_in_map_r = conv_r_idx * CONV_STRIDE + k_r_idx;
        int current_in_map_c = conv_c_idx * CONV_STRIDE + k_c_idx;
        int current_pool_in_r = pool_r_idx * POOL_STRIDE + p_r_idx;
        int current_pool_in_c = pool_c_idx * POOL_STRIDE + p_c_idx;

        conv_pixel_t current_mac_term = 0;
        if (current_in_map_r < INPUT_HEIGHT && current_in_map_c < INPUT_WIDTH) begin // Bounds check (redundant for 'valid' conv)
            current_mac_term = input_map[current_in_map_r][current_in_map_c] * kernel[k_r_idx][k_c_idx];
        end

        pool_pixel_t current_pool_in_val = MIN_POOL_VAL;
        if (current_pool_in_r < CONV_OUT_HEIGHT && current_pool_in_c < CONV_OUT_WIDTH) begin // Bounds check
             current_pool_in_val = conv_out[current_pool_in_r][current_pool_in_c];
        end

        // Done flags (combinational based on current counter values)
        load_input_done   = (load_input_cnt == INPUT_FLAT_SIZE - 1);
        load_kernel_done  = (load_kernel_cnt == KERNEL_FLAT_SIZE - 1);
        conv_mac_done     = (k_r_idx == KERNEL_HEIGHT - 1) && (k_c_idx == KERNEL_WIDTH - 1);
        conv_all_done     = (conv_r_idx == CONV_OUT_HEIGHT - 1) && (conv_c_idx == CONV_OUT_WIDTH - 1) && conv_mac_done;
        pool_compare_done = (p_r_idx == POOL_SIZE - 1) && (p_c_idx == POOL_SIZE - 1);
        pool_all_done     = (pool_r_idx == POOL_OUT_HEIGHT - 1) && (pool_c_idx == POOL_OUT_WIDTH - 1) && pool_compare_done;
        flatten_all_done  = (flat_idx == FLAT_SIZE - 1) && out_fire; // Depends on handshake

        // State transition logic
        case (current_state)
            IDLE: begin
                in_ready = 1'b1;
                if (in_valid) begin
                    next_state = LOAD_INPUT;
                end
            end

            LOAD_INPUT: begin
                in_ready = 1'b1;
                if (in_valid) begin // Accept data only when valid
                    if (load_input_done) begin
                        next_state = LOAD_KERNEL;
                        in_ready = 1'b0; // Wait for kernel loading
                    end
                end
             end

            LOAD_KERNEL: begin
                 in_ready = 1'b1;
                 if (in_valid) begin // Accept data only when valid
                    if (load_kernel_done) begin
                         next_state = CONVOLVE_MAC;
                         in_ready = 1'b0; // Done loading
                    end
                 end
            end

            CONVOLVE_MAC: begin
                // Continue MAC operations until one output pixel is done
                if (conv_mac_done) begin
                    next_state = CONVOLVE_WRITE;
                end else begin
                    next_state = CONVOLVE_MAC; // Stay to continue MAC
                end
            end

            CONVOLVE_WRITE: begin
                 // Write completed conv pixel, check if all are done
                if (conv_all_done) begin
                    next_state = POOL_READ; // Start pooling
                end else begin
                    next_state = CONVOLVE_MAC; // Go back to calculate next pixel
                end
            end

            POOL_READ: begin
                // Continue comparing until one pool window is done
                 if (pool_compare_done) begin
                    next_state = POOL_WRITE;
                 end else begin
                    next_state = POOL_READ; // Stay to continue compare
                 end
            end

             POOL_WRITE: begin
                 // Write completed pool pixel, check if all are done
                  if (pool_all_done) begin
                    next_state = FLATTEN; // Start flattening
                  end else begin
                    next_state = POOL_READ; // Go back to process next window
                  end
             end

            FLATTEN: begin
                out_valid = 1'b1; // Assert valid output
                // Calculate output data based on flat_idx
                out_data = pool_out[flat_idx / POOL_OUT_WIDTH][flat_idx % POOL_OUT_WIDTH];

                if (out_fire) begin // If data accepted by downstream
                    if (flat_idx == FLAT_SIZE - 1) begin // Check if this was the last element
                        next_state = IDLE; // Finished processing one full map
                        out_valid = 1'b0; // No more data valid for this run (combinational)
                    end else begin
                        // Stay in FLATTEN state, flat_idx increments in sequential block
                        next_state = FLATTEN;
                    end
                end else begin
                   // Downstream not ready, stay in FLATTEN, keep valid asserted
                   next_state = FLATTEN;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Output handshake signal
    assign out_fire = out_valid && out_ready;

    //--------------------------------------------------------------------------
    // Sequential Logic: Registers, Counters, State Update
    //--------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state and all counters/accumulators
            current_state <= IDLE;
            load_input_cnt <= '0;
            load_kernel_cnt <= '0;
            conv_r_idx <= '0;
            conv_c_idx <= '0;
            k_r_idx <= '0;
            k_c_idx <= '0;
            conv_accumulator <= '0;
            pool_r_idx <= '0;
            pool_c_idx <= '0;
            p_r_idx <= '0;
            p_c_idx <= '0;
            max_pool_val <= MIN_POOL_VAL;
            flat_idx <= '0;
            // Optionally clear internal memories (may not be synthesizable depending on target)
            foreach (input_map[i,j]) input_map[i][j] <= '0;
            foreach (kernel[i,j]) kernel[i][j] <= '0;
            foreach (conv_out[i,j]) conv_out[i][j] <= '0;
            foreach (pool_out[i,j]) pool_out[i][j] <= '0;
        end else begin
            // Update state register
            current_state <= next_state;

            // Update counters and registers based on current state and transitions
            case (current_state)
                IDLE: begin
                    if (in_valid && in_ready) begin // Reset counters at start of load
                        load_input_cnt <= '0;
                        load_kernel_cnt <= '0;
                        flat_idx <= '0; // Reset output index for next run
                    end
                end

                LOAD_INPUT: begin
                    if (in_valid && in_ready) begin
                        input_map[load_input_cnt / INPUT_WIDTH][load_input_cnt % INPUT_WIDTH] <= in_data;
                        if (!load_input_done) begin
                            load_input_cnt <= load_input_cnt + 1;
                        end else begin
                           load_kernel_cnt <= '0; // Prepare for kernel loading
                        end
                    end
                end

                LOAD_KERNEL: begin
                    if (in_valid && in_ready) begin
                        kernel[load_kernel_cnt / KERNEL_WIDTH][load_kernel_cnt % KERNEL_WIDTH] <= in_data;
                         if (!load_kernel_done) begin
                            load_kernel_cnt <= load_kernel_cnt + 1;
                        end else begin
                           // Initialize convolution counters before entering CONVOLVE_MAC
                           conv_r_idx <= '0;
                           conv_c_idx <= '0;
                           k_r_idx <= '0;
                           k_c_idx <= '0;
                           conv_accumulator <= '0;
                        end
                    end
                end

                CONVOLVE_MAC: begin
                    // Perform one MAC step
                    int current_in_map_r = conv_r_idx * CONV_STRIDE + k_r_idx;
                    int current_in_map_c = conv_c_idx * CONV_STRIDE + k_c_idx;
                    conv_pixel_t mac_term = 0;
                     if (current_in_map_r < INPUT_HEIGHT && current_in_map_c < INPUT_WIDTH) begin // Check bounds
                       mac_term = input_map[current_in_map_r][current_in_map_c] * kernel[k_r_idx][k_c_idx];
                     end
                    conv_accumulator <= conv_accumulator + mac_term;

                    // Update kernel indices for next cycle
                    if (!conv_mac_done) begin // Don't increment if we are transitioning out
                        if (k_c_idx == KERNEL_WIDTH - 1) begin
                            k_c_idx <= '0;
                            k_r_idx <= k_r_idx + 1;
                        end else begin
                            k_c_idx <= k_c_idx + 1;
                        end
                    end
                end

                CONVOLVE_WRITE: begin
                    // Write result of the just-finished MAC sequence
                    conv_out[conv_r_idx][conv_c_idx] <= conv_accumulator;

                    // Reset MAC counters/accumulator for the *next* pixel (if any)
                    k_r_idx <= '0;
                    k_c_idx <= '0;
                    conv_accumulator <= '0;

                    // Update conv output indices for the *next* pixel (if any)
                    if (!conv_all_done) begin // Don't increment if we are transitioning out
                        if (conv_c_idx == CONV_OUT_WIDTH - 1) begin
                            conv_c_idx <= '0;
                            conv_r_idx <= conv_r_idx + 1;
                        end else begin
                            conv_c_idx <= conv_c_idx + 1;
                        end
                    end else begin
                        // Initialize pooling counters before entering POOL_READ
                        pool_r_idx <= '0;
                        pool_c_idx <= '0;
                        p_r_idx <= '0;
                        p_c_idx <= '0;
                        max_pool_val <= MIN_POOL_VAL; // Initialize for first window
                    end
                 end

                POOL_READ: begin
                    // Determine input value for comparison
                    int current_pool_in_r = pool_r_idx * POOL_STRIDE + p_r_idx;
                    int current_pool_in_c = pool_c_idx * POOL_STRIDE + p_c_idx;
                    pool_pixel_t current_pool_in_val = MIN_POOL_VAL;
                     if (current_pool_in_r < CONV_OUT_HEIGHT && current_pool_in_c < CONV_OUT_WIDTH) begin // Check bounds
                        current_pool_in_val = conv_out[current_pool_in_r][current_pool_in_c];
                     end

                    // Compare and update max value register
                    if (current_pool_in_val > max_pool_val) begin
                        max_pool_val <= current_pool_in_val;
                    end

                    // Update pool window indices for next cycle
                    if (!pool_compare_done) begin // Don't increment if we are transitioning out
                        if (p_c_idx == POOL_SIZE - 1) begin
                            p_c_idx <= '0;
                            p_r_idx <= p_r_idx + 1;
                        end else begin
                            p_c_idx <= p_c_idx + 1;
                        end
                    end
                end

                POOL_WRITE: begin
                    // Write the maximum value found for the window
                    pool_out[pool_r_idx][pool_c_idx] <= max_pool_val;

                    // Reset pool window indices and max value for the *next* window
                    p_r_idx <= '0;
                    p_c_idx <= '0;
                    max_pool_val <= MIN_POOL_VAL;

                    // Update pool output indices for the *next* window (if any)
                    if (!pool_all_done) begin // Don't increment if we are transitioning out
                        if (pool_c_idx == POOL_OUT_WIDTH - 1) begin
                            pool_c_idx <= '0;
                            pool_r_idx <= pool_r_idx + 1;
                        end else begin
                            pool_c_idx <= pool_c_idx + 1;
                        end
                    end else begin
                        // Initialize flatten counter before entering FLATTEN
                        flat_idx <= '0;
                    end
                end

                FLATTEN: begin
                    if (out_fire && !flatten_all_done) begin // Increment only if data was accepted and not the last element
                        flat_idx <= flat_idx + 1;
                    end
                end
            endcase
        end
    end

endmodule