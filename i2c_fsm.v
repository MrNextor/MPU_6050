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
    localparam ST_SZ    = 9;            // number of states FSM
    localparam IDLE     = 9'b000000001; // default state
    localparam START    = 9'b000000010; // I2C bus start 
    localparam COMM_SLV = 9'b000000100; // trasmitter command to slave
    localparam ACK_COMM = 9'b000001000; // acknowledge bit command from slave
    localparam WR       = 9'b000010000; // writing data from master to slave
    localparam ACK_DATA = 9'b000100000; // acknowledge bit data from slave 
    localparam RD       = 9'b001000000; // reading data from slave to master
    localparam MSTR_ACK = 9'b010000000; // acknowledge bit data from master                   
    localparam STOP     = 9'b100000000; // I2C bus stop              
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
    reg [ST_SZ-1:0]           st;              // current state of FSM 
    reg [ST_SZ-1:0]           nx_st;           // next state of FSM 
    reg [COMM_SZ-1:0]         comm_slv;        // latched address and read/write
    reg [COMM_SZ-1:0]         nx_comm_slv;     // next latched address and read/write      
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
      nx_data_o_sda = O_SDA;
      nx_st = st;
      nx_comm_slv = comm_slv;
      nx_data_wr = data_wr;  
      nx_o_data_rd = O_DATA_RD;
      nx_cnt_bit_comm = cnt_bit_comm;
      nx_cnt_bit_data = cnt_bit_data;         
      nx_o_busy = O_BUSY;
      nx_en_o_scl = en_o_scl;
      nx_o_ack_fl = O_ACK_FL;
      nx_buff_rd = buff_rd;   
      if (I_RS_PR_SCL)
        begin
            case (st)    
                IDLE     : begin 
                             nx_o_busy = 1'b0;
                             nx_comm_slv = {ADDR_SZ{1'b0}};
                             nx_data_wr = {DATA_SZ{1'b0}};
                             nx_cnt_bit_comm = COMM_SZ - 1'b1;
                             nx_cnt_bit_data = DATA_SZ - 1'b1;
                             nx_buff_rd = {DATA_SZ{1'b0}};                                       
                             if (I_EN)
                                 begin
                                   nx_o_busy = 1'b1;
                                   nx_o_ack_fl = 1'b0;
                                   nx_comm_slv = {I_ADDR, I_RW};
                                   nx_data_wr = I_DATA_WR;
                                   nx_o_data_rd = {DATA_SZ{1'b0}};
                                   nx_st = START;
                                end
                           end
                START    : begin   
                             nx_st = COMM_SLV;
                             nx_data_o_sda = comm_slv[COMM_SZ-1];
                             nx_o_busy = 1'b1;
                           end
                COMM_SLV : begin  
                             nx_cnt_bit_comm = cnt_bit_comm - 1'b1;
                             nx_data_o_sda = comm_slv[cnt_bit_comm-1];
                             if (&(!cnt_bit_comm))
                               begin
                                 nx_cnt_bit_comm = COMM_SZ - 1'b1;
                                 nx_data_o_sda = 1'b1;                        
                                 nx_st = ACK_COMM;
                               end
                           end
                ACK_COMM : begin
                             if (!comm_slv[0])
                               begin
                                 nx_st = WR;
                                 nx_data_o_sda = data_wr[DATA_SZ-1]; 
                               end
                             else
                               begin
                                 nx_st = RD;
                                 nx_data_o_sda = 1'b1;
                               end   
                           end
                WR       : begin
                             nx_o_busy = 1'b1;                    
                             nx_cnt_bit_data = cnt_bit_data - 1'b1;
                             nx_data_o_sda = data_wr[cnt_bit_data-1];
                             if (&(!cnt_bit_data))
                               begin
                                 nx_cnt_bit_data = DATA_SZ - 1'b1;
                                 nx_st = ACK_DATA;
                                 nx_data_o_sda = 1'b1;                        
                               end
                           end
                ACK_DATA : begin
                             if (I_EN)
                               begin
                                 nx_o_busy = 1'b0;
                                 nx_comm_slv = {I_ADDR, I_RW};
                                 nx_data_wr = I_DATA_WR;
                                 if (comm_slv == {I_ADDR, I_RW})
                                   begin
                                     nx_data_o_sda = I_DATA_WR[DATA_SZ-1];
                                     nx_st = WR;   
                                   end
                                 else
                                   begin
                                     nx_st = STOP;
                                     nx_data_o_sda = 1'b0;                                               
                                   end  
                               end
                             else
                               begin
                                 nx_st = STOP;
                                 nx_data_o_sda = 1'b0;                   
                               end
                           end
                STOP     : begin
                             if (I_EN)
                               begin
                                 nx_st = START;
                                 nx_o_busy = 1'b1;
                               end
                             else
                               begin  
                                 nx_st = IDLE;
                                 nx_o_busy = 1'b0;
                               end
                           end
                RD       : begin
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
                MSTR_ACK : begin
                             if (I_EN)
                               begin
                                 nx_o_busy = 1'b0;
                                 nx_comm_slv = {I_ADDR, I_RW};
                                 nx_data_wr = I_DATA_WR;
                                 if (comm_slv == {I_ADDR, I_RW})
                                   begin
                                     nx_st = RD;
                                     nx_data_o_sda = 1'b1;
                                   end
                                 else
                                   begin 
                                     nx_st = STOP;
                                     nx_data_o_sda = 1'b0;
                                   end         
                               end
                             else
                               begin
                                 nx_st = STOP;
                                 nx_data_o_sda = 1'b0;
                               end  
                           end
                default  : begin
                             nx_st = IDLE;
                             nx_o_busy = 1'b0;
                             nx_comm_slv = {COMM_SZ{1'b0}};
                             nx_data_wr = {DATA_SZ{1'b0}};
                             nx_data_o_sda = 1'b1;
                             nx_cnt_bit_comm = COMM_SZ - 1'b1;
                             nx_cnt_bit_data = DATA_SZ - 1'b1;
                             nx_o_ack_fl = 1'b0;
                           end 
            endcase
        end
      else if (I_FL_PR_SCL)
        begin
            case (st)
                START    : begin 
                             nx_data_o_sda = 1'b0;
                             nx_en_o_scl = 1'b1;               
                           end
                ACK_COMM : begin
                             if(I_SDA) 
                               nx_o_ack_fl = 1'b1;
                             else
                               nx_o_ack_fl = 1'b0;      
                           end                  
                ACK_DATA : begin
                             if(I_SDA) 
                               nx_o_ack_fl = 1'b1;
                             else
                               nx_o_ack_fl = 1'b0;                 
                           end                  
                RD       :     nx_buff_rd[cnt_bit_data] = I_SDA;       
                STOP     : begin
                             nx_data_o_sda = 1'b1;
                             nx_en_o_scl = 1'b0;
                           end
                default  :   nx_en_o_scl = en_o_scl;    
            endcase
        end     
    end
            
//  latching the next state of FSM and signals, every clock
    always @(posedge CLK or negedge RST_n) begin
      if (!RST_n) 
        begin
          st       <= IDLE;
          en_o_scl <= 1'b0;
          O_SDA    <= 1'b1;
          O_BUSY   <= 1'b0;			 
        end
      else 
        begin
          st       <= nx_st;
          en_o_scl <= nx_en_o_scl;
          O_SDA    <= nx_data_o_sda; 
          O_BUSY   <= nx_o_busy;          
        end
    end
    always @(posedge CLK) begin
      comm_slv     <= nx_comm_slv;
      data_wr      <= nx_data_wr;
      cnt_bit_comm <= nx_cnt_bit_comm;
      cnt_bit_data <= nx_cnt_bit_data;
      O_ACK_FL     <= nx_o_ack_fl;
      O_DATA_RD    <= nx_o_data_rd;
      buff_rd      <= nx_buff_rd;
      O_SCL        <= nx_o_scl;   
    end


endmodule           