import whisper
import os
from pathlib import Path
import subprocess

def extract_audio(video_path, audio_path):
    """Extract audio from video using ffmpeg"""
    command = [
        'ffmpeg', '-i', video_path,
        '-ar', '16000',  # Sample rate required by Whisper
        '-ac', '1',      # Convert to mono
        '-c:a', 'pcm_s16le',  # PCM format
        audio_path
    ]
    subprocess.run(command, check=True)

def format_timestamp(seconds):
    """Convert seconds to SRT timestamp format"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    msecs = int((seconds % 1) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{msecs:03d}"

def save_srt(segments, output_path):
    """Save segments in SRT format"""
    with open(output_path, 'w', encoding='utf-8') as f:
        for i, seg in enumerate(segments, 1):
            start_time = format_timestamp(seg['start'])
            end_time = format_timestamp(seg['end'])
            text = seg['text'].strip()
            f.write(f"{i}\n{start_time} --> {end_time}\n{text}\n\n")

def extract_subtitles(video_path, output_dir=None, model_size="base", language=None):
    """
    Extract subtitles from a video file using Whisper
    
    Args:
        video_path (str): Path to the video file
        output_dir (str, optional): Directory to save output files. Defaults to video's directory.
        model_size (str, optional): Whisper model size ('tiny', 'base', 'small', 'medium', 'large').
        language (str, optional): Language code (e.g., 'en', 'zh'). If None, auto-detected.
    
    Returns:
        dict: Dictionary containing paths to generated files and transcription result
    """
    video_path = Path(video_path)
    if not video_path.exists():
        raise FileNotFoundError(f"Video file not found: {video_path}")
    
    # Set output directory
    if output_dir is None:
        output_dir = video_path.parent
    else:
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
    
    # Extract audio
    audio_path = output_dir / f"{video_path.stem}_audio.wav"
    print(f"Extracting audio from video...")
    extract_audio(str(video_path), str(audio_path))
    
    try:
        # Load Whisper model
        print(f"Loading Whisper {model_size} model...")
        model = whisper.load_model(model_size)
        
        # Transcribe audio
        print("Transcribing audio...")
        result = model.transcribe(
            str(audio_path),
            language=language,
            task="transcribe",
            verbose=False
        )
        
        # Save outputs
        srt_path = output_dir / f"{video_path.stem}.srt"
        txt_path = output_dir / f"{video_path.stem}.txt"
        
        # Save SRT file
        save_srt(result["segments"], srt_path)
        
        # Save plain text
        with open(txt_path, "w", encoding="utf-8") as f:
            f.write(result["text"])
        
        print(f"Generated files:")
        print(f"- SRT subtitles: {srt_path}")
        print(f"- Text transcript: {txt_path}")
        
        return {
            "srt_path": str(srt_path),
            "txt_path": str(txt_path),
            "result": result
        }
        
    finally:
        # Clean up temporary audio file
        if audio_path.exists():
            os.remove(audio_path)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Extract subtitles from video using Whisper")
    parser.add_argument("video_path", help="Path to the video file")
    parser.add_argument("--output-dir", help="Output directory (optional)")
    parser.add_argument("--model", default="base", choices=["tiny", "base", "small", "medium", "large"],
                      help="Whisper model size (default: base)")
    parser.add_argument("--language", help="Language code (e.g., en, zh). If not specified, auto-detected")
    
    args = parser.parse_args()
    
    try:
        extract_subtitles(
            args.video_path,
            output_dir=args.output_dir,
            model_size=args.model,
            language=args.language
        )
    except Exception as e:
        print(f"Error: {e}")
