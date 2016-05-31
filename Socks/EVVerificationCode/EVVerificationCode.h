//
//  VerificationCode.h
//  ExplorerSDKForFlowRate
//
//  Created by Visitor on 16/4/11.
//  Copyright © 2016年 Visitor. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 获取验证码异常类型
 */
enum EVVerificationError {
    EVVerificationErrorNoError = 0,    // Never used
    EVVerificationErrorServerAddressNil,   // 验证码服务器地址为nil
};

/**
 *  请求验证码，设置请求timeout为5s
 */
@protocol EVVerificationCodeDelegate <NSObject>

/**
 *  服务器响应请求
 *
 *  @param connection connection
 *  @param response   response
 */
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;

/**
 *   接收验证码服务器返回的数据
 *
 *  @param connection connection
 *  @param data       返回的NSData
 */
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;

/**
 *  数据接收完成
 *
 *  @param connection connection
 */
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

/**
 *  当网络异常或其他原因导致获取验证码失败时会调用此函数
 *
 *  @param connection 连接验证码Server的Connection
 *  @param error      错误信息
 */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;

@end

@interface EVVerificationCode : NSObject
@property (nonatomic, strong) NSMutableData *registerData;                 //!<    服务器返回的注册用户相关数据
@property (nonatomic, strong) NSMutableData *verifyCodeData;            //!<    服务器返回的验证码相关信息
@property (nonatomic, strong) NSMutableData *loginData;                     //!<    服务器返回的Socks Server相关数据

@property (nonatomic, assign) BOOL isRegister;      //!<    判断是否是注册
@property (nonatomic, assign) BOOL isGetVerifyCode;    //!<   判断是否获取验证码
@property (nonatomic, assign) BOOL isLogin;           //!<   判断是否登录

@property (nonatomic, assign) id <EVVerificationCodeDelegate> delegate;

/**
 *  初始化服务器地址
 *
 *  @param serverAddress 服务器地址
 *
 *  @return [EVVerificationCode object]
 */
- (id)initWithVerificationCodeServerAddress:(NSString *)serverAddress;

/**
 *  注册账户
 */
- (void)registerAccountWithHttpBody:(NSString *)httpBody;


/**
 *  输入手机号码，获取验证码
 *  说明：
 *       1、首次运行App, 需要获取验证码进行验证
 *       2、验证通过后，再运行App， 用户无需再次验证， 但是需要开发者手动验证
 *       3、步骤2 需要同时满足两个条件（已经验证通过过 && 验证返回的password还未过期）
 *
 *   @param httpBody:   请求登录服务器的json,详细格式请参考接口文旦
 */
- (void)getVerificationCodeWithHttpBody:(NSString *)httpBody;

/**
 *  根据返回的验证码， 再次请求获取 socks Server 的 password
 *
 *  在获取验证码之后，
 *
 *  @param httpBody   http 请求体，详细参考接口文档
 */
- (void)getSocksServerPasswordWithHttpBody:(NSString *)httpBody;

/**
 *  前提：不是首次运行程序，即已经登录成功过
 *  说明：
 *       在已经验证通过过登录服务器之后的每次再次运行程序，开发者需要调用此函数传参password验证
 *       注：此步骤为开发者完成， 无需用户参与
 *
 *  @param password: 这里的password即为首次运行程序时，在调用getSocksServerPasswordWithVerificationCode:函数后，在delegate中获取到的password
 *
 *  目的：
 *       1、检测此用户是否合法
 *       2、检测密码是否过期
 */
//- (void)validatePassword:(NSString *)password serverAddress:(NSString *)serverAddr;

/**
 *  获取手机IDFA
 */
- (NSString *)getDevceIDFA;

@end
