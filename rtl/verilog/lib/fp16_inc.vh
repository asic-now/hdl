`ifndef _FP16_INC_VH
`define _FP16_INC_VH

`define FP16_QNAN               16'h7E01 // 16'h7E00 also ok.
`define FP16_SNAN               016'h7C01
`define FP16_N_QNAN             016'hFE01
`define FP16_N_SNAN             016'hFC01
`define FP16_P_INF              016'h7C00
`define FP16_N_INF              016'hFC00
`define FP16_ZERO               016'h0000
`define FP16_N_ZERO             016'h8000

`endif // _FP16_INC_VH
