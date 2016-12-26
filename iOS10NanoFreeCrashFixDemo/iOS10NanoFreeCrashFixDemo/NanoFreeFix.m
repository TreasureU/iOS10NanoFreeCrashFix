//
//  NanoFreeFix.m
//  iOS10NanoFreeCrashFixDemo
//
//  Created by ChengJianFeng on 2016/12/26.
//  Copyright © 2016年 ChengJianFeng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <malloc/malloc.h>
#include <libkern/OSAtomic.h>
#include <sys/mman.h>
#import <stdatomic.h>

malloc_zone_t* NanoCrashGuardInitialize();
static malloc_zone_t*s_default_zone = NULL;
static malloc_zone_t*s_guard_zone = NULL;
typedef void *(*GuardMalloc) (struct _malloc_zone_t*zone, size_t size);
typedef void (*GuardFree) (struct _malloc_zone_t*zone, void*prt);
typedef size_t (*GuardSize)(struct _malloc_zone_t*zone, const void*prt);
GuardMalloc s_default_zone_origin_malloc = NULL;
GuardFree s_default_zone_origin_free = NULL;
GuardSize s_default_zone_origin_size = NULL;

typedef void *(*GuardRealloc) (struct _malloc_zone_t*zone, void * ptr, size_t size);
GuardRealloc s_default_zone_origin_realloc = NULL;
void *default_zone_realloc(struct _malloc_zone_t*zone, void * ptr, size_t size)
{
    size_t s = s_guard_zone->size(s_guard_zone,ptr);
    if(s){
        return malloc_zone_realloc(s_guard_zone, ptr, size);
    }
    return s_default_zone_origin_realloc(zone, ptr, size);
}

typedef void *(*GuardCalloc) (struct _malloc_zone_t*zone, size_t num_items, size_t size);
GuardCalloc s_default_zone_origin_calloc = NULL;
void *default_zone_calloc(struct _malloc_zone_t*zone, size_t num_items, size_t size)
{
    return malloc_zone_calloc(s_guard_zone, num_items, size);
}

typedef void *(*GuardValloc) (struct _malloc_zone_t*zone, size_t size);
GuardValloc s_default_zone_origin_valloc = NULL;
void *default_zone_valloc(struct _malloc_zone_t*zone, size_t size)
{
    return malloc_zone_valloc(s_guard_zone, size);
}

void*default_zone_malloc(struct _malloc_zone_t*zone, size_t size)
{
    return malloc_zone_malloc(s_guard_zone, size);
}
void default_zone_free(struct _malloc_zone_t*zone, void*ptr)
{
    size_t s = s_guard_zone->size(s_guard_zone,ptr);
    if(s){
        return malloc_zone_free(s_guard_zone, ptr);
    }
    return s_default_zone_origin_free(zone, ptr);
}
size_t default_zone_size(struct _malloc_zone_t *zone, const void*ptr)
{
    size_t s = s_guard_zone->size(s_guard_zone, ptr);
    if(s)return s;
    return s_default_zone_origin_size(zone, ptr);
}

malloc_zone_t*NanoCrashGuardInitialize()
{
    malloc_zone_t * tmp_s_guard_zone = malloc_create_zone(getpagesize(), 0);
    malloc_set_zone_name(tmp_s_guard_zone, "GuardZone");
    s_default_zone = malloc_default_zone();
    mprotect(s_default_zone, sizeof(malloc_zone_t),PROT_READ | PROT_WRITE);
    OSMemoryBarrier();
    OSAtomicCompareAndSwapPtr((void*)s_default_zone_origin_malloc,(void*)s_default_zone->malloc,(void*volatile)&s_default_zone_origin_malloc);
    OSAtomicCompareAndSwapPtr((void*)s_default_zone_origin_free,(void*)s_default_zone->free,(void*volatile)&s_default_zone_origin_free);
    OSAtomicCompareAndSwapPtr((void*)s_default_zone_origin_size,(void*)s_default_zone->size,(void*volatile)&s_default_zone_origin_size);
    OSAtomicCompareAndSwapPtr((void*)s_default_zone->malloc,(void*)default_zone_malloc,(void*volatile)&s_default_zone->malloc);
    OSAtomicCompareAndSwapPtr((void*)s_default_zone->free,(void*)default_zone_free,(void*volatile)&s_default_zone->free);
    OSAtomicCompareAndSwapPtr((void*)s_default_zone->size,(void*)default_zone_size,(void*volatile)&s_default_zone->size);
    
    OSAtomicCompareAndSwapPtr((void*)s_default_zone_origin_realloc,(void*)s_default_zone->realloc,(void*volatile)&s_default_zone_origin_realloc);
    OSAtomicCompareAndSwapPtr((void*)s_default_zone->realloc,(void*)default_zone_realloc,(void*volatile)&s_default_zone->realloc);
    
    OSAtomicCompareAndSwapPtr((void*)s_default_zone_origin_calloc,(void*)s_default_zone->calloc,(void*volatile)&s_default_zone_origin_calloc);
    OSAtomicCompareAndSwapPtr((void*)s_default_zone->calloc,(void*)default_zone_calloc,(void*volatile)&s_default_zone->calloc);
    
    OSAtomicCompareAndSwapPtr((void*)s_default_zone_origin_valloc,(void*)s_default_zone->valloc,(void*volatile)&s_default_zone_origin_valloc);
    OSAtomicCompareAndSwapPtr((void*)s_default_zone->valloc,(void*)default_zone_valloc,(void*volatile)&s_default_zone->valloc);
    
    OSMemoryBarrier();
    mprotect(s_default_zone, sizeof(malloc_zone_t), PROT_READ);
    return tmp_s_guard_zone;
}

static BOOL needFix() {
    NSString *version = [[UIDevice currentDevice] systemVersion];
    if (NO ==[version respondsToSelector:@selector(containsString:)]) {
        return NO;
    }
    //只有这两个小版本需要修复，其他版本不用。iOS 10.2上已经修复这个问题，虽然realloc依然有问题，但是可以继续观察。
    if( [version hasPrefix:@"10.0"] || [version hasPrefix:@"10.1"] ){
        NSLog(@"Now version is %@,需要修复",version);
        return YES;
    }else {
        NSLog(@"Now version is %@,不需要修复",version);
        return NO;
    }
}

__attribute__((constructor)) static void JDSHFupFix(void) {
    @autoreleasepool {
        if (needFix()) {
            NSLog(@"Nano Free bug 修复代码生效");
            s_guard_zone = NanoCrashGuardInitialize();
        }
    }
}
