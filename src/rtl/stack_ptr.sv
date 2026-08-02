module stack_ptr #(
    parameter STACK_SIZE = 256
)(
    input  wire clk,
    input  wire reset,

    output reg [31:0] wb,

    output reg [31:0] stack_ptr_out,

    output reg [31:0] top,

    input  wire stack_push,
    input  wire stack_pop,
    input  wire [7:0] stack_push_count,

    input  wire wb_update,
    input  wire [1:0] wb_op,
    input  wire [15:0] wb_value,

    output reg stack_overflow,

    input  wire clear_top
);

    reg [31:0] next_stack_ptr;
    reg [31:0] next_wb;

    always @(posedge clk) begin
        if (reset) begin
            wb <= 0;
            stack_ptr_out <= 0;
            top <= 0;
            stack_overflow <= 0;
        end else begin
            if (wb_update) begin
                case (wb_op)
                    2'b00: next_wb <= wb;
                    2'b01: next_wb <= wb + {16'h0000, wb_value};
                    2'b10: begin
                        if (wb >= {16'h0000, wb_value})
                            next_wb <= wb - {16'h0000, wb_value};
                        else
                            next_wb <= 0;
                    end
                    2'b11: next_wb <= {16'h0000, wb_value};
                endcase
            end else begin
                next_wb <= wb;
            end

            if (stack_push) begin
                if (stack_push_count == 0)
                    next_stack_ptr <= stack_ptr_out + 1;
                else
                    next_stack_ptr <= stack_ptr_out + {24'h000000, stack_push_count};
            end else if (stack_pop) begin
                if (stack_ptr_out >= {24'h000000, stack_push_count})
                    next_stack_ptr <= stack_ptr_out - {24'h000000, stack_push_count};
                else
                    next_stack_ptr <= 0;
            end else begin
                next_stack_ptr <= stack_ptr_out;
            end

            if (clear_top)
                top <= 0;
            else
                top <= next_stack_ptr;

            stack_ptr_out <= next_stack_ptr;
            wb <= next_wb;

            if (next_stack_ptr >= STACK_SIZE)
                stack_overflow <= 1;
            else
                stack_overflow <= 0;
        end
    end

endmodule
