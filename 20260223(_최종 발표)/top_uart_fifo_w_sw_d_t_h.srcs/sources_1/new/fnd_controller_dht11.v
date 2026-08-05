`timescale 1ns / 1ps

module fnd_controller_dht11 (
    input         clk,
    input         reset,
    input  [15:0] count,
    output [3:0]  fnd_digit,
    output [7:0]  fnd_data
);
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000, w_mux_4x1_out;
    wire [1:0] w_digit_sel;
    wire w_1khz;

    digit_splitter_dht11 U_DIGIT_SPL_DHT11 (
        .in_data   (count),
        .digit_1   (w_digit_1),    // 0~9 -> 4bit
        .digit_10  (w_digit_10),   // 0~9 -> 4bit
        .digit_100 (w_digit_100),  // 0~9 -> 4bit
        .digit_1000(w_digit_1000)  // 0~9 -> 4bit
    );

    clk_div U_CLK_DIV_DHT11 (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    counter_4 U_COUNTER_4_DHT11 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    decoder_2x4 U_DECODER_2x4_DHT11 (
        .digit_sel(w_digit_sel),
        .fnd_digit(fnd_digit)
    );

    mux_4x1 U_Mux_4x1_DHT11 (
        .sel(w_digit_sel),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000),
        .mux_out(w_mux_4x1_out)
    );

    bcd_sensor U_BCD_DHT11 (
        .bcd(w_mux_4x1_out),
        .fnd_data(fnd_data)
    );

endmodule

module digit_splitter_dht11 (
    input  [15:0] in_data,
    output [3:0] digit_1,    // 0~9 -> 4bit
    output [3:0] digit_10,   // 0~9 -> 4bit
    output [3:0] digit_100,  // 0~9 -> 4bit
    output [3:0] digit_1000  // 0~9 -> 4bit
);
    // assign digit_1    = in_data % 10;
    // assign digit_10   = (in_data/10) % 10;
    // assign digit_100  = (in_data/100) % 10;
    // assign digit_1000 = (in_data/1000) % 10;

    assign digit_1    = in_data[7:0] % 10;
    assign digit_10   = in_data[7:0] / 10;
    assign digit_100  = in_data[15:8] % 10;
    assign digit_1000 = in_data[15:8] / 10;

endmodule
