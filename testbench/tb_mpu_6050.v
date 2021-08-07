`define G_A_CONF_0         10'h022 // Full Scale Range: gyroscope - ± 250 °/s, accelerometer - ± 2g
`define G_A_CONF_1         10'h062 // Full Scale Range: gyroscope - ± 500 °/s, accelerometer - ± 4g 
`define G_A_CONF_2         10'h082 // Full Scale Range: gyroscope - ± 1000 °/s, accelerometer - ± 8g 
`define G_A_CONF_3         10'h0A2 // Full Scale Range: gyroscope - ± 2000 °/s, accelerometer - ± 16g
`define FIFO_EN            10'h0C7 // FIFO enable for temperature, gyroscope and accelerometer
`define ACCEL_MSR          10'h008 // accelerometer measurements
`define TMP_MSR            10'h009 // measurement temperature
`define GYRO_MSR           10'h00A // gyroscope measurements
`define USER_CTRL_EN_FIFO  10'h16C
`define USER_CTRL_DIS_FIFO 10'h1AC
`define FIFO_COUNT         10'h00E
`define CHECK              10'h00F // check WHO_AM_I
    
    
`timescale 10 ns/ 1 ns
module tb_mpu_6050;
    parameter FPGA_CLK             = 50_000_000; // FPGA frequency 50 MHz
    parameter I2C_CLK              = 400_000;    // I2C bus frequency 400 KHz     
    parameter ADDR_I2C_SZ          = 7;          // addr on I2C bus width
    parameter DATA_I2C_SZ          = 8;          // data on I2C bus width 
    parameter DATA_ROM_SZ          = 16;         // word width in ROM    
    parameter ADDR_ROM_SZ          = 5;          // addr width in ROM 
    parameter FL_SZ                = 2;          // command execution flag width
/*
    parameter ADDR_OPM_SZ          = 4;          // addr width in RAM 
    parameter DATA_OPM_SZ          = 16;         // word width in RAM
    parameter DATA_ALU             = 32;         // data ALU width
    parameter DATA_DIV             = 33;         // data div width 
*/    
// --------------------------------------------------------------------------     
    reg                     CLK;             // clock 50 MHz
    reg                     RST_n;           // asynchronous reset_n
    reg                     I_EN;            // enable Controller
    reg [ADDR_ROM_SZ*2-1:0] I_INSTR;         // command for MPU_6050  
    wire [DATA_ROM_SZ-1:0]  data_rom_a;      // word A in ROM
    wire [DATA_ROM_SZ-1:0]  data_rom_b;      // word B in ROM    
    wire [ADDR_ROM_SZ-1:0]  addr_rom_a_out;  // word A addr in ROM
    wire [ADDR_ROM_SZ-1:0]  addr_rom_b_out;  // word B addr in ROM  
    wire                    en_i2c;          // enable I2C bus  
    wire [ADDR_I2C_SZ-1:0]  addr_i2c;        // addr on I2C bus
    wire                    rw;              // RW I2C bus 
    wire [DATA_I2C_SZ-1:0]  data_wr_i2c;     // data for writing on I2C bus     
    wire                    IO_SCL;          // serial clock I2C bus 
    wire                    IO_SDA;          // serial data I2C bus    
    wire                    busy_i2c;        // master I2C busy signal
    wire [DATA_I2C_SZ-1:0]  data_rd_i2c;     // readed data from I2C bus
    wire [23:0]             rxd_buff;        // buffer of received data from MPU_6050 
/*    
    wire signed [DATA_OPM_SZ-1:0] t_buff;        // readed TEMP_OUT
    wire signed [DATA_OPM_SZ-1:0] accel_x_buff;  // readed ACCEL_XOUT
    wire signed [DATA_OPM_SZ-1:0] accel_y_buff;  // readed ACCEL_YOUT
    wire signed [DATA_OPM_SZ-1:0] accel_z_buff;  // readed ACCEL_ZOUT    
    wire signed [DATA_OPM_SZ-1:0] gyro_x_buff;   // readed GYRO_XOUT
    wire signed [DATA_OPM_SZ-1:0] gyro_y_buff;   // readed GYRO_YOUT
    wire signed [DATA_OPM_SZ-1:0] gyro_z_buff;   // readed GYRO_ZOUT
    wire [DATA_OPM_SZ-1:0]        fifo_cnt_buff; // current value of the FIFO counter
    wire                          we;            // RAM write enable signal
    wire [ADDR_OPM_SZ-1:0]        addr_opm;      // word addr in RAM (output) 
    wire [DATA_OPM_SZ-1:0]        data_opm;      // word by addr in RAM (output)
    wire [DATA_ALU-1:0]           srcA;          // srcA
    wire [DATA_ALU-1:0]           srcB;          // srcB    
    wire [DATA_ALU-1:0]           rsl_alu;       // result alu
    wire                          en_div;        // enable devision
    wire [DATA_DIV-1:0]           num;           // numerator
    wire [DATA_DIV-1:0]           den;           // denomerator     
    wire                          fn_div;        // end of division
    wire signed [DATA_DIV-1:0]    rsl_div;       // result division   
    wire [FL_SZ-1:0]              O_FL;          // command execution flag     
*/    
    wire [FL_SZ-1:0]        O_FL;            // instruction execution flag 
    wire                    O_BUSY;          // Busy controller
    wire                    O_ERR;           // error state of FSM
    wire [4:0]              O_CNT_RS_ERR;    // counter error state of FSM 
    wire                    O_ACK_FL;        // flag in case of error on the bus   
    wire [4:0]              O_CNT_RS_ACK_FL; // counter error ACK from MPU_6050
    reg                     en_sda_slv;      // enable signal to simulate sda from the slave
    reg                     sda_slv;         // sda from the slave
    integer                 k;  
    
// --------------------------------------------------------------------------     
    top_mpu_6050 dut
        (
         .CLK(CLK), 
         .RST_n(RST_n), 
         .I_EN(I_EN),
         .I_INSTR(I_INSTR),
         .O_ACK_FL(O_ACK_FL),
         .O_CNT_RS_ACK_FL(O_CNT_RS_ACK_FL),
         .O_ERR(O_ERR),
         .O_CNT_RS_ERR(O_CNT_RS_ERR),
         .O_BUSY(O_BUSY),
         .O_FL(O_FL),
         .IO_SCL(IO_SCL), 
         .IO_SDA(IO_SDA)
        );  

// --------------------------------------------------------------------------   
    assign IO_SDA = en_sda_slv ? sda_slv : 1'bz; 
    assign data_rd_i2c = dut.data_rd_i2c;
    assign busy_i2c = dut.busy_i2c;
    assign addr_i2c = dut.addr_i2c;
    assign rw = dut.rw;
    assign data_wr_i2c = dut.data_wr_i2c;
    assign en_i2c = dut.en_i2c;
    assign addr_rom_a_out = dut.addr_rom_a_out;
    assign addr_rom_b_out = dut.addr_rom_b_out;
    assign data_rom_a = dut.data_rom_a;
    assign data_rom_b = dut.data_rom_b;    
    assign rxd_buff = dut.rxd_buff;
/*    
    assign num = dut.num;
    assign den = dut.den;
    assign srcA = dut.srcA;
    assign srcB = dut.srcB;
    assign en_div = dut.en_div;
    assign fn_div = dut.fn_div;
    assign rsl_div = dut.rsl_div;
    assign we = dut.we;
    assign addr_opm = dut.addr_opm;
    assign data_opm = dut.data_opm;    
    assign rsl_alu = dut.rsl_alu;
    assign t_buff = dut.t_buff;
    assign accel_x_buff = dut.accel_x_buff;
    assign accel_y_buff = dut.accel_y_buff;
    assign accel_z_buff = dut.accel_z_buff;
    assign gyro_x_buff = dut.gyro_x_buff;
    assign gyro_y_buff = dut.gyro_y_buff;
    assign gyro_z_buff = dut.gyro_z_buff; 
    assign fifo_cnt_buff = dut.fifo_cnt_buff;
*/    

// --------------------------------------------------------------------------    
    initial begin
      CLK = 1'b1;
      RST_n = 1'b1;
      I_EN = 1'b0;
      en_sda_slv = 1'b0; sda_slv = 1'b1;
//    start reset
      #1; RST_n = 0;
//    stop reset
      #2; RST_n = 1;  
      
      I_EN = 1'b1;
//    reading accelerometer
      I_INSTR = `ACCEL_MSR;
      #2313; en_sda_slv = 1'b1; sda_slv = 1'b0; // ACK from the slave that received the command  
      #250; en_sda_slv = 1'b0; sda_slv = 1'b1;
      ack_data(1);
      ack_comm;
      repeat (3)
        begin
          slv_tr_byte(8'hF0);
          slv_tr_byte(8'hB0); // -3920     
        end  

//    G_A_CONF_0
      I_INSTR = `G_A_CONF_0;
      ack_comm;
      ack_data(3);

//    G_A_CONF_1
      I_INSTR = `G_A_CONF_1;
      ack_comm;
      ack_data(3);

//    G_A_CONF_2
      I_INSTR = `G_A_CONF_2;
      ack_comm;
      ack_data(3);

//    G_A_CONF_3
      I_INSTR = `G_A_CONF_3;
      ack_comm;
      ack_data(3);

//    FIFO Enable
      I_INSTR = `FIFO_EN;
      ack_comm;
      ack_data(2);

//    reading of temperature
      I_INSTR = `TMP_MSR;
      ack_comm;
      ack_data(1);
      ack_comm;
      slv_tr_byte(8'hF0);
      slv_tr_byte(8'hB0); // -3920  

//    reading gyroscope
      I_INSTR = `GYRO_MSR;
      ack_comm;
      ack_data(1);
      ack_comm;      
      repeat (3)
        begin
          slv_tr_byte(8'hF0);
          slv_tr_byte(8'hB0); // -3920     
        end 

//    User Control
      I_INSTR = `USER_CTRL_EN_FIFO;
      ack_comm;
      ack_data(2);

//    FIFO Disable
      I_INSTR = `USER_CTRL_DIS_FIFO;
      ack_comm;
      ack_data(2);

//    reading FIFO Count Registers
      I_INSTR = `FIFO_COUNT;
      ack_comm;
      ack_data(1);
      ack_comm;
      slv_tr_byte(8'hF0);
      slv_tr_byte(8'hB0); // -3920   

//    communication check (1)
      I_INSTR = `CHECK; 
      ack_comm;
      ack_data(1);
      ack_comm;
      slv_tr_byte(8'h68);
      
//    communication check (2)
      I_INSTR = `CHECK; 
      ack_comm;
      ack_data(1);
      ack_comm;
      slv_tr_byte(8'h69);      

//    waiting for instructions      
      I_EN = 1'b0;
      I_INSTR = 8'h0; 
    end   

// --------------------------------------------------------------------------    
    always #1 CLK = ~CLK;
 
// -------------------------------------------------------------------------- 
    initial begin
      // $dumpvars;
      #152000 $finish;
    end

// --------------------------------------------------------------------------     
    task automatic ack_comm; 
      begin
          #2750; en_sda_slv = 1'b1; sda_slv = 1'b0;
          #250; en_sda_slv = 1'b0; sda_slv = 1'b1;      
      end
    endtask

// -------------------------------------------------------------------------- 
    task automatic ack_data;
      input [3:0] num_acks;
      begin
        repeat(num_acks)
          begin
            #2000; en_sda_slv = 1'b1; sda_slv = 1'b0; 
            #250; en_sda_slv = 1'b0; sda_slv = 1'b1;
          end
      end
    endtask

// --------------------------------------------------------------------------        
    task automatic slv_tr_byte; 
      input [7:0] data;
      begin    
          en_sda_slv = 1'b1;
          for (k=7; k>=0; k=k-1)
            begin
              sda_slv = data[k];
              #250;
            end
          en_sda_slv = 1'b0; sda_slv = 1'b1;
          #250;
      end
    endtask  
    

endmodule  