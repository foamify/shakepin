#!/bin/bash

# Original by Ansh Rathod, modified by Damy Wise

echo "v1.1"
# Set the HOME environment variable (if needed)
export HOME="$HOME"

# Source environment configuration files (suppress output)
if [ -f ~/.bash_profile ]; then source ~/.bash_profile &>/dev/null; fi
if [ -f ~/.bashrc ]; then source ~/.bashrc &>/dev/null; fi
if [ -f ~/.profile ]; then source ~/.profile &>/dev/null; fi
if [ -f ~/.zshrc ]; then source ~/.zshrc &>/dev/null; fi
if [ -f ~/.zprofile ]; then source ~/.zprofile &>/dev/null; fi
if [ -f ~/.zlogin ]; then source ~/.zlogin &>/dev/null; fi

# Determine the architecture
ARCH=$(uname -m)

# Set the default Homebrew installation path based on the architecture
if [[ "$ARCH" == "x86_64" ]]; then
  HOMEBREW_PREFIX="/usr/local"
else
  HOMEBREW_PREFIX="/opt/homebrew"
fi

# Function to check if ffmpeg is installed and working
check_ffmpeg() {
  local version_output
  version_output=$(ffmpeg -version 2>/dev/null)
  if [ $? -eq 0 ] && [[ "$version_output" == *"ffmpeg version"* ]]; then
    return 0
  fi
  return 1
}

# Function to check if ImageMagick is installed and working
check_imagemagick() {
  local version_output
  version_output=$(magick -version 2>/dev/null)
  if [ $? -eq 0 ] && [[ "$version_output" == *"ImageMagick"* ]]; then
    return 0
  fi
  return 1
}

# Function to check if yt-dlp is installed and working
check_ytdlp() {
  local version_output
  version_output=$(yt-dlp --version 2>/dev/null)
  if [ $? -eq 0 ]; then
    return 0
  fi
  return 1
}

# Check if all tools are installed and working
ffmpeg_exists=$(check_ffmpeg && echo true || echo false)
imagemagick_exists=$(check_imagemagick && echo true || echo false)
ytdlp_exists=$(check_ytdlp && echo true || echo false)

# Only proceed with Homebrew installation if any tool is missing
if ! $ffmpeg_exists || ! $imagemagick_exists || ! $ytdlp_exists; then
  # Check if Homebrew needs to be installed
  if ! brew --version &>/dev/null; then
    echo -e "\nNote: Homebrew is not installed. Installing Homebrew since one or more required tools are missing...\n"
    
    yes '' | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH
    if [[ "$ARCH" == "x86_64" ]]; then
      echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.bash_profile
    else
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    fi
    
    # Source the updated profile
    source ~/.bash_profile 
    source ~/.zprofile

    echo -e "\nHomebrew installation completed.\n"
  else
    echo -e "\nHomebrew installation completed.\n"
  fi
else
  echo -e "\nAll required tools are already installed.\n"
fi

# Install missing tools
if ! $ffmpeg_exists; then
  echo -e "Note: ffmpeg is not installed. Installing ffmpeg...\n"
  brew install ffmpeg
  
  # Verify installation
  if ! check_ffmpeg; then
    echo -e "\nError: FFmpeg not working. Trying reinstall...\n"
    brew reinstall ffmpeg
    
    if ! check_ffmpeg; then
      echo -e "\nError: FFmpeg installation failed. Please check your system configuration.\n"
      exit 1
    fi
  fi
  
  echo -e "\nffmpeg installation completed.\n"
else
  # Even if FFmpeg exists, verify it's working correctly
  if ! check_ffmpeg; then
    echo -e "\nFFmpeg exists but not working correctly. Reinstalling...\n"
    brew reinstall ffmpeg
    
    if ! check_ffmpeg; then
      echo -e "\nError: FFmpeg reinstallation failed. Please check your system configuration.\n"
      exit 1
    fi
    
    echo -e "\nFFmpeg reinstallation completed successfully.\n"
  else
    echo -e "ffmpeg installation completed.\n"
  fi
fi

if ! $imagemagick_exists; then
  echo -e "Note: ImageMagick is not installed. Installing ImageMagick...\n"

  brew install imagemagick

  echo -e "\nImageMagick installation completed.\n"
else
  echo -e "ImageMagick installation completed.\n"
fi

if ! $ytdlp_exists; then
  echo -e "Note: yt-dlp is not installed. Installing yt-dlp...\n"
  brew install yt-dlp
  
  # Verify installation
  if ! check_ytdlp; then
    echo -e "\nError: yt-dlp not working. Trying reinstall...\n"
    brew reinstall yt-dlp
    
    if ! check_ytdlp; then
      echo -e "\nError: yt-dlp installation failed. Please check your system configuration.\n"
      exit 1
    fi
  fi
  
  echo -e "\nyt-dlp installation completed.\n"
else
  echo -e "yt-dlp installation completed.\n"
fi

echo -e "\nBoth ffmpeg and ImageMagick are already installed.\n"

# Function to check if a command runs successfully
check_command() {
  local version_output
  version_output=$("$@" 2>/dev/null)
  if [ $? -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

# Verify all tools are working correctly by checking their versions
ffmpeg_working=false
imagemagick_working=false
ytdlp_working=false

if check_command ffmpeg -version; then
  ffmpeg_working=true
fi

if check_command magick -version; then
  imagemagick_working=true
fi

if check_command yt-dlp --version; then
  ytdlp_working=true
fi

# Only print paths if all tools are working correctly
if $ffmpeg_working && $imagemagick_working && $ytdlp_working; then
  # Get the paths of all tools
  FFMPEG_PATH=$(which ffmpeg)
  IMAGEMAGICK_PATH=$(which magick)
  YTDLP_PATH=$(which yt-dlp)
  
  # Print the paths with some formatting
  echo -e "\nPaths for installed tools:"
  echo -e "---------------------------------"
  echo -e "FFmpeg path: $FFMPEG_PATH"
  echo -e "ImageMagick path: $IMAGEMAGICK_PATH"
  echo -e "yt-dlp path: $YTDLP_PATH"
  echo -e "---------------------------------\n"
  
  echo -e "All checks and installations are completed successfully."
else
  if ! $ffmpeg_working; then
    echo -e "- FFmpeg is not working properly\n"
  fi
  if ! $imagemagick_working; then
    echo -e "- ImageMagick is not working properly\n"
  fi
  if ! $ytdlp_working; then
    echo -e "- yt-dlp is not working properly\n"
  fi
  echo -e "Error: An error occurred during one or more installations."
fi