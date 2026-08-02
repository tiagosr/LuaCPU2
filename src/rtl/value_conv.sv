/* verilator lint_off WIDTHEXPAND */
module value_conv #(
    parameter IMMEDIATE_WIDTH = 34,
    parameter DATA_WIDTH = 64
)(
    input  wire clk,
    input  wire reset,

    input  wire [4:0] alu_op,

    input  wire [IMMEDIATE_WIDTH-1:0] immediate,

    input  wire [63:0] ktable_data,

    output reg [63:0] load_value,

    output reg load_value_valid
);

    // Type tag constants
    localparam TAG_INTEGER  = 20'hffff0;
    localparam TAG_TRUE     = 20'hffffd;
    localparam TAG_FALSE    = 20'hffffe;
    localparam TAG_NIL      = 20'hfffff;
    localparam NaN_UPPER    = 12'hfff;

    reg [63:0] next_load_value;
    reg next_load_value_valid;

    always_comb begin
        next_load_value = 64'h0;
        next_load_value_valid = 1'b1;

        case (alu_op)
            5'h0: begin
                // pass / load operations - use immediate
                if (immediate[16] == 1'b1) begin
                    next_load_value = {NaN_UPPER, TAG_INTEGER, {16{immediate[16]}}, immediate[15:0]};
                end else begin
                    next_load_value = {NaN_UPPER, TAG_INTEGER, immediate[15:0]};
                end
            end
            default: begin
                next_load_value = ktable_data;
                next_load_value_valid = 1'b1;
            end
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            load_value <= 64'h0;
            load_value_valid <= 1'b0;
        end else begin
            load_value <= next_load_value;
            load_value_valid <= next_load_value_valid;
        end
    end

/* verilator lint_on WIDTHEXPAND */
endmodule
