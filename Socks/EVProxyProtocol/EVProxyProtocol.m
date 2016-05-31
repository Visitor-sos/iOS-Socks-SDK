//
//  EVProxyProtocol.m
//  ComplateFlowRateProject
//
//  Created by Visitor on 16/3/10.
//  Copyright © 2016年 Visitor. All rights reserved.
//

#import "EVProxyProtocol.h"

static NSURLSession *session;

@interface EVProxyProtocol() <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSessionDataTask *task;

@end

@implementation EVProxyProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

+ (void)setLocalPort:(NSInteger)localPort {
    ssLocalPort = localPort;
}

- (void)startLoading
{
    if (!session) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.connectionProxyDictionary =
        @{(NSString *)kCFStreamPropertySOCKSProxyHost: @"127.0.0.1",
          (NSString *)kCFStreamPropertySOCKSProxyPort: @(ssLocalPort)};
        session = [NSURLSession sessionWithConfiguration:configuration];
    }
    
    __weak typeof(self)weakSelf = self;
    self.task = [session dataTaskWithRequest:self.request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        //NSLog(@"%@ - %@", self.request.URL, error);
        if (error) {
            [weakSelf.client URLProtocol:weakSelf didFailWithError:error];
        } else {
            [weakSelf.client URLProtocol:weakSelf didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
            [weakSelf.client URLProtocol:weakSelf didLoadData:data];
            [weakSelf.client URLProtocolDidFinishLoading:weakSelf];
        }
    }];
    [self.task resume];
}

- (void)stopLoading {
    [self.task cancel];
}

@end
