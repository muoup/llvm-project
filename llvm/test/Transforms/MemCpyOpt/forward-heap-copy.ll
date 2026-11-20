; RUN: opt -passes='memcpyopt,instcombine' -verify-memoryssa -S %s | FileCheck %s

target triple = "x86_64-unknown-linux-gnu"

declare noalias ptr @_Znwm(i64) nobuiltin allocsize(0)
declare void @_ZdlPvm(ptr, i64) nobuiltin nounwind
declare void @clobber(ptr captures(none))
declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1)

define ptr @forward_growth_copy() {
; CHECK-LABEL: define ptr @forward_growth_copy(
; CHECK-NOT: call
; CHECK: [[OUT:%.*]] = {{.*}}call {{.*}}@_Znwm(i64 32)
; CHECK-NOT: call
; CHECK-DAG: [[OUT1:%.*]] = getelementptr {{.*}}i8, ptr [[OUT]], i64 4
; CHECK-DAG: [[OUT2:%.*]] = getelementptr {{.*}}i8, ptr [[OUT]], i64 8
; CHECK-DAG: [[OUT3:%.*]] = getelementptr {{.*}}i8, ptr [[OUT]], i64 12
; CHECK-DAG: [[OUT4:%.*]] = getelementptr {{.*}}i8, ptr [[OUT]], i64 16
; CHECK-DAG: store i32 0, ptr [[OUT]], align 4
; CHECK-DAG: store i32 2, ptr [[OUT1]], align 4
; CHECK-DAG: store i32 4, ptr [[OUT2]], align 4
; CHECK-DAG: store i32 6, ptr [[OUT3]], align 4
; CHECK-DAG: store i32 8, ptr [[OUT4]], align 4
; CHECK-NOT: call
; CHECK: ret ptr [[OUT]]
  %first = call ptr @_Znwm(i64 8) builtin nounwind
  %first.1 = getelementptr inbounds i8, ptr %first, i64 4
  store i32 0, ptr %first, align 4
  store i32 2, ptr %first.1, align 4

  %temp = call ptr @_Znwm(i64 16) builtin nounwind
  %pair = load i64, ptr %first, align 4
  store i64 %pair, ptr %temp, align 4
  call void @_ZdlPvm(ptr %first, i64 8) builtin
  %temp.2 = getelementptr inbounds i8, ptr %temp, i64 8
  %temp.3 = getelementptr inbounds i8, ptr %temp, i64 12
  store i32 4, ptr %temp.2, align 4
  store i32 6, ptr %temp.3, align 4

  %out = call ptr @_Znwm(i64 32) builtin nounwind
  %out.4 = getelementptr inbounds i8, ptr %out, i64 16
  store i32 8, ptr %out.4, align 4
  call void @llvm.memcpy.p0.p0.i64(ptr align 4 %out, ptr align 4 %temp, i64 16, i1 false)
  call void @_ZdlPvm(ptr %temp, i64 16) builtin
  ret ptr %out
}

define ptr @preserve_clobbered_copy() {
; CHECK-LABEL: define ptr @preserve_clobbered_copy(
; CHECK: call void @clobber
; CHECK: call void @llvm.memcpy
; CHECK: ret ptr
  %temp = call ptr @_Znwm(i64 16) builtin nounwind
  %temp.1 = getelementptr inbounds i8, ptr %temp, i64 4
  %temp.2 = getelementptr inbounds i8, ptr %temp, i64 8
  %temp.3 = getelementptr inbounds i8, ptr %temp, i64 12
  store i32 0, ptr %temp, align 4
  store i32 2, ptr %temp.1, align 4
  store i32 4, ptr %temp.2, align 4
  store i32 6, ptr %temp.3, align 4
  call void @clobber(ptr %temp)
  %out = call ptr @_Znwm(i64 32) builtin nounwind
  call void @llvm.memcpy.p0.p0.i64(ptr align 4 %out, ptr align 4 %temp, i64 16, i1 false)
  call void @_ZdlPvm(ptr %temp, i64 16) builtin
  ret ptr %out
}
