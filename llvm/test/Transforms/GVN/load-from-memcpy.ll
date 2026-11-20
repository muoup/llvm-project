; RUN: opt -passes=gvn -S < %s | FileCheck %s
; RUN: opt -passes='gvn<memoryssa>' -S < %s | FileCheck %s

target datalayout = "e-p:64:64"

declare noalias ptr @malloc(i64)
declare void @free(ptr captures(none)) memory(argmem: readwrite, inaccessiblemem: readwrite)
declare void @overwrite(ptr captures(none)) memory(argmem: write)
declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1)
declare ptr @llvm.launder.invariant.group.p0(ptr)

define i32 @forward_heap_slice(ptr %dest) {
; CHECK-LABEL: @forward_heap_slice(
; CHECK: ret i32 4
  %source = call ptr @malloc(i64 16)
  store i64 17179869186, ptr %source, align 4
  %next = getelementptr inbounds i8, ptr %source, i64 8
  %slot = call ptr @llvm.launder.invariant.group.p0(ptr %next)
  store i32 6, ptr %slot, align 4
  call void @llvm.memcpy.p0.p0.i64(ptr %dest, ptr %source, i64 12, i1 false)
  store i64 0, ptr %source, align 4
  call void @free(ptr %source)
  %field = getelementptr inbounds i8, ptr %dest, i64 4
  %result = load i32, ptr %field, align 4
  ret i32 %result
}

define i32 @forward_offset_source(ptr %dest, i64 %value) {
; CHECK-LABEL: @forward_offset_source(
; CHECK: [[SHIFT:%.*]] = lshr i64 %value, 32
; CHECK: [[TRUNC:%.*]] = trunc i64 [[SHIFT]] to i32
; CHECK: ret i32 [[TRUNC]]
  %source = alloca i64, align 8
  store i64 %value, ptr %source, align 8
  %slice = getelementptr inbounds i8, ptr %source, i64 4
  call void @llvm.memcpy.p0.p0.i64(ptr %dest, ptr %slice, i64 4, i1 false)
  %result = load i32, ptr %dest, align 4
  ret i32 %result
}

define i32 @source_clobber(ptr %dest) {
; CHECK-LABEL: @source_clobber(
; CHECK: %result = load i32, ptr %field
; CHECK: ret i32 %result
  %source = alloca i64, align 8
  store i64 17179869186, ptr %source, align 8
  call void @overwrite(ptr %source)
  call void @llvm.memcpy.p0.p0.i64(ptr %dest, ptr %source, i64 8, i1 false)
  %field = getelementptr inbounds i8, ptr %dest, i64 4
  %result = load i32, ptr %field, align 4
  ret i32 %result
}

define i32 @partial_source_store(ptr %dest) {
; CHECK-LABEL: @partial_source_store(
; CHECK: %result = load i32, ptr %field
; CHECK: ret i32 %result
  %source = alloca i64, align 8
  store i64 17179869186, ptr %source, align 8
  %slice = getelementptr inbounds i8, ptr %source, i64 4
  store i16 8, ptr %slice, align 4
  call void @llvm.memcpy.p0.p0.i64(ptr %dest, ptr %source, i64 8, i1 false)
  %field = getelementptr inbounds i8, ptr %dest, i64 4
  %result = load i32, ptr %field, align 4
  ret i32 %result
}

define i32 @partial_copy(ptr %dest) {
; CHECK-LABEL: @partial_copy(
; CHECK: %result = load i32, ptr %field
; CHECK: ret i32 %result
  %source = alloca i64, align 8
  store i64 17179869186, ptr %source, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr %dest, ptr %source, i64 6, i1 false)
  %field = getelementptr inbounds i8, ptr %dest, i64 4
  %result = load i32, ptr %field, align 4
  ret i32 %result
}

define i32 @dest_clobber(ptr %dest) {
; CHECK-LABEL: @dest_clobber(
; CHECK: %result = load i32, ptr %field
; CHECK: ret i32 %result
  %source = alloca i64, align 8
  store i64 17179869186, ptr %source, align 8
  call void @llvm.memcpy.p0.p0.i64(ptr %dest, ptr %source, i64 8, i1 false)
  call void @overwrite(ptr %dest)
  %field = getelementptr inbounds i8, ptr %dest, i64 4
  %result = load i32, ptr %field, align 4
  ret i32 %result
}
