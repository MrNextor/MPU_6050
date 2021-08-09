module i2c_fsm
    #(parameter ADDR_SZ = 7,           // address widht
      parameter COMM_SZ = ADDR_SZ + 1, // command widht
      parameter DATA_SZ = 8)           // data widht              
    (CLK, RST_n, I_SCL, I_RS_PR_SCL, I_FL_PR_SCL, I_EN, I_ADDR, I_RW, I_DATA_WR, I_SDA, 
     O_DATA_RD, O_ACK_FL, O_BUSY, 
     O_SCL, O_SDA);
     

//--------------------------------------------------------------------------      
    localparam CNT_BIT_COMM_SZ = $clog2(COMM_SZ); // command bit counter widht
    localparam CNT_BIT_DATA_SZ = $clog2(DATA_SZ); // data bit counter widht   
//  description states FSM
    localparam ST_SZ    = 9; // number of states FSM
    (* syn_encoding = "one-hot" *) reg [ST_SZ-1:0] st; // current state of FSM
    localparam IDLE     = 0; // default state
    localparam START    = 1; // I2C bus start 
    localparam COMM_SLV = 2; // trasmitter command to slave
    localparam ACK_COMM = 3; // acknowledge bit command from slave
    localparam WR       = 4; // writing data from master to slave
    localparam ACK_DATA = 5; // acknowledge bit data from slave 
    localparam RD       = 6; // reading data from slave to master
    localparam MSTR_ACK = 7; // acknowledge bit data from master                   
    localparam STOP     = 8; // I2C bus stop     
//  input signals
    input wire               CLK;         // clock 50 MHz
    input wire               RST_n;       // asynchronous reset_n
    input wire               I_SCL;       // serial clock from i2c_clk_div
    input wire               I_RS_PR_SCL; // rising edge o_prev_scl for sda
    input wire               I_FL_PR_SCL; // falling edge o_prev_scl for sda      
    input wire               I_EN;        // I2C bus enable signal from cpu
    input wire [ADDR_SZ-1:0] I_ADDR;      // address of slave
    input wire               I_RW;        // read or write command   
    input wire [DATA_SZ-1:0] I_DATA_WR;   // data to write to the slave
    input wire               I_SDA;       // serial data from slave
//  output signals
    output reg [DATA_SZ-1:0] O_DATA_RD; // readed data from the slave 
    output reg               O_ACK_FL;  // flag in case of error
    output reg               O_BUSY;    // master busy signal
    output reg               O_SCL;     // serial clock  I2C bus
    output reg               O_SDA;     // serial data I2C bus to slave
//  internal signals 
    reg [ST_SZ-1:0]           nx_st;           // next state of FSM 
    reg [COMM_SZ-1:0]         comm_slv;        // latched address and read/write
    reg [COMM_SZ-1:0]         nx_comm_slv;     // next latched address and read/write 
    reg [COMM_SZ-1:0]         sh_reg;          // shift reg
    reg [COMM_SZ-1:0]         nx_sh_reg;       // shift reg
    reg [DATA_SZ-1:0]         data_wr;         // latched data for writing to slave
    reg [DATA_SZ-1:0]         nx_data_wr;      // next latched data for writing to slave 
    reg                       data_o_sda;      // data for SDA transmitting 
    reg                       nx_data_o_sda;   // next data for SDA transmitting
    wire                      nx_o_scl;        // next serial clock  I2C bus
    reg [CNT_BIT_COMM_SZ-1:0] cnt_bit_comm;    // command bit counter
    reg [CNT_BIT_COMM_SZ-1:0] nx_cnt_bit_comm; // next command bit counter
    reg [CNT_BIT_DATA_SZ-1:0] cnt_bit_data;    // data bit counter
    reg [CNT_BIT_DATA_SZ-1:0] nx_cnt_bit_data; // next data bit counter
    reg                       en_o_scl;        // enables I_SCL to output in I2C bus
    reg                       nx_en_o_scl;     // next enables I_SCL to output in I2C bus
    reg [DATA_SZ-1:0]         nx_o_data_rd;    // next reading data from the slave
    reg [DATA_SZ-1:0]         buff_rd;         // slave data buffer
    reg [DATA_SZ-1:0]         nx_buff_rd;      // slave data buffer
    reg                       nx_o_ack_fl;     // next flag acknowledge from slave (if hight, error)
    reg                       nx_o_busy;       // next master busy signal    
    
//  determining next state of FSM and signals
    assign nx_o_scl = (en_o_scl) ? I_SCL : 1'b1;
    always @(*) begin
      nx_st = st;
      nx_data_o_sda = O_SDA;
      nx_o_busy = O_BUSY;
      nx_o_ack_fl = O_ACK_FL;
      nx_o_data_rd = O_DATA_RD;
      nx_comm_slv = comm_slv;
      nx_sh_reg = sh_reg;
      nx_data_wr = data_wr;  
      nx_cnt_bit_comm = cnt_bit_comm;
      nx_cnt_bit_data = cnt_bit_data;         
      nx_en_o_scl = en_o_scl;
      nx_buff_rd = buff_rd;   
      begin
        case (st)    
            IDLE     : begin
                         if (I_RS_PR_SCL)
                           begin
                             nx_o_busy = 1'b0;
                             nx_cnt_bit_comm = COMM_SZ - 1'b1;
                             nx_cnt_bit_data = DATA_SZ - 1'b1;
                             if (I_EN)
                               begin
                                 nx_o_busy = 1'b1;
                                 nx_o_ack_fl = 1'b0;
                                 nx_comm_slv = {I_ADDR, I_RW};
                                 nx_sh_reg = {I_ADDR, I_RW};
                                 nx_data_wr = I_DATA_WR;
                                 nx_st = START;
                              end
                           end
                       end
            START    : begin   
                         if (I_RS_PR_SCL)
                           begin
                             nx_o_busy = 1'b1;
                             nx_data_o_sda = sh_reg[COMM_SZ-1];
                             nx_sh_reg = {sh_reg[COMM_SZ-2:0], 1'b0};
                             nx_st = COMM_SLV;
                           end
                         if (I_FL_PR_SCL)
                           begin
                             nx_data_o_sda = 1'b0;
                             nx_en_o_scl = 1'b1;                                
                           end
                       end
            COMM_SLV : begin  
                         if (I_RS_PR_SCL)
                           begin
                             nx_data_o_sda = sh_reg[COMM_SZ-1];
                             nx_sh_reg = {sh_reg[COMM_SZ-2:0], 1'b0};
                             nx_cnt_bit_comm = cnt_bit_comm - 1'b1;
                             if (&(!cnt_bit_comm))
                               begin
                                 nx_cnt_bit_comm = COMM_SZ - 1'b1;
                                 nx_data_o_sda = 1'b1;                        
                                 nx_st = ACK_COMM;
                               end
                           end
                       end
            ACK_COMM : begin
                         if (I_RS_PR_SCL)
                           begin
                             if (!comm_slv[0])
                               begin
                                 nx_data_o_sda = data_wr[DATA_SZ-1];
                                 nx_data_wr = {data_wr[DATA_SZ-2:0], 1'b0};
                                 nx_st = WR;
                               end
                             else
                               begin
                                 nx_data_o_sda = 1'b1;
                                 nx_st = RD;
                               end   
                           end
                         if (I_FL_PR_SCL)
                           begin
                             if(I_SDA) 
                               nx_o_ack_fl = 1'b1;
                             else
                               nx_o_ack_fl = 1'b0;                                
                           end
                       end
            WR       : begin
                         if (I_RS_PR_SCL)
                           begin
                             nx_o_busy = 1'b1;                    
                             nx_cnt_bit_data = cnt_bit_data - 1'b1;
                             nx_data_wr = {data_wr[DATA_SZ-2:0], 1'b0};
                             nx_data_o_sda = data_wr[DATA_SZ-1];
                             if (&(!cnt_bit_data))
                               begin
                                 nx_cnt_bit_data = DATA_SZ - 1'b1;
                                 nx_data_o_sda = 1'b1;                        
                                 nx_st = ACK_DATA;
                               end
                           end
                       end
            ACK_DATA : begin
                         if (I_RS_PR_SCL)
                           begin
                             if (I_EN)
                               begin
                                 nx_o_busy = 1'b0;
                                 nx_comm_slv = {I_ADDR, I_RW};
                                 nx_sh_reg = {I_ADDR, I_RW};
                                 if (comm_slv == {I_ADDR, I_RW})
                                   begin
                                     nx_data_o_sda = I_DATA_WR[DATA_SZ-1];
                                     nx_data_wr = {I_DATA_WR[DATA_SZ-2:0], 1'b0};
                                     nx_st = WR;   
                                   end
                                 else
                                   begin
                                     nx_data_o_sda = 1'b0;                                               
                                     nx_data_wr = I_DATA_WR;
                                     nx_st = STOP;
                                   end  
                               end
                             else
                               begin
                                 nx_data_o_sda = 1'b0;                   
                                 nx_st = STOP;
                               end
                           end
                         if (I_FL_PR_SCL)
                           begin
                             if(I_SDA) 
                               nx_o_ack_fl = 1'b1;
                             else
                               nx_o_ack_fl = 1'b0;                                   
                           end
                       end
            STOP     : begin
                         if (I_RS_PR_SCL)
                           begin
                             if (I_EN)
                               begin
                                 nx_o_busy = 1'b1;
                                 nx_st = START;
                               end
                             else
                               begin  
                                 nx_o_busy = 1'b0;
                                 nx_st = IDLE;
                               end
                           end
                         if (I_FL_PR_SCL)
                           begin
                             nx_data_o_sda = 1'b1;
                             nx_en_o_scl = 1'b0;                               
                           end
                       end
            RD       : begin
                         if (I_RS_PR_SCL)
                           begin
                             nx_o_busy = 1'b1;
                             nx_cnt_bit_data = cnt_bit_data - 1'b1;
                             if (&(!cnt_bit_data))
                               begin
                                 nx_cnt_bit_data = DATA_SZ - 1'b1;
                                 nx_o_data_rd = buff_rd;
                                 nx_st = MSTR_ACK;
                                 if (I_EN && (comm_slv == {I_ADDR, I_RW}))
                                   nx_data_o_sda = 1'b0;
                                 else 
                                   nx_data_o_sda = 1'b1;                    
                               end
                          end
                         if (I_FL_PR_SCL)
                           begin
                             nx_buff_rd = {buff_rd[DATA_SZ-2:0], I_SDA};                               
                           end
                       end                          
            MSTR_ACK : begin
                         if (I_RS_PR_SCL)
                           begin
                             if (I_EN)
                               begin
                                 nx_o_busy = 1'b0;
                                 nx_comm_slv = {I_ADDR, I_RW};
                                 nx_data_wr = I_DATA_WR;
                                 nx_sh_reg = {I_ADDR, I_RW};
                                 if (comm_slv == {I_ADDR, I_RW})
                                   begin
                                     nx_data_o_sda = 1'b1;
                                     nx_st = RD;
                                   end
                                 else
                                   begin 
                                     nx_data_o_sda = 1'b0;
                                     nx_st = STOP;
                                   end         
                               end
                             else
                               begin
                                 nx_data_o_sda = 1'b0;
                                 nx_st = STOP;
                               end  
                           end
                       end
            default  : begin
                         nx_st = IDLE;
                         nx_data_o_sda = 1'b1;
                         nx_o_busy = 1'b0;
                         nx_o_ack_fl = 1'b0;
                         nx_comm_slv = {COMM_SZ{1'b0}};
                         nx_sh_reg = {COMM_SZ{1'b0}};
                         nx_data_wr = {DATA_SZ{1'b0}};
                         nx_cnt_bit_comm = COMM_SZ - 1'b1;
                         nx_cnt_bit_data = DATA_SZ - 1'b1;
                         nx_en_o_scl = 1'b0;
                       end 
        endcase
      end
    end

//  latching the next state of FSM and signals, every clock
    always @(posedge CLK or negedge RST_n) begin
      if (!RST_n) 
        begin
          st       <= IDLE;
          O_SDA    <= 1'b1;
          O_BUSY   <= 1'b0;			 
          en_o_scl <= 1'b0;
        end
      else 
        begin
          st       <= nx_st;
          O_SDA    <= nx_data_o_sda; 
          O_BUSY   <= nx_o_busy;          
          en_o_scl <= nx_en_o_scl;
        end
    end
    always @(posedge CLK) begin
      O_SCL        <= nx_o_scl;   
      O_ACK_FL     <= nx_o_ack_fl;
      O_DATA_RD    <= nx_o_data_rd;
      comm_slv     <= nx_comm_slv;
      sh_reg       <= nx_sh_reg;
      data_wr      <= nx_data_wr;
      cnt_bit_comm <= nx_cnt_bit_comm;
      cnt_bit_data <= nx_cnt_bit_data;
      buff_rd      <= nx_buff_rd;
    end


endmodule           