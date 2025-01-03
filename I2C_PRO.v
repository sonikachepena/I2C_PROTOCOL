// Code your design here

module master(
input clk,
input rst,
input mem_ready,
input new_d,
input [6:0] addr,
input op,// 1-r,0-w
input [7:0]data_in, 
inout sda,   
output scl,  
output [7:0] data_out,
output reg busy,done,ack_err
); 
     
reg scl_t = 0;
reg sda_t = 0;

parameter sys_freq = 100000000;  // 100 MHz
parameter  i2c_freq = 100000;    // 100khz

parameter clk_count4 = (sys_freq / i2c_freq); //1000
parameter clk_count1 = clk_count4 / 4;      //250
integer count1=0;

reg[1:0]pulse=0;

always @(posedge clk)
begin
      if(rst)begin
        pulse <= 0;
        count1 <= 0;
      end
      else if(busy == 1'b0)
      begin
        pulse <= 0;
        count1 <= 0;
      end 
      else if (count1 == clk_count1-1)
      begin
         pulse<=1;
         count1<=count1+1;
      end 
      else if (count1 == clk_count1*2-1)
      begin
          pulse<=2;
          count1<=count1+1;
      end 
      else if (count1 == clk_count1*3-1)
      begin
          pulse<=3;
          count1<=count1+1;
      end 
      else if (count1 == clk_count1*4-1)
      begin
          pulse<=0;
          count1<=0;
      end 
      else
        begin
           count1<=count1+1;
        end
end
  
reg [3:0]state;          
reg [3:0] bitcount = 0;
reg [7:0] data_addr = 0, data_tx = 0;
reg r_ack = 0;
reg [7:0] rx_data = 0;
reg sda_en = 0;


parameter IDLE = 4'b0000;
parameter START = 4'b0001;
parameter WRITE_ADDR = 4'b0010;
parameter ACK_1 = 4'b0011;
parameter WRITE_DATA = 4'b0100;
parameter ACK_2 = 4'b0101;
parameter READ_DATA = 4'b0110;
parameter STOP = 4'b0111;
parameter MASTER_ACK = 4'b1000;

always @(posedge clk)
begin
   if(rst)
     begin
      bitcount <= 0;
      data_addr <= 0;
      data_tx <= 0;
      scl_t <= 1;
      sda_t <= 1;
      state <= IDLE;
      busy  <= 1'b0;
      ack_err <= 1'b0;
      done    <= 1'b0;
     end
else
   begin 
               case(state)
               
                    IDLE:
                    begin
                          done <= 1'b0;
                          if(new_d == 1'b1)
                               begin
                               data_addr<={addr,op};
                               data_tx<=data_in;
                               busy  <= 1'b1;
                               state <= START;
                               ack_err <= 1'b0;
                               end
                           else
                               begin
                               data_addr<= 0;
                               data_tx<= 0;
                               busy<= 1'b0;
                               state<= IDLE;
                               ack_err<= 1'b0;
                               end
                     end
                  START:
                   begin
                        sda_en <= 1'b1;
                        case(pulse)
                         0: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                         1: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                         2: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                         3: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                         endcase
                             if(count1  == clk_count1*4 - 1)
                             begin
                                state <=WRITE_ADDR;
                                scl_t <= 1'b0;
                             end
                             else
                                state <= START;
                     end
                 WRITE_ADDR:
                   begin
                         sda_en<=1'b1;
                         if(bitcount<=7)
                            begin
                               case(pulse)
                                0:begin scl_t<=1'b0; end // new change
                                1:begin scl_t<=1'b0;sda_t<= data_addr[7-bitcount];end
                                2:begin scl_t<=1'b1; end
                                3:begin scl_t<=1'b1; end
                              endcase
                                if(count1 == clk_count1*4-1)
                                begin
                                  state<=WRITE_ADDR;
                                  scl_t<=1'b0;
                                  bitcount<=bitcount+1;
                                 end 
                                 else 
                                  begin
                                   state<=WRITE_ADDR;
                               end 
                        end 
                        else
                          begin 
                            state<=ACK_1;
                            bitcount <= 0;
                            sda_en <= 1'b0;
                         end
                   end   
                   
                 ACK_1:
                  begin
                        sda_en<=1'b0;
                        case(pulse)
                         0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                         1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                         2: begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <=sda; end
                         3: begin scl_t <= 1'b1;  end
                         endcase
                      if(count1 == clk_count1*4-1)begin
                           if(r_ack==1'b0 && data_addr[0]==1'b0)
                           begin 
                             state<= WRITE_DATA;
                             sda_t <= 1'b0;
                             sda_en<=1'b1;
                             bitcount<=0;
                           end 
                           else if(r_ack==1'b0 && data_addr[0]==1'b1)
                           begin
                                 state<=READ_DATA;
                                 sda_t <= 1'b1;
                                 sda_en <= 1'b0; 
                                 bitcount<=0;
                            end 
                            else 
                              begin
                                 state<=STOP;
                                 sda_en<=1'b1;
                                 ack_err<=1'b1;
                             end 
                           end 
                          else
                           begin
                            state<=ACK_1;
                         end
                 end
                 
              WRITE_DATA:
                
                begin
                   if(bitcount<=7)
                     begin
                              case(pulse)
                                0:begin scl_t<=1'b0;end
                                1:begin scl_t<=1'b0; sda_en<=1'b1;sda_t<=data_tx[7-bitcount]; end
                                2:begin scl_t<=1'b1;end
                                3:begin scl_t<=1'b1;end
                                endcase 
                                if(count1==clk_count1*4-1)
                                 begin
                                    state<=WRITE_DATA;
                                    scl_t <= 1'b0;
                                    bitcount <= bitcount + 1;
                                  end 
                                  else 
                                    begin 
                                      state<=WRITE_DATA;
                                    end
                             end 
                          else 
                             begin
                              state<=ACK_2;
                              bitcount <= 0;
                              sda_en <= 1'b0;
                            end
                    end
            
                 READ_DATA:
                  begin
                         sda_en <= 1'b0;
                          if(bitcount<=7)
                            begin
                             case(pulse)
                                0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                                1: begin scl_t <= 1'b0; sda_t <= 1'b0; end 
                                2:begin scl_t<=1'b1;  rx_data[7:0] <= (count1 == 500) ? {rx_data[6:0],sda} : rx_data; end
                                3:begin scl_t<=1'b1; end
                                endcase
                                if(count1== clk_count1*4-1)
                                  begin
                                    state<= READ_DATA;
                                    scl_t<=1'b0;
                                    bitcount<=bitcount+1;
                                 end 
                                 else
                                   begin
                                    state<=READ_DATA;
                               end
                               
                           end 
                           else
                              begin
                                state<=MASTER_ACK;
                                bitcount <= 0;
                                sda_en <= 1'b1;
                             end
                    end
                    
                 MASTER_ACK:
                   begin  
                          sda_en<=1'b1;
                     if(mem_ready==1)begin
                         
                          case(pulse)
                                 0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                                 1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                                 2: begin scl_t <= 1'b1; sda_t <= 1'b0; end 
                                 3: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                                 endcase
                     end else begin
                        case(pulse)
                                 0: begin scl_t <= 1'b0; sda_t <= 1'b1; end
                                 1: begin scl_t <= 1'b0; sda_t <= 1'b1; end
                                 2: begin scl_t <= 1'b1; sda_t <= 1'b1; end 
                                 3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                                 endcase
                     end
                       
                             if(count1==clk_count1*4-1)
                                    begin
                                        sda_t <= 1'b0; 
                                        state <= STOP;
                                        sda_en <= 1'b1;
                                     end 
                                     else 
                                       begin
                                            state<=MASTER_ACK;
                                        end
                           end
                       
                      ACK_2: 
                        begin
                             sda_en <= 1'b0;
                              case(pulse)
                               0:begin scl_t<=1'b0; sda_t<=1'b0;end
                               1:begin scl_t<=1'b0; sda_t<=1'b0;end
                               2:begin scl_t<=1'b1; sda_t<=1'b0; r_ack<=sda; end
                               3: begin scl_t <= 1'b1;  end
                               endcase
                            if(count1  == clk_count1*4 - 1)
                              begin
                                sda_t <= 1'b0;
                                sda_en <= 1'b1;
                                if(r_ack == 1'b0)
                                     begin
                                      state <=STOP;
                                      ack_err <= 1'b0;
                                     end 
                                     else
                                      begin
                                      state <= STOP;
                                      ack_err <= 1'b1;
                                  end
                             end 
                             else 
                                begin 
                                   state<=ACK_2;
                                end 
                    end
                 
              STOP: 
                begin 
                       sda_en <= 1'b1; 
                       case(pulse)
                         0: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                         1: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                         2: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                         3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                         endcase
                    if(count1 ==clk_count1*4-1)begin
                              state <= IDLE;
                              scl_t <= 1'b0;
                              busy <= 1'b0;
                              sda_en<=1'b1;
                              done<=1'b1;
                         end 
                           else 
                              state<=STOP;
                   end
                default:  state<=IDLE;
                    
          endcase
              
    end
end
                   
assign sda=(sda_en==1)?(sda_t==0)?1'b0:1'b1:1'bz;
assign scl=scl_t;
assign data_out=rx_data;
              
endmodule

//HERE I AM WRITING CODE FOR SLAVE

module slave(
input clk,
input rst,
inout sda,
input scl,
output reg ack_err,done
);
   
parameter IDLE = 4'b0000;
parameter READ_ADDR = 4'b0001;
parameter SEND_ACK1 = 4'b0010;
parameter SEND_DATA = 4'b0011;
parameter READ_DATA = 4'b0100;
parameter SEND_ACK2 = 4'b0101;
parameter MASTER_ACK = 4'b0110;
parameter WAIT_P = 4'b0111;
parameter STOP = 4'b1000;

reg [7:0] mem[127:0];
reg [7:0] r_addr;
reg sda_t;
reg [6:0] addr;
reg r_mem = 0;
reg w_mem = 0;
reg [7:0] data_out;
reg [7:0] data_in;
reg [3:0]state;
reg sda_en;
reg [3:0] bitcount = 0;
integer i;
always@(posedge clk)
begin
   if(rst)
   begin
      for( i = 0 ; i < 128; i=i+1)
         begin
         mem[i] = i;
       end
      data_out <= 8'b0;
  end 
   else if (r_mem == 1'b1)
     begin
       data_out <= mem[addr];
    end
     else if (w_mem == 1'b1)
      begin
        mem[addr] <= data_in;
   end  
end
parameter sys_freq = 100000000;  // 100 MHz
parameter i2c_freq = 100000;     // 100k

parameter clk_count4 = (sys_freq / i2c_freq); 
parameter clk_count1 = clk_count4 / 4;      
integer count1=0;
reg busy;
reg[1:0]pulse=0;

always @(posedge clk)
begin
    if(rst)
     begin
      pulse <= 0;
      count1 <= 0;
    end 
    else if(busy == 1'b0)
    begin
         pulse <= 2;
         count1 <= 502;
    end 
    else if (count1 == clk_count1*1-1)
    begin
         pulse<=1;
         count1<=count1+1;
    end 
    else if (count1 == clk_count1*2-1)
     begin
          pulse<=2;
          count1<=count1+1;
    end 
     else if (count1 == clk_count1*3-1)
     begin
          pulse<=3;
          count1<=count1+1;
     end 
     else if (count1 == clk_count1*4-1)
     begin
          pulse<=0;
          count1<=0;
     end 
     else 
       begin
       count1<=count1+1;
   end
 end

reg r_ack;

always @(posedge clk)
begin
    if(rst)
     begin
          bitcount<=0;
          state<=IDLE;
          r_addr<=7'b0;
          sda_en<=1'b0;
          sda_t<=1'b0;
          addr<=0;
          r_mem<=0;
          data_in<=8'b0;
          ack_err <=0;
          done <= 1'b0;
          busy <= 1'b0;
     end 
      else 
        begin
          case(state)
              IDLE:
               begin
                 if(scl == 1'b1 && sda == 1'b0)
                     begin
                     busy <= 1'b1;
                     state <= WAIT_P; 
                  end 
                   else 
                    begin
                      state <= IDLE;
                   end
               end
              WAIT_P:begin
                  if (pulse == 2'b11 && count1 == 999)
                        state<=READ_ADDR;
                  else 
                         state<=WAIT_P;
                     
               end
              READ_ADDR:
               begin
                      sda_en <= 1'b0;
                      if(bitcount<=7)
                        begin
                         case(pulse)
                             0: begin end
                             1:begin end
                           2:begin r_addr<=(count1 == 500) ?{r_addr[6:0],sda}:r_addr; end
                             3: begin  end
                          endcase
                          if(count1  == clk_count1*4 - 1)
                               begin
                                     state <= READ_ADDR;
                                     bitcount <= bitcount + 1;
                                end
                                else 
                                  begin
                                   state <=READ_ADDR;
                            end
                       end 
                       else 
                        begin
                             state<=SEND_ACK1;
                             bitcount <= 0;
                             sda_en <= 1'b1;
                             addr <= r_addr[7:1];
                       end
                 end
                   
                 SEND_ACK1:begin
                        case(pulse)
                             0: begin    sda_t <= 1'b0; end
                             1: begin   end
                             2: begin  end
                             3: begin  end
                         endcase
                         if(count1  == clk_count1*4 - 1)
                             begin
                                if(r_addr[0] == 1'b1)
                                    begin
                                    state <= SEND_DATA;
                                    r_mem <= 1'b1;
                                end 
                                 else 
                                     begin
                                     state <= READ_DATA;
                                     r_mem <= 1'b0;
                                 end
                             end 
                            else 
                               begin
                                  state <= SEND_ACK1;
                          end
                    end
                    READ_DATA:begin
                            sda_en <= 1'b0;
                            if(bitcount<=7)
                              begin
                               case(pulse)
                                 0: begin end
                                 1:begin end  
                                 2:begin  data_in <= (count1 == 500) ? {data_in[6:0],sda} : data_in; end 
                                 3: begin  end
                               endcase
                               if(count1== clk_count1*4-1)
                                   begin
                                   state <= READ_DATA;
                                   bitcount <= bitcount + 1;
                                end 
                                else 
                                 begin
                                    state<=READ_DATA;
                                 end
                            end 
                            else 
                            begin
                                state  <= SEND_ACK2;
                                bitcount <= 0;
                                sda_en <= 1'b1;
                                w_mem  <= 1'b1;
                              end
                      end
                      SEND_ACK2:  begin        
                         case(pulse)
                            0: begin  sda_t <= 1'b0; end
                            1: begin  w_mem <= 1'b0; end
                            2: begin  end 
                            3: begin  end
                          endcase
                          if(count1  == clk_count1*4 - 1)
                              begin
                                     state <=STOP;
                                     sda_en <= 1'b0;
                            end 
                            else 
                              begin
                                 state <= SEND_ACK2;
                           end
                     end
                     SEND_DATA: begin
                              sda_en <= 1'b1;
                              if(bitcount <= 7)
                                begin
                                   r_mem  <= 1'b0;
                                 case(pulse)
                                   0: begin   end
                                   1: begin  sda_t <= (count1 == 250) ? data_out[7 - bitcount] : sda_t; end
                                   2: begin    end 
                                   3: begin    end
                                endcase
                                if(count1  == clk_count1*4 - 1)
                                  begin
                                      state <= SEND_DATA;
                                      bitcount <= bitcount + 1;
                                 end 
                                 else 
                                    begin
                                        state <=SEND_DATA;
                                   end
                                     
                             end 
                              else 
                              begin
                                state  <= MASTER_ACK;
                                bitcount <= 0;
                                sda_en <= 1'b0;
                             end
                       end  
                      MASTER_ACK: begin
                         case(pulse)
                            0: begin  end
                            1: begin  end
                            2: begin r_ack <= (count1 == 500) ? sda : r_ack; end 
                            3: begin  end
                          endcase
                          if(count1  == clk_count1*4 - 1)
                             begin
                              if(r_ack == 1'b1) 
                                    begin
                                    ack_err <= 1'b1;
                                    state <= STOP;
                                     sda_en <= 1'b0;
                               end 
                                else 
                                 begin
                                     ack_err <= 1'b0;
                                     state   <= STOP;
                                      sda_en <= 1'b0;
                                   end
                           end 
                           else 
                             begin
                                state <=MASTER_ACK;
                            end
                       end
                       STOP:begin
                          if(pulse==2'b11 && count1==999)begin
                               state<=IDLE;
                               busy <= 1'b0;
                               done <= 1'b1;
                          end 
                          else 
                             
                                state<=STOP;
                       end
                     default: state<=IDLE;
                              
                    endcase
                end
            end
 assign sda = (sda_en == 1'b1) ? sda_t : 1'bz;      
       
endmodule

//HERE I AM WRITING TOP MODULE FOR I2C PROTOCOL
 module i2c_top(
 input clk,
 input rst,
  input mem_ready,
 input new_d,      
 input [6:0]addr,
 input op,// 1-r,0-w
 input [7:0]data_in, 
 output [7:0]data_out,
 output busy,
 output ack_err,
 output done
);

wire sda,scl;
wire ack_errm,ack_errs;
wire done_m,done_s;

// HERE I AM INSTANTIATEING THE MASTER MODULE
        master master_u(
              .clk(clk),
              .rst(rst),
              .data_in(data_in),
              .addr(addr),
              .op(op),
              .data_out(data_out),
              .busy(busy),
              .ack_err(ack_errm),
              .new_d(new_d),
              .sda(sda),
          .mem_ready(mem_ready),
              .scl(scl),
          .done(done_m)
              );
         slave slave_u(
               .scl(scl),
               .sda(sda),
               .clk(clk),
               .rst(rst),
               .ack_err(ack_errs),
               .done(done_s)
               );
               
assign ack_err= ack_errm | ack_errs;
assign done= done_m | done_s; //NEW CHANGE
            
endmodule
