/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

parameter NaN_UPPER = 11'h7ff;
parameter TAG_INTEGER = 20'hffff0;
parameter TAG_TRUE = 20'hffffd;
parameter TAG_FALSE = 20'hffffe;
parameter TAG_NIL = 20'hfffff;


function [63:0] nan_box_integer;
    input [31:0] val;
    begin
        nan_box_integer = {val[31], NaN_UPPER, TAG_INTEGER, val};
    end
endfunction

function [63:0] nan_box_bool;
    input val_is_true;
    begin
        if (val_is_true)
            nan_box_bool = {1'b0, NaN_UPPER, TAG_TRUE, 32'h00000001};
        else
            nan_box_bool = {1'b0, NaN_UPPER, TAG_FALSE, 32'h00000000};
    end
endfunction

function [31:0] unbox_payload;
    input [63:0] val;
    begin
        unbox_payload = val[31:0];
    end
endfunction

function is_nan_boxed;
    input [63:0] val;
    begin
        is_nan_boxed = val[62:52] == NaN_UPPER;
    end
endfunction

function [19:0] get_type_tag;
    input [63:0] val;
    begin
        get_type_tag = val[51:32];
    end
endfunction

function is_integer;
    input [63:0] val;
    begin
        is_integer = (is_nan_boxed(val) && get_type_tag(val) == TAG_INTEGER);
    end
endfunction

function is_double;
    input [63:0] val;
    begin
        is_double = !is_nan_boxed(val) ||
                       (get_type_tag(val) != TAG_INTEGER &&
                        get_type_tag(val) != TAG_TRUE &&
                        get_type_tag(val) != TAG_FALSE &&
                        get_type_tag(val) != TAG_NIL &&
                        get_type_tag(val) != 20'hffff2);
    end
endfunction

function is_boolean;
    input [63:0] val;
    begin
        is_boolean = is_nan_boxed(val) && 
                       (get_type_tag(val) == TAG_TRUE ||
                        get_type_tag(val) == TAG_FALSE);
    end
endfunction

function is_nil;
    input [63:0] val;
    begin
        is_nil = is_nan_boxed(val) && (get_type_tag(val) == TAG_NIL);
    end
endfunction

function is_double_zero;
    input [63:0] val;
    begin
        is_double_zero = val == 63'h0;
    end
endfunction

function is_int_zero;
    input [63:0] val;
    begin
        is_int_zero = is_integer(val) && val[31:0] == 32'h0;
    end
endfunction


function is_truthy;
    input [63:0] val;
    begin
        is_truthy = !is_double_zero(val) && 
                    !is_int_zero(val) &&
                       (get_type_tag(val) != TAG_FALSE &&
                        get_type_tag(val) != TAG_NIL);
    end
endfunction


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
