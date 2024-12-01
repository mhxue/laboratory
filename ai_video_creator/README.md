# AI视频创作器

这是一个使用多个AI服务自动创建视频的工具，它结合了：
- GPT-4生成脚本
- Stable Diffusion生成图像
- 火山引擎TTS生成语音
- MoviePy处理视频

## 功能特点

- 自动生成完整的视频脚本
- 为每个场景生成匹配的图像
- 自然的语音旁白
- 自动添加转场效果
- 支持自定义主题

## 工作流程

1. 输入视频主题
2. GPT-4生成分场景脚本
3. 解析脚本为场景列表
4. 对每个场景：
   - Stable Diffusion生成场景图片
   - TTS生成旁白语音
   - 合成场景视频片段
5. 合并所有场景
6. 添加转场效果
7. 导出最终视频

## 安装要求

1. Python 3.8+
2. FFmpeg
3. 各AI服务的API密钥

## 安装步骤

1. 克隆仓库：
```bash
git clone [repository-url]
cd ai_video_creator
```

2. 安装依赖：
```bash
pip install -r requirements.txt
```

3. 安装FFmpeg：
```bash
brew install ffmpeg  # macOS
```

4. 配置环境变量：
复制`env.example`为`.env`并填入你的API密钥：
```
OPENAI_API_KEY=your_openai_api_key
STABILITY_KEY=your_stability_key
VOLCANO_ACCESS_KEY=your_volcano_access_key
VOLCANO_SECRET_KEY=your_volcano_secret_key
```

## 使用方法

1. 基本使用：
```python
python src/video_creator.py
```

2. 自定义主题：
修改`src/video_creator.py`中的`prompt`变量。

## 参数说明

### 视频参数
- 分辨率：1024x576
- 帧率：24fps
- 视频编码：H.264
- 音频编码：AAC

### AI参数
- GPT模型：gpt-4
- 图像生成步数：50
- TTS音色：活力女声

## 注意事项

1. API使用限制
   - 注意各服务的API调用限制
   - 合理设置生成参数

2. 资源消耗
   - 图片生成较耗时
   - 视频处理需要较大内存

3. 成本控制
   - 跟踪API使用量
   - 优化生成参数

## 常见问题

1. 图片生成失败
   - 检查提示词是否合适
   - 确认API密钥正确

2. 视频处理错误
   - 确认FFmpeg安装正确
   - 检查内存使用情况

3. 语音生成问题
   - 验证文本长度适中
   - 检查网络连接

## 许可证

MIT License

## 贡献指南

欢迎提交Issue和Pull Request！
