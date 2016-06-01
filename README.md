# iOS-Socks-SDK

iOS socks SDK <br>
基于socket，实现proxy,限制访问或翻墙，支持 <br>
> NO AUTHENTICATION REQUIRED
<br>
> USERNAME/PASSWORD
<br>
两种协商方式，暂不支持
<br>
> GSSAPI协商

1、协商格式，Client封装的数据包，请求socks Server协商方式
pragma mark -- 开始协商
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
<br>
2、Socks服务器返回的协商方式
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

<br>
3、根据socks server 返回的协商方式，验证socks server，此处采用Username/Password验证，验证需封装的数据包格式如下
pragma mark -- 封装USERNAME/PASSWORD 为Package
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

<br>
4、验证结果，验证socks server后返回的结果， 0x00表示success，否则fail
/**
 *  Server response for username/password authentication:
 *  field 1: version, 1 byte
 *  filed 2: status code, 1 byte
 *  0x00 = success
 *  any other value = failure, connection must be closed
 */
<br>
<img src="https://github.com/Visitor-sos/iOS-Socks-SDK/blob/master/response.png" alt="Drawing" width="600px" height="500px" />
