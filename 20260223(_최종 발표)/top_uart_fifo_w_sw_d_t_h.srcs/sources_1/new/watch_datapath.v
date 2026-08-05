`timescale 1ns / 1ps

module watch_datapath (
    input        clk,
    input        reset,
    input   i_up,
    input  [1:0] i_shift,
    input        i_start,
    output [6:0] msec,  // 0-99
    output [5:0] sec,   // 0-59
    output [5:0] min,   // 0-59
    output [4:0] hour   // 0-23
);
    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;
    wire [5:0] w_set_sec, w_set_min;
    wire [4:0] w_set_hour;
    wire w_load;

    watch_set U_WATCH_SET(
        .clk(clk),
        .reset(reset),
        .up(i_up),
        .shift(i_shift),
        .load(w_load),
        .set_sec(w_set_sec),
        .set_min(w_set_min),
        .set_hour(w_set_hour)
    );

    tick_counter #(
        .BIT_WIDTH(5),
        .TIMES(24)
    ) hour_counter (
        .clk (clk),
        .reset (reset),
        .i_tick    (w_hour_tick),
        .mode   (),
        .clear   (),
        .run_stop(i_start),
        .load(w_load),
        .value_setting(w_set_hour),
        .o_count (hour),
        .o_tick     ()
    );

    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) min_counter (
        .clk     (clk),
        .reset   (reset),
        .i_tick     (w_min_tick),
        .mode   (),
        .clear  (),
        .run_stop(i_start),
        .load(w_load),
        .value_setting(w_set_min),
        .o_count (min),
        .o_tick (w_hour_tick)
    );

    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) sec_counter (
        .clk     (clk),
        .reset   (reset),
        .i_tick     (w_sec_tick),
        .mode   (),
        .clear   (),
        .run_stop(i_start),
        .load(w_load),
        .value_setting(w_set_sec),
        .o_count (sec),
        .o_tick     (w_min_tick)
    );

    tick_counter #(
        .BIT_WIDTH(7),
        .TIMES(100)
    ) msec_counter (
        .clk  (clk),
        .reset  (reset),
        .i_tick (w_tick_100hz),
        .mode (),
        .clear  (),
        .run_stop(i_start),
        .load(),
        .value_setting(),
        .o_count (msec),
        .o_tick (w_sec_tick)
    );

    tick_gen_100hz U_TICK_GEN (
        .clk     (clk),
        .reset   (reset),
        .i_run_stop     (i_start),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule


module watch_set (
    input clk,
    input reset,
    input up,
    input [1:0] shift,
    output reg load,
    output reg [5:0] set_sec,
    output reg [5:0] set_min,
    output reg [4:0] set_hour
);
    reg up_r;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            set_sec <= 6'd0;
            set_min <= 6'd0;
            set_hour <= 5'd0;
            up_r <= 0;
            load <= 0;
        end
        else begin
            set_sec <= set_sec;
            set_min <= set_min;
            set_hour <= set_hour;
            up_r <= up;
            load <=0;
            case (shift)
                2'b00: begin
                    set_sec <= set_sec;
                    set_min <= set_min;
                    set_hour <= set_hour;
                    load <= 0;
                end
                2'b01: begin
                    if(up_r) begin
                        set_sec <= (set_sec == 59) ? 6'd0 : set_sec + 1; 
                        load <= 1;
                    end
                    else set_sec <= set_sec;
                end
                2'b10: begin
                    if(up_r) begin
                        set_min <= (set_min == 59) ? 6'd0 : set_min + 1;
                        load <= 1;
                    end
                    else set_min <= set_min;
                end
                2'b11: begin
                    if(up_r) begin
                        set_hour <= (set_hour == 23) ? 5'd0 : set_hour + 1; 
                        load <= 1;
                    end
                    else set_hour <= set_hour;
                end
            endcase
        end
    end

endmodule
