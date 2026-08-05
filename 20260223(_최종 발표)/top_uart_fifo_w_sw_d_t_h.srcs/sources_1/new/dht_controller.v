`timescale 1ns / 1ps

module top_dht11 (
    input        clk,
    input        rst,
    input        start,
    output reg [15:0] humidity,
    output reg [15:0] temperature,
    output [2:0] debug,
    output       dht11_valid,
    inout        dhtio
);
    wire [15:0] w_humidity, w_temperature;
    wire w_dht11_done;
    wire w_btn_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            temperature  <= 16'd0;
            humidity <= 16'd0;
        end else begin
            temperature  <= temperature;
            humidity <= humidity;
            if (dht11_valid) begin
                temperature  <= w_temperature;
                humidity <= w_humidity;
            end
        end
    end

    btn_debounce U_BTN_DB_R (
        .clk  (clk),
        .reset(rst),
        .i_btn(start),
        .o_btn(w_btn_r)
    );

    dht11_controller U_DHT11 (
        .clk(clk),
        .rst(rst),
        .start(w_btn_r),
        .humidity(w_humidity),
        .temperature(w_temperature),
        .dht11_done(w_dht11_done),
        .dht11_valid(dht11_valid),
        .debug(debug),
        .dhtio(dhtio)
    );

endmodule

module dht11_controller (
    input             clk,
    input             rst,
    input             start,
    output     [15:0] humidity,
    output     [15:0] temperature,
    output reg        dht11_done,
    output reg        dht11_valid,
    output     [ 2:0] debug,
    inout             dhtio
);
    wire tick_10us;

    tick_gen_10usec U_TICK_10u (
        .clk(clk),
        .rst(rst),
        .tick_10us(tick_10us)
    );

    // STATE
    parameter IDLE = 0, START = 1, WAIT =2, SYNC_L = 3, SYNC_H = 4,
                DATA_SYNC = 5, DATA_COLLECT = 6, STOP = 7;
    reg [2:0] c_state, n_state;
    reg dhtio_reg, dhtio_next;
    reg io_sel_reg, io_sel_next;
    reg [15:0] humidity_reg, humidity_next, temperature_reg, temperature_next;

    // for 19msec count by 10usec tick
    reg [$clog2(1900)-1:0]
        tick_cnt_reg, tick_cnt_next;  //18000*10 = 1800 -> 넉넉하게 1900
    reg [5:0] bit_cnt_reg, bit_cnt_next;  // 40비트 카운팅용
    reg [39:0] data_reg, data_next;

    assign dhtio = (io_sel_reg) ? dhtio_reg : 1'bz;
    assign debug = c_state;
    assign humidity = humidity_reg;
    assign temperature = temperature_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= 3'b000;
            dhtio_reg       <= 1'b1;
            tick_cnt_reg    <= 0;
            io_sel_reg      <= 1'b1;
            bit_cnt_reg     <= 0;
            data_reg        <= 0;
            humidity_reg    <= 0;
            temperature_reg <= 0;
        end else begin
            c_state         <= n_state;
            dhtio_reg       <= dhtio_next;
            tick_cnt_reg    <= tick_cnt_next;
            io_sel_reg      <= io_sel_next;
            bit_cnt_reg     <= bit_cnt_next;
            data_reg        <= data_next;
            humidity_reg    <= humidity_next;
            temperature_reg <= temperature_next;
        end
    end

    // next, output
    always @(*) begin
        n_state          = c_state;
        tick_cnt_next    = tick_cnt_reg;
        dhtio_next       = dhtio_reg;
        io_sel_next      = io_sel_reg;
        bit_cnt_next     = bit_cnt_reg;
        data_next        = data_reg;
        dht11_done       = 1'b0;
        dht11_valid      = 1'b0;
        humidity_next    = humidity_reg;
        temperature_next = temperature_reg;
        case (c_state)
            IDLE: begin
                io_sel_next = 1'b1;
                dhtio_next  = 1'b1;
                if (start) begin
                    tick_cnt_next = 0;
                    bit_cnt_next = 0;  // 비트 카운트 초기화
                    n_state = START;
                end
            end
            START: begin
                dhtio_next = 1'b0;
                if (tick_10us) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 1900) begin
                        tick_cnt_next = 0;
                        n_state = WAIT;
                    end
                end
            end
            WAIT: begin
                dhtio_next = 1'b1;
                if (tick_10us) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 3) begin
                        //for output to high-z
                        n_state = SYNC_L;
                        io_sel_next = 1'b0;
                    end
                end
            end
            SYNC_L: begin
                if (tick_10us) begin
                    if (dhtio == 1) begin
                        n_state = SYNC_H;
                    end
                end
            end
            SYNC_H: begin
                if (tick_10us) begin
                    if (dhtio == 0) begin
                        n_state = DATA_SYNC;
                    end
                end
            end
            DATA_SYNC: begin
                if (tick_10us) begin
                    if (dhtio == 1) begin
                        n_state = DATA_COLLECT;
                        tick_cnt_next = 0;
                    end
                end
            end
            DATA_COLLECT: begin
                if (tick_10us) begin
                    if (dhtio == 1) begin
                        tick_cnt_next = tick_cnt_reg + 1;
                    end else begin
                        data_next[39 - bit_cnt_reg] = (tick_cnt_reg > 4);   //40ns 보다 길면 1, 짧으면 0
                        bit_cnt_next = bit_cnt_reg + 1;
                        tick_cnt_next = 0;

                        if (bit_cnt_reg == 39)
                            n_state = STOP;  // 40비트 완료
                        else n_state = DATA_SYNC;
                    end
                end
            end
            STOP: begin
                dht11_done = 1'b1;
                if (tick_10us) begin
                    tick_cnt_next = tick_cnt_reg + 1;
                    if (tick_cnt_reg == 5) begin
                        // output mode
                        dhtio_next = 1'b1;
                        io_sel_next = 1'b1;
                        n_state = IDLE;
                    end
                end

                if (data_reg[39:32] + data_reg[31:24] + data_reg[23:16] + data_reg[15:8] == data_reg[7:0]) begin
                    dht11_valid = 1'b1; // 계산이 맞으면 유효 신호를 뿌림
                    humidity_next = data_reg[39:24];
                    temperature_next = data_reg[23:8];
                end
            end
        endcase
    end

endmodule


module tick_gen_10usec (
    input      clk,
    input      rst,
    output reg tick_10us
);
    parameter F_COUNT = 100_000_000 / 100_000;
    reg [$clog2(F_COUNT)-1:0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            tick_10us   <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
            if (counter_reg == F_COUNT - 1) begin
                counter_reg <= 0;
                tick_10us   <= 1;
            end else begin
                tick_10us <= 0;
            end
        end
    end

endmodule

module mux_2x1_dht11 (
    input         sel,
    input  [15:0] humidity,
    input  [15:0] temperature,
    output [15:0] o_mux_2x1
);
    //sel == 0 -> humidity, sel == 1 -> temperature
    assign o_mux_2x1 = sel ? temperature : humidity;

endmodule
