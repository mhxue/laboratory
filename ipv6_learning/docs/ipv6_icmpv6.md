# ICMPv6协议

ICMPv6（Internet Control Message Protocol version 6）是IPv6网络中的关键协议，用于执行错误报告、诊断功能和邻居发现等任务。

> 关于ICMPv6与NDP(邻居发现协议)的关系，请参考：[NDP与ICMPv6的关系](ndp_icmpv6_relationship.md)

## 报文格式

```
     0         1         2         3         4
     0123 4567 0123 4567 0123 4567 0123 4567
    +----+----+----+----+----+----+----+----+
    |   Type   |   Code   |    Checksum     |
    +----+----+----+----+----+----+----+----+
    |                                        |
    /         Message Body (Variable)        /
    |                                        |
    +----+----+----+----+----+----+----+----+
```

## ICMPv6报文类型

### 1. 错误报文（0-127）

| 类型 | 名称 | 用途 |
|------|------|------|
| 1 | 目标不可达 | 无法将数据包传递到目标 |
| 2 | 包太大 | MTU太小，需要分片 |
| 3 | 超时 | 跳数限制为零 |
| 4 | 参数问题 | IPv6头部或扩展头部有错误 |

### 2. 信息报文（128-255）

| 类型 | 名称 | 用途 |
|------|------|------|
| 128 | 回显请求 | ping请求 |
| 129 | 回显应答 | ping响应 |
| 130 | 组成员查询 | 多播组管理 |
| 133 | 路由器请求 | 请求路由器通告 |
| 134 | 路由器通告 | 通告路由器信息 |
| 135 | 邻居请求 | 地址解析 |
| 136 | 邻居通告 | 响应邻居请求 |

## ICMPv6报文示例

### 1. Echo Request (Ping请求)
```
     0         1         2         3         4
     0123 4567 0123 4567 0123 4567 0123 4567
    +----+----+----+----+----+----+----+----+
    |Type=0x80 |Code=0x00 |    Checksum     |
    +----+----+----+----+----+----+----+----+
    |          Identifier |    Sequence      |
    +----+----+----+----+----+----+----+----+
    |                                        |
    /            Optional Data               /
    |                                        |
    +----+----+----+----+----+----+----+----+
```
- Type: 0x80 (128) - Echo Request
- Code: 0 - 固定值
- Identifier: 用于匹配请求和响应
- Sequence: 序列号，每发送一个请求加1

### 2. Neighbor Solicitation (邻居请求)
> 详细信息请参考：[邻居请求(Neighbor Solicitation)详解](neighbor_solicitation.md)

```
     0         1         2         3         4
     0123 4567 0123 4567 0123 4567 0123 4567
    +----+----+----+----+----+----+----+----+
    |Type=0x87 |Code=0x00 |    Checksum     |
    +----+----+----+----+----+----+----+----+
    |                Reserved               |
    +----+----+----+----+----+----+----+----+
    |                                        |
    +                                        +
    |                                        |
    +          Target Address               +
    |                                        |
    +                                        +
    |                                        |
    +----+----+----+----+----+----+----+----+
    |   Options (Source Link-Layer Address)  |
    +----+----+----+----+----+----+----+----+
```
- Type: 0x87 (135) - Neighbor Solicitation
- Code: 0 - 固定值
- Target Address: 目标IPv6地址
- Options: 通常包含源MAC地址

### 3. Router Advertisement (路由器通告)
```
     0         1         2         3         4
     0123 4567 0123 4567 0123 4567 0123 4567
    +----+----+----+----+----+----+----+----+
    |Type=0x86 |Code=0x00 |    Checksum     |
    +----+----+----+----+----+----+----+----+
    | Cur Hop Limit |M|O|  Reserved  |Router |
    |               | | |            |Lifetime|
    +----+----+----+----+----+----+----+----+
    |                                        |
    +         Reachable Time                +
    |                                        |
    +----+----+----+----+----+----+----+----+
    |                                        |
    +         Retrans Timer                 +
    |                                        |
    +----+----+----+----+----+----+----+----+
    |   Options (Prefix, MTU, etc.)         |
    +----+----+----+----+----+----+----+----+
```
- Type: 0x86 (134) - Router Advertisement
- M: Managed地址配置标志
- O: Other配置标志
- Router Lifetime: 路由器生命周期
- Reachable Time: 邻居可达时间
- Retrans Timer: 重传计时器

这些是最常见的ICMPv6报文类型。每种类型都有其特定的用途：
- Echo Request/Reply: 用于测试网络连通性
- Neighbor Solicitation/Advertisement: 用于地址解析和重复地址检测
- Router Advertisement: 用于路由器向网络通告其存在和网络参数

## 常见ICMPv6报文示例

### 1. Echo Request/Reply（Ping）
```
发送方                                           接收方
  |                                               |
  |  ICMPv6 Type=128 (Echo Request)              |
  |---------------------------------------------->|
  |                                               |
  |  ICMPv6 Type=129 (Echo Reply)                |
  |<----------------------------------------------|
```

### 2. 目标不可达
```
发送方                    路由器                  目标
  |                         |                      |
  |  数据包                 |                      |
  |------------------------>|                      |
  |                         | X 目标不可达         |
  |  Type=1 (Unreachable)   |                      |
  |<------------------------|                      |
```

## ICMPv6安全考虑

### 1. 常见攻击类型
- ICMPv6泛洪攻击
- 伪造路由器通告
- 伪造邻居通告
- ping of death

### 2. 防护措施
```
# 基本ICMPv6过滤规则示例（ip6tables）
ip6tables -A INPUT -p icmpv6 --icmpv6-type echo-request -j DROP
ip6tables -A INPUT -p icmpv6 --icmpv6-type router-advertisement -j DROP
```

### 3. 安全最佳实践
- 限制ICMPv6速率
- 过滤不必要的ICMPv6类型
- 启用ICMPv6检查
- 监控异常ICMPv6流量

## 调试和故障排查

### 1. 常用命令
```bash
# 测试连通性
ping6 2001:db8::1

# 跟踪路由
traceroute6 2001:db8::1

# 抓包分析
tcpdump -i any icmp6

# 查看ICMPv6统计
netstat -s6 | grep -i icmp
```

### 2. 常见问题诊断
- 连通性问题
- MTU问题
- 邻居发现问题
- 路由通告问题

## ICMPv6与IPv4 ICMP的主要区别

1. **功能整合**
   - ICMPv6集成了ARP的功能
   - 包含了组管理功能（IGMPv4的功能）

2. **安全性改进**
   - 支持IPSec
   - 更好的认证机制

3. **扩展性**
   - 更灵活的扩展机制
   - 更多的报文类型
