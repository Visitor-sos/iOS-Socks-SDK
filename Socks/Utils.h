//
//  Utils.h
//  Socks
//
//  Created by Visitor on 16/4/11.
//  Copyright © 2016年 Visitor. All rights reserved.
//



#define EVKey_SocksPassword @"socks_Password"               //!<  Socks Server Password
#define EVKey_Client_TelNumber @"client_TelephoneNumber"    //!<  Client Telephone Number
#define EVKey_Server_Address @"server_Address"          //!< Login Server Address
#define EVKey_TelephoneNumber @"telephoneNumber"   //!<   本机电话号码

#define SOCKS_Consult             10100             //!< Consult Tag
#define SOCKS_AUTH_USERPASS    10500                //!< Username/Password Tag
#define SOCKS_SERVER_RESPONSE 10600    //!< Socks Server 响应目标地址请求
#define ADDR_STR_LEN 512            //!< url length


#define EVServer_ResponseData_Register @"Server_ResponseData_Register"
#define EVServer_ResponseData_VerifyCode @"Server_ResponseData_VerifyCode"
#define EVServer_ResponseData_Login @"Server_ResponseData_Login"


// operate NSUserDefault
#define NSUserDefaultSet(object,key) [[NSUserDefaults standardUserDefaults] setObject:object forKey:key]
#define NSUserDefaultObject(keys) [[NSUserDefaults standardUserDefaults] objectForKey:keys]
#define NSUserDefault_Syn [[NSUserDefaults standardUserDefaults] synchronize]