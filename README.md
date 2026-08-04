# UART-Based_Control_System_for_Two_Sensors_and_Clock-Stopwatch

UART 기반 센서 2종 및 시계/스톱워치 제어 시스템 설계 및 시뮬레이션


## 0. Summary
### 🎯 Overview
- UART(+FIFO) 기반 SR04(초음파센서)/DHT11(온습도센서) 및 시계/스톱워치 제어
- UART <-> FPGA 상호 통신
- 비동기 입력 신호로 인한 CDC 문제 해결


### 🛠️ 개발 환경 및 사용 기술
- Target Board: Basys3 (Xilinx Artix-7)
- Tools: Vivado, Vitis, VS Code
- Languages: Verilog HDL
- Protocol: Uart


### 👨‍💻 담당 역할
- 센서 2종(SR04/DHT11) Controller 설계
- UART, FIFO 설계


## 1. Introduction & Background
### 1.1 SR04
<img width="626" height="446" alt="image" src="https://github.com/user-attachments/assets/94ba0436-e62e-47ba-932e-2aef166ec6e4" />

<SR04 사진>

<img width="618" height="294" alt="image" src="https://github.com/user-attachments/assets/14fccb51-2be2-4946-903a-57ffb9ccaf52" />

<SR04 동작 원리>

- IDLE, START, WAIT, DISTANCE로 state로 나눔
  
- IDLE : start 신호 필요(다음 state로 넘어가기 위함)
- START : 10us 필요
- WAIT : 내부적으로 200us 이상 필요(8*40kHz), echo 신호 필요(다음 state로 넘어가기 위함)
- DISTANCE : 1cm 당 58us 필요, !echo 신호 필요(다음 state로 넘어가기 위함), 최대 측정거리 : **400cm**

### 1.2 DHT11


<img width="407" height="588" alt="image" src="https://github.com/user-attachments/assets/fa9e9b22-51c6-4b58-a740-01be0a37855d" />

<DHT11 사진>

<img width="1314" height="482" alt="image" src="https://github.com/user-attachments/assets/cd741dbf-e071-4737-81b4-849e9f9fcba1" />

<DHT11 동작 원리>

- IDLE, START, WAIT, DISTANCE로 state로 나눔
  
- IDLE : start 신호 필요(다음 state로 넘어가기 위함)
- START : 1900ms 필요
- WAIT : 20 ~ 40us(30us로 지정)
- SYNC_L : dhtio가 0 -> 1 변경(다음 state로 넘어가기 위함)
- SYNC_H : dhtio가 1 -> 0 변경
- DATA_SYNC : dhtio가 0 -> 1 변경
- DATA_COLLECT : **40 bit**  필요, data_next[39-bit_cnt_reg] = (tick_cnt_reg > 4);
- STOP : 50us 필요, io_sel이 1 - > 0 변경 (FPGA tx)

### 1.3 UART
- Serial 통신?
- 설명 추가 필요..


### 1.4 FIFO & Synchronizer
- FIFO(Synchronous)
데이터 안정적 송신?
설명 추가 필요..

- FIFO(Asynchronous)
비동기 입력?, CDC 환경?, Metastability
설명 추가 필요..


- Synchronizer
비동기 입력?, CDC 환경?, Metastability
설명 추가 필요..


## 2. Hardware Architecture
### 2.1 Overall Structure

### 2.2 SR04

<img width="1587" height="715" alt="image" src="https://github.com/user-attachments/assets/84fa2dcb-67f7-4b1f-b2c4-8701dc6c558b" />

<SR04 테스트를 위한 Block Diagram>


<img width="1526" height="463" alt="image" src="https://github.com/user-attachments/assets/ff015416-68b6-4992-86a8-535d2a832604" />

<SR04 controller FSM>


<img width="849" height="877" alt="image" src="https://github.com/user-attachments/assets/02ae2274-1be3-48da-94c5-96ff5f0239ea" />

<SR04 controller ASM>

### 2.3 DHT11

<img width="1012" height="426" alt="image" src="https://github.com/user-attachments/assets/876ca480-a501-45a7-8614-f86472239cd8" />

<DHT11 테스트를 위한 Block Diagram>
- inout 포트 사용

<img width="1066" height="434" alt="image" src="https://github.com/user-attachments/assets/0cd0c543-17df-418e-9b99-718c971a5761" />


<DHT11 controller FSM>


<img width="1655" height="971" alt="image" src="https://github.com/user-attachments/assets/8f96213c-d507-4d1f-8f5b-5b9f4ad2749c" />


<DHT11 controller ASM>


<img width="912" height="527" alt="image" src="https://github.com/user-attachments/assets/d1f54f74-8fc4-4cbc-bcdc-ac560089be1f" />

<Check Sum>
- Check sum? 이 맞는 경우에만 humidity와 temperature 출력

### 2.4 Synchronizer

<img width="462" height="471" alt="image" src="https://github.com/user-attachments/assets/fce35d2b-60ed-47bc-8ede-40a6ddbf55c1" />

<Echo Synchronizer 코드>

<img width="866" height="484" alt="image" src="https://github.com/user-attachments/assets/04d884e1-9e94-49db-a9da-354802ff49aa" />

<Synchronzier 시뮬레이션>

- F/F 2개 적용된 것을 확인할 수 있음

### 2.5 FIFO(Synchronous)

<img width="1099" height="887" alt="image" src="https://github.com/user-attachments/assets/20250f93-ba88-495a-87b9-41acc1214c87" />

<FIFO Blockdiagram>

## 3. Result
### 3.1 Simulation
#### 3.1-1 SR04
SR04 testbench 시나리오
1. 초기화
2. btn_r 눌렀다고 가정
3. Btn_Debounce 출력을 가정하기 위한 90us 유지(최소 80us) 필요
4. 10us delay 부여(10us pulse trigger 신호가 끝날 때까지 유지)
5. 50us delay 부여(SR04가 자동으로 생성하는 Sonic Burst가 끝날 때까지 유지 - 25ns(40kHz) delay 필요)
6. echo를 10cm로 가정하여 580000ns 부여(1cm당 58us) -> #58000[us]*10

<img width="1474" height="730" alt="image" src="https://github.com/user-attachments/assets/1e9cb3ce-5083-4db3-9343-7d108e2db795" />

<START state 확인>
- trigger가 10us pulse임을 확인
- trig_cnt가 0 ~ 9까지 증가 확인


<img width="1668" height="668" alt="image" src="https://github.com/user-attachments/assets/7603c59f-913d-4a2b-b5da-b4be6d074511" />
- echo 신호에 맞춰 state 변경 확인
- echo_cnt가 0 ~ 57까지 증가 확인

<img width="1668" height="591" alt="image" src="https://github.com/user-attachments/assets/877d3ed7-4119-4ad8-bd20-29495b932399" />

<img width="1639" height="594" alt="image" src="https://github.com/user-attachments/assets/7759be56-1ff8-4aa3-a1b3-a92378df0bc0" />

<DISTANCE state 확인>

#### 3.1-2 DHT11


### 3.2 Demo Video

https://github.com/user-attachments/assets/bf98f1e0-414b-43ff-b525-599eec56f87b






## 4. TroubleShooting
- SR04 설계시 비동기 입력 신호 echo에 Synchronizer를 적용해 CDC 문제를 해결할 수 있었음
