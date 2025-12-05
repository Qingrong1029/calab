module tlb #(
    parameter TLBNUM = 16,
    parameter TLBNUM_IDX_WIDTH = (TLBNUM <= 1) ? 1 : $clog2(TLBNUM)
)(
    input  wire                          clk,

    // search port 0
    input  wire [18:0]                   s0_vppn,
    input  wire                          s0_va_bit12,
    input  wire [9:0]                    s0_asid,
    output wire                          s0_found,
    output wire [TLBNUM_IDX_WIDTH-1:0]   s0_index,
    output wire [19:0]                   s0_ppn,
    output wire [5:0]                    s0_ps,
    output wire [1:0]                    s0_plv,
    output wire [1:0]                    s0_mat,
    output wire                          s0_d,
    output wire                          s0_v,

    // search port 1
    input  wire [18:0]                   s1_vppn,
    input  wire                          s1_va_bit12,
    input  wire [9:0]                    s1_asid,
    output wire                          s1_found,
    output wire [TLBNUM_IDX_WIDTH-1:0]   s1_index,
    output wire [19:0]                   s1_ppn,
    output wire [5:0]                    s1_ps,
    output wire [1:0]                    s1_plv,
    output wire [1:0]                    s1_mat,
    output wire                          s1_d,
    output wire                          s1_v,

    // maintenance operations
    input  wire                          invtlb_valid,
    input  wire [4:0]                    invtlb_op,

    // write port
    input  wire                          we,
    input  wire [TLBNUM_IDX_WIDTH-1:0]   w_index,
    input  wire                          w_e,
    input  wire [18:0]                   w_vppn,
    input  wire [5:0]                    w_ps,
    input  wire [9:0]                    w_asid,
    input  wire                          w_g,
    input  wire [19:0]                   w_ppn0,
    input  wire [1:0]                    w_plv0,
    input  wire [1:0]                    w_mat0,
    input  wire                          w_d0,
    input  wire                          w_v0,
    input  wire [19:0]                   w_ppn1,
    input  wire [1:0]                    w_plv1,
    input  wire [1:0]                    w_mat1,
    input  wire                          w_d1,
    input  wire                          w_v1,

    // read port
    input  wire [TLBNUM_IDX_WIDTH-1:0]   r_index,
    output wire                          r_e,
    output wire [18:0]                   r_vppn,
    output wire [5:0]                    r_ps,
    output wire [9:0]                    r_asid,
    output wire                          r_g,
    output wire [19:0]                   r_ppn0,
    output wire [1:0]                    r_plv0,
    output wire [1:0]                    r_mat0,
    output wire                          r_d0,
    output wire                          r_v0,
    output wire [19:0]                   r_ppn1,
    output wire [1:0]                    r_plv1,
    output wire [1:0]                    r_mat1,
    output wire                          r_d1,
    output wire                          r_v1
);

    localparam INVTLB_OP_ALL        = 5'b00000;
    localparam INVTLB_OP_GLOBAL     = 5'b00001;

    reg        e_array   [TLBNUM-1:0];
    reg [18:0] vppn_array[TLBNUM-1:0];
    reg [5:0]  ps_array  [TLBNUM-1:0];
    reg [9:0]  asid_array[TLBNUM-1:0];
    reg        g_array   [TLBNUM-1:0];
    reg [19:0] ppn0_array[TLBNUM-1:0];
    reg [1:0]  plv0_array[TLBNUM-1:0];
    reg [1:0]  mat0_array[TLBNUM-1:0];
    reg        d0_array  [TLBNUM-1:0];
    reg        v0_array  [TLBNUM-1:0];
    reg [19:0] ppn1_array[TLBNUM-1:0];
    reg [1:0]  plv1_array[TLBNUM-1:0];
    reg [1:0]  mat1_array[TLBNUM-1:0];
    reg        d1_array  [TLBNUM-1:0];
    reg        v1_array  [TLBNUM-1:0];

    integer init_idx;
    integer inv_idx;
    integer s0_idx;
    integer s1_idx;
    integer r_idx;

    function [18:0] vppn_match_mask;
        input [5:0] ps;
        integer low_bits;
        integer bit;
        begin
            vppn_match_mask = 19'h7ffff;
            low_bits = (ps > 6'd12) ? (ps - 6'd12) : 0;
            if (low_bits > 19)
                low_bits = 19;
            for (bit = 0; bit < low_bits; bit = bit + 1)
                vppn_match_mask[bit] = 1'b0;
        end
    endfunction

    function select_odd_page;
        input [5:0]  ps;
        input [18:0] vppn;
        input        va_bit12;
        integer bit_pos;
        begin
            if (ps <= 6'd12)
                select_odd_page = va_bit12;
            else begin
                bit_pos = ps - 6'd13;
                if (bit_pos >= 0 && bit_pos < 19)
                    select_odd_page = vppn[bit_pos];
                else
                    select_odd_page = va_bit12;
            end
        end
    endfunction

    initial begin
        for (init_idx = 0; init_idx < TLBNUM; init_idx = init_idx + 1) begin
            e_array   [init_idx] = 1'b0;
            vppn_array[init_idx] = 19'b0;
            ps_array  [init_idx] = 6'b0;
            asid_array[init_idx] = 10'b0;
            g_array   [init_idx] = 1'b0;
            ppn0_array[init_idx] = 20'b0;
            plv0_array[init_idx] = 2'b0;
            mat0_array[init_idx] = 2'b0;
            d0_array  [init_idx] = 1'b0;
            v0_array  [init_idx] = 1'b0;
            ppn1_array[init_idx] = 20'b0;
            plv1_array[init_idx] = 2'b0;
            mat1_array[init_idx] = 2'b0;
            d1_array  [init_idx] = 1'b0;
            v1_array  [init_idx] = 1'b0;
        end
    end

    always @(posedge clk) begin
        if (we) begin
            e_array   [w_index] <= w_e;
            vppn_array[w_index] <= w_vppn;
            ps_array  [w_index] <= w_ps;
            asid_array[w_index] <= w_asid;
            g_array   [w_index] <= w_g;
            ppn0_array[w_index] <= w_ppn0;
            plv0_array[w_index] <= w_plv0;
            mat0_array[w_index] <= w_mat0;
            d0_array  [w_index] <= w_d0;
            v0_array  [w_index] <= w_v0;
            ppn1_array[w_index] <= w_ppn1;
            plv1_array[w_index] <= w_plv1;
            mat1_array[w_index] <= w_mat1;
            d1_array  [w_index] <= w_d1;
            v1_array  [w_index] <= w_v1;
        end

        if (invtlb_valid) begin
            for (inv_idx = 0; inv_idx < TLBNUM; inv_idx = inv_idx + 1) begin
                if (invtlb_op == INVTLB_OP_ALL) begin
                    e_array[inv_idx]   <= 1'b0;
                    v0_array[inv_idx]  <= 1'b0;
                    d0_array[inv_idx]  <= 1'b0;
                    v1_array[inv_idx]  <= 1'b0;
                    d1_array[inv_idx]  <= 1'b0;
                end else if (invtlb_op == INVTLB_OP_GLOBAL && g_array[inv_idx]) begin
                    e_array[inv_idx]   <= 1'b0;
                    v0_array[inv_idx]  <= 1'b0;
                    d0_array[inv_idx]  <= 1'b0;
                    v1_array[inv_idx]  <= 1'b0;
                    d1_array[inv_idx]  <= 1'b0;
                end
            end
        end
    end

    reg                          s0_found_r;
    reg [TLBNUM_IDX_WIDTH-1:0]   s0_index_r;
    reg [19:0]                   s0_ppn_r;
    reg [5:0]                    s0_ps_r;
    reg [1:0]                    s0_plv_r;
    reg [1:0]                    s0_mat_r;
    reg                          s0_d_r;
    reg                          s0_v_r;

    always @(*) begin
        s0_found_r = 1'b0;
        s0_index_r = {TLBNUM_IDX_WIDTH{1'b0}};
        s0_ppn_r   = 20'b0;
        s0_ps_r    = 6'b0;
        s0_plv_r   = 2'b0;
        s0_mat_r   = 2'b0;
        s0_d_r     = 1'b0;
        s0_v_r     = 1'b0;

        for (s0_idx = 0; s0_idx < TLBNUM; s0_idx = s0_idx + 1) begin
            if (!s0_found_r && e_array[s0_idx]) begin
                if (((vppn_array[s0_idx] ^ s0_vppn) & vppn_match_mask(ps_array[s0_idx])) == 19'b0) begin
                    if (g_array[s0_idx] || (asid_array[s0_idx] == s0_asid)) begin
                        s0_found_r = 1'b1;
                        s0_index_r = s0_idx[TLBNUM_IDX_WIDTH-1:0];
                        s0_ps_r    = ps_array[s0_idx];
                        if (select_odd_page(ps_array[s0_idx], s0_vppn, s0_va_bit12)) begin
                            s0_ppn_r = ppn1_array[s0_idx];
                            s0_plv_r = plv1_array[s0_idx];
                            s0_mat_r = mat1_array[s0_idx];
                            s0_d_r   = d1_array[s0_idx];
                            s0_v_r   = v1_array[s0_idx];
                        end else begin
                            s0_ppn_r = ppn0_array[s0_idx];
                            s0_plv_r = plv0_array[s0_idx];
                            s0_mat_r = mat0_array[s0_idx];
                            s0_d_r   = d0_array[s0_idx];
                            s0_v_r   = v0_array[s0_idx];
                        end
                    end
                end
            end
        end
    end

    reg                          s1_found_r;
    reg [TLBNUM_IDX_WIDTH-1:0]   s1_index_r;
    reg [19:0]                   s1_ppn_r;
    reg [5:0]                    s1_ps_r;
    reg [1:0]                    s1_plv_r;
    reg [1:0]                    s1_mat_r;
    reg                          s1_d_r;
    reg                          s1_v_r;

    always @(*) begin
        s1_found_r = 1'b0;
        s1_index_r = {TLBNUM_IDX_WIDTH{1'b0}};
        s1_ppn_r   = 20'b0;
        s1_ps_r    = 6'b0;
        s1_plv_r   = 2'b0;
        s1_mat_r   = 2'b0;
        s1_d_r     = 1'b0;
        s1_v_r     = 1'b0;

        for (s1_idx = 0; s1_idx < TLBNUM; s1_idx = s1_idx + 1) begin
            if (!s1_found_r && e_array[s1_idx]) begin
                if (((vppn_array[s1_idx] ^ s1_vppn) & vppn_match_mask(ps_array[s1_idx])) == 19'b0) begin
                    if (g_array[s1_idx] || (asid_array[s1_idx] == s1_asid)) begin
                        s1_found_r = 1'b1;
                        s1_index_r = s1_idx[TLBNUM_IDX_WIDTH-1:0];
                        s1_ps_r    = ps_array[s1_idx];
                        if (select_odd_page(ps_array[s1_idx], s1_vppn, s1_va_bit12)) begin
                            s1_ppn_r = ppn1_array[s1_idx];
                            s1_plv_r = plv1_array[s1_idx];
                            s1_mat_r = mat1_array[s1_idx];
                            s1_d_r   = d1_array[s1_idx];
                            s1_v_r   = v1_array[s1_idx];
                        end else begin
                            s1_ppn_r = ppn0_array[s1_idx];
                            s1_plv_r = plv0_array[s1_idx];
                            s1_mat_r = mat0_array[s1_idx];
                            s1_d_r   = d0_array[s1_idx];
                            s1_v_r   = v0_array[s1_idx];
                        end
                    end
                end
            end
        end
    end

    assign s0_found = s0_found_r;
    assign s0_index = s0_index_r;
    assign s0_ppn   = s0_ppn_r;
    assign s0_ps    = s0_ps_r;
    assign s0_plv   = s0_plv_r;
    assign s0_mat   = s0_mat_r;
    assign s0_d     = s0_d_r;
    assign s0_v     = s0_v_r;

    assign s1_found = s1_found_r;
    assign s1_index = s1_index_r;
    assign s1_ppn   = s1_ppn_r;
    assign s1_ps    = s1_ps_r;
    assign s1_plv   = s1_plv_r;
    assign s1_mat   = s1_mat_r;
    assign s1_d     = s1_d_r;
    assign s1_v     = s1_v_r;

    reg        r_e_r;
    reg [18:0] r_vppn_r;
    reg [5:0]  r_ps_r;
    reg [9:0]  r_asid_r;
    reg        r_g_r;
    reg [19:0] r_ppn0_r;
    reg [1:0]  r_plv0_r;
    reg [1:0]  r_mat0_r;
    reg        r_d0_r;
    reg        r_v0_r;
    reg [19:0] r_ppn1_r;
    reg [1:0]  r_plv1_r;
    reg [1:0]  r_mat1_r;
    reg        r_d1_r;
    reg        r_v1_r;

    always @(*) begin
        r_e_r    = 1'b0;
        r_vppn_r = 19'b0;
        r_ps_r   = 6'b0;
        r_asid_r = 10'b0;
        r_g_r    = 1'b0;
        r_ppn0_r = 20'b0;
        r_plv0_r = 2'b0;
        r_mat0_r = 2'b0;
        r_d0_r   = 1'b0;
        r_v0_r   = 1'b0;
        r_ppn1_r = 20'b0;
        r_plv1_r = 2'b0;
        r_mat1_r = 2'b0;
        r_d1_r   = 1'b0;
        r_v1_r   = 1'b0;

        for (r_idx = 0; r_idx < TLBNUM; r_idx = r_idx + 1) begin
            if (r_index == r_idx[TLBNUM_IDX_WIDTH-1:0]) begin
                r_e_r    = e_array[r_idx];
                r_vppn_r = vppn_array[r_idx];
                r_ps_r   = ps_array[r_idx];
                r_asid_r = asid_array[r_idx];
                r_g_r    = g_array[r_idx];
                r_ppn0_r = ppn0_array[r_idx];
                r_plv0_r = plv0_array[r_idx];
                r_mat0_r = mat0_array[r_idx];
                r_d0_r   = d0_array[r_idx];
                r_v0_r   = v0_array[r_idx];
                r_ppn1_r = ppn1_array[r_idx];
                r_plv1_r = plv1_array[r_idx];
                r_mat1_r = mat1_array[r_idx];
                r_d1_r   = d1_array[r_idx];
                r_v1_r   = v1_array[r_idx];
            end
        end
    end

    assign r_e    = r_e_r;
    assign r_vppn = r_vppn_r;
    assign r_ps   = r_ps_r;
    assign r_asid = r_asid_r;
    assign r_g    = r_g_r;
    assign r_ppn0 = r_ppn0_r;
    assign r_plv0 = r_plv0_r;
    assign r_mat0 = r_mat0_r;
    assign r_d0   = r_d0_r;
    assign r_v0   = r_v0_r;
    assign r_ppn1 = r_ppn1_r;
    assign r_plv1 = r_plv1_r;
    assign r_mat1 = r_mat1_r;
    assign r_d1   = r_d1_r;
    assign r_v1   = r_v1_r;

endmodule