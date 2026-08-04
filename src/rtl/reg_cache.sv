/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */
module reg_cache #(
    parameter CACHE_SIZE = 32
)(
    input  wire clk,
    input  wire reset,
    input  wire [31:0] wb,
    input  wire [7:0] operand_offset,
    input  wire [7:0] operand_c_offset,
    input  wire [7:0] write_offset,
    input  wire [1:0] read_req,
    output reg [1:0] read_valid,
    output reg [63:0] read_data,
    input  wire [1:0] read_c_req,
    output reg [1:0] read_c_valid,
    output reg [63:0] read_c_data,
    input  wire [1:0] write_req,
    input  wire [63:0] write_data,
    input  wire [1:0] bus_resp_valid,
    input  wire [63:0] bus_resp_data,
    output reg [1:0] cache_miss,
    output reg [1:0] stall,
    output reg [1:0] stall_c,
    input  wire [1:0] invalidate,
    output reg [31:0] hit_count,
    output reg [31:0] miss_count
);

    reg [63:0] cache_data [0:CACHE_SIZE-1];
    reg cache_valid [0:CACHE_SIZE-1];
    reg [31:0] cache_addr [0:CACHE_SIZE-1];
    reg [4:0] cache_lru [0:CACHE_SIZE-1];

    reg [31:0] stack_addr;
    reg [31:0] stack_addr_c;
    reg [4:0] lru_max;
    reg [4:0] current_lru_max;
    reg [4:0] hit_idx;
    reg hit_found;
    reg [4:0] hit_c_idx;
    reg hit_c_found;
    reg [4:0] evict_idx;
    reg low_lru_found;
    reg waiting_for_bus;
    reg [4:0] load_idx;
    reg waiting_for_bus_c;
    reg [4:0] load_idx_c;
    reg cache_search_done;

    reg [31:0] miss_count_reg;
    reg [31:0] hit_count_reg;

    always @(posedge clk) begin
        if (reset) begin
            stack_addr <= 0;
            stack_addr_c <= 0;
            lru_max <= 0;
            current_lru_max <= 0;
            for (integer i = 0; i < CACHE_SIZE; i = i + 1) begin
                cache_valid[i] <= 0;
                cache_lru[i] <= 0;
                cache_data[i] <= 0;
                cache_addr[i] <= 0;
            end
            waiting_for_bus <= 0;
            load_idx <= 0;
            waiting_for_bus_c <= 0;
            load_idx_c <= 0;
            cache_search_done <= 0;
            read_valid <= 0;
            read_data <= 0;
            read_c_valid <= 0;
            read_c_data <= 0;
            cache_miss <= 0;
            stall <= 0;
            stall_c <= 0;
            miss_count_reg <= 0;
            hit_count_reg <= 0;
        end else begin
            stack_addr <= wb + operand_offset;
            stack_addr_c <= wb + operand_c_offset;

            read_valid <= 0;
            read_c_valid <= 0;
            cache_miss <= 0;
            stall <= 0;
            stall_c <= 0;

            if (invalidate) begin
                for (integer i = 0; i < CACHE_SIZE; i = i + 1) begin
                    cache_valid[i] <= 0;
                    cache_lru[i] <= 0;
                end
                lru_max <= 0;
                current_lru_max <= 0;
            end else begin
                if (waiting_for_bus) begin
                    if (bus_resp_valid) begin
                        cache_data[load_idx] <= bus_resp_data;
                        cache_addr[load_idx] <= stack_addr;
                        cache_valid[load_idx] <= 1;
                        cache_lru[load_idx] <= current_lru_max + 1;
                        if (current_lru_max + 1 > lru_max) begin
                            lru_max <= current_lru_max + 1;
                        end
                        read_valid <= 1;
                        read_data <= bus_resp_data;
                        waiting_for_bus <= 0;
                        stall <= 0;
                        miss_count_reg <= miss_count_reg + 1;
                    end else begin
                        cache_miss <= 1;
                    end
                end else if (waiting_for_bus_c) begin
                    if (bus_resp_valid) begin
                        cache_data[load_idx_c] <= bus_resp_data;
                        cache_addr[load_idx_c] <= stack_addr_c;
                        cache_valid[load_idx_c] <= 1;
                        cache_lru[load_idx_c] <= current_lru_max + 1;
                        if (current_lru_max + 1 > lru_max) begin
                            lru_max <= current_lru_max + 1;
                        end
                        read_c_valid <= 1;
                        read_c_data <= bus_resp_data;
                        waiting_for_bus_c <= 0;
                        stall_c <= 0;
                        miss_count_reg <= miss_count_reg + 1;
                    end else begin
                        cache_miss <= 1;
                    end
                end else if (read_req) begin
                    hit_found <= 0;
                    cache_search_done <= 0;
                    for (integer i = 0; i < CACHE_SIZE && !cache_search_done; i = i + 1) begin
                        if (cache_valid[i] && cache_addr[i] == stack_addr) begin
                            hit_found <= 1;
                            hit_idx <= i[4:0];
                            cache_lru[i] <= current_lru_max + 1;
                            if (current_lru_max + 1 > lru_max) begin
                                lru_max <= current_lru_max + 1;
                            end
                            read_valid <= 1;
                            read_data <= cache_data[i];
                            cache_search_done <= 1;
                            hit_count_reg <= hit_count_reg + 1;
                        end
                    end
                    if (!hit_found) begin
                        cache_miss <= 1;
                        stall <= 1;
                        waiting_for_bus <= 1;
                        low_lru_found <= 0;
                        for (integer i = 0; i < CACHE_SIZE; i = i + 1) begin
                            if (!low_lru_found || cache_lru[i] < cache_lru[evict_idx]) begin
                                evict_idx <= i[4:0];
                                low_lru_found <= 1;
                            end
                        end
                        load_idx <= evict_idx;
                    end
                end else if (read_c_req) begin
                    hit_c_found <= 0;
                    cache_search_done <= 0;
                    for (integer i = 0; i < CACHE_SIZE && !cache_search_done; i = i + 1) begin
                        if (cache_valid[i] && cache_addr[i] == stack_addr_c) begin
                            hit_c_found <= 1;
                            hit_c_idx <= i[4:0];
                            cache_lru[i] <= current_lru_max + 1;
                            if (current_lru_max + 1 > lru_max) begin
                                lru_max <= current_lru_max + 1;
                            end
                            read_c_valid <= 1;
                            read_c_data <= cache_data[i];
                            cache_search_done <= 1;
                            hit_count_reg <= hit_count_reg + 1;
                        end
                    end
                    if (!hit_c_found) begin
                        stall_c <= 1;
                        waiting_for_bus_c <= 1;
                        low_lru_found <= 0;
                        for (integer i = 0; i < CACHE_SIZE; i = i + 1) begin
                            if (!low_lru_found || cache_lru[i] < cache_lru[evict_idx]) begin
                                evict_idx <= i[4:0];
                                low_lru_found <= 1;
                            end
                        end
                        load_idx_c <= evict_idx;
                    end
                end

                current_lru_max <= lru_max;
            end
        end
    end

    assign hit_count = hit_count_reg;
    assign miss_count = miss_count_reg;

endmodule
/* verilator lint_on WIDTHTRUNC */
/* verilator lint_on WIDTHEXPAND */
