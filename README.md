# 🎛️ UART-Based Control System for Two Sensors and Clock/Stopwatch

> **UART 및 FIFO 기반 센서 2종(SR04, DHT11)과 시계/스톱워치 제어 시스템 설계**  
> 비동기 외부 입력 신호 처리를 위한 2-Stage Synchronizer 구축 및 CDC(Clock Domain Crossing) 안정성 확보

---

## 📌 0. Summary

### 🎯 Overview
- **UART (+FIFO) 기반 제어 시스템 구축**: SR04(초음파 센서), DHT11(온습도 센서) 및 시계/스톱워치 통합 제어
- **FPGA ↔ PC 상호 통신**: UART 프로토콜 및 데이터 버퍼링용 FIFO 설계
- **CDC 문제 해결**: 외부 비동기 센서 신호 입력에 따른 메타스테빌리티(Metastability) 방지용 Synchronizer 구현

---

### 🛠️ 개발 환경 및 사용 기술

| Category | Details |
| :--- | :--- |
| **Target Board** | Xilinx Basys3 (Artix-7 FPGA) |
| **Development Tools** | Vivado, Vitis, VS Code |
| **Languages** | Verilog HDL |
| **Protocols & Arch** | UART, FIFO, FSM/ASM, 2-Stage Synchronizer |

---

### 👨‍💻 담당 역할
- 센서 2종(SR04 초음파, DHT11 온습도) Controller RTL 설계
- UART TX/RX 및 Synchronous FIFO 버퍼 설계

---

## 📚 1. Introduction & Background

### 1.1 SR04 Ultrasonic Sensor

<p align="center">
  <img width="45%" alt="SR04 Sensor" src="https://github.com/user-attachments/assets/94ba0436-e62e-47ba-932e-2aef166ec6e4" />
  <img width="50%" alt="SR04 Operation" src="https://github.com/user-attachments/assets/14fccb51-2be2-4946-903a-57ffb9ccaf52" />
</p>

* **FSM State Division**
  * **IDLE**: Start Trigger 신호 대기 상태
  * **START**: 최소 10us 이상의 Pulse Trigger 출력
  * **WAIT**: 센서 내부 8-Cycle Sonic Burst(40kHz) 발사 및 Echo High 전환 대기 (약 200us)
  * **DISTANCE**: Echo High 유지 시간 측정 (1cm 당 58us 소요, 최대 측정 거리 **400cm**)

---

### 1.2 DHT11 Temperature & Humidity Sensor

<p align="center">
  <img width="20%" alt="DHT11 Sensor" src="https://github.com/user-attachments/assets/fa9e9b22-51c6-4b58-a740-01be0a37855d" />
  <img width="65%" alt="DHT11 Operation" src="https://github.com/user-attachments/assets/cd741dbf-e071-4737-81b4-849e9f9fcba1" />
</p>

* **FSM State Division & Protocol**
  * **IDLE**: 명령 대기 상태
  * **START**: Master(FPGA)가 Data Line을 Low로 18ms(최소 18ms) 이상 유지하여 Start Signal 전송
  * **WAIT**: Master가 Bus를 High로 해제 후 Sensor 응답 대기 (20~40us)
  * **SYNC_L / SYNC_H**: DHT11의 Response Signal (Low 80us ➔ High 80us) 수신 및 동기화
  * **DATA_COLLECT**: 총 **40-bit** 데이터 수신 (`Humidity 16-bit` + `Temperature 16-bit` + `Checksum 8-bit`)
    * Bit '0': High 구간 약 26~28us
    * Bit '1': High 구간 약 70us (`tick_cnt_reg > 4` 조건으로 Bit '0'/'1' 판별)
  * **STOP**: 데이터 전송 완료 후 Bus release (Inout Port 제어)

---

### 1.3 UART Protocol
* **비동기 직렬 통신(Asynchronous Serial Communication)**: 별도의 클럭 라인 없이 설정된 Baud Rate(예: 9600, 115200 bps)에 맞춰 Start Bit, Data Bits(8-bit), Stop Bit 순서로 프레임을 전송
* **Over-sampling Mechanism**: Rx 단에서 안정적인 데이터 샘플링을 위해 Baud Rate의 16배속 Sampling Clock을 생성하여 Bit의 중앙 지점에서 데이터 판별

---

### 1.4 FIFO & Synchronizer

* **Synchronous FIFO**
  * 동일한 Clock Domain 환경에서 Tx와 Rx의 데이터 처리 속도 차이로 인한 데이터 손실을 방지하는 First-In, First-Out 구조의 데이터 버퍼
* **2-Stage Flip-Flop Synchronizer**
  * 외부 비동기 신호(Echo, 센서 입력 등)가 FPGA 내부 Clock Edge와 경합을 벌일 때 발생하는 **Metastability(메타스테빌리티)** 방지
  * 연속된 2개의 Flip-Flop을 거치게 하여 신호 안정화 시간(Setup/Hold Time)을 확보 및 안전한 Clock Domain 진입 지원

---

## ⚙️ 2. Hardware Architecture

### 2.1 SR04 Controller Design

| SR04 Test Architecture Diagram | SR04 Controller FSM |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/84fa2dcb-67f7-4b1f-b2c4-8701dc6c558b" width="100%"/> | <img src="https://github.com/user-attachments/assets/ff015416-68b6-4992-86a8-535d2a832604" width="100%"/> |

<p align="center">
  <img width="60%" alt="SR04 ASM" src="https://github.com/user-attachments/assets/02ae2274-1be3-48da-94c5-96ff5f0239ea" /><br>
  <b>[ SR04 Controller ASM Chart ]</b>
</p>

---

### 2.2 DHT11 Controller Design

| DHT11 Test Architecture Diagram | DHT11 Controller FSM |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/1012x426" src="https://github.com/user-attachments/assets/876ca480-a501-45a7-8614-f86472239cd8" width="100%"/> | <img src="https://github.com/user-attachments/assets/0cd0c543-17df-418e-9b99-718c971a5761" width="100%"/> |

<p align="center">
  <img width="70%" alt="DHT11 ASM" src="https://github.com/user-attachments/assets/8f96213c-d507-4d1f-8f5b-5b9f4ad2749c" /><br>
  <b>[ DHT11 Controller ASM Chart ]</b>
</p>

* **Inout Port Control & Checksum Verification**
  <p align="center">
    <img width="55%" alt="Check Sum Validation" src="https://github.com/user-attachments/assets/d1f54f74-8fc4-4cbc-bcdc-ac560089be1f" />
  </p>

  * `High-Impedance (3-state)` 제어를 통한 단일 Tri-state Data Line 양방향 통신 구현
  * 수신된 40-bit 데이터 중 `Humidity[15:8] + Humidity[7:0] + Temp[15:8] + Temp[7:0] == Checksum[7:0]` 검증 성공 시에만 출력 레지스터 갱신

---

### 2.3 Synchronizer & FIFO Architecture

| Echo Synchronizer Code | Synchronizer Waveform |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/fce35d2b-60ed-47bc-8ede-40a6ddbf55c1" width="100%"/> | <img src="https://github.com/user-attachments/assets/04d884e1-9e94-49db-a9da-354802ff49aa" width="100%"/> |

* 2-Stage Flip-Flop 적용으로 외부 비동기 Echo 신호의 안전한 Synchronous domain 이전 확인

<p align="center">
  <img width="60%" alt="FIFO Block Diagram" src="https://github.com/user-attachments/assets/20250f93-ba88-495a-87b9-41acc1214c87" /><br>
  <b>[ Synchronous FIFO Block Diagram ]</b>
</p>

---

## 📈 3. Result & Simulation

### 3.1 SR04 Simulation Analysis

* **Testbench Scenario**
  1. System Reset 및 초기화
  2. `btn_r` Push Signal 인가 (Button Debounce 처리 조건 90us 유지)
  3. 10us Trigger Pulse 발생 확인 (`trig_cnt` 0 ➔ 9 증가)
  4. Sonic Burst 발사 기한 (약 50us delay) 모사
  5. Distance 10cm 입력을 모사하기 위해 Echo High 구간을 **580us** 로 설정 (`58us * 10cm`)

<p align="center">
  <img width="85%" alt="START State Waveform" src="https://github.com/user-attachments/assets/1e9cb3ce-5083-4db3-9343-7d108e2db795" /><br>
  <b>[ Trigger Pulse (10us) 및 START State 검증 ]</b>
</p>

<p align="center">
  <img width="85%" alt="WAIT & DISTANCE Waveform" src="https://github.com/user-attachments/assets/7603c59f-913d-4a2b-b5da-b4be6d074511" /><br>
  <b>[ Echo Signal 에 따른 State Transition 및 Count 검증 ]</b>
</p>

| DISTANCE State Capture 1 | DISTANCE State Capture 2 |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/877d3ed7-4119-4ad8-bd20-29495b932399" width="100%"/> | <img src="https://github.com/user-attachments/assets/7759be56-1ff8-4aa3-a1b3-a92378df0bc0" width="100%"/> |

---

### 🎬 3.2 Demo Video

https://github.com/user-attachments/assets/bf98f1e0-414b-43ff-b525-599eec56f87b

* **시연 내용**: UART 통신을 통한 SR04/DHT11 센서 데이터 및 시계/스톱워치 모드 실시간 제어 동작 검증

---

## 🚨 4. TroubleShooting

### 🚨 SR04 비동기 Echo 신호 입력을 통한 FSM 동작 불안정 및 메타스테빌리티 현상

* **문제 상황 (Problem)**
  * 외부 초음파 센서(SR04)에서 반환되는 Echo 신호는 FPGA 내부 시스템 클럭과 동기화되지 않은 **비동기(Asynchronous) 신호**임.
  * 내부 FSM이 Echo 신호의 Rising/Falling Edge를 직접 샘플링할 때 Setup/Hold Time Violation으로 인한 메타스테빌리티(Metastability)가 발생하여 FSM State가 오작동하는 현상 관측.

* **원인 분석 (Root Cause)**
  * 외부 입력 신호가 FPGA 내부 클럭의 Setup/Hold 창 내부에서 변경될 경우, 래치(Latch) 출력 값이 0 또는 1로 빠르게 확정되지 않고 불확정 전위 상태(Metastable State)에 머무르게 됨.

* **문제 해결 (Solution)**
  * Echo 신호 입력 단에 **2-Stage Flip-Flop Synchronizer**를 추가 적용함.
  * 첫 번째 Flip-Flop에서 발생할 수 있는 메타스테빌리티가 두 번째 Flip-Flop으로 전달되기 전 안정화(Settling)될 수 있는 1 Clock Cycle의 시간적 유예를 확보함.

* **고찰 (Retrospective)**
  * 물리적인 외부 센서와의 인터페이스 시 CDC(Clock Domain Crossing) 및 비동기 입력 신호 처리가 하드웨어 안정성에 미치는 결정적인 영향을 확인하였으며, 모든 외부 입력 신호에 대해 Synchronizer 적용.
