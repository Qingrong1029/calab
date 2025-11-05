// ========================================
// LoongArch CSR 地址宏定义
// ========================================

// ========== 系统控制类 ==========
`define CSR_CRMD       14'h0000   // 当前模式寄存器
`define CSR_PRMD       14'h0001   // 先前模式寄存器
`define CSR_EUEN       14'h0002   // 扩展使能寄存器
`define CSR_ECFG       14'h0004   // 异常配置寄存器
`define CSR_ESTAT      14'h0005   // 异常状态寄存器
`define CSR_ERA        14'h0006   // 异常返回地址寄存器
`define CSR_BADV       14'h0007   // 异常虚拟地址寄存器
`define CSR_EENTRY     14'h000c   // 异常入口寄存器

// ========== 处理器标识类 ==========
`define CSR_CPUID      14'h0020   // CPU 标识寄存器

// ========== 计时类 ==========
`define CSR_TID        14'h0040   // 定时器 ID
`define CSR_TCFG       14'h0041   // 定时器配置寄存器
`define CSR_TVAL       14'h0042   // 定时器当前值
`define CSR_TICLR      14'h0044   // 定时器清除寄存器

// ========== 保存通用寄存器类（软件可用） ==========
`define CSR_SAVE0      14'h0030
`define CSR_SAVE1      14'h0031
`define CSR_SAVE2      14'h0032
`define CSR_SAVE3      14'h0033
`define CSR_SAVE4      14'h0034
`define CSR_SAVE5      14'h0035
`define CSR_SAVE6      14'h0036
`define CSR_SAVE7      14'h0037

// ========== 其他 ==========
`define CSR_TLBIDX     14'h0010
`define CSR_TLBEHI     14'h0011
`define CSR_TLBELO0    14'h0012
`define CSR_TLBELO1    14'h0013
`define CSR_ASID       14'h0018
`define CSR_PGDL       14'h0019
`define CSR_PGDH       14'h001a
`define CSR_PGD        14'h001b
`define CSR_PWCL       14'h001c
`define CSR_PWCH       14'h001d
`define CSR_STLBIDX    14'h001e
`define CSR_RVACFG     14'h001f

// ========== 常用宏 ==========
`define CSR_MASK       14'h3fff   // CSR 地址掩码

// 例外编码 (Ecode) 宏定义
`define ECODE_INT        5'h00    // 中断
`define ECODE_PIL        5'h01    // load操作页无效例外
`define ECODE_PIS        5'h02    // store操作页无效例外
`define ECODE_PIF        5'h03    // 取指操作页无效例外
`define ECODE_PME        5'h04    // 页修改例外
`define ECODE_PPI        5'h07    // 页特权等级不合规例外
`define ECODE_ADE        5'h08    // 取指地址错例外
`define ECODE_ALE        5'h09    // 地址非对齐例外
`define ECODE_SYS        5'h0B    // 系统调用例外
`define ECODE_BRK        5'h0C    // 断点例外
`define ECODE_INE        5'h0D    // 指令不存在例外
`define ECODE_IPE        5'h0E    // 指令特权等级错例外
`define ECODE_FPD        5'h0F    // 浮点指令未使能例外
`define ECODE_FPE        5'h12    // 基础浮点指令例外
`define ECODE_TLBR       5'h3F    // TLB重填例外

// EsubCode 宏定义（针对有子编码的例外）
`define ESUB_ADE         3'h0     // 取指地址错例外
`define ESUB_ADEM        3'h1     // 访存指令地址错例外

// 保留编码范围
`define ECODE_RESERVED_LOW  5'h1A  // 保留编码起始
`define ECODE_RESERVED_HIGH 5'h3E  // 保留编码结束

`define CSR_CRMD_PLV    1 :0
`define CSR_CRMD_IE     2
`define CSR_PRMD_PPLV   1 :0
`define CSR_PRMD_PIE    2
`define CSR_ECFG_LIE    12:0
`define CSR_ESTAT_IS10  1 :0
`define CSR_TICLR_CLR   0
`define CSR_ERA_PC      31:0
`define CSR_BADV_VADDR  31:0
`define CSR_EENTRY_VA   31:6
`define CSR_SAVE_DATA   31:0
`define CSR_TID_TID     31:0
`define CSR_TCFG_EN     0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV  31:2
`define CSR_TVAL_TIMEVAL 31:0
`define CSR_TICLR_CLR   0
`define CSR_CPUID_COREID  8 :0
`define CSR_CPUID_CPUTYPE 31:9