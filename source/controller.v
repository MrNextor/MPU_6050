module controller
    #(parameter FPGA_CLK    = 50_000_000, // FPGA frequency 50 MHz
      parameter ADDR_I2C_SZ = 7,          // addr on I2C bus width
      parameter DATA_I2C_SZ = 8,          // data on I2C bus width
      parameter ADDR_ROM_SZ = 4,          // addr width in ROM 
      parameter DATA_ROM_SZ = 16,         // word width in ROM 
      // parameter ADDR_OPM_SZ = 4,          // addr width in RAM 
      // parameter DATA_OPM_SZ = 16,         // word width in RAM      
      parameter RXD_SZ      = 24)         // buffer of received data from MPU_6050 (width)
    (CLK, RST_n, I_EN, I_DATA_ROM_A, I_DATA_ROM_B, I_DATA_RD_I2C, I_BUSY,
     O_EN_I2C, O_ADDR_I2C, O_RW, O_DATA_WR_I2C, O_RXD_BUFF, O_BUSY, O_FL, O_ERR);
   
   
//--------------------------------------------------------------------------    
    localparam FL_SZ         = 2; // command execution flag width
    localparam CNT_I_BUSY_SZ = 4; // counter I_BUSY width
//  description states FSM
    localparam ST_SZ     = 5;        // number of states FSM
    localparam IDLE      = 5'b00001; // waiting I_EN
    localparam RD_I2C_ST = 5'b00010; // start reading data from slave
    localparam RD_I2C_FN = 5'b00100; // finish reading data from slave
    localparam WR_I2C_ST = 5'b01000; // start writing data to slave
    localparam WR_I2C_FN = 5'b10000; // finish writing data to slave
//  input signals
    input wire                   CLK;           // clock 50 MHz
    input wire                   RST_n;         // asynchronous reset_n
    input wire                   I_EN;          // Enable controller
    input wire [DATA_ROM_SZ-1:0] I_DATA_ROM_A;  // word A in ROM    
    input wire [DATA_ROM_SZ-1:0] I_DATA_ROM_B;  // word B in ROM     
    input wire [DATA_I2C_SZ-1:0] I_DATA_RD_I2C; // readed data from I2C bus
    input wire                   I_BUSY;        // master I2C busy signal
//  output signals
    output reg                   O_EN_I2C;      // enable I2C bus   
    output reg [ADDR_I2C_SZ-1:0] O_ADDR_I2C;    // slave address on the I2C bus
    output reg                   O_RW;          // RW I2C bus 
    output reg [DATA_I2C_SZ-1:0] O_DATA_WR_I2C; // data for writing on I2C bus 
    output reg [RXD_SZ-1:0]      O_RXD_BUFF;    // buffer of received data from I2C bus
    output reg                   O_BUSY;        // Busy controller
    output reg [FL_SZ-1:0]       O_FL;          // command execution flag     
    output reg                   O_ERR;         // error state of FSM
//  internal signals
    reg [ST_SZ-1:0]         st;               // current state of FSM
    reg [ST_SZ-1:0]         nx_st;            // next state of FSM
    reg                     cr_i_busy;        // current I_BUSY
    reg                     pr_i_busy;        // previous I_BUSY
    wire                    rs_i_busy;        // rising edge I_BUSY
    wire                    fl_i_busy;        // falling edge I_BUSY
    reg [CNT_I_BUSY_SZ-1:0] cnt_rs_i_busy;    // rising edge counter I_BUSY
    reg [CNT_I_BUSY_SZ-1:0] nx_cnt_rs_i_busy; // next rising edge counter I_BUSY  
    reg [CNT_I_BUSY_SZ-1:0] cnt_fl_i_busy;    // falling edge counter I_BUSY
    reg [CNT_I_BUSY_SZ-1:0] nx_cnt_fl_i_busy; // next falling edge counter I_BUSY
    reg                     nx_o_en_i2c;      // next enable signal I2C bus   
    reg [ADDR_I2C_SZ-1:0]   nx_o_addr_i2c;    // next slave address on the I2C bus
    reg                     nx_o_rw;          // next RW I2C bus  
    reg [DATA_I2C_SZ-1:0]   nx_o_data_wr_i2c; // next data for writing on I2C bus
    reg [FL_SZ-1:0]         nx_o_fl;          // next command execution flag 
    reg                     nx_o_err;         // chip id error (MPU_6050) or error state of FSM
    reg                     nx_o_busy;        // next Busy controller        
    reg [RXD_SZ-1:0]        nx_o_rxd_buff;    // next buffer of received data from MPU_6050
    reg                     en_ctrl;          // enable controller
    reg [ADDR_I2C_SZ-1:0]   addr_i2c;         // latched slave addres on the I2C bus
    reg [ADDR_I2C_SZ-1:0]   nx_addr_i2c;      // next latched slave addres on the I2C bus
    reg                     rw;               // latched RW
    reg                     nx_rw;            // next latched RW
    reg [DATA_I2C_SZ-1:0]   slv_reg_addr;     // slave register address
    reg [DATA_I2C_SZ-1:0]   nx_slv_reg_addr;  // next slave register address    
    reg [DATA_I2C_SZ-1:0]   slv_reg_data;     // data to write slave to address
    reg [DATA_I2C_SZ-1:0]   nx_slv_reg_data;  // next data to write slave to address    
    
//  determining of rissing edge and falling edge I_BUSY
    assign rs_i_busy =  cr_i_busy & !pr_i_busy;
    assign fl_i_busy = !cr_i_busy &  pr_i_busy; 

//  determining the next state of FSM and singals    
    always @(*) begin
      nx_st = st;
      nx_cnt_rs_i_busy = cnt_rs_i_busy;
      nx_cnt_fl_i_busy = cnt_fl_i_busy;
      nx_o_en_i2c = O_EN_I2C;
      nx_o_addr_i2c = O_ADDR_I2C;
      nx_o_rw = O_RW;
      nx_o_data_wr_i2c = O_DATA_WR_I2C;
      nx_o_fl = O_FL;
      nx_o_err = O_ERR;    
      nx_o_busy = O_BUSY;
      nx_o_rxd_buff = O_RXD_BUFF;
      nx_addr_i2c = addr_i2c;
      nx_rw = rw;
      nx_slv_reg_addr = slv_reg_addr;
      nx_slv_reg_data = slv_reg_data;
      case (st)   
          IDLE           : begin
                             if (en_ctrl)
                               begin
                                 nx_addr_i2c = I_DATA_ROM_A[15:9];
                                 nx_rw = I_DATA_ROM_A[8];
                                 nx_slv_reg_data = I_DATA_ROM_A[7:0];
                                 nx_slv_reg_addr = I_DATA_ROM_B[15:8];
                                 nx_o_en_i2c = 1'b1;                   // start of a transaction on the I2C bus 
                                 nx_o_addr_i2c = I_DATA_ROM_A[15:9];   // setting slave addr on the I2C bus
                                 nx_o_rw = 1'b0;                       // write
                                 nx_o_busy = 1'b1;
                                 nx_o_data_wr_i2c = I_DATA_ROM_B[15:8];
                                 nx_o_err = 1'b0;
                                 nx_cnt_rs_i_busy = I_DATA_ROM_B[7:4];
                                 nx_cnt_fl_i_busy = I_DATA_ROM_B[7:4];
                                 if (!I_DATA_ROM_A[8])
                                   begin
                                     nx_o_fl[1] = 1'b1;                // to start state of reading
                                     nx_st = WR_I2C_ST;
                                   end
                                 else
                                   begin
                                     nx_o_fl[0] = 1'b1;                // to start state of writing
                                     nx_st = RD_I2C_ST;
                                   end                                  
                               end
                           end
          RD_I2C_ST      : begin
                             if (rs_i_busy)
                                 nx_o_en_i2c = 1'b0;              // stop of a transaction on the bus I2C         
                             if (fl_i_busy)  
                               begin
                                 nx_o_en_i2c = 1'b1;              // restart I2C bus
                                 nx_o_addr_i2c = addr_i2c;        // setting addr MPU_6050
                                 nx_o_rw = 1'b1;                  // read
                                 nx_o_data_wr_i2c = slv_reg_addr; 
                                 nx_st = RD_I2C_FN;
                               end                  
                           end
          RD_I2C_FN      : begin
                             if (fl_i_busy)
                               begin
                                 nx_cnt_fl_i_busy = cnt_fl_i_busy - 1'b1; 
                                 nx_o_rxd_buff = {O_RXD_BUFF[15:0], I_DATA_RD_I2C};
                               end
                             if (rs_i_busy)
                                 nx_cnt_rs_i_busy = cnt_rs_i_busy - 1'b1;
                             if (&(!cnt_rs_i_busy))                       // when = 0
                                 nx_o_en_i2c = 1'b0;                      // stop of a transaction on the bus I2C 
                             if (&(!cnt_fl_i_busy))                       // when = 0
                               begin
                                 nx_o_fl[0] = 1'b0;                       // finish state of reading
                                 nx_st = IDLE;
                               end
                           end
          WR_I2C_ST      : begin
                             if (rs_i_busy)
                                 nx_o_data_wr_i2c = slv_reg_data;
                             if (fl_i_busy)
                                 nx_st = WR_I2C_FN;
                           end
          WR_I2C_FN      : begin
                             if (rs_i_busy)
                                 nx_cnt_rs_i_busy = cnt_rs_i_busy - 1'b1;
                             if (fl_i_busy)
                                 nx_cnt_fl_i_busy = cnt_fl_i_busy - 1'b1;
                             if (&(!cnt_rs_i_busy))                       // when = 0
                                 nx_o_en_i2c = 1'b0;
                             if (&(!cnt_fl_i_busy))                       // when = 0
                               begin
                                 nx_o_fl[1] = 1'b0;                       // finish state of writing
                                 nx_st = IDLE;
                               end
                           end                        
          default        : begin
                             nx_st = IDLE;
                             nx_cnt_rs_i_busy = {CNT_I_BUSY_SZ{1'b0}};
                             nx_cnt_fl_i_busy = {CNT_I_BUSY_SZ{1'b0}};
                             nx_o_en_i2c = 1'b0;
                             nx_o_addr_i2c = {ADDR_I2C_SZ{1'b0}};
                             nx_o_rw = 1'b0;
                             nx_o_data_wr_i2c = {DATA_I2C_SZ{1'b0}};
                             nx_o_fl = {FL_SZ{1'b0}};
                             nx_o_err = 1'b1;
                             nx_o_busy  = 1'b0;                             
                             nx_o_rxd_buff = {RXD_SZ{1'b0}};
                             nx_addr_i2c = {ADDR_I2C_SZ{1'b0}};
                             nx_rw = 1'b0;
                             nx_slv_reg_addr = {DATA_I2C_SZ{1'b0}};
                             nx_slv_reg_data = {DATA_I2C_SZ{1'b0}};
                           end
      endcase                           
    end         
    
//  latching the next state of FSM and signals, every clock     
    always @(posedge CLK or negedge RST_n) begin
      if (!RST_n)
        begin
          st            <= IDLE;     
          en_ctrl       <= 1'b0;
          cr_i_busy     <= 1'b0;
          pr_i_busy     <= 1'b0;
          cnt_rs_i_busy <= {CNT_I_BUSY_SZ{1'b0}};
          cnt_fl_i_busy <= {CNT_I_BUSY_SZ{1'b0}};
          O_EN_I2C      <= 1'b0;       
          O_ADDR_I2C    <= {ADDR_I2C_SZ{1'b0}};
          O_RW          <= 1'b0;
          O_DATA_WR_I2C <= {DATA_I2C_SZ{1'b0}};
          O_FL          <= {FL_SZ{1'b0}};
          O_ERR         <= 1'b0;
          O_BUSY        <= 1'b0;
          O_RXD_BUFF    <= {RXD_SZ{1'b0}};
          addr_i2c      <= {ADDR_I2C_SZ{1'b0}};
          rw            <= 1'b0;
          slv_reg_addr  <= {DATA_I2C_SZ{1'b0}};
          slv_reg_data  <= {DATA_I2C_SZ{1'b0}};
        end
      else
        begin
          st            <= nx_st;        
          en_ctrl       <= I_EN;
          cr_i_busy     <= I_BUSY;
          pr_i_busy     <= cr_i_busy; 
          cnt_rs_i_busy <= nx_cnt_rs_i_busy;
          cnt_fl_i_busy <= nx_cnt_fl_i_busy;
          O_EN_I2C      <= nx_o_en_i2c;          
          O_ADDR_I2C    <= nx_o_addr_i2c;
          O_RW          <= nx_o_rw;
          O_DATA_WR_I2C <= nx_o_data_wr_i2c;
          O_FL          <= nx_o_fl;
          O_ERR         <= nx_o_err;
          O_BUSY        <= nx_o_busy;
          O_RXD_BUFF    <= nx_o_rxd_buff;  
          addr_i2c      <= nx_addr_i2c;
          rw            <= nx_rw;
          slv_reg_addr  <= nx_slv_reg_addr;
          slv_reg_data  <= nx_slv_reg_data;
        end
    end
 
    
endmodule