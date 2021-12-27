#!/bin/bash
# shellcheck disable=SC2086,SC2183,SC2026,SC2001,SC2059
# ffmes - ffmpeg media encode script
# Bash tool handling media files and DVD. Mainly with ffmpeg. Batch or single file.
#
# Author : Romain Barbarot
# https://github.com/Jocker666z/ffmes/
#
# licence : GNU GPL-2.0

# Version
VERSION=v0.95

# Paths
export PATH=$PATH:/home/$USER/.local/bin													# For case of launch script outside a terminal & bin in user directory
FFMES_BIN=$(basename "${0}")																# Set script name for prevent error when rename script
FFMES_PATH="$( cd "$( dirname "$0" )" && pwd )"												# Set ffmes path for restart from any directory
FFMES_CACHE="/tmp/ffmes"																	# Cache directory
FFMES_FFPROBE_CACHE_STATS="$FFMES_CACHE/stat-ffprobe-$(date +%Y%m%s%N).info"				# ffprobe cache file
FFMES_FFMPEG_CACHE_STAT="$FFMES_CACHE/stat-ffmpeg-$(date +%Y%m%s%N).info"					# ffmpeg cache file
FFMES_FFMPEG_PROGRESS="$FFMES_CACHE/ffmpeg-progress-$(date +%Y%m%s%N).info"					# ffmpeg progress cache file
FFMES_CACHE_TAG="$FFMES_CACHE/tag-$(date +%Y%m%s%N).info"									# tag-DATE.info, audio tag file
FFMES_CACHE_INTEGRITY="$FFMES_CACHE/interity-$(date +%Y%m%s%N).info"						# integrity-DATE.info, list of files fail interity check
FFMES_CACHE_UNTAGGED="$FFMES_CACHE/untagged-$(date +%Y%m%s%N).info"							# integrity-DATE.info, list of files untagged
LSDVD_CACHE="$FFMES_CACHE/lsdvd-$(date +%Y%m%s%N).info"										# lsdvd cache
OPTICAL_DEVICE=(/dev/dvd /dev/sr0 /dev/sr1 /dev/sr2 /dev/sr3)								# DVD player drives names

# General variables
CORE_COMMAND_NEEDED=(ffmpeg ffprobe sox mediainfo mkvmerge mkvpropedit find nproc uchardet iconv wc bc du awk jq)
NPROC=$(nproc --all)																		# Set number of thread
FFMPEG_LOG_LVL="-hide_banner -loglevel panic -nostats"										# FFmpeg log level
FFMPEG_PROGRESS="-stats_period 0.3 -progress $FFMES_FFMPEG_PROGRESS"						# FFmpeg arguments for progress bar

# Custom binary location
FFMPEG_CUSTOM_BIN=""																		# FFmpeg binary, enter location of bin, if variable empty use system bin
FFPROBE_CUSTOM_BIN=""																		# FFprobe binary, enter location of bin, if variable empty use system bin
SOX_CUSTOM_BIN=""																			# Sox binary, enter location of bin, if variable empty use system bin

# DVD & Blu-ray rip variables
BLURAY_COMMAND_NEEDED=(bluray_copy bluray_info)
DVD_COMMAND_NEEDED=(dvdbackup dvdxchap lsdvd pv)
ISO_EXT_AVAILABLE="iso"
VOB_EXT_AVAILABLE="vob"

# Video variables
X265_LOG_LVL="log-level=-1:"																# libx265 log level
VIDEO_EXT_AVAILABLE="3gp|avi|bik|flv|m2ts|m4v|mkv|mts|mp4|mpeg|mpg|mov|ogv|rm|rmvb|ts|vob|vp9|webm|wmv"
NVENC="0"																					# Set number of video encoding in same time, the countdown starts at 0, so 0 is worth one encoding at a time (0=1;1=2...)
VAAPI_device="/dev/dri/renderD128"															# VAAPI device location

# Subtitle variables
SUBTI_COMMAND_NEEDED=(subp2tiff subptools tesseract wget)
SUBTI_EXT_AVAILABLE="ass|srt|ssa|idx|sup"

# Audio variables
CUE_SPLIT_COMMAND_NEEDED=(flac mac cueprint cuetag shnsplit wvunpack)
AUDIO_EXT_AVAILABLE="8svx|aac|aif|aiff|ac3|amb|ape|aptx|aud|caf|dff|dsf|dts|eac3|flac|m4a|mka|mlp|mp2|mp3|mod|mqa|mpc|mpg|ogg|ops|opus|ra|ram|sbc|shn|spx|tak|thd|tta|w64|wav|wma|wv"
CUE_EXT_AVAILABLE="cue"
M3U_EXT_AVAILABLE="m3u|m3u8"
ExtractCover="0"																			# Extract cover, 0=extract cover from source and remove in output, 1=keep cover from source in output, empty=remove cover in output
RemoveM3U="0"																				# Remove m3u playlist, 0=no remove, 1=remove
PeakNormDB="1"																				# Peak db normalization option, this value is written as positive but is used in negative, e.g. 4 = -4

# Tag variables
TAG_COMMAND_NEEDED=(mac metaflac mid3v2 tracktag wvtag)
AUDIO_TAG_EXT_AVAILABLE="aif|aiff|ape|flac|m4a|mp3|ogg|opus|wv"

# Error messages
MESS_NO_VIDEO_FILE="No video file to process. Select one, or restart ffmes in a directory containing them"
MESS_NO_AUDIO_FILE="No audio file to process. Select one, or restart ffmes in a directory containing them"
MESS_ONE_VIDEO_ONLY="Only one video file at a time. Select one, or restart ffmes in a directory containing one video"
MESS_ONE_AUDIO_ONLY="Only one audio file at a time. Select one, or restart ffmes in a directory containing one audio"
MESS_BATCH_ONLY="Only more than one file at a time. Restart ffmes in a directory containing several files"
MESS_ONE_EXTENTION_ONLY="Only one extention type at a time."

## SOURCE FILES VARIABLES
DetectDVD() {							# DVD detection
for DEVICE in "${OPTICAL_DEVICE[@]}"; do
	lsdvd "$DEVICE" &>/dev/null
	local lsdvd_result=$?
	if [ "$lsdvd_result" -eq 0 ]; then
		DVD_DEVICE="$DEVICE"
		DVDtitle=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD_DEVICE" -I 2>/dev/null | grep "DVD with title" | tail -1 | awk -F'"' '{print $2}')
		break
	fi
done
}
SetGlobalVariables() {					# Construct variables with files accepted
# Array
LSTVIDEO=()
LSTVIDEOEXT=()
LSTAUDIO=()
LSTAUDIOEXT=()
LSTISO=()
LSTAUDIOTAG=()
LSTSUBEXT=()
LSTCUE=()
LSTVOB=()
LSTM3U=()

# Populate arrays
if test -n "$ARGUMENT"; then
	if [[ "$InputFileExt" =~ ${VIDEO_EXT_AVAILABLE[*]} ]]; then
		LSTVIDEO+=("$ARGUMENT")
		mapfile -t LSTVIDEOEXT < <(echo "${LSTVIDEO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	elif [[ "$InputFileExt" =~ ${AUDIO_EXT_AVAILABLE[*]} ]]; then
		LSTAUDIO+=("$ARGUMENT")
		mapfile -t LSTAUDIOEXT < <(echo "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	elif [[ "$InputFileExt" =~ ${ISO_EXT_AVAILABLE[*]} ]]; then
		LSTISO+=("$ARGUMENT")
	fi
else
	# List source(s) video file(s) & number of differents extentions
	mapfile -t LSTVIDEO < <(find "$PWD" -maxdepth 1 -type f -regextype posix-egrep \
		-iregex '.*\.('$VIDEO_EXT_AVAILABLE')$' 2>/dev/null | sort)
	mapfile -t LSTVIDEOEXT < <(echo "${LSTVIDEO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	# List source(s) audio file(s) & number of differents extentions
	mapfile -t LSTAUDIO < <(find . -maxdepth 5 -type f -regextype posix-egrep \
		-iregex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	mapfile -t LSTAUDIOEXT < <(echo "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	# List source(s) ISO file(s)
	mapfile -t LSTISO < <(find . -maxdepth 1 -type f -regextype posix-egrep \
		-iregex '.*\.('$ISO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
fi
# List source(s) audio file(s) that can be tagged
mapfile -t LSTAUDIOTAG < <(find . -maxdepth 1 -type f -regextype posix-egrep \
	-iregex '.*\.('$AUDIO_TAG_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
# List source(s) subtitle file(s)
mapfile -t LSTSUB < <(find . -maxdepth 1 -type f -regextype posix-egrep \
	-iregex '.*\.('$SUBTI_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
mapfile -t LSTSUBEXT < <(echo "${LSTSUB[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
# List source(s) CUE file(s)
mapfile -t LSTCUE < <(find . -maxdepth 1 -type f -regextype posix-egrep \
	-iregex '.*\.('$CUE_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
# List source(s) VOB file(s)
mapfile -t LSTVOB < <(find . -maxdepth 1 -type f -regextype posix-egrep \
	-iregex '.*\.('$VOB_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
# List source(s) M3U file(s)
mapfile -t LSTM3U < <(find . -maxdepth 1 -type f -regextype posix-egrep \
	-iregex '.*\.('$M3U_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

# Count uniq extension
NBVEXT=$(echo "${LSTVIDEOEXT[@]##*.}" | uniq -u | wc -w)
NBAEXT=$(echo "${LSTAUDIOEXT[@]##*.}" | uniq -u | wc -w)
}
Media_Source_Info_Record() {
# Local variables
local source_files
local ffprobe_fps_raw
local video_index
local audio_index
local subtitle_index

# Array
StreamIndex=()
ffprobe_StreamIndex=()
ffprobe_StreamType=()
ffprobe_Codec=()
## Video
ffprobe_v_StreamIndex=()
ffprobe_Profile=()
ffprobe_Width=()
ffprobe_Height=()
ffprobe_SAR=()
ffprobe_DAR=()
ffprobe_Pixfmt=()
ffprobe_ColorRange=()
ffprobe_ColorSpace=()
ffprobe_ColorTransfert=()
ffprobe_ColorPrimaries=()
ffprobe_FieldOrder=()
ffprobe_fps=()
## Audio
ffprobe_a_StreamIndex=()
ffprobe_SampleFormat=()
ffprobe_SampleRate=()
ffprobe_Channel=()
ffprobe_ChannelLayout=()
ffprobe_Bitrate=()
# Subtitle
ffprobe_s_StreamIndex=()
ffprobe_forced=()
## Tag
ffprobe_language=()
# Disposition
ffprobe_AttachedPic=()
ffprobe_default=()


# File to list
source_files="$1"

# Get stats with ffprobe
"$ffprobe_bin" -analyzeduration 1G -probesize 1G -loglevel panic \
	-show_chapters -show_format -show_streams -print_format json=c=1 \
	"$source_files" > "$FFMES_FFPROBE_CACHE_STATS"


# Array stats

## Index of video, audio & subtitle
video_index="0"
audio_index="0"
subtitle_index="0"

## Map stream index
mapfile -t StreamIndex < <(jq -r '.streams[] | .index' "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null)
for index in "${StreamIndex[@]}"; do

		# Shared
		ffprobe_StreamIndex+=( "$index" )
		ffprobe_Codec+=( "$(jqparse_stream "$index" "codec_name")" )
		ffprobe_StreamType+=( "$(jqparse_stream "$index" "codec_type")" )
		if ! [[ "$audio_list" = "1" ]]; then
			ffprobe_language+=( "$(jqparse_tag "$index" "language")" )
			ffprobe_default+=( "$(jqparse_disposition "$index" "default")" )
		fi

		# Video specific
		if ! [[ "$audio_list" = "1" ]]; then
			if [[ "${ffprobe_StreamType[-1]}" = "video" ]]; then
				# Fix black screen + green line (https://trac.ffmpeg.org/ticket/6668)
				if [[ "${ffprobe_Codec[-1]}" = "mpeg2video" ]]; then
					unset GPUDECODE
				else
					if [[ -z "$GPUDECODE" ]] && [[ -n "$VAAPI_device" ]]; then
						TestVAAPI
					fi
				fi
				ffprobe_v_StreamIndex+=( "$video_index" )
				video_index=$((video_index+1))
				ffprobe_Profile+=( "$(jqparse_stream "$index" "profile")" )
				ffprobe_Width+=( "$(jqparse_stream "$index" "width")" )
				ffprobe_Height+=( "$(jqparse_stream "$index" "height")" )
				ffprobe_SAR+=( "$(jqparse_stream "$index" "sample_aspect_ratio")" )
				ffprobe_DAR+=( "$(jqparse_stream "$index" "display_aspect_ratio")" )
				ffprobe_Pixfmt+=( "$(jqparse_stream "$index" "pix_fmt")" )
				ffprobe_ColorRange+=( "$(jqparse_stream "$index" "color_range")" )
				ffprobe_ColorSpace+=( "$(jqparse_stream "$index" "color_space")" )
				ffprobe_ColorTransfert+=( "$(jqparse_stream "$index" "color_transfer")" )
				ffprobe_ColorPrimaries+=( "$(jqparse_stream "$index" "color_primaries")" )
				ffprobe_FieldOrder+=( "$(jqparse_stream "$index" "field_order")" )
				ffprobe_fps_raw=$(jqparse_stream "$index" "r_frame_rate")
				ffprobe_fps+=( "$(bc <<< "scale=2; $ffprobe_fps_raw" | sed 's!\.0*$!!')" )
				ffprobe_AttachedPic+=( "$(jqparse_disposition "$index" "attached_pic")" )
			else
				ffprobe_v_StreamIndex+=( "" )
				ffprobe_Profile+=( "" )
				ffprobe_Width+=( "" )
				ffprobe_Height+=( "" )
				ffprobe_SAR+=( "" )
				ffprobe_DAR+=( "" )
				ffprobe_Pixfmt+=( "" )
				ffprobe_ColorRange+=( "" )
				ffprobe_ColorSpace+=( "" )
				ffprobe_ColorTransfert+=( "" )
				ffprobe_ColorPrimaries+=( "" )
				ffprobe_FieldOrder+=( "" )
				ffprobe_AttachedPic+=( "" )
			fi
		fi

		# Audio specific
		if [[ "${ffprobe_StreamType[-1]}" = "audio" ]]; then
			ffprobe_a_StreamIndex+=( "$audio_index" )
			audio_index=$((audio_index+1))
			ffprobe_SampleFormat+=( "$(jqparse_stream "$index" "sample_fmt")" )
			ffprobe_SampleRate+=( "$(jqparse_stream "$index" "sample_rate" | awk '{ foo = $1 / 1000 ; print foo }')" )
			ffprobe_Channel+=( "$(jqparse_stream "$index" "channels")" )
			ffprobe_ChannelLayout+=( "$(jqparse_stream "$index" "channel_layout")" )
			ffprobe_Bitrate_raw=$(jqparse_stream "$index" "bit_rate" | awk '{ foo = $1 / 1000 ; print foo }')
			if [[ "$ffprobe_Bitrate_raw" = "0" ]]; then
				ffprobe_Bitrate+=( "" )
			else
				ffprobe_Bitrate+=( "$ffprobe_Bitrate_raw" )
			fi
		else
			ffprobe_a_StreamIndex+=( "" )
			ffprobe_SampleFormat+=( "" )
			ffprobe_SampleRate+=( "" )
			ffprobe_ChannelLayout+=( "" )
			ffprobe_Bitrate+=( "" )
		fi

		# Subtitle specific
		if ! [[ "$audio_list" = "1" ]]; then
			if [[ "${ffprobe_StreamType[-1]}" = "subtitle" ]]; then
				ffprobe_s_StreamIndex+=( "$subtitle_index" )
				subtitle_index=$((subtitle_index+1))
				ffprobe_forced+=( "$(jqparse_disposition "$index" "forced")" )
			else
				ffprobe_s_StreamIndex+=( "" )
				ffprobe_forced+=( "" )
			fi
		fi
done

# Variable stats
## ffprobe stats
ffprobe_StartTime=$(jqparse_format "start_time")
ffprobe_Duration=$(jqparse_format "duration")
ffprobe_DurationFormated="$(Calc_Time_s_2_hms "$ffprobe_Duration")"
if ! [[ "$audio_list" = "1" ]]; then
	# If ffprobe_fps[0] active consider video, if not consider audio
	# Total Frames made by calculation instead of count, less accurate but more speed up
	if [[ -n "${ffprobe_fps[0]}" ]]; then
		ffprobe_TotalFrames=$(bc <<< "scale=0; ; ( $ffprobe_Duration * ${ffprobe_fps[0]} )")
	fi

	ffprobe_OverallBitrate=$(jqparse_format "bit_rate" | awk '{ foo = $1 / 1000 ; print foo }' | awk -F"." '{ print $1 }')
	ffprobe_ChapterNumber=$(jq -r '.chapters[]' "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null | grep -c "start_time")
	if [[ "$ffprobe_ChapterNumber" -gt "1" ]]; then
		ffprobe_ChapterNumberFormated="$ffprobe_ChapterNumber chapters"
	fi
fi

## Mediainfo stats
if ! [[ "$audio_list" = "1" ]]; then
	mediainfo_VideoSize=$(mediainfo --Inform="Video;%StreamSize%" "$source_files" | awk '{ foo = $1 / 1024 / 1024 ; print foo }')
	if [[ "$mediainfo_VideoSize" = 0 ]]; then
		mediainfo_VideoSize=""
	fi
	mediainfo_Interlaced=$(mediainfo --Inform="Video;%ScanType/String%" "$source_files")
	mediainfo_HDR=$(mediainfo --Inform="Video;%HDR_Format/String%" "$source_files")
else
	mediainfo_Bitrate="$(mediainfo --Output="General;%OverallBitRate%" "$source_files" \
						| awk '{ kbyte=$1/1024; print kbyte }' | sed 's/\..*$//')"
fi
## File size
FilesSize=$(Calc_Files_Size "$source_files")
## Extentions
FilesExtention="${source_files##*.}"

## ffmpeg stats
if [[ "$FilesExtention" =~ ${AUDIO_EXT_AVAILABLE[*]} ]]; then
	"$ffmpeg_bin" -i "$source_files" -af "volumedetect" -vn -sn -dn -f null - &> "$FFMES_FFMPEG_CACHE_STAT"

	ffmpeg_meandb=$(< "$FFMES_FFMPEG_CACHE_STAT" grep "mean_volume:" | awk '{print $5}')
	ffmpeg_peakdb_raw=$(< "$FFMES_FFMPEG_CACHE_STAT" grep "max_volume:" | awk '{print $5}')
	if [[ "$ffmpeg_peakdb_raw" = "-0.0" ]]; then
		ffmpeg_peakdb_raw="0.0"
	fi
	ffmpeg_peakdb="$ffmpeg_peakdb_raw"
	ffmpeg_diffdb=$( bc <<< "$ffmpeg_peakdb - $ffmpeg_meandb" )
fi

# Clean
rm "$FFMES_FFPROBE_CACHE_STATS" &>/dev/null
}

## CHECK FILES & BIN
CheckFFmpegVersion() {
local ffmpeg_stats_period
local ffmpeg_vaapi_encoder

ffmpeg_stats_period=$("$ffmpeg_bin" -hide_banner -h full | grep "stats_period")
ffmpeg_vaapi_encoder=$("$ffmpeg_bin" -hide_banner -encoders | grep "hevc_vaapi")

# If ffmpeg version < 4.4 not use -stats_period
if [ -z "$ffmpeg_stats_period" ]; then
	FFMPEG_PROGRESS="-progress $FFMES_FFMPEG_PROGRESS"
fi

if [ -z "$ffmpeg_vaapi_encoder" ]; then
	unset VAAPI_device
fi

}
CheckCustomBin() {
if [[ -f "$FFMPEG_CUSTOM_BIN" ]]; then
	ffmpeg_bin="$FFMPEG_CUSTOM_BIN"
else
	ffmpeg_bin=$(command -v ffmpeg)
fi
if [[ -f "$FFPROBE_CUSTOM_BIN" ]]; then
	ffprobe_bin="$FFPROBE_CUSTOM_BIN"
else
	ffprobe_bin=$(command -v ffprobe)
fi
if [[ -f "$SOX_CUSTOM_BIN" ]]; then
	sox_bin="$SOX_CUSTOM_BIN"
else
	sox_bin=$(command -v sox)
fi
}
CheckCommandLabel() {
if [[ "$command" = "dvdxchap" ]]; then
	command="$command (ogmtools package)"
fi
if [[ "$command" = "subp2tiff" ]] || [[ "$command" = "subptools" ]]; then
	command="$command (ogmrip package)"
fi
if [[ "$command" = "mac" ]]; then
	command="$command (monkeys-audio package)"
fi
if [[ "$command" = "metaflac" ]]; then
	command="$command (flac package)"
fi
if [[ "$command" = "mid3v2" ]]; then
	command="$command (python-mutagen or python3-mutagen package)"
fi
if [[ "$command" = "tracktag" ]]; then
	command="$command (audiotools package)"
fi
if [[ "$command" = "wvtag" ]] || [[ "$command" = "wvunpack" ]]; then
	command="$command (wavpack package)"
fi
if [[ "$command" = "shnsplit" ]]; then
	command="$command (shntool package)"
fi
if [[ "$command" = "cuetag" ]] || [[ "$command" = "cueprint" ]]; then
	command="$command (cuetools package)"
fi
if [[ "$command" = "mkvmerge" ]] || [[ "$command" = "mkvpropedit" ]]; then
	command="$command (mkvtoolnix package)"
fi
if [[ "$command" = "bluray_copy" ]] || [[ "$command" = "bluray_info" ]]; then
	command="$command (https://github.com/beandog/bluray_info)"
fi
}
CheckCommandDisplay() {
local label
label="$1"
if (( "${#command_fail[@]}" )); then
	echo
	echo " Please install the $label dependencies:"
	Display_List_Truncate "${command_fail[@]}"
	echo
	exit
fi
}
CheckCoreCommand() {
n=0;
for command in "${CORE_COMMAND_NEEDED[@]}"; do
	if hash "$command" &>/dev/null; then
		(( c++ )) || true
	else
		CheckCommandLabel
		command_fail+=("  [!] $command")
		(( n++ )) || true
	fi
done
CheckCommandDisplay "ffmes"
}
CheckCueSplitCommand() {
n=0;
for command in "${CUE_SPLIT_COMMAND_NEEDED[@]}"; do
	if hash "$command" &>/dev/null; then
		(( c++ )) || true
	else
		CheckCommandLabel
		command_fail+=("  [!] $command")
		(( n++ )) || true
	fi
done
CheckCommandDisplay "CUE Splitting"
}
CheckDVDCommand() {
n=0;
for command in "${DVD_COMMAND_NEEDED[@]}"; do
	if hash "$command" &>/dev/null; then
		(( c++ )) || true
	else
		CheckCommandLabel
		command_fail+=("  [!] $command")
		(( n++ )) || true
	fi
done
CheckCommandDisplay "DVD rip"
}
CheckBDCommand() {
n=0;
for command in "${BLURAY_COMMAND_NEEDED[@]}"; do
	if hash "$command" &>/dev/null; then
		(( c++ )) || true
	else
		CheckCommandLabel
		command_fail+=("  [!] $command")
		(( n++ )) || true
	fi
done
CheckCommandDisplay "Blu-ray rip"
}
CheckSubtitleCommand() {
n=0;
for command in "${SUBTI_COMMAND_NEEDED[@]}"; do
	if hash "$command" &>/dev/null; then
		(( c++ )) || true
	else
		CheckCommandLabel
		command_fail+=("  [!] $command")
		(( n++ )) || true
	fi
done
CheckCommandDisplay "subtitle"
}
CheckTagCommand() {
n=0;
for command in "${TAG_COMMAND_NEEDED[@]}"; do
	if hash "$command" &>/dev/null; then
		(( c++ )) || true
	else
		CheckCommandLabel
		command_fail+=("  [!] $command")
		(( n++ )) || true
	fi
done
CheckCommandDisplay "tag"
}
CheckCacheDirectory() {					# Check if cache directory exist
if [ ! -d "$FFMES_CACHE" ]; then
	mkdir "$FFMES_CACHE"
fi
}
CheckFiles() {							# Promp a message to user with number of video, audio, sub to edit
# Video
if  [[ "$TESTARGUMENT" == *"Video"* ]]; then
	Display_Line_Truncate "  * Video to edit: ${LSTVIDEO[0]##*/}"
elif  [[ "$TESTARGUMENT" != *"Video"* ]] && [ "${#LSTVIDEO[@]}" -eq "1" ]; then
	Display_Line_Truncate "  * Video to edit: ${LSTVIDEO[0]##*/}"
elif [ "${#LSTVIDEO[@]}" -gt "1" ]; then											# If no arg + 1> videos
	echo "  * Video to edit: ${#LSTVIDEO[@]} files"
fi

# Audio
if  [[ "$TESTARGUMENT" == *"Audio"* ]]; then
	Display_Line_Truncate "  * Audio to edit: ${LSTAUDIO[0]##*/}"
elif [[ "$TESTARGUMENT" != *"Audio"* ]] && [ "${#LSTAUDIO[@]}" -eq "1" ]; then
	Display_Line_Truncate "  * Audio to edit: ${LSTAUDIO[0]##*/}"
elif [ "${#LSTAUDIO[@]}" -gt "1" ]; then											# If no arg + 1> videos
	echo "  * Audio to edit: ${#LSTAUDIO[@]} files"
fi

# ISO
if  [[ "$TESTARGUMENT" == *"ISO"* ]]; then
	Display_Line_Truncate "  * ISO to edit: ${LSTISO[0]}"
elif [[ "$TESTARGUMENT" != *"ISO"* ]] && [ "${#LSTISO[@]}" -eq "1" ]; then
	Display_Line_Truncate "  * ISO to edit: ${LSTISO[0]}"
fi

# Subtitle
if [ "${#LSTSUB[@]}" -eq "1" ]; then
	Display_Line_Truncate "  * Subtitle to edit: ${LSTSUB[0]}"
elif [ "${#LSTSUB[@]}" -gt "1" ]; then
	echo "  * Subtitle to edit: ${#LSTSUB[@]}"
fi

# DVD
if test -n "$DVD_DEVICE"; then
	Display_Line_Truncate "  * DVD ($DVD_DEVICE): $DVDtitle"
fi

# Nothing
if [ -z "$TESTARGUMENT" ] && [ -z "$DVD_DEVICE" ] && [ "${#LSTVIDEO[@]}" -eq "0" ] && [ "${#LSTAUDIO[@]}" -eq "0" ] && [ "${#LSTISO[@]}" -eq "0" ] && [ "${#LSTSUB[@]}" -eq "0" ]; then
	echo "  [!] No file to process"
fi
}

# ONE LINE MESSAGES
Echo_Separator_Light() {				# Horizontal separator light
printf '%*s' "$TERM_WIDTH" | tr ' ' "-"; echo
}
Echo_Separator_Large() {				# Horizontal separator large
printf '%*s' "$TERM_WIDTH" | tr ' ' "="; echo
}
Echo_Mess_Invalid_Answer() {			# Horizontal separator large
Echo_Mess_Error "Invalid answer, please try again"
}
Echo_Mess_Error() {						# Error message preformated
local error_label
error_label="$1"
error_option="$2"

if [[ -z "$error_option" ]]; then
	echo "  [!] ${error_label}."
elif [[ "$error_option" = "1" ]]; then
	echo
	echo "  [!] ${error_label}."
	echo
fi
}

## DISPLAY
Usage() {
cat <<- EOF
ffmes $VERSION - GNU GPL-2.0 Copyright - <https://github.com/Jocker666z/ffmes>
Bash tool handling media files and DVD. Mainly with ffmpeg.
In batch or single file.

Usage: ffmes [options]
                          Without option treat current directory.
  -ca|--compare_audio     Compare current audio files stats.
  -i|--input <file>       Treat one file.
  -i|--input <directory>  Treat in batch a specific directory.
  -h|--help               Display this help.
  -j|--videojobs <number> Number of video encoding in same time.
                          Default: 1
  -kc|--keep_cover        Keep embed image in audio files.
  --novaapi               No use vaapi for decode video.
  -s|--select <number>    Preselect option (by-passing main menu).
  -pk|--peaknorm <number> Peak db normalization.
                          Positive input used as negative.
                          Default: $PeakNormDB (-$PeakNormDB db)
  -v|--verbose            Display ffmpeg log level as info.
  -vv|--fullverbose       Display ffmpeg log level as debug.

EOF
}
Display_Main_Menu() {					# Main menu
clear
echo
echo "  / ffmes $VERSION /"
echo "  -----------------------------------------------------"
echo "   0 - DVD & Blu-ray rip                              |"
echo "   1 - video encoding                                 |-Video"
echo "   2 - copy stream to mkv with map option             |"
echo "   3 - encode audio stream only                       |"
echo "   4 - add audio stream with night normalization      |"
echo "  -----------------------------------------------------"
echo "  10 - view detailed video file informations          |"
echo "  11 - add audio stream or subtitle in video file     |-Video Tools"
echo "  12 - concatenate video files                        |"
echo "  13 - extract stream(s) of video file                |"
echo "  14 - split or cut video file by time                |"
echo "  15 - split mkv by chapter                           |"
echo "  16 - change color of DVD subtitle (idx/sub)         |"
echo "  17 - convert DVD subtitle (idx/sub) to srt          |"
echo "  -----------------------------------------------------"
echo "  20 - CUE splitter to flac                           |"
echo "  21 - audio to wav (PCM)                             |-Audio"
echo "  22 - audio to flac                                  |"
echo "  23 - audio to wavpack                               |"
echo "  24 - audio to mp3 (libmp3lame)                      |"
echo "  25 - audio to vorbis (libvorbis)                    |"
echo "  26 - audio to opus (libopus)                        |"
echo "  27 - audio to aac                                   |"
echo "  -----------------------------------------------------"
echo "  30 - audio tag editor                               |"
echo "  31 - view one audio file stats                      |-Audio Tools"
echo "  32 - compare audio files stats                      |"
echo "  33 - generate png image of audio spectrum           |"
echo "  34 - concatenate audio files                        |"
echo "  35 - split or cut audio file by time                |"
echo "  36 - audio file tester                              |"
echo "  37 - find untagged audio files                      |"
echo "  -----------------------------------------------------"
CheckFiles
echo "  -----------------------------------------------------"
}
Display_End_Encoding_Message() {		# Summary of encoding
local total_files
local pass_files
local source_size
local target_size

pass_files="$1"
total_files="$2"
target_size="$3"
source_size="$4"

if (( "${#filesPass[@]}" )); then
	Echo_Separator_Light
	echo " File(s) created:"
	Display_List_Truncate "${filesPass[@]}"
fi
if (( "${#filesReject[@]}" )); then
	Echo_Separator_Light
	echo " File(s) in error:"
	Display_List_Truncate "${filesReject[@]}"
fi
Echo_Separator_Light
if [ -z "$total_files" ]; then
	echo " $pass_files file(s) have been processed."
else
	echo " $pass_files/$total_files file(s) have been processed."
fi
if [[ -n "$source_size" && -n "$target_size" ]]; then
	echo " Created file(s) size: $target_size MB, a difference of $PERC% from the source(s) ($source_size MB)."
elif [[ -z "$source_size" && -n "$target_size" ]]; then
	echo " Created file(s) size: $target_size MB."
fi
echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: ${Elapsed_Time_formated}."
Echo_Separator_Light
echo
}
Display_Audio_Stats_List() {
# Local variables - display
local codec_string_length
local bitrate_string_length
local SampleFormat_string_length
local SampleRate_string_length
local bitrate_string_length
local duration_string_length
local peakdb_string_length
local meandb_string_length
local diffdb_string_lenght
local filename_string_length
local FilesSize_string_length
local horizontal_separator_string_length

# File to list
source_files=("$@")

# Limit to audio files grab stats
audio_list="1"

# Larger of column & separator
codec_string_length="7"
bitrate_string_length="4"
SampleFormat_string_length="4"
SampleRate_string_length="4"
Channel_string_length="1"
duration_string_length="8"
peakdb_string_length="5"
meandb_string_length="5"
diffdb_string_lenght="4"
FilesSize_string_length="5"
filename_string_length="40"
# Separator (=5)
quality_separator_string_length=$(( 4 * 5 ))
db_separator_string_length=$(( 2 * 5 ))
horizontal_separator_string_length=$(( 10 * 5 ))
# Total
quality_string_length=$(( codec_string_length + bitrate_string_length + SampleFormat_string_length \
							+ SampleRate_string_length + Channel_string_length + quality_separator_string_length ))
db_string_length=$(( peakdb_string_length + meandb_string_length + diffdb_string_lenght \
						+ db_separator_string_length ))
separator_string_length=$(( codec_string_length + bitrate_string_length + SampleFormat_string_length \
							+ SampleRate_string_length + duration_string_length + peakdb_string_length \
							+ meandb_string_length + diffdb_string_lenght + filename_string_length \
							+ Channel_string_length + FilesSize_string_length + horizontal_separator_string_length ))


# Only display if launched in argument
if [ "$force_compare_audio" = "1" ]; then
	Display_Remove_Previous_Line
	echo
fi

# Title display
echo " ${#source_files[@]} audio files - $(Calc_Files_Size "${source_files[@]}") MB"

# Table Display
if [[ "$separator_string_length" -le "$TERM_WIDTH" ]]; then
	# Title line 1
	printf '%*s' "$separator_string_length" | tr ' ' "-"; echo
	paste <(printf "%-${quality_string_length}.${quality_string_length}s\n" "Quality") <(printf "%s\n" "|") \
		<(printf "%-${duration_string_length}.${duration_string_length}s\n" "Duration") <(printf "%s\n" "|") \
		<(printf "%-${db_string_length}.${db_string_length}s\n" "Decibel") <(printf "%s\n" "|") \
		<(printf "%-${FilesSize_string_length}.${FilesSize_string_length}s\n" "Size") <(printf "%s\n" "|") \
		<(printf "%-${filename_string_length}.${filename_string_length}s\n" "") | column -s $'\t' -t
	# Title line 2
	paste <(printf "%-${codec_string_length}.${codec_string_length}s\n" "Codec") <(printf "%s\n" ".") \
		<(printf "%-${bitrate_string_length}.${bitrate_string_length}s\n" "kb/s") <(printf "%s\n" ".") \
		<(printf "%-${SampleFormat_string_length}.${SampleFormat_string_length}s\n" "fmt") <(printf "%s\n" ".") \
		<(printf "%-${SampleRate_string_length}.${SampleRate_string_length}s\n" "kHz") <(printf "%s\n" ".") \
		<(printf "%-${Channel_string_length}.${Channel_string_length}s\n" "ch") <(printf "%s\n" "|") \
		<(printf "%-${duration_string_length}.${duration_string_length}s\n" "m:s") <(printf "%s\n" "|") \
		<(printf "%-${peakdb_string_length}.${peakdb_string_length}s\n" "Peak") <(printf "%s\n" ".") \
		<(printf "%-${meandb_string_length}.${meandb_string_length}s\n" "Mean") <(printf "%s\n" ".") \
		<(printf "%-${diffdb_string_lenght}.${diffdb_string_lenght}s\n" "Diff") <(printf "%s\n" "|") \
		<(printf "%-${FilesSize_string_length}.${FilesSize_string_length}s\n" "MB") <(printf "%s\n" "|") \
		<(printf "%-${filename_string_length}.${filename_string_length}s\n" "Files") | column -s $'\t' -t
	printf '%*s' "$separator_string_length" | tr ' ' "-"; echo


	for files in "${source_files[@]}"; do
		# Get stats
		Media_Source_Info_Record "$files"

		for (( i=0; i<=$(( ${#ffprobe_StreamIndex[@]} - 1 )); i++ )); do
			if [[ "${ffprobe_StreamType[$i]}" = "audio" ]]; then
				# In table if term is wide enough, or in ligne
				paste <(printf "%-${codec_string_length}.${codec_string_length}s\n" "${ffprobe_Codec[i]}") <(printf "%s\n" ".") \
					<(printf "%-${bitrate_string_length}.${bitrate_string_length}s\n" "$mediainfo_Bitrate") <(printf "%s\n" ".") \
					<(printf "%-${SampleFormat_string_length}.${SampleFormat_string_length}s\n" "${ffprobe_SampleFormat[i]}") <(printf "%s\n" ".") \
					<(printf "%-${SampleRate_string_length}.${SampleRate_string_length}s\n" "${ffprobe_SampleRate[i]}") <(printf "%s\n" ".") \
					<(printf "%-${Channel_string_length}.${Channel_string_length}s\n" "${ffprobe_Channel[i]}") <(printf "%s\n" "|") \
					<(printf "%-${duration_string_length}.${duration_string_length}s\n" "$ffprobe_DurationFormated") <(printf "%s\n" "|") \
					<(printf "%-${peakdb_string_length}.${peakdb_string_length}s\n" "$ffmpeg_peakdb") <(printf "%s\n" ".") \
					<(printf "%-${meandb_string_length}.${meandb_string_length}s\n" "$ffmpeg_meandb") <(printf "%s\n" ".") \
					<(printf "%-${diffdb_string_lenght}.${diffdb_string_lenght}s\n" "$ffmpeg_diffdb") <(printf "%s\n" "|") \
					<(printf "%-${FilesSize_string_length}.${FilesSize_string_length}s\n" "$FilesSize") <(printf "%s\n" "|") \
					<(printf "%-${filename_string_length}.${filename_string_length}s\n" "$files") | column -s $'\t' -t 2>/dev/null
			fi
		done

	done
	printf '%*s' "$separator_string_length" | tr ' ' "-"; echo

# Line display
else
	# Display Separator
	printf '%*s' "$TERM_WIDTH_TRUNC" | tr ' ' "-"; echo
	for files in "${source_files[@]}"; do
		# Get stats
		Media_Source_Info_Record "$files"

		for (( i=0; i<=$(( ${#ffprobe_StreamIndex[@]} - 1 )); i++ )); do
			if [[ "${ffprobe_StreamType[$i]}" = "audio" ]]; then
				Display_Line_Truncate "  $files"
				echo "$(Display_Variable_Trick "$ffprobe_DurationFormated" "1" "kHz")\
				$FilesSize MB" \
				| awk '{$2=$2};1' | awk '{print "  " $0}'
				echo "$(Display_Variable_Trick "${ffprobe_Codec[i]}" "1")\
				$(Display_Variable_Trick "$mediainfo_Bitrate" "1" "kb/s")\
				$(Display_Variable_Trick "${ffprobe_SampleFormat[i]}" "1")\
				$(Display_Variable_Trick "${ffprobe_SampleRate[i]}" "1" "kHz")\
				${ffprobe_Channel[i]} channel(s)" \
				| awk '{$2=$2};1' | awk '{print "  " $0}'
				echo " peak dB: $ffmpeg_peakdb, mean dB: $ffmpeg_meandb, diff dB: $ffmpeg_diffdb" \
				| awk '{$2=$2};1' | awk '{print "  " $0}'
				printf '%*s' "$TERM_WIDTH_TRUNC" | tr ' ' "-"; echo
			fi
		done
	done
fi

# Only display if launched in argument
if [ "$force_compare_audio" = "1" ]; then
	echo
fi
}
Display_Media_Stats_One() {
# Local variables
local source_files

# File to list
source_files=("$@")

# Get stats
if ! [[ "${source_files[0]}" = "$source_files_backup" ]]; then
	Media_Source_Info_Record "${source_files[0]}"
fi
source_files_backup="${source_files[0]}"

# Display
clear
echo
if [[ "${#source_files[@]}" = "1" ]];then
	echo " Stats of the file:"
else
	echo " Stats of the first entry on a batch of ${#source_files[@]} files:"
fi
Echo_Separator_Light
echo "  File: $(basename "${source_files[0]}")"
echo "  Duration: $ffprobe_DurationFormated, Start: $ffprobe_StartTime, Bitrate: $ffprobe_OverallBitrate kb/s, Size: $FilesSize MB\
		$(Display_Variable_Trick "$ffprobe_ChapterNumberFormated" "2")" \
		| awk '{$2=$2};1' | awk '{print "  " $0}'


for (( i=0; i<=$(( ${#ffprobe_StreamIndex[@]} - 1 )); i++ )); do

	# Video
	if [[ "${ffprobe_StreamType[$i]}" = "video" ]]; then

		# Attached img
		if [[ "${ffprobe_AttachedPic[$i]}" = "attached pic" ]]; then
			echo "  Stream #${ffprobe_StreamIndex[i]}: ${ffprobe_StreamType[i]}:\
			$(Display_Variable_Trick "${ffprobe_Codec[i]}" "1")\
			$(Display_Variable_Trick "${ffprobe_Width[i]}x${ffprobe_Height[i]}" "1")\
			$(Display_Variable_Trick "${ffprobe_Pixfmt[i]}")\
			$(Display_Variable_Trick "${ffprobe_FieldOrder[i]}" "2")\
			$(Display_Variable_Trick "${ffprobe_ColorRange[i]}" "2")\
			$(Display_Variable_Trick "${ffprobe_ColorSpace[i]}" "2")\
			$(Display_Variable_Trick "${ffprobe_ColorTransfert[i]}" "2")\
			$(Display_Variable_Trick "${ffprobe_ColorPrimaries[i]}" "2")\
			$(Display_Variable_Trick "${ffprobe_AttachedPic[i]}" "2")" \
			| awk '{$2=$2};1' | awk '{print "  " $0}'

		# Video
		else
			echo "  Stream #${ffprobe_StreamIndex[i]}: ${ffprobe_StreamType[i]}:\
			$(Display_Variable_Trick "${ffprobe_Codec[i]}")\
			$(Display_Variable_Trick "${ffprobe_Profile[i]}" "3") \
			$(Display_Variable_Trick "${ffprobe_Width[i]}x${ffprobe_Height[i]}")\
			$(Display_Variable_Trick "${ffprobe_SAR[i]}" "4")\
			$(Display_Variable_Trick "${ffprobe_DAR[i]}" "5")\
			$(Display_Variable_Trick "${ffprobe_fps[i]}" "1" "fps")\
			$(Display_Variable_Trick "${mediainfo_VideoSize[i]}" "1" "MB")\
			$(Display_Variable_Trick "${ffprobe_Pixfmt[i]}")\
			$(Display_Variable_Trick "${ffprobe_FieldOrder[i]}" "2")\
			$(Display_Variable_Trick "${ffprobe_ColorRange[i]}" "2")\
			$(Display_Variable_Trick "${ffprobe_ColorSpace[i]}" "2")\
			$(Display_Variable_Trick "${ffprobe_ColorTransfert[i]}" "2")\
			$(Display_Variable_Trick "${ffprobe_ColorPrimaries[i]}" "2")" \
			| awk '{$2=$2};1' | awk '{print "  " $0}'

		fi
	fi

	# Audio
	if [[ "${ffprobe_StreamType[$i]}" = "audio" ]]; then
		echo "  Stream #${ffprobe_StreamIndex[i]}: ${ffprobe_StreamType[i]}: \
		$(Display_Variable_Trick "${ffprobe_Codec[i]}" "1") \
		$(Display_Variable_Trick "${ffprobe_SampleFormat[i]}" "1") \
		$(Display_Variable_Trick "${ffprobe_Bitrate[i]}" "1" "kb/s") \
		$(Display_Variable_Trick "${ffprobe_SampleRate[i]}" "1" "kHz") \
		$(Display_Variable_Trick "${ffprobe_ChannelLayout[i]}") \
		$(Display_Variable_Trick "${ffprobe_language[i]}" "2") \
		$(Display_Variable_Trick "${ffprobe_default[i]}" "2")" \
		| awk '{$2=$2};1' | awk '{print "  " $0}'
	fi

	# Subtitle
	if [[ "${ffprobe_StreamType[$i]}" = "subtitle" ]]; then
		echo "  Stream #${ffprobe_StreamIndex[i]}: ${ffprobe_StreamType[i]}: \
		$(Display_Variable_Trick "${ffprobe_Codec[i]}") \
		$(Display_Variable_Trick "${ffprobe_language[i]}" "2") \
		$(Display_Variable_Trick "${ffprobe_default[i]}" "2") \
		$(Display_Variable_Trick "${ffprobe_forced[i]}" "2")" \
		| awk '{$2=$2};1' | awk '{print "  " $0}'
	fi

done

Echo_Separator_Large

# Reset limit to audio files grab stats
audio_list=""
}
Display_Video_Custom_Info_choice() {	# Option 1  	- Summary of configuration
Display_Media_Stats_One "${LSTVIDEO[@]}"
echo " Target configuration:"
echo "  Video stream: $chvidstream"
if [ "$ENCODV" = "1" ]; then
	echo "   * Desinterlace: $chdes"
	echo "   * Resolution: $chwidth"
	if [[ "$codec" != "hevc_vaapi" ]]; then
		echo "   * Rotation: $chrotation"
		if test -n "$HDR"; then						# display only if HDR source
			echo "   * HDR to SDR: $chsdr2hdr"
		fi
	fi
	echo "   * Frame rate: $chfps"
	echo "   * Codec: $chvcodec${chpreset}${chtune}${chprofile}"
	echo "   * Bitrate: $vkb"
fi
echo "  Audio stream: $chsoundstream"
if [ "$ENCODA" = "1" ]; then
	echo "   * Codec: $chacodec"
	echo "   * Bitrate: $akb"
	echo "   * Channels: $rpchannel"
fi
echo "  Container: $extcont"
echo "  Streams map: $vstream"
Echo_Separator_Light
}

## DISPLAY TRICK
Display_Remove_Previous_Line() {		# Remove last line displayed
printf '\e[A\e[K'
}
Display_Line_Truncate() {				# Line width truncate
local label
label="$*"

if [[ "${#label}" -gt "$TERM_WIDTH_TRUNC" ]]; then
	echo "$label" | cut -c 1-"$TERM_WIDTH_TRUNC" | awk '{print $0"..."}'
else
	echo "$label"
fi
}
Display_List_Truncate() {				# List width truncate
local line
local list
list=("$@")

for line in "${list[@]}"; do

	if [[ "${#line}" -gt "$TERM_WIDTH_TRUNC" ]]; then
		echo "  $line" | cut -c 1-"$TERM_WIDTH_TRUNC" | awk '{print $0"..."}'
	else
		echo "  $line"
	fi

done
}
Display_Line_Progress_Truncate() {		# Line width truncate in progress
local label
label="$*"

if [[ "${#label}" -gt "$TERM_WIDTH_PROGRESS_TRUNC" ]]; then
	echo "$label" | cut -c 1-"$TERM_WIDTH_PROGRESS_TRUNC" | awk '{print $0"..."}'
else
	echo "$label"
fi
}
Display_Term_Size() {					# Get terminal size
TERM_WIDTH=$(stty size | awk '{print $2}')													# Get terminal width
TERM_WIDTH_TRUNC=$(stty size | awk '{print $2}' | awk '{ print $1 - 8 }')					# Get terminal width truncate
TERM_WIDTH_PROGRESS_TRUNC=$(stty size | awk '{print $2}' | awk '{ print $1 - 32 }')			# Get terminal width truncate
}
Display_Variable_Trick() {				# Punctuation trick
local variable
local display_mode
local unit
variable="$1"
display_mode="$2"
unit="$3"

if [[ -n "$variable" ]]; then

	if [[ -n "$unit" ]]; then
		unit=" $unit"
	fi

	# 0 = ",  ,"
	if [[ "$display_mode" = "0" ]]; then
		echo ", ${variable}${unit},"

	# 1 = ","
	elif [[ "$display_mode" = "1" ]]; then
		echo "${variable}${unit},"

	# 2 = "()"
	elif [[ "$display_mode" = "2" ]]; then
		echo "(${variable}${unit})"

	# 3 = "(),"
	elif [[ "$display_mode" = "3" ]]; then
		echo "(${variable}${unit}),"

	# 4 = "( ,"
	elif [[ "$display_mode" = "4" ]]; then
		echo "(${variable}${unit},"

	# 5 = "),"
	elif [[ "$display_mode" = "5" ]]; then
		echo "${variable}${unit}),"

	# 6 = ":"
	elif [[ "$display_mode" = "6" ]]; then
		echo "${variable}${unit}):"

	# 7 = " - "
	elif [[ "$display_mode" = "7" ]]; then
		echo " - ${variable}${unit}"
	else
		echo "${variable}"

	fi

fi
}

## CALCULATION FUNCTIONS
Calc_Table_width() {					# Table display, field width calculation
local string_length
local string_length_calc
string_length=("$@")

for string in "${string_length[@]}"; do

	if [ -z "$string_length_calc" ]; then
		string_length_calc="${#string}"
	fi

	if [[ "$string_length_calc" -lt "${#string}" ]]; then
		string_length_calc="${#string}"
	fi

done

echo "$string_length_calc"
}
Calc_Files_Size() {						# Total size calculation in MB
local files
local size
local size_in_mb
files=("$@")

if (( "${#files[@]}" )); then
	# Get size in bytes
	size=$(wc -c "${files[@]}" | tail -1 | awk '{print $1;}')
	# MB convert
	size_in_mb=$(bc <<< "scale=1; $size / 1024 / 1024" | sed 's!\.0*$!!')
else
	size_in_mb="0"
fi

# If string start by "." add lead 0
if [[ "${size_in_mb:0:1}" == "." ]]; then
	echo "0$size_in_mb"
else
	echo "$size_in_mb"
fi
}
Calc_Percent() {						# Percentage calculation
local total
local value
local perc

value="$1"
total="$2"

if [[ "$value" = "$total" ]]; then
	echo "0"
else
	perc=$(bc <<< "scale=4; ($total - $value)/$value * 100" | sed 's!\0*$!!')

	# If string start by "." or "-." add lead 0
	if [[ "${perc:0:1}" == "." ]] || [[ "${perc:0:2}" == "-." ]]; then

		if [[ "${perc:0:2}" == "-." ]]; then
			echo "${perc/-./-0.}"
		else
			echo "0$perc"
		fi

	else
		echo "$perc"
	fi
fi
}
Calc_Elapsed_Time() {					# Elapsed time formated
local start_in_s
local stop_in_s
local diff_in_s

start_in_s="$1"
stop_in_s="$2"

# Diff in second
diff_in_s=$(( stop_in_s - start_in_s ))

Elapsed_Time_formated="$((diff_in_s/3600))h$((diff_in_s%3600/60))m$((diff_in_s%60))s"
}
Calc_Time_s_2_hms() {
local second
second="$1"

if [[ "$second" == *"."* ]]; then
	second="$(echo "$second" | awk -F"." '{ print $1 }')"
fi

printf '%02d:%02d:%02d\n' $((second/3600)) $((second%3600/60)) $((second%60))
}
Calc_Video_Resolution() {				# Option 1  	- Conf/Calc change Resolution 
# Local variables
local RATIO
local WIDTH
local HEIGHT

WIDTH="$1"
for (( i=0; i<=$(( ${#ffprobe_StreamIndex[@]} - 1 )); i++ )); do
	if [[ "${ffprobe_StreamType[$i]}" = "video" ]]; then
		if [[ "${ffprobe_AttachedPic[$i]}" != "attached pic" ]]; then
			source_width="${ffprobe_Width[i]}"
			source_heigh="${ffprobe_Height[i]}"
		fi
	fi
done

# Ratio calculation
RATIO=$(bc -l <<< "${source_width} / $WIDTH")

# Height calculation, display decimal only if not integer
HEIGHT=$(bc -l <<< "${source_heigh} / $RATIO" | sed 's!\.0*$!!')

# Increment filter counter
nbvfilter=$((nbvfilter+1))
# Scale filter
if ! [[ "$HEIGHT" =~ ^[0-9]+$ ]] ; then			# In not integer
	if [ "$nbvfilter" -gt 1 ] ; then
		if [[ "$codec" = "hevc_vaapi" ]]; then
			vfilter+=",scale_vaapi=w=$WIDTH:h=-2"
		else
			vfilter+=",scale=$WIDTH:-2"
		fi
	else
		vfilter="-vf scale=$WIDTH:-2"
	fi
else
	if [ "$nbvfilter" -gt 1 ] ; then
		if [[ "$codec" = "hevc_vaapi" ]]; then
			vfilter+=",scale_vaapi=w=$WIDTH:h=-1"
		else
			vfilter+=",scale=$WIDTH:-1"
		fi
	else
		vfilter="-vf scale=$WIDTH:-1"
	fi
fi
# Displayed width x height
chwidth="${WIDTH}x${HEIGHT%.*}"
}

## JSON PARSING
jqparse_stream() {
local index
local value
index="$1"
value="$2"

jq -r ".streams[] | select(.index==$1) | .$2" "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null | sed s#null##g
}
jqparse_tag() {
local index
local value
index="$1"
value="$2"

jq -r ".streams[] | select(.index==$1) | .tags | .$2" "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null | sed s#null##g
}
jqparse_disposition() {
local index
local value
local test
index="$1"
value="$2"

test=$(jq -r ".streams[] | select(.index==$1) | .disposition.$2" "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null | sed s#null##g)
if [[ "$value" = "default" ]] && [[ "$test" = "1" ]]; then
	echo "default"
elif [[ "$value" = "forced" ]] && [[ "$test" = "1" ]]; then
	echo "forced"
elif [[ "$value" = "attached_pic" ]] && [[ "$test" = "1" ]]; then
	echo "attached pic"
else
	echo ""
fi
}
jqparse_format() {
local value
value="$1"

jq -r ".format | .$1" "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null | sed s#null##g
}

## IN SCRIPT VARIOUS FUNCTIONS
Restart() {								# Restart script & for keep argument
Clean
if [ -n "$ARGUMENT" ]; then									# If target is file
	bash "$FFMES_PATH"/"$FFMES_BIN" -i "$ARGUMENT" && exit
else
	bash "$FFMES_PATH"/"$FFMES_BIN" && exit
fi
}
TrapStop() {							# Ctrl+z Trap for loop exit
EnterKeyEnable
Clean
kill -s SIGTERM $!
}
TrapExit() {							# Ctrl+c Trap for script exit
EnterKeyEnable
Clean
echo
echo
exit
}
EnterKeyDisable() {						# Disable the enter key
if [[ -z "$VERBOSE" ]]; then
	stty igncr
fi
}
EnterKeyEnable() {						# Enable the enter key
if [[ -z "$VERBOSE" ]]; then
	stty -igncr
fi
}
Clean() {								# Clean Temp
# files
find "$FFMES_CACHE/" -type f -mtime +3 -exec /bin/rm -f {} \;			# consider if file exist in cache directory after 3 days, delete it
rm "$FFMES_FFPROBE_CACHE_STATS" &>/dev/null
rm "$FFMES_FFMPEG_CACHE_STAT" &>/dev/null
rm "$FFMES_CACHE_INTEGRITY" &>/dev/null
rm "$FFMES_CACHE_UNTAGGED" &>/dev/null
rm "$FFMES_CACHE_TAG" &>/dev/null
rm "$LSDVD_CACHE" &>/dev/null
rm "$FFMES_FFMPEG_PROGRESS" &>/dev/null
}
ffmesUpdate() {							# Option 99  	- ffmes update to lastest version (hidden option)
curl https://raw.githubusercontent.com/Jocker666z/ffmes/master/ffmes.sh > /home/"$USER"/.local/bin/ffmes && chmod +rx /home/"$USER"/.local/bin/ffmes
Restart
}
TestVAAPI() {							# VAAPI device test
if [ -e "$VAAPI_device" ]; then
	if "$ffmpeg_bin" -init_hw_device vaapi=foo:"$VAAPI_device" -h 2> /dev/null; then
		GPUDECODE="-vaapi_device $VAAPI_device"
	else
		GPUDECODE=""
	fi
fi
}
TestHDR(){
# HDR double check
if test -n "$mediainfo_HDR"; then
	HDR="1"
else
	for (( i=0; i<=$(( ${#ffprobe_StreamIndex[@]} - 1 )); i++ )); do
		if [ "${ffprobe_ColorSpace[$i]}" = "bt2020nc" ] \
		&& [ "${ffprobe_ColorTransfert[$i]}" = "smpte2084" ] \
		&& [ "${ffprobe_ColorPrimaries[$i]}" = "bt2020" ]; then 
				HDR="1"
		fi
	done
fi
}
Remove_File_Source() {					# Remove source, question+action
if [ "${#filesPass[@]}" -gt 0 ] ; then
	read -r -p " Remove source files? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			# Remove source files
			for f in "${filesSourcePass[@]}"; do
				rm -f "$f" 2>/dev/null
			done
			if [[ "$ffmes_option" -ge 20 ]]; then
				# Remove m3u
				if [ "$RemoveM3U" = "1" ]; then
					for f in "${LSTM3U[@]}"; do
						rm -f "$f" 2>/dev/null
					done
				fi
			fi
			echo
		;;
		*)
			SourceNotRemoved="1"
		;;
	esac
fi
}
Remove_File_Target() {					# Remove target, question+action
if [ "$SourceNotRemoved" = "1" ] ; then
	read -r -p " Remove target files? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			# Remove source files
			for f in "${filesPass[@]}"; do
				rm -f "$f" 2>/dev/null
			done
			# Rename if extention same as source
			for (( i=0; i<=$(( ${#filesInLoop[@]} -1 )); i++ )); do
				if [[ "${filesInLoop[i]%.*}" = "${filesOverwrite[i]%.*}" ]]; then										# If file overwrite
					mv "${filesInLoop[i]%.*}".back.$extcont "${filesInLoop[i]}" 2>/dev/null
				fi
			done
			echo
		;;
		*)
			Restart
		;;
	esac
fi
}
Test_Target_File() {
# Local variables
local source_files
local duration_type
local media_type
local duration

# Array
filesPass=()
filesReject=()
filesSourcePass=()
source_files=()

# Arguments
# duration_type = 1 = full duration test
# remove_fail = 1 = not remove fail test
duration_type="$1"
media_type="$2"
shift 2
source_files=("$@")

if [[ "$duration_type" != "1" ]]; then
	duration="-t 1"
fi

if (( "${#source_files[@]}" )); then

	Echo_Separator_Light
	for (( i=0; i<=$(( ${#source_files[@]} - 1 )); i++ )); do
		if [[ "${source_files[$i]##*.}" =~ ${VIDEO_EXT_AVAILABLE[*]} ]] \
		|| [[ "${source_files[$i]##*.}" =~ ${AUDIO_EXT_AVAILABLE[*]} ]]; then

			if ! "$ffmpeg_bin" -v error $duration -i "${source_files[$i]}" -max_muxing_queue_size 9999 -f null - &>/dev/null; then
				filesReject+=( "${source_files[$i]}" )
				rm "${source_files[$i]}" 2>/dev/null
			else
				# If mkv regenerate stats
				if [ "${source_files[$i]##*.}" = "mkv" ]; then
					mkvpropedit --add-track-statistics-tags "${source_files[$i]}" >/dev/null 2>&1
				fi
				filesPass+=("${source_files[$i]}")
				if [[ "$media_type" = "video" ]];then
					filesSourcePass+=( "${LSTVIDEO[$i]}" )
				elif [[ "$media_type" = "audio" ]];then
					filesSourcePass+=( "${LSTAUDIO[$i]}" )
				fi
			fi

		else
			filesPass+=("${source_files[$i]}")
		fi

		ProgressBar "" "$((i+1))" "${#source_files[@]}" "Validation" "1"
	done

fi
}

## LOADING & PROGRESS BAR
Loading() {								# Loading animation
if [[ -z "$VERBOSE" ]]; then
	local CL="\e[2K"
	local delay=0.10
	local spinstr="▉▉░"
	case $1 in
		start)
			while :
			do
				local temp=${spinstr#?}
				printf "${CL}$spinstr ${task}\r"
				local spinstr=$temp${spinstr%"$temp"}
				sleep $delay
				printf "\b\b\b\b\b\b"
			done
			printf "    \b\b\b\b"
			printf "${CL} ✓ ${task} ${msg}\n"
			;;
		stop)
			kill "$_sp_pid" > /dev/null 2>&1
			printf "${CL} ✓ ${task} ${msg}\n"
			;;
	esac
fi
}
StartLoading() {						# Start loading animation
if [[ -z "$VERBOSE" ]]; then
	task=$1
	Ltask="${#task}"
	if [ "$Ltask" -gt "$TERM_WIDTH_TRUNC" ]; then
		task=$(echo "${task:0:$TERM_WIDTH_TRUNC}" | awk '{print $0"..."}')
	fi
	msg=$2
	Lmsg="${#2}"
	if [ "$Lmsg" -gt "$TERM_WIDTH_TRUNC" ]; then
		msg=$(echo "${msg:0:$TERM_WIDTH_TRUNC}" | awk '{print $0"..."}')
	fi
	# $1 : msg to display
	tput civis		# hide cursor
	Loading "start" "${task}" &
	# set global spinner pid
	_sp_pid=$!
	disown
fi
}
StopLoading() {							# Stop loading animation
if [[ -z "$VERBOSE" ]]; then
	# $1 : command exit status
	tput cnorm		# normal cursor
	Loading "stop" "${task}" "${msg}" $_sp_pid
	unset _sp_pid
fi
}
ProgressBar() {							# Progress bar
# Arguments: ProgressBar "current source file" "number current" "number total" "label" "force mode"

# Local variables
local loop_pass
local sourcefile
local TotalFilesNB
local CurrentFilesNB
local TimeOut
local start_TimeOut
local interval_TimeOut
local interval_calc
local TotalDuration
local CurrentState
local CurrentDuration
local Currentfps
local Currentbitrate
local CurrentSize
local Current_Frame
local CurrentfpsETA
local Current_Remaining
local Current_ETA
local ProgressTitle
local _progress
local _done
local _done
local _left

# arguments
sourcefile=$(Display_Line_Progress_Truncate "${1##*/}")
CurrentFilesNB="$2"
TotalFilesNB="$3"
ProgressTitle="$4"
if [[ -n "$5" ]]; then
	ProgressBarOption="$5"
else
	unset ProgressBarOption
fi

# Reset loop pass
unset loop_pass

# ffmpeg detailed progress bar
if [[ -z "$VERBOSE" && "${#LSTVIDEO[@]}" = "1" && -z "$ProgressBarOption" && "$ffmes_option" -lt "20" ]] \
|| [[ -z "$VERBOSE" && -n "$RipFileName" && -z "$ProgressBarOption" ]] \
|| [[ -z "$VERBOSE" && "${#LSTAUDIO[@]}" = "1" && -z "$ProgressBarOption" && "$ffmes_option" -ge "20" ]] \
|| [[ -z "$VERBOSE" && "${#LSTVIDEO[@]}" -gt "1" && "$NVENC" = "0" && -z "$ProgressBarOption" && "$ffmes_option" -lt "20" ]] \
|| [[ -z "$VERBOSE" && "${#LSTAUDIO[@]}" -gt "1" && "$NPROC" = "0" && -z "$ProgressBarOption" && "$ffmes_option" -ge "20" ]]; then

	# Start value of bar
	_progress="0"
	_left="40"
	_left=$(printf "%${_left}s")

	# Standby "$FFMES_FFMPEG_PROGRESS"
	# Time out in ms
	TimeOut="2000"
	# Start time counter
	start_TimeOut=$(( $(date +%s%N) / 1000000 ))
	while [ ! -f "$FFMES_FFMPEG_PROGRESS" ] && [ ! -s "$FFMES_FFMPEG_PROGRESS" ]; do
		sleep 0.1

		# Time out counter
		interval_TimeOut=$(( $(date +%s%N) / 1000000 ))
		interval_calc=$(( interval_TimeOut - start_TimeOut ))

		# Time out fail break
		if [[ "$interval_calc" -gt "$TimeOut" ]]; then
			echo -e -n "\r\e[0K ]${_done// /▇}${_left// / }[ ${_progress}% - [!] ffmpeg fail"
			break
		fi
	done

	# Duration - in second
	TotalDuration=$(echo "$ffprobe_Duration" | awk -F"." '{ print $1 }')

	# Title display
	echo "  [${sourcefile}]"

	# Progress bar loop
	# Start time counter
	TimeOut="30000"
	start_TimeOut=$(( $(date +%s%N) / 1000000 ))
	while true; do

		# Get main value
		CurrentState=$(tail -n 12 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null | grep "progress" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }')
		CurrentDuration=$(tail -n 12 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null | grep "out_time_ms" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }')
		CurrentDuration=$(( CurrentDuration/1000000 ))

		# Get extra value
		Currentfps=$(tail -n 12 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null | grep "fps" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }')
		Currentbitrate=$(tail -n 12 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null | grep "bitrate" 2>/dev/null | tail -1 \
						| awk -F"=" '{ print $2 }' | awk -F"." '{ print $1 }')
		CurrentSize=$(tail -n 12 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null | grep "total_size" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }' \
						| awk '{ foo = $1 / 1024 / 1024 ; print foo }')

		# ETA - If ffprobe_fps[0] active consider video, if not consider audio
		if [[ -n "${ffprobe_fps[0]}" ]]; then
			Current_Frame=$(tail -n 12 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null | grep "frame=" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }')
			if [[ "$Currentfps" = "0.00" ]] || [[ -z "$Currentfps" ]];then
				CurrentfpsETA="0.01"
			else
				CurrentfpsETA="$Currentfps"
			fi
			if [[ -z "$Current_Frame" ]];then
				Current_Frame="1"
			fi
			Current_Remaining=$(bc <<< "scale=0; ; ( ($ffprobe_TotalFrames - $Current_Frame) / $CurrentfpsETA)")
			Current_ETA="ETA: $((Current_Remaining/3600))h$((Current_Remaining%3600/60))m$((Current_Remaining%60))s"
		else
			Current_ETA=$(tail -n 12 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null | grep "speed" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }')
		fi

		# Displayed label
		if [[ -n "${Currentbitrate}" ]]; then
			ExtendLabel=$(echo "$(Display_Variable_Trick "${Current_ETA}" "7")\
						$(Display_Variable_Trick "${Currentfps}" "7" "fps")\
						$(Display_Variable_Trick "${Currentbitrate}" "7" "kb/s")\
						$(Display_Variable_Trick "${CurrentSize}" "7" "MB")" \
						| awk '{$2=$2};1' | awk '{print "  " $0}' | tr '\n' ' ')
		else
			Current_ETA="IDLE: $(bc <<< "scale=0; ; ( $interval_calc / 1000)")/$(bc <<< "scale=0; ; ( $TimeOut / 1000)")s"
			ExtendLabel=$(echo "$(Display_Variable_Trick "${Current_ETA}" "7")\
						$(Display_Variable_Trick "${Currentfps}" "7" "fps")\
						$(Display_Variable_Trick "${Currentbitrate}" "7" "kb/s")\
						$(Display_Variable_Trick "${CurrentSize}" "7" "MB")" \
						| awk '{$2=$2};1' | awk '{print "  " $0}' | tr '\n' ' ')
		fi

		# Display variables
		if [[ "$CurrentState" = "end" ]]; then
			_progress="100"
		else
			_progress=$(( ( ((CurrentDuration * 100) / TotalDuration) * 100 ) / 100 ))
		fi
		_done=$(( (_progress * 4) / 10 ))
		_left=$(( 40 - _done ))
		_done=$(printf "%${_done}s")
		_left=$(printf "%${_left}s")

		# Progress bar display
		if [[ "$_progress" -le "100" ]]; then
			echo -e -n "\r\e[0K ]${_done// /▇}${_left// / }[ ${_progress}% $ExtendLabel"
		fi

		# Pass break condition
		if [[ "$_progress" = "100" ]]; then
			# Loop pass
			loop_pass="1"
			echo
			break
		fi

		### Fail break condition
		# Time out counter
		interval_TimeOut=$(( $(date +%s%N) / 1000000 ))
		interval_calc=$(( interval_TimeOut - start_TimeOut ))
		# Time out fail break
		if [[ "$interval_calc" -gt "$TimeOut" && -z "$CurrentSize" ]]; then
			# Loop fail
			loop_pass="1"
			echo -e -n "\r\e[0K ]${_done// /▇}${_left// / }[ ${_progress}% - [!] ffmpeg fail"
			echo
			break
		fi
		# Other break
		if [[ ! -f "$FFMES_FFMPEG_PROGRESS" && "$_progress" != "100" && "$CurrentState" != "end" ]]; then
			# Loop fail
			loop_pass="1"
			echo -e -n "\r\e[0K ]${_done// /▇}${_left// / }[ ${_progress}% - [!] ffmpeg fail"
			echo
			break
		fi

		# Refresh rate
		sleep 0.3

	done

# Multi. files progress bar
elif [[ -z "$VERBOSE" ]] && [[ -z "$loop_pass" ]]; then

	# Display variables
	_progress=$(( ( ((CurrentFilesNB * 100) / TotalFilesNB) * 100 ) / 100 ))
	_done=$(( (_progress * 4) / 10 ))
	_left=$(( 40 - _done ))
	_done=$(printf "%${_done}s")
	_left=$(printf "%${_left}s")
	ExtendLabel=$(echo "$(Display_Variable_Trick "${CurrentFilesNB}/${TotalFilesNB}" "7")\
				$(Display_Variable_Trick "${ProgressTitle}" "7")" \
				| awk '{$2=$2};1' | awk '{print "  " $0}' | tr '\n' ' ')

	# Progress bar display
	echo -e -n "\r\e[0K ]${_done// /▇}${_left// / }[ ${_progress}% $ExtendLabel"
	if [[ "$_progress" = "100" ]]; then
		echo
	fi

fi
}

## DVD
DVDRip() {								# Option 0  	- DVD Rip
# Local variables
local DVD
local DVDINFO
local DVDtitle
local TitleParsed
local AspectRatio
local PCM
local pcm_dvd
local VIDEO_EXT_AVAILABLE
local qtitle

# Local Array
qtitle=()

clear
echo
echo " DVD rip"
echo " notes: * for DVD, launch ffmes in directory without ISO & VOB, if you have more than one drive, insert only one DVD."
echo "        * for ISO, launch ffmes in directory with ISO (without VOB)"
echo "        * for VOB, launch ffmes in directory with VOB (in VIDEO_TS/)"
echo
Echo_Separator_Light
while :
do
read -r -p " Continue? [Y/n]:" q
case $q in
		"N"|"n")
			Restart
		;;
		*)
			break
		;;
esac
done

# Assign input
if [ "${#LSTVOB[@]}" -ge "1" ]; then
	DVD="./"
elif [ "${#LSTISO[@]}" -eq "1" ]; then
	DVD="${LSTISO[0]}"
else
	while true; do
		DVDINFO=$(setcd -i "$DVD_DEVICE" 2>/dev/null)
		case "$DVDINFO" in
			*'Disc found'*)
				DVD="$DVD_DEVICE"
				break
				;;
			*'not ready'*)
				echo " Please waiting drive not ready"
				sleep 3
				;;
			*)
				echo " No DVD in drive, ffmes restart"
				sleep 3
				Restart
		esac
	done
fi

# Test ISO & DVD is valid DVD Video
lsdvd "$DVD" &>/dev/null
local lsdvd_result=$?
if ! [ "$lsdvd_result" -eq 0 ]; then
	echo
	Echo_Mess_Error "$DVD is not valid DVD video"
	echo
	exit
fi

# Grep stat
lsdvd -a -s "$DVD" 2>/dev/null | awk -F', AP:' '{print $1}' | awk -F', Subpictures' '{print $1}' \
	| awk ' {gsub("Quantization: drc, ","");print}' | sed 's/^/    /' > "$LSDVD_CACHE"
DVDtitle=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null | grep "DVD with title" | tail -1 | awk -F'"' '{print $2}')
# Extract all title
mapfile -t DVD_TITLES < <(lsdvd "$DVD" 2>/dev/null | grep Title | awk '{print $2}' |  grep -o '[[:digit:]]*')

# Question
echo
if [ "${#LSTVOB[@]}" -ge "1" ]; then
	echo " ${#LSTVIDEO[@]} VOB file(s) are been detected, choice one or more title to rip:"
else
	echo " $DVDtitle DVD video have been detected, choice one or more title to rip:"
fi
echo
cat "$LSDVD_CACHE"
echo
echo " [02 13] > Example of input format for select title 02 and 13"
echo " [all]   > for rip all titles"
echo " [q]     > for exit"
while true; do
	read -r -e -p "-> " qtitlerep
	case "$qtitlerep" in
		[0-9]*)
			IFS=" " read -r -a qtitle <<< "$qtitlerep"
			break
		;;
		"all")
			qtitle=( "${DVD_TITLES[@]}" )
			break
		;;
		"q"|"Q")
			Display_Main_Menu
			break
		;;
		*)
			Echo_Mess_Invalid_Answer
		;;
	esac
done 

# DVD Title question
if [[ -z "$DVDtitle" ]]; then
	while true; do
		read -r -e -p "  What is the name of the DVD?: " qdvd
		case $qdvd in
			"")
				Echo_Mess_Invalid_Answer
			;;
			*)
				DVDtitle="$qdvd"
				break
			;;
		esac
	done
fi

for title in "${qtitle[@]}"; do
	RipFileName=$(echo "${DVDtitle}-${title}")

	# Get aspect ratio
	TitleParsed="${title##*0}"
	AspectRatio=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null \
					| grep "The aspect ratio of title set $TitleParsed" | tail -1 | awk '{print $NF}')
	# If aspect ratio empty, get main feature aspect
	if test -z "$AspectRatio"; then
		AspectRatio=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null \
						| grep "The aspect ratio of the main feature is" | tail -1 | awk '{print $NF}')
	fi

	# Extract chapters
	Echo_Separator_Light
	echo " Extract chapters - $DVDtitle - title $title"
	dvdxchap -t "$title" "$DVD" > "$RipFileName".chapters 2>/dev/null

	# Extract vob
	Echo_Separator_Light
	echo " Extract VOB - $DVDtitle - title $title"
	dvdbackup -p -t "$title" -i "$DVD" -n "$RipFileName" 2>/dev/null

	# Populate array with VOB
	Echo_Separator_Light
	mapfile -t LSTVOB < <(find ./"$RipFileName" -maxdepth 3 -type f -regextype posix-egrep -iregex '.*\.('$VOB_EXT_AVAILABLE')$' 2>/dev/null \
		| sort | sed 's/^..//')

	# Concatenate
	echo " Concatenate VOB - $DVDtitle - title $title"
	cat -- "${LSTVOB[@]}" | pv -p -t -e -r -b > "$RipFileName".VOB

	# Remove data stream, fix DAR, add chapters, and change container
	Echo_Separator_Light
	echo " Make clean mkv - $DVDtitle - title $title"
	# Fix pcm_dvd is present
	PCM=$("$ffprobe_bin" -analyzeduration 1G -probesize 1G -v error -show_entries stream=codec_name -print_format csv=p=0 "$RipFileName".VOB \
			| grep pcm_dvd)
	# pcm_dvd audio track trick
	if test -n "$PCM"; then
		pcm_dvd="-c:a pcm_s16le"
	fi
	# FFmpeg - clean mkv
	Media_Source_Info_Record "${RipFileName}.VOB"
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -fflags +genpts+igndts -analyzeduration 1G -probesize 1G -i "$RipFileName".VOB \
		$FFMPEG_PROGRESS \
		-map 0:v -map 0:a? -map 0:s? -c copy $pcm_dvd -aspect $AspectRatio "$RipFileName".mkv \
		| ProgressBar "${RipFileName}.mkv" "" "" ""

	# mkvmerge - add chapters
	Echo_Separator_Light
	echo " Add chapters - $DVDtitle - title $title"
	mkvmerge "$RipFileName".mkv --chapters "$RipFileName".chapters -o "$RipFileName"-chapters.mkv 2>/dev/null

	# Clean 1
	if [[ $(stat --printf="%s" "$RipFileName"-chapters.mkv 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
		rm "$RipFileName".mkv 2>/dev/null
		mv "$RipFileName"-chapters.mkv "$RipFileName".mkv 2>/dev/null
		rm "$RipFileName".chapters 2>/dev/null
	else																			# if file<30 KBytes rejected
		echo "X mkvmerge pass of DVD Rip fail"
		rm "$RipFileName".chapters 2>/dev/null
	fi

	# Check Target if valid (size test) and clean 2
	if [[ $(stat --printf="%s" "$RipFileName".mkv 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
		rm -f "$RipFileName".VOB 2> /dev/null
		rm -R -f "$RipFileName" 2> /dev/null
	else																			# if file<30 KBytes rejected
		echo "X FFmpeg pass of DVD Rip fail"
		rm -R -f "$RipFileName".mkv 2> /dev/null
	fi
done

# map
unset TESTARGUMENT
VIDEO_EXT_AVAILABLE="mkv"
mapfile -t LSTVIDEO < <(find . -maxdepth 1 -type f -regextype posix-egrep -regex '.*\.('$VIDEO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

# encoding question
if [ "${#LSTVIDEO[@]}" -gt "0" ]; then
	Echo_Separator_Light
	echo
	echo " ${#LSTVIDEO[@]} file(s) detected:"
	printf '  %s\n' "${LSTVIDEO[@]}"
	echo
	read -r -p " Would you like encode it? [y/N]:" q
	case $q in
		"Y"|"y")
			Media_Source_Info_Record "${LSTVIDEO[@]}"
		;;
		*)
			Restart
		;;
	esac
else
	echo
	exit
fi
}
DVDSubColor() {							# Option 17 	- Change color of DVD sub
# Local variables
local palette

clear
echo
echo " Files to change colors:"
printf '  %s\n' "${LSTSUB[@]}"
echo
echo " Select color palette:"
echo
echo "  [0] > white font / black border"
echo "  [1] > black font / white border"
echo "  [2] > yellow font / black border"
echo "  [3] > yellow font / white border"
echo "  [q] > for exit"
while :
do
read -r -e -p "-> " rpspalette
case $rpspalette in

	"0")
		for files in "${LSTSUB[@]}"; do
			palette="white font & black border"
			StartLoading "" "$files color palette change to $palette"
			sed -i '/palette:/c\palette: ffffff, ffffff, 000000, ffffff, ffffff, ffffff, ffffff, ffffff, ffffff, ffffff, ffffff, ffffff, ffffff, ffffff, ffffff, ffffff' "$files"
			StopLoading $?
		done
		echo
		break
	;;
	"1")
		for files in "${LSTSUB[@]}"; do
			palette="black font & white border"
			StartLoading "" "$files color palette change to $palette"
			sed -i '/palette:/c\palette: 000000, 000000, ffffff, 000000, 000000, 000000, 000000, 000000, 000000, 000000, 000000, 000000, 000000, 000000, 000000, 000000' "$files"
			StopLoading $?
		done
		echo
		break
	;;
	"2")
		for files in "${LSTSUB[@]}"; do # fffd00
			palette="yellow font & black border"
			StartLoading "" "$files color palette change to $palette"
			sed -i '/palette:/c\palette: fffd00, fffd00, 000000, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00' "$files"
			StopLoading $?
		done
		echo
		break
	;;
	"3")
		for files in "${LSTSUB[@]}"; do # fffd00
			palette="yellow font & white border"
			StartLoading "" "$files color palette change to $palette"
			sed -i '/palette:/c\palette: fffd00, fffd00, ffffff, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00, fffd00' "$files"
			StopLoading $?
		done
		echo
		break
	;;
	"q"|"Q")
		Restart
		break
	;;
		*)
			echo
			Echo_Mess_Invalid_Answer
			echo
		;;
esac
done 
}
DVDSub2Srt() {							# Option 18 	- DVD sub to srt
# Local variables
local rpspalette
local SubLang
local Tesseract_Arg
local COUNTER
local TIFF_NB
local TOTAL

clear
echo
echo " Select subtitle language for:"
printf '  %s\n' "${LSTSUB[@]}"
echo
echo "   [0] > eng     - english"
echo "   [1] > fra     - french"
echo "   [2] > deu     - deutsch"
echo "   [3] > spa     - spanish"
echo "   [4] > por     - portuguese"
echo "   [5] > ita     - italian"
echo "   [6] > jpn     - japanese"
echo "   [7] > chi-sim - chinese simplified"
echo "   [8] > ara     - arabic"
echo "   [9] > kor     - korean"
echo "  [10] > rus     - russian"
echo "   [q] > for exit"
while :
do
read -r -e -p "-> " rpspalette
case $rpspalette in

	"0")
		SubLang="eng"
		break
	;;
	"1")
		SubLang="fra"
		break
	;;
	"2")
		SubLang="deu"
		break
	;;
	"3")
		SubLang="spa"
		break
	;;
	"4")
		SubLang="por"
		break
	;;
	"5")
		SubLang="ita"
		break
	;;
	"6")
		SubLang="jpn"
		break
	;;
	"7")
		SubLang="chi-sim"
		break
	;;
	"8")
		SubLang="ara"
		break
	;;
	"9")
		SubLang="kor"
		break
	;;
	"10")
		SubLang="rus"
		break
	;;
	"q"|"Q")
		Restart
	;;
		*)
			echo
			Echo_Mess_Invalid_Answer
			echo
		;;
esac
done 

echo
echo " Select Tesseract engine:"
echo
echo "  [0] > fast     - By recognizing character patterns"
echo " *[1] > reliable - By neural net (LSTM)"
echo "  [q] > for exit"
while :
do
read -r -e -p "-> " rpspalette
case $rpspalette in

	"0")
		Tesseract_Arg="--oem 0 --tessdata-dir $FFMES_PATH/tesseract"
		if [ ! -f "$FFMES_PATH/tesseract/$SubLang.traineddata" ]; then
			if [ ! -d "$FFMES_PATH"/tesseract ]; then
				mkdir "$FFMES_PATH"/tesseract
			fi
			StartLoading "Downloading Tesseract trained models"
			wget https://github.com/tesseract-ocr/tessdata/raw/master/"$SubLang".traineddata -P "$FFMES_PATH"/tesseract &>/dev/null
			StopLoading $?
		fi
		break
	;;
	"1")
		Tesseract_Arg="--oem 1"
		break
	;;
	"q"|"Q")
		Restart
	;;
		*)
		Tesseract_Arg="--oem 1"
		break
		;;
esac
done

# Convert loop
echo
Echo_Separator_Light
for files in "${LSTSUB[@]}"; do

	# Extract tiff
	StartLoading "${files%.*}: Extract tiff files"
	subp2tiff --sid=0 -n "${files%.*}" &>/dev/null
	StopLoading $?

	# Convert tiff in text
	TOTAL=(*.tif)
	for tfiles in *.tif; do
		(
		tesseract $Tesseract_Arg "$tfiles" "$tfiles" -l "$SubLang" &>/dev/null
		) &
		if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
			wait -n
		fi
		# Counter
		TIFF_NB=$(( COUNTER + 1 ))
		COUNTER=$TIFF_NB
		# Progress
		ProgressBar "" "${COUNTER}" "${#TOTAL[@]}" "tif to text files" "1" 
	done
	wait

	StartLoading "${files%.*}: Convert text files in srt"

	# Convert text in srt
	subptools -s -w -t srt -i "${files%.*}".xml -o "${files%.*}".srt &>/dev/null

	# Remove ^L/\f/FF/form-feed/page-break character
	sed -i 's/\o14//g' "${files%.*}".srt &>/dev/null

	StopLoading $?
	echo

	# Clean
	COUNTER=0
	rm -- *.tif &>/dev/null
	rm -- *.txt &>/dev/null
	rm -- *.xml &>/dev/null
done
}

## Blu-ray
BLURAYrip() {
# Local variables
local BD_disk
local BD_title

clear
echo
echo " Blu-ray rip"
echo " notes: * for ISO, launch ffmes in directory with one ISO"
echo "        * for disk directory, launch ffmes in disk directory (must writable)"
echo
Echo_Separator_Light
while :
do
read -r -p " Continue? [Y/n]:" q
case $q in
		"N"|"n")
			Restart
		;;
		*)
			break
		;;
esac
done

# Assign input
if bluray_info "$PWD" &>/dev/null; then
	BD_disk="$PWD"
elif [[ -z "$BD_disk" ]] && [ "${#LSTISO[@]}" -eq "1" ]; then
	BD_disk="${LSTISO[0]}"
else
	echo
	Echo_Mess_Error "No ISO or Blu-Ray directory"
	echo
fi

if [[ -n "$BD_disk" ]]; then
	# Get disk title
	BD_title=$(bluray_info -j "$BD_disk" 2>/dev/null | jq -r '.bluray | ."disc name"')

	# Remux
	bluray_copy "$BD_disk" -o - 2>/dev/null | "$ffmpeg_bin" -hide_banner $GPUDECODE -i - \
				-threads 0 -map 0 -codec copy -ignore_unknown -max_muxing_queue_size 4096 \
				"$BD_title".BD.Remux.mkv \
				&& echo "  $BD_title.BD.Remux.mkv remux done" || Echo_Mess_Error "$BD_title.BD.Remux.mkv remux fail"
fi
}

## VIDEO
Video_FFmpeg_video_cmd() {				# FFmpeg video encoding command
# Local variables
local PERC
local total_source_files_size
local total_target_files_size
local START
local END
# Array
TimestampRegen=()
filesInLoop=()

# Start time counter
START=$(date +%s)

# Disable the enter key
EnterKeyDisable

# Test timestamp
if ! [[ "$ENCODV" = "1" ]]; then
	for (( i=0; i<=$(( ${#LSTVIDEO[@]} - 1 )); i++ )); do
		# Progress
		ProgressBar "" "$((i+1))" "${#LSTVIDEO[@]}" "Test timestamp" "1"

		TimestampTest=$("$ffprobe_bin" -analyzeduration 512M -probesize 512M -loglevel error -select_streams v:0 \
						-show_entries packet=pts_time,flags -of csv=print_section=0 "${LSTVIDEO[i]}" \
						2>/dev/null | awk -F',' '/K/ {print $1}' | tail -1)

		shopt -s nocasematch
		if [[ "${files##*.}" = "vob" || "$TimestampTest" = "N/A" ]]; then
			TimestampRegen+=( "-fflags +genpts" )
		else
			TimestampRegen+=( "" )
		fi
		shopt -u nocasematch

	done
	Echo_Separator_Light
fi

# Encoding
for (( i=0; i<=$(( ${#LSTVIDEO[@]} - 1 )); i++ )); do

	# Target files pass in loop for validation test
	filesInLoop+=( "${LSTVIDEO[i]%.*}.$videoformat.$extcont" )

	# For progress bar
	Media_Source_Info_Record "${LSTVIDEO[i]}"

	(
	"$ffmpeg_bin" $FFMPEG_LOG_LVL ${TimestampRegen[i]} -analyzeduration 1G -probesize 1G $GPUDECODE -y -i "${LSTVIDEO[i]}" \
			$FFMPEG_PROGRESS \
			-threads 0 $vstream $videoconf $soundconf $subtitleconf -max_muxing_queue_size 4096 \
			-f $container "${LSTVIDEO[i]%.*}".$videoformat.$extcont \
			| ProgressBar "${LSTVIDEO[i]}" "$((i+1))" "${#LSTVIDEO[@]}" "Encoding"
	) &
	if [[ $(jobs -r -p | wc -l) -gt $NVENC ]]; then
		wait -n
	fi

done
wait

# Enable the enter key
EnterKeyEnable

# End time counter
END=$(date +%s)

# Check target if valid
Test_Target_File "0" "video" "${filesInLoop[@]}"

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"
total_source_files_size=$(Calc_Files_Size "${filesSourcePass[@]}")
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "${#LSTVIDEO[@]}" "$total_target_files_size" "$total_source_files_size"
}
Video_Custom_Video() {					# Option 1  	- Conf codec video
# Get Stats of source
Display_Video_Custom_Info_choice

# Video stream choice, encoding or copy
echo " Encoding or copying the video stream:"
if [[ "${#LSTVIDEO[@]}" -gt "1" ]]; then
	echo " Note: * The settings made here will be applied to the ${#LSTVIDEO[@]} videos in the batch."
fi
echo
echo "  [e] > for encode"
echo " *[↵] > for copy"
echo "  [q] > for exit"
read -r -e -p "-> " qv
if [ "$qv" = "q" ]; then
	Restart

# Video stream edition
elif [ "$qv" = "e" ]; then

	# Set video encoding
	ENCODV="1"

	# Codec choice
	Display_Video_Custom_Info_choice
	echo " Choice the video codec to use:"
	echo
	echo "  [x264]       > for libx264 codec"
	echo " *[x265]       > for libx265 codec"
	if [[ -n "$VAAPI_device" ]]; then
		echo "  [hevc_vaapi] > for hevc_vaapi codec; GPU encoding"
	fi
	echo "  [av1]        > for libaom-av1 codec"
	echo "  [mpeg4]      > for xvid codec"
	echo "  [q]          > for exit"
	read -r -e -p "-> " yn
	case $yn in
		"x264")
			codec="libx264 -x264-params colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off -pix_fmt yuv420p"
			chvcodec="H264"
			Video_Custom_Video_Filter
			Video_x264_5_Config
		;;
		"x265")
			codec="libx265"
			chvcodec="HEVC"
			Video_Custom_Video_Filter
			Video_x264_5_Config
		;;
		"hevc_vaapi")
			codec="hevc_vaapi"
			chvcodec="HEVC_VAAPI"
			Video_Custom_Video_Filter
			Video_hevc_vaapi_Config
		;;
		"av1")
			codec="libaom-av1"
			chvcodec="AV1"
			Video_Custom_Video_Filter
			Video_av1_Config
		;;
		"mpeg4")
			codec="mpeg4 -vtag xvid"
			chvcodec="XVID"
			Video_Custom_Video_Filter
			Video_MPEG4_Config
		;;
		"q"|"Q")
			Restart
		;;
		*)
			codec="libx265"
			chvcodec="HEVC"
			Video_Custom_Video_Filter
			Video_x264_5_Config
		;;
	esac

# No video change
else
	# Set video configuration variable
	chvidstream="Copy"
	filevcodec="vcopy"
	codec="copy"

fi

# Set video configuration variable
vcodec="$codec"
filevcodec="$chvcodec"
videoconf="$framerate $vfilter -c:v $vcodec $preset $profile $tune $vkb"
}
Video_Custom_Video_Filter() {			# Option 1  	- Conf filter video
# Local variables
local nbvfilter

if [[ "$codec" = "hevc_vaapi" ]]; then

	# VAAPI filter
	nbvfilter=$((nbvfilter+1))
	vfilter="-vf format=nv12,hwupload"

fi

# Desinterlace
Display_Video_Custom_Info_choice
if [ "$mediainfo_Interlaced" = "Interlaced" ]; then
	echo " Video SEEMS interlaced, you want deinterlace:"
else
	echo " Video not seems interlaced, you want force deinterlace:"
fi
echo " Note: the detection is not 100% reliable, a visual check of the video will guarantee it."
echo
echo "  [y] > for yes "
echo " *[↵] > for no change"
echo "  [q] > for exit"
read -r -e -p "-> " yn
case $yn in
	"y"|"Y")
		nbvfilter=$((nbvfilter+1))
		chdes="Yes"
		if [ "$nbvfilter" -gt 1 ] ; then
			if [[ "$codec" = "hevc_vaapi" ]]; then
				vfilter+=",deinterlace_vaapi"
			else
				vfilter+=",yadif"
			fi
		else
			vfilter="-vf yadif"
		fi
	;;
	"q"|"Q")
		Restart
	;;
	*)
		chdes="No change"
	;;
esac

# Resolution
Display_Video_Custom_Info_choice
echo " Resolution change:"
echo
echo "  [y] > for yes"
echo " *[↵] > for no change"
echo "  [q] > for exit"
read -r -e -p "-> " yn
case $yn in
	"y"|"Y")
		Display_Video_Custom_Info_choice
		echo " Choose the desired width:"
		echo " Notes: Original ratio is respected."
		echo
		echo "  [1] > 640px  - VGA"
		echo "  [2] > 720px  - DV NTSC/VGA"
		echo "  [3] > 768px  - PAL"
		echo "  [4] > 1024px - XGA"
		echo "  [5] > 1280px - 720p, WXGA"
		echo "  [6] > 1680px - WSXGA+"
		echo "  [7] > 1920px - 1080p, WUXGA+"
		echo "  [8] > 2048px - 2K"
		echo "  [9] > 2560px - WQXGA+"
		echo " [10] > 3840px - UHD-1"
		echo " [11] > 4096px - 4K"
		echo " [12] > 5120px - 4K WHXGA, Ultra wide"
		echo " [13] > 7680px - UHD-2"
		echo " [14] > 8192px - 8K"
		echo "  [c] > for no change"
		echo "  [q] > for exit"
		while :
		do
		read -r -e -p "-> " WIDTH
		case $WIDTH in
			1) Calc_Video_Resolution 640; break;;
			2) Calc_Video_Resolution 720; break;;
			3) Calc_Video_Resolution 768; break;;
			4) Calc_Video_Resolution 1024; break;;
			5) Calc_Video_Resolution 1280; break;;
			6) Calc_Video_Resolution 1680; break;;
			7) Calc_Video_Resolution 1920; break;;
			8) Calc_Video_Resolution 2048; break;;
			9) Calc_Video_Resolution 2560; break;;
			10) Calc_Video_Resolution 3840; break;;
			11) Calc_Video_Resolution 4096; break;;
			12) Calc_Video_Resolution 5120; break;;
			13) Calc_Video_Resolution 7680; break;;
			14) Calc_Video_Resolution 8192; break;;
			"c"|"C")
				chwidth="No change"
				break
			;;
			"q"|"Q")
				Restart
				break
			;;
			*)
				echo
				Echo_Mess_Invalid_Answer
				echo
			;;
		esac
		done
	;;
	"q"|"Q")
		Restart
	;;
	*)
		chwidth="No change"
	;;
esac

if [[ "$codec" != "hevc_vaapi" ]]; then

	# Rotation
	Display_Video_Custom_Info_choice
	echo " Rotate the video?"
	echo
	echo "  [0] > for 90° CounterCLockwise and Vertical Flip"
	echo "  [1] > for 90° Clockwise"
	echo "  [2] > for 90° CounterClockwise"
	echo "  [3] > for 90° Clockwise and Vertical Flip"
	echo "  [4] > for 180°"
	echo " *[↵] > for no change"
	echo "  [q] > for exit"
	while :
	do
	read -r -e -p "-> " ynrotat
	case $ynrotat in
		[0-4])
			if [ "$nbvfilter" -gt 1 ] ; then
				vfilter+=",transpose=$ynrotat"
			else
				vfilter="-vf transpose=$ynrotat"
			fi
			nbvfilter=$((nbvfilter+1))

			if [ "$ynrotat" = "0" ]; then
				chrotation="90° CounterCLockwise and Vertical Flip"
			elif [ "$ynrotat" = "1" ]; then
				chrotation="90° Clockwise"
			elif [ "$ynrotat" = "2" ]; then
				chrotation="90° CounterClockwise"
			elif [ "$ynrotat" = "3" ]; then
				chrotation="90° Clockwise and Vertical Flip"
			elif [ "$ynrotat" = "4" ]; then
				chrotation="180°"
			fi
			break
		;;
		[5-9])
			echo
			Echo_Mess_Invalid_Answer
			echo
		;;
		"q"|"Q")
			Restart
			break
		;;
		*)
			chrotation="No change"
			break
		;;
	esac
	done

	# HDR / SDR - Display only if HDR source
	TestHDR
	if test -n "$HDR"; then
	Display_Video_Custom_Info_choice
	echo " Apply HDR to SDR filter:"
	echo " Note: * This option is necessary to keep an acceptable colorimetry,"
	echo "         if the source video is in HDR and you don't want to keep it."
	echo "       * if you want to keep the HDR, do no here, HDR option is in libx265 parameters."
	echo "       * for no fail, in stream selection, remove attached pic if present."
	echo
	echo "  [n] > for no"
	echo " *[↵] > for yes"
	echo "  [q] > for exit"
	read -r -e -p "-> " yn
	case $yn in
		"n"|"N")
				chsdr2hdr="No change"
			;;
		"q"|"Q")
				Restart
			;;
		*)
			nbvfilter=$((nbvfilter+1))
			chsdr2hdr="Yes"
			if [ "$nbvfilter" -gt 1 ] ; then
				vfilter+=",zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p"
			else
				vfilter="-vf zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p"
			fi
			;;
	esac
	fi

fi

# Frame rate
Display_Video_Custom_Info_choice
echo " Change frame rate to 24 images per second?"
echo
echo "  [y] > for yes "
echo " *[↵] > for no change"
echo "  [q] > for exit"
read -r -e -p "-> " yn
case $yn in
	"y"|"Y")
		framerate="-r 24"
		chfps="24 fps"
	;;
	"q"|"Q")
		Restart
	;;
	*)
		chfps="No change"
	;;
esac

}
Video_Custom_Audio() {					# Option 1  	- Conf audio, encode or not
Display_Video_Custom_Info_choice
echo " Encoding or copying the audio stream(s):"
echo
echo "  [e] > for encode stream(s)"
echo " *[↵] > for copy stream(s)"
echo "  [r] > for remove stream(s)"
echo "  [q] > for exit"
read -r -e -p "-> " qa
if [ "$qa" = "q" ]; then
	Restart
elif [ "$qa" = "e" ]; then

	# Set audio encoding
	ENCODA="1"

	# Codec choice
	Video_Custom_Audio_Codec

# Remove audio stream
elif [ "$qa" = "r" ]; then
	chsoundstream="Remove"
	fileacodec="AREMOVE"
	soundconf=""

# No audio change
else
	chsoundstream="Copy"
	fileacodec="acopy"
	soundconf="-c:a copy"
fi
}
Video_Custom_Audio_Codec() {			# Option 1  	- Conf audio, codec
Display_Video_Custom_Info_choice
echo " Choice the audio codec to use:"
echo " Notes: * Your will be applied to all streams"
echo "        * Consider quality of source before choice codec"
echo "        * Size and quality as bitrate dependent"
echo "        * Size indication: ac3 >= flac > vorbis > opus"
echo "        * Quality indication: flac > opus > vorbis > ac3"
echo "        * Compatibility indication: ac3 > vorbis >= opus = flac"
echo
echo "                         |   max    |"
echo "             | codec     | channels |"
echo "             |-----------|----------|"
echo " *[opus]   > | libopus   |   7.1>   |"
echo "  [vorbis] > | libvorbis |   7.1>   |"
echo "  [ac3]    > | ac3       |   5.1    |"
echo "  [flac]   > | libflac   |   7.1>   |"
echo "  [q]      > | exit"
read -r -e -p "-> " chacodec
case $chacodec in
	"opus")
		codeca="libopus"
		chacodec="OPUS"
		Audio_Opus_Config
		Audio_Channels_Config
	;;
	"vorbis")
		codeca="libvorbis"
		chacodec="OGG"
		Audio_OGG_Config
		Audio_Channels_Config
	;;
	"ac3")
		codeca="ac3"
		chacodec="AC3"
		Audio_AC3_Config
		Audio_Channels_Config
	;;
	"flac")
		codeca="flac"
		chacodec="FLAC"
		Audio_FLAC_Config
		Audio_Channels_Config
	;;
	"q"|"Q")
		Restart
	;;
	*)
		codeca="libopus"
		chacodec="OPUS"
		Audio_Opus_Config
		Audio_Channels_Config
	;;
esac
fileacodec="$chacodec"
soundconf="$afilter -c:a $codeca $akb $asamplerate $confchan"
}
Video_Custom_Stream() {					# Option 1,2	- Conf stream selection
# Local variables
local rpstreamch
local rpstreamch_parsed
local streams_invalid

# Array
VINDEX=()
VCODECTYPE=()
stream=()

# Display summary target if in profile 0 or 1
if [[ "$ffmes_option" -le "1" ]]; then
	Display_Video_Custom_Info_choice

# Display only streams stats if no in profile 1
else 
	Display_Media_Stats_One "${LSTVIDEO[@]}"
fi

# Choice Stream
echo " Select video, audio(s) & subtitle(s) streams, or leave for keep unchanged:"
echo " Notes: * The order of the streams you specify will be the order of in final file."
echo
echo "  [0 3 1] > example of input format for select stream"
echo " *[↵]     > for no change"
echo "  [q]     > for exit"

while true; do
	read -r -e -p "-> " rpstreamch
	rpstreamch_parsed="${rpstreamch// /}"					# For test
	if [ -z "$rpstreamch" ]; then							# If -map 0
		# Construct arrays
		VINDEX=( "${ffprobe_StreamIndex[@]}" )
		VCODECTYPE=("${ffprobe_StreamType[@]}")
		stream+=("-map 0")
		break

	elif [[ "$rpstreamch_parsed" == "q" ]]; then			# Quit
		Restart

	elif ! [[ "$rpstreamch_parsed" =~ ^-?[0-9]+$ ]]; then	# Not integer retry
		Echo_Mess_Error "Map option must be an integer"

	elif [[ "$rpstreamch_parsed" =~ ^-?[0-9]+$ ]]; then		# If valid integer continue
		# Reset streams_invalid
		unset streams_invalid

		# Construct arrays
		VINDEX=()
		VCODECTYPE=()
		# Codec type
		IFS=" " read -r -a VINDEX <<< "$rpstreamch"
		for i in "${VINDEX[@]}"; do
			VCODECTYPE+=("${ffprobe_StreamType[$i]}")
		done

		# Test if selected streams are valid
		for i in "${VINDEX[@]}"; do
			if [[ -z "${ffprobe_StreamIndex[$i]}" ]]; then
				Echo_Mess_Error "The stream $i does not exist"
				streams_invalid="1"
			fi
			
		done
		if ! [[ "${VCODECTYPE[*]}" == *"video"* ]]; then
			Echo_Mess_Error "No video stream selected"
			streams_invalid="1"
		fi

		# If no error continue
		if [[ -z "$streams_invalid" ]]; then
			break
		fi

	fi
done

# Get -map arguments
for i in ${!VINDEX[*]}; do
	case "${VCODECTYPE[i]}" in
		# Video Stream
		video)
			# Add stream
			if [ -n "$rpstreamch" ]; then
				stream+=("-map 0:${VINDEX[i]}")
			fi
			;;

		# Audio Stream
		audio)
			if [ -n "$rpstreamch" ]; then
				if ! [[ "$chsoundstream" = "Remove" ]]; then
					stream+=("-map 0:${VINDEX[i]}")
				fi
			fi
			;;

		# Subtitle Stream
		subtitle)
			if [ -n "$rpstreamch" ]; then
				stream+=("-map 0:${VINDEX[i]}")
			fi
			if test -z "$subtitleconf"; then
				if [ "$extcont" = mkv ]; then
					subtitleconf="-c:s copy"
				elif [ "$extcont" = mp4 ]; then
					subtitleconf="-c:s mov_text"
				fi
			fi
			;;
	esac
done
vstream="${stream[*]}"

# Set file name if $videoformat variable empty
if test -z "$videoformat"; then
	videoformat="$filevcodec.$fileacodec"
fi

# Reset display (last question before encoding)
if [ "$ffmes_option" -le 3 ]; then
	Display_Video_Custom_Info_choice
fi
}
Video_Custom_Container() {				# Option 1  	- Conf container mkv/mp4
Display_Video_Custom_Info_choice
echo " Choose container:"
echo
echo " *[mkv] > for mkv"
echo "  [mp4] > for mp4"
echo "  [q]   > for exit"
read -r -e -p "-> " chcontainer
case $chcontainer in
	"mkv")
		extcont="mkv"
		container="matroska"
	;;
	"mp4")
		extcont="mp4"
		container="mp4"
	;;
	"q"|"Q")
		Restart
	;;
	*)
		extcont="mkv"
		container="matroska"
	;;
esac

# Reset display (last question before encoding)
if [ "${#ffprobe_StreamIndex[@]}" -lt 3 ] ; then
	Display_Video_Custom_Info_choice
fi
}
Video_MPEG4_Config() {					# Option 1  	- Conf Xvid 
Display_Video_Custom_Info_choice
echo " Choose a number OR enter the desired bitrate:"
echo
echo " [1200k] -> Example of input format for desired bitrate"
echo
echo "  [1] > for qscale 1   |"
echo "  [2] > for qscale 5   |HD"
echo " *[3] > for qscale 10  |"
echo "  [4] > for qscale 15  -"
echo "  [5] > for qscale 20  |"
echo "  [6] > for qscale 15  |SD"
echo "  [7] > for qscale 30  |"
echo "  [q] > for exit"
read -r -e -p "-> " rpvkb
if echo "$rpvkb" | grep -q 'k' ; then
	vkb="-b:v $rpvkb"
elif [ "$rpvkb" = "1" ]; then
	vkb="-q:v 1"
elif [ "$rpvkb" = "2" ]; then
	vkb="-q:v 5"
elif [ "$rpvkb" = "3" ]; then
	vkb="-q:v 10"
elif [ "$rpvkb" = "4" ]; then
	vkb="-q:v 15"
elif [ "$rpvkb" = "5" ]; then
	vkb="-q:v 20"
elif [ "$rpvkb" = "6" ]; then
	vkb="-q:v 25"
elif [ "$rpvkb" = "7" ]; then
	vkb="-q:v 30"
elif [ "$rpvkb" = "q" ]; then
	Restart
else
	vkb="-q:v 10"
fi
}
Video_x264_5_Config() {					# Option 1  	- Conf x264/x265
# Local variables
local video_stream_kb
local video_stream_size

# Preset x264/x265
Display_Video_Custom_Info_choice
echo " Choose the preset:"
echo
echo "  [veryslow] > lower speed; best quality"
echo "  [slower]"
echo " *[slow]"
echo "  [medium]"
echo "  [fast]"
echo "  [faster]"
echo "  [veryfast] > best speed; lower quality"
echo "  [q]        > for exit"
read -r -e -p "-> " reppreset
if [ -n "$reppreset" ]; then
	preset="-preset $reppreset"
	chpreset="; preset $reppreset"
elif [ "$reppreset" = "q" ]; then
	Restart
else
	preset="-preset medium"
	chpreset="; preset slow"
fi

# Tune x264/x265
Display_Video_Custom_Info_choice
if [ "$chvcodec" = "H264" ]; then
	echo " Choose tune:"
	echo " Note: This settings influences the final rendering of the image & speed of encoding."
	echo
	echo " *[cfilm]       > for movie content, ffmes custom tuning (high quality)"
	echo "  [canimation]  > for animation content, ffmes custom tuning (high quality)"
	echo
	echo "  [no]          > for no tuning"
	echo "  [film]        > for movie content; lower debloking"
	echo "  [animation]   > for animation; more deblocking and reference frames"
	echo "  [grain]       > for preserves the grain structure in old, grainy film material"
	echo "  [stillimage]  > for slideshow-like content "
	echo "  [fastdecode]  > for allows faster decoding (disabling certain filters)"
	echo "  [zerolatency] > for fast encoding and low-latency streaming "
	echo "  [q]           > for exit"
	read -r -e -p " -> " reptune
	if [ "$reptune" = "film" ]; then
		tune="-tune $reptune"
	elif [ "$reptune" = "animation" ]; then
		tune="-tune $reptune"
	elif [ "$reptune" = "grain" ]; then
		tune="-tune $reptune"
	elif [ "$reptune" = "stillimage" ]; then
		tune="-tune $reptune"
	elif [ "$reptune" = "fastdecode" ]; then
		tune="-tune $reptune"
	elif [ "$reptune" = "zerolatency" ]; then
		tune="-tune $reptune"
	elif [ "$reptune" = "cfilm" ]; then
		tune="-fast-pskip 0 -bf 10 -b_strategy 2 -me_method umh -me_range 24 -trellis 2 -refs 4 -subq 9"
	elif [ "$reptune" = "canimation" ]; then
		tune="-fast-pskip 0 -bf 10 -b_strategy 2 -me_method umh -me_range 24 -trellis 2 -refs 4 -subq 9 -deblock -2:-2 -psy-rd 1.0:0.25 -aq 0.5 -qcomp 0.8"
	elif [ "$reptune" = "no" ]; then
		tune=""
	elif [ "$reptune" = "q" ]; then
		Restart
	else
		tune="-fast-pskip 0 -bf 10 -b_strategy 2 -me_method umh -me_range 24 -trellis 2 -refs 4 -subq 9"
	fi
	# Menu display tune
	chtune="; tune $reptune"
elif [ "$chvcodec" = "HEVC" ]; then
	echo " Choose tune:"
	echo " Notes: * This settings influences the final rendering of the image, and speed of encoding."
	echo "        * By default x265 always tunes for highest perceived visual."
	echo
	echo " *[default]     > for movie content; default, intermediate tuning of the two following"
	echo "  [psnr]        > for movie content; disables adaptive quant, psy-rd, and cutree"
	echo "  [ssim]        > for movie content; enables adaptive quant auto-mode, disables psy-rd"
	echo "  [grain]       > for preserves the grain structure in old, grainy film material"
	echo "  [fastdecode]  > for allows faster decoding (disabling certain filters)"
	echo "  [zerolatency] > for fast encoding and low-latency streaming"
	echo "  [q]           > for exit"
	read -r -e -p "-> " reptune
	if [ "$reptune" = "psnr" ]; then
		tune="-tune $reptune"
	elif [ "$reptune" = "ssim" ]; then
		tune="-tune $reptune"
	elif [ "$reptune" = "grain" ]; then
		tune="-tune $reptune"
	elif [ "$reptune" = "fastdecode" ]; then
		tune="-tune $reptune"
	elif [ "$reptune" = "zerolatency" ]; then
		tune="-tune $reptune"
	elif [ "$reptune" = "q" ]; then
		Restart
	else
		tune=""
		chtune="; tune default"
	fi
	# Menu display tune
	if [ -n "$tune" ]; then
		chtune="; tune $reptune"
	else
		chtune="; tune default"
	fi
fi

# Profile x264/x265
Display_Video_Custom_Info_choice
if [ "$chvcodec" = "H264" ]; then
	echo " Choose the profile:"
	echo " Note: The choice of the profile affects the compatibility of the result,"
	echo "       be careful not to apply any more parameters to the source file (no positive effect)"
	echo
	echo "                                   | max definition/fps by level   |"
	echo "        | lvl | profile  | max db  | res.     >fps                 |"
	echo "        |-----|----------|---------|-------------------------------|"
	echo "  [1] > | 3.0 | Baseline | 10 Mb/s | 720×480  >30  || 720×576  >25 |"
	echo "  [2] > | 3.1 | main     | 14 Mb/s | 1280×720 >30  || 720×576  >66 |"
	echo "  [3] > | 4.0 | Main     | 20 Mb/s | 1920×1080>30  || 2048×1024>30 |"
	echo "  [4] > | 4.0 | High     | 25 Mb/s | 1920×1080>30  || 2048×1024>30 |"
	echo " *[5] > | 4.1 | High     | 63 Mb/s | 1920×1080>30  || 2048×1024>30 |"
	echo "  [6] > | 4.2 | High     | 63 Mb/s | 1920×1080>64  || 2048×1088>60 |"
	echo "  [7] > | 5.0 | High     | 169Mb/s | 1920×1080>72  || 2560×1920>30 |"
	echo "  [8] > | 5.1 | High     | 300Mb/s | 1920×1080>120 || 4096×2048>30 |"
	echo "  [9] > | 5.2 | High     | 300Mb/s | 1920×1080>172 || 4096×2160>60 |"
	echo "  [q] > for exit"
	read -r -e -p "-> " repprofile
	if [ "$repprofile" = "1" ]; then
		profile="-profile:v baseline -level 3.0"
		chprofile="; profile Baseline 3.0"
	elif [ "$repprofile" = "2" ]; then
		profile="-profile:v baseline -level 3.1"
		chprofile="; profile Baseline 3.1"
	elif [ "$repprofile" = "3" ]; then
		profile="-profile:v main -level 4.0"
		chprofile="; profile Baseline 4.0"
	elif [ "$repprofile" = "4" ]; then
		profile="-profile:v high -level 4.0"
		chprofile="; profile High 4.0"
	elif [ "$repprofile" = "5" ]; then
		profile="-profile:v high -level 4.1"
		chprofile="; profile High 4.1"
	elif [ "$repprofile" = "6" ]; then
		profile="-profile:v high -level 4.2"
		chprofile="; profile High 4.2"
	elif [ "$repprofile" = "7" ]; then
		profile="-profile:v high -level 5.0"
		chprofile="; profile High 5.0"
	elif [ "$repprofile" = "8" ]; then
		profile="-profile:v high -level 5.1"
		chprofile="; profile High 5.1"
	elif [ "$repprofile" = "9" ]; then
		profile="-profile:v high -level 5.2"
		chprofile="; profile High 5.2"
	elif [ "$repprofile" = "q" ]; then
		Restart
	else
		profile="-profile:v high -level 4.1"
		chprofile="; profile High 4.1"
	fi
elif [ "$chvcodec" = "HEVC" ]; then
	echo " Choose a profile or make your profile manually:"
	echo " Notes: * For bit and chroma settings, if the source is below the parameters, FFmpeg will not replace them but will be at the same level."
	echo "        * The level (lvl) parameter must be chosen judiciously according to the bit rate of the source file and the result you expect."
	echo "        * The choice of the profile affects the player compatibility of the result."
	echo
	echo " Manually options (expert):"
	echo "  * 8bit profiles: main, main-intra, main444-8, main444-intra"
	echo "  * 10bit profiles: main10, main10-intra, main422-10, main422-10-intra, main444-10, main444-10-intra"
	echo "  * 12bit profiles: main12, main12-intra, main422-12, main422-12-intra, main444-12, main444-12-intra"
	echo "  * Level: 1, 2, 2.1, 3.1, 4, 4.1, 5, 5.1, 5.2, 6, 6.1, 6.2"
	echo "  * High level: high-tier=1"
	echo "  * No high level: no-high"
	echo " [-profile:v main -x265-params level=3.1:no-high-tier] -> Example of input format for manually profile"
	echo
	echo " ffmes predefined profiles:"
	echo
	echo "                                                    | max db | max definition/fps by level |"
	echo "         | lvl | hight | intra | bit | HDR | chroma | Mb/s   | res.     >fps               |"
	echo "         |-----|-------|-------|-----|-----|--------|--------|-----------------------------|"
	echo "   [1] > | 3.1 | 0     | 0     | 8   | 0   | 4:2:0  | 10     | 1280×720 >30                |"
	echo "   [2] > | 4.1 | 0     | 0     | 8   | 0   | 4:2:0  | 20     | 2048×1080>60                |"
	echo "  *[3] > | 4.1 | 1     | 0     | 8   | 0   | 4:2:0  | 50     | 2048×1080>60                |"
	echo "   [4] > | 4.1 | 1     | 0     | 12  | 0   | 4:4:4  | 150    | 2048×1080>60                |"
	echo "   [5] > | 4.1 | 1     | 0     | 12  | 1   | 4:4:4  | 150    | 2048×1080>60                |"
	echo "   [6] > | 4.1 | 1     | 1     | 12  | 0   | 4:4:4  | 1800   | 2048×1080>60                |"
	echo "   [7] > | 5.2 | 1     | 0     | 8   | 0   | 4:2:0  | 240    | 4096×2160>120               |"
	echo "   [8] > | 5.2 | 1     | 0     | 12  | 0   | 4:4:4  | 720    | 4096×2160>120               |"
	echo "   [9] > | 5.2 | 1     | 0     | 12  | 1   | 4:4:4  | 720    | 4096×2160>120               |"
	echo "  [10] > | 5.2 | 1     | 1     | 12  | 0   | 4:4:4  | 8640   | 4096×2160>120               |"
	echo "  [11] > | 6.2 | 1     | 0     | 12  | 0   | 4:4:4  | 2400   | 8192×4320>120               |"
	echo "  [12] > | 6.2 | 1     | 0     | 12  | 1   | 4:4:4  | 2400   | 8192×4320>120               |"
	echo "  [13] > | 6.2 | 1     | 1     | 12  | 0   | 4:4:4  | 28800  | 8192×4320>120               |"
	echo "   [q] > for exit"
	read -r -e -p "-> " repprofile
	if echo "$repprofile" | grep -q 'profil'; then
		profile="$repprofile"
		chprofile="; profile $repprofile"
	elif [ "$repprofile" = "1" ]; then
		profile="-profile:v main -x265-params ${X265_LOG_LVL}level=3.1 -pix_fmt yuv420p"
		chprofile="; profile 3.1 - 8 bit - 4:2:0"
	elif [ "$repprofile" = "2" ]; then
		profile="-profile:v main -x265-params ${X265_LOG_LVL}level=4.1 -pix_fmt yuv420p"
		chprofile="; profile 4.1 - 8 bit - 4:2:0"
	elif [ "$repprofile" = "3" ]; then
		profile="-profile:v main -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1 -pix_fmt yuv420p"
		chprofile="; profile 4.1 - 8 bit - 4:2:0"
	elif [ "$repprofile" = "4" ]; then
		profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1 -pix_fmt yuv420p12le"
		chprofile="; profile 4.1 - 12 bit - 4:4:4"
	elif [ "$repprofile" = "5" ]; then
		profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1:hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,10) -pix_fmt yuv420p12le"
		chprofile="; profile 4.1 - 12 bit - 4:4:4 - HDR"
	elif [ "$repprofile" = "6" ]; then
		profile="-profile:v main444-12-intra -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1 -pix_fmt yuv420p12le"
		chprofile="; profile 4.1 - 12 bit - 4:4:4 - intra"
	elif [ "$repprofile" = "7" ]; then
		profile="-profile:v main -x265-params ${X265_LOG_LVL}level=5.2:high-tier=1 -pix_fmt yuv420p"
		chprofile="; profile 5.2 - 8 bit - 4:2:0"
	elif [ "$repprofile" = "8" ]; then
		profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=5.2:high-tier=1 -pix_fmt yuv420p12le"
		chprofile="; profile 5.2 - 12 bit - 4:4:4"
	elif [ "$repprofile" = "9" ]; then
		profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=5.2:high-tier=1:hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,10) -pix_fmt yuv420p12le"
		chprofile="; profile 5.2 - 12 bit - 4:4:4 - HDR"
	elif [ "$repprofile" = "10" ]; then
		profile="-profile:v main444-12-intra -x265-params ${X265_LOG_LVL}level=5.2:high-tier=1 -pix_fmt yuv420p12le"
		chprofile="; profile 5.2 - 12 bit - 4:4:4 - intra"
	elif [ "$repprofile" = "11" ]; then
		profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=6.2:high-tier=1 -pix_fmt yuv420p12le"
		chprofile="; profile 6.2 - 12 bit - 4:4:4"
	elif [ "$repprofile" = "12" ]; then
		profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=6.2:high-tier=1:hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,10) -pix_fmt yuv420p12le"
		chprofile="; profile 6.2 - 12 bit - 4:4:4 - HDR"
	elif [ "$repprofile" = "13" ]; then
		profile="-profile:v main444-12-intra -x265-params ${X265_LOG_LVL}level=6.2:high-tier=1 -pix_fmt yuv420p12le"
		chprofile="; profile 6.2 - 12 bit - 4:4:4 - intra"
	elif [ "$repprofile" = "q" ]; then
		Restart
	else
		profile="-profile:v main -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1 -pix_fmt yuv420p"
		chprofile="; profile High 4.1 - 8 bit - 4:2:0"
	fi
fi

# Bitrate x264/x265
Display_Video_Custom_Info_choice
echo " Choose a CRF number, video strem size, or enter the desired bitrate:"
echo " Note: * This settings influences size and quality, crf is a better choise in 90% of cases."
echo "       * libx265 which can offer 25–50% bitrate savings compared to libx264."
echo
echo " [1200k]     Example of input for cbr desired bitrate in kb/s"
echo " [1500m]     Example of input for aproximative total size of video stream in MB (not recommended in batch)"
echo " [-crf 21]   Example of input for crf desired level"
echo
echo "  [1] > for crf 0    ∧ |"
echo "  [2] > for crf 5   Q| |"
echo "  [3] > for crf 10  U| |S"
echo "  [4] > for crf 15  A| |I"
echo " *[5] > for crf 20  L| |Z"
echo "  [6] > for crf 22  I| |E"
echo "  [7] > for crf 25  T| |"
echo "  [8] > for crf 30  Y| |"
echo "  [9] > for crf 35   | ∨"
echo "  [q] > for exit"
read -r -e -p "-> " rpvkb
if echo "$rpvkb" | grep -q 'k'; then
	# Remove all after k from variable for prevent syntax error
	video_stream_kb="${rpvkb%k*}"
	# Set cbr variable
	vkb="-b:v ${video_stream_kb}k"
elif echo "$rpvkb" | grep -q 'm'; then
	# Remove all after m from variable
	video_stream_size="${rpvkb%m*}"
	# Bitrate calculation
	video_stream_kb=$(bc <<< "scale=0; ($video_stream_size * 8192)/$ffprobe_Duration")
	# Set cbr variable
	vkb="-b:v ${video_stream_kb}k"
elif echo "$rpvkb" | grep -q 'crf'; then
	vkb="$rpvkb"
elif [ "$rpvkb" = "1" ]; then
	vkb="-crf 0"
elif [ "$rpvkb" = "2" ]; then
	vkb="-crf 5"
elif [ "$rpvkb" = "3" ]; then
	vkb="-crf 10"
elif [ "$rpvkb" = "4" ]; then
	vkb="-crf 15"
elif [ "$rpvkb" = "5" ]; then
	vkb="-crf 20"
elif [ "$rpvkb" = "6" ]; then
	vkb="-crf 22"
elif [ "$rpvkb" = "7" ]; then
	vkb="-crf 25"
elif [ "$rpvkb" = "8" ]; then
	vkb="-crf 30"
elif [ "$rpvkb" = "9" ]; then
	vkb="-crf 35"
elif [ "$rpvkb" = "q" ]; then
	Restart
else
	vkb="-crf 20"
fi
}
Video_hevc_vaapi_Config() {				# Option 1  	- Conf hevc_vaapi
# Local variables
local video_stream_kb
local video_stream_size

# Bitrate
Display_Video_Custom_Info_choice
echo " Choose a QP number, video strem size, or enter the desired bitrate:"
echo " Note: * libx265 which can offer 25–50% bitrate savings compared to libx264."
echo
echo " [1200k]     Example of input for cbr desired bitrate in kb/s"
echo " [1500m]     Example of input for aproximative total size of video stream in MB (not recommended in batch)"
echo " [-qp 21]   Example of input for crf desired level"
echo
echo "  [1] > for crf 0    ∧ |"
echo "  [2] > for crf 5   Q| |"
echo "  [3] > for crf 10  U| |S"
echo "  [4] > for crf 15  A| |I"
echo "  [5] > for crf 20  L| |Z"
echo "  [6] > for crf 22  I| |E"
echo " *[7] > for crf 25  T| |"
echo "  [8] > for crf 30  Y| |"
echo "  [9] > for crf 35   | ∨"
echo "  [q] > for exit"
read -r -e -p "-> " rpvkb
if echo "$rpvkb" | grep -q 'k'; then
	# Remove all after k from variable for prevent syntax error
	video_stream_kb="${rpvkb%k*}"
	# Set cbr variable
	vkb="-rc_mode 2 -b:v ${video_stream_kb}k"
elif echo "$rpvkb" | grep -q 'm'; then
	# Remove all after m from variable
	video_stream_size="${rpvkb%m*}"
	# Bitrate calculation
	video_stream_kb=$(bc <<< "scale=0; ($video_stream_size * 8192)/$ffprobe_Duration")
	# Set cbr variable
	vkb="-rc_mode 2 -b:v ${video_stream_kb}k"
elif echo "$rpvkb" | grep -q 'qp'; then
	vkb="-rc_mode 2 $rpvkb"
elif [ "$rpvkb" = "1" ]; then
	vkb="-rc_mode 1 -qp 0"
elif [ "$rpvkb" = "2" ]; then
	vkb="-rc_mode 1 -qp 5"
elif [ "$rpvkb" = "3" ]; then
	vkb="-rc_mode 1 -qp 10"
elif [ "$rpvkb" = "4" ]; then
	vkb="-rc_mode 1 -qp 15"
elif [ "$rpvkb" = "5" ]; then
	vkb="-rc_mode 1 -qp 20"
elif [ "$rpvkb" = "6" ]; then
	vkb="-rc_mode 1 -qp 22"
elif [ "$rpvkb" = "7" ]; then
	vkb="-rc_mode 1 -qp 25"
elif [ "$rpvkb" = "8" ]; then
	vkb="-rc_mode 1 -qp 30"
elif [ "$rpvkb" = "9" ]; then
	vkb="-rc_mode 1 -qp 35"
elif [ "$rpvkb" = "q" ]; then
	Restart
else
	vkb="-rc_mode 1 -qp 25"
fi
}
Video_av1_Config() {					# Option 1  	- Conf av1
# Local variables
local video_stream_kb
local video_stream_size

# Preset av1
Display_Video_Custom_Info_choice
echo " Choose cpu-used efficient compression value (preset):"
echo
echo "  [0] > for cpu-used 0   ∧ |"
echo "  [1] > for cpu-used 1  Q| |"
echo " *[2] > for cpu-used 2  U| |S"
echo "  [3] > for cpu-used 3  A| |P"
echo "  [4] > for cpu-used 4  L| |E"
echo "  [5] > for cpu-used 5  I| |E"
echo "  [6] > for cpu-used 6  T| |D"
echo "  [7] > for cpu-used 7  Y| |"
echo "  [8] > for cpu-used 8   | ∨"
echo "  [q] > for exit"
read -r -e -p "-> " reppreset
if [ -n "$reppreset" ]; then
	preset="-cpu-used $reppreset -row-mt 1 -tiles 4x1"
	chpreset="; cpu-used: $reppreset"
elif [ "$reppreset" = "q" ]; then
	Restart
else
	preset="-cpu-used 2 -row-mt 1 -tiles 4x1"
	chpreset="; cpu-used: 2"
fi

# Bitrate av1
Display_Video_Custom_Info_choice
echo " Choose a CRF number, video strem size, or enter the desired bitrate:"
echo " Note: * This settings influences size and quality, crf is a better choise in 90% of cases."
echo "       * libaom-av1 can save about 30% bitrate compared to VP9 and H.265 / HEVC,"
echo "         and about 50% over H.264, while retaining the same visual quality. "
echo
echo " [1200k]     Example of input for cbr desired bitrate in kb/s"
echo " [1500m]     Example of input for aproximative total size of video stream in MB (not recommended in batch)"
echo " [-crf 21]   Example of input for crf desired level"
echo
echo "  [1] > for crf 0   Q∧ |"
echo "  [2] > for crf 10  U| |S"
echo "  [3] > for crf 20  A| |I"
echo " *[4] > for crf 30  L| |Z"
echo "  [5] > for crf 40  I| |E"
echo "  [6] > for crf 50  T| |"
echo "  [7] > for crf 60  Y| ∨"
echo "  [q] > for exit"
read -r -e -p "-> " rpvkb
if echo "$rpvkb" | grep -q 'k'; then
	# Remove all after k from variable for prevent syntax error
	video_stream_kb="${rpvkb%k*}"
	# Set cbr variable
	vkb="-b:v ${video_stream_kb}k"
elif echo "$rpvkb" | grep -q 'm'; then
	# Remove all after m from variable
	video_stream_size="${rpvkb%m*}"
	# Bitrate calculation
	video_stream_kb=$(bc <<< "scale=0; ($video_stream_size * 8192)/$ffprobe_Duration")
	# Set cbr variable
	vkb="-b:v ${video_stream_kb}k"
elif echo "$rpvkb" | grep -q 'crf'; then
	vkb="$rpvkb -b:v 0"
elif [ "$rpvkb" = "1" ]; then
	vkb="-crf 0 -b:v 0"
elif [ "$rpvkb" = "2" ]; then
	vkb="-crf 10 -b:v 0"
elif [ "$rpvkb" = "3" ]; then
	vkb="-crf 20 -b:v 0"
elif [ "$rpvkb" = "4" ]; then
	vkb="-crf 30 -b:v 0"
elif [ "$rpvkb" = "5" ]; then
	vkb="-crf 40 -b:v 0"
elif [ "$rpvkb" = "6" ]; then
	vkb="-crf 50 -b:v 0"
elif [ "$rpvkb" = "7" ]; then
	vkb="-crf 60 -b:v 0"
elif [ "$rpvkb" = "q" ]; then
	Restart
else
	vkb="-crf 30 -b:v 0"
fi
}
Video_Custom_Audio_Only() {				# Option 3  	- Encode audio stream only
# Local variable
local rpstreamch_parsed
local audio_stream_config
local subtitleconf

# Array
VINDEX=()
stream=()
mapLabel=()

Display_Media_Stats_One "${LSTVIDEO[@]}"

echo " Select one or several audio stream:"
echo
echo "  [0 3 1] > Example of input format for select stream"
echo " *[↵]     > for all"
echo "  [q]     > for exit"
while true; do
	read -r -e -p "-> " rpstreamch
	rpstreamch_parsed="${rpstreamch// /}"					# For test
	if [ -z "$rpstreamch" ]; then							# If -map 0
		# Construct index array
		VINDEX=( "${ffprobe_a_StreamIndex[@]}" )
		break

	elif [[ "$rpstreamch_parsed" == "q" ]]; then			# Quit
		Restart

	elif ! [[ "$rpstreamch_parsed" =~ ^-?[0-9]+$ ]]; then	# Not integer retry
		Echo_Mess_Error "Map option must be an integer"

	elif [[ "$rpstreamch_parsed" =~ ^-?[0-9]+$ ]]; then		# If valid integer continue
		# Construct index array
		IFS=" " read -r -a VINDEX <<< "$rpstreamch"

		# Test if selected stream is audio
		for i in "${VINDEX[@]}"; do
			if ! [[ "${ffprobe_StreamType[i]}" = "audio" ]]; then
				Echo_Mess_Error "The stream $i is not audio stream"
			else
				break 2
			fi
		done

	fi
done

# Codec choice
chvidstream="Copy"
ENCODA="1"
extcont="${LSTVIDEO[0]##*.}"
Video_Custom_Audio_Codec

# Construct ffmpeg encoding command
for i in "${VINDEX[@]}"; do
	if [[ "$codeca" = "libopus" ]]; then
		stream+=( "-filter:a:${ffprobe_a_StreamIndex[i]} aformat=channel_layouts='7.1|6.1|5.1|stereo' -mapping_family 1 -c:a:${ffprobe_a_StreamIndex[i]} $codeca" )
		mapLabel+=( "$i" )
	else
		stream+=( "-c:a:${ffprobe_a_StreamIndex[i]} $codeca" )
		mapLabel+=( "$i" )
	fi
done

# ffmpeg audio command argument
audio_stream_config="${stream[*]}"

# Variable for display summary
vstream="${mapLabel[*]}"

# Reset display
Display_Video_Custom_Info_choice

# Start time counter
START=$(date +%s)

# Encoding
for files in "${LSTVIDEO[@]}"; do

	# Subtitle correction
	if [ "${files##*.}" = mkv ]; then
		subtitleconf="-c:s copy"
	elif [ "${files##*.}" = mp4 ]; then
		subtitleconf="-c:s mov_text"
	fi

	filename_id="${files%.*}-${chacodec}.${files##*.}"

	# Encoding
	"$ffmpeg_bin"  $FFMPEG_LOG_LVL -y -i "$files" \
		$FFMPEG_PROGRESS \
		-map 0 -c:v copy $subtitleconf -c:a copy \
		$audio_stream_config \
		$akb $asamplerate $confchan \
		"$filename_id" \
		| ProgressBar "$files" "" "" "Encoding"

	# Check Target if valid
	Test_Target_File "0" "video" "$filename_id"

done

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"											# Get elapsed time
total_source_files_size=$(Calc_Files_Size "${LSTVIDEO[@]}")					# Source file(s) size
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")				# Target(s) size
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")	# Size difference between source and target

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" "$total_source_files_size"
}
Video_Add_OPUS_NightNorm() {			# Option 4		- Add audio stream with night normalization in opus/stereo/320kb
# Local variables
local subtitleconf
# Array
VINDEX=()

Display_Media_Stats_One "${LSTVIDEO[@]}"

echo " Select one audio stream:"
echo " Note: * The selected audio will be encoded in a new stream in opus/stereo/320kb."
echo "       * Night normalization reduce amplitude between heavy and weak sounds."
echo
echo "  [0 3 1] > example for select stream"
echo "  [q]     > for exit"
while true; do
	read -r -e -p "-> " rpstreamch
	if [[ "$rpstreamch" == "q" ]]; then						# Quit
		Restart

	elif ! [[ "$rpstreamch" =~ ^-?[0-9]+$ ]]; then			# Not integer retry
		Echo_Mess_Error "Map option must be an integer"

	elif [[ "$rpstreamch" =~ ^-?[0-9]+$ ]]; then			# If valid integer continue
		# Construct index array
		IFS=" " read -r -a VINDEX <<< "$rpstreamch"

		# Test if selected stream is audio
		for i in "${VINDEX[@]}"; do
			if ! [[ "${ffprobe_StreamType[i]}" = "audio" ]]; then
				Echo_Mess_Error "The stream $i is not audio stream"
			else
				break 2
			fi
		done

	fi
done

# Start time counter
START=$(date +%s)

# Encoding
for files in "${LSTVIDEO[@]}"; do

	# Subtitle correction
	if [ "${files##*.}" = mkv ]; then
		subtitleconf="-c:s copy"
	elif [ "${files##*.}" = mp4 ]; then
		subtitleconf="-c:s mov_text"
	fi

	for i in ${!VINDEX[*]}; do

		# Encoding new track
		"$ffmpeg_bin"  $FFMPEG_LOG_LVL -y -i "$files" \
			$FFMPEG_PROGRESS \
			-map 0:v -c:v copy -map 0:s? $subtitleconf -map 0:a -map 0:a:${VINDEX[i]}? \
			-c:a copy -metadata:s:a:${VINDEX[i]} title="Opus 2.0 Night Mode" -c:a:${VINDEX[i]} libopus \
			-b:a:${VINDEX[i]} 320K -ac 2 \
			-filter:a:${VINDEX[i]} acompressor=threshold=0.031623:attack=200:release=1000:detection=0,loudnorm \
			"${files%.*}"-NightNorm.mkv \
			| ProgressBar "$files" "" "" "Encoding"

		# Check Target if valid
		Test_Target_File "0" "video" "${files%.*}-NightNorm.mkv"

	done

done

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"											# Get elapsed time
total_source_files_size=$(Calc_Files_Size "${LSTVIDEO[@]}")					# Source file(s) size
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")				# Target(s) size
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")	# Size difference between source and target

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" "$total_source_files_size"
}
Video_Merge_Files() {					# Option 11 	- Add audio stream or subtitle in video file
# Local variables
local MERGE_LSTAUDIO
local MERGE_LSTSUB

# Keep extention with wildcard for current audio and sub
mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
if [ "${#LSTAUDIO[@]}" -gt 0 ] ; then
	MERGE_LSTAUDIO=$(printf '*.%s ' "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
fi
if [ "${#LSTSUB[@]}" -gt 0 ] ; then
	MERGE_LSTSUB=$(printf '*.%s ' "${LSTSUB[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
fi

# Summary message
Display_Media_Stats_One "${LSTVIDEO[@]}"
echo "  You will merge the following files:"
echo "   ${LSTVIDEO[0]##*/}"
if [ "${#LSTAUDIO[@]}" -gt 0 ] ; then
	printf '   %s\n' "${LSTAUDIO[@]}"
fi
if [ "${#LSTSUB[@]}" -gt 0 ] ; then
	printf '   %s\n' "${LSTSUB[@]}"
fi
echo
read -r -e -p "Continue? [Y/n]:" qarm
case $qarm in
	"N"|"n")
		Restart
	;;
	*)
	;;
esac

# Start time counter
START=$(date +%s)

echo
Echo_Separator_Light

# If sub add, convert in UTF-8, srt and ssa
if [ "${#LSTSUB[@]}" -gt 0 ] ; then
	for files in "${LSTSUB[@]}"; do
		if [ "${files##*.}" != "idx" ] && [ "${files##*.}" != "sup" ]; then
			CHARSET_DETECT=$(uchardet "$files" 2> /dev/null)
			if [ "$CHARSET_DETECT" != "UTF-8" ]; then
				iconv -f "$CHARSET_DETECT" -t UTF-8 "$files" > utf-8-"$files"
				mkdir SUB_BACKUP 2> /dev/null
				mv "$files" SUB_BACKUP/"$files".back
				mv -f utf-8-"$files" "$files"
			fi
		fi
	done
fi

# Merge
mkvmerge -o "${LSTVIDEO[0]%.*}"."$videoformat".mkv "${LSTVIDEO[0]}" $MERGE_LSTAUDIO $MERGE_LSTSUB


# File validation
Test_Target_File "0" "video" "${LSTVIDEO%.*}.$videoformat.mkv"

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" ""
}
Video_Concatenate() {					# Option 12 	- Concatenate video
# Local variables
local filename_id

clear
echo
echo " Concatenate video files?"
echo " Note: * Before you start, make sure that the files all have the same height/width, codecs and bitrates."
echo
echo " Files to concatenate:"
printf '  %s\n' "${LSTVIDEO[@]##*/}"
echo
echo " *[↵] > for continue"
echo "  [q] > for exit"
read -r -e -p "-> " concatrep
if [ "$concatrep" = "q" ]; then
		Restart
else
	# Start time counter
	START=$(date +%s)

	echo
	Echo_Separator_Light

	# Add date id to created filename, prevent infinite loop of ffmpeg is target=source filename
	filename_id="Concatenate_Output-$(date +%s).${LSTVIDEO[0]##*.}"
	
	# Concatenate
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -f concat -safe 0 -i <(for f in *."${LSTVIDEO[0]##*.}"; do echo "file '$PWD/$f'"; done) \
		-map 0 -c copy "$filename_id" \
		| ProgressBar "" "1" "1" "Concatenate" "1"

	# End time counter
	END=$(date +%s)

	# File validation
	Test_Target_File "0" "video" "$filename_id"

	# Make statistics of processed files
	Calc_Elapsed_Time "$START" "$END"
	total_source_files_size=$(Calc_Files_Size "${LSTVIDEO[@]}")
	total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")
	PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")

	# End encoding messages "pass_files" "total_files" "target_size" "source_size"
	Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" "$total_source_files_size"

	# Next encoding question
	read -r -p "You want encoding concatenating video? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			LSTVIDEO=("$filename_id")
			Media_Source_Info_Record "$filename_id"
		;;
		*)
			Restart
		;;
	esac
fi
}
Video_Extract_Stream() {				# Option 13 	- Extract stream
# Local variables
local rpstreamch_parsed
local streams_invalid
local MKVEXTRACT
local FILE_EXT

# Array
VINDEX=()
VCODECNAME=()
filesInLoop=()

Display_Media_Stats_One "${LSTVIDEO[@]}"

echo " Select Video, audio(s) &/or subtitle(s) streams, one or severale:"
echo " Note: extracted files saved in source directory."
echo
echo " *[↵]     > extract all streams"
echo "  [0 2 5] > example for select streams"
echo "  [q]     > for exit"

while true; do
	read -r -e -p "-> " rpstreamch
	rpstreamch_parsed="${rpstreamch// /}"					# For test
	if [ -z "$rpstreamch" ]; then							# If -map 0
		# Construct arrays
		VINDEX=( "${ffprobe_StreamIndex[@]}" )
		VCODECNAME=("${ffprobe_Codec[@]}")
		break

	elif [[ "$rpstreamch_parsed" == "q" ]]; then			# Quit
		Restart

	elif ! [[ "$rpstreamch_parsed" =~ ^-?[0-9]+$ ]]; then	# Not integer retry
		Echo_Mess_Error "Map option must be an integer"

	elif [[ "$rpstreamch_parsed" =~ ^-?[0-9]+$ ]]; then		# If valid integer continue
		# Reset streams_invalid
		unset streams_invalid

		# Construct arrays
		VINDEX=()
		VCODECNAME=()
		IFS=" " read -r -a VINDEX <<< "$rpstreamch"
		for i in "${VINDEX[@]}"; do
			VCODECNAME+=("${ffprobe_Codec[$i]}")
		done

		# Test if selected streams are valid
		for i in "${VINDEX[@]}"; do
			if [[ -z "${ffprobe_StreamIndex[$i]}" ]]; then
				Echo_Mess_Error "The stream $i does not exist"
				streams_invalid="1"
			fi
		done

		# If no error continue
		if [[ -z "$streams_invalid" ]]; then
			break
		fi

	fi
done

# Start time counter
START=$(date +%s)

echo
Echo_Separator_Light

for files in "${LSTVIDEO[@]}"; do

	for i in ${!VINDEX[*]}; do

		case "${VCODECNAME[i]}" in
			h264) FILE_EXT=mkv ;;
			hevc) FILE_EXT=mkv ;;
			av1) FILE_EXT=mkv ;;
			mpeg4) FILE_EXT=mkv ;;
			mpeg2video)
				MPEG2EXTRACT="1"
				FILE_EXT=mkv
				;;
			vp9) FILE_EXT=mkv ;;

			ac3) FILE_EXT=ac3 ;;
			eac3) FILE_EXT=eac3 ;;
			dts) FILE_EXT=dts ;;
			mp3) FILE_EXT=mp3 ;;
			aac) FILE_EXT=m4a ;;
			vorbis) FILE_EXT=ogg ;;
			opus) FILE_EXT=opus ;;
			flac) FILE_EXT=flac ;;
			pcm_s16le) FILE_EXT=wav ;;
			pcm_s24le) FILE_EXT=wav ;;
			pcm_s32le) FILE_EXT=wav ;;
			pcm_dvd)
				DVDPCMEXTRACT="1"
				FILE_EXT=wav
				;;

			subrip)
				FILE_EXT=srt ;;
			ass) FILE_EXT=ass ;;
			hdmv_pgs_subtitle) FILE_EXT=sup ;;
			dvd_subtitle)
				MKVEXTRACT="1"
				FILE_EXT=idx
				;;
			esac

			# Extract
			if [ "$MKVEXTRACT" = "1" ]; then
				mkvextract "$files" tracks "${VINDEX[i]}":"${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT"

			elif [ "$MPEG2EXTRACT" = "1" ]; then
				"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -fflags +genpts -analyzeduration 1G -probesize 1G -i "$files" \
					$FFMPEG_PROGRESS \
					-c copy -map 0:"${VINDEX[i]}" "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" \
					| ProgressBar "${files%.*}-Stream-${VINDEX[i]}.$FILE_EXT" "" "" "Extract"

			elif [ "$DVDPCMEXTRACT" = "1" ]; then
				"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "$files" \
					$FFMPEG_PROGRESS \
					-map 0:"${VINDEX[i]}" -acodec pcm_s16le -ar 48000 \
					"${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" \
					| ProgressBar "${files%.*}-Stream-${VINDEX[i]}.$FILE_EXT" "" "" "Extract"

			else
				"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "$files" \
				$FFMPEG_PROGRESS \
				-c copy -map 0:"${VINDEX[i]}" "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" \
				| ProgressBar "${files%.*}-Stream-${VINDEX[i]}.$FILE_EXT" "" "" "Extract"
			fi

			# For validation test
			filesInLoop+=( "${files%.*}-Stream-${VINDEX[i]}.$FILE_EXT" )

		done
done

# End time counter
END=$(date +%s)

# Check Target if valid
Test_Target_File "0" "mixed" "${filesInLoop[@]}"

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" ""
}
Video_Cut_File() {						# Option 14 	- Cut video
# Local variables
local qcut0
local qcut
local CutStart
local CutEnd
local split_output
local CutSegment
# Array
filesInLoop=()

Display_Media_Stats_One "${LSTVIDEO[@]}"

echo " Enter duration of cut or split:"
echo " Notes: * for hours :   HOURS:MM:SS.MICROSECONDS"
echo "        * for minutes : MM:SS.MICROSECONDS"
echo "        * for seconds : SS.MICROSECONDS"
echo "        * microseconds is optional, you can not indicate them"
echo
echo " Examples of input:"
echo "  [s.20]        > remove video after 20 second"
echo "  [e.01:11:20]  > remove video before 1 hour 11 minutes 20 second"
echo "  [p.00:02:00]  > split video in parts of 2 minutes"
echo
echo "  [s.time]      > for remove end"
echo "  [e.time]      > for remove start"
echo "  [t.time.time] > for remove start and end"
echo "  [p.time]      > for split"
echo "  [q]           > for exit"
while :
do
read -r -e -p "-> " qcut0
case $qcut0 in
	s.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')												# Replace [.] by [ ] in variable
		CutStart="$ffprobe_StartTime"
		CutEnd=$(echo "$qcut" | awk '{print $2;}')
		break
	;;
	e.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')
		CutStart=$(echo "$qcut" | awk '{print $2;}')
		CutEnd="$ffprobe_Duration"
		break
	;;
	t.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')
		CutStart=$(echo "$qcut" | awk '{print $2;}')
		CutEnd=$(echo "$qcut" | awk '{print $3;}')
		break
	;;
	p.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')
		CutSegment=$(echo "$qcut" | awk '{print $2;}')
		break
	;;
	"q"|"Q")
		Restart
		break
	;;
		*)
			echo
			Echo_Mess_Invalid_Answer
			echo
		;;
	esac
	done

# Start time counter
START=$(date +%s)

echo
Echo_Separator_Light

# Segment
if [[ -n "$CutSegment" ]]; then
	# Create file path & directory for segmented files
	split_output_files="${LSTVIDEO[0]##*/}"
	split_output="splitted_raw_${split_output_files%.*}"
	if ! [[ -d "$split_output" ]]; then
		mkdir "$split_output"
	fi

	# Segment
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -analyzeduration 1G -probesize 1G -y -i "${LSTVIDEO[0]}" $FFMPEG_PROGRESS \
		-f segment -segment_time "$CutSegment" \
		-c copy -map 0 -map_metadata 0 -reset_timestamps 1 \
		"$split_output"/"${split_output_files%.*}"_segment_%04d."${LSTVIDEO[0]##*.}" \
		| ProgressBar "${LSTVIDEO[0]}" "" "" "Segment"

	# map array of target files
	mapfile -t filesInLoop < <(find "$split_output" -maxdepth 1 -type f -regextype posix-egrep \
		-iregex '.*\.('${LSTVIDEO[0]##*.}')$' 2>/dev/null | sort)

# Cut
else
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -analyzeduration 1G -probesize 1G -y -i "${LSTVIDEO[0]}" $FFMPEG_PROGRESS \
		-ss "$CutStart" -to "$CutEnd" \
		-c copy -map 0 -map_metadata 0 "${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}" \
		| ProgressBar "${LSTVIDEO[0]}" "" "" "Cut"
fi

# End time counter
END=$(date +%s)

# Check Target if valid
if [[ -n "$CutSegment" ]]; then
	Test_Target_File "0" "video" "${filesInLoop[@]}"
else
	Test_Target_File "0" "video" "${LSTVIDEO[0]%.*}.cut.${LSTVIDEO[0]##*.}"
fi

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"
total_source_files_size=$(Calc_Files_Size "${LSTVIDEO[@]}")
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" "$total_source_files_size"
}
Video_Split_By_Chapter() {				# Option 15 	- Split by chapter
Display_Media_Stats_One "${LSTVIDEO[@]}"

if [[ -n "$ffprobe_ChapterNumberFormated" ]]; then
	read -r -p " Split by chapter, continue? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			mkvmerge -o "${LSTVIDEO[0]%.*}"-Chapter.mkv --split chapters:all "${LSTVIDEO[0]}"
		;;
		*)
			Restart
		;;
	esac
else
	echo
	Echo_Mess_Error "${LSTVIDEO[0]} has no chapter"
	echo
fi
}
Video_Multiple_Extention_Check() {		# If sources video multiple extention question
if [ "$NBVEXT" -gt "1" ]; then
	echo
	echo " Different source video file extensions have been found, would you like to select one or more?"
	echo " Note: * It is recommended not to batch process different sources, in order to control the result as well as possible."
	echo
	echo " Extensions found: ${LSTVIDEOEXT[*]}"
	echo
	echo "  [avi]     > Example of input format for select one extension"
	echo "  [mkv|mp4] > Example of input format for multiple selection"
	echo " *[↵]       > for no selection"
	echo "  [q]       > for exit"
	read -r -e -p "-> " NEW_VIDEO_EXT_AVAILABLE
	if [ "$NEW_VIDEO_EXT_AVAILABLE" = "q" ]; then
		Restart
	elif test -n "$NEW_VIDEO_EXT_AVAILABLE"; then
		mapfile -t LSTVIDEO < <(find "$PWD" -maxdepth 1 -type f -regextype posix-egrep \
			-regex '.*\.('$NEW_VIDEO_EXT_AVAILABLE')$' 2>/dev/null | sort)
	fi
fi
}

## AUDIO
Audio_FFmpeg_cmd() {					# FFmpeg audio encoding loop
# Local variables
local PERC
local total_source_files_size
local total_target_files_size
local START
local END
local file_test
local filesRejectRm
# Array
filesInLoop=()
filesOverwrite=()
filesPass=()
filesSourcePass=()
filesReject=()

# Start time counter
START=$(date +%s)

# Copy $extcont for test and reset inside loop
ExtContSource="$extcont"

# Disable the enter key
EnterKeyDisable

# Encoding
echo
Echo_Separator_Light
for files in "${LSTAUDIO[@]}"; do
	# Reset $extcont
	extcont="$ExtContSource"
	# Test Volume and set normalization variable
	Audio_Peak_Normalization_Action
	# Channel test mono or stereo
	Audio_False_Stereo_Action
	# Silence detect & remove, at start & end (only for wav and flac source files)
	Audio_Silent_Detection_Action
	# Opus & AAC auto adapted bitrate
	Audio_Opus_AAC_Auto_Bitrate
	# Flac & WavPack sampling rate limitation
	Audio_Sample_Rate_Limitation
	# Flac & WavPack bit depht source detection (if not set)
	Audio_Bit_Depth_Detection
	# Stream set & cover extract
	Audio_Cover_Process
	# Stock files pass in loop
	filesInLoop+=("$files")
	# For progress bar
	if [[ -z "$VERBOSE" && "${#LSTAUDIO[@]}" = "1" ]] \
	|| [[ -z "$VERBOSE" && "${#LSTAUDIO[@]}" -gt "1" && "$NPROC" = "0" ]]; then
		Media_Source_Info_Record "$files"
	fi
	# If source extention same as target
	if [[ "${files##*.}" = "$extcont" ]]; then
		extcont="new.$extcont"
		filesOverwrite+=("$files")
	else
		filesOverwrite+=("$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')")
	fi

	# Encoding / Test integrity / Untagged test
	(
	if [[ -n "$Untagged" ]]; then
		ProgressBar "" "${#filesInLoop[@]}" "${#LSTAUDIO[@]}" "Search files without tag: $untagged_label" "1"
		"$ffprobe_bin" -hide_banner -loglevel panic -select_streams a -show_streams -show_format "$files" \
			| grep -i "$untagged_type" 1>/dev/null || echo "  $files" >> "$FFMES_CACHE_UNTAGGED"
	else
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "$files" $FFMPEG_PROGRESS \
			$afilter $astream $acodec $akb $abitdeph \
			$asamplerate $confchan "${files%.*}".$extcont \
			| ProgressBar "$files" "${#filesInLoop[@]}" "${#LSTAUDIO[@]}" "Encoding"
	fi
	) &
	if [[ $(jobs -r -p | wc -l) -ge $NPROC ]]; then
		wait -n
	fi

done
wait

# Test results
if [[ -z "$Untagged" ]]; then

	# Check Target if valid (size test) and clean
	extcont="$ExtContSource"	# Reset $extcont
	for (( i=0; i<=$(( ${#filesInLoop[@]} - 1 )); i++ )); do

		# File to test
		if [[ "${filesInLoop[i]%.*}" = "${filesOverwrite[i]%.*}" ]]; then
			file_test="${filesInLoop[i]%.*}.new.$extcont"
		else
			file_test="${filesInLoop[i]%.*}.$extcont"
		fi

		# Tests & populate file in arrays
		# File rejected
		if ! "$ffmpeg_bin" -v error -t 1 -i "$file_test" -max_muxing_queue_size 9999 -f null - &>/dev/null ; then
			filesRejectRm="$file_test"
			filesReject+=("$file_test")
			# File passed
			else
				if [[ "${filesInLoop[i]%.*}" = "${filesOverwrite[i]%.*}" ]]; then
					mv "${filesInLoop[i]}" "${filesInLoop[i]%.*}".back."$extcont" 2>/dev/null
					mv "${filesInLoop[i]%.*}".new."$extcont" "${filesInLoop[i]}" 2>/dev/null
					filesPass+=("${filesInLoop[i]}")
					filesSourcePass+=("${filesInLoop[i]%.*}".back."$extcont")
				else
					filesPass+=("${filesInLoop[i]%.*}"."$extcont")
					filesSourcePass+=("${filesInLoop[i]}")
				fi
		fi

		# Progress
		ProgressBar "$files" "$((i+1))" "${#filesInLoop[@]}" "Validation" "1"

		# Remove rejected
		rm "$filesRejectRm" 2>/dev/null

	done

fi

# Enable the enter key
EnterKeyEnable

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"
total_source_files_size=$(Calc_Files_Size "${filesSourcePass[@]}")
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")		# Size difference between source and target

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
if [[ -z "$Untagged" ]]; then
	Display_End_Encoding_Message "${#filesPass[@]}" "${#LSTAUDIO[@]}" "$total_target_files_size" "$total_source_files_size"
else
	Echo_Separator_Light
	if [ -s "$FFMES_CACHE_UNTAGGED" ]; then
		echo " $(wc -l < "$FFMES_CACHE_UNTAGGED") file(s) without tag $untagged_label:"
		cat "$FFMES_CACHE_UNTAGGED"
	else
		echo " No file untagged."
	fi
	Display_End_Encoding_Message "${#filesInLoop[@]}" "${#LSTAUDIO[@]}" "" ""
fi
}
Audio_Peak_Normalization_Action() {		# Part of Audio_FFmpeg_cmd loop
# Local variables
local TestDB
local GREPVOLUME

if [ "$PeakNorm" = "1" ]; then

	TestDB=$("$ffmpeg_bin" -i "$files" -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
	if [ -n "$afilter" ] && [[ "$codeca" = "libopus" || "$AudioCodecType" = "libopus" ]]; then			# Opus trick for peak normalization
		# Apply norm. if grep value is negative & greater default value
		if [[ "$TestDB" = *"-"* ]] && (( $(echo "${TestDB/-/} > $PeakNormDB" | bc -l) )); then
			GREPVOLUME="$(echo "${TestDB/-/}" | awk -v var="$PeakNormDB" '{print $1-var}')dB"
			afilter="-af aformat=channel_layouts='7.1|6.1|5.1|stereo',volume=$GREPVOLUME -mapping_family 1"
		else
			afilter="-af aformat=channel_layouts='7.1|6.1|5.1|stereo' -mapping_family 1"
		fi
	else
		if [[ "$TestDB" = *"-"* ]] && (( $(echo "${TestDB/-/} > $PeakNormDB" | bc -l) )); then
			GREPVOLUME="$(echo "${TestDB/-/}" | awk -v var="$PeakNormDB" '{print $1-var}')dB"
			afilter="-af volume=$GREPVOLUME"
		else
			afilter=""
		fi
	fi

fi
}
Audio_False_Stereo_Action() {			# Part of Audio_FFmpeg_cmd loop
local TESTLEFT
local TESTRIGHT
if [ "$TestFalseStereo" = "1" ]; then
	TESTLEFT=$("$ffmpeg_bin" -i "$files" -map_channel 0.0.0 -f md5 - 2>/dev/null)
	TESTRIGHT=$("$ffmpeg_bin" -i "$files" -map_channel 0.0.1 -f md5 - 2>/dev/null)
	if [ "$TESTLEFT" = "$TESTRIGHT" ]; then
		confchan="-channel_layout mono"
	else
		confchan=""
	fi
fi
}
Audio_Silent_Detection_Action() {		# Part of Audio_FFmpeg_cmd loop
local test_duration
if [ "$SilenceDetect" = "1" ]; then
	if [[ "${files##*.}" = "wav" || "${files##*.}" = "flac" ]]; then
		test_duration=$(mediainfo --Output="General;%Duration%" "${files%.*}"."${files##*.}")
		if [[ "$test_duration" -gt 10000 ]] ; then
			"$sox_bin" "${files%.*}"."${files##*.}" temp-out."${files##*.}" \
				silence 1 0.2 -85d reverse silence 1 0.2 -85d reverse
			rm "${files%.*}"."${files##*.}" &>/dev/null
			mv temp-out."${files##*.}" "${files%.*}"."${files##*.}" &>/dev/null
		fi
	fi
fi
}
Audio_Opus_AAC_Auto_Bitrate() {			# Part of Audio_FFmpeg_cmd loop
local TestBitrate
if [ "$AdaptedBitrate" = "1" ]; then
	TestBitrate=$(mediainfo --Output="General;%OverallBitRate%" "$files")
	if ! [[ "$TestBitrate" =~ ^[0-9]+$ ]] ; then		# If not integer = file not valid
		akb=""
	elif [ "$TestBitrate" -ge 1 ] && [ "$TestBitrate" -le 96000 ]; then
		akb="-b:a 64K"
		asamplerate="-cutoff 15000"
	elif [ "$TestBitrate" -ge 96001 ] && [ "$TestBitrate" -le 128000 ]; then
		akb="-b:a 96K"
		asamplerate="-cutoff 16000"
	elif [ "$TestBitrate" -ge 129000 ] && [ "$TestBitrate" -le 160000 ]; then
		akb="-b:a 128K"
		asamplerate="-cutoff 16000"
	elif [ "$TestBitrate" -ge 161000 ] && [ "$TestBitrate" -le 192000 ]; then
		akb="-b:a 160K"
		asamplerate="-cutoff 17000"
	elif [ "$TestBitrate" -ge 193000 ] && [ "$TestBitrate" -le 256000 ]; then
		akb="-b:a 192K"
		asamplerate="-cutoff 18000"
	elif [ "$TestBitrate" -ge 257000 ] && [ "$TestBitrate" -le 280000 ]; then
		akb="-b:a 220K"
		asamplerate="-cutoff 19000"
	elif [ "$TestBitrate" -ge 281000 ] && [ "$TestBitrate" -le 320000 ]; then
		akb="-b:a 256K"
		asamplerate="-cutoff 20000"
	elif [ "$TestBitrate" -ge 321000 ] && [ "$TestBitrate" -le 400000 ]; then
		akb="-b:a 280K"
		asamplerate="-cutoff 20000"
	elif [ "$TestBitrate" -ge 400001 ]; then
		akb="-b:a 320K"
		asamplerate="-cutoff 20000"
	else
		akb="-b:a 320K"
		asamplerate="-cutoff 20000"
	fi
fi
}
Audio_Sample_Rate_Limitation() {		# Part of Audio_FFmpeg_cmd loop
local TestSamplingRate
if [[ -z "$asamplerate" ]]; then
	if [[ "$extcont" = "flac" ]] || [[ "$extcont" = "wv" ]]; then
		TestSamplingRate=$("$ffprobe_bin" -analyzeduration 1G -probesize 1G -v panic -show_entries stream=sample_rate -print_format csv=p=0 "$files")
		if [[ "$TestSamplingRate" -gt "384000" ]]; then
				asamplerate="-ar 384000"
		else
				asamplerate="-ar $TestSamplingRate"
		fi
	fi
fi
}
Audio_Bit_Depth_Detection() {			# Part of Audio_FFmpeg_cmd loop
local TestBitDepth
if ! [[ "$akb" == *"sample_fmt"* ]]; then
	if [[ "$AudioCodecType" = "flac" ]] || [[ "$AudioCodecType" = "wavpack" ]]; then
		TestBitDepth=$("$ffprobe_bin" -analyzeduration 1G -probesize 1G -v panic -show_entries stream=sample_fmt -print_format csv=p=0 "$files")
		if [[ "$TestBitDepth" == "u8"* ]]; then			# 8 bits
			if [[ "$AudioCodecType" = "flac" ]]; then
				abitdeph="-sample_fmt s16"
			elif [[ "$AudioCodecType" = "wavpack" ]]; then
				abitdeph="-sample_fmt u8p"
			fi
		elif [[ "$TestBitDepth" == "s16"* ]]; then		# 16 bits
			if [[ "$AudioCodecType" = "flac" ]]; then
				abitdeph="-sample_fmt s16"
			elif [[ "$AudioCodecType" = "wavpack" ]]; then
				abitdeph="-sample_fmt s16p"
			fi
		elif [[ "$TestBitDepth" == "s32"* ]] || [[ "$TestBitDepth" = "fltp" ]]; then	# 32 bits
			if [[ "$AudioCodecType" = "flac" ]]; then
				abitdeph="-sample_fmt s32"
			elif [[ "$AudioCodecType" = "wavpack" ]]; then
				abitdeph="-sample_fmt s32p"
			fi
		elif [[ "$TestBitDepth" == "s64"* ]] || [[ "$TestBitDepth" = "dblp" ]]; then	# 64 bits
			if [[ "$AudioCodecType" = "flac" ]]; then
				abitdeph="-sample_fmt s32"
			elif [[ "$AudioCodecType" = "wavpack" ]]; then
				abitdeph="-sample_fmt s32p"
			fi
		fi
	fi
fi
}
Audio_Cover_Process() {					# Part of Audio_FFmpeg_cmd loop
if [ "$ExtractCover" = "0" ]; then

	for cover in cover.*; do
		astream="-map 0:a"
		if [ ! -e "$cover" ]; then
			"$ffmpeg_bin" -n -i "$files" "${files%.*}".jpg 2>/dev/null
			mv "${files%.*}".jpg "${files%/*}"/cover.jpg 2>/dev/null
			mv "${files%.*}".jpg cover.jpg 2>/dev/null
			break
		fi
	done

elif [ "$ExtractCover" = "1" ] && [ "$extcont" != "opus" ]; then
	astream="-map 0 -c:v copy"

else
	astream="-map 0:a"

fi
}
Audio_Channels_Config() {				#
if [ "$ffmes_option" -lt 20 ]; then          # if profile 0 or 1 display
	Display_Video_Custom_Info_choice
fi
if [[ "$codeca" = "libopus" || "$AudioCodecType" = "libopus" ]]; then
	echo " Choose desired audio channels configuration:"
	echo
	echo "  [1] > for channel_layout 1.0 (Mono)"
	echo "  [2] > for channel_layout 2.0 (Stereo)"
	echo "  [3] > for channel_layout 3.0 (FL+FR+FC)"
	echo "  [4] > for channel_layout 5.1 (FL+FR+FC+LFE+BL+BR)"
	echo " *[↵] > for no change"
	echo "  [q] > for exit"
	read -r -e -p "-> " rpchan
	if [ "$rpchan" = "q" ]; then
		Restart
	elif [ "$rpchan" = "1" ]; then
		confchan="-channel_layout mono"
		rpchannel="1.0 (Mono)"
	elif [ "$rpchan" = "2" ]; then
		confchan="-channel_layout stereo"
		rpchannel="2.0 (Stereo)"
	elif [ "$rpchan" = "3" ]; then
		confchan="-channel_layout 3.0"
		rpchannel="3.0 (FL+FR+FC)"
	elif [ "$rpchan" = "4" ]; then
		confchan="-channel_layout 5.1"
		rpchannel="5.1 (FL+FR+FC+LFE+BL+BR)"
	else
		afilter="-af aformat=channel_layouts='7.1|6.1|5.1|stereo' -mapping_family 1"
		rpchannel="No change"
	fi
else
	echo
	echo " Choose desired audio channels configuration:"
	echo
	echo "  [1] > for channel_layout 1.0 (Mono)"
	echo "  [2] > for channel_layout 2.0 (Stereo)"
	echo "  [3] > for channel_layout 2.1 (FL+FR+LFE)"
	echo "  [4] > for channel_layout 3.0 (FL+FR+FC)"
	echo "  [5] > for channel_layout 3.1 (FL+FR+FC+LFE)"
	echo "  [6] > for channel_layout 4.0 (FL+FR+FC+BC)"
	echo "  [7] > for channel_layout 4.1 (FL+FR+FC+LFE+BC)"
	echo "  [8] > for channel_layout 5.0 (FL+FR+FC+BL+BR)"
	echo "  [9] > for channel_layout 5.1 (FL+FR+FC+LFE+BL+BR)"
	echo " *[↵] > for no change"
	echo "  [q] > for exit"
	read -r -e -p "-> " rpchan
	if [ "$rpchan" = "q" ]; then
		Restart
	elif [ "$rpchan" = "1" ]; then
		confchan="-channel_layout mono"
		rpchannel="1.0 (Mono)"
	elif [ "$rpchan" = "2" ]; then
		confchan="-channel_layout stereo"
		rpchannel="2.0 (Stereo)"
	elif [ "$rpchan" = "3" ]; then
		confchan="-channel_layout 2.1"
		rpchannel="2.1 (FL+FR+LFE)"
	elif [ "$rpchan" = "4" ]; then
		confchan="-channel_layout 3.0"
		rpchannel="3.0 (FL+FR+FC)"
	elif [ "$rpchan" = "5" ]; then
		confchan="-channel_layout 3.1"
		rpchannel="3.1 (FL+FR+FC+LFE)"
	elif [ "$rpchan" = "6" ]; then
		confchan="-channel_layout 4.0"
		rpchannel="4.0 (FL+FR+FC+BC)"
	elif [ "$rpchan" = "7" ]; then
		confchan="-channel_layout 4.1"
		rpchannel="4.1 (FL+FR+FC+LFE+BC)"
	elif [ "$rpchan" = "8" ]; then
		confchan="-channel_layout 5.0"
		rpchannel="5.0 (FL+FR+FC+BL+BR)"
	elif [ "$rpchan" = "9" ]; then
		confchan="-channel_layout 5.1"
		rpchannel="5.1 (FL+FR+FC+LFE+BL+BR)"
	else
		rpchannel="No change"
	fi
fi
}
Audio_PCM_Config() {					# Option 21 	- Audio to wav (PCM)
if [ "$ffmes_option" -lt 20 ]; then		# If in video encoding
	Display_Video_Custom_Info_choice
else							# If not in video encoding
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi
echo " Choose PCM desired configuration:"
echo
echo "         | integer represent. & | sample |   bit |"
echo "         | coding               |   rate | depth |"
echo "         |----------------------|--------|-------|"
echo "  [1]  > | unsigned             |  44kHz |     8 |"
echo "  [2]  > | signed               |  44kHz |     8 |"
echo "  [3]  > | signed little-endian |  44kHz |    16 |"
echo "  [4]  > | signed little-endian |  44kHz |    24 |"
echo "  [5]  > | signed little-endian |  44kHz |    32 |"
echo "  [6]  > | unsigned             |  48kHz |     8 |"
echo "  [7]  > | signed               |  48kHz |     8 |"
echo "  [8]  > | signed little-endian |  48kHz |    16 |"
echo "  [9]  > | signed little-endian |  48kHz |    24 |"
echo "  [10] > | signed little-endian |  48kHz |    32 |"
echo "  [11] > | unsigned             |   auto |     8 |"
echo "  [12] > | signed               |   auto |     8 |"
echo " *[13] > | signed little-endian |   auto |    16 |"
echo "  [14] > | signed little-endian |   auto |    24 |"
echo "  [15] > | signed little-endian |   auto |    32 |"
echo "  [q]  > | for exit"
read -r -e -p "-> " rpakb
if [ "$rpakb" = "q" ]; then
	Restart
elif [ "$rpakb" = "1" ]; then
	acodec="-acodec u8"
	asamplerate="-ar 44100"
elif [ "$rpakb" = "2" ]; then
	acodec="-acodec s8"
	asamplerate="-ar 44100"
elif [ "$rpakb" = "3" ]; then
	acodec="-acodec pcm_s16le"
	asamplerate="-ar 44100"
elif [ "$rpakb" = "4" ]; then
	acodec="-acodec pcm_s24le"
	asamplerate="-ar 44100"
elif [ "$rpakb" = "5" ]; then
	acodec="-acodec pcm_s32le"
	asamplerate="-ar 44100"
elif [ "$rpakb" = "6" ]; then
	acodec="-acodec u8"
	asamplerate="-ar 48000"
elif [ "$rpakb" = "7" ]; then
	acodec="-acodec s8"
	asamplerate="-ar 48000"
elif [ "$rpakb" = "8" ]; then
	acodec="-acodec pcm_s16le"
	asamplerate="-ar 48000"
elif [ "$rpakb" = "9" ]; then
	acodec="-acodec pcm_s24le"
	asamplerate="-ar 48000"
elif [ "$rpakb" = "10" ]; then
	acodec="-acodec pcm_s32le"
	asamplerate="-ar 48000"
elif [ "$rpakb" = "11" ]; then
	acodec="-acodec u8"
	asamplerate=""
elif [ "$rpakb" = "12" ]; then
	acodec="-acodec s8"
	asamplerate=""
elif [ "$rpakb" = "13" ]; then
	acodec="-acodec pcm_s16le"
	asamplerate=""
elif [ "$rpakb" = "14" ]; then
	acodec="-acodec pcm_s24le"
	asamplerate=""
elif [ "$rpakb" = "15" ]; then
	acodec="-acodec pcm_s32le"
	asamplerate=""
else
	acodec="-acodec pcm_s16le"
	asamplerate=""
fi
}
Audio_FLAC_Config() {					# Option 1,22 	- Conf audio/video flac, audio to flac
if [ "$ffmes_option" -lt 20 ]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi
	echo " Choose FLAC desired configuration:"
	echo " Notes: * libFLAC uses a compression level parameter that varies from 0 (fastest) to 8 (slowest)."
	echo "          The compressed files are always perfect, lossless representations of the original data."
	echo "          Although the compression process involves a tradeoff between speed and size, "
	echo "          the decoding process is always quite fast and not dependent on the level of compression."
	echo "        * If you choose and audio bit depth superior of source file, the encoding will fail."
	echo "        * Option tagued [auto] = same value of source file."
	echo "        * Max value of sample rate is 384kHz."
	echo
	echo " Choose a number:"
	echo
	echo "        | comp. | sample |   bit |"
	echo "        | level |   rate | depth |"
	echo "        |-------|--------|-------|"
	echo "  [1] > |   12  |  44kHz |    16 |"
	echo "  [2] > |   12  |  44kHz |    24 |"
	echo "  [3] > |   12  |  44kHz |  auto |"
	echo "  [4] > |   12  |  48kHz |    16 |"
	echo "  [5] > |   12  |  48kHz |    24 |"
	echo "  [6] > |   12  |  48kHz |  auto |"
	echo "  [7] > |   12  |   auto |    16 |"
	echo "  [8] > |   12  |   auto |    24 |"
	echo " *[9] > |   12  |   auto |  auto |"
	echo "  [q] > | for exit"
	read -r -e -p "-> " rpakb
	if [ "$rpakb" = "q" ]; then
		Restart
	elif echo "$rpakb" | grep -q 'c' ; then
		akb="$rpakb"
	elif [ "$rpakb" = "1" ]; then
		akb="-compression_level 12 -sample_fmt s16"
		asamplerate="-ar 44100"
	elif [ "$rpakb" = "2" ]; then
		akb="-compression_level 12 -sample_fmt s32"
		asamplerate="-ar 44100"
	elif [ "$rpakb" = "3" ]; then
		akb="-compression_level 12"
		asamplerate="-ar 44100"
	elif [ "$rpakb" = "4" ]; then
		akb="-compression_level 12 -sample_fmt s16"
		asamplerate="-ar 48000"
	elif [ "$rpakb" = "5" ]; then
		akb="-compression_level 12 -sample_fmt s32"
		asamplerate="-ar 48000"
	elif [ "$rpakb" = "6" ]; then
		akb="-compression_level 12"
		asamplerate="-ar 48000"
	elif [ "$rpakb" = "7" ]; then
		akb="-compression_level 12 -sample_fmt s16"
		asamplerate=""
	elif [ "$rpakb" = "8" ]; then
		akb="-compression_level 12 -sample_fmt s32"
		asamplerate=""
	elif [ "$rpakb" = "9" ]; then
		akb="-compression_level 12"
		asamplerate=""
	else
		akb="-compression_level 12"
		asamplerate=""
	fi
	}
Audio_WavPack_Config() {				# Option 23 	- audio to wavpack
if [ "$ffmes_option" -lt 20 ]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi
    echo " Choose WavPack desired configuration:"
    echo " Notes: * WavPack uses a compression level parameter that varies from 0 (fastest) to 8 (slowest)."
	echo "          The value 3 allows a very good compression without having a huge encoding time."
	echo "        * Option tagued [auto] = same value of source file."
	echo "        * Max value of sample rate is 384kHz."
    echo
    echo " Choose a number:"
    echo
    echo "         | comp. | sample |   bit |"
    echo "         | level |   rate | depth |"
    echo "         |-------|--------|-------|"
    echo "  [1]  > |    3  |  44kHz |    16 |"
    echo "  [2]  > |    3  |  44kHz | 24/32 |"
    echo "  [3]  > |    3  |  44kHz |  auto |"
    echo "  [4]  > |    1  |  44kHz |  auto |"
    echo "  [5]  > |    3  |  48kHz |    16 |"
    echo "  [6]  > |    3  |  48kHz | 24/32 |"
    echo "  [7]  > |    3  |  48kHz |  auto |"
    echo "  [8]  > |    1  |  48kHz |  auto |"
    echo "  [9]  > |    3  |   auto |    16 |"
    echo "  [10] > |    3  |   auto | 24/32 |"
    echo " *[11] > |    3  |   auto |  auto |"
    echo "  [12] > |    1  |   auto |  auto |"
	echo "  [q] >  | for exit"
	read -r -e -p "-> " rpakb
	if [ "$rpakb" = "q" ]; then
		Restart
	elif echo "$rpakb" | grep -q 'c' ; then
		akb="$rpakb"
	elif [ "$rpakb" = "1" ]; then
		akb="-compression_level 3 -sample_fmt s16p"
		asamplerate="-ar 44100"
	elif [ "$rpakb" = "2" ]; then
		akb="-compression_level 3 -sample_fmt s32p"
		asamplerate="-ar 44100"
	elif [ "$rpakb" = "3" ]; then
		akb="-compression_level 3"
		asamplerate="-ar 44100"
	elif [ "$rpakb" = "4" ]; then
		akb="-compression_level 1"
		asamplerate="-ar 44100"
	elif [ "$rpakb" = "5" ]; then
		akb="-compression_level 3 -sample_fmt s16p"
		asamplerate="-ar 48000"
	elif [ "$rpakb" = "6" ]; then
		akb="-compression_level 3 -sample_fmt s32p"
		asamplerate="-ar 48000"
	elif [ "$rpakb" = "7" ]; then
		akb="-compression_level 3"
		asamplerate="-ar 48000"
	elif [ "$rpakb" = "8" ]; then
		akb="-compression_level 1"
		asamplerate="-ar 48000"
	elif [ "$rpakb" = "9" ]; then
		akb="-compression_level 3  -sample_fmt s16p"
		asamplerate=""
	elif [ "$rpakb" = "10" ]; then
		akb="-compression_level 3 -sample_fmt s32p"
		asamplerate=""
	elif [ "$rpakb" = "11" ]; then
		akb="-compression_level 3"
		asamplerate=""
	elif [ "$rpakb" = "12" ]; then
		akb="-compression_level 1"
		asamplerate=""
	else
		akb="-compression_level 3"
		asamplerate=""
	fi
	}
Audio_Opus_Config() {					# Option 1,26 	- Conf audio/video opus, audio to opus (libopus)
if [ "$ffmes_option" -lt 20 ]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi
echo " Choose Opus (libopus) desired configuration:"
echo " Note: * All options have cutoff at 48kHz"
echo '       * With the "adaptive bitrate" option, ffmes will choose'
echo '         each target file the number of kb/s to apply according'
echo '         to the table.'
echo
echo "         | kb/s | Descriptions            |"
echo "         |------|-------------------------|"
echo "  [1]  > |  64k | comparable to mp3 96k   |"
echo "  [2]  > |  96k | comparable to mp3 120k  |"
echo "  [3]  > | 128k | comparable to mp3 160k  |"
echo "  [4]  > | 160k | comparable to mp3 192k  |"
echo "  [5]  > | 192k | comparable to mp3 280k  |"
if [[ "$AudioCodecType" = "libopus" ]]; then
	echo "  [6]  > | 220k | comparable to mp3 320k  |"
else
	echo " *[6]  > | 220k | comparable to mp3 320k  |"
fi
echo "  [7]  > | 256k | 5.1 audio source        |"
echo "  [8]  > | 320k | 7.1 audio source        |"
echo "  [9]  > | 450k | 7.1 audio source        |"
echo "  [10] > | 510k | highest bitrate of opus |"
if [[ "$AudioCodecType" = "libopus" ]]; then
	echo "  -----------------------------------------"
	echo " *[X]  > |    adaptive bitrate     |"
	echo "         |-------------------------|"
	echo "         | Target |     Source     |"
	echo "         |--------|----------------|"
	echo "         |   64k  |   1kb ->  96kb |"
	echo "         |   96k  |  97kb -> 128kb |"
	echo "         |  128k  | 129kb -> 160kb |"
	echo "         |  160k  | 161kb -> 192kb |"
	echo "         |  192k  | 193kb -> 256kb |"
	echo "         |  220k  | 257kb -> 280kb |"
	echo "         |  256k  | 281kb -> 320kb |"
	echo "         |  280k  | 321kb -> 400kb |"
	echo "         |  320k  | 400kb -> ∞     |"
fi
echo "  [q]  > | for exit"
read -r -e -p "-> " rpakb
if [ "$rpakb" = "q" ]; then
	Restart
elif [ "$rpakb" = "1" ]; then
	akb="-b:a 64K"
elif [ "$rpakb" = "2" ]; then
	akb="-b:a 96K"
elif [ "$rpakb" = "3" ]; then
	akb="-b:a 128K"
elif [ "$rpakb" = "4" ]; then
	akb="-b:a 160K"
elif [ "$rpakb" = "5" ]; then
	akb="-b:a 192K"
elif [ "$rpakb" = "6" ]; then
	akb="-b:a 220K"
elif [ "$rpakb" = "7" ]; then
	akb="-b:a 256K"
elif [ "$rpakb" = "8" ]; then
	akb="-b:a 320K"
elif [ "$rpakb" = "9" ]; then
	akb="-b:a 450K"
elif [ "$rpakb" = "10" ]; then
	akb="-b:a 510K"
elif [ "$rpakb" = "X" ]  && [[ "$codeca" = "libopus" || "$AudioCodecType" = "libopus" ]]; then
	AdaptedBitrate="1"
else
	if [[ "$AudioCodecType" = "libopus" ]]; then
		AdaptedBitrate="1"
	else
		akb="-b:a 220K"
	fi
fi
}
Audio_OGG_Config() {					# Option 1,25 	- Conf audio/video libvorbis, audio to ogg (libvorbis)
if [ "$ffmes_option" -lt 20 ]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi
echo " Choose Ogg (libvorbis) desired configuration:"
echo " Notes: * The reference is the variable bitrate (vbr), it allows to allocate more information to"
echo "          compressdifficult passages and to save space on less demanding passages."
echo "        * A constant bitrate (cbr) is valid for streaming in order to maintain bitrate regularity."
echo "        * The cutoff allows to lose bitrate on high frequencies,"
echo "          to gain bitrate on audible frequencies."
echo
echo " For crb:"
echo " [192k] -> Example of input format for desired bitrate"
echo
echo " For vbr:"
echo
echo "                |  cut  |"
echo "         | kb/s |  off  |"
echo "         |------|-------|"
echo "  [1]  > |  96k | 14kHz |"
echo "  [2]  > | 112k | 15kHz |"
echo "  [3]  > | 128k | 15kHz |"
echo "  [4]  > | 160k | 16kHz |"
echo "  [5]  > | 192k | 17kHz |"
echo "  [6]  > | 224k | 18kHz |"
echo "  [7]  > | 256k | 19kHz |"
echo "  [8]  > | 320k | 20kHz |"
echo " *[9]  > | 500k | 22kHz |"
echo "  [10] > | 500k |  N/A  |"
echo "  [q]  > | for exit"
read -r -e -p "-> " rpakb
if [ "$rpakb" = "q" ]; then
	Restart
elif echo "$rpakb" | grep -q 'k' ; then
	akb="-b:a $rpakb"
	asamplerate=""
elif [ "$rpakb" = "1" ]; then
	akb="-q 2"
	asamplerate="-cutoff 14000 -ar 44100"
elif [ "$rpakb" = "2" ]; then
	akb="-q 3"
	asamplerate="-cutoff 15000 -ar 44100"
elif [ "$rpakb" = "3" ]; then
	akb="-q 4"
	asamplerate="-cutoff 15000 -ar 44100"
elif [ "$rpakb" = "4" ]; then
	akb="-q 5"
	asamplerate="-cutoff 16000 -ar 44100"
elif [ "$rpakb" = "5" ]; then
	akb="-q 6"
	asamplerate="-cutoff 17000 -ar 44100"
elif [ "$rpakb" = "6" ]; then
	akb="-q 7"
	asamplerate="-cutoff 18000 -ar 44100"
elif [ "$rpakb" = "7" ]; then
	akb="-q 8 "
	asamplerate="-cutoff 19000 -ar 44100"
elif [ "$rpakb" = "8" ]; then
	akb="-q 9"
	asamplerate="-cutoff 20000 -ar 44100"
elif [ "$rpakb" = "9" ]; then
	akb="-q 10"
	asamplerate="-cutoff 22050 -ar 44100"
elif [ "$rpakb" = "10" ]; then
	akb="-q 10"
	asamplerate=""
else
	akb="-q 10"
	asamplerate="-cutoff 22050 -ar 44100"
fi
}
Audio_MP3_Config() {					# Option 24 	- Audio to mp3 (libmp3lame)
if [ "$ffmes_option" -lt 20 ]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi
echo " Choose MP3 (libmp3lame) desired configuration:"
echo
echo " For crb:"
echo " [192k] -> Example of input format for desired bitrate"
echo
echo " Otherwise choose a number:"
echo
echo "        | kb/s     |"
echo "        |----------|"
echo "  [1]   | 140-185k |"
echo "  [2]   | 150-195k |"
echo "  [3]   | 170-210k |"
echo "  [4]   | 190-250k |"
echo "  [5]   | 220-260k |"
echo " *[6] > | 320k     |"
echo "  [q] > | for exit"
read -r -e -p "-> " rpakb
if [ "$rpakb" = "q" ]; then
	Restart
elif echo "$rpakb" | grep -q 'k' ; then
	akb="-b:a $rpakb"
elif [ "$rpakb" = "1" ]; then
	akb="-q:a 4"
elif [ "$rpakb" = "2" ]; then
	akb="-q:a 3"
elif [ "$rpakb" = "3" ]; then
	akb="-q:a 2"
elif [ "$rpakb" = "4" ]; then
	akb="-q:a 1"
elif [ "$rpakb" = "5" ]; then
	akb="-q:a 0"
elif [ "$rpakb" = "6" ]; then
	akb="-b:a 320k"
else
	akb="-b:a 320k"
fi
}
Audio_AAC_Config() {					# Option 1,27 	- Conf audio/video libvorbis, audio to m4a (aac)
if [ "$ffmes_option" -lt 20 ]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi

# Local variables
local test_libfdk_aac
local aac_codec_label

# Test current ffmpeg configuration, libfdk_aac is non-free compilation
test_libfdk_aac=$("$ffmpeg_bin" -hide_banner -loglevel quiet -codecs | grep "libfdk")

# If libfdk_aac present use libfdk_aac
if [ -n "$test_libfdk_aac" ]; then
	acodec="-acodec libfdk_aac"
	aac_codec_label="libfdk_aac (HE-AAC v1)"
else
	acodec="-acodec aac"
	aac_codec_label="ffmpeg aac"
fi

# Question
echo " Choose AAC desired configuration:"
echo " Note: * Current codec used: $aac_codec_label"
echo '       * With the "adaptive bitrate" option, ffmes will choose'
echo '         each target file the number of kb/s to apply according'
echo '         to the table.'
echo "       * The cutoff allows to lose bitrate on high frequencies,"
echo "         to gain bitrate on audible frequencies."
echo
echo "                |  cut  |"
echo "         | kb/s |  off  | Descriptions      |"
echo "         |------|-------|-------------------|"
echo "  [1]  > |  64k | 14kHz | 2.0 ~ mp3 96k     |"
echo "  [2]  > |  96k | 15kHz | 2.0 ~ mp3 120k    |"
echo "  [3]  > | 128k | 16kHz | 2.0 ~ mp3 160k    |"
echo "  [4]  > | 160k | 17kHz | 2.0 ~ mp3 192k    |"
echo "  [5]  > | 192k | 18kHz | 2.0 ~ mp3 280k    |"
echo "  [6]  > | 220k | 19kHz | 2.0 ~ mp3 320k    |"
echo "  [7]  > | 320k | 20kHz | 2.0 > mp3         |"
echo "  [8]  > | 384k | 20kHz | 5.1 audio source  |"
echo "  [9]  > | 512k | 20kHz | 7.1 audio source  |"
echo "  -------------------------------------------"
echo " [10]  > | vbr1 | 15kHz | 20-32k  / channel |"
echo " [11]  > | vbr2 | 15kHz | 32-40k  / channel |"
echo " [12]  > | vbr3 | 16kHz | 48-56k  / channel |"
echo " [13]  > | vbr4 | 17kHz | 64-72k  / channel |"
echo " [14]  > | vbr5 | 19kHz | 96-112k / channel |"
echo "  -------------------------------------------"
echo " *[X]  > |    adaptive bitrate     |"
echo "         |-------------------------|  cut  |"
echo "         | Target |     Source     |  off  |"
echo "         |--------|----------------|-------|"
echo "         |   64k  |   1kb ->  96kb | 15kHz |"
echo "         |   96k  |  97kb -> 128kb | 16kHz |"
echo "         |  128k  | 129kb -> 160kb | 16kHz |"
echo "         |  160k  | 161kb -> 192kb | 17kHz |"
echo "         |  192k  | 193kb -> 256kb | 18kHz |"
echo "         |  220k  | 257kb -> 280kb | 19kHz |"
echo "         |  256k  | 281kb -> 320kb | 20kHz |"
echo "         |  280k  | 321kb -> 400kb | 20kHz |"
echo "         |  320k  | 400kb -> ∞     | 20kHz |"
echo "  [q]  > | for exit"
read -r -e -p "-> " rpakb
if [ "$rpakb" = "q" ]; then
	Restart
elif [ "$rpakb" = "1" ]; then
	akb="-b:a 64K"
	asamplerate="-cutoff 14000"
elif [ "$rpakb" = "2" ]; then
	akb="-b:a 96K"
	asamplerate="-cutoff 15000"
elif [ "$rpakb" = "3" ]; then
	akb="-b:a 128K"
	asamplerate="-cutoff 16000"
elif [ "$rpakb" = "4" ]; then
	akb="-b:a 160K"
	asamplerate="-cutoff 17000"
elif [ "$rpakb" = "5" ]; then
	akb="-b:a 192K"
	asamplerate="-cutoff 18000"
elif [ "$rpakb" = "6" ]; then
	akb="-b:a 220K"
	asamplerate="-cutoff 19000"
elif [ "$rpakb" = "7" ]; then
	akb="-b:a 320K"
	asamplerate="-cutoff 20000"
elif [ "$rpakb" = "8" ]; then
	akb="-b:a 384K"
	asamplerate="-cutoff 20000"
elif [ "$rpakb" = "9" ]; then
	akb="-b:a 512K"
	asamplerate="-cutoff 20000"
elif [ "$rpakb" = "10" ]; then
	akb="-vbr 1"
	asamplerate="-cutoff 15000"
elif [ "$rpakb" = "11" ]; then
	akb="-vbr 2"
	asamplerate="-cutoff 15000"
elif [ "$rpakb" = "12" ]; then
	akb="-vbr 3"
	asamplerate="-cutoff 16000"
elif [ "$rpakb" = "13" ]; then
	akb="-vbr 4"
	asamplerate="-cutoff 17000"
elif [ "$rpakb" = "14" ]; then
	akb="-vbr 5"
	asamplerate="-cutoff 19000"
elif [ "$rpakb" = "X" ]; then
	AdaptedBitrate="1"
else
	AdaptedBitrate="1"
fi
}
Audio_AC3_Config() {					# Option 1  	- Conf audio/video AC3
Display_Video_Custom_Info_choice
echo " Choose AC3 desired configuration:"
echo
echo " [192k] -> Example of input format for desired bitrate"
echo
echo " Otherwise choose a number:"
echo
echo "        | kb/s |"
echo "        |------|"
echo "  [1] > | 140k |"
echo "  [2] > | 240k |"
echo "  [3] > | 340k |"
echo "  [4] > | 440k |"
echo "  [5] > | 540k |"
echo " *[6] > | 640k |"
echo "  [q] > | for exit"
read -r -e -p "-> " rpakb
if [ "$rpakb" = "q" ]; then
	Restart
elif echo "$rpakb" | grep -q 'k' ; then
	akb="-b:a $rpakb"
elif [ "$rpakb" = "1" ]; then
	akb="-b:a 140k"
elif [ "$rpakb" = "2" ]; then
	akb="-b:a 240k"
elif [ "$rpakb" = "3" ]; then
	akb="-b:a 340k"
elif [ "$rpakb" = "4" ]; then
	akb="-b:a 440k"
elif [ "$rpakb" = "5" ]; then
	akb="-b:a 540k"
elif [ "$rpakb" = "6" ]; then
	akb="-b:a 640k"
else
	akb="-b:a 640k"
fi
}
Audio_Source_Info_Detail_Question() {	# Option 32
if [[ "${#LSTAUDIO[@]}" != "1" ]]; then
	if [[ "${#LSTAUDIO[@]}" -gt "50" ]]; then
		read -r -p " View the stats of the ${#LSTAUDIO[@]} files in the loop (can be long, it's recursive)? [y/N]" qarm
	else
		read -r -p " View the stats of the ${#LSTAUDIO[@]} files in the loop? [y/N]" qarm
	fi
	case $qarm in
		"Y"|"y")
			Display_Remove_Previous_Line
			Display_Audio_Stats_List "${LSTAUDIO[@]}"
		;;
		*)
			Display_Remove_Previous_Line
			return
		;;
	esac
fi
}
Audio_Peak_Normalization_Question() {	#
read -r -p " Apply a -${PeakNormDB}db peak normalization (1st file DB peak:${ffmpeg_peakdb})? [y/N]" qarm
case $qarm in
	"Y"|"y")
		PeakNorm="1"
	;;
	*)
		return
	;;
esac
}
Audio_False_Stereo_Question() {			#
if [[ -z "$confchan" ]]; then			# if number of channel forced, no display option
	read -r -p " Detect and convert false stereo files in mono? [y/N]" qarm
	case $qarm in
		"Y"|"y")
			TestFalseStereo="1"
		;;
		*)
			return
		;;
	esac
fi
}
Audio_Channels_Question() {				#
echo
read -r -p " Change the channels layout? [y/N]" qarm
case $qarm in
	"Y"|"y")
		Audio_Channels_Config
	;;
	*)
		if [[ "$codeca" = "libopus" || "$AudioCodecType" = "libopus" ]]; then
			afilter="-af aformat=channel_layouts='7.1|6.1|5.1|stereo' -mapping_family 1"
		fi
		return
	;;
esac
}
Audio_Silent_Detection_Question() {		#
local TESTWAV
local TESTFLAC
TESTWAV=$(echo "${LSTAUDIOEXT[@]}" | grep wav )
TESTFLAC=$(echo "${LSTAUDIOEXT[@]}" | grep flac)
if [[ -n "$TESTWAV" || -n "$TESTFLAC" ]]; then
	read -r -p " Detect and remove silence at start and end of files? [y/N]" qarm
	case $qarm in
		"Y"|"y")
			SilenceDetect="1"
		;;
		*)
			return
		;;
	esac
fi
}
Audio_Multiple_Extention_Check() {		# If sources audio multiple extention question
if [ "$NBAEXT" -gt "1" ]; then
	echo
	echo " Different source audio file extensions have been found, would you like to select one or more?"
	echo " Notes: * It is recommended not to batch process different sources, in order to control the result as well as possible."
	echo "        * If target have same extention of source file, it will not processed."
	echo
	echo " Extensions found: ${LSTAUDIOEXT[*]}"
	echo
	echo "  [m4a]     > Example of input format for select one extension"
	echo "  [m4a|mp3] > Example of input format for multiple selection"
	echo " *[↵]       > for no selection"
	echo "  [q]       > for exit"
	echo -n " -> "
	read -r NEW_AUDIO_EXT_AVAILABLE
	if [ "$NEW_AUDIO_EXT_AVAILABLE" = "q" ]; then
		Restart
	elif test -n "$NEW_AUDIO_EXT_AVAILABLE"; then
		StartLoading "Search the files processed"
		mapfile -t LSTAUDIO < <(find . -maxdepth 5 -type f -regextype posix-egrep \
			-regex '.*\.('$NEW_AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
		mapfile -t LSTAUDIOEXT < <(echo "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
		StopLoading $?
	fi
fi
}
Audio_Generate_Spectrum_Img() {			# Option 33 	- PNG of audio spectrum
# Local variables
local total_target_files_size
local START
local END
# Array
filesPass=()
filesReject=()

clear
echo
echo " Choose size of png spectrum for the ${#LSTAUDIO[@]} files:"
echo
echo "        |     sizes | descriptions                |"
echo "        |-----------|-----------------------------|"
echo "  [1] > |   800x450 | 2.0 thumb                   |"
echo "  [2] > |  1280x720 | 2.0 readable / 5.1 thumb    |"
echo " *[3] > | 1920x1080 | 2.0 detail   / 5.1 readable |"
echo "  [4] > | 3840x2160 | 5.1 detail                  |"
echo "  [5] > | 7680x4320 | Shoryuken                   |"
echo "  [q] > | exit"
read -r -e -p "-> " qspek
if [ "$qspek" = "q" ]; then
	Restart
elif [ "$qspek" = "1" ]; then
	spekres="800x450"
elif [ "$qspek" = "2" ]; then
	spekres="1280x720"
elif [ "$qspek" = "3" ]; then
	spekres="1920x1080"
elif [ "$qspek" = "4" ]; then
	spekres="3840x2160"
elif [ "$qspek" = "5" ]; then
	spekres="7680x4320"
else
	spekres="1920x1080"
fi

# Start time counter
START=$(date +%s)

echo
Echo_Separator_Light
for (( i=0; i<=$(( ${#LSTAUDIO[@]} - 1 )); i++ )); do

	(
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "${LSTAUDIO[i]}" \
		-lavfi showspectrumpic=s=$spekres:mode=separate:gain=1.4:color=2 "${LSTAUDIO[i]%.*}".png \
		| ProgressBar "" "$((i+1))" "${#LSTAUDIO[@]}" "Spectrum creation" "1"
	) &
	if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
		wait -n
	fi

done
wait

# Generate target file array
mapfile -t LSTPNG < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('png')$' 2>/dev/null | sort | sed 's/^..//')
# File validation
Test_Target_File "0" "video" "${LSTPNG[@]}"

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "${#LSTAUDIO[@]}" "$total_target_files_size" ""
}
Audio_Concatenate_Files() {				# Option 34 	- Concatenate audio files
# Local variables
local total_source_files_size
local total_target_files_size
local PERC
local START
local END

echo
echo " Concatenate audio files:"
echo " Note: Before you start, make sure that the files all have the same codec and bitrate."
echo
echo " Files to concatenate:"
printf '  %s\n' "${LSTAUDIO[@]}"
echo
echo " *[↵] > for continue"
echo "  [q] > for exit"
read -r -e -p "-> " concatrep
if [ "$concatrep" = "q" ]; then
		Restart
else

	echo
	Echo_Separator_Light
	
	# Start time counter
	START=$(date +%s)

	# Add date id to created filename, prevent infinite loop of ffmpeg is target=source filename
	filename_id="Concatenate_Output-$(date +%s).${LSTAUDIO[0]##*.}"

	# Concatenate
	if [[ "${LSTAUDIO[0]##*.}" = "flac" ]] || [[ "${LSTAUDIO[0]##*.}" = "FLAC" ]]; then
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -f concat -safe 0 -i <(for f in *."${LSTAUDIO[0]##*.}"; do echo "file '$PWD/$f'"; done) \
			$FFMPEG_PROGRESS "$filename_id" \
			| ProgressBar "" "1" "1" "Concatenate" "1"
	else
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -f concat -safe 0 -i <(for f in *."${LSTAUDIO[0]##*.}"; do echo "file '$PWD/$f'"; done) \
			$FFMPEG_PROGRESS -c copy "$filename_id" \
			| ProgressBar "" "1" "1" "Concatenate" "1"
	fi

	# File validation
	Test_Target_File "1" "audio" "$filename_id"

	# End time counter
	END=$(date +%s)

	# Make statistics of processed files
	Calc_Elapsed_Time "$START" "$END"
	total_source_files_size=$(Calc_Files_Size "${LSTAUDIO[@]}")
	total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")
	PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")

	# End encoding messages "pass_files" "total_files" "target_size" "source_size"
	Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" "$total_source_files_size"

fi
}
Audio_Cut_File() {						# Option 35 	- Cut audio file
# Local variables
local total_source_files_size
local total_target_files_size
local PERC
local START
local END
local split_output
local CutSegment
# Array
filesInLoop=()

# Display stats
Display_Media_Stats_One "${LSTAUDIO[@]}"

echo " Enter duration of cut:"
echo " Notes: * for hours :   HOURS:MM:SS.MICROSECONDS"
echo "        * for minutes : MM:SS.MICROSECONDS"
echo "        * for seconds : SS.MICROSECONDS"
echo "        * microseconds is optional, you can not indicate them"
echo
echo " Examples of input:"
echo "  [s.20]        > remove audio after 20 second"
echo "  [e.01:11:20]  > remove audio before 1 hour 11 minutes 20 second"
echo "  [p.00:02:00]  > split audio in parts of 2 minutes"
echo
echo "  [s.time]      > for remove end"
echo "  [e.time]      > for remove start"
echo "  [t.time.time] > for remove start and end"
echo "  [q]           > for exit"
echo "  [p.time]      > for split"
while :
do
read -r -e -p "-> " qcut0
case $qcut0 in
	s.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')
		CutStart="$ffprobe_StartTime"
		CutEnd=$(echo "$qcut" | awk '{print $2;}')
		break
	;;
	e.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')
		CutStart=$(echo "$qcut" | awk '{print $2;}')
		CutEnd="$ffprobe_Duration"
		break
	;;
	t.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')
		CutStart=$(echo "$qcut" | awk '{print $2;}')
		CutEnd=$(echo "$qcut" | awk '{print $3;}')
		break
	;;
	p.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')
		CutSegment=$(echo "$qcut" | awk '{print $2;}')
		break
	;;
	"q"|"Q")
		Restart
		break
	;;
		*)
			echo
			Echo_Mess_Invalid_Answer
			echo
		;;
esac
done

# Start time counter
START=$(date +%s)

echo
Echo_Separator_Light

# Segment
if [[ -n "$CutSegment" ]]; then
	# Create file path & directory for segmented files
	split_output_files="${LSTAUDIO[0]##*/}"
	split_output="splitted_raw_${split_output_files%.*}"
	if ! [[ -d "$split_output" ]]; then
		mkdir "$split_output"
	fi

	# Segment
	# Flac exception for reconstruc duration
	if [[ "${LSTAUDIO[0]##*.}" = "flac" ]] || [[ "${LSTAUDIO[0]##*.}" = "FLAC" ]]; then
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "${LSTAUDIO[0]}" $FFMPEG_PROGRESS \
			-f segment -segment_time "$CutSegment" \
			-map 0 -map_metadata 0 -c:a flac -reset_timestamps 1 \
			"$split_output"/"${split_output_files%.*}"_segment_%04d."${LSTAUDIO[0]##*.}" \
			| ProgressBar "${LSTAUDIO[0]}" "" "" "Segment"
	else
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "${LSTAUDIO[0]}" $FFMPEG_PROGRESS \
			-f segment -segment_time "$CutSegment" \
			-c copy -map 0 -map_metadata 0 \
			"$split_output"/"${split_output_files%.*}"_segment_%04d."${LSTAUDIO[0]##*.}" \
			| ProgressBar "${LSTAUDIO[0]}" "" "" "Segment"
	fi

	# map array of target files
	mapfile -t filesInLoop < <(find "$split_output" -maxdepth 1 -type f -regextype posix-egrep \
		-iregex '.*\.('${LSTAUDIO[0]##*.}')$' 2>/dev/null | sort)

# Cut
else
	# Flac exception for reconstruc duration
	if [[ "${LSTAUDIO[0]##*.}" = "flac" ]] || [[ "${LSTAUDIO[0]##*.}" = "FLAC" ]]; then
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "${LSTAUDIO[0]}" $FFMPEG_PROGRESS \
			-ss "$CutStart" -to "$CutEnd" \
			-map 0 -map_metadata 0 -c:a flac -reset_timestamps 1 \
			"${LSTAUDIO[0]%.*}".cut."${LSTAUDIO[0]##*.}" \
			| ProgressBar "${LSTAUDIO[0]}" "" "" "Cut"
	else
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "${LSTAUDIO[0]}" $FFMPEG_PROGRESS \
			-ss "$CutStart" -to "$CutEnd" \
			-map 0 -c copy -map_metadata 0 \
			"${LSTAUDIO[0]%.*}".cut."${LSTAUDIO[0]##*.}" \
			| ProgressBar "${LSTAUDIO[0]}" "" "" "Cut"
	fi
fi

# Check Target if valid
if [[ -n "$CutSegment" ]]; then
	Test_Target_File "0" "audio" "${filesInLoop[@]}"
else
	Test_Target_File "1" "audio" "${LSTAUDIO[0]%.*}.cut.${LSTAUDIO[0]##*.}"
fi

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"
total_source_files_size=$(Calc_Files_Size "${LSTAUDIO[@]}")
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" "$total_source_files_size"
}
Audio_CUE_Split() {						# Option 22 	- CUE Splitter to flac
# Local variables
local CHARSET_DETECT
local total_source_files_size
local total_target_files_size
local PERC
local START
local END

# Limit to current directory
mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep \
	-iregex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

if [ "${#LSTAUDIO[@]}" -eq "0" ]; then
	Echo_Mess_Error "No audio file in the working directory"
elif [ "${#LSTAUDIO[@]}" -gt "1" ]; then
	Echo_Mess_Error "More than one audio file in working directory"
elif [[ "${#LSTCUE[@]}" -eq "1" ]] && [[ "${#LSTAUDIO[@]}" -eq "1" ]]; then

	# Display
	echo
	Echo_Separator_Light
	echo " CUE Split:"

	# Start time counter
	START=$(date +%s)

	# UTF-8 convert
	CHARSET_DETECT=$(uchardet "${LSTCUE[0]}" 2> /dev/null)
	if [ "$CHARSET_DETECT" != "UTF-8" ]; then
		iconv -f "$CHARSET_DETECT" -t UTF-8 "${LSTCUE[0]}" > utf-8.cue
		mkdir BACK 2> /dev/null
		mv "${LSTCUE[0]}" BACK/"${LSTCUE[0]}".back
		mv -f utf-8.cue "${LSTCUE[0]}"
	fi

	# If wavpack file -> unpack
	if [[ "${LSTAUDIO[0]##*.}" = "wv" ]]; then
		wvunpack -w "${LSTAUDIO[0]}"
		# Clean
		if test $? -eq 0; then
			if [ ! -d BACK/ ]; then
				mkdir BACK 2> /dev/null
			fi
			mv "${LSTAUDIO[0]}" BACK/"${LSTAUDIO[0]}".back 2> /dev/null
			LSTAUDIO=( "${LSTAUDIO[0]%.*}.wav" )
		else
			Echo_Separator_Light
			echo "  CUE Splitting fail on WavPack extraction"
			Echo_Separator_Light
			return 1
		fi
	fi

	# Split file
	shnsplit -f "${LSTCUE[0]}" -t "%n - %t" "${LSTAUDIO[0]}" -o "flac flac --best -s -o %f -"

	# Clean
	if test $? -eq 0; then
		rm 00*.flac 2> /dev/null
		if [ ! -d BACK/ ]; then
			mkdir BACK 2> /dev/null
		fi
		mv "${LSTAUDIO[0]}" BACK/"${LSTAUDIO[0]}".back 2> /dev/null
	else
		Echo_Separator_Light
		echo "  CUE Splitting fail on shnsplit file"
		Echo_Separator_Light
		return 1
	fi

	# Generate target file array
	mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep \
		-iregex '.*\.('flac')$' 2>/dev/null | sort | sed 's/^..//')

	# Tag
	cuetag "${LSTCUE[0]}" "${LSTAUDIO[@]}" 2> /dev/null

	# File validation
	Test_Target_File "1" "audio" "${LSTAUDIO[@]}"

	# End time counter
	END=$(date +%s)

	# Make statistics of processed files
	Calc_Elapsed_Time "$START" "$END"
	total_target_files_size=$(Calc_Files_Size "${LSTAUDIO[@]}")

	# End encoding messages "pass_files" "total_files" "target_size" "source_size"
	Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" ""

fi
}
Audio_File_Tester() {					# Option 36 	- ffmpeg test player
# Local variables
local START
local END

# Start time counter
START=$(date +%s)

# Messages
clear
echo
echo " Audio file integrity check:"
echo
Echo_Separator_Light

# Disable the enter key
EnterKeyDisable


# Encoding
for files in "${LSTAUDIO[@]}"; do
	# Stock files pass in loop
	filesInLoop+=("$files")

	# Test integrity
	(
	ProgressBar "" "${#filesInLoop[@]}" "${#LSTAUDIO[@]}" "Integrity check"
	"$ffmpeg_bin" -v error -i "$files" $FFMPEG_LOG_LVL -f null - &>/dev/null \
		|| echo "  $files" >> "$FFMES_CACHE_INTEGRITY"
	) &
	if [[ $(jobs -r -p | wc -l) -ge $NPROC ]]; then
		wait -n
	fi

done
wait

# Enable the enter key
EnterKeyEnable

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"								# Get elapsed time

# End encoding messages
echo
if [ -s "$FFMES_CACHE_INTEGRITY" ]; then
	Echo_Separator_Light
	echo " File(s) in error:"
	cat "$FFMES_CACHE_INTEGRITY"
else
	echo " No file in error."
fi
echo
}

## AUDIO TAG
Audio_Tag_cmd() {						# Part of Audio_Tag_Editor
# Local variables
local tag_label
local tag_value
local tag_option
local tag_cut

tag_label="$1"
tag_value="$2"
tag_option="$3"
tag_cut="$4"

for (( i=0; i<=$(( ${#LSTAUDIO[@]} - 1 )); i++ )); do
	StartLoading "" "Tag: ${LSTAUDIO[$i]}"

	if [[ "$tag_option" = "ftitle" ]]; then
		tag_value="${LSTAUDIO[$i]%.*}"
	elif [[ "$tag_option" = "stitle" ]]; then
		tag_value=$(echo "${TAG_TITLE[$i]}" | cut -c "$tag_cut"-)
	elif [[ "$tag_option" = "etitle" ]]; then
		tag_value=$(echo "${TAG_TITLE[$i]}" | rev | cut -c "$tag_cut"- | rev)
	elif [[ "$tag_option" = "ptitle" ]]; then
		tag_value="${TAG_TITLE[$i]//$tag_cut}"
	elif [[ "$tag_option" = "track" ]]; then
		tag_value="${TAG_TRACK_COUNT[$i]}"
	fi

	(
	if [[ "${LSTAUDIO[$i]##*.}" = "wv" ]]; then

		wvtag -q -w "$tag_label"="$tag_value" "${LSTAUDIO[$i]}"

	elif [[ "${LSTAUDIO[$i]##*.}" = "ape" ]]; then

		mac "${LSTAUDIO[$i]}" -t "$tag_label"="$tag_value" &>/dev/null

	elif [[ "${LSTAUDIO[$i]##*.}" = "flac" ]]; then

		metaflac --remove-tag="$tag_label" --set-tag="$tag_label"="$tag_value" "${LSTAUDIO[$i]}"

	elif [[ "${LSTAUDIO[$i]##*.}" = "mp3" ]]; then

		if [[ "$tag_label" = "title" ]]; then
			mid3v2 -t "$tag_value" "${LSTAUDIO[$i]}" &>/dev/null
		else
			mid3v2 --"$tag_label"="$tag_value" "${LSTAUDIO[$i]}" &>/dev/null
		fi

	else

		if [[ "$tag_label" = "date" ]]; then
			tracktag --remove-year "${LSTAUDIO[$i]}" &>/dev/null \
			&& tracktag --year "$tag_value" "${LSTAUDIO[$i]}" &>/dev/null
			tracktag --remove-date "${LSTAUDIO[$i]}" &>/dev/null \
			&& tracktag --"$tag_label" "$tag_value" "${LSTAUDIO[$i]}" &>/dev/null
		elif [[ "$tag_label" = "track" ]]; then
			tracktag --remove-number "${LSTAUDIO[$i]}" &>/dev/null \
			&& tracktag --number "$tag_value" "${LSTAUDIO[$i]}" &>/dev/null
		elif [[ "$tag_label" = "title" ]]; then
			tracktag --remove-name "${LSTAUDIO[$i]}" &>/dev/null \
			&& tracktag --name "$tag_value" "${LSTAUDIO[$i]}" &>/dev/null
		elif [[ "$tag_label" = "disc" ]]; then
			tracktag --remove-album-number "${LSTAUDIO[$i]}" &>/dev/null \
			&& tracktag --album-number "$tag_value" "${LSTAUDIO[$i]}" &>/dev/null
		else
			tracktag --remove-"$tag_label" "${LSTAUDIO[$i]}" &>/dev/null \
			&& tracktag --"$tag_label" "$tag_value" "${LSTAUDIO[$i]}" &>/dev/null
		fi

	fi
	StopLoading $?
	) &
	if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
		wait -n
	fi
done
wait
}
Audio_Tag_Rename() {					# Part of Audio_Tag_Editor
local rename_option
local integer_test2_track

rename_option="$1"

for (( i=0; i<=$(( ${#LSTAUDIO[@]} - 1 )); i++ )); do
	StartLoading "" "Rename: ${LSTAUDIO[$i]}"
	# If no tag track
	if [[ -z "${TAG_TRACK[$i]}" ]]; then					# if no TAG_TRACK
		ParsedTrack="${TAG_TRACK_COUNT[$i]}"				# use TAG_TRACK_COUNT
	else
		# Integer test 1 - XX
		if [[ "${TAG_TRACK[$i]}" =~ ^-?[0-9]+$ ]]; then
			if [ "${#TAG_TRACK[i]}" -eq "1" ] && [ "${#LSTAUDIO[@]}" -ge 10 ]; then
				if [ "${#LSTAUDIO[@]}" -ge 10 ] && [ "${#LSTAUDIO[@]}" -le 99 ]; then
					ParsedTrack="0${TAG_TRACK[$i]}"
				fi
			elif [ "${#LSTAUDIO[@]}" -eq "2" ] && [ "${#LSTAUDIO[@]}" -ge 100 ]; then
				if [ "${#LSTAUDIO[@]}" -ge 10 ] && [ "${#LSTAUDIO[@]}" -le 99 ]; then
					ParsedTrack="00${TAG_TRACK[$i]}"
				fi
			else
				ParsedTrack="${TAG_TRACK[$i]}"
			fi
		# Integer test 2 - XX/XX
		elif [[ $(echo "${TAG_TRACK[$i]}" | awk -F"/" '{ print $1 }') =~ ^-?[0-9]+$ ]]; then
			integer_test2_track=$(echo "${TAG_TRACK[$i]}" | awk -F"/" '{ print $1 }')
			if [ "$integer_test2_track" -eq "1" ] && [ "${#LSTAUDIO[@]}" -ge 10 ]; then
				if [ "${#LSTAUDIO[@]}" -ge 10 ] && [ "${#LSTAUDIO[@]}" -le 99 ]; then
					ParsedTrack="0$integer_test2_track"
				fi
			elif [ "${#LSTAUDIO[@]}" -eq "2" ] && [ "${#LSTAUDIO[@]}" -ge 100 ]; then
				if [ "${#LSTAUDIO[@]}" -ge 10 ] && [ "${#LSTAUDIO[@]}" -le 99 ]; then
					ParsedTrack="00$integer_test2_track"
				fi
			else
				ParsedTrack="$integer_test2_track"
			fi
		fi
	fi
	# If no tag title
	if test -z "${TAG_TITLE[$i]}"; then						# if no title
		ParsedTitle="[untitled]"							# use "[untitled]"
	else
		# Replace eventualy / , " , : in string
		ParsedTitle=$(echo "${TAG_TITLE[$i]}" | sed s#/#-#g)
		ParsedTitle=$(echo "$ParsedTitle" | sed s#:#-#g)
		ParsedTitle=$(echo "$ParsedTitle" | sed 's#"#-#g')
	fi
	# If no tag artist
	if test -z "${TAG_ARTIST[$i]}"; then					# if no artist
		ParsedTitle="[unknown]"								# use "[unamed]"
	else
		# Replace eventualy / , " , : in string
		ParsedArtist=$(echo "${TAG_ARTIST[$i]}" | sed s#/#-#g)
		ParsedArtist=$(echo "$ParsedArtist" | sed s#:#-#g)
		ParsedArtist=$(echo "$ParsedArtist" | sed 's#"#-#g')
	fi
	# Rename
	(
	if [[ -f "${LSTAUDIO[$i]}" && -s "${LSTAUDIO[$i]}" ]]; then
		if [[ "$rename_option" = "rename" ]]; then
			mv "${LSTAUDIO[$i]}" "$ParsedTrack"\ -\ "$ParsedTitle"."${LSTAUDIO[$i]##*.}" &>/dev/null
		elif [[ "$rename_option" = "arename" ]]; then
			mv "${LSTAUDIO[$i]}" "$ParsedTrack"\ -\ "$ParsedArtist"\ -\ "$ParsedTitle"."${LSTAUDIO[$i]##*.}" &>/dev/null
		fi
	fi
	StopLoading $?
	) &
	if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
		wait -n
	fi
done
wait
}
Audio_Tag_Editor() {					# Option 30 	- Tag editor
# Local variables
local Cut
local ParsedAlbum
local ParsedArtist
local ParsedDate
local ParsedDisc
local ParsedTitle
local ParsedTrack
local PrtSep
local TAG_ALBUM
local TAG_ARTIST
local TAG_DATE
local TAG_DISC
local TAG_TITLE
local TAG_TRACK
local TAG_TRACK_COUNT
local TitlePattern
local tag_artist_string_length
local tag_disc_string_length
local tag_track_string_length
local tag_title_string_length
local tag_artist_string_length
local tag_album_string_length
local tag_date_string_length
local filename_string_length
local horizontal_separator_string_length
# Array
TAG_DISC=()
TAG_TRACK=()
TAG_TITLE=()
TAG_ARTIST=()
TAG_ALBUM=()
TAG_DATE=()
TAG_TRACK_COUNT=()
PrtSep=()


# Loading on
StartLoading "Grab current tags" ""

# Limit to current directory & audio file ext. tested
mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$AUDIO_TAG_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

# Get tag with ffprobe
for (( i=0; i<=$(( ${#LSTAUDIO[@]} - 1 )); i++ )); do
	(
	"$ffprobe_bin" -hide_banner -loglevel panic -select_streams a -show_streams -show_format "${LSTAUDIO[$i]}" > "$FFMES_CACHE_TAG-[$i]"
	) &
	if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
		wait -n
	fi
done
wait

# Populate array with tag
for (( i=0; i<=$(( ${#LSTAUDIO[@]} - 1 )); i++ )); do
	TAG_DISC+=( "$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:disc=" | awk -F'=' '{print $NF}')" )
	TAG_TRACK+=( "$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:track=" | awk -F'=' '{print $NF}')" )
	TAG_TITLE+=( "$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:title=" | awk -F'=' '{print $NF}')" )
	TAG_ARTIST+=( "$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:artist=" | awk -F'=' '{print $NF}')" )
	TAG_ALBUM+=( "$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:album=" | awk -F'=' '{print $NF}')" )
	TAG_DATE+=( "$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:date=" | awk -F'=' '{print $NF}')" )

	# Table separator trick
	PrtSep+=("|")
	# Clean
	rm "$FFMES_CACHE_TAG-[$i]" &>/dev/null
done

# Track populate in advance with lead zero if necessary
for i in $(seq -w 1 "${#LSTAUDIO[@]}"); do
			TAG_TRACK_COUNT+=( "$i" )
done


# Calcul/Size larger of column
filename_string_length=$(Calc_Table_width "${LSTAUDIO[@]}")
tag_artist_string_length="17"
tag_disc_string_length="1"
tag_track_string_length=$(Calc_Table_width "${TAG_TRACK[@]}")
tag_title_string_length="20"
tag_album_string_length="20"
tag_date_string_length="5"
horizontal_separator_string_length=$(( 6 * 5 ))

# Length min/max value correction
if [[ "$filename_string_length" -gt "40" ]]; then
	filename_string_length="40"
fi
if [[ "$tag_track_string_length" -gt "5" ]]; then
	tag_track_string_length="5"
elif [[ "$tag_track_string_length" -eq "0" ]]; then
	tag_track_string_length="1"
fi
# Separator
separator_string_length=$(( filename_string_length + tag_disc_string_length \
							+ tag_track_string_length + tag_title_string_length + tag_artist_string_length \
							+ tag_album_string_length + tag_date_string_length + horizontal_separator_string_length ))

# Loading off
StopLoading $?

# Display tags
# In table if term is wide enough, or in ligne
clear
echo
echo "Audio files tags:"
if [[ "$separator_string_length" -le "$TERM_WIDTH" ]]; then
	printf '%*s' "$separator_string_length" | tr ' ' "-"; echo
	paste <(printf "%-${filename_string_length}.${filename_string_length}s\n" "Files") <(printf "%s\n" "|") \
			<(printf "%-${tag_disc_string_length}.${tag_disc_string_length}s\n" "D") <(printf "%s\n" "|") \
			<(printf "%-${tag_track_string_length}.${tag_track_string_length}s\n" "Track") <(printf "%s\n" "|") \
			<(printf "%-${tag_title_string_length}.${tag_title_string_length}s\n" "Title") <(printf "%s\n" "|") \
			<(printf "%-${tag_artist_string_length}.${tag_artist_string_length}s\n" "Artist") <(printf "%s\n" "|") \
			<(printf "%-${tag_album_string_length}.${tag_album_string_length}s\n" "Album") <(printf "%s\n" "|") \
			<(printf "%-${tag_date_string_length}.${tag_date_string_length}s\n" "date") | column -s $'\t' -t
	printf '%*s' "$separator_string_length" | tr ' ' "-"; echo
	paste <(printf "%-${filename_string_length}.${filename_string_length}s\n" "${LSTAUDIO[@]}") <(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_disc_string_length}.${tag_disc_string_length}s\n" "${TAG_DISC[@]}") <(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_track_string_length}.${tag_track_string_length}s\n" "${TAG_TRACK[@]}") <(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_title_string_length}.${tag_title_string_length}s\n" "${TAG_TITLE[@]}") <(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_artist_string_length}.${tag_artist_string_length}s\n" "${TAG_ARTIST[@]}") <(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_album_string_length}.${tag_album_string_length}s\n" "${TAG_ALBUM[@]}") <(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_date_string_length}.${tag_date_string_length}s\n" "${TAG_DATE[@]}") | column -s $'\t' -t 2>/dev/null
	printf '%*s' "$separator_string_length" | tr ' ' "-"; echo
else
	printf '%*s' "$TERM_WIDTH_TRUNC" | tr ' ' "-"; echo
	for (( i=0; i<=$(( ${#LSTAUDIO[@]} - 1 )); i++ )); do
		Display_Line_Truncate "${LSTAUDIO[$i]}"
		echo " disc: ${TAG_DISC[$i]}, track: ${TAG_TRACK[$i]}"
		echo " title: ${TAG_TITLE[$i]}"
		echo " artist: ${TAG_ARTIST[$i]}"
		echo " album: ${TAG_ALBUM[$i]}"
		echo " date: ${TAG_DATE[$i]}"
		printf '%*s' "$TERM_WIDTH_TRUNC" | tr ' ' "-"; echo
	done
fi

# Display menu
echo
echo " Select tag option:"
echo " Notes: it is not at all recommended to threat more than one album at a time."
if [[ "$separator_string_length" -le "$TERM_WIDTH" ]]; then
	echo
	echo "                 | actions                    | descriptions"
	echo "                 |----------------------------|-------------------------------------------------------------------|"
	echo '  [rename]     > | rename files               | rename in "Track - Title"                                         |'
	echo '  [arename]    > | rename files with artist   | rename in "Track - Artist - Title"                                |'
	echo "  [disc]       > | change or add disc number  | ex. of input [disc 1]                                             |"
	echo "  [track]      > | change or add tag track    | apply to all files by alphabetic sorting                          |"
	echo "  [album x]    > | change or add tag album    | ex. of input [album Conan the Barbarian]                          |"
	echo "  [artist x]   > | change or add tag artist   | ex. of input [artist Basil Poledouris]                            |"
	echo "  [uartist]    > | change artist by [unknown] |                                                                   |"
	echo "  [date x]     > | change or add tag date     | ex. of input [date 1982]                                          |"
	echo "  [ftitle]     > | change title by [filename] |                                                                   |"
	echo "  [utitle]     > | change title by [untitled] |                                                                   |"
	echo "  [stitle x]   > | remove N at begin of title | ex. [stitle 3] -> remove 3 first characters at start (limit to 9) |"
	echo "  [etitle x]   > | remove N at end of title   | ex. [etitle 1] -> remove 1 first characters at end (limit to 9)   |"
	echo '  [ptitle "x"] > | remove pattern in title    | ex. [ptitle "test"] -> remove test pattern in title               |'
	echo "  [r]          > | for restart tag editor"
	echo "  [q]          > | for exit"
	echo
else
	echo
	echo '  [rename]   > rename files in "Track - Title"'
	echo '  [arename]  > rename files in "Track - Artist - Title"'
	echo "  [disc]     > change or add disc number"
	echo "  [track]    > change or add tag track (alphabetic sorting)"
	echo "  [album x]  > change or add tag album"
	echo "  [artist x] > change or add tag artist"
	echo "  [uartist]  > change artist by [unknown]"
	echo "  [date x]   > change or add tag date"
	echo "  [ftitle]   > change title by [filename]"
	echo "  [utitle]   > change title by [untitled]"
	echo "  [stitle x] > remove N at begin of title (limit to 9)"
	echo "  [etitle x] > remove N at end of title (limit to 9)"
	echo "  [ptitle x] > remove pattern in title"
	echo "  [r]        > for restart tag editor"
	echo "  [q]        > for exit"
	echo
fi

shopt -s nocasematch

while :
do
read -r -e -p "-> " rpstag
case $rpstag in

	rename)
		Audio_Tag_Rename "rename"
		Audio_Tag_Editor
	;;
	arename)
		Audio_Tag_Rename "arename"
		Audio_Tag_Editor
	;;
	disc?[0-9])
		ParsedDisc="${rpstag##* }"
		Audio_Tag_cmd "disc" "$ParsedDisc"
		Audio_Tag_Editor
	;;
	track)
		Audio_Tag_cmd "track" "" "track"
		Audio_Tag_Editor
	;;
	album*)
		ParsedAlbum=$(echo "$rpstag" | awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}')
		Audio_Tag_cmd "album" "$ParsedAlbum"
		Audio_Tag_Editor
	;;
	artist*)
		ParsedArtist=$(echo "$rpstag" | awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}')
		Audio_Tag_cmd "artist" "$ParsedArtist"
		Audio_Tag_Editor
	;;
	uartist*)
		ParsedArtist="[unknown]"
		Audio_Tag_cmd "artist" "$ParsedArtist"
		Audio_Tag_Editor
	;;
	date*)
		ParsedDate="${rpstag##* }"
		Audio_Tag_cmd "date" "$ParsedDate"
		Audio_Tag_Editor
	;;
	ftitle)
		Audio_Tag_cmd "title" "" "ftitle"
		Audio_Tag_Editor
	;;
	utitle)
		Audio_Tag_cmd "title" "[untitled]"
		Audio_Tag_Editor
	;;
	stitle?[0-9])
		Cut=$(echo "$rpstag" | awk '{print $2+1}')
		Audio_Tag_cmd "title" "" "stitle" "$Cut"
		Audio_Tag_Editor
	;;
	etitle?[0-9])
		Cut=$(echo "$rpstag" | awk '{print $2+1}')
		Audio_Tag_cmd "title" "" "etitle" "$Cut"
		Audio_Tag_Editor
	;;
	ptitle*)
		TitlePattern=$(echo "$rpstag" | awk -F'"' '$0=$2')
		Audio_Tag_cmd "title" "" "ptitle" "$TitlePattern"
		Audio_Tag_Editor
	;;
	"r"|"R")
		Audio_Tag_Editor
		break
	;;
	"q"|"Q")
		Restart
		break
	;;
		*)
			echo
			Echo_Mess_Invalid_Answer
			echo
		;;
esac
done

shopt -u nocasematch

}
Audio_Tag_Search_Untagged() {			# Option 37 	- Untagged find
clear
echo
echo " Find untagged audio files"
echo " Note: The search can be long."
echo
echo " *[album]  > find files without album tag"
echo "  [artist] > find files without title tag"
echo "  [title]  > find files without title tag"
echo "  [date]   > find files without date tag"
echo "  [q] > for exit"
read -r -e -p "-> " untagged_q
case "$untagged_q" in
	"album"|"ALBUM")
		untagged_type="TAG:album="
		untagged_label="album"
	;;
	"artist"|"ARTIST")
		untagged_type="TAG:artist="
		untagged_label="artist"
	;;
	"title"|"TITLE")
		untagged_type="TAG:track="
		untagged_label="track"
	;;
	"date"|"DATE")
		untagged_type="TAG:date="
		untagged_label="date"
	;;
	"q"|"Q")
		Restart
	;;
	*)
		untagged_type="TAG:album="
		untagged_label="album"
	;;
esac
}

# Arguments variables
while [[ $# -gt 0 ]]; do
    key="$1"
    case "$key" in
    -h|--help)																						# Help
		Usage
		exit
    ;;
    -ca|--compare_audio)																			# Compare current audio files informations. 
		shift
		force_compare_audio="1"
		ffmes_option="32"
	;;
    -i|--input)
		shift
		InputFileDir="$1"
		if [ -d "$InputFileDir" ]; then															# If target is directory
			cd "$InputFileDir" || exit															# Move to directory
		elif [ -f "$InputFileDir" ]; then														# If target is file
			InputFileExt="${InputFileDir##*.}"
			InputFileExt="${InputFileExt,,}"
			all_ext_available="${VIDEO_EXT_AVAILABLE[*]}|${AUDIO_EXT_AVAILABLE[*]}|${ISO_EXT_AVAILABLE[*]}"
			if ! [[ "$all_ext_available" =~ $InputFileExt ]]; then
				echo
				Echo_Mess_Error "\"$1\" is not supported"
				Echo_Mess_Error "Supported Video: ${VIDEO_EXT_AVAILABLE//|/, }"
				Echo_Mess_Error "Supported Audio: ${AUDIO_EXT_AVAILABLE//|/, }"
				Echo_Mess_Error "Supported ISO: ${ISO_EXT_AVAILABLE//|/, }"
				echo
				exit
			else
				ARGUMENT="$InputFileDir"
			fi
		elif ! [ -f "$InputFileDir" ]; then
			Echo_Mess_Error "\"$1\" does not exist" "1"
			exit
		fi
    ;;
    -j|--videojobs)																					# Select 
		shift
		if ! [[ "$1" =~ ^[0-9]*$ ]] ; then															# If not integer
			Echo_Mess_Error "Video jobs option must be an integer" "1"
			exit
		else
			unset NVENC																				# Unset default NVENC
			NVENC="$1"																				# Set NVENC
			if [[ "$NVENC" -lt 0 ]] ; then															# If result inferior than 0
				Echo_Mess_Error "Video jobs must be greater than zero" "1"
				exit
			fi
		fi
    ;;
    -kc|--keep_cover)
		unset ExtractCover
		ExtractCover="1"
    ;;
    --novaapi)																						# No VAAPI 
		unset VAAPI_device																			# Unset VAAPI device
    ;;
    -s|--select)																					# Select 
		shift
		ffmes_option="$1"
    ;;
    -pk|--peaknorm)																					# Peak db 
		shift
		if [[ "$1" =~ ^[0-9]*[.][0-9]*$ ]] || [[ "$1" =~ ^[0-9]*$ ]]; then							# If integer or float
			unset PeakNormDB																		# Unset default PeakNormDB
			PeakNormDB="$1"																			# Set PeakNormDB
		else
			Echo_Mess_Error "Peak db normalization option must be a positive number" "1"
			exit
		fi
    ;;
    -v|--verbose)
		VERBOSE="1"																					# Set verbose, for dev/null and loading disable
		unset FFMPEG_LOG_LVL																		# Unset default ffmpeg log
		unset X265_LOG_LVL																			# Unset, for display x265 info log
		FFMPEG_LOG_LVL="-loglevel info -stats"														# Set ffmpeg log level to stats
		FFMPEG_PROGRESS=""
    ;;
    -vv|--fullverbose)
		VERBOSE="1"																					# Set verbose, for dev/null and loading disable
		unset FFMPEG_LOG_LVL																		# Unset default ffmpeg log
		unset X265_LOG_LVL																			# Unset, for display x265 info log
		FFMPEG_LOG_LVL="-loglevel debug -stats"														# Set ffmpeg log level to debug
		FFMPEG_PROGRESS=""
    ;;
    *)
		Usage
		exit
    ;;
esac
shift
done

# Main
CheckCoreCommand
CheckCacheDirectory							# Check if cache directory exist
CheckCustomBin
CheckFFmpegVersion
Display_Term_Size
StartLoading "Listing of media files to be processed"
SetGlobalVariables							# Set global variable
DetectDVD									# DVD detection
TestVAAPI									# VAAPI detection
StopLoading $?
trap TrapExit SIGINT SIGQUIT				# Set Ctrl+c clean trap for exit all script
trap TrapStop SIGTSTP						# Set Ctrl+z clean trap for exit current loop (for debug)
if [ -z "$ffmes_option" ]; then				# By-pass main menu if using command argument
	Display_Main_Menu						# Display main menu
fi

while true; do

if [ -z "$ffmes_option" ]; then						# By-pass selection if using command argument
	echo "  [q]exit [m]menu [r]restart"
	read -r -e -p "  -> " ffmes_option
fi

case $ffmes_option in

 Restart | rst | r )
	Restart
	;;

 exit | quit | q )
	TrapExit
	;;

 main | menu | m )
	Display_Main_Menu
	;;

 0 ) # DVD & BD rip
	echo " Choose DVD or Blu-Ray?"
	echo
	echo "  [0] > for DVD"
	echo "  [1] > for Blu-ray"
	read -r -e -p "  -> " qdvdbd
	case $qdvdbd in
		"0")
			# DVD rip
			CheckDVDCommand
			DVDRip
			Video_Custom_Video
			Video_Custom_Audio
			Video_Custom_Container
			Video_Custom_Stream
			Video_FFmpeg_video_cmd
			Remove_File_Source
			Clean
		;;
		"1")
			# Blu-ray rip
			if [ "${#LSTISO[@]}" -gt "1" ]; then
				echo
				Echo_Mess_Error "${#LSTISO[@]} files, one ISO file at a time"
				echo
				exit
			else
				CheckBDCommand
				BLURAYrip
			fi
		;;
		*)
			Echo_Mess_Invalid_Answer
		;;
	esac
	;;

 1 ) # video -> full custom
	if [ "${#LSTVIDEO[@]}" -gt "0" ]; then
		Video_Multiple_Extention_Check
		Video_Custom_Video
		Video_Custom_Audio
		Video_Custom_Container
		Video_Custom_Stream
		Video_FFmpeg_video_cmd
		Remove_File_Source
		Remove_File_Target
		Clean
	else
		Echo_Mess_Error "$MESS_NO_VIDEO_FILE" "1"
	fi
	;;

 2 ) # video -> mkv|copy|copy
 	if [ "${#LSTVIDEO[@]}" -gt "0" ]; then
		videoconf="-c:v copy"
		soundconf="-c:a copy"
		extcont="mkv"
		container="matroska"
		videoformat="avcopy"
		Video_Multiple_Extention_Check
		Video_Custom_Stream
		Video_FFmpeg_video_cmd
		Remove_File_Source
		Clean
	else
		Echo_Mess_Error "$MESS_NO_VIDEO_FILE" "1"
	fi
	;;

 3 ) # Video, audio only
	if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
		Video_Custom_Audio_Only
		Remove_File_Source
		Remove_File_Target
		Clean
	else
		Echo_Mess_Error "$MESS_ONE_VIDEO_ONLY" "1"
	fi
	;;

 4 ) # Audio night normalization
	if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
		Video_Add_OPUS_NightNorm
		Clean
	else
		Echo_Mess_Error "$MESS_ONE_VIDEO_ONLY" "1"
	fi
	;;

 10 ) # tools -> view stats
	if [ "${#LSTVIDEO[@]}" -gt "0" ]; then
	echo
	mediainfo "${LSTVIDEO[0]}"
	else
		Echo_Mess_Error "$MESS_NO_VIDEO_FILE" "1"
	fi
	;;

 11 ) # video -> mkv|copy|add audio|add sub
	if [[ "${#LSTVIDEO[@]}" -eq "1" ]] && [[ "${#LSTSUB[@]}" -gt 0 || "${#LSTAUDIO[@]}" -gt 0 ]]; then
		#if [[ "${LSTVIDEO[0]##*.}" = "mkv" ]]; then
			videoformat="addcopy"
			Video_Merge_Files
			Clean
		#else
		#	Echo_Mess_Error "Only mkv video files are allowed" "1"
		#fi
	else
		Echo_Mess_Error "One video, with several audio and/or subtitle files" "1"
	fi
	;;

 12 ) # Concatenate video
	if [ "${#LSTVIDEO[@]}" -gt "1" ] && [ "$NBVEXT" -eq "1" ]; then
		Video_Concatenate
		Video_Custom_Video
		Video_Custom_Audio
		Video_Custom_Container
		Video_Custom_Stream
		Video_FFmpeg_video_cmd
		Remove_File_Source
		Clean
	else
		if [[ "${#LSTVIDEO[@]}" -le "1" ]]; then
			Echo_Mess_Error "$MESS_BATCH_ONLY" "1"
		fi
		if [[ "$NBVEXT" != "1" ]]; then
			Echo_Mess_Error "$MESS_ONE_EXTENTION_ONLY" "1"
		fi
	fi
	;;

 13 ) # Extract stream video
	if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
		Video_Extract_Stream
		Clean
	else
		Echo_Mess_Error "$MESS_ONE_VIDEO_ONLY" "1"
	fi
	;;

 14 ) # Cut video
	if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
		Video_Cut_File
		Clean
	else
		Echo_Mess_Error "$MESS_ONE_VIDEO_ONLY" "1"
	fi
	;;

 15 ) # Split by chapter mkv
	if [ "${#LSTVIDEO[@]}" -eq "1" ] && [[ "${LSTVIDEO[0]##*.}" = "mkv" ]]; then
		Video_Split_By_Chapter
		Clean
	else
		Echo_Mess_Error "$MESS_ONE_VIDEO_ONLY" "1"
	fi
	;;

 16 ) # Change color palette of DVD subtitle
	if [[ "${LSTSUBEXT[*]}" = *"idx"* ]]; then
		DVDSubColor
		Clean
	else
		Echo_Mess_Error "Only DVD subtitle extention type (idx/sub)" "1"
	fi
	;;

 17 ) # Convert DVD subtitle to srt
	CheckSubtitleCommand
	if [[ "${LSTSUBEXT[*]}" = *"idx"* ]]; then
		DVDSub2Srt
		Clean
	else
		Echo_Mess_Error "Only DVD subtitle extention type (idx/sub)" "1"
	fi
	;;

 20 ) # audio -> CUE splitter
	CheckCueSplitCommand
	if [ "${#LSTCUE[@]}" -eq "0" ]; then
		Echo_Mess_Error "No CUE file in the working director" "1"
	elif [ "${#LSTCUE[@]}" -gt "1" ]; then
		Echo_Mess_Error "More than one CUE file in working directory" "1"
	else
		Audio_CUE_Split
		Clean
	fi
	;;

 21 ) # audio -> PCM
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="pcm"
		Audio_Multiple_Extention_Check
		Audio_PCM_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		extcont="wav"
		Audio_FFmpeg_cmd
		Remove_File_Source
		Remove_File_Target
		Clean
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	;;

 22 ) # audio -> flac lossless
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="flac"
		Audio_Multiple_Extention_Check
		Audio_FLAC_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		acodec="-acodec flac"
		extcont="flac"
		Audio_FFmpeg_cmd
		Remove_File_Source
		Remove_File_Target
		Clean
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	;;

 23 ) # audio -> wavpack lossless
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="wavpack"
		Audio_Multiple_Extention_Check
		Audio_WavPack_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		acodec="-acodec wavpack"
		extcont="wv"
		Audio_FFmpeg_cmd
		Remove_File_Source
		Remove_File_Target
		Clean
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	;;

 24 ) # audio -> mp3 @ vbr190-250kb
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="libmp3lame"
		Audio_Multiple_Extention_Check
		Audio_MP3_Config
		Audio_Peak_Normalization_Question
		Audio_Silent_Detection_Question
		acodec="-acodec libmp3lame"
		confchan="-ac 2"
		extcont="mp3"
		Audio_FFmpeg_cmd
		Remove_File_Source
		Remove_File_Target
		Clean
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	;;

 25 ) # audio -> ogg
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="libvorbis"
		Audio_Multiple_Extention_Check
		Audio_OGG_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		acodec="-acodec libvorbis"
		extcont="ogg"
		Audio_FFmpeg_cmd
		Remove_File_Source
		Remove_File_Target
		Clean
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	;;

 26 ) # audio -> opus
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="libopus"
		Audio_Multiple_Extention_Check
		Audio_Opus_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		acodec="-acodec libopus"
		extcont="opus"
		Audio_FFmpeg_cmd
		Remove_File_Source
		Remove_File_Target
		Clean
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	;;

 27 ) # audio -> aac
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="aac"
		Audio_Multiple_Extention_Check
		Audio_AAC_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		extcont="m4a"
		Audio_FFmpeg_cmd
		Remove_File_Source
		Remove_File_Target
		Clean
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	;;

 30 ) # tools -> audio tag
	CheckTagCommand
	if (( "${#LSTAUDIOTAG[@]}" )); then
		# Change number of process for increase speed, here 4*nproc
		NPROC=$(nproc --all | awk '{ print $1 * 4 }')
		Audio_Tag_Editor
		# Reset number of process
		NPROC=$(nproc --all)
		Clean
	else
			echo
			Echo_Mess_Error "No audio file to supported"
			Echo_Mess_Error "Supported files: ${AUDIO_TAG_EXT_AVAILABLE//|/, }"
			echo
	fi
	;;

 31 ) # tools -> one file view stats
	if (( "${#LSTAUDIO[@]}" )); then
		Audio_Multiple_Extention_Check
		echo
		mediainfo "${LSTAUDIO[0]}"
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	;;

 32 ) # tools -> multi file view stats
	if (( "${#LSTAUDIO[@]}" )); then
		Display_Audio_Stats_List "${LSTAUDIO[@]}"
		Clean
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	if [ "$force_compare_audio" = "1" ]; then
		exit
	fi
	;;

 33 ) # audio -> generate png of audio spectrum
	if (( "${#LSTAUDIO[@]}" )); then
		Audio_Multiple_Extention_Check
		Audio_Generate_Spectrum_Img
		Clean
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	;;

 34 ) # Concatenate audio
	if [ "${#LSTAUDIO[@]}" -gt "1" ] && [ "$NBAEXT" -eq "1" ]; then
		Audio_Concatenate_Files
		Remove_File_Source
		Clean
	else
		if [[ "${#LSTAUDIO[@]}" -le "1" ]]; then
			Echo_Mess_Error "$MESS_BATCH_ONLY" "1"
		fi
		if [[ "$NBAEXT" != "1" ]]; then
			Echo_Mess_Error "$MESS_ONE_EXTENTION_ONLY" "1"
		fi
	fi
	;;

 35 ) # Cut audio
	if [[ "${#LSTAUDIO[@]}" -eq "1" ]]; then
		Audio_Cut_File
		Clean
	else
		Echo_Mess_Error "$MESS_ONE_AUDIO_ONLY" "1"
	fi
	;;

 36 ) # File check
	if [[ "${#LSTAUDIO[@]}" -ge "1" ]]; then
		ProgressBarOption="1"
		NPROC=$(nproc --all | awk '{ print $1 * 4 }')
		Audio_File_Tester
		Clean
		# Reset
		NPROC=$(nproc --all)
		unset ProgressBarOption
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	;;

 37 ) # Untagged search
	if (( "${#LSTAUDIO[@]}" )); then
		Untagged="1"
		ProgressBarOption="1"
		NPROC=$(nproc --all | awk '{ print $1 * 10 }')
		Audio_Tag_Search_Untagged
		Audio_FFmpeg_cmd
		Clean
		# Reset
		NPROC=$(nproc --all)
		unset Untagged
		unset ProgressBarOption
	else
		Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
	fi
	;;

 99 ) # update
	ffmesUpdate
	Restart
	;;

 * ) # update
	echo
	Echo_Mess_Invalid_Answer
	echo
	;;

esac

unset ffmes_option		# By-pass selection if using command argument

done
exit
