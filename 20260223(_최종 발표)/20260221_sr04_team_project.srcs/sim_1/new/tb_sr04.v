`timescale 1ns / 1ps

module tb_sr04();

    reg clk, rst, btn_r, echo;
    wire trigger;
    wire [8:0] distance;

    //btn_r - 80us delay를 부여해야함

    top_sr04 dut(
        .clk(clk),
        .rst(rst),
        .btn_r(btn_r),
        .echo(echo),
        .trigger(trigger),
        .distance(distance)
    );

    always #5 clk = ~clk;


    initial begin
        #0;
        clk = 0;
        rst = 1;
        btn_r = 0;
        echo = 0;

        #10;
        btn_r = 1;
        rst = 0;

        #90000;
        btn_r = 0;

        #10000;

        #50000;
        
        echo = 1;

        #580000;
        echo = 0;

        #1000;


        #10;
        $stop;
        
    end




endmodule
