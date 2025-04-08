module fully_connected_layer #(
    parameter int DATA_WIDTH = 16,
    parameter int INPUT_SIZE = 256,
    parameter int OUTPUT_SIZE = 64,
    // Calculate accumulator width: 2*DATA_WIDTH for multiplication + log2(INPUT_SIZE) for accumulation
    parameter int ACCUM_WIDTH = DATA_WIDTH + DATA_WIDTH + $clog2(INPUT_SIZE)
) (
    input logic clk,
    input logic rst_n,

    // Control Interface
    input logic start,
    output logic done,

    // Data Input Interface
    input logic input_valid, // Assumes all inputs are valid when high
    input logic signed [DATA_WIDTH-1:0] input_activations [INPUT_SIZE-1:0],

    // Weights and Biases (Assumed pre-loaded/accessible)
    // In a real system, these might come from BRAM or be streamed
    input logic signed [DATA_WIDTH-1:0] weights [OUTPUT_SIZE-1:0][INPUT_SIZE-1:0],
    input logic signed [ACCUM_WIDTH-1:0] biases [OUTPUT_SIZE-1:0], // Bias width matches accumulator

    // Data Output Interface
    output logic output_valid,
    output logic signed [DATA_WIDTH-1:0] output_activations [OUTPUT_SIZE-1:0]
);

    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        ACTIVATE_OUTPUT,
        DONE_STATE
    } state_t;

    state_t current_state, next_state;

    // Internal Registers
    logic signed [ACCUM_WIDTH-1:0] accumulators [OUTPUT_SIZE-1:0];
    logic signed [DATA_WIDTH-1:0] output_activations_reg [OUTPUT_SIZE-1:0];
    logic [$clog2(INPUT_SIZE)-1:0] input_idx;
    logic [$clog2(OUTPUT_SIZE)-1:0] output_idx;
    logic done_reg;
    logic output_valid_reg;

    //--------------------------------------------------------------------------
    // State Register
    //--------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    //--------------------------------------------------------------------------
    // Next State Logic & Control Signals
    //--------------------------------------------------------------------------
    always_comb begin
        next_state = current_state;
        done = done_reg;
        output_valid = output_valid_reg;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                // Check if computation for all outputs is done
                if (output_idx == OUTPUT_SIZE-1 && input_idx == INPUT_SIZE-1) begin
                     next_state = ACTIVATE_OUTPUT;
                end
            end
            ACTIVATE_OUTPUT: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                 if (!start) begin // Wait for start to de-assert before going IDLE
                     next_state = IDLE;
                 end
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    //--------------------------------------------------------------------------
    // Datapath Logic
    //--------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_idx <= '0;
            output_idx <= '0;
            foreach (accumulators[i]) accumulators[i] <= '0;
            foreach (output_activations_reg[i]) output_activations_reg[i] <= '0;
            done_reg <= 1'b0;
            output_valid_reg <= 1'b0;
        end else begin
            // Default assignments (hold values)
            done_reg <= done_reg;
            output_valid_reg <= 1'b0; // Usually pulsed for one cycle

            case (current_state)
                IDLE: begin
                    done_reg <= 1'b0;
                    output_valid_reg <= 1'b0;
                    if (start) begin
                        input_idx <= '0;
                        output_idx <= '0;
                        // Initialize accumulators with biases when starting
                        for (int i = 0; i < OUTPUT_SIZE; i++) begin
                            accumulators[i] <= biases[i];
                        end
                    end
                end

                COMPUTE: begin
                    if (input_valid) begin // Process only when inputs are valid
                        // Perform one multiply-accumulate operation per cycle
                        logic signed [ACCUM_WIDTH-1:0] mult_result;
                        mult_result = input_activations[input_idx] * weights[output_idx][input_idx];
                        accumulators[output_idx] <= accumulators[output_idx] + mult_result;

                        // Increment counters
                        if (input_idx == INPUT_SIZE-1) begin
                            input_idx <= '0;
                            if (output_idx == OUTPUT_SIZE-1) begin
                                // Stay here, next state logic handles transition
                                output_idx <= output_idx;
                            end else begin
                                output_idx <= output_idx + 1;
                            end
                        end else begin
                            input_idx <= input_idx + 1;
                        end
                    end
                end

                ACTIVATE_OUTPUT: begin
                    // Apply ReLU activation and saturate/truncate to DATA_WIDTH
                    for (int i = 0; i < OUTPUT_SIZE; i++) begin
                        if (accumulators[i][ACCUM_WIDTH-1]) begin // Check sign bit (negative)
                            output_activations_reg[i] <= '0; // ReLU clamps negative to 0
                        end else if (ACCUM_WIDTH > DATA_WIDTH && |accumulators[i][ACCUM_WIDTH-1 -: (ACCUM_WIDTH - DATA_WIDTH)]) begin // Check for overflow
                           // Saturate positive values if they exceed max representable value
                           output_activations_reg[i] <= {1'b0, {DATA_WIDTH-1{1'b1}}}; // Max positive value
                        end else begin
                           // Truncate if positive and no overflow
                           output_activations_reg[i] <= accumulators[i][DATA_WIDTH-1:0];
                        end
                    end
                    output_valid_reg <= 1'b1; // Output is ready for one cycle
                end

                DONE_STATE: begin
                    done_reg <= 1'b1;
                    output_valid_reg <= 1'b0; // De-assert valid after one cycle
                     if (!start) begin
                          done_reg <= 1'b0; // Clear done when start goes low
                     end
                end

                default: begin
                     // Reset internal state in case of illegal state
                     input_idx <= '0;
                     output_idx <= '0;
                     foreach (accumulators[i]) accumulators[i] <= '0;
                     foreach (output_activations_reg[i]) output_activations_reg[i] <= '0;
                     done_reg <= 1'b0;
                     output_valid_reg <= 1'b0;
                end
            endcase
        end
    end

    // Assign registered output to module output port
    assign output_activations = output_activations_reg;

endmodule