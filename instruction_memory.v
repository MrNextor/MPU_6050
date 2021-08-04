module instruction_memory
    #(parameter ADDR_ROM_SZ = 4,  // addr width in ROM 
      parameter DATA_ROM_SZ = 16) // word width in ROM
    (CLK, I_ADDR_ROM_A, I_ADDR_ROM_B, 
     O_DATA_ROM_A, O_DATA_ROM_B, O_ADDR_ROM_A, O_ADDR_ROM_B);
    
    
//  input signals    
    input wire                    CLK;        // clock 50 MHz
    input wire [ADDR_ROM_SZ-1:0]  I_ADDR_ROM_A; // word A addr in ROM
    input wire [ADDR_ROM_SZ-1:0]  I_ADDR_ROM_B; // word B addr in ROM    
//  output signals    
    output reg [DATA_ROM_SZ-1:0]  O_DATA_ROM_A; // word A in ROM
    output reg [DATA_ROM_SZ-1:0]  O_DATA_ROM_B; // word B in ROM    
    output wire [ADDR_ROM_SZ-1:0] O_ADDR_ROM_A; // word A addr in ROM
    output wire [ADDR_ROM_SZ-1:0] O_ADDR_ROM_B; // word B addr in ROM    
//  internal signals
    reg [DATA_ROM_SZ-1:0] rom_array [0:2**ADDR_ROM_SZ-1]; // ROM array
    reg [ADDR_ROM_SZ-1:0] addr_reg_a;
    reg [ADDR_ROM_SZ-1:0] addr_reg_b; 
    
//-------------------------------------------------------------------------- 
    assign O_ADDR_ROM_A = addr_reg_a;
    assign O_ADDR_ROM_B = addr_reg_b;
    
//  read ROM content from file
    initial begin
      $readmemh("../instruction_memory.txt", rom_array); 
    end

//  read operation  
    always @(posedge CLK) begin
      addr_reg_a   <= I_ADDR_ROM_A;
      addr_reg_b   <= I_ADDR_ROM_B;
      O_DATA_ROM_A <= rom_array[I_ADDR_ROM_A];
      O_DATA_ROM_B <= rom_array[I_ADDR_ROM_B];
    end
    
    
endmodule