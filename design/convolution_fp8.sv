module fp8_conv_2x2_accelerator #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter FP8_WIDTH  = 8,
    parameter ACCEL_BASE_ADDR = 32'hFFFF0000,
    parameter ADDR_LSBS = 4,
    parameter INPUT_DIM = 28,
    parameter KERNEL_DIM = 2,
    parameter OUTPUT_DIM = 26
) (
    input logic clk,
    input logic rst_n,

    input  logic [ADDR_WIDTH-1:0] cs_address,
    input  logic                  cs_read,
    input  logic                  cs_write,
    input  logic [DATA_WIDTH-1:0] cs_writedata,
    output logic [DATA_WIDTH-1:0] cs_readdata,
    output logic                  cs_waitrequest,

    output logic mem_read,
    output logic mem_write,
    output logic [ADDR_WIDTH-1:0] mem_address,
    output logic [FP8_WIDTH-1:0]  mem_writedata,
    input  logic [FP8_WIDTH-1:0]  mem_readdata,
    input  logic                  mem_waitrequest,
    input  logic                  mem_readdatavalid
);

    localparam REG_CONTROL        = 4'h0;
    localparam REG_STATUS         = 4'h1;
    localparam REG_KERNEL_ADDR    = 4'h2;
    localparam REG_INPUT_MAP_ADDR = 4'h3;
    localparam REG_OUTPUT_MAP_ADDR= 4'h4;

    typedef enum logic [3:0] {
        IDLE,
        FETCH_KERNEL_00, FETCH_KERNEL_01, FETCH_KERNEL_10, FETCH_KERNEL_11,
        FETCH_INPUT_00, FETCH_INPUT_01, FETCH_INPUT_10, FETCH_INPUT_11,
        COMPUTE,
        WRITE_OUTPUT,
        DONE
    } state_t;

    state_t current_state, next_state;

    logic [ADDR_WIDTH-1:0] kernel_addr_reg;
    logic [ADDR_WIDTH-1:0] input_map_addr_reg;
    logic [ADDR_WIDTH-1:0] output_map_addr_reg;
    logic                  start_bit_reg;
    logic                  busy_status;
    logic                  done_status;

    logic [7:0] row_counter;
    logic [7:0] col_counter;

    logic [FP8_WIDTH-1:0] kernel_buf [0:KERNEL_DIM*KERNEL_DIM-1];
    logic [FP8_WIDTH-1:0] input_buf [0:KERNEL_DIM*KERNEL_DIM-1];
    logic [FP8_WIDTH-1:0] result_buf;

    logic [3:0]            reg_addr_local;
    logic                  accel_select;

    logic start_computation_core;
    logic computation_core_done;


    assign reg_addr_local = cs_address[ADDR_LSBS-1:0];
    assign accel_select = (cs_address >= ACCEL_BASE_ADDR) && (cs_address < (ACCEL_BASE_ADDR + (1<<ADDR_LSBS)));


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            kernel_addr_reg <= '0;
            input_map_addr_reg <= '0;
            output_map_addr_reg <= '0;
            start_bit_reg <= 1'b0;
        end else begin
            start_bit_reg <= 1'b0;
            if (accel_select && cs_write && !cs_waitrequest) begin
                case (reg_addr_local)
                    REG_CONTROL: start_bit_reg <= cs_writedata[0];
                    REG_KERNEL_ADDR: kernel_addr_reg <= cs_writedata;
                    REG_INPUT_MAP_ADDR: input_map_addr_reg <= cs_writedata;
                    REG_OUTPUT_MAP_ADDR: output_map_addr_reg <= cs_writedata;
                    default: ;
                endcase
            end
        end
    end


    always_comb begin
        cs_readdata = '0;
        cs_waitrequest = 1'b0;
        if (accel_select && cs_read) begin
            case (reg_addr_local)
                REG_STATUS: cs_readdata = {{(DATA_WIDTH-2){1'b0}}, busy_status, done_status};
                REG_KERNEL_ADDR: cs_readdata = kernel_addr_reg;
                REG_INPUT_MAP_ADDR: cs_readdata = input_map_addr_reg;
                REG_OUTPUT_MAP_ADDR: cs_readdata = output_map_addr_reg;
                default: cs_readdata = 'x;
            endcase
        end
    end


    fp8_comp_core comp_core (
        .clk(clk),
        .rst_n(rst_n),
        .start_computation(start_computation_core),
        .kernel_00(kernel_buf[0]), .kernel_01(kernel_buf[1]),
        .kernel_10(kernel_buf[2]), .kernel_11(kernel_buf[3]),
        .input_00(input_buf[0]), .input_01(input_buf[1]),
        .input_10(input_buf[2]), .input_11(input_buf[3]),
        .result(result_buf),
        .computation_done(computation_core_done)
    );


    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            row_counter <= '0;
            col_counter <= '0;
        end else begin
            current_state <= next_state;
            if (next_state == FETCH_KERNEL_01 && current_state == FETCH_KERNEL_00 && mem_readdatavalid) kernel_buf[0] <= mem_readdata;
            if (next_state == FETCH_KERNEL_10 && current_state == FETCH_KERNEL_01 && mem_readdatavalid) kernel_buf[1] <= mem_readdata;
            if (next_state == FETCH_KERNEL_11 && current_state == FETCH_KERNEL_10 && mem_readdatavalid) kernel_buf[2] <= mem_readdata;
            if (next_state == FETCH_INPUT_00 && current_state == FETCH_KERNEL_11 && mem_readdatavalid) kernel_buf[3] <= mem_readdata;

            if (next_state == FETCH_INPUT_01 && current_state == FETCH_INPUT_00 && mem_readdatavalid) input_buf[0] <= mem_readdata;
            if (next_state == FETCH_INPUT_10 && current_state == FETCH_INPUT_01 && mem_readdatavalid) input_buf[1] <= mem_readdata;
            if (next_state == FETCH_INPUT_11 && current_state == FETCH_INPUT_10 && mem_readdatavalid) input_buf[2] <= mem_readdata;
            if (next_state == COMPUTE && current_state == FETCH_INPUT_11 && mem_readdatavalid) input_buf[3] <= mem_readdata;


            if (next_state == FETCH_INPUT_00 && current_state == WRITE_OUTPUT) begin
                if (col_counter == OUTPUT_DIM - 1) begin
                    col_counter <= 0;
                    row_counter <= row_counter + 1;
                end else begin
                    col_counter <= col_counter + 1;
                end
            end

            if (current_state == IDLE && next_state != IDLE) begin
                 row_counter <= '0;
                 col_counter <= '0;
            end
        end
    end


    always_comb begin
        next_state = current_state;
        mem_read = 1'b0;
        mem_write = 1'b0;
        mem_address = '0;
        mem_writedata = '0;
        busy_status = 1'b0;
        done_status = 1'b0;
        start_computation_core = 1'b0;

        case (current_state)
            IDLE: begin
                busy_status = 1'b0;
                done_status = 1'b0;
                if (start_bit_reg) begin
                    next_state = FETCH_KERNEL_00;
                end else begin
                    next_state = IDLE;
                end
            end

            FETCH_KERNEL_00: begin
                busy_status = 1'b1;
                mem_read = 1'b1;
                mem_address = kernel_addr_reg + 0;
                if (mem_readdatavalid && !mem_waitrequest) next_state = FETCH_KERNEL_01;
            end
            FETCH_KERNEL_01: begin
                 busy_status = 1'b1;
                 mem_read = 1'b1;
                 mem_address = kernel_addr_reg + 1;
                 if (mem_readdatavalid && !mem_waitrequest) next_state = FETCH_KERNEL_10;
             end
             FETCH_KERNEL_10: begin
                  busy_status = 1'b1;
                  mem_read = 1'b1;
                  mem_address = kernel_addr_reg + 2;
                  if (mem_readdatavalid && !mem_waitrequest) next_state = FETCH_KERNEL_11;
              end
             FETCH_KERNEL_11: begin
                  busy_status = 1'b1;
                  mem_read = 1'b1;
                  mem_address = kernel_addr_reg + 3;
                  if (mem_readdatavalid && !mem_waitrequest) next_state = FETCH_INPUT_00;
              end

            FETCH_INPUT_00: begin
                 busy_status = 1'b1;
                 mem_read = 1'b1;
                 mem_address = input_map_addr_reg + (row_counter * INPUT_DIM) + col_counter + 0;
                 if (mem_readdatavalid && !mem_waitrequest) next_state = FETCH_INPUT_01;
             end
            FETCH_INPUT_01: begin
                 busy_status = 1'b1;
                 mem_read = 1'b1;
                 mem_address = input_map_addr_reg + (row_counter * INPUT_DIM) + col_counter + 1;
                 if (mem_readdatavalid && !mem_waitrequest) next_state = FETCH_INPUT_10;
             end
            FETCH_INPUT_10: begin
                 busy_status = 1'b1;
                 mem_read = 1'b1;
                 mem_address = input_map_addr_reg + ((row_counter+1) * INPUT_DIM) + col_counter + 0;
                 if (mem_readdatavalid && !mem_waitrequest) next_state = FETCH_INPUT_11;
             end
            FETCH_INPUT_11: begin
                 busy_status = 1'b1;
                 mem_read = 1'b1;
                 mem_address = input_map_addr_reg + ((row_counter+1) * INPUT_DIM) + col_counter + 1;
                 if (mem_readdatavalid && !mem_waitrequest) next_state = COMPUTE;
             end

            COMPUTE: begin
                 busy_status = 1'b1;
                 start_computation_core = 1'b1;
                 if (computation_core_done) begin
                     next_state = WRITE_OUTPUT;
                 end
            end

            WRITE_OUTPUT: begin
                 busy_status = 1'b1;
                 mem_write = 1'b1;
                 mem_address = output_map_addr_reg + (row_counter * OUTPUT_DIM) + col_counter;
                 mem_writedata = result_buf;
                 if (!mem_waitrequest) begin
                     if (row_counter == OUTPUT_DIM - 1 && col_counter == OUTPUT_DIM - 1) begin
                         next_state = DONE;
                     end else begin
                         next_state = FETCH_INPUT_00;
                     end
                 end
            end

            DONE: begin
                busy_status = 1'b0;
                done_status = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule