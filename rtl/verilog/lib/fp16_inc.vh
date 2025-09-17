`ifndef _FP16_INC_VH
`define _FP16_INC_VH

`define FP16_QNAN               16'h7E01 // 16'h7E00 also ok.
`define FP16_SNAN               16'h7C01
`define FP16_N_QNAN             16'hFE01
`define FP16_N_SNAN             16'hFC01
`define FP16_P_INF              16'h7C00
`define FP16_N_INF              16'hFC00
`define FP16_ZERO               16'h0000
`define FP16_P_ZERO             16'h0000
`define FP16_N_ZERO             16'h8000

`endif // _FP16_INC_VH
