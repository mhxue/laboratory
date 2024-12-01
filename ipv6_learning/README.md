# IPv6 学习项目

这是一个用于学习和探索IPv6网络协议的项目。通过实践和代码示例来深入理解IPv6的各个方面。

## IPv6学习路线图

### 1. 基础阶段
- [IPv6基础知识](docs/ipv6_basics.md)
  * 地址格式和类型
  * CIDR和子网划分
  * 特殊地址

### 2. 网络层基础
- IPv6报文头部结构
- ICMPv6协议
- 邻居发现协议（NDP）
- 路径MTU发现
- IPv6分片机制

### 3. 地址管理和分配
- 地址规划和设计
- 无状态地址自动配置（SLAAC）
- DHCPv6详解
- 前缀委派
- 地址隐私保护机制

### 4. 路由和转发
- IPv6静态路由
- OSPFv3协议
- BGP4+协议
- IPv6组播路由
- 策略路由

### 5. 转换和过渡技术
- 双栈实现
- 隧道技术（6to4、6in4、ISATAP）
- NAT64/DNS64
- 464XLAT
- MAP-E/MAP-T

### 6. 安全技术
- IPv6安全威胁分析
- IPSec应用
- IPv6 ACL配置
- RA Guard
- DHCPv6 Guard
- 邻居发现协议安全

### 7. 服务质量（QoS）
- IPv6 QoS模型
- 流标签应用
- 差分服务（DiffServ）
- 流量管理和整形

### 8. 高级特性
- 移动IPv6
- IPv6多宿主
- IPv6 VPN
- IPv6 SDN
- IPv6分段路由（SRv6）

### 9. 运维和监控
- IPv6网络监控
- IPv6故障排除
- 性能优化
- 日志分析
- 网络管理工具

## 工具
- IPv6地址处理工具

## 使用说明

1. 克隆仓库：
```bash
git clone [repository-url]
```

2. 安装依赖：
```bash
pip install -r requirements.txt
```

3. 运行示例：
```bash
python ipv6_tools.py      # 基础功能测试
```

## 许可证

本项目采用MIT许可证 - 详见 [LICENSE](LICENSE) 文件
