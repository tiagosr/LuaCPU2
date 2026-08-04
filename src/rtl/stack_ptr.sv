/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module stack_ptr #(
    parameter PARAM_STACK = 256
)(
    input  wire clk,
    input  wire reset,
    output reg [31:0] wb,
    output reg [31:0] stack_ptr_out,
    output reg [31:0] top,
    input  wire [1:0] stack_push,
    input  wire [1:0] stack_pop,
    input  wire [7:0] stack_push_count,
    input  wire wb_update,
    input  wire [1:0] wb_op,
    input  wire [15:0] wb_value,
    output reg [31:0] stack_overflow,
    input  wire clear_top
);

    always @(posedge clk) begin
        if (reset) begin
            wb <= 0;
            stack_ptr_out <= 0;
            top <= 0;
            stack_overflow <= 0;
        end else begin
            if (wb_update) begin
                case (wb_op)
                    2'b00: wb <= wb;
                    2'b01: wb <= wb + wb_value;
                    2'b10: begin
                        if (wb >= wb_value)
                            wb <= wb - wb_value;
                        else
                            wb <= 0;
                    end
                    2'b11: wb <= wb_value;
                endcase
            end

            if (stack_push) begin
                stack_ptr_out <= stack_ptr_out + stack_push_count;
            end else if (stack_pop) begin
                stack_ptr_out <= stack_ptr_out - stack_push_count;
            end

            if (clear_top)
                top <= 0;
            else
                top <= stack_ptr_out;

            if (stack_ptr_out >= PARAM_STACK)
                stack_overflow <= 1;
            else
                stack_overflow <= 0;
        end
    end

endmodule
/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
