module uart_model #(
    parameter BAUD_RATE = 115200
)(
    input  wire clk,
    input  wire rx,
    output wire tx,
    output wire tx_rdy,
    output wire rx_rdy
);

    reg tx_idle;
    reg [3:0] tx_bit_count;
    reg [7:0] tx_shift_reg;
    reg [7:0] tx_char;

    reg rx_idle;
    reg [3:0] rx_bit_count;
    reg [7:0] rx_shift_reg;
    reg [7:0] rx_char;

    reg [31:0] baud_cnt;

    assign tx = tx_idle ? 1'b1 : tx_shift_reg[0];
    assign tx_rdy = tx_idle;
    assign rx_rdy = rx_idle;

    always @(posedge clk) begin
        if (tx_idle) begin
            tx_bit_count = 0;
            tx_shift_reg = 0;
        end else begin
            baud_cnt = baud_cnt + 1;
            if (baud_cnt >= (20000000 / BAUD_RATE)) begin
                baud_cnt = 0;
                if (tx_bit_count == 0) begin
                    tx_shift_reg = {1'b0, tx_char[7:1]};
                    tx_bit_count = 1;
                end else if (tx_bit_count == 10) begin
                    tx_shift_reg = {1'b1, tx_char[7:1]};
                    tx_idle = 1;
                    tx_bit_count = 0;
                end else begin
                    tx_shift_reg = {1'b0, tx_shift_reg[6:0]};
                    tx_bit_count = tx_bit_count + 1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (rx_idle) begin
            rx_bit_count = 0;
            rx_shift_reg = 0;
        end else begin
            baud_cnt = baud_cnt + 1;
            if (baud_cnt >= (20000000 / BAUD_RATE)) begin
                baud_cnt = 0;
                if (rx_bit_count == 0) begin
                    if (~rx) begin
                        rx_shift_reg = 0;
                        rx_bit_count = 1;
                    end else begin
                        rx_idle = 1;
                        rx_bit_count = 0;
                    end
                end else if (rx_bit_count == 9) begin
                    if (rx) begin
                        rx_char = rx_shift_reg[7:0];
                        rx_idle = 1;
                        rx_bit_count = 0;
                    end else begin
                        rx_idle = 1;
                        rx_bit_count = 0;
                    end
                end else begin
                    rx_shift_reg = {rx, rx_shift_reg[6:0]};
                    rx_bit_count = rx_bit_count + 1;
                end
            end
        end
    end

endmodule
