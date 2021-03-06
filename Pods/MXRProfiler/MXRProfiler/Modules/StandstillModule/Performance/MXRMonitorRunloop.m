//
//  MXRMonitorRunloop.m
//  easywayout
//
//  Created by Martin.Liu on 17/1/19.
//  Copyright © 2017年 MAIERSI. All rights reserved.
//

#import "MXRMonitorRunloop.h"
#import "MXRCallStack.h"
#import "MXRProfilerMacro.h"
#import "UIDevice+MXRProfiler.h"

// minimum
static const NSInteger MXRMonitorRunloopMinOneStandstillMillisecond = 20;
static const NSInteger MXRMonitorRunloopMinStandstillCount = 1;

// default
static const NSInteger MXRMonitorRunloopOneStandstillMillisecond = 300;      // 超过多少毫秒为一次卡顿
static const NSInteger MXRMonitorRunloopStandstillCount = 5;                // 多少次卡顿纪录为一次有效卡顿

// for 7 series
static const NSInteger MXRMonitorRunloopOneStandstillMillisecond_ForIPhone7eries = 300;
static const NSInteger MXRMonitorRunloopStandstillCount_ForIPhone7Series = 5;

// for 6 series
static const NSInteger MXRMonitorRunloopOneStandstillMillisecond_ForIPhone6Series = 400;
static const NSInteger MXRMonitorRunloopStandstillCount_ForIPhone6Series = 5;

// for 5 series
static const NSInteger MXRMonitorRunloopOneStandstillMillisecond_ForIPhone5Series = 500;
static const NSInteger MXRMonitorRunloopStandstillCount_ForIPhone5Series = 5;

// for old machine
static const NSInteger MXRMonitorRunloopOneStandstillMillisecond_ForOldMachine = 600;
static const NSInteger MXRMonitorRunloopStandstillCount_ForOldMachine = 5;

@interface MXRMonitorRunloop(){
    CFRunLoopObserverRef _observer;
    dispatch_semaphore_t _semaphore;
    CFRunLoopActivity _activity;
    NSInteger _countTime;
    NSMutableArray *_backtrace;
    BOOL _isCancel;
}

@end

@implementation MXRMonitorRunloop

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static MXRMonitorRunloop *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
        if (kMXRISIphone7Series()) {
            sharedInstance.limitMillisecond = MXRMonitorRunloopOneStandstillMillisecond_ForIPhone7eries;
            sharedInstance.standstillCount  = MXRMonitorRunloopStandstillCount_ForIPhone7Series;
        }
        else if (kMXRISIphone6Series())
        {
            sharedInstance.limitMillisecond = MXRMonitorRunloopOneStandstillMillisecond_ForIPhone6Series;
            sharedInstance.standstillCount  = MXRMonitorRunloopStandstillCount_ForIPhone6Series;
        }
        else if (kMXRISIphone5Series())
        {
            sharedInstance.limitMillisecond = MXRMonitorRunloopOneStandstillMillisecond_ForIPhone5Series;
            sharedInstance.standstillCount  = MXRMonitorRunloopStandstillCount_ForIPhone5Series;
        }
        else if (kMXRISOldMachie())
        {
            sharedInstance.limitMillisecond = MXRMonitorRunloopOneStandstillMillisecond_ForOldMachine;
            sharedInstance.standstillCount  = MXRMonitorRunloopStandstillCount_ForOldMachine;
        }
        else
        {
            sharedInstance.limitMillisecond = MXRMonitorRunloopOneStandstillMillisecond;
            sharedInstance.standstillCount  = MXRMonitorRunloopStandstillCount;
        }
    });
    return sharedInstance;
}

- (void)setLimitMillisecond:(int)limitMillisecond
{
    [self willChangeValueForKey:@"limitMillisecond"];
    _limitMillisecond = limitMillisecond >= MXRMonitorRunloopMinOneStandstillMillisecond ? limitMillisecond : MXRMonitorRunloopMinOneStandstillMillisecond;
    [self didChangeValueForKey:@"limitMillisecond"];
}

- (void)setStandstillCount:(int)standstillCount
{
    [self willChangeValueForKey:@"standstillCount"];
    _standstillCount = standstillCount >= MXRMonitorRunloopMinStandstillCount ? standstillCount : MXRMonitorRunloopMinStandstillCount;
    [self didChangeValueForKey:@"standstillCount"];
}

- (void) startMonitor
{
    _isCancel = NO;
    [self registerObserver];
}

- (void) endMonitor
{
    _isCancel = YES;
    if(!_observer) return;
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    CFRelease(_observer);
    _observer = NULL;
}

static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    MXRMonitorRunloop *instance = [MXRMonitorRunloop sharedInstance];
    instance->_activity = activity;
    // 发送信号
    dispatch_semaphore_t semaphore = instance->_semaphore;
    dispatch_semaphore_signal(semaphore);
}

- (void)registerObserver
{
    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL};
    _observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                        kCFRunLoopAllActivities,
                                        YES,
                                        0,
                                        &runLoopObserverCallBack,
                                        &context);
    CFRunLoopAddObserver(CFRunLoopGetMain(), _observer, kCFRunLoopCommonModes);
    // 创建信号
    _semaphore = dispatch_semaphore_create(0);
    
    // 在子线程监控时长
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        while (YES) {
            @autoreleasepool {
                if (_isCancel) {
                    return;
                }
                // N次卡顿超过阈值T记录为一次卡顿
                // Returns zero on success, or non-zero if the timeout occurred.
                long dsw = dispatch_semaphore_wait(_semaphore, dispatch_time(DISPATCH_TIME_NOW, _limitMillisecond * NSEC_PER_MSEC));
                if (dsw != 0) {
                    if (_activity == kCFRunLoopBeforeSources || _activity == kCFRunLoopAfterWaiting) {
                        if (++_countTime < _standstillCount) continue;
                        if (self.callbackWhenStandStill) {
                            self.callbackWhenStandStill();
                        }
                        // post noti when happend standstill
                        mxr_dispatch_async_on_main_queue(^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:MXRPROFILERNOTIFICATION_HAPPENSTANDSTILL object:nil];
                        });
                    }
                }
                _countTime = 0;
            }
        }
    });
}

@end
