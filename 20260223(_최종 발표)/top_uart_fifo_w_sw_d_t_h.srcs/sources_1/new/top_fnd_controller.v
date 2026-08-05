`timescale 1ns / 1ps

module top_fnd_controller (
    input clk,
    input rst,
    input [1:0] sel,  //sel[0] : watch/stopwatch, sel[1] : dht11/sr04
    input sel_display,
    input [23:0] indata_w_sw,
    input [8:0] indata_sr04,
    input [15:0] indata_dht11,
    output reg [3:0] fnd_digit,
    output reg [7:0] fnd_data
);

    wire [3:0] w_fnd_digit_w_sw, w_fnd_digit_sr04, w_fnd_digit_dht11;
    wire [7:0] w_fnd_data_w_sw, w_fnd_data_sr04, w_fnd_data_dht11;

    fnd_controller_w_sw U_FND_CNTL_W_SW (
        .clk        (clk),
        .reset      (rst),
        .sel_display(sel_display),
        .fnd_in_data(indata_w_sw),
        .fnd_digit  (w_fnd_digit_w_sw),
        .fnd_data   (w_fnd_data_w_sw)
    );

    fnd_controller_sr04 U_FND_CNTL_SR04 (
        .clk(clk),
        .reset(rst),
        .count(indata_sr04),
        .fnd_digit(w_fnd_digit_sr04),
        .fnd_data(w_fnd_data_sr04)
    );

    fnd_controller_dht11 U_FND_CNTL_DHT11 (
        .clk(clk),
        .reset(rst),
        .count(indata_dht11),
        .fnd_digit(w_fnd_digit_dht11),
        .fnd_data(w_fnd_data_dht11)
    );

    always @(*) begin
        case (sel)
            2'b00: begin
                fnd_digit = w_fnd_digit_w_sw;
                fnd_data  = w_fnd_data_w_sw;
            end
            2'b01: begin
                fnd_digit = w_fnd_digit_w_sw;
                fnd_data  = w_fnd_data_w_sw;
            end
            2'b10: begin
                fnd_digit = w_fnd_digit_sr04;
                fnd_data  = w_fnd_data_sr04;
            end
            2'b11: begin
                fnd_digit = w_fnd_digit_dht11;
                fnd_data  = w_fnd_data_dht11;
            end
        endcase
    end

endmodule
