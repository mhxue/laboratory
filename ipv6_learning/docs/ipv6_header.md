# IPv6报文头部结构

## IPv6头部字段布局

```
+-------+---------------+--------------------------------+ ─┐
| 版本  |  通信量类别   |            流标签              |  │
| 4位   |     8位      |            20位               |  │
+-------+---------------+--------------------------------+  │
|         有效载荷长度        |  下一个头部  |  跳数限制   |  ├─ 40字节
|            16位            |     8位     |    8位     |  │  固定长度
+-----------------------------+-------------+-------------+  │
|                                                        |  │
|                        源地址 (128位)                   |  │
|                                                        |  │
+--------------------------------------------------------+  │
|                                                        |  │
|                      目的地址 (128位)                   |  │
|                                                        |  │
+--------------------------------------------------------+ ─┘
```

## 字段说明

| 字段名称 | 位数 | 说明 | 取值示例 |
|---------|------|------|---------|
| 版本 | 4位 | 协议版本号 | `0110` (6) |
| 通信量类别 | 8位 | 服务质量控制 | `00001010` (优先转发) |
| 流标签 | 20位 | 数据流标识 | `00000000001111111111` |
| 有效载荷长度 | 16位 | 净荷长度 | `0000000100000000` (256字节) |
| 下一个头部 | 8位 | 扩展头部/协议 | `06` (TCP), `11` (UDP) |
| 跳数限制 | 8位 | 生存周期 | `64`, `128` |
| 源地址 | 128位 | 发送方地址 | `2001:db8::1` |
| 目的地址 | 128位 | 接收方地址 | `2001:db8::2` |

## 特点说明

📌 **固定长度**
- 40字节固定长度，无可选字段
- 简化了路由器处理过程

🔄 **字段排列**
- 按32位（4字节）对齐
- 便于硬件快速处理

🎯 **设计改进**
- 移除校验和字段
- 分片功能移至扩展头部
- 提供流标签支持QoS

## 通信量类别详解

IPv6的通信量类别（Traffic Class）字段用于区分不同类型的数据包，支持服务质量（QoS）管理：
- DSCP（前6位）：定义数据包的转发行为
- ECN（后2位）：提供拥塞通知机制

详细的服务类型和配置方法请参考[IPv6通信量类别文档](ipv6_traffic_class.md)。

## 流标签详解

IPv6引入了流标签字段来支持特殊处理需求。流标签可以用于：
- 实时应用（如视频流、VoIP）的QoS保证
- 负载均衡和流量工程
- 快速转发决策

详细信息请参考[IPv6流标签文档](ipv6_flow_label.md)。

## 扩展头部

IPv6通过扩展头部提供额外功能。关于扩展头部的详细信息，请参考[IPv6扩展头部文档](ipv6_extension_headers.md)。

扩展头部的基本类型包括：

1. **逐跳选项头部**
2. **目的地选项头部**
3. **路由头部**
4. **分片头部**
5. **认证头部**
6. **封装安全载荷头部**

## 扩展头部链（按顺序）

1️⃣ IPv6基本头部
↓
2️⃣ 逐跳选项头部
↓
3️⃣ 目的地选项头部
↓
4️⃣ 路由头部
↓
5️⃣ 分片头部
↓
6️⃣ 认证头部
↓
7️⃣ 封装安全载荷头部
↓
8️⃣ 目的地选项头部
↓
9️⃣ 上层协议 (TCP/UDP/ICMPv6)

## IPv6头部的优势

1. **简化的头部结构**
   - 固定长度，便于硬件处理
   - 去除了校验和字段，提高处理效率

2. **更好的扩展性**
   - 通过扩展头部灵活添加新功能
   - 支持未来协议的演进

3. **改进的QoS支持**
   - 流标签支持
   - 更好的流量分类能力

4. **更高的安全性**
   - 内置IPSec支持
   - 更完善的认证和加密机制

## 注意事项

1. IPv6头部不支持分片，分片功能由扩展头部实现
2. 路由器只处理基本头部，提高转发效率
3. 扩展头部的顺序需要遵循规范
4. 部分扩展头部只能出现一次
