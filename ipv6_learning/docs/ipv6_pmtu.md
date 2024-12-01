# IPv6路径MTU发现（PMTUD）

路径MTU发现（Path MTU Discovery, PMTUD）是IPv6中的一个重要机制，用于确定到目的地的路径上的最小MTU，以避免分片和提高传输效率。

## 基本概念

### 1. MTU（最大传输单元）
- 链路层可以传输的最大数据包大小
- IPv6要求最小MTU为1280字节
- 常见MTU值：
  * 以太网：1500字节
  * PPPoE：1492字节
  * IPv6隧道：1480字节

### 2. 路径MTU
- 源到目的地路径上的最小MTU
- 动态发现和更新
- 影响因素：
  * 物理链路MTU
  * 隧道封装
  * 网络设备配置

## PMTUD工作机制

### 1. 基本流程
```
源主机                     路由器                      目标主机
  |                          |                           |
  |  发送大数据包            |                           |
  |------------------------->|                           |
  |                          | MTU太小                   |
  |   ICMPv6"包太大"消息     |                           |
  |<-------------------------|                           |
  |                          |                           |
  |  使用更小MTU重试          |                           |
  |------------------------->|-------------------------->|
```

### 2. 详细过程
1. 源主机初始使用链路MTU发送数据包
2. 如果路径中某个链路MTU更小：
   - 路由器丢弃数据包
   - 发送ICMPv6"包太大"消息
   - 包含链路MTU信息
3. 源主机更新路径MTU缓存
4. 使用新MTU重新发送数据包

## PMTUD实现

### 1. 数据结构
```c
struct pmtu_entry {
    struct in6_addr dst;     // 目标地址
    u32 pmtu;               // 路径MTU值
    u32 expires;            // 过期时间
    u32 probes;            // 探测计数
};
```

### 2. 关键算法
```python
def handle_packet(packet, mtu):
    if packet.size > mtu:
        if packet.dontfrag:
            send_icmp_too_big(packet.source, mtu)
            drop_packet(packet)
        else:
            fragments = fragment_packet(packet, mtu)
            forward_fragments(fragments)
    else:
        forward_packet(packet)
```

## MTU老化机制

### 1. 时间间隔
- 初始发现：立即更新
- 定期探测：10分钟
- 老化超时：20分钟

### 2. MTU增长探测
```
   当前PMTU
      |
      | 探测更大MTU
      v
  是否成功？
   /     \
是        否
 |         |
增大MTU    保持当前值
```

## 配置和优化

### 1. 系统参数
```bash
# Linux系统PMTU相关参数
sysctl -w net.ipv6.ip6frag_time=60
sysctl -w net.ipv6.mtu_expires=600
```

### 2. 静态配置
```bash
# 设置接口MTU
ip link set dev eth0 mtu 1500

# 添加静态PMTU条目
ip route add 2001:db8::/64 mtu 1400 dev eth0
```

## 故障排查

### 1. 常见问题
- 黑洞路由
- ICMP过滤
- MTU不一致
- 性能下降

### 2. 诊断工具
```bash
# 跟踪路径MTU
tracepath6 2001:db8::1

# 测试特定大小包
ping6 -s 1452 2001:db8::1

# 查看PMTU缓存
ip -6 route show cache
```

### 3. 抓包分析
```bash
# 捕获ICMPv6包太大消息
tcpdump -i any 'icmp6 and ip6[40] == 2'
```

## 最佳实践

### 1. 设计建议
✅ **推荐做法**:
- 使用标准MTU值
- 允许ICMPv6消息
- 启用PMTUD机制
- 定期监控MTU问题

❌ **避免做法**:
- 禁用PMTUD
- 过滤ICMPv6消息
- 使用非标准MTU值

### 2. 性能优化
- 选择合适的MTU值
- 避免不必要的分片
- 优化缓存参数
- 监控MTU变化

### 3. 安全考虑
- 限制ICMPv6速率
- 验证ICMPv6消息
- 防止PMTUD攻击
- 监控异常行为

## 监控和维护

### 1. 监控指标
- PMTU变化次数
- ICMPv6包太大消息数量
- 分片包数量
- MTU黑洞事件

### 2. 告警设置
- MTU频繁变化
- 持续分片
- PMTUD失败
- 性能异常

### 3. 日志分析
```bash
# 分析系统日志
grep -i "pmtu" /var/log/syslog

# 检查网络接口状态
ip -6 link show

# 查看路由表
ip -6 route show
```
