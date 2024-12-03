#!/usr/bin/env python3
import struct
import ipaddress
from dataclasses import dataclass
from typing import List, Optional, Tuple

@dataclass
class DNSHeader:
    """DNS报文头部结构"""
    id: int
    is_response: bool
    opcode: int
    authoritative: bool
    truncated: bool
    recursion_desired: bool
    recursion_available: bool
    rcode: int
    qdcount: int
    ancount: int
    nscount: int
    arcount: int

@dataclass
class DNSQuestion:
    """DNS问题部分结构"""
    name: str
    type_: int
    class_: int

@dataclass
class DNSResourceRecord:
    """DNS资源记录结构"""
    name: str
    type_: int
    class_: int
    ttl: int
    data: bytes

class DNSParser:
    """DNS报文解析器"""
    
    # DNS记录类型定义
    RECORD_TYPES = {
        1: "A",
        2: "NS",
        5: "CNAME",
        15: "MX",
        16: "TXT",
        28: "AAAA"
    }
    
    def __init__(self, data: bytes):
        self.data = data
        self.offset = 0
    
    def parse_header(self) -> DNSHeader:
        """解析DNS头部（12字节）"""
        if len(self.data) < 12:
            raise ValueError("DNS报文头部不完整")
        
        # 解析各个字段
        id_ = struct.unpack('!H', self.data[0:2])[0]
        flags = struct.unpack('!H', self.data[2:4])[0]
        
        # 解析标志位
        is_response = bool(flags & 0x8000)
        opcode = (flags >> 11) & 0xF
        authoritative = bool(flags & 0x0400)
        truncated = bool(flags & 0x0200)
        recursion_desired = bool(flags & 0x0100)
        recursion_available = bool(flags & 0x0080)
        rcode = flags & 0xF
        
        # 解析计数器
        qdcount = struct.unpack('!H', self.data[4:6])[0]
        ancount = struct.unpack('!H', self.data[6:8])[0]
        nscount = struct.unpack('!H', self.data[8:10])[0]
        arcount = struct.unpack('!H', self.data[10:12])[0]
        
        self.offset = 12
        
        return DNSHeader(
            id=id_,
            is_response=is_response,
            opcode=opcode,
            authoritative=authoritative,
            truncated=truncated,
            recursion_desired=recursion_desired,
            recursion_available=recursion_available,
            rcode=rcode,
            qdcount=qdcount,
            ancount=ancount,
            nscount=nscount,
            arcount=arcount
        )
    
    def parse_name(self) -> str:
        """解析DNS名称（支持压缩指针）"""
        name_parts = []
        
        while True:
            if self.offset >= len(self.data):
                raise ValueError("DNS名称解析超出数据范围")
                
            length = self.data[self.offset]
            
            # 检查是否是压缩指针
            if (length & 0xC0) == 0xC0:
                if self.offset + 2 > len(self.data):
                    raise ValueError("压缩指针超出数据范围")
                
                pointer = ((length & 0x3F) << 8) + self.data[self.offset + 1]
                current_offset = self.offset
                self.offset = pointer
                name_parts.append(self.parse_name())
                self.offset = current_offset + 2
                break
                
            # 检查是否是结束符
            elif length == 0:
                self.offset += 1
                break
                
            # 常规标签处理
            else:
                self.offset += 1
                if self.offset + length > len(self.data):
                    raise ValueError("名称标签超出数据范围")
                name_parts.append(
                    self.data[self.offset:self.offset + length].decode('utf-8')
                )
                self.offset += length
        
        return '.'.join(filter(None, name_parts))
    
    def parse_question(self) -> DNSQuestion:
        """解析DNS问题部分"""
        name = self.parse_name()
        
        if self.offset + 4 > len(self.data):
            raise ValueError("问题记录不完整")
        
        type_ = struct.unpack('!H', self.data[self.offset:self.offset + 2])[0]
        self.offset += 2
        
        class_ = struct.unpack('!H', self.data[self.offset:self.offset + 2])[0]
        self.offset += 2
        
        return DNSQuestion(name=name, type_=type_, class_=class_)
    
    def parse_resource_record(self) -> DNSResourceRecord:
        """解析资源记录"""
        name = self.parse_name()
        
        if self.offset + 10 > len(self.data):
            raise ValueError("资源记录不完整")
        
        type_ = struct.unpack('!H', self.data[self.offset:self.offset + 2])[0]
        self.offset += 2
        
        class_ = struct.unpack('!H', self.data[self.offset:self.offset + 2])[0]
        self.offset += 2
        
        ttl = struct.unpack('!I', self.data[self.offset:self.offset + 4])[0]
        self.offset += 4
        
        rdlength = struct.unpack('!H', self.data[self.offset:self.offset + 2])[0]
        self.offset += 2
        
        if self.offset + rdlength > len(self.data):
            raise ValueError("资源记录数据不完整")
        
        data = self.data[self.offset:self.offset + rdlength]
        self.offset += rdlength
        
        return DNSResourceRecord(
            name=name,
            type_=type_,
            class_=class_,
            ttl=ttl,
            data=data
        )
    
    def format_resource_record(self, record: DNSResourceRecord) -> str:
        """格式化资源记录为可读字符串"""
        type_name = self.RECORD_TYPES.get(record.type_, f"TYPE{record.type_}")
        result = f"名称: {record.name}\n"
        result += f"类型: {type_name}\n"
        result += f"TTL: {record.ttl}秒\n"
        
        # 根据记录类型解析数据
        if record.type_ == 1:  # A记录
            ip = ipaddress.IPv4Address(record.data)
            result += f"IPv4地址: {ip}"
        elif record.type_ == 28:  # AAAA记录
            ip = ipaddress.IPv6Address(record.data)
            result += f"IPv6地址: {ip}"
        else:
            result += f"数据长度: {len(record.data)}字节"
        
        return result
    
    def parse_packet(self) -> Tuple[DNSHeader, List[DNSQuestion], List[DNSResourceRecord]]:
        """解析完整的DNS报文"""
        header = self.parse_header()
        
        questions = []
        for _ in range(header.qdcount):
            questions.append(self.parse_question())
        
        answers = []
        for _ in range(header.ancount):
            answers.append(self.parse_resource_record())
        
        return header, questions, answers

def create_dns_query(domain: str, record_type: int) -> bytes:
    """创建DNS查询报文"""
    # 构建DNS头部
    transaction_id = 0x1234  # 可以是随机值
    flags = 0x0100          # 标准查询
    qdcount = 1            # 一个问题
    ancount = 0            # 没有答案
    nscount = 0            # 没有授权记录
    arcount = 0            # 没有附加记录
    
    header = struct.pack('!HHHHHH',
        transaction_id,
        flags,
        qdcount,
        ancount,
        nscount,
        arcount
    )
    
    # 编码域名
    question = b''
    for part in domain.split('.'):
        length = len(part)
        question += bytes([length])
        question += part.encode()
    question += b'\x00'  # 结束符
    
    # 添加查询类型和类别
    question += struct.pack('!HH',
        record_type,  # 查询类型
        1            # IN类别
    )
    
    return header + question
