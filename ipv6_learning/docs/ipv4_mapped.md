# IPv4映射地址详

## 1. 基本定义
IPv4映射地址（IPv4-Mapped IPv6 Address）是一种特殊的IPv6地址，用于表示IPv4节点的IPv6地址。这种地址格式允许IPv6应用程序直接与IPv4节点通信。

## 2. 地址格式
### 2.1 基本格式
- **前缀**：`::ffff:0:0/96`
- **结构**：`::ffff:a.b.c.d`
  * 前80位：全为0
  * 中间16位：全为1（ffff）
  * 后32位：IPv4地址

### 2.2 格式示例
```
IPv4地址：192.168.1.1
对应的IPv4映射地址：::ffff:192.168.1.1
或者用十六进制表示：::ffff:c0a8:0101
```

## 3. 地址结构详解
```
|                    |         |              |
|      80 bits      | 16 bits |    32 bits   |
|-------------------|---------|---------------|
|       0000...     |  FFFF   |  IPv4地址     |
|                   |         |              |
```

### 3.1 各字段说明
1. **前80位**：
   - 全部为0
   - 在地址表示中简写为`::`

2. **中间16位**：
   - 固定值`FFFF`
   - 标识这是一个IPv4映射地址

3. **后32位**：
   - 原始IPv4地址
   - 可以是点分十进制或十六进制格式

## 4. 使用场景
### 4.1 主要用途
1. **双栈环境**：
   - 允许IPv6应用访问IPv4服务
   - 在IPv6套接字API中表示IPv4连接

2. **地址转换**：
   - 用于IPv4/IPv6转换机制
   - 帮助识别和处理IPv4流量

3. **应用程序兼容性**：
   - 使IPv6应用程序能处理IPv4连接
   - 简化双协议栈的实现

### 4.2 常见应用
1. **Web服务器**：
   - 处理来自IPv4客户端的请求
   - 在日志中统一记录IPv6格式地址

2. **数据库系统**：
   - 统一存储IPv4和IPv6地址
   - 简化地址处理逻辑

3. **网络工具**：
   - 在IPv6环境中显示IPv4连接
   - 进行网络监控和故障排除

## 5. 编程考虑
### 5.1 Socket编程
```python
# Python示例
import socket

# 创建IPv6套接字
sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)

# 允许IPv4连接映射到IPv6
sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
```

### 5.2 地址转换
```python
# IPv4地址转换为映射地址
def ipv4_to_mapped(ipv4_addr):
    # 将IPv4地址转换为32位整数
    parts = ipv4_addr.split('.')
    ipv4_int = (int(parts[0]) << 24) + (int(parts[1]) << 16) + \
               (int(parts[2]) << 8) + int(parts[3])
    
    # 构造IPv4映射地址
    # :08x 表示:
    #   - 以十六进制格式(x)显示
    #   - 宽度为8位
    #   - 不足8位用0填充
    return f"::ffff:{ipv4_int:08x}"

# 示例
addr = "192.168.1.1"
mapped = ipv4_to_mapped(addr)
# 输出: ::ffff:c0a80101
print(mapped)
```

## 6. 注意事项
1. **安全考虑**：
   - 注意访问控制策略的一致性
   - 防火墙规则需考虑映射地址

2. **性能影响**：
   - 可能引入额外的处理开销
   - 在高性能要求场景需谨慎使用

3. **兼容性问题**：
   - 不同操作系统实现可能有差异
   - 需要测试目标平台的支持情况

## 7. 最佳实践
1. **地址记录**：
   - 统一使用IPv6格式记录
   - 保持日志格式一致性

2. **应用设计**：
   - 优先使用IPv6原生地址
   - 仅在必要时使用映射地址

3. **监控和调试**：
   - 正确识别映射地址
   - 在故障排除时注意区分

## 8. 相关RFC文档
- RFC 4291：IPv6寻址架构
- RFC 3493：Basic Socket Interface Extensions for IPv6
- RFC 2553：Basic Socket Interface Extensions for IPv6
