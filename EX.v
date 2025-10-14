module EX (
    input           clk,
    input           resetn,

    output          ex_allowin,
    input           id_ex_valid,
    input   [179:0] id_ex_bus,

    output          ex_mem_valid,
    input           mem_allowin,
    output  [102:0] ex_mem_bus,

    output          data_sram_en,
    output  [ 3:0]  data_sram_we,
    output  [31:0]  data_sram_addr,
    output  [31:0]  data_sram_wdata,

    output  [38:0]  ex_id_bus
);

    reg             ex_valid;
    wire            ex_ready_go;
    wire    [ 31:0] ex_inst;
    wire    [ 31:0] ex_pc;
    reg     [179:0] id_ex_bus_vld;
    wire            ex_bypass;
    wire            ex_ld;
    
    assign  ex_ready_go = 1'b1;
    assign  ex_mem_valid = ex_ready_go & ex_valid;
    assign  ex_allowin = ex_mem_valid & mem_allowin | ~ex_valid;
    always @(posedge clk ) begin
        if (~resetn) begin
            ex_valid <= 1'b0;
        end
        else if(ex_allowin) begin
            ex_valid <= id_ex_valid;
        end
    end
    always @(posedge clk ) begin
        if (id_ex_valid & ex_allowin) begin
            id_ex_bus_vld <= id_ex_bus; 
        end
    end

    wire             ex_gr_we;
    wire             mem_we;
    wire             res_from_mem;
    wire    [11:0]  alu_op;
    wire    [31:0]  alu_src1;
    wire    [31:0]  alu_src2;
    wire    [ 4:0]  ex_dest;
    wire    [31:0]  rkd_value;
    assign {
        ex_gr_we, mem_we, res_from_mem,
        alu_op, alu_src1, alu_src2,
        ex_dest, rkd_value, ex_inst, ex_pc
    } = id_ex_bus_vld;

    wire    [31:0]  alu_result;
    alu my_alu (    
        .alu_op(alu_op),
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_result(alu_result)
    );

    assign  data_sram_en = 1'b1;
    assign  data_sram_we = {4{mem_we}};
    assign  data_sram_addr = alu_result;
    assign  data_sram_wdata = rkd_value;
    assign ex_mem_bus = {
        ex_gr_we, res_from_mem, ex_dest,
        ex_pc, ex_inst, alu_result
    };
    assign ex_bypass = ex_valid & ex_gr_we;
    assign ex_ld = ex_valid & res_from_mem;
    assign ex_id_bus = {ex_bypass , ex_ld , ex_dest , alu_result};
endmodule