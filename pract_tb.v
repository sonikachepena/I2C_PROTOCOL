
// Code your testbench here
// or browse Examples

`timescale 1ns / 1ps

module TEST( );
    // Testbench signals
    reg clk;
    reg rst;  
  reg mem_ready;
    reg new_d;
    reg [6:0] addr;
    reg op; // 1 - Read, 0 - Write
    reg [7:0] data_in;
    wire [7:0] data_out;
    wire busy;
    wire ack_err;
    wire done;
  // Instantiate the I2C top module (Master and Slave)
    i2c_top uut (
        .clk(clk),
        .rst(rst),
        .new_d(new_d),
        .addr(addr),
        .op(op),
        .data_in(data_in),
        .data_out(data_out),
        .busy(busy),
        .ack_err(ack_err),
      .done(done),
      .mem_ready(mem_ready)
    );
  
  // Clock generation
    always begin
        #5 clk = ~clk;  // 100 MHz clock period
    end
  // Test procedure
    initial begin
        // Initialize signals
        clk = 0;
        rst = 0;
        new_d = 0;
        addr = 7'b0;    
        op = 0;
        data_in = 8'b0;
        
        // Reset the system
        #45;
        rst = 1;  
       
      #20  rst = 0 ;  
        
        
        new_d = 1; 
      // Step 1: Write data to address 
        addr = 7'b1010110;     
        data_in = 8'b10101110;  
        op = 0;          
        #100000 new_d=0;     
        #120000;        
      // Step 2: Read data from address 
       mem_ready=0;
        op = 1;   
        addr = 7'b1010110;  
         data_in = 8'b0;  
        new_d = 1;          // Start reading
        #10000 new_d=0; 
        #120000;  
        $display("%d",data_out);     
    #1000000$finish;
  end
endmodule


