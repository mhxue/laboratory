#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import time
import http.client
import requests
from dotenv import load_dotenv
from aliyunsdkcore.client import AcsClient
from aliyunsdkcore.acs_exception.exceptions import ClientException
from aliyunsdkcore.acs_exception.exceptions import ServerException
from aliyunsdknls_cloud_meta.request.v20180518.CreateTokenRequest import CreateTokenRequest

class AliyunTTS:
    def __init__(self):
        load_dotenv()
        self.access_key_id = os.getenv('ALIYUN_ACCESS_KEY_ID')
        self.access_key_secret = os.getenv('ALIYUN_ACCESS_KEY_SECRET')
        self.app_key = os.getenv('ALIYUN_APP_KEY')
        self.region = "cn-shanghai"
        
        if not all([self.access_key_id, self.access_key_secret, self.app_key]):
            raise ValueError("请在.env文件中设置阿里云访问凭证")
        
        self.client = AcsClient(
            self.access_key_id,
            self.access_key_secret,
            self.region
        )

    def create_token(self):
        """创建访问令牌"""
        request = CreateTokenRequest()
        request.set_accept_format('json')
        try:
            response = self.client.do_action_with_exception(request)
            token = json.loads(response)
            return token.get('Token', {}).get('Id')
        except Exception as e:
            print(f"获取Token失败: {e}")
            return None

    def list_voices(self):
        """列出可用的语音列表"""
        voices = [
            {"name": "xiaoyun", "description": "温柔女声"},
            {"name": "xiaogang", "description": "成熟男声"},
            {"name": "xiaomei", "description": "甜美女声"},
            {"name": "xiaowang", "description": "儿童音色"}
        ]
        
        print("可用的语音列表：")
        for voice in voices:
            print(f"名称: {voice['name']}")
            print(f"描述: {voice['description']}\n")

    def synthesize_speech(self, text, output_file, voice="xiaoyun"):
        """将文本转换为语音"""
        token = self.create_token()
        if not token:
            return False

        url = 'https://nls-gateway.cn-shanghai.aliyuncs.com/stream/v1/tts'
        headers = {
            'Content-Type': 'application/json',
            'X-NLS-Token': token,
        }
        
        data = {
            'appkey': self.app_key,
            'text': text,
            'format': 'mp3',
            'voice': voice,
            'volume': 50,
            'speech_rate': 0,
            'pitch_rate': 0
        }

        try:
            response = requests.post(url, headers=headers, json=data, stream=True)
            if response.status_code == 200:
                with open(output_file, 'wb') as f:
                    for chunk in response.iter_content(chunk_size=1024):
                        if chunk:
                            f.write(chunk)
                print(f'音频内容已写入文件: {output_file}')
                return True
            else:
                print(f"合成失败，状态码: {response.status_code}")
                return False
        except Exception as e:
            print(f"合成过程中出现错误: {e}")
            return False

def main():
    """主函数"""
    # 创建TTS客户端
    tts = AliyunTTS()
    
    # 列出可用语音
    tts.list_voices()
    
    # 测试文本转语音
    text = "你好，这是一个阿里云文本转语音的演示。"
    output_file = "output.mp3"
    
    try:
        if tts.synthesize_speech(text, output_file):
            print("转换完成！")
        else:
            print("转换失败！")
    except Exception as e:
        print(f"转换过程中出现错误: {e}")

if __name__ == "__main__":
    main()
