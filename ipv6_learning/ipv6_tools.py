import ipaddress
import socket
import sys
from dns_parser import DNSParser, create_dns_query

def demonstrate_ipv6_address():
    """演示IPv6地址的基本操作和特性"""
    print("\n=== IPv6地址演示 ===")
    
    # 1. 创建IPv6地址对象
    addr = ipaddress.IPv6Address('2001:db8::1')
    print(f"IPv6地址: {addr}")
    print(f"压缩形式: {addr.compressed}")
    print(f"完整形式: {addr.exploded}")
    
    # 2. 检查地址类型
    print(f"\n地址类型:")
    print(f"是否是链路本地地址: {addr.is_link_local}")
    print(f"是否是站点本地地址: {addr.is_site_local}")
    print(f"是否是全局单播地址: {addr.is_global}")
    print(f"是否是多播地址: {addr.is_multicast}")
    
    # 3. 地址计算
    print(f"\n地址计算:")
    next_addr = addr + 1
    print(f"下一个地址: {next_addr}")

def get_host_ipv6():
    """获取主机的IPv6地址信息"""
    print("\n=== 主机IPv6地址信息 ===")
    
    try:
        # 获取所有网络接口的地址
        hostname = socket.gethostname()
        addrs = socket.getaddrinfo(hostname, None)
        
        # 过滤出IPv6地址
        ipv6_addrs = [addr[4][0] for addr in addrs if addr[0] == socket.AF_INET6]
        
        if ipv6_addrs:
            print("找到以下IPv6地址:")
            for addr in ipv6_addrs:
                ip = ipaddress.IPv6Address(addr)
                print(f"地址: {ip}")
                print(f"- 压缩形式: {ip.compressed}")
                print(f"- 完整形式: {ip.exploded}")
                print(f"- 是否是链路本地: {ip.is_link_local}")
                print(f"- 是否是全局单播: {ip.is_global}")
        else:
            print("未找到IPv6地址")
            
    except Exception as e:
        print(f"获取地址信息时出错: {e}")

def check_tcp_connection(target_ip, port=80):
    """检查TCP连接状态"""
    sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
    sock.settimeout(5)
    
    try:
        print(f"正在连接到 {target_ip}:{port}...")
        sock.connect((target_ip, port))
        
        peer = sock.getpeername()
        print(f"连接成功！对端地址: {peer}")
        
        err = sock.getsockopt(socket.SOL_SOCKET, socket.SO_ERROR)
        if err == 0:
            print("Socket状态正常")
        else:
            print(f"Socket错误: {err}")
            
        return True
        
    except socket.timeout:
        print(f"连接超时")
        return False
    except socket.error as e:
        print(f"连接错误: {e}")
        return False
    finally:
        sock.close()

def check_ipv6_connectivity():
    """检查IPv6连接性"""
    print("\n=== IPv6连接性测试 ===")
    
    # 首先检查TCP连接
    google_dns = "2001:4860:4860::8888"
    print("1. 测试TCP基础连接...")
    if not check_tcp_connection(google_dns, 53):
        print("TCP连接失败，IPv6可能不可用")
        return False
    
    try:
        # 2. 测试DNS查询（UDP数据传输）
        print("\n2. 测试DNS查询（UDP数据传输）...")
        sock = socket.socket(socket.AF_INET6, socket.SOCK_DGRAM)
        sock.settimeout(5)
        
        # 创建DNS查询
        query = create_dns_query("google.com", 28)  # 28是AAAA记录类型
        
        # 发送查询
        print("   发送DNS查询...")
        sock.sendto(query, (google_dns, 53))
        
        # 接收响应
        print("   等待响应...")
        response, addr = sock.recvfrom(512)
        print(f"   收到来自 {addr[0]} 的响应，长度: {len(response)} 字节")
        
        # 使用DNSParser解析响应
        parser = DNSParser(response)
        header, questions, answers = parser.parse_packet()
        
        # 检查响应码
        if header.rcode == 0:
            print("   DNS响应正常")
            print(f"   包含 {len(answers)} 个答案记录")
            
            # 显示每个答案记录
            for i, answer in enumerate(answers, 1):
                print(f"\n   记录 {i}:")
                print("   " + parser.format_resource_record(answer).replace('\n', '\n   '))
            
            print("\n   数据传输测试成功！")
            return True
        else:
            print(f"   DNS响应错误，错误码: {header.rcode}")
            return False
            
    except socket.timeout:
        print("   DNS查询超时")
        return False
    except socket.error as e:
        print(f"   网络错误: {e}")
        return False
    except Exception as e:
        print(f"   解析错误: {e}")
        return False
    finally:
        sock.close()

def main():
    """主函数"""
    demonstrate_ipv6_address()
    get_host_ipv6()
    check_ipv6_connectivity()

if __name__ == '__main__':
    main()
