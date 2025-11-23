`include "defines.vh"

module WB (
    input           clk,
    input           resetn,

    output          wb_allowin,
    input           mem_wb_valid,
    input   [231:0] mem_wb_bus,

    output  [ 38:0] wb_id_bus,

    output  [ 31:0] debug_wb_pc,
    output  [  3:0] debug_wb_rf_we,
    output  [  4:0] debug_wb_rf_wnum,
    output  [ 31:0] debug_wb_rf_wdata,
    
    //csr
    output  [13:0]  csr_num,
    output          csr_re,
    input   [31:0]  csr_rvalue,

    output          csr_we,
    output  [31:0]  csr_wvalue,
    output  [31:0]  csr_wmask,
    output          ertn_flush,
    output          wb_ex,
    output  [31:0]  wb_csr_pc,
    output  [ 5:0]  wb_ecode,
    output  [ 8:0]  wb_esubcode,
    output  [31:0]  wb_vaddr
);

    reg             wb_valid;
    reg     [231:0] mem_wb_bus_vld;
    wire            wb_ready_go;
    wire            wb_gr_we;
    wire            rf_we;
    wire    [ 31:0] wb_pc;
    wire    [ 31:0] wb_inst;
    wire    [ 31:0] final_result;
    wire    [  4:0] rf_waddr;
    wire    [ 31:0] rf_wdata;
    wire    [  4:0] wb_dest;
    wire    [ 31:0] wb_wdata; 
    //csr exp12
    wire            wb_csr_we;
    wire            wb_csr_re;
    wire    [13:0]  wb_csr_num;
    wire    [31:0]  wb_csr_wmask;
    wire    [31:0]  wb_csr_wvalue;
    wire            wb_ertn;

    wire    [31:0]  wb_wrong_addr;  
    wire     [31:0] wb_vaddr; // 错误地址
    wire            wb_ex_id;         // 从ID传来的异常
    wire    [ 8:0]  wb_esubcode;      // 异常子码
    wire    [ 5:0]  wb_ecode;         // 异常编码
    
    assign wb_ready_go = 1'b1;
    assign wb_allowin = wb_ready_go | ~wb_valid;
    always @(posedge clk ) begin
        if (~resetn) begin
            wb_valid <= 1'b0;
        end
        else if (wb_ex) begin
            wb_valid <= 1'b0;
        end
        else if (ertn_flush) begin
            wb_valid <= 1'b0;
        end
        else if (wb_allowin) begin
            wb_valid <= mem_wb_valid;
        end
    end
    always @(posedge clk ) begin
        if (mem_wb_valid & wb_allowin) begin
            mem_wb_bus_vld <= mem_wb_bus;
        end
    end
    assign  {
        wb_gr_we, wb_pc, wb_inst, final_result, wb_dest,
        wb_csr_we, wb_csr_re, wb_csr_num, wb_csr_wmask, wb_csr_wvalue, wb_ertn, wb_syscall_ex, wb_wrong_addr, wb_ex_id, wb_esubcode, wb_ecode
    } = mem_wb_bus_vld;
    assign  rf_we = wb_valid & wb_gr_we & ~wb_ex;
    assign  rf_waddr = wb_dest; 
    assign  rf_wdata = wb_wdata;
    assign  wb_id_bus = {
        rf_we, rf_waddr, rf_wdata, csr_re
    };
    assign wb_ex = wb_valid & wb_ex_id ;//可以加别的异常
    assign wb_esubcode = wb_ex_id ? `ESUBCODE_ADEF : 9'b0;  // syscall没有子编码
    assign wb_csr_pc = wb_pc;
    assign ertn_flush = wb_valid & wb_ertn;
    //csr
    assign wb_wdata = csr_re ? csr_rvalue : final_result;
    assign csr_num = wb_csr_num;
    assign csr_re = wb_csr_re | wb_csr_we;
    assign csr_we = wb_csr_we;
    assign csr_wvalue = wb_csr_wvalue;
    assign csr_wmask = wb_csr_wmask;
    assign wb_vaddr = wb_wrong_addr;
    assign  debug_wb_pc = wb_pc;
    assign  debug_wb_rf_we = {4{rf_we}};
    assign  debug_wb_rf_wnum = wb_dest;
    assign  debug_wb_rf_wdata = wb_wdata;
endmodule