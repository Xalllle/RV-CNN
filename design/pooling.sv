module pooling_unit #(
  parameter DATA_WIDTH = 32,
  parameter WINDOW_SIZE = 2,
  parameter STRIDE = 2
) (
  input clk,
  input reset,
  input [DATA_WIDTH-1:0] input_data,
  input input_valid,
  input last_input,
  output reg [DATA_WIDTH-1:0] output_data,
  output reg output_valid,
  output reg last_output
);

  localparam WINDOW_AREA = WINDOW_SIZE * WINDOW_SIZE;

  reg [DATA_WIDTH-1:0] window_buffer [WINDOW_AREA-1:0];
  reg [integer:0] window_index;
  reg [integer:0] input_counter_x;
  reg [integer:0] input_counter_y;
  reg [integer:0] output_counter_x;
  reg [integer:0] output_counter_y;
  reg window_full;
  reg calculate;
  reg last_calc;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      window_index <= 0;
      input_counter_x <= 0;
      input_counter_y <= 0;
      output_counter_x <= 0;
      output_counter_y <= 0;
      window_full <= 0;
      output_valid <= 0;
      last_output <= 0;
      calculate <= 0;
      last_calc <= 0;
    end else begin
      if (input_valid) begin
        window_buffer[window_index] <= input_data;
        window_index <= window_index + 1;
        input_counter_x <= input_counter_x + 1;

        if (input_counter_x == WINDOW_SIZE) begin
          input_counter_x <= 0;
          input_counter_y <= input_counter_y + 1;
        end

        if (window_index == WINDOW_AREA) begin
          window_full <= 1;
          window_index <= 0;
          calculate <= 1;
        end

        if(last_input) begin
            last_calc <= 1;
        end

        if(input_counter_x == STRIDE && input_counter_y == STRIDE) begin
           input_counter_x <= 0;
           input_counter_y <= 0;
        end

      end

      if(calculate) begin
        output_valid <= 1;

        output_data <= window_buffer[0];
        for (integer i = 1; i < WINDOW_AREA; i = i + 1) begin
          if (window_buffer[i] > output_data) begin
            output_data <= window_buffer[i];
          end
        end

        output_counter_x <= output_counter_x + 1;

        if(output_counter_x == 1) begin
            output_counter_x <= 0;
            output_counter_y <= output_counter_y + 1;
        end

        calculate <= 0;
        window_full <= 0;

        if(last_calc) begin
            last_output <= 1;
        end
      end else begin
        output_valid <= 0;
      end

      if (last_output) begin
        last_output <= 0;
      end
    end
  end

endmodule