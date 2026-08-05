`timescale 1ns / 1ps

module top_sr04 (
    input        clk,
    input        rst,
    input        btn_r,
    input        echo,
    output       trigger,
    output [8:0] distance
);
    wire w_echo, w_btn_r;
    wire w_tick_1Mhz;

    echo_synchronizer U_ECHO_SYNCHRONIZER(
        .clk(clk),
        .rst(rst),
        .i_echo(echo),
        .o_echo(w_echo)
    );

    btn_debounce U_BTN_DB_SR04_R (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_r),
        .o_btn(w_btn_r)
    );

    sr04_controller U_SR04_CTRL (
        .clk(clk),
        .rst(rst),
        .i_tick_1Mhz(w_tick_1Mhz),
        .start(w_btn_r),
        .echo(w_echo),
        .distance(distance),
        .trigger(trigger)
    );

    tick_gen_1Mhz U_TICK_GEN_1MHZ (
        .clk(clk),
        .rst(rst),
        .o_tick_1Mhz(w_tick_1Mhz)
    );

endmodule

module sr04_controller (
    input            clk,
    input            rst,
    input            i_tick_1Mhz,
    input            start,        //for trigger
    input            echo,
    output     [8:0] distance,     //400cm
    output reg       trigger       //10us tick
);
    localparam MAX_DISTANCE = 400;

    parameter IDLE = 2'd0;
    parameter START = 2'd1;
    parameter WAIT = 2'd2;
    parameter DISTANCE = 2'd3;

    reg [1:0] c_state, n_state;

    reg [3:0] trig_cnt_reg, trig_cnt_next;  //10us check
    reg [5:0] echo_cnt_reg, echo_cnt_next;  //58us check
    reg [8:0] dist_reg, dist_next;

    assign distance = dist_reg;

    //state register
    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state      <= IDLE;
            trig_cnt_reg <= 0;
            echo_cnt_reg <= 0;
            dist_reg     <= 0;
        end else begin
            c_state      <= n_state;
            trig_cnt_reg <= trig_cnt_next;
            echo_cnt_reg <= echo_cnt_next;
            dist_reg     <= dist_next;
        end
    end

    //next CL
    always @(*) begin
        n_state = c_state;
        case (c_state)
            IDLE: if (start) n_state = START;
            START: if (i_tick_1Mhz && trig_cnt_reg == 9) n_state = WAIT;
            WAIT: if (echo) n_state = DISTANCE;
            DISTANCE: if (!echo || dist_reg >= MAX_DISTANCE) n_state = IDLE;
        endcase
    end

    //output CL
    always @(*) begin
        trigger = 0;
        trig_cnt_next = trig_cnt_reg;
        echo_cnt_next = echo_cnt_reg;
        dist_next = dist_reg;
        case (c_state)
            IDLE: begin
                trig_cnt_next = 0;
                echo_cnt_next = 0;
                if (start) dist_next = 0;
            end
            START: begin
                trigger = 1;  // 10us 동안 High 유지
                if (i_tick_1Mhz) begin
                    if (trig_cnt_reg == 9) begin
                        trig_cnt_next = 0;
                    end else begin
                        trig_cnt_next = trig_cnt_reg + 1;
                    end
                end
            end
            WAIT: begin
                trig_cnt_next = 0;
                echo_cnt_next = 0;
            end
            DISTANCE: begin
                if (i_tick_1Mhz) begin
                    if (echo_cnt_reg == 57) begin  // 58us 마다
                        echo_cnt_next = 0;
                        dist_next = dist_reg + 1;  // 1cm 증가
                    end else begin
                        echo_cnt_next = echo_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module tick_gen_1Mhz (
    input clk,
    input rst,
    output reg o_tick_1Mhz     //1us
);
    parameter SIZE = 1_000_000;
    parameter F_COUNT = 100_000_000 / SIZE;

    reg [$clog2(F_COUNT)-1:0] counter;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter <= 0;
            o_tick_1Mhz <= 0;
        end else begin
            counter <= counter + 1;
            o_tick_1Mhz <= 0;
            if (counter == (F_COUNT - 1)) begin
                counter <= 0;
                o_tick_1Mhz <= 1;
            end else begin
                o_tick_1Mhz <= 0;
            end
        end
    end
endmodule

module echo_synchronizer (
    input  clk,
    input  rst,
    input  i_echo,
    output o_echo
);
    reg [1:0] echo_sync;
    always @(posedge clk) begin
        if(rst) begin
            echo_sync <= 2'd0;
        end
        else begin
            echo_sync <= {echo_sync[0], i_echo};  // 2단 동기화
        end
    end

    assign o_echo = echo_sync[1];

endmodule

