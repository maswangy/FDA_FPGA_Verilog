`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    11:50:30 01/08/2014 
// Design Name: 
// Module Name:    DataStorage 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module DataStorage(
    input [31:0] DataIn,
    output [7:0] DataOut,
    input WriteStrobe,
    input ReadEnable,
    input WriteClock,
    input WriteClockDelayed,
    input ReadClock,
    input Reset,
    output DataValid,
    output FifoNotFull,
    output DataReadyToSend,
	 output [1:0] State
    ); 

wire FifoReadEn;
wire SideFull, TopFull, BottomFull; 
wire SideEmpty, TopEmpty, BottomEmpty;
wire SideValid, TopValid, BottomValid;
wire [31:0] FifoDataOut;	//This data is in chronological order: [31:25] is DQD (oldest), 
									// [24:16] is DID, [8:15] is DQ, [7:0] is DI 
wire ConverterWriteEn, ConverterFull, ConverterEmpty, ConverterValid;
wire FifosValid = (SideValid && TopValid && BottomValid);
wire FifosEmpty = (SideEmpty && TopEmpty && BottomEmpty);
wire FifosFull = (SideFull || TopFull || BottomFull);	
reg StoringData;
assign FifoNotFull = (~CurrentState[1]);
assign DataReadyToSend = ~ConverterEmpty;

localparam 	READY_TO_STORE = 2'b00,
				STORING_DATA = 2'b01,
				SENDING_DATA = 2'b10;

reg [1:0] CurrentState = SENDING_DATA;
reg [1:0] NextState = SENDING_DATA;

assign State = CurrentState;

reg [1:0] WriteEnableEdge = 2'b00;
assign WriteEnable = (CurrentState == STORING_DATA);


always@(posedge ReadClock) begin
	if(Reset) begin
		CurrentState <= READY_TO_STORE;
		WriteEnableEdge <= 2'b00;
	end
	else begin
		CurrentState <= NextState;		
		WriteEnableEdge <= {WriteEnableEdge[0], WriteStrobe};
	end
end

always@(*) begin
	NextState = CurrentState;
	case (CurrentState)
		READY_TO_STORE: begin
			if(WriteEnableEdge == 2'b01) NextState = STORING_DATA;
		end
		STORING_DATA:begin
			if(FifosFull) NextState = SENDING_DATA;
		end
		SENDING_DATA:begin
			if(ConverterEmpty) NextState = READY_TO_STORE;
		end
	endcase
end


FIFO_11bit FIFO_Side_Inputs (
  .rst(Reset), // input rst
  .wr_clk(WriteClock), // input wr_clk
  .rd_clk(ReadClock), // input rd_clk
  .din({DataIn[31:26], DataIn[15:11]}), // input [10 : 0] din
  .wr_en(WriteEnable), // input wr_en
  .rd_en(FifoReadEn), // input rd_en
  .dout({FifoDataOut[7:2], FifoDataOut[15:11]}), // output [10 : 0] dout
  .full(SideFull), // output full
  .empty(SideEmpty), // output empty
  .valid(SideValid) // output valid
);

FIFO_11bit FIFO_Bottom_Inputs (
  .rst(Reset), // input rst
  .wr_clk(WriteClockDelayed), // input wr_clk
  .rd_clk(ReadClock), // input rd_clk
  .din(DataIn[10:0]), // input [10 : 0] din
  .wr_en(WriteEnable), // input wr_en
  .rd_en(FifoReadEn), // input rd_en
  .dout({FifoDataOut[10:8], FifoDataOut [31:24]}), // output [10 : 0] dout
  .full(BottomFull), // output full
  .empty(BottomEmpty), // output empty
  .valid(BottomValid) // output valid
);

FIFO_10bit FIFO_Top_Inputs (
  .rst(Reset), // input rst
  .wr_clk(WriteClockDelayed), // input wr_clk
  .rd_clk(ReadClock), // input rd_clk
  .din(DataIn[25:16]), // input [9 : 0] din
  .wr_en(WriteEnable), // input wr_en
  .rd_en(FifoReadEn), // input rd_en\
  .dout({FifoDataOut[1:0], FifoDataOut[23:16]}), // output [9 : 0] dout
  .full(TopFull), // output full
  .empty(TopEmpty), // output empty
  .valid(TopValid) // output valid
);

wire ConverterAlmostFull;
assign FifoReadEn = (~ConverterAlmostFull &&  ~FifosEmpty);	// Read from FIFOs when the converter is not full and the FIFOs are not empty
reg [31:0] FirstWord = 32'b11111111100000000111111100000000;
wire [31:0] dwcInput;
wire dwcWrEn;

//These assignments should mean that the first 4 bytes are the signature "FirstWord" to denote the start of data transfer
assign dwcInput = (WriteEnableEdge == 2'b01) ? FirstWord : FifoDataOut[31:0];
assign dwcWrEn =  (WriteEnableEdge == 2'b01) ? 1'b1 : FifosValid;

FIFO_32to8 DataWidthConverter (
  .rst(Reset), // input rst
  .wr_clk(ReadClock), // input wr_clk
  .rd_clk(ReadClock), // input rd_clk
  .din(dwcInput), // input [31 : 0] din
  .wr_en(dwcWrEn), // input wr_en
  .rd_en(ReadEnable), // input rd_en
  .dout(DataOut), // output [7 : 0] dout
  .full(ConverterFull), // output full
  .almost_full(ConverterAlmostFull),
  .empty(ConverterEmpty), // output empty
  .valid(DataValid) // output valid
);

endmodule
