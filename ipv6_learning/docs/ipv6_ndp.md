# IPv6邻居发现协议（NDP）

邻居发现协议（Neighbor Discovery Protocol, NDP）是IPv6中的一个基础协议，用于替代IPv4中的ARP、ICMP路由器发现和重定向功能。

## 基本功能

### 1. 地址解析
- 将IPv6地址解析为链路层地址
- 维护邻居缓存表
- 检测地址冲突

### 2. 路由器发现
- 发现本地链路上的路由器
- 获取前缀信息
- 自动配置地址

### 3. 重定向
- 通知主机更优路径
- 优化路由选择

## NDP报文类型

### 1. 路由器请求（Router Solicitation，RS）
```
主机                                            路由器
  |   ICMPv6 Type=133 (Router Solicitation)      |
  |------------------------------------------>   |
  |                                              |
```

### 2. 路由器通告（Router Advertisement，RA）
```
路由器                                          主机
  |   ICMPv6 Type=134 (Router Advertisement)     |
  |   - 前缀信息                                 |
  |   - MTU信息                                  |
  |   - 其他配置标志                             |
  |------------------------------------------>   |
```

### 3. 邻居请求（Neighbor Solicitation，NS）
```
发送方                                          目标
  |   ICMPv6 Type=135 (Neighbor Solicitation)    |
  |------------------------------------------>   |
```

### 4. 邻居通告（Neighbor Advertisement，NA）
```
目标                                            发送方
  |   ICMPv6 Type=136 (Neighbor Advertisement)   |
  |------------------------------------------>   |
```

### 5. 重定向（Redirect）
```
路由器                                          主机
  |   ICMPv6 Type=137 (Redirect)                |
  |------------------------------------------>   |
```

## 邻居发现过程

### 1. DAD（重复地址检测）过程
```
新节点                                         网络
  |   NS (目标=暂定地址)                        |
  |------------------------------------------>  |
  |                                             |
  |   等待NA响应                                |
  |   如果无响应，地址可用                       |
  |   如果有响应，地址冲突                       |
```

### 2. 地址解析过程
```
节点A                                          节点B
  |   NS (包含节点A的链路层地址)                |
  |------------------------------------------>  |
  |                                             |
  |   NA (包含节点B的链路层地址)                |
  |<------------------------------------------  |
```

## 邻居缓存状态

| 状态 | 描述 | 转换触发条件 |
|------|------|-------------|
| INCOMPLETE | 正在解析地址 | 发送NS |
| REACHABLE | 邻居可达 | 收到NA |
| STALE | 可能可达 | 可达性超时 |
| DELAY | 等待确认 | 发送数据包 |
| PROBE | 正在探测 | 发送NS探测 |

## 配置和优化

### 1. 系统参数调整
```bash
# Linux系统NDP参数示例
sysctl -w net.ipv6.neigh.default.gc_thresh1=1024
sysctl -w net.ipv6.neigh.default.gc_thresh2=2048
sysctl -w net.ipv6.neigh.default.gc_thresh3=4096
```

### 2. 静态邻居配置
```bash
# 添加静态邻居条目
ip -6 neigh add 2001:db8::1 lladdr 00:11:22:33:44:55 dev eth0 nud permanent
```

## 安全考虑

### 1. 常见威胁
- 伪造路由器通告
- 伪造邻居通告
- DAD攻击
- 缓存耗尽攻击

### 2. 防护措施
```
# RA Guard配置示例（Cisco设备）
ipv6 nd raguard policy POLICY-NAME
 device-role host
!
interface GigabitEthernet1/0/1
 ipv6 nd raguard attach-policy POLICY-NAME
```

### 3. SEND（SEcure Neighbor Discovery）
- 使用加密签名
- 防止伪造报文
- 提供地址所有权证明

## 故障排查

### 1. 常用命令
```bash
# 查看邻居缓存
ip -6 neigh show

# 清除邻居缓存
ip -6 neigh flush all

# 抓包分析
tcpdump -i any 'icmp6 and (ip6[40] == 135 or ip6[40] == 136)'
```

### 2. 常见问题
- 地址解析失败
- 重复地址检测失败
- 路由器发现问题
- 邻居不可达

## 最佳实践

### 1. 性能优化
- 适当调整缓存大小
- 配置合理的定时器
- 使用静态条目减少解析

### 2. 安全加固
- 启用RA Guard
- 配置SEND（如果可能）
- 限制NDP报文速率
- 监控异常行为

### 3. 运维建议
- 定期清理过期条目
- 监控缓存使用情况
- 记录重要NDP事件
- 配置NDP日志
