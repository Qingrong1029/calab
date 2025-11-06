module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    wire            id_allowin;
    wire            if_id_valid;
    wire    [ 96:0] if_id_bus;
    wire    [ 32:0] id_if_bus;
    wire            ex_allowin;
    wire            id_ex_valid;
    wire    [332:0] id_ex_bus;
    wire    [ 38:0] wb_id_bus;
    wire    [239:0] ex_mem_bus;
    wire            ex_mem_valid;
    wire            mem_allowin;
    wire            mem_wb_valid;
    wire    [232:0] mem_wb_bus;
    wire            wb_allowin;
    wire    [ 53:0] mem_id_bus;
    wire    [ 55:0] ex_id_bus;
    wire    [168:0] wb_csr_bus;
    
    wire    [31:0]  csr_rvalue;
    wire    [31:0]  ex_entry;
    wire            ertn_flush;
    wire    [31:0]  ertn_entry;

    
    IF my_IF (
        .clk                (clk),
        .resetn             (resetn),
        .id_allowin         (id_allowin),
        .if_id_valid        (if_id_valid),
        .if_id_bus          (if_id_bus),
        .id_if_bus          (id_if_bus),
        .inst_sram_en       (inst_sram_en),
        .inst_sram_we       (inst_sram_we),
        .inst_sram_addr     (inst_sram_addr),
        .inst_sram_rdata    (inst_sram_rdata),
        .inst_sram_wdata    (inst_sram_wdata),
        .ertn_flush         (ertn_flush),
        .ertn_entry         (ertn_entry),
        .wb_ex              (wb_ex),
        .ex_entry           (ex_entry)
    );
    ID my_ID (
        .clk                (clk),
        .resetn             (resetn),
        .if_id_valid        (if_id_valid),
        .id_allowin         (id_allowin),
        .if_id_bus          (if_id_bus),
        .id_if_bus          (id_if_bus),
        .ex_allowin         (ex_allowin),
        .id_ex_valid        (id_ex_valid),
        .id_ex_bus          (id_ex_bus),
        .wb_id_bus          (wb_id_bus),
        .mem_id_bus         (mem_id_bus),
        .ex_id_bus          (ex_id_bus),
        .ertn_flush         (ertn_flush),
        .id_has_int         (has_int),
        .wb_ex              (wb_ex | ertn_flush)
    );
    EX  my_EX (
        .clk                (clk),
        .resetn             (resetn),
        .ex_allowin         (ex_allowin),
        .id_ex_valid        (id_ex_valid),
        .id_ex_bus          (id_ex_bus),
        .ex_mem_valid       (ex_mem_valid),
        .mem_allowin        (mem_allowin),
        .ex_mem_bus         (ex_mem_bus),
        .data_sram_en       (data_sram_en),
        .data_sram_we       (data_sram_we),
        .data_sram_addr     (data_sram_addr),
        .data_sram_wdata    (data_sram_wdata),
        .ex_id_bus          (ex_id_bus),
        //ertn
        .ertn_flush         (ertn_flush),
        .mem_ex             (mem_ex),
        .wb_ex              (wb_ex | ertn_flush)
    );
    MEM my_MEM (
        .clk                (clk),
        .resetn             (resetn),
        .mem_allowin        (mem_allowin),
        .ex_mem_valid       (ex_mem_valid),
        .ex_mem_bus         (ex_mem_bus),
        .mem_wb_valid       (mem_wb_valid),
        .wb_allowin         (wb_allowin),
        .mem_wb_bus         (mem_wb_bus),
        .data_sram_rdata    (data_sram_rdata),
        .mem_id_bus         (mem_id_bus),
        //ertn
        .ertn_flush        (ertn_flush),
        .mem_ex            (mem_ex),
        .wb_ex             (wb_ex | ertn_flush)
    );
    WB my_WB (
        .clk                (clk),
        .resetn             (resetn),
        .wb_allowin         (wb_allowin),
        .mem_wb_valid       (mem_wb_valid),
        .mem_wb_bus         (mem_wb_bus),
        .wb_id_bus          (wb_id_bus),
        .debug_wb_pc        (debug_wb_pc),
        .debug_wb_rf_we     (debug_wb_rf_we),
        .debug_wb_rf_wnum   (debug_wb_rf_wnum),
        .debug_wb_rf_wdata  (debug_wb_rf_wdata),
        //csr
        .wb_csr_bus         (wb_csr_bus),
        .csr_rvalue         (csr_rvalue),
        .ertn_flush         (ertn_flush),
        .wb_ex              (wb_ex)
    );
    csr_reg csr(
        .clk                (clk),
        .resetn             (resetn),
        .csr_rvalue         (csr_rvalue),
        .ex_entry           (ex_entry),
        .ertn_flush         (ertn_flush),
        .ertn_entry         (ertn_entry),
        .wb_csr_bus         (wb_csr_bus),
        .wb_ex              (wb_ex)
    );
endmodule