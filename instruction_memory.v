    `define CHECK     4'b0001 // check chip id MPU_6050
    `define TMP_MSR   4'b0010 // measurement temperature
    `define ACCEL_MSR 4'b0011 // accelerometer Measurements 
    `define GYRO_MSR  4'b0100 // gyroscope measurements 
    `define FIFO_EN   4'b0101 // FIFO Enable for temp, gyro and accel
    `define FIFO_CNT  4'b0110 // keep track of the number of samples currently in the FIFO buffer    

// commands for MPU_6050
//
// addr rom `CHECK - reg addr 8'h75 - chip-id : This value is fixed in MPU_6050 to 0x68 and can be used to check whether communication is functioning
// addr rom `TMP_MSR - reg addr 8'h41
// addr rom `ACCEL_MSR - reg addr 8'h3B
// addr rom `GYRO_MSR - reg addr 8'h43
// addr rom `FIFO_EN - by reg addr 8'h23 write 8'hF8
// addr rom `FIFO_CNT - reg addr 8'h72

module instruction_memory
    #(parameter ADDR_ROM_SZ = 4,              // addr width in ROM 
      parameter DATA_ROM_SZ = 8)              // word width in ROM
    (CLK, I_ADDR_ROM, O_ADDR_ROM, O_DATA_ROM);
    
    
//  input signals    
    input wire                    CLK;        // clock 50 MHz
    input wire [ADDR_ROM_SZ-1:0]  I_ADDR_ROM; // word addr in ROM
//  output signals    
    output reg [DATA_ROM_SZ-1:0]  O_DATA_ROM; // word in ROM
    output wire [ADDR_ROM_SZ-1:0] O_ADDR_ROM; // word addr in ROM
//  internal signals
    reg [DATA_ROM_SZ-1:0] rom_array [0:2**ADDR_ROM_SZ-1]; // ROM array
    reg [ADDR_ROM_SZ-1:0] addr_reg; 
    
    
//-------------------------------------------------------------------------- 
    assign O_ADDR_ROM = addr_reg;
    
//  read ROM content from file
    initial begin
      $readmemh("../instruction_memory.txt", rom_array); 
    end

//  read operation  
    always @(posedge CLK) begin
      addr_reg   <= I_ADDR_ROM;
      O_DATA_ROM <= rom_array[I_ADDR_ROM];
    end
    
    
endmodule