module i2c_clk_div
    #(parameter FPGA_CLK = 50_000_000, // FPGA frequency 50 MHz
      parameter I2C_CLK  = 100_000)    // I2C bus frequency 100 KHz                   
    (CLK, RST_n, 
     O_SCL, O_RS_PR_SCL, O_FL_PR_SCL);
    
    
//--------------------------------------------------------------------------     
    localparam DIV_CLK     = (FPGA_CLK / I2C_CLK); // the I2C bus frequency
    localparam DIV_CLK_1_4 = DIV_CLK / 4;          // 1/4 of the I2C bus frequency
    localparam DIV_WIDTH   = $clog2(DIV_CLK);      // counter widht for div 
//  input signals    
    input wire          CLK;                       // clock 50 MHz
    input wire          RST_n;                     // asynchronous reset_n
//  output signals
    output reg          O_SCL;                     // serial clock from i2c_clk_div
    output reg          O_RS_PR_SCL;               // rising edge o_prev_scl for sda
    output reg          O_FL_PR_SCL;               // falling edge o_prev_scl for sda
//  internal signals    
    reg [DIV_WIDTH-1:0] cnt_clk;                   // counter clock
    reg [DIV_WIDTH-1:0] nx_cnt_clk;                // next counter clock                 
    wire                nx_o_scl;                  // next serial clock from i2c_clk_div      
    wire                nx_o_rs_pr_scl;            // next rising edge next_o_prev_scl for sda
    wire                nx_o_fl_pr_scl;            // next falling edge next_o_prev_scl for sda

//  determining output signals next state 
    assign nx_o_rs_pr_scl = (cnt_clk == DIV_CLK_1_4 - 1'b1) ? 1'b1 : 1'b0;
    assign nx_o_fl_pr_scl = (cnt_clk == DIV_CLK_1_4 * 3 - 1'b1) ? 1'b1 : 1'b0;
    assign nx_o_scl       = ((cnt_clk >= DIV_CLK_1_4 * 2 - 1'b1) && (cnt_clk < DIV_CLK - 1'b1)) ? 1'b1 : 1'b0;   
        
//  latching next state counter and output signals
    always @(posedge CLK or negedge RST_n) begin
      if (!RST_n)
        begin
          cnt_clk     <= {DIV_WIDTH{1'b0}};
          O_SCL       <= 1'b0;
          O_RS_PR_SCL <= 1'b0;
          O_FL_PR_SCL <= 1'b0;
        end
      else
        begin
          if (cnt_clk == DIV_CLK - 1'b1)
            cnt_clk   <= {DIV_WIDTH{1'b0}};
          else 
            cnt_clk   <= cnt_clk + 1'b1; 
//------------------------------------------------------            
          O_SCL       <= nx_o_scl;
          O_RS_PR_SCL <= nx_o_rs_pr_scl;
          O_FL_PR_SCL <= nx_o_fl_pr_scl;
        end
    end

    
endmodule