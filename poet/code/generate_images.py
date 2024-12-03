import json
import os
import time
from openai import OpenAI
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Initialize OpenAI client
client = OpenAI(
    api_key=os.getenv('OPENAI_API_KEY'),
    base_url=os.getenv('OPENAI_API_BASE')
)

# Get the project root directory
project_root = Path(__file__).parent.parent
images_dir = project_root / 'images'

# Style configuration
STYLE_PROMPT = """使用中国水墨画风格创作，要求：
1. 整体风格：传统水墨画，色彩鲜艳明朗一点，要适合短视频平台风格
2. 笔触细腻，层次丰富
3. 构图要有留白，体现意境
4. 保持简约优雅的美感
具体场景："""

def generate_image(prompt, filename, retry_delay=3600):
    """Generate an image using OpenAI DALL-E and save it"""
    # Skip if image already exists
    if os.path.exists(images_dir / f'{filename}.png'):
        print(f"Skipping {filename} - already exists")
        return

    try:
        # Combine style prompt with content prompt
        full_prompt = f"{STYLE_PROMPT} {prompt}"
        print(f"Generating image with prompt: {full_prompt}")
        
        response = client.images.generate(
            model="dall-e-3",
            prompt=full_prompt,
            size="1024x1024",
            quality="standard",
            n=1,
        )
        
        # Get the image URL
        image_url = response.data[0].url
        
        # Download and save the image
        import requests
        img_data = requests.get(image_url).content
        
        # Save the image
        with open(images_dir / f'{filename}.png', 'wb') as f:
            f.write(img_data)
            
        print(f"Generated and saved: {filename}")
        
    except Exception as e:
        if "rate limit exceeded" in str(e).lower():
            print(f"Rate limit hit. Waiting {retry_delay} seconds before retrying...")
            time.sleep(retry_delay)
            generate_image(prompt, filename, retry_delay)
        else:
            print(f"Error generating image for {filename}: {str(e)}")

def main():
    # Read the script
    script_path = project_root / '01' / 'script.json'
    with open(script_path, 'r', encoding='utf-8') as f:
        script = json.load(f)
    
    # Create images directory if it doesn't exist
    os.makedirs(images_dir, exist_ok=True)
    
    print("Starting image generation...")
    
    # Generate opening scene
    opening = script['segments'][0]
    generate_image(
        f"Create a serene winter forest scene. {opening['visual']}",
        "opening_scene"
    )
    
    # Generate background scene
    background = script['segments'][1]
    generate_image(
        f"Create a portrait scene showing Tang Dynasty poet Wang Wei in his mountain retreat. {background['visual']}",
        "wang_wei_portrait"
    )
    
    # Generate poem scenes
    poem_section = script['segments'][2]
    for i, detail in enumerate(poem_section['visual_details']):
        generate_image(
            f"Create a scene depicting: {detail['visual']}",
            f"poem_scene_{i+1}"
        )
    
    # Generate ending scene
    ending = script['segments'][-1]
    generate_image(
        f"Create a peaceful nature scene for video ending. {ending['visual']}",
        "ending_scene"
    )
    
    print("Image generation complete!")

if __name__ == "__main__":
    main()
