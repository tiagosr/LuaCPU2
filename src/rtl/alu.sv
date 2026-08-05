/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module alu (
    input  wire clk,
    input  wire reset,
    input  wire [4:0] alu_op,
    input  wire [1:0] alu_optype,
    input  wire [63:0] operand_a,
    input  wire [63:0] operand_b,
    input  wire [33:0] immediate,
    input  wire test_compare_k,
    output reg [63:0] result,
    output reg [1:0] result_valid,
    output reg [1:0] zero_flag,
    output reg [1:0] div_zero_flag,
    output reg [1:0] type_error_flag
);


    reg [63:0] alu_next_result;
    reg alu_next_result_valid;
    reg alu_next_div_zero_flag;
    reg alu_next_type_error_flag;

    always @(*) begin
        alu_next_result = 64'h0;
        alu_next_result_valid = 1'b0;
        alu_next_div_zero_flag = 1'b0;
        alu_next_type_error_flag = 1'b0;

        case (alu_op)
            ALU_PASS: begin
                alu_next_result = operand_a;
            end

            ALU_ADD: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_integer(unbox_payload(operand_a) + unbox_payload(operand_b));
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    if (is_integer(operand_a) && is_double(operand_b)) begin
                        alu_next_result = operand_b;
                    end else if (is_double(operand_a) && is_integer(operand_b)) begin
                        alu_next_result = operand_a;
                    end else begin
                        alu_next_result = operand_a;
                    end
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_SUB: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_integer(unbox_payload(operand_a) - unbox_payload(operand_b));
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    if (is_integer(operand_a) && is_double(operand_b)) begin
                        alu_next_result = operand_b;
                    end else if (is_double(operand_a) && is_integer(operand_b)) begin
                        alu_next_result = operand_a;
                    end else begin
                        alu_next_result = operand_a;
                    end
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_MUL: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_integer(unbox_payload(operand_a) * unbox_payload(operand_b));
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    if (is_integer(operand_a) && is_double(operand_b)) begin
                        alu_next_result = operand_b;
                    end else if (is_double(operand_a) && is_integer(operand_b)) begin
                        alu_next_result = operand_a;
                    end else begin
                        alu_next_result = operand_a;
                    end
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_DIV: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    if (unbox_payload(operand_b) == 32'h0) begin
                        alu_next_div_zero_flag = 1'b1;
                        alu_next_result_valid = 1'b0;
                    end else begin
                        alu_next_result = nan_box_integer(unbox_payload(operand_a) / unbox_payload(operand_b));
                    end
                end else if (is_double(operand_a) || is_double(operand_b)) begin
                    if (is_integer(operand_a) && is_double(operand_b)) begin
                        alu_next_result = operand_b;
                    end else if (is_double(operand_a) && is_integer(operand_b)) begin
                        alu_next_result = operand_a;
                    end else begin
                        alu_next_result = operand_a;
                    end
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_MOD: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    if (unbox_payload(operand_b) == 32'h0) begin
                        alu_next_div_zero_flag = 1'b1;
                        alu_next_result_valid = 1'b0;
                    end else begin
                        alu_next_result = nan_box_integer(unbox_payload(operand_a) % unbox_payload(operand_b));
                    end
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_POW: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_integer(unbox_payload(operand_a) ** unbox_payload(operand_b));
                end else begin
                    alu_next_result = operand_a;
                end
            end

            ALU_IDIV: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    if (unbox_payload(operand_b) == 32'h0) begin
                        alu_next_div_zero_flag = 1'b1;
                        alu_next_result_valid = 1'b0;
                    end else begin
                        alu_next_result = nan_box_integer(unbox_payload(operand_a) / unbox_payload(operand_b));
                    end
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_NEG: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a)) begin
                    alu_next_result = nan_box_integer(-unbox_payload(operand_a));
                end else if (is_double(operand_a)) begin
                    alu_next_result = operand_a;
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_NOT: begin
                alu_next_result_valid = 1'b1;
                if (alu_optype == ALUOPTYPE_LOGIC) begin
                    alu_next_result = nan_box_bool(!is_truthy(operand_a));
                end else if (is_integer(operand_a)) begin
                    alu_next_result = nan_box_integer(~unbox_payload(operand_a));
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_AND: begin
                alu_next_result_valid = 1'b1;
                if (alu_optype == ALUOPTYPE_LOGIC) begin
                    alu_next_result = nan_box_bool(is_truthy(operand_a) & is_truthy(operand_b));
                end else if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_integer(unbox_payload(operand_a) & unbox_payload(operand_b));
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_OR: begin
                alu_next_result_valid = 1'b1;
                if (alu_optype == ALUOPTYPE_LOGIC) begin
                    alu_next_result = nan_box_bool(is_truthy(operand_a) | is_truthy(operand_b));
                end else if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_integer(unbox_payload(operand_a) | unbox_payload(operand_b));
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_XOR: begin
                alu_next_result_valid = 1'b1;
                if (alu_optype == ALUOPTYPE_LOGIC) begin
                    alu_next_result = nan_box_bool(is_truthy(operand_a) ^ is_truthy(operand_b));
                end else if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_integer(unbox_payload(operand_a) ^ unbox_payload(operand_b));
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_SHL: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_integer(unbox_payload(operand_a) << (unbox_payload(operand_b) & 32'h1F));
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_SHR: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_integer(unbox_payload(operand_a) >> (unbox_payload(operand_b) & 32'h1F));
                end else begin
                    alu_next_type_error_flag = 1'b1;
                end
            end

            ALU_TEST: begin
                alu_next_result_valid = 1'b1;
                alu_next_result = nan_box_bool(!is_truthy(operand_a));
            end

            ALU_CMP_EQ: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_bool(unbox_payload(operand_a) == unbox_payload(operand_b));
                end else if (is_boolean(operand_a) && is_boolean(operand_b)) begin
                    alu_next_result = nan_box_bool(get_type_tag(operand_a) == get_type_tag(operand_b));
                end else if (is_nil(operand_a) && is_nil(operand_b)) begin
                    alu_next_result = nan_box_bool(1'b1);
                end else begin
                    alu_next_result = nan_box_bool(1'b0);
                end
            end

            ALU_CMP_LT: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_bool($signed(unbox_payload(operand_a)) < $signed(unbox_payload(operand_b)));
                end else begin
                    alu_next_result = nan_box_bool(1'b0);
                end
            end

            ALU_CMP_LE: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_bool($signed(unbox_payload(operand_a)) <= $signed(unbox_payload(operand_b)));
                end else begin
                    alu_next_result = nan_box_bool(1'b0);
                end
            end

            ALU_CMP_GT: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_bool($signed(unbox_payload(operand_a)) > $signed(unbox_payload(operand_b)));
                end else begin
                    alu_next_result = nan_box_bool(1'b0);
                end
            end

            ALU_CMP_GE: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_bool($signed(unbox_payload(operand_a)) >= $signed(unbox_payload(operand_b)));
                end else begin
                    alu_next_result = nan_box_bool(1'b0);
                end
            end

            ALU_LEN: begin
                alu_next_result_valid = 1'b1;
                alu_next_result = nan_box_integer(32'h0);
            end

            ALU_CONCAT: begin
                alu_next_result_valid = 1'b1;
                alu_next_result = operand_a;
            end

            ALU_FORLOOP: begin
                alu_next_result_valid = 1'b1;
                if (is_integer(operand_a) && is_integer(operand_b)) begin
                    alu_next_result = nan_box_integer(unbox_payload(operand_a) + unbox_payload(operand_b));
                end else begin
                    alu_next_result = operand_a;
                end
            end

            ALU_NIL: begin
                alu_next_result_valid = 1'b1;
                alu_next_result = {NaN_UPPER, TAG_NIL, 32'h00000000};
            end

            ALU_FALSE: begin
                alu_next_result_valid = 1'b1;
                alu_next_result = nan_box_bool(1'b0);
            end

            ALU_TRUE: begin
                alu_next_result_valid = 1'b1;
                alu_next_result = nan_box_bool(1'b1);
            end

            default: begin
                alu_next_result = operand_a;
            end
        endcase
    end

    always @(posedge clk) begin
        if (reset) begin
            result <= 64'h0;
            result_valid <= 0;
            div_zero_flag <= 0;
            type_error_flag <= 0;
        end else begin
            result <= alu_next_result;
            result_valid <= alu_next_result_valid;
            div_zero_flag <= alu_next_div_zero_flag;
            type_error_flag <= alu_next_type_error_flag;
        end
    end

endmodule
/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
