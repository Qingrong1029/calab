module MEM (
    input           clk,
    input           resetn,

    output          mem_allowin,
    input           ex_mem_valid,
    input   [189:0] ex_mem_bus,

    output          mem_wb_valid,
    input           wb_allowin,
    output  [183:0] mem_wb_bus,

    input   [ 31:0] data_sram_rdata,

    output  [ 38:0] mem_id_bus,
    output          ertn_flush 
);

    reg             mem_valid;
    wire            mem_ready_go;
    wire    [ 31:0] mem_pc;
    wire    [ 31:0] mem_inst;
    reg     [189:0] ex_mem_bus_vld;
    wire            mem_gr_we;
    wire            res_from_mem;
    wire    [  4:0] mem_dest;
    wire    [ 31:0] alu_result;
    wire    [ 31:0] final_result;
    wire            mem_bypass;
    
    wire    [  2:0] mem_type;      // 访存类型信息
    wire    [  1:0] mem_addr_low2; // 访存地址最低两位
    wire    [ 31:0] selected_data;
    wire    [ 15:0] halfword_data;
    wire    [  7:0] byte_data;
    wire    [ 31:0] extended_data;
    //csr exp12
    wire            mem_csr_we;
    wire            mem_csr_re;
    wire    [13:0]  mem_csr_num;
    wire    [31:0]  mem_csr_wmask;
    wire    [31:0]  mem_csr_wvalue;
    wire            mem_ertn;
    wire            ertn_flush;
    wire            mem_syscall_ex;
    
    assign halfword_data = (mem_addr_low2[1] == 1'b0) ? data_sram_rdata[15:0] : data_sram_rdata[31:16];

    assign byte_data = (mem_addr_low2 == 2'b00) ? data_sram_rdata[7:0] :
                       (mem_addr_low2 == 2'b01) ? data_sram_rdata[15:8] :
                       (mem_addr_low2 == 2'b10) ? data_sram_rdata[23:16] :
                                                  data_sram_rdata[31:24];

    assign selected_data = (mem_type[1:0] == 2'b00) ? data_sram_rdata :  // word
                           (mem_type[1:0] == 2'b01) ? {16'b0, halfword_data} :  // halfword
                                                      {24'b0, byte_data};  // byte
    
    wire [31:0] sign_extended_half = {{16{halfword_data[15]}}, halfword_data};
    wire [31:0] sign_extended_byte = {{24{byte_data[7]}}, byte_data};
    wire [31:0] zero_extended_half = {16'b0, halfword_data};
    wire [31:0] zero_extended_byte = {24'b0, byte_data};

    assign extended_data = (mem_type[1:0] == 2'b00) ? selected_data :  // ld.w: 直接使用
                       (mem_type == 3'b001) ? sign_extended_half :  // ld.h: 半字符号扩展
                       (mem_type == 3'b010) ? sign_extended_byte :  // ld.b: 字节符号扩展
                       (mem_type == 3'b101) ? zero_extended_half :  // ld.hu: 半字零扩展
                       zero_extended_byte;  // ld.bu: 字节零扩展

    
    assign  ertn_flush = mem_valid & mem_ertn;
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
        mem_gr_we, res_from_mem, mem_type, mem_addr_low2,
        mem_dest, mem_pc, mem_inst, alu_result, mem_csr_we, mem_csr_re, mem_csr_num, mem_csr_wmask, mem_csr_wvalue, mem_ertn,mem_syscall_ex
    } = ex_mem_bus_vld;
    assign  final_result = res_from_mem ? extended_data : alu_result;
    assign  mem_wb_bus = {
        mem_gr_we, mem_pc, mem_inst, final_result, mem_dest,
        mem_csr_we, mem_csr_re, mem_csr_num, mem_csr_wmask, mem_csr_wvalue, mem_ertn,mem_syscall_ex
    };
    assign  mem_bypass = mem_valid & mem_gr_we;
    
    assign  mem_id_bus = {mem_bypass , mem_dest , final_result};
endmodule