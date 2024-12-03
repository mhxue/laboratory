# IPv6 学习代码示例

本目录包含IPv6相关协议的Python实现示例。

## 设备发现程序 (ndp_discovery.py)

这个程序使用NDP协议来发现本地网络中的IPv6设备。它通过发送NS（邻居请求）消息并处理NA（邻居通告）响应来实现设备发现。

### 功能特点

1. 自动发现本地网络中的IPv6设备
2. 支持指定网络前缀进行扫描
3. 获取设备的IPv6地址和MAC地址
4. 多线程处理发送和接收
5. 实时显示发现结果

### 使用方法

需要root权限运行：

```bash
# 基本用法
sudo ./ndp_discovery.py <接口名称>

# 指定网络前缀
sudo ./ndp_discovery.py <接口名称> --prefix 2001:db8::/64

# 自定义超时时间
sudo ./ndp_discovery.py <接口名称> --timeout 10
```

示例：
```bash
sudo ./ndp_discovery.py eth0
```

### 输出示例

```
开始扫描 100 个地址...
发现设备: 2001:db8::1
  MAC地址: 00:11:22:33:44:55
发现设备: 2001:db8::2
  MAC地址: 00:11:22:33:44:66

发现的设备:

IPv6地址: 2001:db8::1
MAC地址: 00:11:22:33:44:55
源地址: fe80::1
标志: 0x60000000

IPv6地址: 2001:db8::2
MAC地址: 00:11:22:33:44:66
源地址: fe80::2
标志: 0x60000000
```

### 程序结构

- `DeviceDiscovery`: 主要的设备发现类
  - `discover()`: 执行设备发现
  - `generate_target_addresses()`: 生成目标地址列表
  - `send_ns()`: 发送NS消息
  - `parse_na()`: 解析NA响应
  - `receiver()`: 接收响应的线程
  - `process_responses()`: 处理响应的线程

### 依赖项

```
netifaces>=0.11.0
ipaddress>=1.0.23
```

安装依赖：
```bash
pip install -r requirements.txt
```

### 注意事项

1. 需要root权限
2. 确保网络接口启用了IPv6
3. 某些网络可能会限制ICMPv6流量
4. 扫描大型网络时要谨慎使用

## NDP演示程序 (ndp_demo.py)

这个程序演示了NDP消息的封装和处理过程，包括：
1. ICMPv6头部的构造
2. NDP消息的封装
3. 校验和的计算
4. NS消息的发送
5. NA消息的接收和解析

### 使用方法

需要root权限运行：

```bash
sudo ./ndp_demo.py <接口名称> <目标IPv6地址>
```

示例：
```bash
sudo ./ndp_demo.py eth0 fe80::1
```

### 程序结构

- `ICMPv6Packet`: ICMPv6基础包类
- `NDPPacket`: NDP消息类，继承自ICMPv6Packet
- `calculate_checksum()`: 计算ICMPv6校验和
- `create_ns_packet()`: 创建邻居请求包
- `send_ns()`: 发送NS并接收NA
- `parse_na()`: 解析邻居通告消息

### 输出示例

```
发送NS消息到 fe80::1
收到来自 fe80::1 的NA响应
NA消息详情:
  类型: 136
  代码: 0
  校验和: 0x1234
  标志: 0x60000000
  目标地址: fe80::1
  选项:
    目标链路层地址: 00:11:22:33:44:55
```

### 注意事项

1. 需要root权限
2. 确保目标IPv6地址可达
3. 接口名称要正确
4. 防火墙可能会影响程序运行
