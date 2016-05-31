//
//  EvSocksClient.h
//  ComplateFlowRateProject
//
//  Created by Visitor on 16/3/10.
//  Copyright © 2016年 Visitor. All rights reserved.
//

#import <Foundation/Foundation.h>
@class GCDAsyncSocket;

/**
 socks Server support Authentication Method
 */
enum EVSocksClientConsultMethod {
    EVSocksClientConsultMethodNO = 0,   // NO AUTHENTICATION REQUIRED
    EVSocksClientConsultMethodGSSAPI,   // GSSAPI   (当前SDK暂不支持)
    EVSocksClientConsultMethodUSRPSD,   // USERNAME/PASSWORD
};
typedef enum EVSocksClientConsultMethod EVSocksClientConsultMethod;

/**
 Socks Server Error Message Type
 */
enum EVSocksClientError {
    EVSocksClientErrorNoError = 0,    // Never used
    EVSocksClientErrorNoAuth,         // Socks server 无需协商
    EVSocksClientErrorNOSupported,    // Socks server 协商方式不支持
    EVSocksClientErrorValidateFailed,  // Socks server 登录验证失败
};

#pragma mark - EVSocksClientDelegate
@protocol EVSocksClientDelegate <NSObject>

@required
/**
 *  当监听本地端口出错时调用
 *
 *  @param socket server Socket
 *  @param error  bind error
 */
- (void)evSocket:(GCDAsyncSocket *)socket bindError:(NSError *)error;

@optional
/**
 *  连接Socks Server失败时调用
 *
 *  @param socket remote socket
 *  @param error  错误提示
 */
- (void)evSocket:(GCDAsyncSocket *)socket didDisconnectWithError:(NSError *)error;

@end


#pragma mark - EVSocksClientConsultDelegate
/**
 *  协商Socks Server，获取Connect Server 验证方式
 */
@protocol EVSocksClientConsultDelegate <NSObject>
@optional
/**
 *  当Socks Server 协商失败时会调用此函数
 *
 *  @param socks remote socket
 *  @param error 错误提示
 */
- (void)consultSocket:(GCDAsyncSocket *)socks didFailWithError:(NSError *)error;

/**
 *  当Socks Client 成功接收 Socks Server 返回的data
 *
 *  @param socket remote socket
 */
- (void)consultSocketDidFinishLoad:(GCDAsyncSocket *)socket;
@end


#pragma mark -  EVSocksClientValidateDelegate
/**
 *   倘若Socks Server 需要验证，实现此代理提示验证信息
 */
@protocol EVSocksClientValidateDelegate <NSObject>
@optional

/**
 *  验证Socks Server 失败会调用此方法
 *
 *  @param socket 请求验证的socket Object
 *  @param error  错误提示
 */
- (void)validateSocket:(GCDAsyncSocket *)socket didFailWithError:(NSError *)error;

/**
 *  验证Socket Server 成功会调用此方法
 *
 *  @param socket 请求验证的socket Object
 */
- (void)validateSocketDidFinishLoad:(GCDAsyncSocket *)socket;

@end

@interface EVSocksClient : NSURLProtocol

@property (nonatomic, assign) EVSocksClientConsultMethod consultMethod;   //!< Proxy server 协商方式
@property (nonatomic, readonly) NSString *host;     //!< Proxy server address
@property (nonatomic, readonly) NSInteger port;     //!< Proxy server port
@property (nonatomic, readonly) NSString *method;   //!< Proxy server encrypt method
@property (nonatomic, readonly) NSString *password; //!< Proxy server encrypt password
@property (nonatomic, assign) id <EVSocksClientDelegate> evDelegate;    //!< socks Delegate
@property (nonatomic, assign) id <EVSocksClientValidateDelegate> validateDelegate;    //!< Validate Socks Delegate
@property (nonatomic, assign) id <EVSocksClientConsultDelegate> consultDelegate;  //!<  Consult Socks Delegate


/**
 *  初始化EVSocksClient
 *
 *  @param host       proxy server address
 *  @param port       proxy server port
 *  @param passoword  proxy server encrypt password
 *  @param method     proxy server encrypt method
 *
 *  @return EVSocksClient
 */
- (id)initWithHost:(NSString *)host port:(NSInteger)port;

/**
 *  更新Proxy Server信息
 *
 *  @param host      proxy server address
 *  @param port      proxy server port
 *  @param passoword proxy server encrypt password
 *  @param method    proxy server encrypt method
 */
- (void)updateHost:(NSString *)host port:(NSInteger)port password:(NSString *)passoword method:(NSString *)method;

/**
 *  设置Proxy Server 的password 和 加密方法
 *
 *  @param password socks Server 密码
 *  @param method   加密方法
 */
- (void)setSocksServerPassword:(NSString *)password method:(NSString *)method;

/**
 *  监听本地端口， 一般与Proxy Server address 相同
 *
 *  @param localPort 本地端口
 *
 *  @return return 0 if listen success, otherwise
 */
- (BOOL)startWithLocalPort:(NSInteger)localPort;

/**
 *  倘若需要验证Proxy Server，需调用此函数设置Username/Password
 *
 *  @param username 登录Proxy Server的用户名
 *  @param password 登录Proxy Server的密码
 */
- (void)setProxyServerUsr:(NSString *)username psd:(NSString *)password;


/**
 *  停止Proxy Server
 */
- (void)stop;

/**
 *  判断是否已经连接Proxy Server
 *
 *  @return return 0 if has been connected, otherwise 1
 */
- (BOOL)isConnected;

@end
