`timescale 1ns / 1ps

module stopwatch_datapath (
    input        clk,
    input        reset,
    input        mode,
    input        clear,
    input        run_stop,
    output [6:0] msec,      //0-99
    output [5:0] sec,       //0-59
    output [5:0] min,       //0-59
    output [4:0] hour       //0-23
);
    wire w_tick_100hz, w_sec_tick, w_min_tick, w_hour_tick;

    tick_counter #(
        .BIT_WIDTH(5), 
        .TIMES(24)
    ) hour_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_hour_tick),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .load(),
        .value_setting(),
        .o_count(hour),
        .o_tick()
    );

    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) min_counter (
        .clk   (clk),
        .reset  (reset),
        .i_tick (w_min_tick),
        .mode  (mode),
        .clear  (clear),
        .run_stop(run_stop),
        .load(),
        .value_setting(),
        .o_count (min),
        .o_tick (w_hour_tick)
    );

    tick_counter #(
        .BIT_WIDTH(6),
        .TIMES(60)
    ) sec_counter (
        .clk(clk),
        .reset(reset),
        .i_tick(w_sec_tick),
        .mode(mode),
        .clear(clear),
        .run_stop(run_stop),
        .load(),
        .value_setting(),
        .o_count(sec),
        .o_tick(w_min_tick)
    );

    tick_counter #(
        .BIT_WIDTH(7),
        .TIMES(100)
    ) msec_counter (
        .clk   (clk),
        .reset  (reset),
        .i_tick (w_tick_100hz),
        .mode (mode),
        .clear  (clear),
        .run_stop(run_stop),
        .load(),
        .value_setting(),
        .o_count (msec),
        .o_tick (w_sec_tick)
    );

    tick_gen_100hz U_TICK_GEN (
        .clk         (clk),
        .reset       (reset),
        .i_run_stop  (run_stop),
        .o_tick_100hz(w_tick_100hz)
    );

endmodule

module mux_time_out (
    input sel,
    input [23:0] i_sel0,
    input [23:0] i_sel1,
    output [23:0] o_mux
);
    //1 : i_sel1, 0:i_sle0
    assign o_mux = (sel) ? i_sel1 : i_sel0;

endmodule

// msec, sec, min, hour
// tick counter
    module tick_counter #(
        parameter BIT_WIDTH = 7,
        TIMES = 100
    ) (
        input                      clk,
        input                      reset,
        input                      i_tick,
        input                      mode,
        input                      clear,
        input                      run_stop,
        input                       load,    // up 신호에 맞춰 시간 up_setting 
        input      [BIT_WIDTH-1:0]  value_setting,
        output     [BIT_WIDTH-1:0] o_count,
        output reg                 o_tick
    );
        // counter reg
        reg [BIT_WIDTH-1:0] counter_reg, counter_next;

        assign o_count = counter_reg;

        // State reg SL
        always @(posedge clk, posedge reset) begin
            if (reset || clear) begin
                counter_reg <= 0;
            end
            else if (load) begin
                counter_reg <= value_setting;
            end
            else begin
                counter_reg <= counter_next;
            end
        end

        //next CL
        always @(*) begin
            counter_next = counter_reg;
            o_tick = 1'b0;
            if (i_tick && run_stop) begin
                if (mode) begin
                    //down
                    if (counter_reg == 0) begin
                        counter_next = TIMES - 1;
                        o_tick = 1'b1;
                    end else begin
                        counter_next = counter_reg - 1;
                        o_tick = 1'b0;
                    end
                    end 
                else begin
                    //up
                    if (counter_reg == (TIMES - 1)) begin
                        counter_next = 0;
                        o_tick = 1'b1;
                    end else begin
                        counter_next = counter_reg + 1;
                        o_tick = 1'b0;
                    end
                end
            end
        end

    endmodule

module tick_gen_100hz (
    input clk,
    input reset,
    input i_run_stop,
    output reg o_tick_100hz
);
    //parameter F_COUNT = 100_000_000 / 1_000_000;    //SIMULATION
    parameter F_COUNT = 100_000_000 / 100;        //FPGA
    reg [$clog2(F_COUNT)-1:0] r_counter;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_counter <= 0;
            o_tick_100hz <= 1'b0;
        end else begin
            if (i_run_stop) begin
                r_counter <= r_counter + 1;
                if (r_counter == F_COUNT - 1) begin
                    r_counter <= 0;
                    o_tick_100hz <= 1'b1;
                end else begin
                    o_tick_100hz <= 1'b0;
                end
            end
        end
    end
endmodule

