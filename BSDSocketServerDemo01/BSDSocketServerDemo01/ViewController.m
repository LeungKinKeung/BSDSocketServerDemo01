//
//  ViewController.m
//  BSDSocketServerDemo01
//
//  Created by KinKeung Leung on 2016/11/19.
//  Copyright © 2016年 KinKeung Leung. All rights reserved.
//

#import "ViewController.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self performSelectorInBackground:@selector(startService)
                           withObject:nil];
}

// 开始服务
- (void)startService
{
    // 服务端口(由此程序决定，建议范围在1024到49151)
    NSInteger serivePort    = 12345;
    
    int status;
    
    // 1.创建Socket描述符
    int socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0);
    if (socketFileDescriptor == -1)
    {
        NSLog(@"1.创建Socket描述符失败");
        return;
    }
    
    // 2.创建本机套接字地址实例
    struct sockaddr_in localAddressInstance;
    memset(&localAddressInstance, 0, sizeof(localAddressInstance));
    localAddressInstance.sin_len            = sizeof(localAddressInstance);
    localAddressInstance.sin_family         = AF_INET;
    localAddressInstance.sin_addr.s_addr    = INADDR_ANY;
    
    // 重点:服务器程序必须要指定端口，否则客户端程序由于不知道确定的服务端口而无法连接
    localAddressInstance.sin_port           = htons(serivePort);
    
    
    // 3.绑定，将Socket实例与本机地址以及一个本地端口号绑定
    status = bind(socketFileDescriptor,
                  (const struct sockaddr *)&localAddressInstance,
                  sizeof(localAddressInstance));
    
    // 绑定失败,通常是此端口被其他程序占用了；或者是此程序重启时没有正确关闭Socket导致端口没有被系统回收导致无法使用此端口，如果是第二种情况稍后再重启此程序即可
    if (status != 0)
    {
        NSLog(@"3.绑定到本机地址和端口失败");
        return;
    }
    
    /*
        4.监听申请的连接(这里只监听客户端申请的连接，还没接受)
        int listen( int socketFileDescriptor, int backlog);
        socketFileDescriptor：已捆绑未连接套接口的描述符,
        backlog：等待连接队列的最大长度(个数)。
     */
    status = listen(socketFileDescriptor, 2);
    
    // 成功返回 0，失败返回 -1。
    if (status != 0)
    {
        NSLog(@"4.监听客户端申请的连接失败");
        return;
    }
    
    while (YES)
    {
        // 创建客户端Socket实例
        struct sockaddr_in clientAddressInstance;
        int clientSocketFileDescriptor;
        
        socklen_t clientAddressStructLength = sizeof(clientAddressInstance);
        
        /*
            5.接受客户端连接请求并将客户端的网络地址信息保存到 clientAddressInstance 中。当客户端连接请求被服务器接受之后，客户端和服务器之间的链路就建立好了，两者就可以通信了。
            int accept(int socketFileDescriptor, sockaddr *clientAddressInstance, int clientAddressStructLength)
         */
        clientSocketFileDescriptor = accept(socketFileDescriptor,
                                            (struct sockaddr *)&clientAddressInstance,
                                            &clientAddressStructLength);
        
        // 接收失败
        if (clientSocketFileDescriptor == -1)
        {
            NSLog(@"接受连接请求失败");
            close(clientSocketFileDescriptor);
            continue;
        }else
        {
            NSLog(@"接受连接成功,客户端地址:%s,port:%d",
                  inet_ntoa(clientAddressInstance.sin_addr),
                  ntohs(clientAddressInstance.sin_port));
        }
        
        // 自动回复消息
        [self echoMessageWithSocketFileDescriptor:clientSocketFileDescriptor];
    }
    
}

// 让服务器回复消息给客户端(注释参考客户端程序)
- (void)echoMessageWithSocketFileDescriptor:(int)socketFileDescriptor
{
    // 问候一下
    BOOL success = [self sendMessage:@"欢迎连接到服务器"
                            toClient:socketFileDescriptor];
    
    // 如果没有断开，就让其一直循环接收
    BOOL isNoDisconnection  = success;
    
    size_t maximumAcceptableLength   = 32768;
    Byte buffer[maximumAcceptableLength];
    ssize_t receivedLength           = 0;
    
    while (isNoDisconnection)
    {
        memset(&buffer, 0, maximumAcceptableLength);
        receivedLength  = 0;
        
        receivedLength  = recv(socketFileDescriptor,
                               buffer,
                               maximumAcceptableLength,
                               0);
        
        if (receivedLength < 1) {
            if (receivedLength  == -1) NSLog(@"Socket没有连接，或已被本程序断开");
            if (receivedLength  == 0) NSLog(@"Socket已被客户端断开");
            isNoDisconnection   = NO;
            break;
        }
        
        // 这里也暂不考虑数据粘包(多包)和断包(少包)问题
        NSString *message = [[NSString alloc] initWithBytes:buffer
                                                     length:receivedLength
                                                   encoding:NSUTF8StringEncoding];
        NSLog(@"已接收到消息:%@",message);
        
        // 原话回复给客户端
        isNoDisconnection = [self sendMessage:message
                                     toClient:socketFileDescriptor];
    }
    
    // 走到这里代表连接断开了，需要关闭Socket
    close(socketFileDescriptor);
}

// 发送消息(注释参考客户端程序)
- (BOOL)sendMessage:(NSString *)message toClient:(int)socketFileDescriptor
{
    
    NSData *messageData             = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSUInteger bufferLength         = 2048;
    Byte buffer[bufferLength];
    NSUInteger totalMessageLength   = messageData.length;
    NSUInteger offset               = 0;

    while (offset  != totalMessageLength)
    {
        NSUInteger willSendBytesLength  = totalMessageLength - offset;
        
        if (willSendBytesLength > bufferLength)
        {
            willSendBytesLength = bufferLength;
        }
        [messageData getBytes:&buffer
                        range:NSMakeRange(offset, willSendBytesLength)];
        
        NSInteger didSendMsgLen = send(socketFileDescriptor,
                                       buffer,
                                       willSendBytesLength,
                                       0);
        if (didSendMsgLen < 1)
        {
            NSLog(@"发送消息失败");
            break;
        }
        offset += didSendMsgLen;
    }
    if (offset == totalMessageLength)
    {
        NSLog(@"消息回复完成");
        return YES;
    }
    return NO;
}

/**
 
    服务端比客户端多两个个步骤，没有connect()，分别为:
    socket()        创建
    bind()          绑定
    listen()        监听
    accept()        接受连接
    recv()/send()   接收/发送
 
    里面必需要确定的参数是 端口(如:12345)、传输协议(如:TCP/IP)
    listen()/recv()/send() 等接口都是会阻塞线程的，建议放到非UI线程执行
 */





@end
