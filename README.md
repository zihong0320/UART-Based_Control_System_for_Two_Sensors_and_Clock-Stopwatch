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
- 시계/스톱워치 설계
- UART, FIFO 설계


## 1. Introduction & Background
### 1.1 SR04


### 1.2 DHT11


### 1.3 UART


### 1.4 FIFO & Synchronizer


## 2. Hardware Architecture
### 2.1 Overall Structure

### 2.2 SR04

### 2.3 DHT11

### 2.4 Synchronizer

### 2.5 FIFO(Synchronous)


## 3. Result
### 3.1 Simulation
#### 3.1-1 SR04


#### 3.1-2 DHT11

### 3.2 Demo Video


## 4. TroubleShooting
