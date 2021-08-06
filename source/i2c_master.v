module i2c_master
    #(parameter FPGA_CLK = 50_000_000,  // FPGA frequency 50 MHz
      parameter I2C_CLK  = 100_000,     // I2C bus frequency 100 KHz
      parameter ADDR_SZ  = 7,           // address widht
      parameter COMM_SZ  = ADDR_SZ + 1, // command widht
      parameter DATA_SZ  = 8)           // data widht
    (CLK, RST_n, I_EN, I_ADDR, I_RW, I_DATA_WR, 
     O_DATA_RD, O_ACK_FL, O_BUSY, 
     IO_SCL, IO_SDA);
    
    
//--------------------------------------------------------------------------    
//  input signals
    input wire                CLK;       // clock 50 MHz
    input wire                RST_n;     // asynchronous reset_n
    input wire                I_EN;      // I2C bus enable signal from cpu
    input wire [ADDR_SZ-1:0]  I_ADDR;    // address of slave
    input wire                I_RW;      // read or write signal from slave
    input wire [DATA_SZ-1:0]  I_DATA_WR; // data for write in slave
//  output signals
    output wire [DATA_SZ-1:0] O_DATA_RD; // readed data from the slave 
    output wire               O_ACK_FL;  // flag in case of error
    output wire               O_BUSY;    // master busy signal
//  bidirectional signals
    inout wire IO_SCL; // serial clock I2C bus 
    inout wire IO_SDA; // serial data I2C bus
//  internal signals        
    wire scl;       // serial clock from i2c_clk_div
    wire rs_pr_scl; // rising edge o_prev_scl for sda
    wire fl_pr_scl; // falling edge o_prev_scl for sda
    wire sda_out;   // sda from I2C muster to slave
    wire scl_out;   // scl from I2C muster to slave
    wire sda;       // input sda from the slave

//--------------------------------------------------------------------------
    i2c_clk_div 
        #(
         .FPGA_CLK(FPGA_CLK),
         .I2C_CLK(I2C_CLK)
        )
    i2c_clk_div
        (
         .CLK(CLK),
         .RST_n(RST_n),
         .O_SCL(scl),
         .O_RS_PR_SCL(rs_pr_scl),
         .O_FL_PR_SCL(fl_pr_scl)
        );   

//--------------------------------------------------------------------------
    i2c_fsm 
        #(
         .ADDR_SZ(ADDR_SZ),
         .COMM_SZ(COMM_SZ),
         .DATA_SZ(DATA_SZ)
        )
    i2c_fsm
        (
         .CLK(CLK),
         .RST_n(RST_n),
         .I_SCL(scl),
         .I_RS_PR_SCL(rs_pr_scl),
         .I_FL_PR_SCL(fl_pr_scl),
         .I_EN(I_EN),
         .I_ADDR(I_ADDR),
         .I_RW(I_RW),
         .I_DATA_WR(I_DATA_WR),
         .I_SDA(sda),
         .O_DATA_RD(O_DATA_RD),
         .O_ACK_FL(O_ACK_FL),
         .O_BUSY(O_BUSY),
         .O_SCL(scl_out),
         .O_SDA(sda_out)
        );
 
//-------------------------------------------------------------------------- 
    assign sda    = IO_SDA;
    assign IO_SDA = sda_out ? 1'bz : 1'b0;
    assign IO_SCL = scl_out ? 1'bz : 1'b0;  
 
 
endmodule