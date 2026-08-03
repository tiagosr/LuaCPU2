module reg_cache #(
    parameter CACHE_SIZE = 32
)(
    input  wire clk,
    input  wire reset,

    input  wire [31:0] wb,

    input  wire [7:0] operand_offset,
    input  wire [7:0] write_offset,

    input  wire read_req,
    output reg read_valid,
    output reg [63:0] read_data,

    input  wire write_req,
    input  wire [63:0] write_data,

    input  wire bus_resp_valid,
    input  wire [63:0] bus_resp_data,

    output reg cache_miss,
    output reg stall,

    input  wire invalidate,

    output reg [4:0] hit_count,
    output reg [4:0] miss_count
);

    reg [63:0] cache_data [0:CACHE_SIZE - 1];
    reg cache_valid [0:CACHE_SIZE - 1];
    reg [31:0] cache_addr [0:CACHE_SIZE - 1];
    reg [4:0] cache_lru [0:CACHE_SIZE - 1];

    reg [31:0] stack_addr;
    reg [31:0] write_addr;
    reg [4:0] lru_max;
    reg [4:0] hit_idx;
    reg hit_found;

    reg [4:0] evict_idx;
    reg low_lru_found;

    reg waiting_for_bus;
    reg [4:0] load_idx;

    reg [4:0] current_lru_max;

    always @(posedge clk) begin
        if (reset) begin
            stack_addr <= 0;
            lru_max <= 0;
            hit_idx <= 0;
            hit_found <= 0;
            evict_idx <= 0;
            low_lru_found <= 0;
            waiting_for_bus <= 0;
            load_idx <= 0;
            current_lru_max <= 0;
            read_valid <= 0;
            read_data <= 0;
            cache_miss <= 0;
            stall <= 0;
            hit_count <= 0;
            miss_count <= 0;
            for (int i = 0; i < CACHE_SIZE; i = i + 1) begin
                cache_valid[i] <= 0;
                cache_lru[i] <= 0;
                cache_data[i] <= 0;
                cache_addr[i] <= 0;
            end
        end else begin
            stack_addr <= wb + {24'h000000, operand_offset};
            write_addr <= wb + {24'h000000, write_offset};

            read_valid <= 0;
            cache_miss <= 0;

            if (invalidate) begin
                for (int i = 0; i < CACHE_SIZE; i = i + 1) begin
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
                        miss_count <= miss_count + 1;
                    end
                end else if (write_req) begin
                    hit_found <= 0;
                    for (int i = 0; i < CACHE_SIZE; i = i + 1) begin
                        if (cache_valid[i] && cache_addr[i] == write_addr) begin
                            hit_found <= 1;
                            hit_idx <= i[4:0];
                            cache_data[i] <= write_data;
                            cache_lru[i] <= current_lru_max + 1;
                            if (current_lru_max + 1 > lru_max) begin
                                lru_max <= current_lru_max + 1;
                            end
                            hit_count <= hit_count + 1;
                            break;
                        end
                    end
                    if (!hit_found) begin
                        cache_miss <= 1;
                        low_lru_found <= 0;
                        for (int i = 0; i < CACHE_SIZE; i = i + 1) begin
                            if (!low_lru_found || cache_lru[i] < cache_lru[evict_idx]) begin
                                evict_idx <= i[4:0];
                                low_lru_found <= 1;
                            end
                        end
                        cache_data[evict_idx] <= write_data;
                        cache_addr[evict_idx] <= write_addr;
                        cache_valid[evict_idx] <= 1;
                        cache_lru[evict_idx] <= current_lru_max + 1;
                        if (current_lru_max + 1 > lru_max) begin
                            lru_max <= current_lru_max + 1;
                        end
                        miss_count <= miss_count + 1;
                    end
                end else if (read_req) begin
                    hit_found <= 0;
                    for (int i = 0; i < CACHE_SIZE; i = i + 1) begin
                        if (cache_valid[i] && cache_addr[i] == stack_addr) begin
                            hit_found <= 1;
                            hit_idx <= i[4:0];
                            cache_lru[i] <= current_lru_max + 1;
                            if (current_lru_max + 1 > lru_max) begin
                                lru_max <= current_lru_max + 1;
                            end
                            read_valid <= 1;
                            read_data <= cache_data[i];
                            hit_count <= hit_count + 1;
                            break;
                        end
                    end
                    if (!hit_found) begin
                        cache_miss <= 1;
                        stall <= 1;
                        waiting_for_bus <= 1;
                        low_lru_found <= 0;
                        for (int i = 0; i < CACHE_SIZE; i = i + 1) begin
                            if (!low_lru_found || cache_lru[i] < cache_lru[evict_idx]) begin
                                evict_idx <= i[4:0];
                                low_lru_found <= 1;
                            end
                        end
                        load_idx <= evict_idx;
                        miss_count <= miss_count + 1;
                    end
                end

                current_lru_max <= lru_max;
            end
        end
    end

endmodule
