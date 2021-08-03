module MPU_6050
    #(parameter FPGA_CLK = 50_000_000, // FPGA frequency 50 MHz
      parameter I2C_CLK  = 400_000)    // I2C bus frequency 400 KHz     
    (CLK, RST_n, I_COMM, 
     O_FL, O_ACK_FL, O_CNT_RS_ACK_FL, O_ERR, O_CNT_RS_ERR,
     IO_SCL, IO_SDA);


    localparam ADDR_I2C_SZ          = 7;                    // addr on I2C bus width
    localparam COMM_SZ              = 8;                    // command widht on I2C bus
    localparam DATA_I2C_SZ          = 8;                    // data on I2C bus width    
    localparam ADDR_ROM_SZ          = 4;                    // addr width in ROM 
    localparam DATA_ROM_SZ          = 8;                    // word width in ROM 
    localparam ADDR_OPM_SZ          = 4;                    // addr width in RAM 
    localparam DATA_OPM_SZ          = 16;                   // word width in RAM
    // localparam DATA_ALU             = 32;                   // data ALU width
    // localparam OP_SZ                = 3;                    // aluControl width
    // localparam SH_SZ                = 5;                    // shift width   
    // localparam DATA_DIV             = 6'd33;                // data div width 
    localparam FL_SZ                = 8;                    // command execution flag width  
    localparam RXD_SZ               = 24;                   // buffer of received data from MPU_6050 (width)
//  input signals    
    input wire                   CLK;    // clock 50 MHz
    input wire                   RST_n;  // asynchronous reset_n
    input wire [ADDR_ROM_SZ-1:0] I_COMM; // command for MPU_6050  
//  output signals   
    output wire [FL_SZ-1:0]   O_FL;            // command execution flag 
    output wire               O_ACK_FL;        // flag in case of error
    output wire [4:0]         O_CNT_RS_ACK_FL; // counter error ACK from MPU_6050
    output wire               O_ERR;           // chip id error (MPU_6050) or error state of FSM
    output wire [4:0]         O_CNT_RS_ERR;    // counter chip id error (MPU_6050) or error state of FSM     
//  bidirectional signals
    inout wire                IO_SCL; // serial clock I2C bus 
    inout wire                IO_SDA; // serial data I2C bus    
//  internal signals
    wire                       en_i2c;        // enable I2C bus  
    wire [ADDR_I2C_SZ-1:0]     addr_i2c;      // addr MPU_6050 on I2C bus
    wire                       rw;            // RW I2C bus 
    wire [DATA_I2C_SZ-1:0]     data_wr_i2c;   // data for writing on I2C bus  
    wire [DATA_I2C_SZ-1:0]     data_rd_i2c;   // readed data from I2C bus
    wire                       busy_i2c;      // master I2C busy signal
    wire                       ack_fl;        // flag in case of error on the bus
    reg                        cr_ack_fl;     // current ACK from MPU_6050
    reg                        pr_ack_fl;     // previous ACK from MPU_6050
    wire                       rs_ack_fl;     // rising edge ACK from MPU_6050
    reg [4:0]                  cnt_rs_ack_fl; // counter error ACK from MPU_6050
    wire [ADDR_ROM_SZ-1:0]     command;       // command for MPU_6050 
    wire [ADDR_ROM_SZ-1:0]     addr_rom_o;    // word address in ROM (output)
    wire [DATA_ROM_SZ-1:0]     data_rom;      // word in ROM
    // wire                       we;            // WE RAM signal
    // wire [ADDR_OPM_SZ-1:0]     addr_opm;      // word addr in RAM (input)
    // wire [DATA_OPM_SZ-1:0]     data_opm;      // word to write to RAM (input)
    // wire [ADDR_OPM_SZ-1:0]     addr_opm_o;     // word addr in RAM (output) 
    // wire [DATA_OPM_SZ-1:0]     data_opm_o;     // word by addr in RAM (output)
    // wire [DATA_ALU-1:0]        srcA;          // srcA
    // wire [DATA_ALU-1:0]        srcB;          // srcB    
    // wire [OP_SZ-1:0]           oper;          // aluControl
    // wire [SH_SZ-1:0]           shift;         // shift
    // wire [DATA_ALU-1:0]        rsl_alu;       // result alu
    // wire                       sg;            // singed mult
    // wire [DATA_ALU-1:0]        rsl_mult;      // result mult
    // wire                       en_div;        // enable devision
    // wire [DATA_DIV-1:0]        num;           // numerator
    // wire [DATA_DIV-1:0]        den;           // denomerator     
    // wire signed [DATA_DIV-1:0] rsl_div;       // result division    
    // wire                       fn_div;        // end of division
    wire                       err;           // chip id error (MPU_6050) or error state of FSM
    reg                        cr_err;        // current chip id error (MPU_6050) or error state of FSM
    reg                        pr_err;        // previous chip id error (MPU_6050) or error state of FSM
    wire                       rs_err;        // rising edge chip id error (MPU_6050) or error state of FSM
    reg [4:0]                  cnt_rs_err;    // counter chip id error (MPU_6050) or error state of FSM  
    wire [RXD_SZ-1:0]          rxd_buff;      // buffer of received data from MPU_6050 
    wire signed [DATA_OPM_SZ-1:0]        t_buff;           // readed TEMP_OUT
    wire signed [DATA_OPM_SZ-1:0] accel_x_buff;   // readed ACCEL_XOUT
    wire signed [DATA_OPM_SZ-1:0] accel_y_buff;   // readed ACCEL_YOUT
    wire signed [DATA_OPM_SZ-1:0] accel_z_buff;   // readed ACCEL_ZOUT    
    wire signed [DATA_OPM_SZ-1:0] gyro_x_buff;   // readed GYRO_XOUT
    wire signed [DATA_OPM_SZ-1:0] gyro_y_buff;   // readed GYRO_YOUT
    wire signed [DATA_OPM_SZ-1:0] gyro_z_buff;   // readed GYRO_ZOUT    
    wire [DATA_OPM_SZ-1:0] fifo_cnt_buff; // current value of the FIFO counter
    // wire                       en_ram;        // RAM transaction enable
    // wire                       we_ctrl;       // WE RAM (controller to RAM)
    // wire                       we_calc;       // WE RAM (calc to RAM)
    // wire [ADDR_OPM_SZ-1:0]     addr_opm_ctrl; // word addr in RAM (input) (from controller)
    // wire [ADDR_OPM_SZ-1:0]     addr_opm_calc; // word addr in RAM (input) (from calc)
    // wire [DATA_OPM_SZ-1:0]     data_opm_ctrl; // word to write to RAM (input) (from controller)   
    // wire [DATA_OPM_SZ-1:0]     data_opm_calc; // word to write to RAM (input) (from calc)      
    

//--------------------------------------------------------------------------    
    controller
        #(
         .FPGA_CLK(FPGA_CLK),
         .ADDR_I2C_SZ(ADDR_I2C_SZ),
         .DATA_I2C_SZ(DATA_I2C_SZ),
         .ADDR_ROM_SZ(ADDR_ROM_SZ),
         .DATA_ROM_SZ(DATA_ROM_SZ),
         .RXD_SZ(RXD_SZ)
        )     
    controller
        (
         .CLK(CLK), 
         .RST_n(RST_n), 
         .I_COMM(I_COMM),
         .I_DATA_ROM(data_rom),
         .I_DATA_RD_I2C(data_rd_i2c),
         .I_BUSY(busy_i2c), 
         .O_EN_I2C(en_i2c), 
         .O_ADDR_I2C(addr_i2c), 
         .O_RW(rw), 
         .O_DATA_WR_I2C(data_wr_i2c),
         .O_RXD_BUFF(rxd_buff),
         .O_FL(O_FL),         
         .O_ERR(err),
         .O_ADDR_ROM(command),
         .t_buff(t_buff),
         .accel_x_buff(accel_x_buff),
         .accel_y_buff(accel_y_buff),
         .accel_z_buff(accel_z_buff),
         .gyro_x_buff(gyro_x_buff),
         .gyro_y_buff(gyro_y_buff),
         .gyro_z_buff(gyro_z_buff),
         .fifo_cnt_buff(fifo_cnt_buff)
         // .O_EN_RAM(en_ram),
         // .O_WE(we_ctrl),
         // .O_ADDR_OPM(addr_opm_ctrl), 
         // .O_DATA_WR_OPM(data_opm_ctrl),
        );      

//--------------------------------------------------------------------------     
    instruction_memory 
        #(
         .ADDR_ROM_SZ(ADDR_ROM_SZ), 
         .DATA_ROM_SZ(DATA_ROM_SZ)
        )
    instruction_memory
        (
         .CLK(CLK), 
         .I_ADDR_ROM(command), 
         .O_ADDR_ROM(addr_rom_o), 
         .O_DATA_ROM(data_rom)
        );

// --------------------------------------------------------------------------         
    // opm 
        // #(
         // .DATA_OPM_SZ(DATA_OPM_SZ), 
         // .ADDR_OPM_SZ(ADDR_OPM_SZ)
        // )
    // opm
        // (
         // .CLK(CLK), 
         // .I_WE(we), 
         // .I_ADDR_OPM(addr_opm), 
         // .I_DATA_WR_OPM(data_opm),
         // .O_ADDR(addr_opm_o),
         // .O_DATA(data_opm_o)
        // );

// --------------------------------------------------------------------------  
    // clk_div_msrmnt 
        // #(
         // .FPGA_CLK(FPGA_CLK),
         // .T_MSR_MX(T_MSR_MX),
         // .N_CLK_MSR_MX(N_CLK_MSR_MX),
         // .CNT_MSR_MX_SZ(CNT_MSR_MX_SZ)
        // ) 
    // clk_div_msrmnt
        // (
         // .CLK(CLK),
         // .RST_n(RST_n), 
         // .I_EN(en_cnt), 
         // .I_RST(rst_cnt), 
         // .O_CNT(cnt)
        // );

// --------------------------------------------------------------------------         
    // alu 
        // #(
         // .DATA_ALU(DATA_ALU),
         // .OP_SZ(OP_SZ),
         // .SH_SZ(SH_SZ)
        // )
    // alu 
        // (
         // .I_A(srcA), 
         // .I_B(srcB), 
         // .I_OP(oper), 
         // .I_SH(shift), 
         // .O_RSL(rsl_alu)
        // );

// -------------------------------------------------------------------------- 
    // mult
        // #(
         // .DATA_ALU(DATA_ALU)
         // )
    // mult 
        // (
         // .I_A(srcA),
         // .I_B(srcB), 
         // .I_SG(sg),
         // .O_RSL(rsl_mult)
        // );

// --------------------------------------------------------------------------        
    // div 
        // #(
         // .DATA_DIV(DATA_DIV)
        // )
    // div
        // (
         // .CLK(CLK),
         // .I_EN(en_div),
         // .I_NUM(num),
         // .I_DEN(den),
         // .O_RSL(rsl_div),
         // .O_REM(), 
         // .O_FN(fn_div)
        // );

// -------------------------------------------------------------------------- 
    i2c_master 
        #(
         .FPGA_CLK(FPGA_CLK),
         .I2C_CLK(I2C_CLK),
         .ADDR_SZ(ADDR_I2C_SZ),
         .COMM_SZ(COMM_SZ),
         .DATA_SZ(DATA_I2C_SZ)
        )
    i2c_master
        (
         .CLK(CLK), 
         .RST_n(RST_n), 
         .I_EN(en_i2c),
         .I_ADDR(addr_i2c), 
         .I_RW(rw), 
         .I_DATA_WR(data_wr_i2c), 
         .O_DATA_RD(data_rd_i2c), 
         .O_ACK_FL(ack_fl), 
         .O_BUSY(busy_i2c), 
         .IO_SCL(IO_SCL), 
         .IO_SDA(IO_SDA)
        );
        
//  memory access
    // assign we = en_ram ? we_ctrl : we_calc;
    // assign addr_opm = en_ram ? addr_opm_ctrl : addr_opm_calc;
    // assign data_opm = en_ram ? data_opm_ctrl : data_opm_calc;

//  error monitoring    
    assign rs_ack_fl = cr_ack_fl & !pr_ack_fl;
    assign rs_err = cr_err & !pr_err;
    assign O_CNT_RS_ACK_FL = cnt_rs_ack_fl;
    assign O_CNT_RS_ERR = cnt_rs_err;
    assign O_ACK_FL = ack_fl;
    assign O_ERR = err;   

//  counter error    
    always @(posedge CLK or negedge RST_n) begin
      if (!RST_n)
        begin
          cr_ack_fl <= 1'b0;
          pr_ack_fl <= 1'b0;
          cr_err <= 1'b0;
          pr_err <= 1'b0;
          cnt_rs_ack_fl <= 5'b0;
          cnt_rs_err <= 5'b0;
        end
      else
        begin
          cr_ack_fl <= ack_fl;
          pr_ack_fl <= cr_ack_fl;
          cr_err <= err;
          pr_err <= cr_err;
          if (rs_ack_fl)
            cnt_rs_ack_fl <= cnt_rs_ack_fl + 1'b1;
          else 
            cnt_rs_ack_fl <= cnt_rs_ack_fl;
          if (rs_err)
            cnt_rs_err <= cnt_rs_err + 1'b1;
          else
            cnt_rs_err <= cnt_rs_err;
        end
    end        

  
endmodule        