module transfer_axi_bridge(
    input  wire         aclk,
    input  wire         aresetn,

    // AXI AR channel
    output reg  [3:0]   arid,
    output reg [31:0]   araddr,
    output reg  [7:0]   arlen,
    output reg  [2:0]   arsize,
    output reg  [1:0]   arburst,
    output reg  [1:0]   arlock,
    output reg  [3:0]   arcache,
    output reg  [2:0]   arprot,
    output reg          arvalid,
    input  wire         arready,

    // AXI R channel
    input  wire  [3:0]  rid,
    input  wire [31:0]  rdata,
    input  wire  [1:0]  rresp,
    input  wire         rlast,
    input  wire         rvalid,
    output wire         rready,

    // AXI AW channel
    output reg  [3:0]   awid,
    output reg [31:0]   awaddr,
    output reg  [7:0]   awlen,
    output reg  [2:0]   awsize,
    output reg  [1:0]   awburst,
    output reg  [1:0]   awlock,
    output reg  [3:0]   awcache,
    output reg  [2:0]   awprot,
    output reg          awvalid,
    input  wire         awready,

    // AXI W channel
    output reg  [3:0]   wid,
    output reg [31:0]   wdata,
    output reg  [3:0]   wstrb,
    output reg          wlast,
    output reg          wvalid,
    input  wire         wready,

    // AXI B channel
    input  wire  [3:0]  bid,
    input  wire  [1:0]  bresp,
    input  wire         bvalid,
    output wire         bready,

    // Instruction SRAM interface
    input  wire         inst_sram_req,
    input  wire         inst_sram_wr,
    input  wire  [1:0]  inst_sram_size,
    input  wire  [3:0]  inst_sram_wstrb,
    input  wire [31:0]  inst_sram_addr,
    input  wire [31:0]  inst_sram_wdata,
    output wire [31:0]  inst_sram_rdata,
    output reg          inst_sram_addr_ok,
    output reg          inst_sram_data_ok,
    
    // Data SRAM interface
    input  wire         data_sram_req,
    input  wire         data_sram_wr,
    input  wire  [3:0]  data_sram_wstrb,
    input  wire  [1:0]  data_sram_size,
    input  wire [31:0]  data_sram_addr,
    input  wire [31:0]  data_sram_wdata,
    output reg          data_sram_addr_ok,
    output reg          data_sram_data_ok,
    output wire [31:0]  data_sram_rdata
);

    // State Definitions
    localparam RREQ_IDLE = 3'd0;
    localparam RREQ_INST = 3'd1;
    localparam RREQ_DATA = 3'd2;
    localparam RREQ_WAIT_RAW = 3'd3;
    
    localparam WREQ_IDLE = 2'd0;
    localparam WREQ_SEND = 2'd1;
    localparam WREQ_WAIT_RAW = 2'd2;

    // Internal Registers
    reg [2:0] rreq_state;
    reg [1:0] wreq_state;
    
    reg [31:0] inst_rdata_buf;
    reg [31:0] data_rdata_buf;
    
    reg [1:0] inst_read_cnt;
    reg [1:0] data_read_cnt;
    reg [1:0] write_cnt;
    
    // 跟踪 AW 和 W 是否已经握手
    reg aw_sent;
    reg w_sent;

    // Request Detection
    wire inst_read_req = inst_sram_req && !inst_sram_wr;
    wire data_read_req = data_sram_req && !data_sram_wr;
    wire data_write_req = data_sram_req && data_sram_wr;
    
    // RAW hazard
    wire raw_hazard = arvalid && awvalid && (araddr == awaddr);

    // Read Request State Machine
    always @(posedge aclk) begin
        if (!aresetn) begin
            rreq_state <= RREQ_IDLE;
        end else begin
            case (rreq_state)
                RREQ_IDLE: begin
                    if (data_read_req)
                        rreq_state <= raw_hazard ? RREQ_WAIT_RAW : RREQ_DATA;
                    else if (inst_read_req)
                        rreq_state <= RREQ_INST;
                end
                RREQ_INST: begin
                    if (arvalid && arready)
                        rreq_state <= RREQ_IDLE;
                end
                RREQ_DATA: begin
                    if (arvalid && arready)
                        rreq_state <= RREQ_IDLE;
                end
                RREQ_WAIT_RAW: begin
                    if (!raw_hazard)
                        rreq_state <= RREQ_DATA;
                end
                default: rreq_state <= RREQ_IDLE;
            endcase
        end
    end

    // Write Request State Machine
    always @(posedge aclk) begin
        if (!aresetn) begin
            wreq_state <= WREQ_IDLE;
            aw_sent <= 1'b0;
            w_sent <= 1'b0;
        end else begin
            case (wreq_state)
                WREQ_IDLE: begin
                    if (data_write_req) begin
                        wreq_state <= raw_hazard ? WREQ_WAIT_RAW : WREQ_SEND;
                        aw_sent <= 1'b0;
                        w_sent <= 1'b0;
                    end
                end
                WREQ_WAIT_RAW: begin
                    if (!raw_hazard)
                        wreq_state <= WREQ_SEND;
				end
                WREQ_SEND: begin
                    if (awvalid && awready)
                        aw_sent <= 1'b1;
                    if (wvalid && wready)
                        w_sent <= 1'b1; 
                    if ((aw_sent || (awvalid && awready)) && 
                        (w_sent || (wvalid && wready))) begin
                        wreq_state <= WREQ_IDLE;
                        aw_sent <= 1'b0;
                        w_sent <= 1'b0;
                    end
                end   
                default: wreq_state <= WREQ_IDLE;
            endcase
        end
    end

    // Transaction Counters
    always @(posedge aclk) begin
        if (!aresetn) begin
            inst_read_cnt <= 2'd0;
        end else begin
            case ({arvalid && arready && arid == 4'd0, rvalid && rready && rid == 4'd0})
                2'b10: inst_read_cnt <= inst_read_cnt + 1'd1;
                2'b01: inst_read_cnt <= inst_read_cnt - 1'd1;
                default: inst_read_cnt <= inst_read_cnt;
            endcase
        end
    end
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            data_read_cnt <= 2'd0;
        end else begin
            case ({arvalid && arready && arid == 4'd1, rvalid && rready && rid == 4'd1})
                2'b10: data_read_cnt <= data_read_cnt + 1'd1;
                2'b01: data_read_cnt <= data_read_cnt - 1'd1;
                default: data_read_cnt <= data_read_cnt;
            endcase
        end
    end
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            write_cnt <= 2'd0;
        end else begin
            case ({wvalid && wready, bvalid && bready})
                2'b10: write_cnt <= write_cnt + 1'd1;
                2'b01: write_cnt <= write_cnt - 1'd1;
                default: write_cnt <= write_cnt;
            endcase
        end
    end


    // AXI AR Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            arvalid <= 1'b0;
            arid <= 4'd0;
            araddr <= 32'd0;
            arsize <= 3'd0;
            arlen <= 8'd0;
            arburst <= 2'b01;
            arlock <= 2'd0;
            arcache <= 4'd0;
            arprot <= 3'd0;
        end else begin
            if (rreq_state == RREQ_DATA && !arvalid) begin
                arvalid <= 1'b1;
                arid <= 4'd1;
                araddr <= data_sram_addr;
                arsize <= {1'b0, data_sram_size};
                arlen <= 8'd0;
                arburst <= 2'b01;
                arlock <= 2'd0;
                arcache <= 4'd0;
                arprot <= 3'd0;
            end else if (rreq_state == RREQ_INST && !arvalid) begin
                arvalid <= 1'b1;
                arid <= 4'd0;
                araddr <= inst_sram_addr;
                arsize <= {1'b0, inst_sram_size};
                arlen <= 8'd0;
                arburst <= 2'b01;
                arlock <= 2'd0;
                arcache <= 4'd0;
                arprot <= 3'd0;
            end else if (arready) begin
                arvalid <= 1'b0;
            end
        end
    end

    // AXI R Channel
    assign rready = (inst_read_cnt != 2'd0) || (data_read_cnt != 2'd0) || 
                    (arvalid && arready);
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            inst_rdata_buf <= 32'd0;
            data_rdata_buf <= 32'd0;
        end else if (rvalid && rready) begin
            if (rid == 4'd0)
                inst_rdata_buf <= rdata;
            else if (rid == 4'd1)
                data_rdata_buf <= rdata;
        end
    end


    // AXI AW Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            awvalid <= 1'b0;
            awid <= 4'd1;
            awaddr <= 32'd0;
            awsize <= 3'd0;
            awlen <= 8'd0;
            awburst <= 2'b01;
            awlock <= 2'd0;
            awcache <= 4'd0;
            awprot <= 3'd0;
        end else begin
            if (wreq_state == WREQ_SEND && !awvalid && !aw_sent) begin
                awvalid <= 1'b1;
                awid <= 4'd1;
                awaddr <= data_sram_addr;
                awsize <= {1'b0, data_sram_size};
                awlen <= 8'd0;
                awburst <= 2'b01;
                awlock <= 2'd0;
                awcache <= 4'd0;
                awprot <= 3'd0;
            end else if (awready) begin
                awvalid <= 1'b0;
            end
        end
    end


    // AXI W Channel
    always @(posedge aclk) begin
        if (!aresetn) begin
            wvalid <= 1'b0;
            wid <= 4'd1;
            wdata <= 32'd0;
            wstrb <= 4'd0;
            wlast <= 1'b1;
        end else begin
            if (wreq_state == WREQ_SEND && !wvalid && !w_sent) begin
                wvalid <= 1'b1;
                wid <= 4'd1;
                wdata <= data_sram_wdata;
                wstrb <= data_sram_wstrb;
                wlast <= 1'b1;
            end else if (wready) begin
                wvalid <= 1'b0;
            end
        end
    end


    // AXI B Channel
    assign bready = (write_cnt != 2'd0) || (wvalid && wready);


    // SRAM addr_ok
    always @(posedge aclk) begin
        if (!aresetn) begin
            inst_sram_addr_ok <= 1'b0;
        end else begin
            if (rreq_state == RREQ_IDLE && inst_read_req && !data_read_req) begin
                inst_sram_addr_ok <= 1'b1;
            end else begin
                inst_sram_addr_ok <= 1'b0;
            end
        end
    end
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            data_sram_addr_ok <= 1'b0;
        end else begin
            // 读请求
            if ((rreq_state == RREQ_IDLE || rreq_state == RREQ_WAIT_RAW) && 
                data_read_req) begin
                data_sram_addr_ok <= 1'b1;
            end 
            // 写请求
            else if ((wreq_state == WREQ_IDLE || wreq_state == WREQ_WAIT_RAW) && 
                     data_write_req) begin
                data_sram_addr_ok <= 1'b1;
            end else begin
                data_sram_addr_ok <= 1'b0;
            end
        end
    end

   
    // SRAM data_ok
    always @(posedge aclk) begin
        if (!aresetn) begin
            inst_sram_data_ok <= 1'b0;
        end else begin
            inst_sram_data_ok <= rvalid && rready && (rid == 4'd0);
        end
    end
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            data_sram_data_ok <= 1'b0;
        end else begin
            data_sram_data_ok <= (rvalid && rready && (rid == 4'd1)) ||
                                 (bvalid && bready);
        end
    end

    // Output Assignments
    assign inst_sram_rdata = inst_rdata_buf;
    assign data_sram_rdata = data_rdata_buf;

endmodule