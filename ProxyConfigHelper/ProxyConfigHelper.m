//
//  ProxyConfigHelper.m
//  com.west2online.ClashX.ProxyConfigHelper
//
//  Created by yichengchen on 2019/8/17.
//  Copyright © 2019 west2online. All rights reserved.
//

#import "ProxyConfigHelper.h"
#import <AppKit/AppKit.h>
#import "ProxyConfigRemoteProcessProtocol.h"
#import "ProxySettingTool.h"

#import "com_metacubex_ClashX_ProxyConfigHelper-Swift.h"


@interface ProxyConfigHelper()
<
NSXPCListenerDelegate,
ProxyConfigRemoteProcessProtocol
>

@property (nonatomic, strong) NSXPCListener *listener;
@property (nonatomic, strong) NSMutableSet<NSXPCConnection *> *connections;
@property (nonatomic, strong) NSTimer *checkTimer;
@property (nonatomic, assign) BOOL shouldQuit;

@property (nonatomic, strong) MetaTask *metaTask;
@property (nonatomic, strong) MetaDNS *metaDNS;

@end

@implementation ProxyConfigHelper
- (instancetype)init {
    
    if (self = [super init]) {
        self.connections = [NSMutableSet new];
        self.shouldQuit = NO;
        self.listener = [[NSXPCListener alloc] initWithMachServiceName:@"com.metacubex.ClashX.ProxyConfigHelper"];
        self.listener.delegate = self;
        self.metaTask = [MetaTask new];
        self.metaDNS = [MetaDNS new];
    }
    return self;
}

- (void)run {
    [self.listener resume];
    self.checkTimer =
    [NSTimer timerWithTimeInterval:5.f target:self selector:@selector(connectionCheckOnLaunch) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.checkTimer forMode:NSDefaultRunLoopMode];
    while (!self.shouldQuit) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    }
}

- (void)connectionCheckOnLaunch {
    if (self.connections.count == 0) {
        self.shouldQuit = YES;
        [self.metaTask stop];
    }
}

- (BOOL)connectionIsVaild: (NSXPCConnection *)connection {
    NSRunningApplication *remoteApp =
    [NSRunningApplication runningApplicationWithProcessIdentifier:connection.processIdentifier];
    return remoteApp != nil;
}

// MARK: - NSXPCListenerDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
//    if (![self connectionIsVaild:newConnection]) {
//        return NO;
//    }
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ProxyConfigRemoteProcessProtocol)];
    newConnection.exportedObject = self;
    __weak NSXPCConnection *weakConnection = newConnection;
    __weak ProxyConfigHelper *weakSelf = self;
    newConnection.invalidationHandler = ^{
        [weakSelf.connections removeObject:weakConnection];
        if (weakSelf.connections.count == 0) {
            weakSelf.shouldQuit = YES;
            [weakSelf.metaTask stop];
        }
    };
    [self.connections addObject:newConnection];
    [newConnection resume];
    return YES;
}

// MARK: - ProxyConfigRemoteProcessProtocol
- (void)getVersion:(stringReplyBlock)reply {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (version == nil) {
        version = @"unknown";
    }
    reply(version);
}

- (void)enableProxyWithPort:(int)port
          socksPort:(int)socksPort
            pac:(NSString *)pac
            filterInterface:(BOOL)filterInterface
                 ignoreList:(NSArray<NSString *>*)ignoreList
            error:(stringReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        ProxySettingTool *tool = [ProxySettingTool new];
        [tool enableProxyWithport:port socksPort:socksPort pacUrl:pac filterInterface:filterInterface ignoreList:ignoreList];
        reply(nil);
    });
}

- (void)disableProxyWithFilterInterface:(BOOL)filterInterface reply:(stringReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        ProxySettingTool *tool = [ProxySettingTool new];
        [tool disableProxyWithfilterInterface:filterInterface];
        reply(nil);
    });
}


- (void)restoreProxyWithCurrentPort:(int)port
                          socksPort:(int)socksPort
                               info:(NSDictionary *)dict
                    filterInterface:(BOOL)filterInterface
                              error:(stringReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        ProxySettingTool *tool = [ProxySettingTool new];
        [tool restoreProxySetting:dict currentPort:port currentSocksPort:socksPort filterInterface:filterInterface];
        reply(nil);
    });
}

- (void)getCurrentProxySetting:(dictReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *info = [ProxySettingTool currentProxySettings];
        reply(info);
    });
}

- (void)initMetaCoreWithPath:(NSString *)path {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.metaTask setLaunchPath:path];
    });
}


- (void)startMetaWithConfPath:(NSString *)confPath ConfFilePath:(NSString *)confFilePath result:(stringReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.metaTask start:confPath confFilePath:confFilePath result:reply];
    });
}

- (void)verifyMetaWithConfPath:(NSString *)confPath ConfFilePath:(NSString *)confFilePath result:(stringReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* re = [self.metaTask test:confPath confFilePath:confFilePath];
        reply(re);
    });
}

- (void)stopMeta {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.metaTask stop];
    });
}

- (void)getUsedPorts:(stringReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.metaTask getUsedPorts:reply];
    });
}

- (void)updateTunWith:(BOOL)state {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (state) {
            [self.metaDNS updateDns];
        } else {
            [self.metaDNS revertDns];
        }
        [self.metaDNS flushDnsCache];
    });
}

@end
