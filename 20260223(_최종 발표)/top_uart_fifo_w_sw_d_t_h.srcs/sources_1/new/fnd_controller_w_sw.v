`timescale 1ns / 1ps

module fnd_controller_w_sw (
    input clk,
    input reset,
    input sel_display,
    input [23:0] fnd_in_data,
    output [3:0] fnd_digit,
    output [7:0] fnd_data
);

    wire [3:0] w_digit_msec, w_digit_msec_10;
    wire [3:0] w_digit_sec, w_digit_sec_10;
    wire [3:0] w_digit_min, w_digit_min_10;
    wire [3:0] w_digit_hour, w_digit_hour_10;
    wire [3:0] w_mux_hour_min_out, w_mux_sec_msec_out;
    wire [3:0] w_mux_2x1_out;
    wire [2:0] w_digit_sel;
    wire w_1khz;
    wire w_dot_onoff;

    digit_splitter #(
        .BIT_WIDTH(5)
    ) U_HOUR_DS (
        .in_data (fnd_in_data[23:19]),
        .digit_1 (w_digit_hour),
        .digit_10(w_digit_hour_10),
        .digit_100(),  
        .digit_1000()
    );

    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_MIN_DS (
        .in_data (fnd_in_data[18:13]),
        .digit_1 (w_digit_min),
        .digit_10(w_digit_min_10),
        .digit_100(),  
        .digit_1000()
    );

    digit_splitter #(
        .BIT_WIDTH(6)
    ) U_SEC_DS (
        .in_data (fnd_in_data[12:7]),
        .digit_1 (w_digit_sec),
        .digit_10(w_digit_sec_10),
        .digit_100(),  
        .digit_1000()
    );

    digit_splitter #(
        .BIT_WIDTH(7)
    ) U_MSEC_DS (
        .in_data (fnd_in_data[6:0]),
        .digit_1 (w_digit_msec),
        .digit_10(w_digit_msec_10),
        .digit_100(),  
        .digit_1000()
    );

    dot_onoff_comp U_DOT_COMP (
        .msec(fnd_in_data[6:0]),
        .dot_onoff(w_dot_onoff)
    );

    mux_8x1 U_MUX_HOUR_MIN (
        .sel(w_digit_sel),
        .digit_1(w_digit_min),
        .digit_10(w_digit_min_10),
        .digit_100(w_digit_hour),
        .digit_1000(w_digit_hour_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_hour_min_out)
    );

    mux_8x1 U_MUX_SEC_MSEC (
        .sel(w_digit_sel),
        .digit_1(w_digit_msec),
        .digit_10(w_digit_msec_10),
        .digit_100(w_digit_sec),
        .digit_1000(w_digit_sec_10),
        .digit_dot_1(4'hf),
        .digit_dot_10(4'hf),
        .digit_dot_100({3'b111, w_dot_onoff}),
        .digit_dot_1000(4'hf),
        .mux_out(w_mux_sec_msec_out)
    );

    mux_2x1_w_sw U_MUX_2x1_W_SW (
        .sel(sel_display),
        .i_sel0(w_mux_sec_msec_out),
        .i_sel1(w_mux_hour_min_out),
        .o_mux(w_mux_2x1_out)
    );

    clk_div U_CLK_DIV_W_SW (
        .clk(clk),
        .reset(reset),
        .o_1khz(w_1khz)
    );

    counter_8 U_COUNTER_8 (
        .clk(w_1khz),
        .reset(reset),
        .digit_sel(w_digit_sel)
    );

    decoder_2x4 U_DECODER_2x4_W_SW (
        .digit_sel(w_digit_sel[1:0]), //3bit 중 아래쪽만 사용
        .fnd_digit(fnd_digit)
    );

    bcd_w_sw U_BCD_W_SW (
        .bcd(w_mux_2x1_out),
        .fnd_data(fnd_data)
    );

endmodule

module dot_onoff_comp (
    input [6:0] msec,
    output dot_onoff
);
    assign dot_onoff = (msec < 50);

endmodule

module mux_2x1_w_sw (
    input sel,
    input [3:0] i_sel0,
    input [3:0] i_sel1,
    output [3:0] o_mux
);
    //1 : i_sel1, 0:i_sle0
    assign o_mux = (sel) ? i_sel1 : i_sel0;

endmodule

module clk_div (
    input   clk,
    input   reset,
    output reg o_1khz
);

    reg [16:0] counter_r; //[16:0] = [$clog2(100_000):0] : 10만에 필요한 비트수 자동 입력되는 기능

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            counter_r <= 0; 
            o_1khz <= 1'b0;
        end else begin
            if (counter_r == 99_999) begin
                counter_r <= 0;
                o_1khz <= 1'b1;
            end else begin
                counter_r <= counter_r + 1;
                o_1khz <= 1'b0;
            end
        end
    end

endmodule

module counter_8 (
    input   clk,
    input   reset,
    output [2:0] digit_sel
);

    reg [2:0] counter_r;

    assign digit_sel = counter_r;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            // init counter_r
            counter_r <= 0;
        end else begin
            counter_r <= counter_r + 1;
        end
    end

endmodule

module decoder_2x4 (
    input [1:0] digit_sel,
    output reg [3:0] fnd_digit
);

    always @(digit_sel) begin
        case (digit_sel)
            2'b00: fnd_digit = 4'b1110;
            2'b01: fnd_digit = 4'b1101;
            2'b10: fnd_digit = 4'b1011;
            2'b11: fnd_digit = 4'b0111;
        endcase
    end

endmodule


module mux_8x1 (
    input       [2:0] sel,
    input       [3:0] digit_1,
    input       [3:0] digit_10,
    input       [3:0] digit_100,
    input       [3:0] digit_1000,
    input       [3:0] digit_dot_1,
    input       [3:0] digit_dot_10,
    input       [3:0] digit_dot_100,
    input       [3:0] digit_dot_1000,
    output reg [3:0] mux_out
);

    always @(*) begin 
         case (sel)
            3'b000: mux_out = digit_1;
            3'b001: mux_out = digit_10;
            3'b010: mux_out = digit_100;
            3'b011: mux_out = digit_1000;
            3'b100: mux_out = digit_dot_1;
            3'b101: mux_out = digit_dot_10;
            3'b110: mux_out = digit_dot_100;
            3'b111: mux_out = digit_dot_1000;
        endcase
    end

endmodule

module digit_splitter #(
    parameter BIT_WIDTH = 7
) (
    input [BIT_WIDTH-1:0] in_data,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);

    assign digit_1  = in_data % 10;
    assign digit_10 = (in_data / 10) % 10;
    assign digit_100  = (in_data/100) % 10;
    assign digit_1000 = (in_data/1000) % 10;

endmodule

module bcd_w_sw (
    input [3:0] bcd,
    output reg [7:0] fnd_data 
);
    always @(bcd) begin
        case (bcd)
            4'd0: fnd_data = 8'hc0;
            4'd1: fnd_data = 8'hf9;
            4'd2: fnd_data = 8'ha4;
            4'd3: fnd_data = 8'hb0;
            4'd4: fnd_data = 8'h99;
            4'd5: fnd_data = 8'h92;
            4'd6: fnd_data = 8'h82;
            4'd7: fnd_data = 8'hf8;
            4'd8: fnd_data = 8'h80;
            4'd9: fnd_data = 8'h90;
            4'd10: fnd_data = 8'hff; //1111_1111
            4'd11: fnd_data = 8'hff;
            4'd12: fnd_data = 8'hff;
            4'd13: fnd_data = 8'hff;
            4'd14: fnd_data = 8'h7f; //0111_1111
            4'd15: fnd_data = 8'hff;
            default: fnd_data = 8'hff;
        endcase
    end
endmodule