# IPv6通信量类别（Traffic Class）

IPv6头部中的通信量类别字段是一个8位字段，用于标识数据包的服务类型和优先级。它包含两个主要部分：差分服务（DS）字段和显式拥塞通知（ECN）字段。

## 字段结构

```
  0   1   2   3   4   5   6   7
+---+---+---+---+---+---+---+---+
|      DSCP       |     ECN     |
+---+---+---+---+---+---+---+---+
```

- DSCP（Differentiated Services Code Point）：前6位
- ECN（Explicit Congestion Notification）：后2位

## DSCP值及其服务类型

### 1. 标准PHB（Per-Hop Behavior）类型

| DSCP值(二进制) | DSCP值(十进制) | 服务类型 | 应用场景 |
|--------------|--------------|---------|---------|
| `000000` | 0 | BE（Best Effort） | 默认服务 |
| `001000` | 8 | CS1（Class Selector 1） | 低优先级数据 |
| `010000` | 16 | CS2（Class Selector 2） | OAM业务 |
| `011000` | 24 | CS3（Class Selector 3） | 信令业务 |
| `100000` | 32 | CS4（Class Selector 4） | 实时业务 |
| `101000` | 40 | CS5（Class Selector 5） | 视频业务 |
| `110000` | 48 | CS6（Class Selector 6） | 网络控制 |
| `111000` | 56 | CS7（Class Selector 7） | 网络控制 |

### 2. 保证转发（AF，Assured Forwarding）类型

| 优先级 | 低丢包率(AF1x) | 中丢包率(AF2x) | 高丢包率(AF3x) | 最高丢包率(AF4x) |
|-------|--------------|--------------|--------------|---------------|
| DSCP值 | `001010`(AF11) | `010010`(AF21) | `011010`(AF31) | `100010`(AF41) |
|       | `001100`(AF12) | `010100`(AF22) | `011100`(AF32) | `100100`(AF42) |
|       | `001110`(AF13) | `010110`(AF23) | `011110`(AF33) | `100110`(AF43) |

### 3. 加速转发（EF，Expedited Forwarding）

- DSCP值：`101110`（46）
- 用途：低延迟、低丢包、低抖动的高优先级服务
- 应用：VoIP、视频会议等实时应用

## ECN（显式拥塞通知）值

| ECN值 | 含义 | 说明 |
|------|------|------|
| `00` | Non-ECT | 不支持ECN |
| `01` | ECT(1) | 支持ECN，发送方设置 |
| `10` | ECT(0) | 支持ECN，发送方设置 |
| `11` | CE | 发生拥塞，由网络设备设置 |

## 应用场景示例

### 1. 企业网络QoS策略
```
视频会议：EF (DSCP 46)
语音通话：EF (DSCP 46)
关键业务：AF41 (DSCP 34)
邮件系统：AF21 (DSCP 18)
普通浏览：BE (DSCP 0)
```

### 2. 运营商网络QoS策略
```
网络控制：CS6 (DSCP 48)
语音业务：EF (DSCP 46)
视频业务：AF41 (DSCP 34)
高优先数据：AF31 (DSCP 26)
普通数据：BE (DSCP 0)
```

## 配置示例

### 1. Linux系统配置
```bash
# 设置出站数据包的DSCP值
tc qdisc add dev eth0 root handle 1: prio bands 4
tc filter add dev eth0 parent 1: protocol ip prio 1 u32 match ip tos 0x68 0xff flowid 1:1
```

### 2. Cisco设备配置
```
policy-map QOS-POLICY
 class VOICE
  set dscp ef
 class VIDEO
  set dscp af41
 class DATA
  set dscp default
```

## QoS策略实施建议

### 1. 分类原则
- 基于应用类型
- 基于业务重要性
- 基于用户级别
- 基于服务等级协议（SLA）

### 2. 标记策略
- 在网络边缘进行标记
- 保持端到端一致性
- 遵循信任边界原则

### 3. 队列分配
- EF流量独立队列
- AF类按优先级分配
- 预留BE流量带宽

## 常见问题和解决方案

### 1. DSCP重写
问题：中间设备重写DSCP值
解决：
- 端到端QoS策略协调
- 使用MPLS VPN保持QoS标记

### 2. QoS策略不一致
问题：不同区域QoS策略不同
解决：
- 建立QoS策略映射关系
- 在边界进行策略转换

### 3. 带宽保证
问题：高优先级流量占用过多带宽
解决：
- 实施流量整形
- 设置带宽限制
- 使用公平队列

## 最佳实践

### 1. 设计建议
✅ **推荐做法**:
- 使用标准PHB值
- 保持策略简单
- 定期监控和调整

❌ **避免做法**:
- 过度细分服务类别
- 随意使用EF类别
- 忽略BE流量需求

### 2. 部署检查清单
- [ ] QoS需求分析
- [ ] 流量分类方案
- [ ] DSCP标记策略
- [ ] 队列配置方案
- [ ] 监控告警机制

## 监控和维护

### 1. 关键指标
- 每类流量的带宽使用率
- 丢包率
- 延迟和抖动
- QoS策略命中率

### 2. 故障排查
```bash
# 查看数据包DSCP标记
tcpdump -i any -vv ip6

# 检查QoS策略
tc -s qdisc show dev eth0

# 查看接口队列状态
ifconfig eth0 -a
```
