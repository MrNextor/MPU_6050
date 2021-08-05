### Description of instructions
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
- LSB byte: data to write.  
Description O_DATA_ROM_B:
- MSB byte: slave register address;
- LSB byte:
    - bits[7:4]: number of bytes to read/write;
    - bits[3:0]: 4'h0.
### Implemented instructions

#### Gyroscope and accelerometer configuration
W type.  
Register map:
1. 4.4 Register 27 (8'h1B) – Gyroscope Configuration (GYRO_CONFIG);
2. 4.5 Register 28 (8'h1C) – Accelerometer Configuration (ACCEL_CONFIG)

Implemented 4 configurations:
1. ***I_INSTR: 8'h12***. Full Scale Range: gyroscope - ± 250 °/s, accelerometer - ± 2g.  
    Signals instruction_memory.v:
    - Input signals:
        - I_ADDR_ROM_A: *4'h1*;
        - I_ADDR_ROM_B: *4'h2*.
    - Output signals:
        - O_DATA_ROM_A: *16'hD0_00 (16'b110_1000_0_0000_0000)*;
        - O_DATA_ROM_B: *16'h1B_20 (16'b0001_1011_0010_0000)*.
2. ***I_INSTR: 8'h32***. Full Scale Range: gyroscope - ± 500 °/s, accelerometer - ± 4g.  
    Signals instruction_memory.v:
    - Input signals:
        - I_ADDR_ROM_A: *4'h3*;
        - I_ADDR_ROM_B: *4'h2*.
    - Output signals:
        - O_DATA_ROM_A: *16'hD0_08 (16'b110_1000_0_0000_1000)*;
        - O_DATA_ROM_B: *16'h1B_20 (16'b0001_1011_0010_0000)*. 
3. ***I_INSTR: 8'h42***. Full Scale Range: gyroscope - ± 1000 °/s, accelerometer - ± 8g.  
    Signals instruction_memory.v:
    - Input signals:
        - I_ADDR_ROM_A: *4'h4*;
        - I_ADDR_ROM_B: *4'h2*.
    - Output signals:
        - O_DATA_ROM_A: *16'hD0_10 (16'b110_1000_0_0001_0000)*;
        - O_DATA_ROM_B: *16'h1B_20 (16'b0001_1011_0010_0000)*.   
4. ***I_INSTR: 8'h52***. Full Scale Range: gyroscope - ± 2000 °/s, accelerometer - ± 16g.  
    Signals instruction_memory.v:
    - Input signals:
        - I_ADDR_ROM_A: *4'h5*;
        - I_ADDR_ROM_B: *4'h2*.
    - Output signals:
        - O_DATA_ROM_A: *16'hD0_18 (16'b110_1000_0_0001_1000)*;
        - O_DATA_ROM_B: *16'h1B_20 (16'b0001_1011_0010_0000)*.
#### FIFO Enable
W type : ***I_INSTR: 8'h67***  
Register map: 4.6 Register 35 (8'h23) – FIFO Enable (FIFO_EN)  
FIFO enable for temperature, gyroscope and accelerometer.  
Setting FIFO_EN:
- *TEMP_FIFO_EN[7]*: set 1;
- *XG_FIFO_EN[6]*: set 1;
- *YG_FIFO_EN[5]*: set 1;
- *ZG_FIFO_EN[4]*: set 1;
- *ACCEL_FIFO_EN[3]*: set 1;
- *bits[2:0]*: set 0.  
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: *4'h6*;
    - I_ADDR_ROM_B: *4'h*7.
- Output signals:
    - O_DATA_ROM_A: *16'hD0_F8 (16'b110_1000_0_1111_1000)*;
    - O_DATA_ROM_B: *16'h23_10 (16'b0010_0011_0001_0000)*.
#### Accelerometer Measurements
R type: ***I_INSTR: 8'h08***  
Register map: 4.17 Registers 59 to 64 (8'h3B to 8'h40) – Accelerometer Measurements (ACCEL_XOUT_H, ACCEL_XOUT_L, ACCEL_YOUT_H, ACCEL_YOUT_L, ACCEL_ZOUT_H, and ACCEL_ZOUT_L)  
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: *4'h0*;
    - I_ADDR_ROM_B: *4'h8*.
- Output signals:
    - O_DATA_ROM_A: *16'hD1_00 (16'b110_1000_1_0000_0000)*;
    - O_DATA_ROM_B: *16'h3B_60 (16'b0011_0101_0110_0000)*. 
#### Temperature Measurement
R type: ***I_INSTR: 8'h09 ***  
Register map: 4.18 Registers 65 and 66 (8'h41, 8'h42) - Temperature Measurement (TEMP_OUT_H and TEMP_OUT_L)  
    Calculation not implemented:  
    Temperature in degrees C = (TEMP_OUT Register Value as a signed quantity)/340 + 36.53  
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: *4'h0*;
    - I_ADDR_ROM_B: *4'h9*.
- Output signals:
    - O_DATA_ROM_A: *16'hD1_00 (16'b110_1000_1_0000_0000)*;
    - O_DATA_ROM_B: *16'h41_20 (16'b0100_0001_0010_0000)*.    
#### Gyroscope Measurements
R type: ***I_INSTR: 8'h0A***  
Register map: 4.19 Registers 67 to 72 (8'h43 to 8'h48) – Gyroscope Measurements (GYRO_XOUT_H, GYRO_XOUT_L, GYRO_YOUT_H, GYRO_YOUT_L, GYRO_ZOUT_H, and GYRO_ZOUT_L)  
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: *4'h0*;
    - I_ADDR_ROM_B: *4'hA*.
- Output signals:
    - O_DATA_ROM_A: *16'hD1_00 (16'b110_1000_1_0000_0000)*;
    - O_DATA_ROM_B: *16'h43_60 (16'b0100_0011_0110_0000)*. 
#### User Control
W type  
Register map: 4.27 Register 106 (8'h6A) – User Control (USER_CTRL)
Setting USER_CTRL:
- *FIFO_EN[6]*: set 1 for enables FIFO op, 0 for disable FIFO op;
- *I2C_MST_EN[5], I2C_IF_DIS[4]*: set 0;
- *FIFO_RESET[2], I2C_MST_RESET[1], SIG_COND_RESET[0]*: set 0;
- *bits [7], [3]*: not user.
***I_INSTR: 8'hBC*** Enables FIFO operations.  
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: *4'hB*;
    - I_ADDR_ROM_B: *4'hC*.
- Output signals:
    - O_DATA_ROM_A: *16'hD0_40 (16'b110_1000_0_0100_0000)*;
    - O_DATA_ROM_B: *16'h6A_10 (16'b0110_1010_0001_0000)*.  
***I_INSTR: 8'hDC*** Disable FIFO operations.  
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: *4'hD*;
    - I_ADDR_ROM_B: *4'hC*.
- Output signals:
    - O_DATA_ROM_A: *16'hD0_04 (16'b110_1000_0_0000_0100)*;
    - O_DATA_ROM_B: *16'h6A_10 (16'b0110_1010_0001_0000)*    
#### FIFO Count Registers
R type: ***I_INSTR: 8'h0E***  
Register map: 4.30 Register 114 and 115 (8'h72 and 8'h73) – FIFO Count Registers (FIFO_COUNT_H and FIFO_COUNT_L)  
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: *4'h0*;
    - I_ADDR_ROM_B: *4'hE*.
- Output signals:
    - O_DATA_ROM_A: *16'hD1_00 (16'b110_1000_1_0000_0000)*;
    - O_DATA_ROM_B: *16'h72_20 (16'b0111_0010_0010_0000)*.
#### Communication check  - WHO_AM_I
R type: ***I_INSTR: 8'h0F***  
Register map: 4.32 Register 117 (8'h75) - WHO_AM_I  
Signals instruction_memory.v:
- Input signals:
    - I_ADDR_ROM_A: *4'h0*;
    - I_ADDR_ROM_B: *4'hF*.
- Output signals:
    - O_DATA_ROM_A: *16'hD1_00 (16'b110_1000_1_0000_0000)*;
    - O_DATA_ROM_B: *16'h75_10 (16'b0111_0101_0001_0000)*.