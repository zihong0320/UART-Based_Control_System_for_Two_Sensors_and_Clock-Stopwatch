`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        rst,
    input        uart_rx,
    input        fifo_tx_push,
    input  [7:0] uart_tx_data,
    input        fifo_rx_pop,
    //output       fifo_rx_full,
    output       fifo_rx_empty,
    output       fifo_tx_full,      
    output       uart_tx,
    output       rx_done,
    output [7:0] uart_rx_data
);
    wire w_b_tick;
    wire tx_done;

    wire [7:0] w_rx_data, w_rx_fifo_pop_data, w_tx_fifo_push_data, w_tx_fifo_pop_data;
    wire w_rx_done, w_tx_busy, w_tx_fifo_empty;


    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(~w_tx_fifo_empty),
        .b_tick(w_b_tick),
        .tx_data(w_tx_fifo_pop_data),
        .tx_busy(w_tx_busy),
        .tx_done(tx_done),
        .uart_tx(uart_tx)
    );

    fifo U_FIFO_TX(
        .clk(clk),
        .rst(rst),
        .push(fifo_tx_push),
        .pop(w_tx_done | (~w_tx_busy && ~w_tx_fifo_empty)),
        .push_data(w_tx_fifo_push_data),
        .pop_data(w_tx_fifo_pop_data),
        .full(fifo_tx_full),
        .empty(w_tx_fifo_empty)
    );

    fifo U_FIFO_RX(
        .clk(clk),
        .rst(rst),
        .push(w_rx_done),
        .pop(fifo_rx_pop),
        .push_data(w_rx_data),
        .pop_data(w_rx_fifo_pop_data),
        .full(),
        .empty(fifo_rx_empty)
    );

    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(uart_rx),
        .b_tick(w_b_tick),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

    baud_tick U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .b_tick(w_b_tick)
    );

endmodule

module ascii_sender (
    input clk,
    input rst,
    input [23:0] final_time,  // [23:19] - hour, [18:13] - min, [12:7] - sec, [6:0] - msec 
    input [8:0] distance,
    input [15:0] humidity,
    input [15:0] temperature,
    input [2:0] sw_mode,
    input [4:0] sw_sel,
    input tx_busy,
    output reg tx_start,
    output reg [7:0] tx_data
);
    parameter [1:0] IDLE = 2'b00;
    parameter [1:0] SEND = 2'b01;
    parameter [1:0] WAIT_TX = 2'b10;
    parameter [1:0] NEXT_STEP = 2'b11;  //busy

    reg [1:0] current_state, next_state;
    reg [4:0] char_idx_next, char_idx_reg;

    wire [3:0] hour_10, hour_1;
    wire [3:0] min_10, min_1;
    wire [3:0] sec_10, sec_1;
    wire [3:0] msec_10, msec_1;

    wire [3:0] dist_100, dist_10, dist_1;
    wire [3:0] h_int_10, h_int_1, h_dec_10, h_dec_1;
    wire [3:0] t_int_10, t_int_1, t_dec_10, t_dec_1;

    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_HOUR (
        .in_data(final_time[23:19]),
        .digit_1(hour_1),
        .digit_10(hour_10),
        .digit_100(),
        .digit_1000()
    );

    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_MIN (
        .in_data(final_time[18:13]),
        .digit_1(min_1),
        .digit_10(min_10),
        .digit_100(),
        .digit_1000()
    );

    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_SEC (
        .in_data(final_time[12:7]),
        .digit_1(sec_1),
        .digit_10(sec_10),
        .digit_100(),
        .digit_1000()
    );

    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_MSEC (
        .in_data(final_time[6:0]),
        .digit_1(msec_1),
        .digit_10(msec_10),
        .digit_100(),
        .digit_1000()
    );

    digit_splitter #(
        .BIT_WIDTH(9)
    ) U_DIST (
        .in_data(distance),
        .digit_1(dist_1),
        .digit_10(dist_10),
        .digit_100(dist_100),
        .digit_1000()
    );

    digit_splitter_dht11 U_HUMIDITY (
        .in_data(humidity),
        .digit_1(h_dec_1),
        .digit_10(h_dec_10),
        .digit_100(h_int_1),
        .digit_1000(h_int_10)
    );

    digit_splitter_dht11 U_TEMPERATURE (
        .in_data(temperature),
        .digit_1(t_dec_1),
        .digit_10(t_dec_10),
        .digit_100(t_int_1),
        .digit_1000(t_int_10)
    );

    //state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            current_state <= 0;
            char_idx_reg  <= 0;
        end else begin
            current_state <= next_state;
            char_idx_reg  <= char_idx_next;
        end
    end

    //next state CL
    always @(*) begin
        char_idx_next = char_idx_reg;
        next_state = current_state;
        case (current_state)
            IDLE: begin
                char_idx_next = 0;
                if (|sw_sel) next_state = SEND;
            end
            SEND: begin
                next_state = WAIT_TX;
            end
            WAIT_TX: begin
                if (!tx_busy) next_state = NEXT_STEP;
            end
            NEXT_STEP: begin
                if (char_idx_reg == 5'd16) begin
                    next_state = IDLE;
                end else begin
                    char_idx_next = char_idx_reg + 1;
                    next_state = SEND;
                end
            end
        endcase
    end

    //output CL
    always @(*) begin
        tx_start = (current_state == SEND); // SEND 상태에서만 Start 신호 발생
        tx_data = 8'h00;
        case (char_idx_reg)
            // 헤더 결정 (Watch vs Stopwatch)
            5'd0: begin
                if (sw_mode == 3'b000) tx_data = "S";
                else if (sw_mode == 3'b001) tx_data = "W";
                else if (sw_mode == 3'b010) tx_data = "U";
                else if (sw_mode == 3'b011) tx_data = "H";
                else if (sw_mode == 3'b111) tx_data = "T";
            end
            5'd1: begin
                if (sw_mode == 3'b000) tx_data = "T";
                else if (sw_mode == 3'b001) tx_data = "A";
                else if (sw_mode == 3'b010) tx_data = "L";
                else if (sw_mode == 3'b011) tx_data = "U";
                else if (sw_mode == 3'b111) tx_data = "E";
            end

            5'd2: begin
                if (sw_mode == 3'b000) tx_data = "O";
                else if (sw_mode == 3'b001) tx_data = "T";
                else if (sw_mode == 3'b010) tx_data = "T";
                else if (sw_mode == 3'b011) tx_data = "M";
                else if (sw_mode == 3'b111) tx_data = "M";
            end
            5'd3: begin
                if (sw_mode == 3'b000) tx_data = "P";
                else if (sw_mode == 3'b001) tx_data = "C";
                else if (sw_mode == 3'b010) tx_data = "R";
                else if (sw_mode == 3'b011) tx_data = "I";
                else if (sw_mode == 3'b111) tx_data = "P";
            end
            5'd4: begin
                if (sw_mode == 3'b000) tx_data = "W";
                else if (sw_mode == 3'b001) tx_data = "H";
                else if (sw_mode == 3'b010) tx_data = "A";
                else if (sw_mode == 3'b011) tx_data = "D";
                else if (sw_mode == 3'b111) tx_data = "E";
            end
            5'd5: tx_data = " ";
            // 시간 데이터 (ASCII 변환: 숫자에 0x30을 더함)
            5'd6: begin
                if (sw_mode == 3'b000 || sw_mode == 3'b001)
                    tx_data = {4'h3, hour_10};
                else if (sw_mode == 3'b010) tx_data = " ";
                else if (sw_mode == 3'b011) tx_data = {4'h3, h_int_10};
                else if (sw_mode == 3'b111) tx_data = {4'h3, t_int_10};
            end
            5'd7: begin
                if (sw_mode == 3'b000 || sw_mode == 3'b001)
                    tx_data = {4'h3, hour_1};
                else if (sw_mode == 3'b010) tx_data = {4'h3, dist_100};
                else if (sw_mode == 3'b011) tx_data = {4'h3, h_int_1};
                else if (sw_mode == 3'b111) tx_data = {4'h3, t_int_1};
            end
            5'd8: begin
                if (sw_mode == 3'b000 || sw_mode == 3'b001) tx_data = ":";
                else if (sw_mode == 3'b010) tx_data = {4'h3, dist_10};
                else if (sw_mode == 3'b011 || sw_mode == 3'b111) tx_data = ".";
            end
            5'd9: begin
                if (sw_mode == 3'b000 || sw_mode == 3'b001)
                    tx_data = {4'h3, min_10};
                else if (sw_mode == 3'b010) tx_data = {4'h3, dist_1};
                else if (sw_mode == 3'b011) tx_data = {4'h3, h_dec_10};
                else if (sw_mode == 3'b111) tx_data = {4'h3, t_dec_10};
            end
            5'd10: begin
                if (sw_mode == 3'b000 || sw_mode == 3'b001)
                    tx_data = {4'h3, min_1};
                else if (sw_mode == 3'b010) tx_data = "c";
                else if (sw_mode == 3'b011) tx_data = {4'h3, h_dec_1};
                else if (sw_mode == 3'b111) tx_data = {4'h3, t_dec_1};
            end
            5'd11: begin
                if (sw_mode == 3'b000 || sw_mode == 3'b001) tx_data = ":";
                else if (sw_mode == 3'b010) tx_data = "m";
                else if (sw_mode == 3'b011 || sw_mode == 3'b111) tx_data = " ";
            end
            5'd12: begin
                if (sw_mode == 3'b000 || sw_mode == 3'b001)
                    tx_data = {4'h3, sec_10};
                else if (sw_mode == 3'b010) tx_data = " ";
                else if (sw_mode == 3'b011 || sw_mode == 3'b111) tx_data = " ";
            end
            5'd13: begin
                if (sw_mode == 3'b000 || sw_mode == 3'b001)
                    tx_data = {4'h3, sec_1};
                else if (sw_mode == 3'b010) tx_data = " ";
                else if (sw_mode == 3'b011 || sw_mode == 3'b111) tx_data = " ";
            end
            5'd14: begin
                if (sw_mode == 3'b000 || sw_mode == 3'b001) tx_data = ":";
                else if (sw_mode == 3'b010) tx_data = " ";
                else if (sw_mode == 3'b011 || sw_mode == 3'b111) tx_data = " ";
            end
            5'd15: begin
                if (sw_mode == 3'b000 || sw_mode == 3'b001)
                    tx_data = {4'h3, msec_10};
                else if (sw_mode == 3'b010) tx_data = " ";
                else if (sw_mode == 3'b011 || sw_mode == 3'b111) tx_data = " ";
            end
            5'd16: begin
                if (sw_mode == 3'b000 || sw_mode == 3'b001)
                    tx_data = {4'h3, msec_1};
                else if (sw_mode == 3'b010) tx_data = " ";
                else if (sw_mode == 3'b011 || sw_mode == 3'b111) tx_data = " ";
            end
            default: tx_data = 8'h00;
        endcase
    end
endmodule


module ascii_decoder (
    input clk,
    input rst,
    input [7:0] ascii,
    input done,
    output reg [8:0] num
);
    parameter IDLE = 1'b0;
    parameter DECODE = 1'b1;

    reg current_state, next_state;

    // state register SL
    always @(posedge clk, posedge rst) begin
        if (rst) current_state <= IDLE;
        else current_state <= next_state;
    end

    // next CL
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE:   next_state = done ? DECODE : IDLE;
            DECODE: next_state = IDLE;
        endcase
    end

    // output CL
    always @(*) begin
        num = 9'd0;
        case (current_state)
            IDLE: num = 9'd0;
            DECODE: begin
                case (ascii)
                    8'h72: num[0] = 1'd1;  //r
                    8'h6c: num[1] = 1'd1;  //l
                    8'h75: num[2] = 1'd1;  //u
                    8'h64: num[3] = 1'd1;  //d

                    8'h53: num[4] = 1'd1;  // S(Stopwatch)
                    8'h57: num[5] = 1'd1;  // W(Watch)     
                    8'h55: num[6] = 1'd1;  // U(Ultrasonic wave) 
                    8'h48: num[7] = 1'd1;  // H(Humidity)  
                    8'h54: num[8] = 1'd1;  // T(Temperature)
                    default: begin
                        num = 9'd0;
                    end
                endcase
            end
        endcase
    end

endmodule

module or_gate (
    input  asc_num,
    input  btn_num,
    output ctrl_in
);
    assign ctrl_in = asc_num | btn_num;

endmodule


module uart_rx (
    input        clk,
    input        rst,
    input        rx,
    input        b_tick,
    output [7:0] rx_data,
    output       rx_done
);

    localparam IDLE = 2'd0;
    localparam START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;

    // state reg
    reg [1:0] c_state, n_state;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg done_reg, done_next;
    reg [7:0] buf_reg, buf_next;

    assign rx_data = buf_reg;
    assign rx_done = done_reg;

    //state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state        <= IDLE;
            b_tick_cnt_reg <= 5'd0;
            bit_cnt_reg    <= 3'd0;
            done_reg       <= 1'b0;
            buf_reg        <= 8'd0;
        end else begin
            c_state        <= n_state;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            done_reg       <= done_next;
            buf_reg        <= buf_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next = bit_cnt_reg;
        done_next = done_reg;
        buf_next = buf_reg;
        case (c_state)
            IDLE: begin
                b_tick_cnt_next = 5'd0;
                bit_cnt_next    = 3'd0;
                done_next       = 1'b0;
                if (b_tick && !rx) begin
                    buf_next = 8'd0;
                    n_state  = START;
                end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        n_state = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        buf_next = {rx, buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            n_state = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state   = IDLE;
                        done_next = 1'b1;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input        b_tick,
    input  [7:0] tx_data,
    output       tx_busy,
    output       tx_done,
    output       uart_tx
);

    localparam IDLE = 2'd0;
    localparam START = 2'd1;
    localparam DATA = 2'd2;
    localparam STOP = 2'd3;

    // state reg
    reg [1:0] c_state, n_state;
    reg tx_reg, tx_next;  //for output SL
    // bit_cnt
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    //baud_tick_counter
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    // busy, done
    reg busy_reg, busy_next, done_reg, done_next;
    // data_in_buf
    reg [7:0] data_in_buf_reg, data_in_buf_next;

    assign uart_tx = tx_reg;
    assign tx_busy = busy_reg;
    assign tx_done = done_reg;

    // state register SL
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state         <= IDLE;
            tx_reg          <= 1'b1;
            bit_cnt_reg     <= 4'd0;
            b_tick_cnt_reg  <= 4'd0;
            busy_reg        <= 0;
            done_reg        <= 0;
            data_in_buf_reg <= 8'd0;
        end else begin
            c_state         <= n_state;
            tx_reg          <= tx_next;
            bit_cnt_reg     <= bit_cnt_next;
            b_tick_cnt_reg  <= b_tick_cnt_next;
            busy_reg        <= busy_next;
            done_reg        <= done_next;
            data_in_buf_reg <= data_in_buf_next;
        end
    end

    //next CL
    always @(*) begin
        n_state          = c_state;
        tx_next          = tx_reg;
        bit_cnt_next     = bit_cnt_reg;
        b_tick_cnt_next  = b_tick_cnt_reg;
        busy_next        = busy_reg;
        done_next        = done_reg;
        data_in_buf_next = data_in_buf_reg;
        case (c_state)
            IDLE: begin
                tx_next = 1'b1;
                bit_cnt_next = 1'b0;
                b_tick_cnt_next = 4'h0;
                busy_next = 1'b0;
                done_next = 1'b0;
                if (tx_start) begin
                    n_state          = START;
                    busy_next        = 1'b1;
                    data_in_buf_next = tx_data;
                end
            end

            START: begin
                tx_next = 0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = DATA;
                        b_tick_cnt_next = 4'h0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_in_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            b_tick_cnt_next = 4'h0;
                            n_state = STOP;
                        end else begin
                            b_tick_cnt_next = 4'h0;
                            bit_cnt_next = bit_cnt_reg + 1;
                            data_in_buf_next = {1'b0, data_in_buf_reg[7:1]};
                            n_state = DATA;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        n_state = IDLE;
                        done_next = 1'b1;
                        b_tick_cnt_next = 4'h0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule


module baud_tick (
    input      clk,
    input      rst,
    output reg b_tick
);
    // 100MHz/9600*16 -> count 해야 할 값
    parameter BAUDRATE = (9600 * 16);
    parameter F_count = 100_000_000 / BAUDRATE;  // 651마다 count하면 됨

    // reg for counter
    reg [$clog2(F_count)-1 : 0] counter_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick <= 0;
        end else begin
            counter_reg <= counter_reg + 1'b1;
            b_tick <= 0;
            if (counter_reg == (F_count - 1)) begin
                counter_reg <= 0;
                b_tick <= 1'b1;
            end else begin
                b_tick <= 1'b0;
            end
        end
    end
endmodule
