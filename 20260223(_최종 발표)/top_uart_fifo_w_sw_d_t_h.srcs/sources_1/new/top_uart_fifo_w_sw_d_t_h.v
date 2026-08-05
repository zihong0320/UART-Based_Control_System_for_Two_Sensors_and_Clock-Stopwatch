`timescale 1ns / 1ps

module top_uart_fifo_w_sw_d_t_h (
    input        clk,
    input        rst,
    input  [5:0] sw,
    input        btn_r,      //run_stop
    input        btn_l,      //clear
    input        btn_u,      //up
    input        btn_d,      //shift
    input        echo,
    input        rx,         //for top
    output       tx,         //for pc
    output       trigger,
    output [2:0] debug,
    output       valid,
    output [3:0] fnd_digit,
    output [7:0] fnd_data,
    inout        dhtio
);
    wire w_rx_done;
    wire [8:0] w_asc_num;
    wire [7:0] w_uart_rx_data;
    wire [3:0] w_ctrl_in;

    wire w_btn_r, w_btn_l, w_btn_u, w_btn_d;

    wire w_run_stop, w_clear, w_mode;
    wire [23:0] w_stopwatch_time, w_watch_time, w_final_time;
    wire w_up;
    wire w_start;
    wire [1:0] w_shift;

    wire w_tx_start, w_tx_busy;
    wire [7:0] w_tx_data;

    wire [8:0] w_distance;
    wire [15:0] w_humidity, w_temperature, w_final_t_h;

    wire w_fifo_rx_empty;

    btn_debounce U_BTN_DB_R (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_r),
        .o_btn(w_btn_r)
    );

    btn_debounce U_BTN_DB_L (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_l),
        .o_btn(w_btn_l)
    );

    btn_debounce U_BTN_DB_U (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_u),
        .o_btn(w_btn_u)
    );

    btn_debounce U_BTN_DB_D (
        .clk  (clk),
        .reset(rst),
        .i_btn(btn_d),
        .o_btn(w_btn_d)
    );

    uart_top U_UART_TOP (
        .clk(clk),
        .rst(rst),
        .uart_rx(rx),
        .fifo_tx_push(w_tx_start),
        .uart_tx_data(w_tx_data),
        .fifo_rx_pop(~w_fifo_rx_empty),  // 디코더가 데이터를 소모하면 Pop
        .fifo_tx_full(w_tx_busy),     // FIFO가 꽉 차면 Sender에게 busy 전달
        .fifo_rx_empty(w_fifo_rx_empty),
        .uart_tx(tx),
        .rx_done(w_rx_done),
        .uart_rx_data(w_uart_rx_data)
    );

    ascii_sender U_ASCII_SENDER (
        .clk(clk),
        .rst(rst),
        .final_time(w_final_time),  // [23:19] - hour, [18:13] - min, [12:7] - sec, [6:0] - msec 
        .distance(w_distance),
        .humidity(w_humidity),
        .temperature(w_temperature),
        .sw_mode({sw[5], sw[4], sw[1]}),  // 000 : stopwatch, 001 : watch, 010 : sr04, 011 : dht11_humid, 111 : dht_temperature
        .sw_sel(w_asc_num[8:4]),
        .tx_busy(w_tx_busy),
        .tx_start(w_tx_start),
        .tx_data(w_tx_data)
    );

    ascii_decoder U_ASCII_DECODER (
        .clk(clk),
        .rst(rst),
        .ascii(w_uart_rx_data),
        .done(w_rx_done),
        .num(w_asc_num)
    );

    or_gate U_OR_GATE_R (
        .asc_num(w_asc_num[0]),
        .btn_num(w_btn_r),
        .ctrl_in(w_ctrl_in[0])
    );

    or_gate U_OR_GATE_L (
        .asc_num(w_asc_num[1]),
        .btn_num(w_btn_l),
        .ctrl_in(w_ctrl_in[1])
    );

    or_gate U_OR_GATE_U (
        .asc_num(w_asc_num[2]),
        .btn_num(w_btn_u),
        .ctrl_in(w_ctrl_in[2])
    );

    or_gate U_OR_GATE_D (
        .asc_num(w_asc_num[3]),
        .btn_num(w_btn_d),
        .ctrl_in(w_ctrl_in[3])
    );

    stopwatch_ctrl_unit U_STOPWATCH_CTRL_UNIT (
        .clk(clk),
        .reset(rst),
        .i_mode(sw[0]),
        .i_run_stop(w_ctrl_in[0]),
        .i_clear(w_ctrl_in[1]),
        .o_mode(w_mode),
        .o_run_stop(w_run_stop),
        .o_clear(w_clear)
    );

    watch_ctrl_unit U_WATCH_CTRL_UNIT (
        .clk    (clk),
        .reset  (rst),
        .i_up   (w_ctrl_in[2]),  // btn_up
        .i_shift(w_ctrl_in[3]),  // 자릿수 이동
        .i_start(sw[3]),         // 1 : watch_run
        .o_up   (w_up),
        .o_shift(w_shift),
        .o_start(w_start)
    );

    stopwatch_datapath U_STOPWATCH_DATAPATH (
        .clk(clk),
        .reset(rst),
        .mode(w_mode),
        .clear(w_clear),
        .run_stop(w_run_stop),
        .msec(w_stopwatch_time[6:0]),  //7bit - 99
        .sec(w_stopwatch_time[12:7]),  //6bit - 59
        .min(w_stopwatch_time[18:13]),  //6bit - 59
        .hour(w_stopwatch_time[23:19])  //5bit - 23
    );

    watch_datapath U_WATCH_DATAPATH (
        .clk(clk),
        .reset(rst),
        .i_up(w_up),
        .i_shift(w_shift),
        .i_start(w_start),
        .msec(w_watch_time[6:0]),
        .sec(w_watch_time[12:7]),
        .min(w_watch_time[18:13]),
        .hour(w_watch_time[23:19])
    );

    mux_time_out U_TIME_OUT (
        .sel(sw[1]),  //sw[1]==1 : watch, sw[1]==0 : stopwatch 
        .i_sel0(w_stopwatch_time),
        .i_sel1(w_watch_time),
        .o_mux(w_final_time)
    );

    top_sr04 U_TOP_SR04 (
        .clk     (clk),
        .rst     (rst),
        .btn_r   (btn_r),      // 여기 수정 필요할 듯
        .echo    (echo),
        .trigger (trigger),
        .distance(w_distance)
    );

    top_dht11 U_TOP_DHT11 (
        .clk        (clk),
        .rst        (rst),
        .start      (btn_r),          // 여기 수정 필요할 듯..
        .humidity   (w_humidity),
        .temperature(w_temperature),
        .debug      (debug),
        .dht11_valid(valid),
        .dhtio      (dhtio)
    );

    mux_2x1_dht11 U_MUX_2X1_DHT11 (
        .sel        (sw[5]),          // sw[5] : dht11(t/h)
        .humidity   (w_humidity),
        .temperature(w_temperature),
        .o_mux_2x1  (w_final_t_h)
    );

    top_fnd_controller U_TOP_FND_CTRL (
        .clk(clk),
        .rst(rst),
        .sel({sw[4], sw[1]}),  // 00 : stopwatch, 01 : watch, 10 : sr04, 11 : dht11
        .sel_display(sw[2]),  //sw[1] : hour,min / min,sec
        .indata_w_sw(w_final_time),
        .indata_sr04(w_distance),
        .indata_dht11(w_final_t_h),
        .fnd_digit(fnd_digit),
        .fnd_data(fnd_data)
    );
endmodule
