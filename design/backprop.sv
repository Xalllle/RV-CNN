// Simple module to calculate delta for one neuron and gradient for one weight
// Assumes sigmoid activation and fixed-point arithmetic (scaling omitted for simplicity)

module backprop_neuron_core #(
    parameter WIDTH = 16,             // Data width (assuming signed fixed-point)
    parameter FRAC_BITS = 8             // Number of fractional bits
) (
    input logic clk,
    input logic rst_n,
    input logic enable,               // Start calculation

    // Inputs for delta calculation
    input logic signed [WIDTH-1:0] activation_current, // Activation of this neuron (from forward pass, σ(sum))
    input logic signed [WIDTH-1:0] error_weighted_sum, // For hidden: Σ(w*δ) from next layer. For output: (target - activation)

    // Inputs for gradient calculation
    input logic signed [WIDTH-1:0] activation_prev,    // Activation of the previous layer neuron connected by the weight

    // Inputs for weight update (Optional - can be done outside)
    input logic signed [WIDTH-1:0] learning_rate,      // Learning rate η
    input logic signed [WIDTH-1:0] current_weight,     // The current value of the weight w_ij

    // Outputs
    output logic signed [WIDTH-1:0] delta_out,          // Calculated error term δ for this neuron
    output logic signed [WIDTH-1:0] gradient_out,       // Calculated gradient Δw for the specific weight
    output logic signed [WIDTH-1:0] new_weight_out,     // Calculated new weight (optional)
    output logic                   done                // Calculation finished signal
);

    // Fixed-point representation of '1'
    localparam logic signed [WIDTH-1:0] ONE = (1 << FRAC_BITS);

    // Internal registers for pipelining/storing results
    logic signed [WIDTH-1:0] activation_deriv_reg;
    logic signed [WIDTH-1:0] delta_reg;
    logic signed [WIDTH-1:0] gradient_reg;
    logic signed [WIDTH-1:0] weight_update_reg;
    logic signed [WIDTH-1:0] new_weight_reg;
    logic                    done_reg;

    // Intermediate results (potentially wider before scaling/truncation)
    logic signed [2*WIDTH-1:0] mult_deriv1_temp;
    logic signed [WIDTH:0]     sub_deriv_temp; // Need one extra bit for 1.0 - activation
    logic signed [2*WIDTH-1:0] mult_deriv2_temp;
    logic signed [2*WIDTH-1:0] mult_delta_temp;
    logic signed [2*WIDTH-1:0] mult_gradient_temp;
    logic signed [2*WIDTH-1:0] mult_update_temp;

    // State machine (simple example)
    typedef enum logic [1:0] {
        IDLE,
        CALC_DERIV_DELTA,
        CALC_GRAD_UPDATE,
        DONE
    } state_t;
    state_t current_state, next_state;

    //----------------------------------------------------
    // Combinational Logic for Calculations
    //----------------------------------------------------
    always_comb begin
        // Default assignments
        next_state = current_state;
        done = done_reg;

        // *** NOTE: Proper fixed-point scaling (right shifts by FRAC_BITS) after multiplications
        // *** is OMITTED here for simplicity. In real hardware, this is ESSENTIAL.
        // Example: scaled_result = full_result >>> FRAC_BITS;

        // Calculate 1 - activation
        sub_deriv_temp = ONE - activation_current; // Potential overflow if activation > 1

        // Calculate activation' = activation * (1 - activation)
        mult_deriv1_temp = activation_current * sub_deriv_temp;
        // Scale mult_deriv1_temp here in real code
        activation_deriv_reg = mult_deriv1_temp[WIDTH-1:0]; // Simplified truncation

        // Calculate delta = error_weighted_sum * activation'
        mult_delta_temp = error_weighted_sum * activation_deriv_reg;
         // Scale mult_delta_temp here in real code
        delta_reg = mult_delta_temp[WIDTH-1:0]; // Simplified truncation

        // Calculate gradient = delta * activation_prev
        mult_gradient_temp = delta_reg * activation_prev;
         // Scale mult_gradient_temp here in real code
        gradient_reg = mult_gradient_temp[WIDTH-1:0]; // Simplified truncation

        // Calculate weight update term = learning_rate * gradient
        mult_update_temp = learning_rate * gradient_reg;
         // Scale mult_update_temp here in real code
        weight_update_reg = mult_update_temp[WIDTH-1:0]; // Simplified truncation

        // Calculate new_weight = current_weight - weight_update_term
        new_weight_reg = current_weight - weight_update_reg;


        // State transition logic
        case (current_state)
            IDLE: begin
                done = 1'b0;
                if (enable) begin
                    next_state = CALC_DERIV_DELTA;
                end else begin
                    next_state = IDLE;
                end
            end
            CALC_DERIV_DELTA: begin
                 // Calculations happen combinatorially, move to next stage
                 next_state = CALC_GRAD_UPDATE;
            end
            CALC_GRAD_UPDATE: begin
                 // Calculations happen combinatorially, move to next stage
                 next_state = DONE;
            end
            DONE: begin
                done = 1'b1;
                if (!enable) begin // Wait for enable to go low to reset
                    next_state = IDLE;
                end else begin
                    next_state = DONE; // Stay done until enable drops
                end
            end
            default: next_state = IDLE;
        endcase
    end

    //----------------------------------------------------
    // Sequential Logic (Registers and State)
    //----------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            delta_out <= '0;
            gradient_out <= '0;
            new_weight_out <= '0;
            done_reg <= 1'b0;
        end else begin
            current_state <= next_state;
            done_reg <= done; // Register the done signal

            // Register outputs when calculation is finished
            if (current_state == CALC_GRAD_UPDATE && next_state == DONE) begin
                delta_out      <= delta_reg;
                gradient_out   <= gradient_reg;
                new_weight_out <= new_weight_reg;
            end

             if (current_state == DONE && next_state == IDLE) begin
                 // Optionally clear outputs when returning to idle
                 delta_out <= '0;
                 gradient_out <= '0;
                 new_weight_out <= '0;
            end
        end
    end

endmodule