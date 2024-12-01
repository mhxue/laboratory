#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
from dotenv import load_dotenv
from volcengine.service.tts.v1.tts_service import TTSService

class VolcanoTTS:
    def __init__(self):
        load_dotenv()
        self.access_key = os.getenv('VOLCANO_ACCESS_KEY')
        self.secret_key = os.getenv('VOLCANO_SECRET_KEY')
        
        if not all([self.access_key, self.secret_key]):
            raise ValueError("请在.env文件中设置火山引擎访问凭证")
        
        self.service = TTSService()
        self.service.set_ak(self.access_key)
        self.service.set_sk(self.secret_key)

    def list_voices(self):
        """列出可用的语音列表"""
        voices = [
            {"name": "zh_female_sound_1", "description": "成熟女声"},
            {"name": "zh_male_sound_1", "description": "成熟男声"},
            {"name": "zh_female_sound_2", "description": "温柔女声"},
            {"name": "zh_male_sound_2", "description": "磁性男声"},
            {"name": "zh_female_sound_3", "description": "活力女声"}, # 类似西瓜视频常用音色
        ]
        
        print("可用的语音列表：")
        for voice in voices:
            print(f"名称: {voice['name']}")
            print(f"描述: {voice['description']}\n")

    def synthesize_speech(self, text, output_file, voice="zh_female_sound_3"):
        """将文本转换为语音"""
        try:
            # 配置TTS参数
            params = {
                "text": text,
                "voice": voice,
                "format": "mp3",
                "sample_rate": 16000,
                "volume": 100,
                "speed": 1.0,
                "pitch": 1.0
            }

            # 调用TTS服务
            resp = self.service.convert_text_to_speech(params)
            
            if resp.get("StatusCode") == 200:
                # 保存音频文件
                audio_data = resp.get("Data", {}).get("Audio")
                if audio_data:
                    with open(output_file, "wb") as f:
                        f.write(audio_data)
                    print(f'音频内容已写入文件: {output_file}')
                    return True
                else:
                    print("未获取到音频数据")
                    return False
            else:
                print(f"合成失败，状态码: {resp.get('StatusCode')}")
                return False

        except Exception as e:
            print(f"合成过程中出现错误: {e}")
            return False

def main():
    """主函数"""
    # 创建TTS客户端
    tts = VolcanoTTS()
    
    # 列出可用语音
    tts.list_voices()
    
    # 测试文本转语音
    text = "你好，这是一个火山引擎文本转语音的演示，使用类似西瓜视频的音色。"
    output_file = "output_volcano.mp3"
    
    try:
        if tts.synthesize_speech(text, output_file):
            print("转换完成！")
        else:
            print("转换失败！")
    except Exception as e:
        print(f"转换过程中出现错误: {e}")

if __name__ == "__main__":
    main()
