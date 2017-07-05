//
//  EvSocksClient.m
//  ComplateFlowRateProject
//
//  Created by Visitor on 16/3/10.
//  Copyright © 2016年 Visitor. All rights reserved.
//



//#define EServerHost @"ServerHost"
//#define EServerPort @"ServerPort"
//#define EServerPassword @"ServerPassword"
//#define EServerMethod @"ServerMethod"


#import "EvSocksClient.h"
#include "encrypt.h"
#include "socks5.h"
#include <arpa/inet.h>
#import <UIKit/UIKit.h>
#import "GCDAsyncSocket.h"
#import "Utils.h"


NSString *const EVSocksClientErrorDomain = @"EVSocksClientErrorDomain";


@interface EVPipeline : NSObject
{
@public
    struct encryption_ctx sendEncryptionContext;
    struct encryption_ctx recvEncryptionContext;
}

@property (nonatomic, strong) GCDAsyncSocket *localSocket;
@property (nonatomic, strong) GCDAsyncSocket *remoteSocket;
@property (nonatomic, assign) int stage;
@property (nonatomic, strong) NSData *addrData;
@property (nonatomic, strong) NSData *requestData;
@property (nonatomic, strong) NSData *destinationData;    //!< 用于存续将目标地址解析后的数据

- (void)disconnect;

@end

@implementation EVPipeline

- (void)disconnect {
    [self.localSocket disconnectAfterReadingAndWriting];
    [self.remoteSocket disconnectAfterReadingAndWriting];
}

@end

@interface EVSocksClient () <GCDAsyncSocketDelegate>

@property (nonatomic, strong) NSString *username;    //!< a username use validate socks server
@property (nonatomic, strong) NSString *password;    //!< a password use validate socks server

@end

@implementation EVSocksClient {
    dispatch_queue_t _socketQueue;   /// queue, async request
    GCDAsyncSocket *_serverSocket;   /// listen local port
    NSMutableArray *_pipelines;      /// 所有连接Socks Server 的Object
    NSString *_host;
    NSInteger _port;
    NSString *_method;
    NSString *_passoword;
}

@synthesize host = _host;
@synthesize port = _port;
@synthesize method = _method;
@synthesize password = _passoword;


#pragma mark - 根据Local/Remote Socket,查找Super Object
/**
 *  根据当前local socket对象查找父对象
 *
 *  @param localSocket localSocket
 *
 *  @return EVPipeline Object
 */
- (EVPipeline *)pipelineOfLocalSocket:(GCDAsyncSocket *)localSocket {
    __block EVPipeline *ret;
    [_pipelines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        EVPipeline *pipeline = obj;
        if (pipeline.localSocket == localSocket) {
            ret = pipeline;
        }
    }];
    return ret;
}

/**
 *  根据当前remote socket对象查找父对象
 *
 *  @param remoteSocket remoteSocket
 *
 *  @return EVPipeline Object
 */
- (EVPipeline *)pipelineOfRemoteSocket:(GCDAsyncSocket *)remoteSocket {
    __block EVPipeline *ret;
    [_pipelines enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        EVPipeline *pipeline = obj;
        if (pipeline.remoteSocket == remoteSocket) {
            ret = pipeline;
        }
    }];
    return ret;
}


#pragma mark - Initial
#pragma mark -- 初始化函数
- (id)initWithHost:(NSString *)host port:(NSInteger)port {
    self = [super init];
    if (self) {
#ifdef DEBUG
        NSLog(@"Socks Server: %@", host);
#endif
        _host = [host copy];
        _port = port;
    }
    return self;
}

#pragma mark -- 更新
- (void)updateHost:(NSString *)host port:(NSInteger)port password:(NSString *)passoword method:(NSString *)method {
    _host = [host copy];
    _port = port;
    _passoword = [passoword copy];
    config_encryption([passoword cStringUsingEncoding:NSASCIIStringEncoding],
                      [method cStringUsingEncoding:NSASCIIStringEncoding]);
    _method = [method copy];
}

- (void)setSocksServerPassword:(NSString *)password method:(NSString *)method {
    password = [password copy];
    config_encryption([password cStringUsingEncoding:NSASCIIStringEncoding],[method cStringUsingEncoding:NSASCIIStringEncoding]);
    _method = [method copy];
}

#pragma mark -- listen local port
- (BOOL)startWithLocalPort:(NSInteger)localPort {
    if (_serverSocket) {
        [self stop];
        return [self _doStartWithLocalPort:localPort];
    } else {
        [self stop];
        return [self _doStartWithLocalPort:localPort];
    }
}

- (BOOL)_doStartWithLocalPort:(NSInteger)localPort {
    _socketQueue = dispatch_queue_create("me.tuoxie.shadowsocks", NULL);
    _serverSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
    NSError *error;
    [_serverSocket acceptOnPort:localPort error:&error];
    if (error) {
#ifdef DEBUG
        NSLog(@"bind failed, %@", error);
#endif
        [self.evDelegate evSocket:_serverSocket bindError:error];
        return NO;
    }
    _pipelines = [[NSMutableArray alloc] init];
    return YES;
}

#pragma mark - 设置 USERNAME/PASSWORD
- (void)setProxyServerUsr:(NSString *)username psd:(NSString *)password {
    self.username = username;
    self.password = password;
}

#pragma mark -isConnected/stop
- (BOOL)isConnected {
    return _serverSocket.isConnected;
}

- (void)stop {
    [_serverSocket disconnect];
    NSArray *ps = [NSArray arrayWithArray:_pipelines];
    [ps enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        EVPipeline *pipeline = obj;
        [pipeline.localSocket disconnect];
        [pipeline.remoteSocket disconnect];
    }];
    _serverSocket = nil;
}

#pragma mark - GCDAsyncSocketDelegate

- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
#ifdef DEBUG
    NSLog(@"didAcceptNewSocket");
#endif
    EVPipeline *pipeline = [[EVPipeline alloc] init];
    pipeline.localSocket = newSocket;
    [_pipelines addObject:pipeline];
    
    [pipeline.localSocket readDataWithTimeout:-1 tag:0];
}

/**
 *  1. 存储数据
 *  2. 协商
 *  3. 验证登录
 *  4. 转发请求
 */
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    NSLog(@"data:%@", data);
    EVPipeline *pipeline =
    [self pipelineOfLocalSocket:sock] ?: [self pipelineOfRemoteSocket:sock];
    if (!pipeline) {
        return;
    }
    
    if (tag == 0) { // get request data
        [pipeline.localSocket writeData:[NSData dataWithBytes:"\x05\x00" length:2] withTimeout:-1 tag:0];
    }
    else if(tag == 1) {
        /**
         *  MethodNo: 直接向Socks Server请求数据
         *  MethodUSRPSD: 需协商验证后才可请求数据
         */
        if(self.consultMethod == EVSocksClientConsultMethodNO) {
            [self setConsultMethodNoWithPipeline:pipeline];
        }
        else if(self.consultMethod == EVSocksClientConsultMethodUSRPSD) {
            [self setConsultMethodUSRPSDWith:pipeline data:data];
        }
    }
    else if (tag == 2) {         // read data from local, send to remote
        /**
         *  存储本地解析后的目标服务器地址信息，等待Socks Server响应成功后
         *  再次将上面信息发送到Socks Server，获取目标服务器详细信息
         */
        // NSLog(@"pipeline.destinationData:%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        pipeline.destinationData = data;
        [pipeline.remoteSocket writeData:data withTimeout:-1 tag:4];
        
    } else if (tag == 3) { // read data from remote, send to local
        [pipeline.localSocket writeData:data withTimeout:-1 tag:3];
    }
    
    // 协商
    if(tag == SOCKS_Consult) {
        [self socksConsultWithPipeline:pipeline data:data];
    }
    else if(tag == SOCKS_AUTH_USERPASS) {  // 验证
        [self socksAuthUserPassWithPipeline:pipeline data:data];
    }
    else if(tag == SOCKS_SERVER_RESPONSE) {   //
        /**
         *  响应目标服务器
         *
         *  验证成功之后， 发送目标地址到Socks Server
         *
         *  等Socks Server响应并返回data(/0x05/0x00...)后， 即可转发
         */
        uint8_t *bytes = (uint8_t*)[data bytes];
        uint8_t version = bytes[0];
        uint8_t flag = bytes[1];
        if(version == 5) {
            if(flag == 0) {
#ifdef DEBUG
                NSLog(@"fake reply Successful, request destination data");
#endif
                [self socksFakeReply:pipeline];
            }
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    EVPipeline *pipeline =
    [self pipelineOfLocalSocket:sock] ?: [self pipelineOfRemoteSocket:sock];
    
    if (tag == 0) {
        [pipeline.localSocket readDataWithTimeout:-1 tag:1];
    }
    else if (tag == 1) {
        
    }
    else if (tag == 2) {
        
    }
    else if (tag == 3) { // write data to local
        [pipeline.remoteSocket readDataWithTimeout:-1 buffer:nil bufferOffset:0 maxLength:4096 tag:3];
        [pipeline.localSocket readDataWithTimeout:-1 buffer:nil bufferOffset:0 maxLength:4096 tag:2];
    }
    else if (tag == 4) { // write data to remote
        [pipeline.remoteSocket readDataWithTimeout:-1 buffer:nil bufferOffset:0 maxLength:4096 tag:3];
        [pipeline.localSocket readDataWithTimeout:-1 buffer:nil bufferOffset:0 maxLength:4096 tag:2];
    }
    else if(tag == SOCKS_SERVER_RESPONSE) {
        [pipeline.remoteSocket readDataWithTimeout:-1 buffer:nil bufferOffset:0 maxLength:4096 tag:SOCKS_SERVER_RESPONSE];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    EVPipeline *pipeline = [self pipelineOfRemoteSocket:sock];
    
    if(self.consultMethod == EVSocksClientConsultMethodNO) {
        [pipeline.remoteSocket writeData:pipeline.addrData withTimeout:-1 tag:2];
        // Fake reply
        [self socksFakeReply:pipeline];
    }
    else if(self.consultMethod == EVSocksClientConsultMethodUSRPSD) {
        [self socksOpenWithSocket:pipeline.remoteSocket];
    }
    else {
        // 其他验证方式
        
    }
}


- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    [self.evDelegate evSocket:sock didDisconnectWithError:err];
    EVPipeline *pipeline;
    pipeline = [self pipelineOfRemoteSocket:sock];
    if (pipeline) { // disconnect remote
        if (pipeline.localSocket.isDisconnected) {
            [_pipelines removeObject:pipeline];
        } else {
            [pipeline.localSocket disconnectAfterReadingAndWriting];
        }
        return;
    }
    
    pipeline = [self pipelineOfLocalSocket:sock];
    if (pipeline) { // disconnect local
        if (pipeline.remoteSocket.isDisconnected) {
            [_pipelines removeObject:pipeline];
        } else {
            [pipeline.remoteSocket disconnectAfterReadingAndWriting];
        }
        return;
    }
}

#pragma mark - 设置Proxy Server协商方式
#pragma mark -- 无需协商
- (void)setConsultMethodNoWithPipeline:(EVPipeline *)pipeline {
    char addr_to_send[ADDR_STR_LEN];
    int addr_len = 0;
    [self transformDataToProxyServer:pipeline addr:addr_to_send addr_len:addr_len];
    GCDAsyncSocket *remoteSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
    pipeline.remoteSocket = remoteSocket;
    [remoteSocket connectToHost:_host onPort:_port error:nil];
    init_encryption(&(pipeline->sendEncryptionContext));
    init_encryption(&(pipeline->recvEncryptionContext));
    encrypt_buf(&(pipeline->sendEncryptionContext), addr_to_send, &addr_len);
    pipeline.addrData = [NSData dataWithBytes:addr_to_send length:addr_len];
}

#pragma mark -- USERNAME/PASSWORD 协商
- (void)setConsultMethodUSRPSDWith:(EVPipeline *)pipeline data:(NSData *)data{
    // store request data
    pipeline.requestData = data;
    if(!pipeline.remoteSocket) {
        NSError *connectErr = nil;
        pipeline.remoteSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_socketQueue];
        [pipeline.remoteSocket connectToHost:_host onPort:self.port error:&connectErr];
    }
}

#pragma mark - 协商
#pragma mark -- 开始协商
/**
 *  Sends the SOCKS5 open/handshake/authentication data, and starts reading the response.
 *  We attempt to gain anonymous access (no authentication).
 *
 *      +-----+-----------+---------+
 * NAME | VER | NMETHODS  | METHODS |
 *      +-----+-----------+---------+
 * SIZE |  1  |    1      | 1 - 255 |
 *      +-----+-----------+---------+
 *
 *  Note: Size is in bytes
 *
 *  Version    = 5 (for SOCKS5)
 *  NumMethods = 1
 *  Method     = 0 (No authentication, anonymous access)
 *  @param rmSocket remote Socket
 */
- (void)socksOpenWithSocket:(GCDAsyncSocket *)rmSocket
{
    NSUInteger byteBufferLength = 3;
    uint8_t *byteBuffer = malloc(byteBufferLength * sizeof(uint8_t));
    
    uint8_t version = 5; /// VER
    byteBuffer[0] = version;
    
    uint8_t numMethods = 1; /// NMETHODS
    byteBuffer[1] = numMethods;
    
    uint8_t method = 0; /// 0 == no auth
    method = 2; // username/password
    byteBuffer[2] = method;
    
    NSData *data = [NSData dataWithBytesNoCopy:byteBuffer length:byteBufferLength freeWhenDone:YES];
    [rmSocket writeData:data withTimeout:-1 tag:SOCKS_Consult];
    
    [self socksReadConsultDataWithSocket:rmSocket];
}

/**
 *  读取与Proxy Server 协商返回的结果
 *
 *          +-----+--------+
 *    NAME  | VER | METHOD |
 *          +-----+--------+
 *    SIZE  |  1  |   1    |
 *          +-----+--------+
 *
 *  Note: Size is in bytes
 *
 *  Version = 5 (for SOCKS5)
 *  Method  = 0 (No authentication, anonymous access)
 *
 *  @param socket remote Socket
 */
- (void)socksReadConsultDataWithSocket:(GCDAsyncSocket *)socket {
    [socket readDataToLength:2 withTimeout:-1 tag:SOCKS_Consult];
}

#pragma mark -- Consult 协商验证结果
- (void)socksConsultWithPipeline:(EVPipeline *)pipeline data:(NSData *)data {
    // See socksOpen method for socks reply format
    uint8_t *bytes = (uint8_t*)[data bytes];
    uint8_t version = bytes[0];
    uint8_t method = bytes[1];
    if(version == 5) {
        if(method == 0) {
            // No Auth
            NSError *err = [self consultNoAuth:@"无需协商"];
            [self.consultDelegate consultSocket:pipeline.remoteSocket didFailWithError:err];
        }
        else if(method == 2) {
            // Username/Password Validate
            [self.consultDelegate consultSocketDidFinishLoad:pipeline.remoteSocket];
            [self socksUserPassAuthWithSocket:pipeline.remoteSocket usr:self.username psd:self.password];
        }
        else {
            // unsupported auth method
            [pipeline.remoteSocket disconnect];
            NSError *err = [self consultNoSupport:@"socks服务器协商方式不支持，请检查支持的协商方式"];
            [self.consultDelegate consultSocket:pipeline.remoteSocket didFailWithError:err];
        }
    }
}

#pragma mark - 登录
#pragma mark -- 封装USERNAME/PASSWORD 为Package
/**
 *  封装username/password为package
 *        +-----+-------------+----------+-------------+------------
 *   NAME | VER | USERNAMELen | USERNAME | PASSWORDLEN |  PASSWORD  |
 *         +-----+------------+----------+-------------+------------
 *   SIZE |  1   |     1      |  1 - 255 |      1      |  1 - 255   |
 *         +-----+------------+----------+-------------+------------
 *
 *  @param rmSocket remote socket
 */
- (void)socksUserPassAuthWithSocket:(GCDAsyncSocket *)rmSocket usr:(NSString *)username psd:(NSString *)password {
    NSData *usernameData = [username dataUsingEncoding:NSUTF8StringEncoding];
    
    NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
    
    uint8_t usernameLength = (uint8_t)username.length;
    uint8_t passwordLength = (uint8_t)password.length;
    
    NSMutableData *authData = [NSMutableData dataWithCapacity:1+1+usernameLength + 1 + passwordLength];
    uint8_t version[1] = {0x01};
    [authData appendBytes:version length:1];
    [authData appendBytes:&usernameLength length:1];
    [authData appendBytes:usernameData.bytes length:usernameLength];
    [authData appendBytes:&passwordLength length:1];
    [authData appendBytes:passwordData.bytes length:passwordLength];
    
    // 与Server 验证用户名和密码    ^^^^^^^这里需要加密
    [rmSocket writeData:authData withTimeout:-1 tag:SOCKS_AUTH_USERPASS];
    [rmSocket readDataToLength:2 withTimeout:-1 tag:SOCKS_AUTH_USERPASS];
}


#pragma mark -- USERNAME/PASSWORD 登录验证结果
/**
 *  Server response for username/password authentication:
 *  field 1: version, 1 byte
 *  filed 2: status code, 1 byte
 *  0x00 = success
 *  any other value = failure, connection must be closed
 */
- (void)socksAuthUserPassWithPipeline:(EVPipeline *)pipeline data:(NSData *)data {
    if(data.length == 2) {
        uint8_t *bytes = (uint8_t *)[data bytes];
        uint8_t status = bytes[1];
        if(status ==0x00) {
            // 验证成功， 开始访问数据
            // set delegate
            [self.validateDelegate validateSocketDidFinishLoad:pipeline.remoteSocket];
            
            char addr_to_send[ADDR_STR_LEN];
            int addr_len = 0;
            
            addr_len = [self transformDataToProxyServer:pipeline addr:addr_to_send addr_len:addr_len];
            
            [pipeline.remoteSocket writeData:pipeline.requestData withTimeout:-1 tag:SOCKS_SERVER_RESPONSE];
            pipeline.addrData = [NSData dataWithBytes:addr_to_send length:addr_len];
        }
        else {
            NSError *err = [self validateSocksServer:[NSString stringWithFormat:@"服务器返回异常:%@", data]];
            [self.validateDelegate validateSocket:pipeline.remoteSocket didFailWithError:err];
            [pipeline.remoteSocket disconnect];
            return;
        }
    }
    else {
        
        NSError *err = [self validateSocksServer:[NSString stringWithFormat:@"服务器返回数据长度异常:%@", data]];
        [self.validateDelegate validateSocket:pipeline.remoteSocket didFailWithError:err];
        // 返回数据超过2个字节长度
        [pipeline.remoteSocket disconnect];
        return;
    }
}

#pragma mark - 请求转发/fade reply
/**
 *  根据destination host & prot 获取的data，转发Proxy Server
 */
- (int)transformDataToProxyServer:(EVPipeline *)pipeline addr:(char [ADDR_STR_LEN])addr_to_send addr_len:(int)addr_len {
    // transform data
    struct socks5_request *request = (struct socks5_request *)pipeline.requestData.bytes;
    if (request->cmd != SOCKS_CMD_CONNECT) {
        struct socks5_response response;
        response.ver = SOCKS_VERSION;
        response.rep = SOCKS_CMD_NOT_SUPPORTED;
        response.rsv = 0;
        response.atyp = SOCKS_IPV4;
        char *send_buf = (char *)&response;
        [pipeline.localSocket writeData:[NSData dataWithBytes:send_buf length:4] withTimeout:-1 tag:1];
        [pipeline disconnect];
        return -1;
    }
    
    addr_to_send[addr_len++] = request->atyp;
    char addr_str[ADDR_STR_LEN];
    // get remote addr and port
    if (request->atyp == SOCKS_IPV4) {
        // IP V4
        size_t in_addr_len = sizeof(struct in_addr);
        memcpy(addr_to_send + addr_len, pipeline.requestData.bytes + 4, in_addr_len + 2);
        addr_len += in_addr_len + 2;
        
        // now get it back and print it
        inet_ntop(AF_INET, pipeline.requestData.bytes + 4, addr_str, ADDR_STR_LEN);
    } else if (request->atyp == SOCKS_DOMAIN) {
        // Domain name
        unsigned char name_len = *(unsigned char *)(pipeline.requestData.bytes + 4);
        addr_to_send[addr_len++] = name_len;
        memcpy(addr_to_send + addr_len, pipeline.requestData.bytes + 4 + 1, name_len);
        memcpy(addr_str, pipeline.requestData.bytes + 4 + 1, name_len);
        addr_str[name_len] = '\0';
        addr_len += name_len;
        
        // get port
        unsigned char v1 = *(unsigned char *)(pipeline.requestData.bytes + 4 + 1 + name_len);
        unsigned char v2 = *(unsigned char *)(pipeline.requestData.bytes + 4 + 1 + name_len + 1);
        addr_to_send[addr_len++] = v1;
        addr_to_send[addr_len++] = v2;
    } else {
        [pipeline disconnect];
        return -1;
    }
    return addr_len;
}

/**
 *  local socket 回调
 *
 *  @param pipeline pipeline
 */
- (void)socksFakeReply:(EVPipeline *)pipeline {
    // Fake reply
    struct socks5_response response;
    response.ver = SOCKS_VERSION;
    response.rep = 0;
    response.rsv = 0;
    response.atyp = SOCKS_IPV4;
    
    struct in_addr sin_addr;
    inet_aton("0.0.0.0", &sin_addr);
    
    int reply_size = 4 + sizeof(struct in_addr) + sizeof(unsigned short);
    char *replayBytes = (char *)malloc(reply_size);
    
    memcpy(replayBytes, &response, 4);
    memcpy(replayBytes + 4, &sin_addr, sizeof(struct in_addr));
    *((unsigned short *)(replayBytes + 4 + sizeof(struct in_addr)))
    = (unsigned short) htons(atoi("22"));
    
    [pipeline.localSocket
     writeData:[NSData dataWithBytes:replayBytes length:reply_size]
     withTimeout:-1
     tag:3];
    free(replayBytes);
}

#pragma mark - EVSocksClientError
- (NSError *)errnoError {
    NSString *errMsg = [NSString stringWithUTF8String:strerror(errno)];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:userInfo];
}

- (NSError *)consultNoAuth:(NSString *)errMsg {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:EVSocksClientErrorDomain code:EVSocksClientErrorNoAuth userInfo:userInfo];
}

- (NSError *)consultNoSupport:(NSString *)errMsg {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:EVSocksClientErrorDomain code:EVSocksClientErrorNOSupported userInfo:userInfo];
}

- (NSError *)validateSocksServer:(NSString *)errMsg {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    return [NSError errorWithDomain:EVSocksClientErrorDomain code:EVSocksClientErrorValidateFailed userInfo:userInfo];
}

#pragma mark -Dealloc
- (void)dealloc {
    _serverSocket = nil;
    _pipelines = nil;
    _host = nil;
}


@end
