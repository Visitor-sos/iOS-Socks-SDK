//
//  VerificationCode.m
//  ExplorerSDKForFlowRate
//
//  Created by Visitor on 16/4/11.
//  Copyright © 2016年 Visitor. All rights reserved.
//

#import "EVVerificationCode.h"
#import <UIKit/UIKit.h>
#import "Utils.h"
#import <SBJson/SBJson4.h>
#import <AdSupport/AdSupport.h>

NSString *const EVVerificationErrorDomain = @"EVVerificationErrorDomain";

@interface EVVerificationCode () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, copy) NSString *serverAddress;
@property (nonatomic, copy) NSString *telephoneNumber;
;
@end


@implementation EVVerificationCode {
    NSURLConnection *registerConnect;
    NSURLConnection *verifyCodeConnect;
    NSURLConnection *loginConnect;
}
- (id)initWithVerificationCodeServerAddress:(NSString *)serverAddress {
    if(self = [super init]) {
        self.serverAddress = serverAddress;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setValue:serverAddress forKey:EVKey_Server_Address];
        [defaults synchronize];
    }
    return self;
}

- (void)registerAccountWithHttpBody:(NSString *)httpBody {
    NSString *serverAddress = [[NSUserDefaults standardUserDefaults] valueForKey:EVKey_Server_Address];
    if(!serverAddress) {
#ifdef DEBUG
        NSLog(@"服务器地址为%@", serverAddress);
#endif
    }
    else {
        // 创建请求对象
        NSURL *addrUrl = [NSURL URLWithString:serverAddress];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:addrUrl];
        request.timeoutInterval = 10.0f;
        request.HTTPMethod = @"POST";
        
        request.HTTPBody = [httpBody dataUsingEncoding:NSUTF8StringEncoding];
        registerConnect = [NSURLConnection connectionWithRequest:request delegate:self];
        [registerConnect start];
    }
}

- (void)getVerificationCodeWithHttpBody:(NSString *)httpBody {
    // 设置请求路径
    if(!self.serverAddress || [self.serverAddress isEqualToString:@""]) {
        NSError *serverNilErr = [self serverAddress:[NSString stringWithFormat:@"服务器地址为空，请检查%@", self.serverAddress]];
        [self.delegate connection:nil didFailWithError:serverNilErr];
        return;
    }
    
    NSString *urlStr = self.serverAddress;
    NSURL *url = [NSURL URLWithString:urlStr];
    
    // 创建请求对象
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 5.0f;
    request.HTTPMethod = @"POST";
    
    // 设置请求体
    request.HTTPBody =[httpBody dataUsingEncoding:NSUTF8StringEncoding];
    verifyCodeConnect = [NSURLConnection connectionWithRequest:request delegate:self];
    [verifyCodeConnect start];
}


- (void)getSocksServerPasswordWithHttpBody:(NSString *)httpBody {
    // 设置请求路径
    if(!self.serverAddress || [self.serverAddress isEqualToString:@""]) {
        NSError *serverNilErr = [self serverAddress:[NSString stringWithFormat:@"服务器地址为空，请检查%@", self.serverAddress]];
        [self.delegate connection:nil didFailWithError:serverNilErr];
        return;
    }
    NSString *urlStr = self.serverAddress;
    NSURL *url = [NSURL URLWithString:urlStr];
    
    // 创建请求对象
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 5.0f;
    request.HTTPMethod = @"POST";
    
    // 设置请求体
    request.HTTPBody = [httpBody dataUsingEncoding:NSUTF8StringEncoding];
    loginConnect = [NSURLConnection connectionWithRequest:request delegate:self];
    [loginConnect start];
}

//- (void)validatePassword:(NSString *)password serverAddress:(NSString *)serverAddr {
//    NSString *serverAddressStr = [[NSUserDefaults standardUserDefaults] valueForKey:EVKey_Server_Address];
//    NSURL *url = [NSURL URLWithString:serverAddressStr];
//
//    // 创建请求对象
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
//    request.timeoutInterval = 5.0f;
//    request.HTTPMethod = @"POST";
//
//    NSString *telephoneNumberStr = [[NSUserDefaults standardUserDefaults] valueForKey:EVKey_Client_TelNumber];
//    NSString *passwordStr = [[NSUserDefaults standardUserDefaults] valueForKey:EVKey_SocksPassword];
//
//    // 设置请求体
//    NSString *paramStr = [NSString stringWithFormat:@"telephoneNumber=%@, verificationCode=%@", telephoneNumberStr, passwordStr];
//    request.HTTPBody = [paramStr dataUsingEncoding:NSUTF8StringEncoding];
//    NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
//    [connection start];
//}


#pragma mark -- NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if(connection == registerConnect) {
        if(!self.registerData) {
            self.registerData = [[NSMutableData alloc] init];
        }
        else {
            [self.registerData setLength:0];
        }
    }
    else if(connection == verifyCodeConnect) {
        if(!self.verifyCodeData) {
            self.verifyCodeData = [[NSMutableData alloc] init];
        }
        else {
            [self.verifyCodeData setLength:0];
        }
    }
    else if(connection == loginConnect) {
        if(!self.loginData) {
            self.loginData = [[NSMutableData alloc] init];
        }
        else {
            [self.loginData setLength:0];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    //    NSLog(@"data:%@", data);
    
    // 存储数据
    if(connection == registerConnect) {
        [self.registerData appendData:data];
    }
    else if(connection == verifyCodeConnect) {
        [self.verifyCodeData appendData:data];
    }
    else if(connection == loginConnect) {
        [self.loginData appendData:data];
    }
    [self.delegate connection:connection didReceiveData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSUserDefaults *defalue = [NSUserDefaults standardUserDefaults];
    if(connection == registerConnect) {
        [defalue setValue:self.registerData forKey:EVServer_ResponseData_Register];
        self.isRegister = YES;
        self.isLogin = NO;
        self.isGetVerifyCode = NO;
    }
    else if(connection == verifyCodeConnect) {
        [defalue setValue:self.verifyCodeData forKey:EVServer_ResponseData_VerifyCode];
        self.isRegister = NO;
        self.isLogin = NO;
        self.isGetVerifyCode = YES;
    }
    else if(connection == loginConnect) {
        [defalue setValue:self.loginData forKey:EVServer_ResponseData_Login];
        self.isRegister = NO;
        self.isLogin = YES;
        self.isGetVerifyCode = NO;
        // 存储 Telephone number
        [defalue setValue:self.telephoneNumber forKey:EVKey_Client_TelNumber];
    }
    [defalue synchronize];
    [self.delegate connectionDidFinishLoading:connection];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.delegate connection:connection didFailWithError:error];
}

/**
 *     https请求，取消服务器证书认证
 **/
- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
        
        [[challenge sender]  useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
        [[challenge sender]  continueWithoutCredentialForAuthenticationChallenge: challenge];
    }
}

/**
 *  服务器地址为空
 *
 *  @param errMsg error tips
 *
 *  @return NSError
 */
- (NSError *)serverAddress:(NSString *)errMsg {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:EVVerificationErrorDomain code:EVVerificationErrorServerAddressNil userInfo:userInfo];
}

#pragma mark - idfa
- (NSString *)getDevceIDFA {
    return [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
}

@end
