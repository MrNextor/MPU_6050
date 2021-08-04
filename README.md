#### Description of instructions
Implemented two types of instructions:
- R type: reading data from a slave device;
- W type: writing data to a slave device.
The instruction is 32 bits in size:
- MSB 2 bytes: output O_DATA_ROM_A;
- LSB 2 bytes: output O_DATA_ROM_B.  
Description O_DATA_ROM_A:
- MSB byte:
    - bits[15:9]: slave address on the I2C bus;
    - bit[8]: R/W.
- LSB byte: slave register address.
Description O_DATA_ROM_B:
- For R type:
    - MSB byte: 8'h00;
    - LSB byte:
        - bits[8:4]: number of bytes read;
        - bits[3:0]: 4'h0.
- For W type:
    - MSB byte: data to write;
    - LSB byte:
        - bits[8:4]: 4'h2 (sets counter rising and falling edge i_busy = 2);
        - bits[3:0]: 4'h0.
##### Temperature Measurement
Register map: 4.18 Registers 65 and 66 (8'h41, 8'h42) - Temperature Measurement (TEMP_OUT_H and TEMP_OUT_L)
    Calculation not implemented:
    Temperature in degrees C = (TEMP_OUT Register Value as a signed quantity)/340 + 36.53
R type: I_INSTR: 8'h10
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: 4'h1;
    - I_ADDR_ROM_B: 4'h0.
- Output signals:
    - O_DATA_ROM_A: 16'hD1_41 (16'b110_1000_1_0100_0001);
    - O_DATA_ROM_B: 16'h00_20 (16'b0000_0000_0010_0000).
    
##### Communication check  - WHO_AM_I
Register map: 4.32 Register 117 (8'h75) - WHO_AM_I
R type: I_INSTR: 8'h32
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: 4'h3;
    - I_ADDR_ROM_B: 4'h2.
- Output signals:
    - O_DATA_ROM_A: 16'hD1_75 (16'b110_1000_1_0111_0101);
    - O_DATA_ROM_B: 16'h00_10 (16'b0000_0000_0001_0000).
    
##### Gyroscope Measurements
Register map: 4.19 Registers 67 to 72 (8'h43 to 8'h48) – Gyroscope Measurements (GYRO_XOUT_H, GYRO_XOUT_L, GYRO_YOUT_H, GYRO_YOUT_L, GYRO_ZOUT_H, and GYRO_ZOUT_L)
R type: I_INSTR: 8'h54
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: 4'h5;
    - I_ADDR_ROM_B: 4'h4.
- Output signals:
    - O_DATA_ROM_A: 16'hD1_43 (16'b110_1000_1_0100_0011);
    - O_DATA_ROM_B: 16'h00_60 (16'b0000_0000_0001_0000).
    
##### Accelerometer Measurements
Register map: 4.17 Registers 59 to 64 (8'h3B to 8'h40) – Accelerometer Measurements (ACCEL_XOUT_H, ACCEL_XOUT_L, ACCEL_YOUT_H, ACCEL_YOUT_L, ACCEL_ZOUT_H, and ACCEL_ZOUT_L)
R type: I_INSTR: 8'h76
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: 4'h7;
    - I_ADDR_ROM_B: 4'h6.
- Output signals:
    - O_DATA_ROM_A: 16'hD1_3B (16'b110_1000_1_0011_1011);
    - O_DATA_ROM_B: 16'h00_60 (16'b0000_0000_0001_0000).
    
#### FIFO Enable
Register map: 4.6 Register 35 (8'h23) – FIFO Enable (FIFO_EN)
FIFO enable for temperature, gyroscope and accelerometer.
Setting FIFO_EN:
- TEMP_FIFO_EN[7]: set 1;
- XG_FIFO_EN[6]: set 1;
- YG_FIFO_EN[5]: set 1;
- ZG_FIFO_EN[4]: set 1;
- ACCEL_FIFO_EN[3]: set 1;
- bits[2:0]: set 0.
W type : I_INSTR: 8'h98
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: 4'h9;
    - I_ADDR_ROM_B: 4'h8.
- Output signals:
    - O_DATA_ROM_A: 16'hD0_23 (16'b110_1000_0_0010_0011);
    - O_DATA_ROM_B: 16'hF8_20 (16'b1111_1000_0000_0000).