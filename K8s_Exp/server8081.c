#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

#define PORT 8081
#define BUFFER_SIZE 1024

int main() {
    int server_fd, client_fd;
    struct sockaddr_in address;
    socklen_t addrlen = sizeof(address);
    char buffer[BUFFER_SIZE] = {0};
    
    // 创建IPv4 TCP套接字 [8,11](@ref)
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        perror("socket创建失败");
        exit(EXIT_FAILURE);
    }
    
    // 配置服务器地址结构 [6,11](@ref)
    address.sin_family = AF_INET;          // IPv4协议族
    address.sin_addr.s_addr = INADDR_ANY;  // 监听所有网卡
    address.sin_port = htons(PORT);        // 端口转换为网络字节序
    
    // 绑定套接字到指定地址 [7,8](@ref)
    if (bind(server_fd, (struct sockaddr*)&address, sizeof(address)) < 0) {
        perror("绑定失败");
        exit(EXIT_FAILURE);
    }
    
    // 开始监听，等待队列最大长度=3 [7,11](@ref)
    if (listen(server_fd, 3) < 0) {
        perror("监听失败");
        exit(EXIT_FAILURE);
    }
    printf("服务器监听端口: %d\n", PORT);
    
    // 接受客户端连接 [6,8](@ref)
    if ((client_fd = accept(server_fd, (struct sockaddr*)&address, &addrlen)) < 0) {
        perror("接受连接失败");
        exit(EXIT_FAILURE);
    }
    printf("客户端已连接\n");
    
    // 接收客户端数据 (触发内核ip_rcv()) [1,4](@ref)
    ssize_t bytes_read = read(client_fd, buffer, BUFFER_SIZE);
    printf("收到 %zd 字节: %s\n", bytes_read, buffer);
    
    // 发送响应 (触发内核ip_local_out()) [1,3](@ref)
    const char* response = "服务器响应: 数据已接收";
    send(client_fd, response, strlen(response), 0);
    printf("响应已发送\n");
    
    // 关闭连接
    close(client_fd);
    close(server_fd);
    return 0;
}