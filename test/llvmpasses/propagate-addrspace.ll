; RUN: opt -load libjulia.so -PropagateJuliaAddrspaces -dce -S %s | FileCheck %s

define i64 @simple() {
; CHECK-LABEL: @simple
; CHECK-NOT: addrspace(11)
    %stack = alloca i64
    %casted = addrspacecast i64 *%stack to i64 addrspace(11)*
    %loaded = load i64, i64 addrspace(11)* %casted
    ret i64 %loaded
}

define i64 @twogeps() {
; CHECK-LABEL: @twogeps
; CHECK-NOT: addrspace(11)
    %stack = alloca i64
    %casted = addrspacecast i64 *%stack to i64 addrspace(11)*
    %gep1 = getelementptr i64, i64 addrspace(11)* %casted, i64 1
    %gep2 = getelementptr i64, i64 addrspace(11)* %gep1, i64 1
    %loaded = load i64, i64 addrspace(11)* %gep2
    ret i64 %loaded
}

define i64 @phi(i1 %cond) {
; CHECK-LABEL: @phi
; CHECK-NOT: addrspace(11)
top:
    %a = alloca i64
    %b = alloca i64
    %casteda = addrspacecast i64 *%a to i64 addrspace(11)*
    %castedb = addrspacecast i64 *%b to i64 addrspace(11)*
    br i1 %cond, label %brancha, label %bot

brancha:
    br label %bot

bot:
    %phiptr = phi i64 addrspace(11)* [ %casteda, %top ], [ %castedb, %brancha ]
    %loaded = load i64, i64 addrspace(11)* %phiptr
    ret i64 %loaded
}
