#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import time
from pathlib import Path
from typing import List, Dict, Any

import openai
from stability_sdk import client
import stability_sdk.interfaces.gooseai.generation.generation_pb2 as generation
from aip import AipSpeech
from moviepy.editor import *
from PIL import Image
import numpy as np
from dotenv import load_dotenv
from tqdm import tqdm

class AIVideoCreator:
    def __init__(self):
        load_dotenv()
        
        # 初始化各个AI服务
        self._init_openai()
        self._init_stability()
        self._init_tts()
        
        # 创建输出目录
        self.output_dir = Path("output")
        self.output_dir.mkdir(exist_ok=True)
        
    def _init_openai(self):
        """初始化OpenAI"""
        self.openai_client = openai.OpenAI(
            api_key=os.getenv('OPENAI_API_KEY')
        )
        
    def _init_stability(self):
        """初始化Stability AI"""
        self.stability_client = client.StabilityInference(
            key=os.getenv('STABILITY_KEY'),
            verbose=False,
        )
        
    def _init_tts(self):
        """初始化语音合成"""
        app_id = os.getenv('BAIDU_APP_ID')
        api_key = os.getenv('BAIDU_API_KEY')
        secret_key = os.getenv('BAIDU_SECRET_KEY')
        
        if not all([app_id, api_key, secret_key]):
            raise ValueError("请在.env文件中设置百度语音服务凭证")
            
        self.tts_client = AipSpeech(app_id, api_key, secret_key)

    def generate_script(self, prompt: str, max_tokens: int = 500) -> str:
        """使用GPT生成视频脚本"""
        print("正在生成视频脚本...")
        
        response = self.openai_client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "你是一个专业的短视频脚本作家，善于创作简洁、吸引人的内容。"},
                {"role": "user", "content": f"请为以下主题创作一个短视频脚本（包含旁白和场景描述）：{prompt}"}
            ],
            max_tokens=max_tokens
        )
        
        script = response.choices[0].message.content
        print(f"脚本生成完成：\n{script}\n")
        return script

    def parse_script(self, script: str) -> List[Dict[str, str]]:
        """解析脚本为场景列表"""
        print("正在解析脚本...")
        
        response = self.openai_client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": "你是一个脚本解析专家，请将输入的脚本解析为场景列表，每个场景包含旁白和场景描述。输出格式为JSON数组。"},
                {"role": "user", "content": f"请解析以下脚本：\n{script}"}
            ]
        )
        
        scenes = json.loads(response.choices[0].message.content)
        print(f"解析完成，共{len(scenes)}个场景\n")
        return scenes

    def generate_image(self, prompt: str, output_path: str) -> str:
        """使用Stable Diffusion生成场景图片"""
        print(f"正在生成图片：{prompt}")
        
        # 生成图片
        answers = self.stability_client.generate(
            prompt=prompt,
            seed=int(time.time()),
            steps=50,
            cfg_scale=8.0,
            width=1024,
            height=576,
            samples=1,
        )
        
        # 保存图片
        for resp in answers:
            for artifact in resp.artifacts:
                if artifact.finish_reason == generation.FILTER:
                    print("图片生成被过滤")
                    return None
                    
                if artifact.type == generation.ARTIFACT_IMAGE:
                    img = Image.fromarray(np.array(artifact.binary, dtype=np.uint8))
                    img.save(output_path)
                    print(f"图片已保存：{output_path}\n")
                    return output_path
        
        return None

    def generate_audio(self, text: str, output_path: str) -> str:
        """使用百度TTS生成语音"""
        print(f"正在生成语音：{text}")
        
        try:
            # TTS参数配置
            options = {
                'spd': 5,  # 语速，取值0-15
                'pit': 5,  # 音调，取值0-15
                'vol': 8,  # 音量，取值0-15
                'per': 4,  # 发音人选择：0-普通女声，1-普通男声，3-情感男声，4-情感女声
                'aue': 6   # 下载的文件格式，3为mp3格式(默认)； 4为pcm-16k；5为pcm-8k；6为wav
            }

            # 调用TTS服务
            result = self.tts_client.synthesis(text, 'zh', 1, options)
            
            # 如果返回结果是字典类型，说明合成失败
            if isinstance(result, dict):
                print(f"语音生成失败：{result}\n")
                return None
                
            # 保存音频文件
            with open(output_path, 'wb') as f:
                f.write(result)
            print(f"语音已保存：{output_path}\n")
            return output_path

        except Exception as e:
            print(f"语音生成错误: {e}\n")
            return None

    def create_scene(self, scene: Dict[str, str], scene_idx: int) -> VideoFileClip:
        """创建单个场景的视频片段"""
        print(f"正在创建第{scene_idx + 1}个场景...")
        
        # 生成图片
        image_path = self.output_dir / f"scene_{scene_idx}.png"
        image_path = self.generate_image(scene['scene_description'], str(image_path))
        
        # 生成语音
        audio_path = self.output_dir / f"scene_{scene_idx}.wav"
        audio_path = self.generate_audio(scene['narration'], str(audio_path))
        
        if not image_path or not audio_path:
            return None
            
        # 创建视频片段
        image_clip = ImageClip(str(image_path))
        audio_clip = AudioFileClip(str(audio_path))
        
        # 设置持续时间与音频相同
        video_clip = image_clip.set_duration(audio_clip.duration)
        video_clip = video_clip.set_audio(audio_clip)
        
        print(f"场景{scene_idx + 1}创建完成\n")
        return video_clip

    def create_video(self, prompt: str, output_path: str = "output.mp4"):
        """创建完整视频"""
        print(f"开始创建视频：{prompt}")
        
        # 生成脚本
        script = self.generate_script(prompt)
        
        # 解析场景
        scenes = self.parse_script(script)
        
        # 创建每个场景
        video_clips = []
        for i, scene in enumerate(scenes):
            clip = self.create_scene(scene, i)
            if clip:
                video_clips.append(clip)
        
        if not video_clips:
            print("没有成功创建任何场景")
            return
        
        # 合并所有场景
        print("正在合并场景...")
        final_video = concatenate_videoclips(video_clips)
        
        # 添加转场效果
        final_video = final_video.fadein(1).fadeout(1)
        
        # 保存视频
        print("正在导出视频...")
        final_video.write_videofile(
            output_path,
            fps=24,
            codec='libx264',
            audio_codec='aac'
        )
        
        # 清理资源
        final_video.close()
        for clip in video_clips:
            clip.close()
            
        print(f"视频创建完成：{output_path}")

def main():
    # 创建AI视频创作器
    creator = AIVideoCreator()
    
    # 设置视频主题
    prompt = "介绍人工智能如何改变我们的生活"
    
    # 创建视频
    creator.create_video(prompt)

if __name__ == "__main__":
    main()
