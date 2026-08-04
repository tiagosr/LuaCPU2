/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module value_conv #(
    localparam NaN_UPPER = 12'hfff,
    localparam TAG_INTEGER = 20'hffff0,
    localparam TAG_TRUE = 20'hffffd,
    localparam TAG_FALSE = 20'hffffe,
    localparam TAG_NIL = 20'hfffff
)(
    input  wire clk,
    input  wire reset,
    input  wire [4:0] alu_op,
    input  wire [33:0] immediate,
    input  wire [63:0] ktable_data,
    output reg [63:0] load_value,
    output reg [1:0] load_value_valid,
    output reg [1:0] load_value_valid_comb
);

    always @(posedge clk) begin
        if (reset) begin
            load_value <= 64'h0;
            load_value_valid <= 0;
        end else begin
            case (alu_op)
                5'h0: begin
                    if (immediate != 34'h0) begin
                        if (immediate[16] == 1'b1) begin
                            load_value = {NaN_UPPER, TAG_INTEGER, {16{immediate[16]}}, immediate[15:0]};
                        end else begin
                            load_value = {NaN_UPPER, TAG_INTEGER, immediate[15:0]};
                        end
                        load_value_valid = 1;
                    end else begin
                        load_value_valid = 0;
                    end
                end
                5'h2: begin
                    load_value = {NaN_UPPER, TAG_TRUE, 32'h00000001};
                    load_value_valid = 1;
                end
                5'h3: begin
                    load_value = {NaN_UPPER, TAG_FALSE, 32'h00000000};
                    load_value_valid = 1;
                end
                5'h4: begin
                    load_value = {NaN_UPPER, TAG_NIL, 32'h00000000};
                    load_value_valid = 1;
                end
                5'h5: begin
                    if (immediate[16] == 1'b1) begin
                        load_value = {NaN_UPPER, TAG_INTEGER, {16{immediate[16]}}, immediate[15:0]};
                    end else begin
                        load_value = {NaN_UPPER, TAG_INTEGER, immediate[15:0]};
                    end
                    load_value_valid = 1;
                end
                default: begin
                    load_value = ktable_data;
                    load_value_valid = 1;
                end
            endcase
        end
    end

    assign load_value_valid_comb = load_value_valid;

endmodule
/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
