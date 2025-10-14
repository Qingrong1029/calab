module MEM (
    input           clk,
    input           resetn,

    output          mem_allowin,
    input           ex_mem_valid,
    input   [102:0] ex_mem_bus,

    output          mem_wb_valid,
    input           wb_allowin,
    output  [101:0] mem_wb_bus,

    input   [ 31:0] data_sram_rdata,

    output  [ 38:0]  mem_id_bus

);

    reg             mem_valid;
    wire            mem_ready_go;
    wire    [ 31:0] mem_pc;
    wire    [ 31:0] mem_inst;
    reg     [102:0] ex_mem_bus_vld;
    wire            mem_gr_we;
    wire            res_from_mem;
    wire    [  4:0] mem_dest;
    wire    [ 31:0] alu_result;
    wire    [ 31:0] final_result;
    wire            mem_bypass;

    assign  mem_ready_go = 1'b1;
    assign  mem_wb_valid = mem_ready_go & mem_valid;
    assign  mem_allowin = mem_wb_valid & wb_allowin | ~mem_valid;
    always @(posedge clk ) begin
        if (~resetn) begin
            mem_valid <= 1'b0;
        end
        else if(mem_allowin) begin
            mem_valid <= ex_mem_valid;
        end
    end
    always @(posedge clk ) begin
        if (ex_mem_valid & mem_allowin) begin
            ex_mem_bus_vld <= ex_mem_bus;
        end
    end
    assign {
        mem_gr_we, res_from_mem, mem_dest,
        mem_pc, mem_inst, alu_result
    } = ex_mem_bus_vld;
    assign  final_result = res_from_mem ? data_sram_rdata : alu_result;
    assign  mem_wb_bus = {
        mem_gr_we, mem_pc, mem_inst, final_result, mem_dest
    };
    assign  mem_bypass = mem_valid & mem_gr_we;
    assign  mem_id_bus = {mem_bypass , mem_dest , final_result};
endmodule