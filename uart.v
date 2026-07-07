//=========================================================================
// Copyright (c) 2026 Huzaifa
//=========================================================================
//
// FILE NAME    : uart.v
// PROJECT      : FPGA-Based UART Transmitter and Receiver
// TYPE         : RTL Design (FSM-Based)
// LANGUAGE     : Verilog HDL
//
// UNIVERSITY   : National University of Sciences and Technology (NUST)
// DEPARTMENT   : Electrical Engineering
//
// AUTHOR       : Huzaifa
// EMAIL        : huzaifa.e19@gmail.com
//
//==========================================================================
//
// RELEASE HISTORY
//
// VERSION   DATE         AUTHOR      DESCRIPTION
// -------   ----------   ----------  --------------------------------------
// 1.0       07-Jul-2026  Huzaifa     Initial project release
//
//==========================================================================
//
// KEYWORDS
// UART, Serial Communication, Verilog HDL, FPGA, RTL Design,
// FSM, UART Transmitter, UART Receiver, Asynchronous Communication
//
//==========================================================================
//
// PURPOSE
// This project implements a synthesizable Universal Asynchronous Receiver
// Transmitter (UART) using Verilog HDL. The design integrates independent
// transmitter and receiver modules based on Finite State Machines (FSMs)
// and is intended for FPGA implementation.
//
// Features:
//   • UART Transmission (8-N-1)
//   • UART Reception (8-N-1)
//   • Independent TX and RX FSMs
//   • Baud Rate Generator
//   • Start Bit Detection
//   • Mid-Bit Sampling
//   • Stop Bit Verification
//   • Data Valid Flag
//   • Busy Status Indication
//   • Synthesizable RTL Design
//
//==========================================================================

module uart(
    input clk,
    input reset,
    // UART Pins
    input  rx,
    output reg tx,
    // Transmitter Interface
    input  [7:0] datain,
    input  txstart,
    output reg txbusy,
    // Receiver Interface
    output reg [7:0] dataout,
    output reg data_valid
);


// PARAMETERS

localparam BAUD_MAX      = 13'd5207;
localparam HALF_BAUD_MAX = 13'd2603;


// FSM STATES

localparam IDLE  = 2'b00,
           START = 2'b01,
           DATA  = 2'b10,
           STOP  = 2'b11;


// TRANSMITTER


// Registers
reg [1:0] tx_state, tx_next_state;
reg [2:0] tx_bitcount;
reg [7:0] tx_shiftreg;

reg [12:0] tx_baudcount;
reg tx_baudenable;

// Baud Tick
wire tx_baudtick = (tx_baudcount == BAUD_MAX);


// Baud Counter

always @(posedge clk or posedge reset)
begin
    if(reset)
        tx_baudcount <= 0;
    else if(!tx_baudenable)
        tx_baudcount <= 0;
    else if(tx_baudtick)
        tx_baudcount <= 0;
    else
        tx_baudcount <= tx_baudcount + 1'b1;
end


// State Register

always @(posedge clk or posedge reset)
begin
    if(reset)
        tx_state <= IDLE;
    else
        tx_state <= tx_next_state;
end


// Next State Logic

always @(*)
begin
    tx_next_state = tx_state;

    case(tx_state)

        IDLE:
            if(txstart)
                tx_next_state = START;

        START:
            if(tx_baudtick)
                tx_next_state = DATA;

        DATA:
            if(tx_baudtick && tx_bitcount==3'd7)
                tx_next_state = STOP;

        STOP:
            if(tx_baudtick)
                tx_next_state = IDLE;

        default:
            tx_next_state = IDLE;

    endcase
end

// Datapath

always @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        tx_shiftreg   <= 0;
        tx_bitcount   <= 0;
        tx_baudenable <= 0;
    end
    else
    begin
        case(tx_state)

            IDLE:
            begin
                tx_bitcount <= 0;

                if(txstart)
                begin
                    tx_shiftreg   <= datain;
                    tx_baudenable <= 1'b1;
                end
            end

            DATA:
            begin
                if(tx_baudtick)
                begin
                    tx_shiftreg <= {1'b0,tx_shiftreg[7:1]};
                    tx_bitcount <= tx_bitcount + 1'b1;
                end
            end

            STOP:
            begin
                if(tx_baudtick)
                    tx_baudenable <= 1'b0;
            end

        endcase
    end
end


// TX Output

always @(*)
begin
    case(tx_state)

        IDLE  : tx = 1'b1;
        START : tx = 1'b0;
        DATA  : tx = tx_shiftreg[0];
        STOP  : tx = 1'b1;
        default : tx = 1'b1;

    endcase
end


// TX Busy

always @(*)
begin
    txbusy = (tx_state != IDLE);
end


// RECEIVER


// Registers
reg [1:0] rx_state, rx_next_state;
reg [2:0] rx_bitcount;
reg [7:0] rx_shiftreg;

reg [12:0] rx_baudcount;
reg rx_baudenable;

// Baud Tick
wire rx_baudtick = (rx_baudcount == BAUD_MAX);
wire rx_halftick = (rx_baudcount == HALF_BAUD_MAX);


// Baud Counter
always @(posedge clk or posedge reset)
begin
    if(reset)
        rx_baudcount <= 0;

    else if(!rx_baudenable)
        rx_baudcount <= 0;

    else if(rx_baudtick)
        rx_baudcount <= 0;

    else
        rx_baudcount <= rx_baudcount + 1'b1;
end


// State Register

always @(posedge clk or posedge reset)
begin
    if(reset)
        rx_state <= IDLE;
    else
        rx_state <= rx_next_state;
end


// Next State Logic

always @(*)
begin
    rx_next_state = rx_state;

    case(rx_state)

        IDLE:
            if(rx==1'b0)
                rx_next_state = START;

        START:
            if(rx_halftick)
                rx_next_state = (rx==1'b0) ? DATA : IDLE;

        DATA:
            if(rx_baudtick && rx_bitcount==3'd7)
                rx_next_state = STOP;

        STOP:
            if(rx_baudtick)
                rx_next_state = IDLE;

        default:
            rx_next_state = IDLE;

    endcase
end


// Datapath

always @(posedge clk or posedge reset)
begin
    if(reset)
    begin
        rx_bitcount    <= 0;
        rx_shiftreg    <= 0;
        dataout        <= 0;
        data_valid     <= 0;
        rx_baudenable  <= 0;
    end
    else
    begin
        data_valid <= 0;

        case(rx_state)

            IDLE:
            begin
                rx_bitcount   <= 0;
                rx_baudenable <= 0;

                if(rx==1'b0)
                    rx_baudenable <= 1'b1;
            end

            DATA:
            begin
                if(rx_baudtick)
                begin
                    rx_shiftreg <= {rx,rx_shiftreg[7:1]};
                    rx_bitcount <= rx_bitcount + 1'b1;
                end
            end

            STOP:
            begin
                if(rx_baudtick)
                begin
                    if(rx==1'b1)
                    begin
                        dataout    <= rx_shiftreg;
                        data_valid <= 1'b1;
                    end

                    rx_baudenable <= 1'b0;
                end
            end

        endcase
    end
end

endmodule
