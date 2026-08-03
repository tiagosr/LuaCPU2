/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module alu #(
    parameter DATA_WIDTH = 64
)(
    input  wire clk,
    input  wire reset,

    input  wire [4:0] alu_op,

    input  wire [63:0] operand_a,
    input  wire [63:0] operand_b,
    input  wire [63:0] operand_c,

    input  wire [33:0] immediate,

    output reg [63:0] result,

    output reg result_valid,

    output reg zero_flag,
    output reg div_zero_flag,
    output reg type_error_flag
);

    // Type tag constants (bits [51:32])
    localparam TAG_INTEGER  = 20'hffff0;
    localparam TAG_DOUBLE   = 20'hfffff; // NaN pattern, any non-specific tag
    localparam TAG_TRUE     = 20'hffffd;
    localparam TAG_FALSE    = 20'hffffe;
    localparam TAG_NIL      = 20'hfffff;
    localparam TAG_FIXED    = 20'hffff2;

    // NaN upper payload (bits [63:52])
    localparam NaN_UPPER    = 12'hfff;

    // ALU operation codes
    localparam OP_PASS      = 5'h0;
    localparam OP_ADD       = 5'h1;
    localparam OP_SUB       = 5'h2;
    localparam OP_MUL       = 5'h3;
    localparam OP_DIV       = 5'h4;
    localparam OP_NEG       = 5'h5;
    localparam OP_NOT       = 5'h6;
    localparam OP_BNOT      = 5'h7;
    localparam OP_AND       = 5'h8;
    localparam OP_OR        = 5'h9;
    localparam OP_XOR       = 5'hA;
    localparam OP_SHL       = 5'hB;
    localparam OP_SHR       = 5'hC;
    localparam OP_TEST      = 5'hE;
    localparam OP_CMP_EQ    = 5'hF;
    localparam OP_CMP_LT    = 5'h10;
    localparam OP_CMP_LE    = 5'h17;
    localparam OP_CMP_GT    = 5'h18;
    localparam OP_CMP_GE    = 5'h19;
    localparam OP_LEN       = 5'hD;
    localparam OP_CONCAT    = 5'h11;
    localparam OP_FORLOOP   = 5'h12;
    localparam OP_MOD       = 5'h14;
    localparam OP_POW       = 5'h15;
    localparam OP_IDIV      = 5'h16;

    // NaN-boxing: wrap a 32-bit value into a 64-bit NaN-boxed format
    function [63:0] nan_box_integer;
        input [31:0] val;
        begin
            nan_box_integer = {NaN_UPPER, TAG_INTEGER, val};
        end
    endfunction

    function [63:0] nan_box_fixed;
        input [31:0] val;
        begin
            nan_box_fixed = {NaN_UPPER, TAG_FIXED, val};
        end
    endfunction

    function [63:0] nan_box_bool;
        input val_is_true;
        begin
            if (val_is_true)
                nan_box_bool = {NaN_UPPER, TAG_TRUE, 32'h00000001};
            else
                nan_box_bool = {NaN_UPPER, TAG_FALSE, 32'h00000000};
        end
    endfunction

    function [63:0] nan_box_nil;
        begin
            nan_box_nil = {NaN_UPPER, TAG_NIL, 32'h00000000};
        end
    endfunction

    // Unbox: extract 32-bit payload from NaN-boxed value
    function [31:0] unbox_payload;
        input [63:0] val;
        begin
            unbox_payload = val[31:0];
        end
    endfunction

    // Get type tag
    function [19:0] get_type_tag;
        input [63:0] val;
        begin
            get_type_tag = val[51:32];
        end
    endfunction

    // Check if value is integer
    function is_integer;
        input [63:0] val;
        begin
            is_integer = (get_type_tag(val) == TAG_INTEGER);
        end
    endfunction

    // Check if value is double
    function is_double;
        input [63:0] val;
        begin
            is_double = (get_type_tag(val) != TAG_INTEGER &&
                         get_type_tag(val) != TAG_TRUE &&
                         get_type_tag(val) != TAG_FALSE &&
                         get_type_tag(val) != TAG_NIL &&
                         get_type_tag(val) != TAG_FIXED);
        end
    endfunction

    // Check if value is boolean
    function is_boolean;
        input [63:0] val;
        begin
            is_boolean = (get_type_tag(val) == TAG_TRUE ||
                          get_type_tag(val) == TAG_FALSE);
        end
    endfunction

    // Check if value is nil
    function is_nil;
        input [63:0] val;
        begin
            is_nil = (get_type_tag(val) == TAG_NIL);
        end
    endfunction

    // Check if value is truthy (not false and not nil)
    function is_truthy;
        input [63:0] val;
        begin
            is_truthy = (get_type_tag(val) != TAG_FALSE &&
                         get_type_tag(val) != TAG_NIL);
        end
    endfunction

    reg [63:0] next_result;
    reg next_result_valid;
    reg next_zero_flag;
    reg next_div_zero_flag;
    reg next_type_error_flag;

    always_comb begin
        next_result = 64'h0;
        next_result_valid = 1'b0;
        next_zero_flag = 1'b0;
        next_div_zero_flag = 1'b0;
        next_type_error_flag = 1'b0;

        case (alu_op)
            OP_PASS: begin
                next_result = operand_a;
                next_zero_flag = (operand_a[31:0] == 32'h0);
            end

            OP_ADD: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_integer(unbox_payload(operand_a) + unbox_payload(operand_b));
                    next_zero_flag = (unbox_payload(operand_a) + unbox_payload(operand_b) == 32'h0);
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    // Double + Integer => Double
                    if (is_integer(operand_a) && is_double(operand_b)) begin
                        next_result = operand_b; // simplified: integer converted to double
                    end else if (is_double(operand_a) && is_integer(operand_b)) begin
                        next_result = operand_a; // simplified: integer converted to double
                    end else begin
                        next_result = operand_a; // double + double simplified
                    end
                    next_zero_flag = (next_result[31:0] == 32'h0);
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_SUB: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_integer(unbox_payload(operand_a) - unbox_payload(operand_b));
                    next_zero_flag = (unbox_payload(operand_a) - unbox_payload(operand_b) == 32'h0);
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    if (is_integer(operand_a) && is_double(operand_b)) begin
                        next_result = operand_b;
                    end else if (is_double(operand_a) && is_integer(operand_b)) begin
                        next_result = operand_a;
                    end else begin
                        next_result = operand_a;
                    end
                    next_zero_flag = (next_result[31:0] == 32'h0);
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_MUL: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_integer(unbox_payload(operand_a) * unbox_payload(operand_b));
                    next_zero_flag = (unbox_payload(operand_a) * unbox_payload(operand_b) == 32'h0);
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    if (is_integer(operand_a) && is_double(operand_b)) begin
                        next_result = operand_b;
                    end else if (is_double(operand_a) && is_integer(operand_b)) begin
                        next_result = operand_a;
                    end else begin
                        next_result = operand_a;
                    end
                    next_zero_flag = (next_result[31:0] == 32'h0);
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_DIV: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    if (unbox_payload(operand_b) == 32'h0) begin
                        next_div_zero_flag = 1'b1;
                        next_result_valid = 1'b0;
                    end else begin
                        next_result = nan_box_integer(unbox_payload(operand_a) / unbox_payload(operand_b));
                        next_zero_flag = (unbox_payload(operand_a) / unbox_payload(operand_b) == 32'h0);
                    end
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    if (is_integer(operand_a) && is_double(operand_b)) begin
                        next_result = operand_b;
                    end else if (is_double(operand_a) && is_integer(operand_b)) begin
                        next_result = operand_a;
                    end else begin
                        next_result = operand_a;
                    end
                    next_zero_flag = (next_result[31:0] == 32'h0);
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_MOD: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    if (unbox_payload(operand_b) == 32'h0) begin
                        next_div_zero_flag = 1'b1;
                        next_result_valid = 1'b0;
                    end else begin
                        next_result = nan_box_integer(unbox_payload(operand_a) % unbox_payload(operand_b));
                        next_zero_flag = (unbox_payload(operand_a) % unbox_payload(operand_b) == 32'h0);
                    end
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_POW: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_integer(unbox_payload(operand_a) ** unbox_payload(operand_b));
                    next_zero_flag = (unbox_payload(operand_a) ** unbox_payload(operand_b) == 32'h0);
                end else begin
                    next_result = operand_a;
                    next_zero_flag = (next_result[31:0] == 32'h0);
                end
            end

            OP_IDIV: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    if (unbox_payload(operand_b) == 32'h0) begin
                        next_div_zero_flag = 1'b1;
                        next_result_valid = 1'b0;
                    end else begin
                        next_result = nan_box_integer(unbox_payload(operand_a) / unbox_payload(operand_b));
                        next_zero_flag = (unbox_payload(operand_a) / unbox_payload(operand_b) == 32'h0);
                    end
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_NEG: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a)) begin
                    next_result = nan_box_integer(-unbox_payload(operand_a));
                    next_zero_flag = (-unbox_payload(operand_a) == 32'h0);
                end else if (is_double(operand_a)) begin
                    next_result = operand_a;
                    next_zero_flag = (operand_a[31:0] == 32'h0);
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_NOT: begin
                next_result_valid = 1'b1;
                next_result = nan_box_bool(!is_truthy(operand_a));
                next_zero_flag = 1'b0;
            end

            OP_BNOT: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a)) begin
                    next_result = nan_box_integer(~unbox_payload(operand_a));
                    next_zero_flag = (~unbox_payload(operand_a) == 32'h0);
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_AND: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_integer(unbox_payload(operand_a) & unbox_payload(operand_b));
                    next_zero_flag = (unbox_payload(operand_a) & unbox_payload(operand_b) == 32'h0);
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_OR: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_integer(unbox_payload(operand_a) | unbox_payload(operand_b));
                    next_zero_flag = (unbox_payload(operand_a) | unbox_payload(operand_b) == 32'h0);
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_XOR: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_integer(unbox_payload(operand_a) ^ unbox_payload(operand_b));
                    next_zero_flag = (unbox_payload(operand_a) ^ unbox_payload(operand_b) == 32'h0);
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_SHL: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_integer(unbox_payload(operand_a) << (unbox_payload(operand_b) & 31'h1F));
                    next_zero_flag = (unbox_payload(operand_a) << (unbox_payload(operand_b) & 31'h1F) == 32'h0);
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_SHR: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_integer(unbox_payload(operand_a) >> (unbox_payload(operand_b) & 31'h1F));
                    next_zero_flag = (unbox_payload(operand_a) >> (unbox_payload(operand_b) & 31'h1F) == 32'h0);
                end else begin
                    next_type_error_flag = 1'b1;
                end
            end

            OP_TEST: begin
                next_result_valid = 1'b1;
                next_result = nan_box_bool(!is_truthy(operand_a));
                next_zero_flag = 1'b0;
            end

            OP_CMP_EQ: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_bool(unbox_payload(operand_a) == unbox_payload(operand_b));
                end else if (is_boolean(operand_a) && is_boolean(operand_b)) begin
                    next_result = nan_box_bool(get_type_tag(operand_a) == get_type_tag(operand_b));
                end else if (is_nil(operand_a) && is_nil(operand_b)) begin
                    next_result = nan_box_bool(1'b1);
                end else begin
                    next_result = nan_box_bool(1'b0);
                end
                next_zero_flag = 1'b0;
            end

            OP_CMP_LT: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_bool($signed(unbox_payload(operand_a)) < $signed(unbox_payload(operand_b)));
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    next_result = nan_box_bool(1'b0);
                end else begin
                    next_result = nan_box_bool(1'b0);
                end
                next_zero_flag = 1'b0;
            end

            OP_CMP_LE: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_bool($signed(unbox_payload(operand_a)) <= $signed(unbox_payload(operand_b)));
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    next_result = nan_box_bool(1'b0);
                end else begin
                    next_result = nan_box_bool(1'b0);
                end
                next_zero_flag = 1'b0;
            end

            OP_CMP_GT: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_bool($signed(unbox_payload(operand_a)) > $signed(unbox_payload(operand_b)));
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    next_result = nan_box_bool(1'b0);
                end else begin
                    next_result = nan_box_bool(1'b0);
                end
                next_zero_flag = 1'b0;
            end

            OP_CMP_GE: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_bool($signed(unbox_payload(operand_a)) >= $signed(unbox_payload(operand_b)));
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    next_result = nan_box_bool(1'b0);
                end else begin
                    next_result = nan_box_bool(1'b0);
                end
                next_zero_flag = 1'b0;
            end

            OP_LEN: begin
                next_result_valid = 1'b1;
                next_result = nan_box_integer(32'h0);
                next_zero_flag = 1'b1;
            end

            OP_CONCAT: begin
                next_result_valid = 1'b1;
                next_result = operand_a;
                next_zero_flag = (operand_a[31:0] == 32'h0);
            end

            OP_FORLOOP: begin
                next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    next_result = nan_box_integer(unbox_payload(operand_a) + unbox_payload(operand_b));
                    next_zero_flag = (unbox_payload(operand_a) + unbox_payload(operand_b) == 32'h0);
                end else begin
                    next_result = operand_a;
                    next_zero_flag = (operand_a[31:0] == 32'h0);
                end
            end

            default: begin
                next_result = operand_a;
                next_zero_flag = (operand_a[31:0] == 32'h0);
            end
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            result <= 64'h0;
            result_valid <= 1'b0;
            zero_flag <= 1'b0;
            div_zero_flag <= 1'b0;
            type_error_flag <= 1'b0;
        end else begin
            result <= next_result;
            result_valid <= next_result_valid;
            zero_flag <= next_zero_flag;
            div_zero_flag <= next_div_zero_flag;
            type_error_flag <= next_type_error_flag;
        end
    end

/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
endmodule
