# IPv6 学习项目

这是一个用于学习和探索IPv6网络协议的项目。通过实践和代码示例来深入理解IPv6的各个方面。

## IPv6学习路线图

### 1. 基础阶段
- [IPv6地址格式和表示法](docs/ipv6_basics.md#1-ipv6地址格式)
- [基本的地址类型](docs/ipv6_basics.md#2-ipv6地址类型)
  * [单播地址](docs/ipv6_basics.md#21-单播地址unicast)
  * [多播地址](docs/ipv6_basics.md#22-多播地址multicast)
  * [任播地址](docs/ipv6_basics.md#23-任播地址anycast)
- [子网划分基础（CIDR表示法）](docs/ipv6_basics.md#4-子网划分)
- [基本的IPv6配置命令](docs/ipv6_basics.md#7-基本配置命令)
- [IPv6与IPv4的主要区别](docs/ipv6_basics.md#6-ipv6与ipv4的主要区别)

### 2. 网络层基础
- IPv6报文头部结构
- ICMPv6协议详解
- 邻居发现协议（NDP）
- 路径MTU发现
- IPv6分片机制

### 3. 地址管理和分配
- 地址规划和设计
- 无状态地址自动配置（SLAAC）
- DHCPv6详解
- 前缀委派（Prefix Delegation）
- 地址隐私保护机制

### 4. 路由和转发
- IPv6静态路由
- OSPFv3协议
- BGP4+协议
- IPv6组播路由
- 策略路由

### 5. 转换和过渡技术
- 双栈实现
- 隧道技术
  * 6to4
  * 6in4
  * ISATAP
  * Teredo
- NAT64/DNS64
- 464XLAT
- MAP-E/MAP-T

### 6. 安全技术
- IPv6安全威胁分析
- IPSec在IPv6中的应用
- IPv6 ACL配置
- RA Guard
- DHCPv6 Guard
- 邻居发现协议安全

### 7. 服务质量（QoS）
- IPv6 QoS模型
- 流标签的使用
- 差分服务（DiffServ）
- 流量管理和整形
- 带宽管理

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

### 10. 应用层集成
- DNS64配置
- Web服务器IPv6配置
- 邮件服务器IPv6支持
- 应用程序IPv6适配
- 负载均衡

### 11. 企业实践
- IPv6部署规划
- 地址分配策略
- 安全策略制定
- 性能优化策略
- 运维管理流程

### 12. 新技术跟进
- IPv6+技术
- 5G与IPv6
- IoT中的IPv6应用
- 云原生环境中的IPv6
- IPv6创新应用

## 实践部分

本项目包含以下示例代码：
1. IPv6地址处理工具
2. IPv6网络编程示例
3. IPv6连接测试工具

请查看相应的Python文件来了解具体实现。

## 实践指南

### 实验环境搭建
1. 虚拟机环境
2. GNS3/EVE-NG网络模拟器
3. 云平台测试环境

### 必备工具
- Wireshark：网络抓包分析
- ping6/traceroute6：连通性测试
- ip -6命令：接口配置
- tcpdump：数据包捕获
- IPv6专用测试工具

### 认证路线
- CCNA/CCNP IPv6专项
- IPv6 Forum认证
- 厂商特定IPv6认证

### 持续学习资源
- RFC文档阅读
- 技术会议参与
- 社区交流
- 实验室实践

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
python ipv6_advanced.py   # 高级特性演示
```

## 许可证

本项目采用MIT许可证 - 详见 [LICENSE](LICENSE) 文件
