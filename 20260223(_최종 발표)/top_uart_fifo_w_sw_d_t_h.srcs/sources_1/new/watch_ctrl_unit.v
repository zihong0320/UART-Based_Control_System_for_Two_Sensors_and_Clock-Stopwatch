`timescale 1ns / 1ps

module  watch_ctrl_unit (
    input        clk,
    input        reset,
    input   i_up,        // btn_up, up[0]:초, up[1]:분, up[2]:시 
    //input        down,      // btn_down
    input        i_shift,     // 자릿수 이동
    input        i_start,      // 1 : watch_run

    output reg   o_up,
    output reg [1:0]  o_shift,  
    output reg   o_start    
);
    localparam IDLE = 3'b000, SEC = 3'b001, MIN = 3'b010, HOUR = 3'b011, UP_SEC = 3'b100, UP_MIN = 3'b101, UP_HOUR = 3'b110, START = 3'b111;
  
    // reg variable
    reg [2:0] current_st, next_st;

    // state register SL
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            current_st <= IDLE;
        end 
        else begin
            current_st <= next_st;
        end
    end

    //next CL
    always @(*) begin
        next_st = current_st;
        case (current_st)
            IDLE : next_st = i_shift ? SEC : (i_start ? START : IDLE); 
            SEC : next_st = i_shift ? MIN : (i_start ? START : (i_up ? UP_SEC : SEC)); //IDLE or SEC
            MIN : next_st = i_shift ? HOUR : (i_start ? START : (i_up ? UP_MIN : MIN)); //IDLE or MIN
            HOUR : next_st = i_shift ? SEC : (i_start ? START : (i_up ? UP_HOUR : HOUR)); //IDLE or SEC
            UP_SEC : next_st = SEC; 
            UP_MIN : next_st = MIN;  
            UP_HOUR : next_st = HOUR;   
            START : next_st = i_start ? START : IDLE;
        endcase
    end

    //output CL
    always @(*) begin
        o_start = 1'b0;
        o_shift = 2'b00;
        o_up = 1'b0;
        case (current_st)
            IDLE : begin
                o_start = 1'b0;
                o_shift = 2'b00;
                o_up = 1'b0;
            end
            SEC : begin
                o_start = 1'b0;
                o_shift = 2'b01;
                o_up = 1'b0;
            end
            MIN : begin
                o_start = 1'b0;
                o_shift = 2'b10;
                o_up = 1'b0;
            end 
            HOUR : begin
                o_start = 1'b0;
                o_shift = 2'b11;
                o_up = 1'b0;
            end
            UP_SEC : begin
                o_start = 1'b0;
                o_shift = 2'b00;
                o_up = 1'b1;
            end
            UP_MIN : begin
                o_start = 1'b0;
                o_shift = 2'b00;
                o_up = 1'b1;
            end
            UP_HOUR : begin
                o_start = 1'b0;
                o_shift = 2'b00;
                o_up = 1'b1;
            end  
            START : begin
                o_start = 1'b1;
                o_shift = 2'b00;
                o_up = 1'b0;
            end
        endcase
    end
endmodule




