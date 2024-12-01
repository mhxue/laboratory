# 阿里云语音合成（TTS）演示

这是一个使用阿里云智能语音服务的示例项目，展示了如何将文本转换为自然语音。

## 功能特点

- 支持多种中文音色
- 可调节音量和语速
- 支持流式合成
- 输出MP3格式音频

## 前置要求

1. Python 3.7+
2. 阿里云账号
3. 开通智能语音服务
4. 创建AccessKey和AppKey

## 安装

1. 克隆仓库：
```bash
git clone [repository-url]
cd aliyun_tts
```

2. 安装依赖：
```bash
pip install -r requirements.txt
```

3. 设置环境变量：
复制`env.example`为`.env`并填入你的阿里云凭证：
```
ALIYUN_ACCESS_KEY_ID=your_access_key_id
ALIYUN_ACCESS_KEY_SECRET=your_access_key_secret
ALIYUN_APP_KEY=your_app_key
```

## 使用方法

1. 列出可用语音：
```python
python src/tts_demo.py
```

2. 自定义转换：
修改`src/tts_demo.py`中的参数来自定义文本和语音选项：
- voice: 选择语音（xiaoyun/xiaogang/xiaomei/xiaowang）
- volume: 音量（0-100）
- speech_rate: 语速（-500到500）
- pitch_rate: 语调（-500到500）

## API参考

### 主要函数

- `create_token()`: 创建访问令牌
- `list_voices()`: 列出可用语音选项
- `synthesize_speech()`: 执行文本到语音的转换

### 参数说明

- `text`: 要转换的文本
- `output_file`: 输出文件路径
- `voice`: 语音选择
- `volume`: 音量大小
- `speech_rate`: 语速
- `pitch_rate`: 语调

## 注意事项

1. 确保有足够的阿里云余额
2. 注意API调用频率限制
3. 保护好AccessKey等凭证
4. 注意音频文件的存储位置

## 故障排除

常见问题：

1. 认证失败
   - 检查AccessKey是否正确
   - 确认服务是否开通

2. 合成失败
   - 检查网络连接
   - 验证AppKey是否正确
   - 确认文本长度是否合规

## 许可证

MIT License

## 贡献指南

欢迎提交Issue和Pull Request！
