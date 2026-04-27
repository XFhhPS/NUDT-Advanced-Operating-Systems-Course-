#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#define PORT 8081
#define BUFFER_SIZE 1024

int main() {
    int sock;
    struct sockaddr_in serv_addr;
    char buffer[BUFFER_SIZE] = {0};
    
    // 创建IPv4 TCP套接字 [8,11](@ref)
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        perror("socket创建失败");
        exit(EXIT_FAILURE);
    }
    
    // 配置服务器地址 [6,7](@ref)
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(PORT);
    // 将点分十进制IP转为二进制格式
    if (inet_pton(AF_INET, "10.0.2.2", &serv_addr.sin_addr) <= 0) {
        perror("地址转换失败");
        exit(EXIT_FAILURE);
    }
    
    // 连接到服务器 (触发TCP三次握手) [8,11](@ref)
    if (connect(sock, (struct sockaddr*)&serv_addr, sizeof(serv_addr)) < 0) {
        perror("连接服务器失败");
        exit(EXIT_FAILURE);
    }
    printf("已连接到服务器\n");
    
    // 发送数据 (触发内核ip_queue_xmit()) [3,4](@ref)
    const char* message = "客户端测试数据";
    send(sock, message, strlen(message), 0);
    printf("请求已发送\n");
    
    // 接收服务器响应 [6,7](@ref)
    ssize_t bytes_read = read(sock, buffer, BUFFER_SIZE);
    printf("服务器响应: %s\n", buffer);
    
    close(sock);
    return 0;
}