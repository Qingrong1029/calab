module EX (
    input           clk,
    input           resetn,

    output          ex_allowin,
    input           id_ex_valid,
    input   [273:0] id_ex_bus,

    output          ex_mem_valid,
    input           mem_allowin,
    output  [189:0] ex_mem_bus,

    output          data_sram_en,
    output  [ 3:0]  data_sram_we,
    output  [31:0]  data_sram_addr,
    output  [31:0]  data_sram_wdata,

    output  [40:0]  ex_id_bus,
    //ertn
    input           ertn_flush

);

    reg             ex_valid;
    wire            ex_ready_go;
    wire    [ 31:0] ex_inst;
    wire    [ 31:0] ex_pc;
    reg     [273:0] id_ex_bus_vld;
    wire            ex_bypass;
    wire            ex_ld;
    wire    [  2:0] mem_type;
    wire ex_syscall_ex;
    
    //block
    assign  ex_ready_go = (ex_div_en) ? div_done : 1'b1;
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

    wire            ex_gr_we;
    wire            res_from_mem;
    wire    [14:0]  alu_op;
    wire            ex_div_en;
    wire    [ 2:0]  ex_div_op;
    wire    [31:0]  alu_src1;
    wire    [31:0]  alu_src2;
    wire    [ 4:0]  ex_dest;
    wire    [31:0]  rkd_value;
    wire    [31:0]  st_data;
    //csr exp12
    wire            ex_csr_we;
    wire            ex_csr_re;
    wire    [13:0]  ex_csr_num;
    wire    [31:0]  ex_csr_wmask;
    wire    [31:0]  ex_csr_wvalue;
    wire            ex_ertn;
    wire            ex_csr;

    wire            inst_st_w;
    wire            inst_st_b;
    wire            inst_st_h;
    
    assign {
        ex_gr_we, inst_st_w, inst_st_b, inst_st_h, res_from_mem, mem_type,
        alu_op, ex_div_en, ex_div_op, alu_src1, alu_src2,
        ex_dest, rkd_value, ex_inst, ex_pc, ex_csr_we, ex_csr_re, ex_csr_num, ex_csr_wmask, ex_csr_wvalue, ex_ertn, ex_syscall_ex
    } = id_ex_bus_vld;

    wire    [31:0]  alu_result;
    alu my_alu (    
        .alu_op(alu_op),
        .alu_src1(alu_src1),
        .alu_src2(alu_src2),
        .alu_result(alu_result)
    );
    
    wire [ 1:0] mem_addr_low2 = alu_result[1:0];
    wire [31:0] div_result;
    wire        div_busy;
    wire        div_done;

    div my_div (
        .clk         (clk),
        .resetn      (resetn),
        .ex_div_en   (ex_div_en),
        .ex_div_op   (ex_div_op[1:0]),
        .alu_src1    (alu_src1),
        .alu_src2    (alu_src2),
        .signed_src1 ($signed(alu_src1)),
        .signed_src2 ($signed(alu_src2)),
        .div_result  (div_result),
        .div_busy    (div_busy),
        .div_done    (div_done)
    );

    wire [31:0] ex_final_result = ex_div_en ? div_result : alu_result;
    
    assign st_data = inst_st_b ? {4{rkd_value[ 7:0]}} :
                     inst_st_h ? {2{rkd_value[15:0]}} :
                                    rkd_value[31:0];
    
    assign  data_sram_en = 1'b1;
    assign  data_sram_we = (~ertn_flush) ? (
                    inst_st_b ? (
                        mem_addr_low2 == 2'b00 ? 4'b0001 :
                        mem_addr_low2 == 2'b01 ? 4'b0010 :
                        mem_addr_low2 == 2'b10 ? 4'b0100 :
                                                 4'b1000
                    ) : inst_st_h ? (
                        mem_addr_low2 == 2'b00 ? 4'b0011 :
                                                 4'b1100
                    ) : inst_st_w ? 4'b1111 : 4'b0000
                ) : 4'b0000;  // ERTN flush 时禁止写
    assign  data_sram_addr = {alu_result[31:2],2'b00};
    assign  data_sram_wdata = st_data;
    assign ex_mem_bus = {
        ex_gr_we, res_from_mem, mem_type, mem_addr_low2,
        ex_dest,ex_pc, ex_inst, ex_final_result, ex_csr_we, ex_csr_re, ex_csr_num, ex_csr_wmask, ex_csr_wvalue, ex_ertn,ex_syscall_ex 
    };
    assign ex_csr = ex_csr_re | ex_csr_we;
    assign ex_bypass = ex_valid & ex_gr_we;
    assign ex_ld = ex_valid & res_from_mem;
    assign ex_div_busy = ex_valid & div_busy;
    assign ex_id_bus = {ex_bypass , ex_ld , ex_dest , ex_final_result , ex_div_busy , ex_gr_we ,ex_csr};
endmodule