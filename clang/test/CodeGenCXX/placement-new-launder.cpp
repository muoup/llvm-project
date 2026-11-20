// RUN: %clang_cc1 -triple x86_64-unknown-linux-gnu -std=c++20 -fstrict-vtable-pointers -emit-llvm -o - %s | FileCheck %s

using size_t = decltype(sizeof(0));
void *operator new(size_t, void *) noexcept;
void *operator new[](size_t, void *) noexcept;

struct Poly {
  virtual void f();
};

struct Ordinary {
  Ordinary();
  ~Ordinary();
  Poly *ptr;
};

struct Empty {};
struct VirtualBase : virtual Empty {};

struct HoldsArray {
  Poly elements[2];
};
struct InheritsArray : HoldsArray {};

union Choice {
  Choice() : tag(0) {}
  int tag;
  InheritsArray object;
};

// CHECK-LABEL: define{{.*}} @place_int(
// CHECK-NOT: @llvm.launder.invariant.group
// CHECK: ret ptr
extern "C" int *place_int(void *p) { return new (p) int(7); }

// CHECK-LABEL: define{{.*}} @place_ordinary_array(
// CHECK-NOT: @llvm.launder.invariant.group
// CHECK: ret ptr
extern "C" Ordinary *place_ordinary_array(void *p) {
  return new (p) Ordinary[2];
}

// CHECK-LABEL: define{{.*}} @place_virtual_base(
// CHECK: call ptr @llvm.launder.invariant.group
// CHECK: ret ptr
extern "C" VirtualBase *place_virtual_base(void *p) {
  return new (p) VirtualBase;
}

// CHECK-LABEL: define{{.*}} @place_inherited_array(
// CHECK: call ptr @llvm.launder.invariant.group
// CHECK: ret ptr
extern "C" InheritsArray *place_inherited_array(void *p) {
  return new (p) InheritsArray;
}

// CHECK-LABEL: define{{.*}} @place_choice(
// CHECK: call ptr @llvm.launder.invariant.group
// CHECK: ret ptr
extern "C" Choice *place_choice(void *p) { return new (p) Choice; }

// CHECK-LABEL: define{{.*}} @place_in_byte_array(
// CHECK: call ptr @llvm.launder.invariant.group
// CHECK-NOT: @llvm.launder.invariant.group
// CHECK: ret ptr
extern "C" Poly *place_in_byte_array(void *p) {
  auto *bytes = new (p) unsigned char[sizeof(Poly)];
  return new (bytes) Poly;
}
