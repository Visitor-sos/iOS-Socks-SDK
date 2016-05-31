//
//  EVProxyProtocol.h
//  ComplateFlowRateProject
//
//  Created by Visitor on 16/3/10.
//  Copyright © 2016年 Visitor. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSInteger ssLocalPort;

@interface EVProxyProtocol : NSURLProtocol


/**
 *  监听本地端口
 *
 *  @param localPort 本地端口
 */
+ (void)setLocalPort:(NSInteger)localPort;

@end
