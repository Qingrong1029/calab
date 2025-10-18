//======================================================================
//  File: div.v
//  Description: Division Control Module (Supports Signed and Unsigned Division)
//======================================================================

module div (
    input  wire         clk,
    input  wire         resetn,

    // Control inputs
    input  wire         ex_div_en,     // Division enable signal from EX stage
    input  wire [1:0]   ex_div_op,     // Division operation code:
                                        //   00 - signed division (div.s)
                                        //   01 - signed modulo   (mod.s)
                                        //   10 - unsigned division (div.u)
                                        //   11 - unsigned modulo   (mod.u)
    input  wire [31:0]  alu_src1,
    input  wire [31:0]  alu_src2,
    input  wire [31:0]  signed_src1,
    input  wire [31:0]  signed_src2,

    // Output results
    output wire [31:0]  div_result,
    output wire         div_busy,
    output wire         div_done
);

    //------------------------------------------------------------------
    //  Wires for signed divider IP core
    //------------------------------------------------------------------
    wire div_s_tvalid, div_s_tready, div_s_valid;
    wire [63:0] div_s_result;

    // Signed divider instantiation
    div_gen_0 div_signed (
        .aclk                  (clk),
        .s_axis_divisor_tvalid (div_s_tvalid),
        .s_axis_divisor_tready (div_s_tready),
        .s_axis_divisor_tdata  (signed_src2),
        .s_axis_dividend_tvalid(div_s_tvalid),
        .s_axis_dividend_tready(),
        .s_axis_dividend_tdata (signed_src1),
        .m_axis_dout_tvalid    (div_s_valid),
        .m_axis_dout_tdata     (div_s_result)
    );

    //------------------------------------------------------------------
    //  Wires for unsigned divider IP core
    //------------------------------------------------------------------
    wire div_u_tvalid, div_u_tready, div_u_valid;
    wire [63:0] div_u_result;

    // Unsigned divider instantiation
    div_gen_1 div_unsigned (
        .aclk                  (clk),
        .s_axis_divisor_tvalid (div_u_tvalid),
        .s_axis_divisor_tready (div_u_tready),
        .s_axis_divisor_tdata  (alu_src2),
        .s_axis_dividend_tvalid(div_u_tvalid),
        .s_axis_dividend_tready(),
        .s_axis_dividend_tdata (alu_src1),
        .m_axis_dout_tvalid    (div_u_valid),
        .m_axis_dout_tdata     (div_u_result)
    );

    //------------------------------------------------------------------
    //  Start signal logic for signed/unsigned division
    //------------------------------------------------------------------
    wire start_signed   = ex_div_en && !div_busy &&
                          (ex_div_op[1:0] == 2'b00 || ex_div_op[1:0] == 2'b01);
    wire start_unsigned = ex_div_en && !div_busy &&
                          (ex_div_op[1:0] == 2'b10 || ex_div_op[1:0] == 2'b11);

    // Start handshake (requires both start and ready)
    wire div_s_start = start_signed   && div_s_tready;
    wire div_u_start = start_unsigned && div_u_tready;

    assign div_s_tvalid = start_signed;
    assign div_u_tvalid = start_unsigned;

    //------------------------------------------------------------------
    //  Division busy flag control
    //------------------------------------------------------------------
    reg div_busy_r;
    assign div_busy = div_busy_r;

    always @(posedge clk or negedge resetn) begin
        if (~resetn)
            div_busy_r <= 1'b0;                   // Reset: divider idle
        else if (div_s_valid || div_u_valid)
            div_busy_r <= 1'b0;                   // Division completed
        else if (div_s_start || div_u_start)
            div_busy_r <= 1'b1;                   // Division started
    end

    //------------------------------------------------------------------
    //  Division done signal (result ready)
    //------------------------------------------------------------------
    assign div_done = div_s_valid | div_u_valid;

    //------------------------------------------------------------------
    //  Output result selection
    //------------------------------------------------------------------
    reg [31:0] div_result_r;
    assign div_result = div_result_r;

    // Select result based on operation type:
    always @(*) begin
        case (ex_div_op[1:0])
            2'b00: div_result_r = div_s_result[63:32];
            2'b01: div_result_r = div_s_result[31:0];
            2'b10: div_result_r = div_u_result[63:32];
            2'b11: div_result_r = div_u_result[31:0];
            default: div_result_r = 32'b0;
        endcase
    end

endmodule