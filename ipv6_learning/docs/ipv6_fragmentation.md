# IPv6分片机制

IPv6中的分片机制与IPv4有很大不同。在IPv6中，只有源节点才能进行分片，中间路由器不再进行分片操作，这简化了路由器的处理过程并提高了网络效率。

## 基本概念

### 1. 分片的必要性
- 处理大于链路MTU的数据包
- 适应不同网络的MTU限制
- 优化传输效率

### 2. 与IPv4的区别
```
IPv4分片：
[原始IPv4包]  -->  路由器  -->  [分片1][分片2][分片3]

IPv6分片：
[分片1][分片2][分片3]  -->  路由器  -->  [分片1][分片2][分片3]
（只在源节点分片）     （不进行分片）  （保持分片不变）
```

## 分片头部格式

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|  下一个头部   |    保留     |      分片偏移        |Res|M|
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                         标识                                     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

### 字段说明
- **下一个头部**：原始包的下一个头部类型
- **分片偏移**：该分片在原始包中的位置（8字节为单位）
- **M标志**：1表示后面还有分片，0表示最后一个分片
- **标识**：标识同一个原始包的所有分片

## 分片过程

### 1. 分片决策
```python
def should_fragment(packet_size, path_mtu):
    if packet_size > path_mtu:
        return True
    return False
```

### 2. 分片计算
```python
def calculate_fragments(packet_size, mtu):
    fragment_size = (mtu - 40 - 8) & ~7  # 减去IPv6头部和分片头部，8字节对齐
    num_fragments = (packet_size + fragment_size - 1) // fragment_size
    return num_fragments, fragment_size
```

### 3. 分片示例
```
原始数据包（3000字节）：
[IPv6头部(40)][TCP头部(20)][数据(2940)]

分片后（MTU=1500）：
分片1：[IPv6头部(40)][分片头部(8)][TCP头部(20)][数据(1424)]
分片2：[IPv6头部(40)][分片头部(8)][数据(1424)]
分片3：[IPv6头部(40)][分片头部(8)][数据(92)]
```

## 重组过程

### 1. 接收缓冲区
```c
struct frag_queue {
    struct in6_addr src;    // 源地址
    struct in6_addr dst;    // 目的地址
    u32 id;                // 分片标识
    u32 len;              // 总长度
    struct list_head fragments; // 分片链表
    struct timer_list timer;    // 重组定时器
};
```

### 2. 重组算法
```python
def reassemble_packet(fragments):
    # 按偏移排序分片
    fragments.sort(key=lambda x: x.offset)
    
    # 检查分片是否连续
    current_offset = 0
    for frag in fragments:
        if frag.offset != current_offset:
            return None  # 分片不连续
        current_offset += frag.length
    
    # 合并分片
    return merge_fragments(fragments)
```

## 性能优化

### 1. 源端优化
- 使用PMTUD避免分片
- 选择合适的应用层分段大小
- 优化发送缓冲区大小

### 2. 目标端优化
```bash
# 调整重组缓冲区
sysctl -w net.ipv6.ip6frag_high_thresh=4194304
sysctl -w net.ipv6.ip6frag_low_thresh=3145728

# 调整重组超时
sysctl -w net.ipv6.ip6frag_time=60
```

## 安全考虑

### 1. 潜在威胁
- 分片重叠攻击
- 分片耗尽攻击
- 微小分片攻击
- 重组超时攻击

### 2. 防护措施
```bash
# 限制分片包速率
ip6tables -A INPUT -f -m limit --limit 100/s --limit-burst 100 -j ACCEPT
ip6tables -A INPUT -f -j DROP

# 设置最小分片大小
ip6tables -A INPUT -f --fragm-length 200 -j DROP
```

## 故障排查

### 1. 常见问题
- 分片丢失
- 重组超时
- 性能下降
- MTU黑洞

### 2. 诊断工具
```bash
# 查看分片统计
ip -s -6 route show

# 抓包分析分片
tcpdump -i any 'ip6[6:1] = 44'

# 测试分片
ping6 -s 1452 -M do 2001:db8::1
```

## 最佳实践

### 1. 设计建议
✅ **推荐做法**:
- 尽量避免分片
- 使用PMTUD
- 合理设置MTU
- 监控分片统计

❌ **避免做法**:
- 禁用PMTUD
- 使用过小的MTU
- 忽略分片相关告警

### 2. 配置清单
- [ ] MTU配置检查
- [ ] 分片参数优化
- [ ] 安全策略设置
- [ ] 监控告警配置

### 3. 监控指标
- 分片率
- 重组成功率
- 分片丢失率
- 重组超时次数

## 调试和监控

### 1. 系统日志
```bash
# 查看分片相关日志
grep -i "fragment" /var/log/syslog

# 查看IPv6统计
netstat -s6 | grep -i "fragment"
```

### 2. 性能分析
```bash
# 查看网络接口统计
ip -6 -s link show

# 分析网络流量
iptraf-ng
```

### 3. 告警设置
- 分片率超阈值
- 重组失败率高
- 分片缓冲区接近上限
- 频繁的分片超时
