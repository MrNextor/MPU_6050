module db_mpu_6050
    #(parameter FPGA_CLK = 50_000_000, // FPGA frequency 50 MHz
      parameter I2C_CLK  = 400_000)    // I2C bus frequency 400 KHz  
    (CLK, I_KEY, I_SW, 
     O_LEDR, 
     IO_SCL, IO_SDA);


//--------------------------------------------------------------------------  
    localparam RXD_SZ = 24; // buffer of received data from MPU_6050 (width)
//  input signals
    input wire       CLK;   // clock 50 MHz
    input wire [1:0] I_KEY; 
    input wire [8:0] I_SW;
//  output signals
    output reg [9:0] O_LEDR;
//  inout signals
    inout wire       IO_SCL; // serial clock I2C bus 
    inout wire       IO_SDA; // serial data I2C bus   
//  internal signals  
    wire               RST_n;
    wire               ack;
    wire               err;
    wire [RXD_SZ-1:0]  rxd_buff; // buffer of received data from MPU_6050 
    
//--------------------------------------------------------------------------
    top_mpu_6050 
        #(
         .FPGA_CLK(FPGA_CLK),
         .I2C_CLK(I2C_CLK)
        )
    top_mpu_6050 
        (
         .CLK(CLK), 
         .RST_n(RST_n),
         .I_EN(~I_KEY[0]),
         .I_INSTR(I_SW[8:1]), 
         .O_ACK_FL(ack),
         .O_CNT_RS_ACK_FL(),
         .O_ERR(err),
         .O_CNT_RS_ERR(),
         .O_BUSY(),
         .O_FL(),
         .rxd_buff(rxd_buff),
         .IO_SCL(IO_SCL), 
         .IO_SDA(IO_SDA)
        );

//--------------------------------------------------------------------------
    assign RST_n = I_KEY[1];
    always @(posedge CLK or negedge RST_n) begin
      if (!RST_n) 
        begin
          O_LEDR[9:0] <= 10'b0;
        end
      else
        begin
          if (!I_SW[0])
            O_LEDR[9:0] <= {err, ack, rxd_buff[15:8]};
          else 
            O_LEDR[9:0] <= {err, ack, rxd_buff[7:0]};
        end
    end

    
endmodule