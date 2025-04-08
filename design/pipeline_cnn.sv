//-----------------------------------------------------------------------------
// Module: parallel_cnn_pipeline
// Description: A pipelined datapath for parallel MAC operations
//              common in CNN convolution layers. Includes ReLU activation.
//              Assumes external control for data feeding and sequencing.
//-----------------------------------------------------------------------------
module parallel_cnn_pipeline #(
    parameter int DATA_WIDTH         = 8,  // Bit width for activations and weights
    parameter int PARALLEL_MAC_UNITS = 4,  // Number of MAC units operating in parallel
    // Derived Parameters
    localparam int MULT_WIDTH = DATA_WIDTH * 2, // Width of multiplication result
    // Accumulator needs width for sum of PARALLEL_MAC_UNITS products
    localparam int ACCUM_WIDTH = MULT_WIDTH + $clog2(PARALLEL_MAC_UNITS)
) (
    input logic clk,
    input logic rst_n, // Asynchronous reset active low

    // --- Input Interface (from Control/Memory) ---
    input logic valid_in,                  // Input data and weights are valid
    output logic ready_out,                // Pipeline is ready for new input
    input logic signed [DATA_WIDTH-1:0] data_in [PARALLEL_MAC_UNITS], // Parallel input activation data
    input logic signed [DATA_WIDTH-1:0] weights_in [PARALLEL_MAC_UNITS], // Parallel filter weights

    // --- Output Interface (to next stage/Control/Memory) ---
    output logic valid_out,                 // Output data is valid
    input logic ready_in,                  // Next stage is ready to accept output
    output logic signed [DATA_WIDTH-1:0] data_out  // Result after MAC, accumulation, ReLU, saturation
);

    //-------------------------------------------------------------------------
    // Pipeline Stage Registers and Wires
    //-------------------------------------------------------------------------

    // Stage 1: Input Latching
    logic stage1_valid_reg;
    logic signed [DATA_WIDTH-1:0] stage1_data_reg [PARALLEL_MAC_UNITS];
    logic signed [DATA_WIDTH-1:0] stage1_weights_reg [PARALLEL_MAC_UNITS];
    logic stage1_ready; // Is stage 1 ready to accept data?

    // Stage 2: Multiplication Results
    logic stage2_valid_reg;
    logic signed [MULT_WIDTH-1:0] stage2_mult_results_reg [PARALLEL_MAC_UNITS];
    logic stage2_ready; // Is stage 2 ready to accept data?
    // Combinational multiplication results for input to stage 2 registers
    logic signed [MULT_WIDTH-1:0] stage1_mult_results [PARALLEL_MAC_UNITS];

    // Stage 3: Accumulation Result
    logic stage3_valid_reg;
    logic signed [ACCUM_WIDTH-1:0] stage3_accum_result_reg;
    logic stage3_ready; // Is stage 3 ready to accept data?
    // Combinational accumulation result for input to stage 3 registers
    logic signed [ACCUM_WIDTH-1:0] stage2_accum_result;

    // Stage 4: Activation (ReLU) and Saturation/Truncation Result
    logic stage4_valid_reg;
    logic signed [DATA_WIDTH-1:0] stage4_output_reg; // Final output width
    logic stage4_ready; // Is stage 4 ready to accept data?
    // Combinational activation result for input to stage 4 registers
    logic signed [DATA_WIDTH-1:0] stage3_activated_output;

    //-------------------------------------------------------------------------
    // Pipeline Flow Control (Ready Signals - Combinational)
    //-------------------------------------------------------------------------
    // A stage is ready if the next stage is ready OR the next stage register is empty (invalid)
    assign stage4_ready = ready_in; // Connects to the module downstream
    assign stage3_ready = stage4_ready || !stage4_valid_reg;
    assign stage2_ready = stage3_ready || !stage3_valid_reg;
    assign stage1_ready = stage2_ready || !stage2_valid_reg;
    assign ready_out    = stage1_ready || !stage1_valid_reg; // Pipeline ready if first stage can accept

    //-------------------------------------------------------------------------
    // Pipeline Stage Logic
    //-------------------------------------------------------------------------

    // --- Stage 1: Input Latching ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1_valid_reg <= 1'b0;
        end else if (stage1_ready) begin // Only load if not stalled
            stage1_valid_reg <= valid_in;
            if (valid_in) begin
                stage1_data_reg <= data_in;
                stage1_weights_reg <= weights_in;
            end
        end
    end

    // --- Stage 2: Parallel Multiplication ---
    // Combinational logic for multiplication
    genvar i;
    generate
        for (i = 0; i < PARALLEL_MAC_UNITS; i = i + 1) begin : parallel_multipliers
            assign stage1_mult_results[i] = stage1_data_reg[i] * stage1_weights_reg[i];
        end
    endgenerate

    // Register for stage 2
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage2_valid_reg <= 1'b0;
        end else if (stage2_ready) begin // Only load if not stalled
            stage2_valid_reg <= stage1_valid_reg && stage1_ready; // Propagate valid if stage 1 was valid and we accepted it
            if (stage1_valid_reg && stage1_ready) begin
                stage2_mult_results_reg <= stage1_mult_results;
            end
        end
    end

    // --- Stage 3: Accumulation ---
    // Combinational logic for accumulation (simple adder tree logic)
    // This implementation uses a loop; for high performance, a dedicated adder tree structure is better.
    always_comb begin
        stage2_accum_result = $[insert latex math expression:'0]$; // Initialize sum to zero with appropriate width
        for (int j = 0; j < PARALLEL_MAC_UNITS; j = j + 1) begin
            // Add results, ensuring sign extension if needed (implicit via signed type)
            stage2_accum_result = stage2_accum_result + stage2_mult_results_reg[j];
        end
    end

    // Register for stage 3
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage3_valid_reg <= 1'b0;
        end else if (stage3_ready) begin // Only load if not stalled
            stage3_valid_reg <= stage2_valid_reg && stage2_ready;
            if (stage2_valid_reg && stage2_ready) begin
                stage3_accum_result_reg <= stage2_accum_result;
            end
        end
    end

    // --- Stage 4: Activation (ReLU) and Saturation/Truncation ---
    // Combinational logic for ReLU and casting back to DATA_WIDTH
    always_comb begin
        logic signed [ACCUM_WIDTH-1:0] relu_interm;
        // ReLU activation
        if (stage3_accum_result_reg < $[insert latex math expression:0]$) begin
            relu_interm = $[insert latex math expression:'0]$;
        end else begin
            relu_interm = stage3_accum_result_reg;
        end

        // Saturation/Truncation to final DATA_WIDTH
        logic signed [DATA_WIDTH-1:0] max_val = (1 <<< ($[insert latex math expression:DATA_WIDTH-1]$)) - $[insert latex math expression:1]$;
        logic signed [DATA_WIDTH-1:0] min_val = -(1 <<< ($[insert latex math expression:DATA_WIDTH-1]$)); // Usually $[insert latex math expression:0]$ for ReLU output

        if (relu_interm > max_val) begin
            stage3_activated_output = max_val;
        // Since ReLU output >= 0, min_val check isn't strictly needed unless activation changes
        // } else if (relu_interm < min_val) begin
        //     stage3_activated_output = min_val;
        end else begin
            // Truncate (assign lower bits)
            stage3_activated_output = relu_interm[$[insert latex math expression:DATA_WIDTH-1]$:0];
        end
    end

    // Register for stage 4
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage4_valid_reg <= 1'b0;
        end else if (stage4_ready) begin // Only load if not stalled (checks ready_in)
            stage4_valid_reg <= stage3_valid_reg && stage3_ready;
            if (stage3_valid_reg && stage3_ready) begin
                stage4_output_reg <= stage3_activated_output;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Assign Module Outputs
    //-------------------------------------------------------------------------
    assign data_out = stage4_output_reg;
    assign valid_out = stage4_valid_reg;

endmodule : parallel_cnn_pipeline