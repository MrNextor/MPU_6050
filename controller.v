// command MPU_6050
    `define CHECK     4'b0001 // check chip id MPU_6050
    `define TMP_MSR   4'b0010 // measurement temperature
    `define ACCEL_MSR 4'b0011 // accelerometer measurements
    `define GYRO_MSR  4'b0100 // gyroscope measurements    
    `define FIFO_EN   4'b0101 // FIFO Enable for temp, gyro and accel
    `define FIFO_CNT  4'b0110 // keep track of the number of samples currently in the FIFO buffer
    // `define READ_CC   4'b0001 // reading calibration coefficients
    // `define MSR_PRS0  4'b0010 // measurement pressure (OSS0)
    // `define MSR_PRS1  4'b0011 // measurement pressure (OSS1)
    // `define MSR_PRS2  4'b0100 // measurement pressure (OSS2)
    // `define MSR_PRS3  4'b0101 // measurement pressure (OSS3)
    // `define SOFT_RST  4'b0110 // soft reset MPU_6050


module controller
    #(parameter FPGA_CLK    = 50_000_000, // FPGA frequency 50 MHz
      parameter ADDR_I2C_SZ = 7,          // addr on I2C bus width
      parameter DATA_I2C_SZ = 8,          // data on I2C bus width
      parameter ADDR_ROM_SZ = 4,          // addr width in ROM 
      parameter DATA_ROM_SZ = 8,          // word width in ROM 
      parameter ADDR_OPM_SZ          = 4,                    // addr width in RAM 
      parameter DATA_OPM_SZ          = 16,             // word width in RAM      
      parameter RXD_SZ      = 24)         // buffer of received data from MPU_6050 (width)
    (CLK, RST_n, I_COMM, I_DATA_ROM, I_DATA_RD_I2C, I_BUSY,
     O_EN_I2C, O_ADDR_I2C, O_RW, O_DATA_WR_I2C, O_ADDR_ROM, O_FL, O_ERR, O_RXD_BUFF,
     t_buff, accel_x_buff, accel_y_buff, accel_z_buff, gyro_x_buff, gyro_y_buff, gyro_z_buff, fifo_cnt_buff);
   

    localparam WHO_AM_I          = 8'h68; // chip id MPU_6050 = 0x68
    localparam ADDR_FIFO_EN     = 8'h23; // addr reg FIFO_EN
    localparam WR_FIFO          = 8'hF8; // write to reg 8'h23 enable FIFO for temp, gyro and accel
    
    localparam CNT_RS_I_BUSY_SZ = 2;     // rising edge counter I_BUSY width
    localparam CNT_FL_I_BUSY_SZ = 5;     // falling edge counter I_BUSY width
    localparam FL_SZ            = 8;     // command execution flag width
//  addr reg MPU_6050
    localparam AD0_MPU_6050 = 7'h68; // addr MPU_6050 on I2C bus (if AD0 = 0)
    localparam AD1_MPU_6050 = 7'h69; // addr MPU_6050 on I2C bus (if AD0 = 1)


//  description states FSM
    localparam ST_SZ          = 15;                // number of states FSM
    localparam WT_COMM        = 15'b000000000001000; // waiting for a command for MPU_6050
    localparam RD_TMP_ST      = 15'b000000000010000; // start reading temperature
    localparam RD_TMP_FN      = 15'b000000000100000; // finish reading temperature
    localparam RD_ACCEL_ST    = 15'b000000001000000; // start reading accelerometer
    localparam RD_ACCEL_FN    = 15'b000000010000000; // finish reading accelerometer     
    localparam RD_GYRO_ST     = 15'b000000100000000; // start reading gyroscope
    localparam RD_GYRO_FN     = 15'b000001000000000; // finish reading gyroscope  
    localparam FIFO_EN        = 15'b000010000000000; // FIFO enable
    localparam RD_FIFO_CNT_ST = 15'b000100000000000; // start reading FIFO counter
    localparam RD_FIFO_CNT_FN = 15'b001000000000000; // finish reading FIFO counter
    localparam PING           = 15'b010000000000000; // start communication check, sensor returns value 0x55
    localparam PING_RD        = 15'b100000000000000; // reading chip id    
//  input signals
    input wire                     CLK;           // clock 50 MHz
    input wire                     RST_n;         // asynchronous reset_n
    input wire [ADDR_ROM_SZ-1:0]   I_COMM;        // command for MPU_6050  
    input wire [DATA_ROM_SZ-1:0]   I_DATA_ROM;    // word in ROM    
    input wire [DATA_I2C_SZ-1:0]   I_DATA_RD_I2C; // readed data from I2C bus
    input wire                     I_BUSY;        // master I2C busy signal
//  output signals
    output reg                   O_EN_I2C;      // start enable I2C bus   
    output reg [ADDR_I2C_SZ-1:0] O_ADDR_I2C;    // addr MPU_6050 on I2C bus
    output reg                   O_RW;          // RW I2C bus 
    output reg [DATA_I2C_SZ-1:0] O_DATA_WR_I2C; // data for writing on I2C bus 
    output reg [ADDR_ROM_SZ-1:0] O_ADDR_ROM;    // command for MPU_6050     
    output reg [FL_SZ-1:0]       O_FL;          // command execution flag     
    output reg                   O_ERR;         // chip id error (MPU_6050) or error state of FSM
    output reg [RXD_SZ-1:0]      O_RXD_BUFF;    // next buffer of received data from MPU_6050 
    
    output reg signed [DATA_OPM_SZ-1:0]     t_buff;         // readed TEMP_OUT
    output reg signed [DATA_OPM_SZ-1:0] accel_x_buff;   // readed ACCEL_XOUT
    output reg signed [DATA_OPM_SZ-1:0] accel_y_buff;   // readed ACCEL_YOUT
    output reg signed [DATA_OPM_SZ-1:0] accel_z_buff;   // readed ACCEL_ZOUT
    output reg signed [DATA_OPM_SZ-1:0] gyro_x_buff;   // readed GYRO_XOUT
    output reg signed [DATA_OPM_SZ-1:0] gyro_y_buff;   // readed GYRO_YOUT
    output reg signed [DATA_OPM_SZ-1:0] gyro_z_buff;   // readed GYRO_ZOUT   
    output reg [DATA_OPM_SZ-1:0] fifo_cnt_buff; // current value of the FIFO counter
//  internal signals
    reg [ST_SZ-1:0]            st;               // current state of FSM
    reg [ST_SZ-1:0]            nx_st;            // next state of FSM
    reg                        nx_o_en_i2c;      // next enable signal I2C bus
    reg [ADDR_I2C_SZ-1:0]      nx_o_addr_i2c;    // next addr on I2C bus
    reg                        nx_o_rw;          // next RW I2C bus     
    reg [DATA_I2C_SZ-1:0]      nx_o_data_wr_i2c; // next data for writing on I2C bus 
    reg                        pr_i_busy;        // previous I_BUSY
    reg                        cr_i_busy;        // current I_BUSY
    wire                       rs_i_busy;        // rising edge I_BUSY
    wire                       fl_i_busy;        // falling edge I_BUSY
    reg [CNT_RS_I_BUSY_SZ-1:0] cnt_rs_i_busy;    // rising edge counter I_BUSY
    reg [CNT_RS_I_BUSY_SZ-1:0] nx_cnt_rs_i_busy; // next rising edge counter I_BUSY  
    reg [CNT_FL_I_BUSY_SZ-1:0] cnt_fl_i_busy;    // falling edge counter I_BUSY
    reg [CNT_FL_I_BUSY_SZ-1:0] nx_cnt_fl_i_busy; // next falling edge counter I_BUSY
    reg [ADDR_ROM_SZ-1:0]      nx_o_addr_rom;    // next command for MPU_6050
    reg [ADDR_ROM_SZ-1:0]      comm_reg;         // latching I_COMM
    reg [ADDR_ROM_SZ-1:0]      nx_comm_reg;      // next latching I_COMM
    reg [FL_SZ-1:0]            nx_o_fl;          // next command execution flag 
    reg                        nx_o_err;         // chip id error (MPU_6050) or error state of FSM
    reg [RXD_SZ-1:0]           nx_o_rxd_buff;    // next buffer of received data from MPU_6050
    
    // reg signed [DATA_OPM_SZ-1:0] t_buff;           // readed TEMP_OUT
    reg signed [DATA_OPM_SZ-1:0] nx_t_buff;        // next readed TEMP_OUT
    // reg signed [DATA_OPM_SZ-1:0] accel_x_buff;   // readed ACCEL_XOUT
    reg signed [DATA_OPM_SZ-1:0] nx_accel_x_buff;   // next readed ACCEL_XOUT  
    // reg signed [DATA_OPM_SZ-1:0] accel_y_buff;   // readed ACCEL_YOUT
    reg signed [DATA_OPM_SZ-1:0] nx_accel_y_buff;   // next readed ACCEL_YOUT  
    // reg signed [DATA_OPM_SZ-1:0] accel_z_buff;   // readed ACCEL_ZOUT
    reg signed [DATA_OPM_SZ-1:0] nx_accel_z_buff;   // next readed ACCEL_ZOUT  

    // reg signed [DATA_OPM_SZ-1:0] gyro_x_buff;   // readed GYRO_XOUT
    reg signed [DATA_OPM_SZ-1:0] nx_gyro_x_buff;   // next readed GYRO_XOUT  
    // reg signed [DATA_OPM_SZ-1:0] gyro_y_buff;   // readed GYRO_YOUT
    reg signed [DATA_OPM_SZ-1:0] nx_gyro_y_buff;   // next readed GYRO_YOUT  
    // reg signed [DATA_OPM_SZ-1:0] gyro_z_buff;   // readed GYRO_ZOUT
    reg signed [DATA_OPM_SZ-1:0] nx_gyro_z_buff;   // next readed GYRO_ZOUT    
    // reg [DATA_OPM_SZ-1:0] fifo_cnt_buff; // current value of the FIFO counter
    reg [DATA_OPM_SZ-1:0] nx_fifo_cnt_buff; // current value of the FIFO counter    
    
//  determining of rissing edge and falling edge I_BUSY
    assign rs_i_busy =  cr_i_busy & !pr_i_busy;
    assign fl_i_busy = !cr_i_busy &  pr_i_busy; 

//  determining the next state of FSM and singals    
    always @(*) begin
      nx_st = st;
      nx_o_addr_i2c = O_ADDR_I2C;
      nx_o_rw = O_RW;
      nx_o_data_wr_i2c = O_DATA_WR_I2C;
      nx_o_en_i2c = O_EN_I2C;
      nx_o_addr_rom = O_ADDR_ROM;      
      nx_cnt_rs_i_busy = cnt_rs_i_busy;
      nx_cnt_fl_i_busy = cnt_fl_i_busy;
      nx_comm_reg = comm_reg;
      nx_o_fl = O_FL;
      nx_o_err = O_ERR;
      nx_o_rxd_buff = O_RXD_BUFF;
      nx_t_buff = t_buff;
      nx_accel_x_buff = accel_x_buff;
      nx_accel_y_buff = accel_y_buff;
      nx_accel_z_buff = accel_z_buff;
      nx_gyro_x_buff = gyro_x_buff;
      nx_gyro_y_buff = gyro_y_buff;
      nx_gyro_z_buff = gyro_z_buff;
      nx_fifo_cnt_buff = fifo_cnt_buff;
      case (st)   
          WT_COMM        : begin
                             nx_comm_reg = I_COMM; // latching I_COMM
                             case (I_COMM)
                                `CHECK     : begin
                                               nx_o_en_i2c = 1'b1;            // start of a transaction on the bus I2C
                                               nx_o_addr_i2c = AD0_MPU_6050;  // setting addr MPU_6050
                                               nx_o_rw = 1'b0;                // write
                                               nx_o_err = 1'b0;               // zero error
                                               nx_o_fl[0] = 1'b1;             // transaction execution flag
                                               nx_o_addr_rom = `CHECK;
                                               nx_st = PING;
                                             end
                                `TMP_MSR   : begin
                                               nx_o_en_i2c = 1'b1;            // start of a transaction on the bus I2C
                                               nx_o_addr_i2c = AD0_MPU_6050;  // setting addr MPU_6050
                                               nx_o_rw = 1'b0;                // write
                                               nx_o_err = 1'b0;               // zero error
                                               nx_o_fl[1] = 1'b1;             // transaction execution flag
                                               nx_o_addr_rom = `TMP_MSR;
                                               nx_st = RD_TMP_ST;
                                             end    
                                `ACCEL_MSR : begin
                                               nx_o_en_i2c = 1'b1;            // start of a transaction on the bus I2C
                                               nx_o_addr_i2c = AD0_MPU_6050;  // setting addr MPU_6050
                                               nx_o_rw = 1'b0;                // write
                                               nx_o_err = 1'b0;               // zero error
                                               nx_o_fl[2] = 1'b1;             // transaction execution flag
                                               nx_o_addr_rom = `ACCEL_MSR;
                                               nx_st = RD_ACCEL_ST;
                                             end
                                `GYRO_MSR  : begin
                                               nx_o_en_i2c = 1'b1;            // start of a transaction on the bus I2C
                                               nx_o_addr_i2c = AD0_MPU_6050;  // setting addr MPU_6050
                                               nx_o_rw = 1'b0;                // write
                                               nx_o_err = 1'b0;               // zero error
                                               nx_o_fl[3] = 1'b1;             // transaction execution flag
                                               nx_o_addr_rom = `GYRO_MSR;
                                               nx_st = RD_GYRO_ST;
                                             end
                                            
                                            
                                `FIFO_EN   : begin
                                               nx_o_en_i2c = 1'b1;            // start of a transaction on the bus I2C
                                               nx_o_addr_i2c = AD0_MPU_6050;  // setting addr MPU_6050
                                               nx_o_rw = 1'b0;                // write
                                               nx_o_err = 1'b0;               // zero error
                                               nx_o_fl[4] = 1'b1;             // transaction execution flag
                                               nx_o_data_wr_i2c = ADDR_FIFO_EN;
                                               nx_o_addr_rom = `FIFO_EN;
                                               nx_st = FIFO_EN;
                                             end
                                             
                                             
                                `FIFO_CNT  : begin
                                               nx_o_en_i2c = 1'b1;            // start of a transaction on the bus I2C
                                               nx_o_addr_i2c = AD0_MPU_6050;  // setting addr MPU_6050
                                               nx_o_rw = 1'b0;                // write
                                               nx_o_err = 1'b0;               // zero error
                                               nx_o_fl[5] = 1'b1;             // transaction execution flag
                                               nx_o_addr_rom = `FIFO_CNT;
                                               nx_st = RD_FIFO_CNT_ST;
                                             end 
                                             
                                             
                                default    : begin
                                               nx_st = WT_COMM;
                                             end
                             endcase
                           end
          PING           : begin
                             nx_o_data_wr_i2c = I_DATA_ROM;    // reg addr chip id
                             if (rs_i_busy)
                                 nx_o_en_i2c = 1'b0;           // stop of a transaction on the bus I2C         
                             if (fl_i_busy)  
                               begin
                                 nx_o_en_i2c = 1'b1;           // restart I2C bus
                                 nx_o_addr_i2c = AD0_MPU_6050; // setting addr MPU_6050
                                 nx_o_rw = 1'b1;               // read
                                 nx_st = PING_RD;              // nx_st is PING
                               end                  
                           end
          PING_RD        : begin
                             if (rs_i_busy)
                               nx_o_en_i2c = 1'b0;             // stop of a transaction on the bus I2C 
                             if (fl_i_busy)
                               begin
                                 nx_o_fl = {FL_SZ{1'b0}};      // zero flags
                                 nx_st = WT_COMM;
                                 if (I_DATA_RD_I2C != WHO_AM_I)
                                   nx_o_err = 1'b1;            // error if read data != 0x68                                  
                               end
                           end   
          RD_TMP_ST      : begin
                             nx_o_data_wr_i2c = I_DATA_ROM;    // reg addr measurement temperature
                             if (rs_i_busy)
                                 nx_o_en_i2c = 1'b0;           // stop of a transaction on the bus I2C         
                             if (fl_i_busy)  
                               begin
                                 nx_o_en_i2c = 1'b1;           // restart I2C bus
                                 nx_o_addr_i2c = AD0_MPU_6050; // setting addr MPU_6050
                                 nx_o_rw = 1'b1;               // read
                                 nx_cnt_fl_i_busy = 2'b10;      // setting counter = 2 (rxd 2 bytes from reg addr 8'h41 and 8'h42)
                                 nx_st = RD_TMP_FN;
                               end                  
                           end
          RD_TMP_FN      : begin
                             if (fl_i_busy)
                               begin
                                 nx_cnt_fl_i_busy = cnt_fl_i_busy - 1'b1; 
                                 nx_o_rxd_buff = {O_RXD_BUFF[15:0], I_DATA_RD_I2C};
                                 // nx_cnt_for_wr = cnt_for_wr + 1'b1;
                               end
                             // if (cnt_for_wr == 2'b10)
                               // begin
                                 // nx_cnt_for_wr = 2'b0;
                                 // nx_t_buff = O_RXD_BUFF[15:0];     // setting data to writing to t_buff;
                                 // nx_o_data_wr_opm = O_RXD_BUFF[15:0];     // setting data to writing to RAM
                                 // nx_o_we = 1'b1;                          // setting I_WE to writing to RAM             
                                 // nx_o_addr_opm = O_ADDR_OPM - 1'b1;       // setting addr for RAM
                               // end
                             // if (rs_i_busy)
                               // begin
                                 // nx_o_we = 1'b0;                          // stop writing to RAM
                               // end
                             if (cnt_fl_i_busy == 1)
                               nx_o_en_i2c = 1'b0;                        // stop reading, txd ACK
                             if (&(!cnt_fl_i_busy))                       // when = 0
                               begin
                                 nx_t_buff = O_RXD_BUFF[15:0];     // setting data to writing to t_buff;
                                 nx_o_fl[1] = 1'b0;                       // end of reading temperature
                                 nx_st = WT_COMM;
                               end
                           end  
          RD_ACCEL_ST      : begin
                             nx_o_data_wr_i2c = I_DATA_ROM;    // reg addr accelerometer measurements
                             if (rs_i_busy)
                                 nx_o_en_i2c = 1'b0;           // stop of a transaction on the bus I2C         
                             if (fl_i_busy)  
                               begin
                                 nx_o_en_i2c = 1'b1;           // restart I2C bus
                                 nx_o_addr_i2c = AD0_MPU_6050; // setting addr MPU_6050
                                 nx_o_rw = 1'b1;               // read
                                 nx_cnt_fl_i_busy = 6;         // setting counter = 6 (rxd 6 bytes from reg addr from 8'h3B to 8'h40)
                                 nx_st = RD_ACCEL_FN;
                               end                  
                           end
          RD_ACCEL_FN    : begin
                             if (fl_i_busy)
                               begin
                                 nx_cnt_fl_i_busy = cnt_fl_i_busy - 1'b1; 
                                 nx_o_rxd_buff = {O_RXD_BUFF[15:0], I_DATA_RD_I2C};
                               end
                             if (cnt_fl_i_busy == 4)
                               begin
                                 nx_accel_x_buff = O_RXD_BUFF[15:0];     // setting data to writing to accel_x_buff;
                               end
                             if (cnt_fl_i_busy == 2)
                               begin
                                 nx_accel_y_buff = O_RXD_BUFF[15:0];     // setting data to writing to accel_y_buff;
                               end
                             if (cnt_fl_i_busy == 1)
                               nx_o_en_i2c = 1'b0;                        // stop reading, txd ACK
                             if (&(!cnt_fl_i_busy))                       // when = 0
                               begin
                                 nx_accel_z_buff = O_RXD_BUFF[15:0];     // setting data to writing to accel_z_buff;
                                 nx_o_fl[2] = 1'b0;                       // end of reading accelerometer
                                 nx_st = WT_COMM;
                               end
                           end  
          RD_GYRO_ST     : begin
                             nx_o_data_wr_i2c = I_DATA_ROM;    // reg addr gyroscope measurements
                             if (rs_i_busy)
                                 nx_o_en_i2c = 1'b0;           // stop of a transaction on the bus I2C         
                             if (fl_i_busy)  
                               begin
                                 nx_o_en_i2c = 1'b1;           // restart I2C bus
                                 nx_o_addr_i2c = AD0_MPU_6050; // setting addr MPU_6050
                                 nx_o_rw = 1'b1;               // read
                                 nx_cnt_fl_i_busy = 6;         // setting counter = 6 (rxd 6 bytes from reg addr from 8'h43 to 8'h48)
                                 nx_st = RD_GYRO_FN;
                               end                  
                           end
          RD_GYRO_FN     : begin
                             if (fl_i_busy)
                               begin
                                 nx_cnt_fl_i_busy = cnt_fl_i_busy - 1'b1; 
                                 nx_o_rxd_buff = {O_RXD_BUFF[15:0], I_DATA_RD_I2C};
                               end
                             if (cnt_fl_i_busy == 4)
                               begin
                                 nx_gyro_x_buff = O_RXD_BUFF[15:0];     // setting data to writing to gyro_x_buff;
                               end
                             if (cnt_fl_i_busy == 2)
                               begin
                                 nx_gyro_y_buff = O_RXD_BUFF[15:0];     // setting data to writing to gyro_y_buff;
                               end
                             if (cnt_fl_i_busy == 1)
                               nx_o_en_i2c = 1'b0;                        // stop reading, txd ACK
                             if (&(!cnt_fl_i_busy))                       // when = 0
                               begin
                                 nx_gyro_z_buff = O_RXD_BUFF[15:0];     // setting data to writing to gyro_z_buff;
                                 nx_o_fl[3] = 1'b0;                       // end of reading gyroscope
                                 nx_st = WT_COMM;
                               end
                           end
          FIFO_EN        : begin
                             if (rs_i_busy)
                               begin
                                 nx_o_data_wr_i2c = WR_FIFO;           // write to reg 8'h23 FIFO_EN for temp, gyro and accel
                                 nx_cnt_rs_i_busy = cnt_rs_i_busy + 1'b1;
                               end
                             if (fl_i_busy)
                                 nx_cnt_fl_i_busy = cnt_fl_i_busy + 1'b1;
                             if (cnt_rs_i_busy == 2'b10)
                                 nx_o_en_i2c = 1'b0;                      // stop of a transaction on the bus I2C
                             if (cnt_fl_i_busy == 2'b10)
                               begin
                                 nx_cnt_rs_i_busy = {CNT_RS_I_BUSY_SZ{1'b0}};
                                 nx_cnt_fl_i_busy = {CNT_FL_I_BUSY_SZ{1'b0}};
                                 nx_o_fl[4] = 1'b0;
                                 nx_st = WT_COMM;
                               end
                           end


          RD_FIFO_CNT_ST : begin
                             nx_o_data_wr_i2c = I_DATA_ROM;    // reg addr FIFO Count Registers
                             if (rs_i_busy)
                                 nx_o_en_i2c = 1'b0;           // stop of a transaction on the bus I2C         
                             if (fl_i_busy)  
                               begin
                                 nx_o_en_i2c = 1'b1;           // restart I2C bus
                                 nx_o_addr_i2c = AD0_MPU_6050; // setting addr MPU_6050
                                 nx_o_rw = 1'b1;               // read
                                 nx_cnt_fl_i_busy = 2'b10;      // setting counter = 2 (rxd 2 bytes from reg addr 8'h72 and 8'h73)
                                 nx_st = RD_FIFO_CNT_FN;
                               end                  
                           end
          RD_FIFO_CNT_FN : begin
                             if (fl_i_busy)
                               begin
                                 nx_cnt_fl_i_busy = cnt_fl_i_busy - 1'b1; 
                                 nx_o_rxd_buff = {O_RXD_BUFF[15:0], I_DATA_RD_I2C};
                               end
                             if (cnt_fl_i_busy == 1)
                               nx_o_en_i2c = 1'b0;                        // stop reading, txd ACK
                             if (&(!cnt_fl_i_busy))                       // when = 0
                               begin
                                 nx_fifo_cnt_buff = O_RXD_BUFF[15:0];     // setting data to writing to fifo_cnt_buff;
                                 nx_o_fl[5] = 1'b0;                       // end of reading temperature
                                 nx_st = WT_COMM;
                               end
                           end                            
                           
          default        : begin
                             nx_st = WT_COMM;
                             nx_o_err = 1'b1;
                             nx_o_en_i2c = 1'b0;
                             nx_o_addr_rom = {ADDR_ROM_SZ{1'b0}};                             
                             nx_o_addr_i2c = {ADDR_I2C_SZ{1'b0}};
                             nx_o_rw = 1'b0;
                             nx_o_data_wr_i2c = {DATA_I2C_SZ{1'b0}};
                             nx_cnt_rs_i_busy = {CNT_RS_I_BUSY_SZ{1'b0}};
                             nx_cnt_fl_i_busy = {CNT_FL_I_BUSY_SZ{1'b0}};
                             nx_comm_reg = {ADDR_ROM_SZ{1'b0}};
                             nx_o_fl = {FL_SZ{1'b0}};
                             nx_o_rxd_buff = {RXD_SZ{1'b0}};
                             nx_t_buff = {DATA_OPM_SZ{1'b0}};
                             nx_accel_x_buff = {DATA_OPM_SZ{1'b0}};
                             nx_accel_y_buff = {DATA_OPM_SZ{1'b0}};
                             nx_accel_z_buff = {DATA_OPM_SZ{1'b0}};
                             nx_gyro_x_buff = {DATA_OPM_SZ{1'b0}};
                             nx_gyro_y_buff = {DATA_OPM_SZ{1'b0}};
                             nx_gyro_z_buff = {DATA_OPM_SZ{1'b0}};
                             nx_fifo_cnt_buff = {DATA_OPM_SZ{1'b0}};
                           end
      endcase                           
    end         
    
//  latching the next state of FSM and signals, every clock     
    always @(posedge CLK or negedge RST_n) begin
      if (!RST_n)
        begin
          st            <= WT_COMM;     
          O_EN_I2C      <= 1'b0;       
          O_ADDR_I2C    <= {ADDR_I2C_SZ{1'b0}};
          O_RW          <= 1'b0;
          O_DATA_WR_I2C <= {DATA_I2C_SZ{1'b0}};
          O_ADDR_ROM    <= {ADDR_ROM_SZ{1'b0}};          
          cr_i_busy     <= 1'b0;
          pr_i_busy     <= 1'b0;
          cnt_rs_i_busy <= {CNT_RS_I_BUSY_SZ{1'b0}};
          cnt_fl_i_busy <= {CNT_FL_I_BUSY_SZ{1'b0}};    
          comm_reg      <= {ADDR_ROM_SZ{1'b0}};
          O_FL          <= {FL_SZ{1'b0}};
          O_ERR         <= 1'b0;
          O_RXD_BUFF    <= {RXD_SZ{1'b0}};
          t_buff        <= {DATA_OPM_SZ{1'b0}};
          accel_x_buff  <= {DATA_OPM_SZ{1'b0}};
          accel_y_buff  <= {DATA_OPM_SZ{1'b0}};
          accel_z_buff  <= {DATA_OPM_SZ{1'b0}};
          gyro_x_buff  <= {DATA_OPM_SZ{1'b0}};
          gyro_y_buff  <= {DATA_OPM_SZ{1'b0}};
          gyro_z_buff  <= {DATA_OPM_SZ{1'b0}};
          fifo_cnt_buff <= {DATA_OPM_SZ{1'b0}};
        end
      else
        begin
          st            <= nx_st;        
          O_EN_I2C      <= nx_o_en_i2c;          
          O_ADDR_I2C    <= nx_o_addr_i2c;
          O_RW          <= nx_o_rw;
          O_DATA_WR_I2C <= nx_o_data_wr_i2c;
          O_ADDR_ROM    <= nx_o_addr_rom;       
          cr_i_busy     <= I_BUSY;
          pr_i_busy     <= cr_i_busy; 
          cnt_rs_i_busy <= nx_cnt_rs_i_busy;
          cnt_fl_i_busy <= nx_cnt_fl_i_busy;
          comm_reg      <= nx_comm_reg;
          O_FL          <= nx_o_fl;
          O_ERR         <= nx_o_err;
          O_RXD_BUFF    <= nx_o_rxd_buff;  
          t_buff        <= nx_t_buff;
          accel_x_buff  <= nx_accel_x_buff;
          accel_y_buff  <= nx_accel_y_buff;
          accel_z_buff  <= nx_accel_z_buff;
          gyro_x_buff  <= nx_gyro_x_buff;
          gyro_y_buff  <= nx_gyro_y_buff;
          gyro_z_buff  <= nx_gyro_z_buff;
          fifo_cnt_buff <= nx_fifo_cnt_buff;
        end
    end
 
    
endmodule