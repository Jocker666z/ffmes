#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2026,SC2046,SC2059,SC2086,SC2317
# ffmes - ffmpeg media encode script
# Bash tool handling media files and DVD. Mainly with ffmpeg. Batch or single file.
#
# Author : Romain Barbarot
# https://github.com/Jocker666z/ffmes/
#
# licence : GNU GPL-2.0

# Paths
## For case of launch script outside a terminal & bin in user directory
export PATH=$PATH:/home/$USER/.local/bin
## Set script name for prevent error when rename script
FFMES_BIN=$(basename "${0}")
## Set ffmes path for restart from any directory
FFMES_PATH="$( cd "$( dirname "$0" )" && pwd )"
## Share directory
FFMES_SHARE="/home/$USER/.local/share/ffmes"
## Cache directory
FFMES_CACHE="/tmp/ffmes"
## ffprobe cache file
FFMES_FFPROBE_CACHE_STATS="$FFMES_CACHE/stat-ffprobe-$(date +%Y%m%s%N).info"
## ffmpeg cache file
FFMES_FFMPEG_CACHE_STAT="$FFMES_CACHE/stat-ffmpeg-$(date +%Y%m%s%N).info"
## tag-DATE.info, audio tag file
FFMES_CACHE_TAG="$FFMES_CACHE/tag-$(date +%Y%m%s%N).info"
## integrity-DATE.info, list of fail interity check
FFMES_CACHE_INTEGRITY="$FFMES_CACHE/interity-$(date +%Y%m%s%N).info"
## lsdvd cache
LSDVD_CACHE="$FFMES_CACHE/lsdvd-$(date +%Y%m%s%N).info"
## bluray_info cache
BDINFO_CACHE="$FFMES_CACHE/bdinfo-$(date +%Y%m%s%N).info"
## DVD player drives names
OPTICAL_DEVICE=(/dev/dvd /dev/sr0 /dev/sr1 /dev/sr2 /dev/sr3)

# General variables
## Core command needed
CORE_COMMAND_NEEDED=(ffmpeg ffprobe mkvmerge mkvpropedit find uchardet iconv wc bc du awk jq)
## Set number of processor thread
NPROC=$(grep -cE 'processor' /proc/cpuinfo)
## ffmpeg default log level
FFMPEG_LOG_LVL="-hide_banner -loglevel panic -nostats"

# Custom binary location
## ffmpeg binary, enter location of bin, if variable empty use system bin
FFMPEG_CUSTOM_BIN=""
## ffprobe binary, enter location of bin, if variable empty use system bin
FFPROBE_CUSTOM_BIN=""

# DVD & Blu-ray rip variables
## BD command needed
BLURAY_COMMAND_NEEDED=(bluray_copy bluray_info)
## DVD command needed
DVD_COMMAND_NEEDED=(dvdbackup dvdxchap lsdvd setcd pv)
## DVD & Blu-ray input extension available
ISO_EXT_AVAILABLE="iso"
VOB_EXT_AVAILABLE="vob"

# Video variables
## Video input extension available
VIDEO_EXT_AVAILABLE="3gp|avi|bik|flv|m2ts|m4v|mkv|mts|mp4|mpeg|mpg|mov|ogv|rm|rmvb|ts|vob|vp9|webm|wmv"
## Set number of video encoding in same time, the countdown starts at 0 (0=1;1=2...)
NVENC="0"
## libx265 default log level
X265_LOG_LVL="log-level=-1:"
## VAAPI device location
VAAPI_device="/dev/dri/renderD128"

# Subtitle variables
## Subtitle command needed
SUBTI_COMMAND_NEEDED=(subp2tiff subptools tesseract wget)
## Subtitle input extension available
SUBTI_EXT_AVAILABLE="ass|idx|srt|ssa|sup"

# Audio variables
## Audio command needed
CUE_SPLIT_COMMAND_NEEDED=(flac cueprint cuetag shnsplit)
## Audio input extension available
AUDIO_EXT_AVAILABLE="8svx|aac|aif|aiff|ac3|amb|ape|aptx|aud|caf|dff|dsf|dts|eac3|flac|m4a|mka|mlp|mp2|mp3|mod|mqa|mpc|mpg|oga|ogg|ops|opus|ra|ram|sbc|shn|spx|tak|thd|tta|w64|wav|wma|wv"
## Cue split input extension available
CUE_EXT_AVAILABLE="cue"
## Playlist input extension available
M3U_EXT_AVAILABLE="m3u|m3u8"
## Extract cover, 0=extract cover from source and remove in output, 1=keep cover from source in output, empty=remove cover in output
ExtractCover="0"
## Remove playlist, 0=no remove, 1=remove
RemoveM3U="0"
## Peak db normalization, value written as positive but is used in negative, e.g. 4=-4
PeakNormDB="1"

# Tag variables
## Tag command needed
TAG_COMMAND_NEEDED=(AtomicParsley metaflac mid3v2 opustags vorbiscomment wvtag)
## Tag input extension available
AUDIO_TAG_EXT_AVAILABLE="ape|flac|m4a|mp3|ogg|opus|wav|wv"

# Error messages
MESS_NO_VIDEO_FILE="No video file to process. Select one, or restart ffmes in a directory containing them"
MESS_NO_AUDIO_FILE="No audio file to process. Select one, or restart ffmes in a directory containing them"
MESS_ONE_VIDEO_ONLY="Only one video file at a time. Select one, or restart ffmes in a directory containing one video"
MESS_ONE_AUDIO_ONLY="Only one audio file at a time. Select one, or restart ffmes in a directory containing one audio"
MESS_BATCH_ONLY="Only more than one file at a time. Restart ffmes in a directory containing several files"
MESS_ONE_EXTENTION_ONLY="Only one extention type at a time."

## SOURCE FILES VARIABLES
DetectDVD() {							# DVD detection
local lsdvd_result

for DEVICE in "${OPTICAL_DEVICE[@]}"; do
	lsdvd "$DEVICE" &>/dev/null
	lsdvd_result=$?
	if [[ "$lsdvd_result" -eq 0 ]]; then
		DVD_DEVICE="$DEVICE"
		DVDtitle=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD_DEVICE" -I 2>/dev/null \
					| grep "DVD with title" \
					| tail -1 \
					| awk -F'"' '{print $2}')
		break
	fi
done
}
SetGlobalVariables() {					# Construct arrays with files accepted
# Array
unset LSTVIDEO
unset LSTVIDEOEXT
unset LSTAUDIO
unset LSTAUDIOEXT
unset LSTISO
unset LSTAUDIOTAG
unset LSTSUBEXT
unset LSTCUE
unset LSTVOB
unset LSTM3U

# Populate arrays
if [[ -n "$InputFileArg" ]]; then
	if [[ ${VIDEO_EXT_AVAILABLE[*]} =~ ${InputFileExt} ]]; then
		LSTVIDEO+=("$InputFileArg")
		mapfile -t LSTVIDEOEXT < <(echo "${LSTVIDEO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	elif [[ ${AUDIO_EXT_AVAILABLE[*]} =~ ${InputFileExt} ]]; then
		LSTAUDIO+=("$InputFileArg")
		mapfile -t LSTAUDIOEXT < <(echo "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	elif [[ ${ISO_EXT_AVAILABLE[*]} =~ ${InputFileExt} ]]; then
		LSTISO+=("$InputFileArg")
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
mapfile -t LSTAUDIOTAG < <(find . -maxdepth 2 -type f -regextype posix-egrep \
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
Media_Source_Info_Record() {			# Construct arrays with files stats
# Local variables
local source_files
local source_files_extentions
local ffprobe_fps_raw
local ffprobe_Bitrate_raw
local video_index
local audio_index
local subtitle_index
local ffprobe_Interlaced_raw
local Interlaced_frames_progressive
local Interlaced_frames_TFF

# Array
unset StreamIndex
unset ffprobe_StreamIndex
unset ffprobe_StreamType
unset ffprobe_Codec
unset ffprobe_StreamSize
unset ffprobe_StreamSize_Raw
## Video
unset ffprobe_v_StreamIndex
unset ffprobe_Profile
unset ffprobe_Width
unset ffprobe_Height
unset ffprobe_SAR
unset ffprobe_DAR
unset ffprobe_Pixfmt
unset ffprobe_ColorRange
unset ffprobe_ColorSpace
unset ffprobe_ColorTransfert
unset ffprobe_ColorPrimaries
unset ffprobe_FieldOrder
unset ffprobe_fps
## Audio
unset ffprobe_a_StreamIndex
unset ffprobe_SampleFormat
unset ffprobe_SampleRate
unset ffprobe_Channel
unset ffprobe_ChannelLayout
unset ffprobe_Bitrate
# Subtitle
unset ffprobe_s_StreamIndex
unset ffprobe_forced
## Data
unset ffprobe_d_StreamIndex
## Tag
unset ffprobe_language
# Disposition
unset ffprobe_AttachedPic
unset ffprobe_default

# File to list
source_files="$1"
# File extentions
source_files_extentions="${source_files##*.}"

# If mkv regenerate stats tag
if [[ "$source_files_extentions" = "mkv" ]] && [[ "$mkv_regenerate_stats" = "1" ]]; then
	mkvpropedit --add-track-statistics-tags "${source_files}"
	# Reset
	unset mkv_regenerate_stats
fi

# Get stats with ffprobe - probesize 1G for video / 50M for audio
if [[ ${VIDEO_EXT_AVAILABLE[*]} =~ ${source_files_extentions} ]]; then
	"$ffprobe_bin" -analyzeduration 1G -probesize 1G -loglevel panic \
		-show_chapters -show_format -show_streams -print_format json=c=1 \
		"$source_files" > "$FFMES_FFPROBE_CACHE_STATS"
else
	"$ffprobe_bin" -analyzeduration 50M -probesize 50M -loglevel panic \
		-show_chapters -show_format -show_streams -print_format json=c=1 \
		"$source_files" > "$FFMES_FFPROBE_CACHE_STATS"
fi

# Variable stats
## ffprobe stats
ffprobe_StartTime=$(ff_jqparse_format "start_time")
ffprobe_Duration=$(ff_jqparse_format "duration")
ffprobe_DurationFormated="$(Calc_Time_s_2_hms "$ffprobe_Duration")"
ffprobe_OverallBitrate=$(ff_jqparse_format "bit_rate" | awk '{ foo = $1 / 1000 ; print foo }' \
						| awk -F"." '{ print $1 }')
if ! [[ "$audio_list" = "1" ]]; then
	# Interlaced test
	ffprobe_Interlaced_raw=$(ffmpeg -v info -hide_banner -nostats \
			-filter:v idet -frames:v 1000 -an -f rawvideo -y /dev/null -i vid.mp4 2>&1 \
			| grep "Multi frame detection")
	Interlaced_frames_progressive=$(echo "$ffprobe_Interlaced_raw" \
									| awk '{for(i=1; i<=NF; i++) if($i~/Progressive:/) print $(i+1)}')
	Interlaced_frames_TFF=$(echo "$ffprobe_Interlaced_raw" \
							| awk '{for(i=1; i<=NF; i++) if($i~/TFF:/) print $(i+1)}')
	if [[ "$Interlaced_frames_TFF" -gt "$Interlaced_frames_progressive" ]];then
		ffprobe_Interlaced="1"
	fi
fi

## File size
FilesSize=$(Calc_Files_Size "$source_files")

## ffmpeg db stats
if [[ ${AUDIO_EXT_AVAILABLE[*]} =~ ${source_files_extentions} ]]; then
	"$ffmpeg_bin" -i "$source_files" -af "volumedetect" -vn -sn -dn -f null - &> "$FFMES_FFMPEG_CACHE_STAT"

	ffmpeg_meandb=$(< "$FFMES_FFMPEG_CACHE_STAT" grep "mean_volume:" | awk '{print $5}')
	ffmpeg_peakdb_raw=$(< "$FFMES_FFMPEG_CACHE_STAT" grep "max_volume:" | awk '{print $5}')
	if [[ "$ffmpeg_peakdb_raw" = "-0.0" ]]; then
		ffmpeg_peakdb_raw="0.0"
	fi
	ffmpeg_peakdb="$ffmpeg_peakdb_raw"
	ffmpeg_diffdb=$( bc <<< "$ffmpeg_peakdb - $ffmpeg_meandb" 2>/dev/null)
fi

# Array stats
## Index of video, audio & subtitle
video_index="0"
audio_index="0"
subtitle_index="0"
data_index="0"

## Map stream index
mapfile -t StreamIndex < <("$json_parser" -r '.streams[] | .index' "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null)
for index in "${StreamIndex[@]}"; do

		# Shared
		ffprobe_StreamIndex+=( "$index" )
		ffprobe_Codec+=( "$(ff_jqparse_stream "$index" "codec_name")" )
		ffprobe_StreamType+=( "$(ff_jqparse_stream "$index" "codec_type")" )
		ffprobe_StreamSize_Raw+=( "$(ff_jqparse_tag "$index" "NUMBER_OF_BYTES")" )
		ffprobe_StreamSize+=( "$(Calc_Files_Size "${ffprobe_StreamSize_Raw[-1]}" 2>/dev/null)" )
		ffprobe_Bitrate_raw=$(ff_jqparse_stream "$index" "bit_rate" \
								| awk '{ foo = $1 / 1000 ; print foo }' \
								| awk -F"." '{ print $1 }')
		if [[ "$ffprobe_Bitrate_raw" = "0" ]] && [[ "$audio_list" != "1" ]]; then
			ffprobe_Bitrate_raw=$(Calc_byte_2_kbs "${ffprobe_StreamSize_Raw[-1]}" "$ffprobe_Duration" )
			if [[ -z "$ffprobe_Bitrate_raw" ]]; then
				ffprobe_Bitrate+=( "" )
			else
				ffprobe_Bitrate+=( "$ffprobe_Bitrate_raw" )
			fi
		elif [[ "$audio_list" = "1" ]]; then
			# Display only audio stream bitrate if available
			if [[ "$ffprobe_Bitrate_raw" = "0" ]]; then
				ffprobe_Bitrate+=( "$ffprobe_OverallBitrate" )
			else
				ffprobe_Bitrate+=( "$ffprobe_Bitrate_raw" )
			fi
		else
			ffprobe_Bitrate+=( "$ffprobe_Bitrate_raw" )
		fi

		if ! [[ "$audio_list" = "1" ]]; then
			ffprobe_language+=( "$(ff_jqparse_tag "$index" "language")" )
			ffprobe_default+=( "$(ff_jqparse_disposition "$index" "default")" )
		fi

		# Video specific
		if ! [[ "$audio_list" = "1" ]]; then
			if [[ "${ffprobe_StreamType[-1]}" = "video" ]]; then
				## Fix black screen + green line (https://trac.ffmpeg.org/ticket/6668)
				#if [[ "${ffprobe_Codec[-1]}" = "mpeg2video" ]]; then
					#unset GPUDECODE
				#else
					#if [[ -z "$GPUDECODE" ]] && [[ -n "$VAAPI_device" ]]; then
						#TestVAAPI
					#fi
				#fi
				ffprobe_v_StreamIndex+=( "$video_index" )
				video_index=$((video_index+1))
				ffprobe_Profile+=( "$(ff_jqparse_stream "$index" "profile")" )
				ffprobe_Width+=( "$(ff_jqparse_stream "$index" "width")" )
				ffprobe_Height+=( "$(ff_jqparse_stream "$index" "height")" )
				ffprobe_SAR+=( "$(ff_jqparse_stream "$index" "sample_aspect_ratio")" )
				ffprobe_DAR+=( "$(ff_jqparse_stream "$index" "display_aspect_ratio")" )
				ffprobe_Pixfmt+=( "$(ff_jqparse_stream "$index" "pix_fmt")" )
				ffprobe_ColorRange+=( "$(ff_jqparse_stream "$index" "color_range")" )
				ffprobe_ColorSpace+=( "$(ff_jqparse_stream "$index" "color_space")" )
				ffprobe_ColorTransfert+=( "$(ff_jqparse_stream "$index" "color_transfer")" )
				ffprobe_ColorPrimaries+=( "$(ff_jqparse_stream "$index" "color_primaries")" )
				ffprobe_FieldOrder+=( "$(ff_jqparse_stream "$index" "field_order")" )
				ffprobe_fps_raw=$(ff_jqparse_stream "$index" "r_frame_rate")
				ffprobe_fps+=( "$(bc <<< "scale=2; $ffprobe_fps_raw" 2>/dev/null | sed 's!\.0*$!!')" )
				ffprobe_AttachedPic+=( "$(ff_jqparse_disposition "$index" "attached_pic")" )
				# HDR detection
				if [[ "${ffprobe_ColorSpace[-1]}" = "bt2020nc" ]] \
					&& [[ "${ffprobe_ColorTransfert[-1]}" = "smpte2084" ]] \
					&& [[ "${ffprobe_ColorPrimaries[-1]}" = "bt2020" ]]; then 
					ffprobe_hdr="1"
				fi
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
			ffprobe_SampleFormat+=( "$(ff_jqparse_stream "$index" "sample_fmt")" )
			ffprobe_SampleRate+=( "$(ff_jqparse_stream "$index" "sample_rate" | awk '{ foo = $1 / 1000 ; print foo }')" )
			ffprobe_Channel+=( "$(ff_jqparse_stream "$index" "channels")" )
			ffprobe_ChannelLayout+=( "$(ff_jqparse_stream "$index" "channel_layout")" )
		else
			ffprobe_a_StreamIndex+=( "" )
			ffprobe_SampleFormat+=( "" )
			ffprobe_SampleRate+=( "" )
			ffprobe_ChannelLayout+=( "" )
		fi

		# Subtitle specific
		if ! [[ "$audio_list" = "1" ]]; then
			if [[ "${ffprobe_StreamType[-1]}" = "subtitle" ]]; then
				ffprobe_s_StreamIndex+=( "$subtitle_index" )
				subtitle_index=$((subtitle_index+1))
				ffprobe_forced+=( "$(ff_jqparse_disposition "$index" "forced")" )
			else
				ffprobe_s_StreamIndex+=( "" )
				ffprobe_forced+=( "" )
			fi
		fi

		# Data specific
		if ! [[ "$audio_list" = "1" ]]; then
			if [[ "${ffprobe_StreamType[-1]}" = "data" ]]; then
				ffprobe_d_StreamIndex+=( "$data_index" )
				data_index=$((data_index+1))
			else
				ffprobe_d_StreamIndex+=( "" )
				ffprobe_forced+=( "" )
			fi
		fi

done

# ffprobe variable - end
if ! [[ "$audio_list" = "1" ]]; then
	# If ffprobe_fps[0] active consider video, if not consider audio
	# Total Frames made by calculation instead of count, less accurate but more speed up
	if [[ -n "${ffprobe_fps[0]}" ]]; then
		ffprobe_TotalFrames=$(bc <<< "scale=0; ; ( $ffprobe_Duration * ${ffprobe_fps[0]} )")
	fi

	ffprobe_ChapterNumber=$("$json_parser" -r '.chapters[]' "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null \
							| grep -c "start_time")
	if [[ "$ffprobe_ChapterNumber" -gt "1" ]]; then
		ffprobe_ChapterNumberFormated="$ffprobe_ChapterNumber chapters"
	fi
fi

# Clean
rm "$FFMES_FFPROBE_CACHE_STATS" &>/dev/null
}

## JSON PARSING
ff_jqparse_stream() {
local index
local value
index="$1"
value="$2"

"$json_parser" -r ".streams[] \
	| select(.index==$index) \
	| .$value" "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null \
	| sed s#null##g
}
ff_jqparse_tag() {
local index
local value
index="$1"
value="$2"

"$json_parser" -r ".streams[] \
	| select(.index==$index) \
	| .tags \
	| .$value" "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null \
	| sed s#null##g
}
ff_jqparse_disposition() {
local index
local value
local test
index="$1"
value="$2"

test=$("$json_parser" -r ".streams[] \
		| select(.index==$index) \
		| .disposition.$value" "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null \
		| sed s#null##g)
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
ff_jqparse_format() {
local value
value="$1"

"$json_parser" -r ".format \
	| .$value" "$FFMES_FFPROBE_CACHE_STATS" 2>/dev/null \
	| sed s#null##g
}
bd_jqparse_main_info() {
local value
value="$1"

"$json_parser" -r ".bluray.$value" "$BDINFO_CACHE" 2>/dev/null \
	| sed s#null##g
}
bd_jqparse_title() {
local title
local value
title="$1"
value="$2"

"$json_parser" -r ".titles[] \
	| select(.title==$title) \
	| .$value" "$BDINFO_CACHE" 2>/dev/null \
	| sed s#null##g
}
bd_jqparse_title_audio() {
local title
local track
title="$1"
track="$2"

# One line formated
"$json_parser" -r ".titles[] \
	| select(.title==$title) \
	| .audio[] | select(.track==$track) \
	| .language,.codec,.format,.rate" "$BDINFO_CACHE" 2>/dev/null \
	| sed ':b;N;$!bb;s/\n/, /g' | awk '$0=""$0"kHz"'
}
bd_jqparse_title_subtitles() {
local title
local track
title="$1"
track="$2"

# One line formated
"$json_parser" -r ".titles[] \
	| select(.title==$title) \
	| .subtitles[] \
	| select(.track==$track) \
	| .language" "$BDINFO_CACHE" 2>/dev/null \
	| sed ':b;N;$!bb;s/\n/, /g'
}

## CHECK FILES & BIN
CheckFFmpegVersion() {
local ffmpeg_test_hevc_vaapi_codec
local ffmpeg_test_libfdk_codec

# ffmpeg version number
ffmpeg_bin_version=$("$ffmpeg_bin" -version | awk -F 'ffmpeg version' '{print $2}' | awk 'NR==1{print $1}')
# ffmpeg version number label formating for main menu
ffmpeg_version_label="ffmpeg v${ffmpeg_bin_version}"

# ffmpeg capabilities
ffmpeg_test_hevc_vaapi_codec=$("$ffmpeg_bin" -hide_banner -loglevel quiet -encoders | grep "hevc_vaapi")
ffmpeg_test_libsvtav1_codec=$("$ffmpeg_bin" -hide_banner -loglevel quiet -encoders | grep "libsvtav1")
ffmpeg_test_libfdk_codec=$("$ffmpeg_bin" -hide_banner -loglevel quiet -codecs | grep "libfdk")
ffmpeg_test_libsoxr_filter=$("$ffmpeg_bin" -hide_banner -loglevel quiet -buildconf | grep "libsoxr")

# If no VAAPI response unset
if [[ -z "$ffmpeg_test_hevc_vaapi_codec" ]]; then
	unset VAAPI_device
fi
# If libfdk_aac present use libfdk_aac
if [[ -n "$ffmpeg_test_libfdk_codec" ]]; then
	ffmpeg_aac_encoder="libfdk_aac"
else
	ffmpeg_aac_encoder="aac"
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
if [[ "$command" = "vorbiscomment" ]]; then
	command="$command (vorbis-tools package)"
fi
if [[ "$command" = "AtomicParsley" ]]; then
	command="$command (atomicparsley package)"
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
CheckJQCommand() {
if hash gojq &>/dev/null; then
	json_parser=$(command -v gojq)
else
	json_parser=$(command -v jq)
fi
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
CheckMediaInfoCommand() {
if hash mediainfo &>/dev/null; then
	mediainfo_bin=$(command -v mediainfo)
fi
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
CheckFFmesDirectory() {					# Check ffmes directories exist
if [[ ! -d "$FFMES_CACHE" ]]; then
	mkdir "$FFMES_CACHE"
fi
if [[ ! -d "$FFMES_SHARE" ]]; then
	mkdir "$FFMES_SHARE"
fi
}
CheckFiles() {							# Promp a message to user with number of video, audio, sub to edit
# Video
if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
	Display_Line_Truncate "  * Video     > ${LSTVIDEO[0]##*/}"
elif [[ "${#LSTVIDEO[@]}" -gt "1" ]]; then
	echo "  * Videos    > ${#LSTVIDEO[@]} files"
fi

# Audio
if [[ "${#LSTAUDIO[@]}" -eq "1" ]]; then
	Display_Line_Truncate "  * Audio     > ${LSTAUDIO[0]##*/}"
elif [[ "${#LSTAUDIO[@]}" -gt "1" ]]; then
	echo "  * Audios    > ${#LSTAUDIO[@]} files"
fi

# ISO
if [[ "${#LSTISO[@]}" -eq "1" ]]; then
	Display_Line_Truncate "  * ISO       > ${LSTISO[0]}"
elif [[ "${#LSTISO[@]}" -gt "1" ]]; then
	echo "  * ISO       > ${#LSTISO[@]} files"
fi

# Subtitle
if [[ "${#LSTSUB[@]}" -eq "1" ]]; then
	Display_Line_Truncate "  * Subtitle  > ${LSTSUB[0]##*/}"
elif [[ "${#LSTSUB[@]}" -gt "1" ]]; then
	echo "  * Subtitles > ${#LSTSUB[@]} files"
fi

# DVD
if [[ -n "$DVD_DEVICE" ]]; then
	Display_Line_Truncate "  * DVD ($DVD_DEVICE): $DVDtitle"
fi

# Nothing
if [[ -z "$DVD_DEVICE" ]] && [[ "${#LSTVIDEO[@]}" -eq "0" ]] \
&& [[ "${#LSTAUDIO[@]}" -eq "0" ]] && [[ "${#LSTISO[@]}" -eq "0" ]] \
&& [[ "${#LSTSUB[@]}" -eq "0" ]]; then
	echo "  [!] No file to process"
fi
}

## DISPLAY
Usage() {
cat <<- EOF
ffmes - GNU GPL-2.0 Copyright - <https://github.com/Jocker666z/ffmes>
Bash tool handling media files, DVD & Blu-ray. Mainly with ffmpeg.

Usage:
  Select all currents: ffmes
  Select file:         ffmes -i <file>
  Select directory:    ffmes -i <directory>

In batch:
  Video batch, processes one subdirectories.
  Audio batch, processes five subdirectories.

Options:
                          Without option treat current directory.
  -ca|--compare_audio     Compare current audio files stats.
  -i|--input <file>       Treat one file.
  -i|--input <directory>  Treat in batch a specific directory.
  -h|--help               Display this help.
  -j|--videojobs <number> Number of video encoding in same time.
                          Default: 1
  -kc|--keep_cover        Keep embed image in audio files.
  --novaapi               No use vaapi.
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
echo "  / ffmes / $ffmpeg_version_label"
echo "  -----------------------------------------------------"
echo "   0 - DVD & Blu-ray rip                              |"
echo "   1 - video encoding with custom options             |-Video"
echo "   2 - copy stream to mkv with map option             |"
echo "   3 - add audio stream with night normalization      |"
echo "   4 - one audio stream encoding                      |"
echo "  -----------------------------------------------------"
echo "  10 - add audio stream or subtitle in video file     |"
echo "  11 - concatenate video files                        |-Video Tools"
echo "  12 - extract stream(s) of video file                |"
echo "  13 - split or cut video file by time                |"
echo "  14 - split mkv by chapter                           |"
echo "  15 - change color of DVD subtitle (idx/sub)         |"
echo "  16 - convert DVD subtitle (idx/sub) to srt          |"
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
echo "  31 - view audio files stats                         |-Audio Tools"
echo "  32 - generate png image of audio spectrum           |"
echo "  33 - concatenate audio files                        |"
echo "  34 - split or cut audio file by time                |"
echo "  35 - audio file tester                              |"
echo "  -----------------------------------------------------"
CheckFiles
echo "  -----------------------------------------------------"
}
Display_End_Encoding_Message() {		# Summary of encoding
local total_files
local pass_files
local source_size
local target_size

unset filesPassLabel
unset filesRejectLabel

pass_files="$1"
total_files="$2"
target_size="$3"
source_size="$4"

if (( "${#filesPass[@]}" )); then
	if (( "${#filesPassSizeReduction[@]}" )); then
		for i in "${!filesPass[@]}"; do
			filesPassLabel+=( "(${filesPassSizeReduction[i]}%) ~ $(Display_Filename_Truncate "${filesPass[i]}")" )
		done
	else
		for i in "${!filesPass[@]}"; do
			filesPassLabel+=( "$(Display_Filename_Truncate "${filesPass[i]}")" )
		done
	fi
	Echo_Separator_Light
	echo " File(s) created:"
	Display_List_Truncate "${filesPassLabel[@]}"
fi
if (( "${#filesReject[@]}" )); then
	for i in "${!filesReject[@]}"; do
		filesRejectLabel+=( "$(Display_Filename_Truncate "${filesReject[i]}")" )
	done
	Echo_Separator_Light
	echo " File(s) in error:"
	Display_List_Truncate "${filesRejectLabel[@]}"
fi

Echo_Separator_Light

if [[ -z "$total_files" ]]; then
	echo " $pass_files file(s) have been processed."
else
	echo " ${pass_files}/${total_files} file(s) have been processed."
fi
if [[ -n "$source_size" && -n "$target_size" ]]; then
	echo " Created file(s) size: ${target_size}Mb, a difference of ${PERC}% from the source(s) (${source_size}Mb)."
elif [[ -z "$source_size" && -n "$target_size" ]]; then
	echo " Created file(s) size: ${target_size}Mb."
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
if [[ "$force_compare_audio" = "1" ]]; then
	Display_Remove_Previous_Line
	echo
fi

# Title display
echo " ${#source_files[@]} audio files - $(Calc_Files_Size "${source_files[@]}")Mb"

# Table Display
if [[ "$separator_string_length" -le "$TERM_WIDTH" ]]; then
	# Title line 1
	printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo
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
		<(printf "%-${duration_string_length}.${duration_string_length}s\n" "h:m:s") <(printf "%s\n" "|") \
		<(printf "%-${peakdb_string_length}.${peakdb_string_length}s\n" "Peak") <(printf "%s\n" ".") \
		<(printf "%-${meandb_string_length}.${meandb_string_length}s\n" "Mean") <(printf "%s\n" ".") \
		<(printf "%-${diffdb_string_lenght}.${diffdb_string_lenght}s\n" "Diff") <(printf "%s\n" "|") \
		<(printf "%-${FilesSize_string_length}.${FilesSize_string_length}s\n" "Mb") <(printf "%s\n" "|") \
		<(printf "%-${filename_string_length}.${filename_string_length}s\n" "Files") | column -s $'\t' -t
	printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo


	for files in "${source_files[@]}"; do
		# Get stats
		Media_Source_Info_Record "$files"

		for i in "${!ffprobe_StreamIndex[@]}"; do
			if [[ "${ffprobe_StreamType[$i]}" = "audio" ]]; then
				# In table if term is wide enough, or in ligne
				paste <(printf "%-${codec_string_length}.${codec_string_length}s\n" "${ffprobe_Codec[i]}") <(printf "%s\n" ".") \
					<(printf "%-${bitrate_string_length}.${bitrate_string_length}s\n" "${ffprobe_Bitrate[i]}") <(printf "%s\n" ".") \
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
	printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo

# Line display
else
	# Display Separator
	printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo
	for files in "${source_files[@]}"; do
		# Get stats
		Media_Source_Info_Record "$files"

		for i in "${!ffprobe_StreamIndex[@]}"; do
			if [[ "${ffprobe_StreamType[$i]}" = "audio" ]]; then
				Display_Line_Truncate "  $files"
				echo "$(Display_Variable_Trick "$ffprobe_DurationFormated" "1" "kHz")\
				$FilesSize Mb" \
				| awk '{$2=$2};1' | awk '{print "  " $0}'
				echo "$(Display_Variable_Trick "${ffprobe_Codec[i]}" "1")\
				$(Display_Variable_Trick "${ffprobe_Bitrate[i]}" "1" "kb/s")\
				$(Display_Variable_Trick "${ffprobe_SampleFormat[i]}" "1")\
				$(Display_Variable_Trick "${ffprobe_SampleRate[i]}" "1" "kHz")\
				${ffprobe_Channel[i]} channel(s)" \
				| awk '{$2=$2};1' | awk '{print "  " $0}'
				echo " peak dB: $ffmpeg_peakdb, mean dB: $ffmpeg_meandb, diff dB: $ffmpeg_diffdb" \
				| awk '{$2=$2};1' | awk '{print "  " $0}'
				printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo
			fi
		done
	done
fi

# Only display if launched in argument
if [[ "$force_compare_audio" = "1" ]]; then
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

	# If mkv, check mkvpropedit stats
	if [[ "${source_files[$i]##*.}" = "mkv" ]]; then
		for i in "${!ffprobe_StreamIndex[@]}"; do
			if [[ "${ffprobe_StreamType[$i]}" = "video" ]] \
			&& [[ "${ffprobe_AttachedPic[$i]}" != "attached pic" ]] \
			&& [[ -z "${ffprobe_StreamSize[i]}" ]]; then

				read -r -p " mkvpropedit statistics seems to be missing, do you want to generate them? [Y/n]" qarm
				case $qarm in
					"N"|"n")
						mkv_regenerate_stats="0"
					;;
					*)
						mkv_regenerate_stats="1"
						Media_Source_Info_Record "${source_files[0]}"
					;;
				esac
			fi
			if [[ -n "$mkv_regenerate_stats" ]]; then
				break
			fi
		done
	fi
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
echo "  Duration: $ffprobe_DurationFormated, Start: $ffprobe_StartTime, Bitrate: $ffprobe_OverallBitrate kb/s, Size: ${FilesSize}Mb\
		$(Display_Variable_Trick "$ffprobe_ChapterNumberFormated" "2")" \
		| awk '{$2=$2};1' | awk '{print "  " $0}'


for i in "${!ffprobe_StreamIndex[@]}"; do

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
			$(Display_Variable_Trick "${ffprobe_StreamSize[i]}" "1" "Mb") \
			$(Display_Variable_Trick "${ffprobe_Codec[i]}")\
			$(Display_Variable_Trick "${ffprobe_Profile[i]}" "3") \
			$(Display_Variable_Trick "${ffprobe_Bitrate[i]}" "1" "kb/s") \
			$(Display_Variable_Trick "${ffprobe_Width[i]}x${ffprobe_Height[i]}")\
			$(Display_Variable_Trick "${ffprobe_SAR[i]}" "4")\
			$(Display_Variable_Trick "${ffprobe_DAR[i]}" "5")\
			$(Display_Variable_Trick "${ffprobe_fps[i]}" "1" "fps")\
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
		$(Display_Variable_Trick "${ffprobe_StreamSize[i]}" "1" "Mb") \
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

	# Data
	if [[ "${ffprobe_StreamType[$i]}" = "data" ]]; then
		echo "  Stream #${ffprobe_StreamIndex[i]}: ${ffprobe_StreamType[i]}: \
		$(Display_Variable_Trick "${ffprobe_StreamSize[i]}" "1" "Mb") \
		$(Display_Variable_Trick "${ffprobe_Codec[i]}")" \
		| awk '{$2=$2};1' | awk '{print "  " $0}'
	fi

done

Echo_Separator_Large

# Reset limit to audio files grab stats
unset audio_list
}
Display_Video_Custom_Info_choice() {	# Option 1  	- Summary of configuration
Display_Media_Stats_One "${LSTVIDEO[@]}"
echo " Target configuration:"
echo "  Video stream: $chvidstream"
if [[ "$ENCODV" = "1" ]]; then
	echo "   * Desinterlace: $chdes"
	echo "   * Resolution: $chwidth"
	if [[ "$codec" != "hevc_vaapi" ]]; then
		echo "   * Rotation: $chrotation"
		# Display only if HDR source
		if [[ -n "$ffprobe_hdr" ]]; then
			echo "   * HDR to SDR: $chsdr2hdr"
		fi
	fi
	echo "   * Codec: ${chvcodec}${chpreset}${chtune}${chprofile}"
	echo "   * Bitrate: ${vkb}${chpass}"
fi
echo "  Audio stream: $chsoundstream"
if [[ "$ENCODA" = "1" ]]; then
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
Display_Filename_Truncate() {			# Filename truncate
local label
local label_truncate
local path_occurence
label="$*"

path_occurence=$(echo "$label" | awk '{print  gsub("/","",$0)}')
if [[ "${path_occurence}" -gt "4" ]]; then
	label_truncate=$(echo "${label}" | rev | cut -d'/' -f-3 | rev)
	echo "...$label_truncate"
else
	echo "${label}"
fi
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
		echo -e "  $line" | cut -c 1-"$TERM_WIDTH_TRUNC" | awk '{print $0"..."}'
	else
		echo -e "  $line"
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
TERM_WIDTH=$(stty size)
TERM_WIDTH="${TERM_WIDTH##* }"
TERM_WIDTH_TRUNC=$(( TERM_WIDTH - 8 ))
TERM_WIDTH_PROGRESS_TRUNC=$(( TERM_WIDTH - 32 ))
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
Echo_Separator_Light() {				# Horizontal separator light
printf "%*s" "$TERM_WIDTH" "" | tr ' ' "-"; echo
}
Echo_Separator_Large() {				# Horizontal separator large
printf "%*s" "$TERM_WIDTH" "" | tr ' ' "="; echo
}
Echo_Mess_Invalid_Answer() {			# Horizontal separator large
Echo_Mess_Error "Invalid answer, please try again"
}
Echo_Mess_Error() {						# Error message preformated
local error_label
error_label="$1"
error_option="$2"

if [[ -z "$error_option" ]]; then
	echo "  [!] ${error_label}." >&2
elif [[ "$error_option" = "1" ]]; then
	echo
	echo "  [!] ${error_label}." >&2
	echo
fi
}

## CALCULATION FUNCTIONS
Calc_Table_width() {					# Table display, field width calculation
local string_length
local string_length_calc
string_length=("$@")

for string in "${string_length[@]}"; do

	if [[ -z "$string_length_calc" ]]; then
		string_length_calc="${#string}"
	fi

	if [[ "$string_length_calc" -lt "${#string}" ]]; then
		string_length_calc="${#string}"
	fi

done

echo "$string_length_calc"
}
Calc_byte_2_kbs() {						# Average kb/s of a file - Input must be in bytes & second
local size_bytes
local duration_s
local kbs

size_bytes="$1"
duration_s="$2"

if [[ -n "$size_bytes" ]] && [[ -n "$duration_s" ]]; then
	if [[ "$size_bytes" =~ ^[0-9]+$ ]]; then
		kbs=$(bc <<< "scale=0; ($size_bytes * 8) / 1000 / $duration_s")

		echo "$kbs"
	fi
fi
}
Calc_Files_Size() {						# Total size calculation in Mb - Input must be in bytes
local files
local size
local size_in_mb

files=("$@")

if (( "${#files[@]}" )); then
	# Get size in bytes
	if ! [[ "${files[-1]}" =~ ^[0-9]+$ ]]; then
		size=$(wc -c "${files[@]}" | tail -1 | awk '{print $1;}')
	else
		size="${files[-1]}"
	fi
	# Mb convert
	size_in_mb=$(bc <<< "scale=1; $size / 1024 / 1024" | sed 's!\.0*$!!')
else
	size_in_mb="0"
fi

# If string start by "." add lead 0
if [[ "${size_in_mb:0:1}" == "." ]]; then
	size_in_mb="0$size_in_mb"
fi

# If GB not display float
size_in_mb_integer="${size_in_mb%%.*}"
if [[ "${#size_in_mb_integer}" -ge "4" ]]; then
	size_in_mb="$size_in_mb_integer"
fi

echo "$size_in_mb"
}
Calc_Files_Size_bytes() {				# Total size calculation in byte
local files
local size
files=("$@")

if (( "${#files[@]}" )); then
	# Get size in bytes
	size=$(wc -c "${files[@]}" | tail -1 | awk '{print $1;}')
fi

echo "$size"
}
Calc_Percent() {						# Percentage calculation
local total
local value
local perc

value="$1"
total="$2"

if [[ "$value" = "$total" ]]; then
	echo "00.00"
else
	# Percentage calculation
	perc=$(bc <<< "scale=4; ($total - $value)/$value * 100")
	# If string start by "." or "-." add lead 0
	if [[ "${perc:0:1}" == "." ]] || [[ "${perc:0:2}" == "-." ]]; then
		if [[ "${perc:0:2}" == "-." ]]; then
			perc="${perc/-./-0.}"
		else
			perc="${perc/./+0.}"
		fi
	fi
	# If string start by integer add lead +
	if [[ "${perc:0:1}" =~ ^[0-9]+$ ]]; then
			perc="+${perc}"
	fi
	# Keep only 5 first digit
	perc="${perc:0:5}"

	echo "$perc"
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

## IN SCRIPT VARIOUS FUNCTIONS
Restart() {								# Restart script & for keep argument
Clean
if [[ -n "$ffmes_args" ]]; then
	cd "$initial_working_dir" \
	&& exec "${FFMES_PATH}/${FFMES_BIN}" "${ffmes_args_full[@]}"
else
	exec "${FFMES_PATH}/${FFMES_BIN}" && exit
fi
}
TrapStop() {							# Ctrl+z Trap for loop exit
EnterKeyEnable
Clean
stty sane
kill -s SIGTERM $!
}
TrapExit() {							# Ctrl+c Trap for script exit
EnterKeyEnable
Clean
echo
echo
stty sane
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
Clean() {								# Clean variables & temp files
# Variable reset
## Common variables
unset extcont
## Video variables
unset vstream
unset subtitleconf
unset videoformat
unset soundconf
### videoconf & this sub variable
unset videoconf
unset framerate
unset vfilter
unset vfilter_final
unset vcodec
unset preset
unset profile
unset tune
unset vkb

## Audio variables
unset afilter
unset astream
unset acodec
unset akb
unset abitdeph
unset asamplerate
unset confchan

# Files
## Old files - consider if file exist in cache directory after 3 days, delete it
find "$FFMES_CACHE/" -type f -mtime +3 -exec /bin/rm -f {} \;
## Current temp files
rm "$FFMES_FFPROBE_CACHE_STATS" &>/dev/null
rm "$FFMES_FFMPEG_CACHE_STAT" &>/dev/null
rm "$FFMES_CACHE_INTEGRITY" &>/dev/null
rm "$FFMES_CACHE_TAG" &>/dev/null
rm "$LSDVD_CACHE" &>/dev/null
rm "$BDINFO_CACHE" &>/dev/null
rm "$tmp_error" &>/dev/null
}
ffmesUpdate() {							# Option 99  	- ffmes update to lastest version (hidden option)
curl https://raw.githubusercontent.com/Jocker666z/ffmes/master/ffmes.sh > /home/"$USER"/.local/bin/ffmes && chmod +rx /home/"$USER"/.local/bin/ffmes
Restart
}
TestVAAPI() {							# VAAPI device test
if [[ -e "$VAAPI_device" ]]; then
	if "$ffmpeg_bin" -init_hw_device vaapi=foo:"$VAAPI_device" -h &>/dev/null; then
		if [[ "$chvcodec" = "hevc_vaapi" ]]; then
			GPUDECODE="-init_hw_device vaapi=foo:$VAAPI_device -hwaccel vaapi -hwaccel_output_format vaapi -hwaccel_device foo"
		else
			GPUDECODE="-vaapi_device $VAAPI_device"
		fi
	else
		unset GPUDECODE
	fi
fi
}
Remove_Audio_Split_Backup_Dir() {		# Remove CUE/AUDIO backup directory, question+action
read -r -p " Remove backup directory with cue/audio files? [y/N]:" qarm
case $qarm in
	"Y"|"y")
		# Remove source files
		rm -R backup/
		echo
	;;
	*)
		SourceNotRemoved="1"
	;;
esac
}
Remove_File_Source() {					# Remove source, question+action
if (( "${#filesPass[@]}" )); then
	read -r -p " Remove source files? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			# Remove source files
			for f in "${filesSourcePass[@]}"; do
				rm -f "$f" 2>/dev/null
			done
			if [[ "$ffmes_option" -ge 20 ]]; then
				# Remove m3u
				if [[ "$RemoveM3U" = "1" ]]; then
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
if [[ "$SourceNotRemoved" = "1" ]]; then
	read -r -p " Remove target files? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			# Remove source files
			for f in "${filesPass[@]}"; do
				rm -f "$f" 2>/dev/null
			done
			# Rename if extention same as source
			for i in "${!filesInLoop[@]}"; do
				# If file overwrite
				if [[ "${filesInLoop[i]%.*}" = "${filesOverwrite[i]%.*}" ]]; then
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
Test_Target_File() {					# Test audio & video target files
# Local variables
local source_files
local duration_type
local media_type
local duration
local false_positive_test

# Array
unset filesPass
unset filesReject
unset filesSourcePass
unset source_files

# Arguments
## duration_type = 1 = full duration test
duration_type="$1"
media_type="$2"
shift 2
source_files=("$@")

# Duration assignement
if [[ "$duration_type" != "1" ]]; then
	duration="-t 1"
fi

if (( "${#source_files[@]}" )); then

	Echo_Separator_Light
	# Progress
	ProgressBar "" "0" "${#source_files[@]}" "Validation" "1"

	for i in "${!source_files[@]}"; do
		if [[ "${source_files[$i]##*.}" =~ ${VIDEO_EXT_AVAILABLE[*]} ]] \
		|| [[ "${source_files[$i]##*.}" =~ ${AUDIO_EXT_AVAILABLE[*]} ]]; then

			# File test & error log generation
			tmp_error=$(mktemp)
			"$ffmpeg_bin" -v error $duration -i "${source_files[$i]}" \
				-max_muxing_queue_size 9999 -f null - 2> "$tmp_error"

			# False positive test
			if [[ -s "$tmp_error" ]]; then
				# not blocking, rather a warning: "non monotonically increasing dts to muxer"
				false_positive_test=$(< "$tmp_error" \
										grep "non monotonically increasing dts to muxer")
				if [[ -n "$false_positive_test" ]]; then
					rm "$tmp_error"
				fi
			fi

			# File fail
			if [[ -s "$tmp_error" ]]; then
				cp "$tmp_error" "${source_files[$i]%.*}.error.log"
				# File fail array
				filesReject+=( "${source_files[$i]}" )
				rm "${source_files[$i]}" 2>/dev/null
			# File pass
			else
				# File pass array
				filesPass+=("${source_files[$i]}")
				if [[ "$media_type" = "video" ]];then
					# If mkv regenerate stats tag
					if [[ "${source_files[$i]##*.}" = "mkv" ]]; then
						if [[ "$VERBOSE" = "1" ]]; then
							mkvpropedit --add-track-statistics-tags "${source_files[$i]}"
						else
							mkvpropedit -q --add-track-statistics-tags "${source_files[$i]}" >/dev/null 2>&1
						fi
					fi
					# Video target file pass array
					filesSourcePass+=( "${LSTVIDEO[$i]}" )
				elif [[ "$media_type" = "audio" ]];then
					# Audio target file pass array
					filesSourcePass+=( "${LSTAUDIO[$i]}" )
				fi
			fi

		else
			# Other source file pass array
			filesPass+=("${source_files[$i]}")
		fi

		# Progress
		ProgressBar "" "$((i+1))" "${#source_files[@]}" "Validation" "1"
	done

fi
}
FFmpeg_instance_count() {				# Counting ffmpeg instance for parallel job
pgrep -f ffmpeg | wc -l
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
	if [[ "$Ltask" -gt "$TERM_WIDTH_TRUNC" ]]; then
		task=$(echo "${task:0:$TERM_WIDTH_TRUNC}" | awk '{print $0"..."}')
	fi
	msg=$2
	Lmsg="${#2}"
	if [[ "$Lmsg" -gt "$TERM_WIDTH_TRUNC" ]]; then
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

# Arguments
sourcefile=$(Display_Line_Progress_Truncate "${1##*/}")
CurrentFilesNB="$2"
TotalFilesNB="$3"
ProgressTitle="$4"
if [[ -n "$5" ]]; then
	ProgressBarOption="$5"
else
	unset ProgressBarOption
fi

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
	while [[ ! -f "$FFMES_FFMPEG_PROGRESS" ]] \
	   && [[ ! -s "$FFMES_FFMPEG_PROGRESS" ]]; do
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
		CurrentState=$(tail -n 13 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null \
						| grep "progress" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }')
		CurrentDuration=$(tail -n 13 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null \
						| grep "out_time_ms" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }')
		CurrentDuration=$(( CurrentDuration/1000000 ))

		# Get extra value
		Currentfps=$(tail -n 13 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null \
					| grep "fps" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }')
		Currentbitrate=$(tail -n 13 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null \
						| grep "bitrate" 2>/dev/null | tail -1 \
						| awk -F"=" '{ print $2 }' | awk -F"." '{ print $1 }')
		CurrentSize=$(tail -n 13 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null \
						| grep "total_size" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }' \
						| awk '{ foo = $1 / 1024 / 1024 ; print foo }')

		# ETA - If ffprobe_fps[0] active consider video, if not consider audio
		if [[ -n "${ffprobe_fps[0]}" ]]; then
			Current_Frame=$(tail -n 13 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null \
							| grep "frame=" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }')
			if [[ "$Currentfps" = "0.00" ]] || [[ -z "$Currentfps" ]];then
				CurrentfpsETA="0.01"
			else
				CurrentfpsETA="$Currentfps"
			fi
			if [[ -z "$Current_Frame" ]];then
				Current_Frame="1"
			fi
			# if Current_Frame stuck at 1, consider ETA value is invalid
			if [[ "$Current_Frame" -eq "1" ]]; then
				Current_ETA="ETA: N/A"
			else
				Current_Remaining=$(bc <<< "scale=0; ; ( ($ffprobe_TotalFrames - $Current_Frame) / $CurrentfpsETA)")
				Current_ETA="ETA: $((Current_Remaining/3600))h$((Current_Remaining%3600/60))m$((Current_Remaining%60))s"
			fi
		else
			Current_ETA=$(tail -n 13 "$FFMES_FFMPEG_PROGRESS" 2>/dev/null \
						| grep "speed" 2>/dev/null | tail -1 | awk -F"=" '{ print $2 }')
		fi

		# Displayed label
		if [[ -n "${Currentbitrate}" ]]; then
			ExtendLabel=$(echo "$(Display_Variable_Trick "${Current_ETA}" "7")\
						$(Display_Variable_Trick "${Currentfps}" "7" "fps")\
						$(Display_Variable_Trick "${Currentbitrate}" "7" "kb/s")\
						$(Display_Variable_Trick "${CurrentSize}" "7" "Mb")" \
						| awk '{$2=$2};1' | awk '{print "  " $0}' | tr '\n' ' ')
		else
			# Standby first interval time calculation for prevent (standard_in) 1: syntax error
			if [[ -n "$interval_calc" ]]; then
				Current_ETA="IDLE: $(bc <<< "scale=0; ; ( $interval_calc / 1000)")/$(bc <<< "scale=0; ; ( $TimeOut / 1000)")s"
			fi
			ExtendLabel=$(echo "$(Display_Variable_Trick "${Current_ETA}" "7")\
						$(Display_Variable_Trick "${Currentfps}" "7" "fps")\
						$(Display_Variable_Trick "${Currentbitrate}" "7" "kb/s")\
						$(Display_Variable_Trick "${CurrentSize}" "7" "Mb")" \
						| awk '{$2=$2};1' | awk '{print "  " $0}' | tr '\n' ' ')
		fi

		# Display variables
		# End case
		if [[ "$CurrentState" = "end" ]]; then
			_progress="100"
		# Total duration not available (dts audio)
		elif [[ -z "$TotalDuration" ]]; then
			_progress="100"
		# Common case
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
			rm "$FFMES_FFMPEG_PROGRESS" &>/dev/null
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
			rm "$FFMES_FFMPEG_PROGRESS" &>/dev/null
			echo
			break
		fi
		# Other break
		if [[ ! -f "$FFMES_FFMPEG_PROGRESS" && "$_progress" != "100" && "$CurrentState" != "end" ]]; then
			# Loop fail
			loop_pass="1"
			echo -e -n "\r\e[0K ]${_done// /▇}${_left// / }[ ${_progress}% - [!] ffmpeg fail"
			rm "$FFMES_FFMPEG_PROGRESS" &>/dev/null
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
local lsdvd_result
local DVD
local DVDINFO
local DVDtitle
local TitleParsed
local AspectRatio
local PCM
local pcm_dvd
local VIDEO_EXT_AVAILABLE
local qtitle

clear
echo
echo " DVD rip"
echo " notes: * for DVD, launch ffmes in directory without ISO & VOB, if you have more than one drive, insert only one DVD."
echo "        * for ISO, launch ffmes in directory with ISO (without VOB)"
echo "        * for VOB, launch ffmes in directory with VOB (in VIDEO_TS/) "
echo "        * for VOB, launch ffmes in directory with VIDEO_TS/"
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
if [[ -d VIDEO_TS ]]; then
	DVD="VIDEO_TS/"
elif [[ "${#LSTVOB[@]}" -ge "1" ]]; then
	DVD="./"
elif [[ "${#LSTISO[@]}" -eq "1" ]]; then
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
lsdvd_result=$?
if ! [[ "$lsdvd_result" -eq 0 ]]; then
	echo
	Echo_Mess_Error "$DVD is not valid DVD video"
	echo
	exit
fi

# Get stats
lsdvd -a -s "$DVD" 2>/dev/null \
	| awk '/Disc Title/,0' \
	| awk -F', AP:' '{print $1}' \
	| awk -F', Subpictures' '{print $1}' \
	| awk ' {gsub("Quantization: drc, ","");print}' \
	| sed 's/^/    /' > "$LSDVD_CACHE"
# Parse titles
DVDtitle=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null \
			| grep "DVD with title" \
			| tail -1 \
			| awk -F'"' '{print $2}')
# All titles to array
mapfile -t DVD_TITLES < <(lsdvd "$DVD" 2>/dev/null | awk '/Disc Title/,0' | grep Title | awk '{print $2}' |  grep -o '[[:digit:]]*')

# Question: Title to rip
echo
if [[ "${#LSTVOB[@]}" -ge "1" ]]; then
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

# Question: DVD title name
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

# Rip loop
for title in "${qtitle[@]}"; do
	RipFileName=$(echo "${DVDtitle}-${title}")

	# Get aspect ratio
	TitleParsed="${title##*0}"
	AspectRatio=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null \
					| grep "The aspect ratio of title set $TitleParsed" \
					| tail -1 \
					| awk '{print $NF}')
	# If aspect ratio empty, get main feature aspect
	if [[ -z "$AspectRatio" ]]; then
		AspectRatio=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null \
						| grep "The aspect ratio of the main feature is" \
						| tail -1 \
						| awk '{print $NF}')
	fi

	# Extract chapters
	Echo_Separator_Light
	echo " Extract chapters - $DVDtitle - title $title"
	dvdxchap -t "$title" "$DVD" 2>/dev/null \
		| awk '/CHAPTER/,0' > "$RipFileName".chapters

	# Extract VOB
	Echo_Separator_Light
	echo " Extract VOB - $DVDtitle - title $title"
	dvdbackup -p -t "$title" -i "$DVD" -n "$RipFileName" &>/dev/null

	# Concatenate VOB
	Echo_Separator_Light
	mapfile -t LSTVOB < <(find ./"$RipFileName" -maxdepth 3 -type f -regextype posix-egrep -iregex '.*\.('$VOB_EXT_AVAILABLE')$' 2>/dev/null \
		| sort | sed 's/^..//')
	echo " Concatenate VOB - $DVDtitle - title $title"
	cat -- "${LSTVOB[@]}" | pv -p -t -e -r -b > "$RipFileName".VOB

	# Remove data stream, fix DAR, add chapters, and change container
	Echo_Separator_Light
	echo " Make clean mkv - $DVDtitle - title $title"
	# Fix pcm_dvd stream
	PCM=$("$ffprobe_bin" -analyzeduration 1G -probesize 1G -v error -show_entries stream=codec_name -print_format csv=p=0 "$RipFileName".VOB \
			| grep pcm_dvd)
	# pcm_dvd to pcm (trick)
	if [[ -n "$PCM" ]]; then
		pcm_dvd="-c:a pcm_s16le"
	fi

	# FFmpeg - clean mkv
	# For progress bar
	FFMES_FFMPEG_PROGRESS="$FFMES_CACHE/ffmpeg-progress-$(date +%Y%m%s%N).info"
	FFMPEG_PROGRESS="-stats_period 0.3 -progress $FFMES_FFMPEG_PROGRESS"
	#FFMES_FFMPEG_PROGRESS="$FFMES_CACHE/ffmpeg-progress-$(date +%Y%m%s%N).info"
	Media_Source_Info_Record "${RipFileName}.VOB"
	if [[ "$VERBOSE" = "1" ]]; then
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -fflags +genpts+igndts \
			-analyzeduration 1G -probesize 1G \
			-i "$RipFileName".VOB \
			$FFMPEG_PROGRESS \
			-map 0:v -map 0:a? -map 0:s? \
			-c copy $pcm_dvd -aspect $AspectRatio "$RipFileName".mkv
	else
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -fflags +genpts+igndts \
			-analyzeduration 1G -probesize 1G \
			-i "$RipFileName".VOB \
			$FFMPEG_PROGRESS \
			-map 0:v -map 0:a? -map 0:s? \
			-c copy $pcm_dvd -aspect $AspectRatio "$RipFileName".mkv \
			| ProgressBar "${RipFileName}.mkv" "1" "1" "Encoding"
	fi

	# Add chapters mkvpropedit
	Echo_Separator_Light
	echo " Add chapters - $DVDtitle - title $title"
	if [[ "$VERBOSE" = "1" ]]; then
		mkvpropedit --add-track-statistics-tags -c "$RipFileName".chapters "$RipFileName".mkv
	else
		mkvpropedit --add-track-statistics-tags -q -c "$RipFileName".chapters "$RipFileName".mkv 2>/dev/null
	fi

	# Check Target if valid (size test) and clean
	if [[ $(stat --printf="%s" "$RipFileName".mkv 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
		rm "$RipFileName".chapters 2>/dev/null
		rm -f "$RipFileName".VOB 2>/dev/null
		rm -R -f "$RipFileName" 2>/dev/null
	else																				# if file<30 KBytes rejected
		echo "X FFmpeg pass of DVD Rip fail"
		rm -R -f "$RipFileName".mkv 2>/dev/null
		rm "$RipFileName".chapters 2>/dev/null
	fi
done

# map
unset TESTARGUMENT
VIDEO_EXT_AVAILABLE="mkv"
mapfile -t LSTVIDEO < <(find . -maxdepth 1 -type f -regextype posix-egrep -regex '.*\.('$VIDEO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

# encoding question
if (( "${#LSTVIDEO[@]}" )); then
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
DVDSubColor() {							# Option 15 	- Change color of DVD sub
# Local variables
local rps
local palette

# Set available ext.
SUBTI_EXT_AVAILABLE="idx"
# Regen list of sub
mapfile -t LSTSUB < <(find . -maxdepth 1 -type f -regextype posix-egrep \
	-iregex '.*\.('$SUBTI_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

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
read -r -e -p "-> " rps
case $rps in

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
DVDSub2Srt() {							# Option 16 	- DVD sub to srt
# Local variables
local pair_error
local rps
local proper_filename
local sub_id_selected
local sub_id
local SubLang
local Tesseract_Arg
local COUNTER
local TIFF_NB
local TOTAL

unset list_sub_id
unset pair_error_list

# Set available ext.
SUBTI_EXT_AVAILABLE="idx"
# Regen list of sub
mapfile -t LSTSUB < <(find . -maxdepth 1 -type f -regextype posix-egrep \
	-iregex '.*\.('$SUBTI_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

# Test idx/sub pair
for files in "${LSTSUB[@]}"; do
	if ! [[ -f "${files%.*}.sub" ]] && [[ -f "${files%.*}.idx" ]]; then
		pair_error="1"
		pair_error_list+=( "$files" )
	fi
done

# Fail if not pair
if [[ "$pair_error" = "1" ]]; then

	echo
	Echo_Mess_Error "The pair idx/sub must have the exact same file name"
	echo "  File(s) without sub pair:"
	Display_List_Truncate "${pair_error_list[@]}"
	echo

# Main if pair
else

	# Backup original files
	if [[ ! -d IDX_Backup/ ]]; then
		mkdir IDX_Backup 2>/dev/null
	fi
	for files in "${LSTSUB[@]}"; do
		cp "${files%.*}".idx IDX_Backup/
		cp "${files%.*}".sub IDX_Backup/
	done
	# Test filename/rename for prevent subptools fail
	for files in "${LSTSUB[@]}"; do
		proper_filename="${files[$i]//&/and}"
		proper_filename="${proper_filename//[ '"'"'"()@$:]/_}"
		mv "${files%.*}".idx "${proper_filename%.*}".idx
		mv "${files%.*}".sub "${proper_filename%.*}".sub
	done

	# Regen list of sub
	mapfile -t LSTSUB < <(find . -maxdepth 1 -type f -regextype posix-egrep \
		-iregex '.*\.('$SUBTI_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
		
	# Choose sub id function
	subid_choose() {
		printf '  %s\n' "${LSTSUB[0]}"
		printf '   %s\n' "${list_sub_id[@]}"
		echo
		while true; do
			read -r -e -p "-> " rps
			# Not integer retry
			if ! [[ $rps =~ ^[0-9]+$ ]]; then
				Echo_Mess_Error "Index must be an integer"
			elif [[ "$rps" -lt "${#list_sub_id[@]}" ]]; then
				sub_id_selected="$rps"
				break
			fi
		done
		echo
		echo " Select subtitle language for this index:"
	}

	# SUB id count
	mapfile -t list_sub_id < <(< "${LSTSUB[0]}" grep "id:")

	clear
	echo
	if [[ "${#list_sub_id[@]}" -gt "1" ]] && [[ "${#LSTSUB[@]}" -gt "1" ]]; then
		echo "Choose the index to convert:"
		echo "notes:  * below the list of languages for the first file"
		echo "        * if the id is not present on the other files, 0 will be used."
		echo "        * if the language is different, the processing will be bad."
		subid_choose
	elif [[ "${#list_sub_id[@]}" -gt "1" ]] && [[ "${#LSTSUB[@]}" -eq "1" ]]; then
		echo "Choose the index to convert:"
		subid_choose
	else
		echo " Select subtitle language for:"
		printf '  %s\n' "${LSTSUB[@]}"
		sub_id_selected="0"
	fi
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
	read -r -e -p "-> " rps
	case $rps in

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
			SubLang="chi_sim"
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
	echo " *[1] > reliable - By recognizing character + neural net"
	echo "  [q] > for exit"
	while :
	do
	read -r -e -p "-> " rps
	case $rps in
		"0")
			if [[ "$SubLang" = "chi_sim" ]];then
				Tesseract_Arg="--oem 1 --psm 6 -c preserve_interword_spaces=1 --tessdata-dir ${FFMES_SHARE}/tesseract"
			else
				Tesseract_Arg="--oem 1 --tessdata-dir ${FFMES_SHARE}/tesseract"
			fi
			break
		;;
		"1")
			if [[ "$SubLang" = "chi_sim" ]];then
				Tesseract_Arg="--oem 2 --psm 6 -c preserve_interword_spaces=1 --tessdata-dir ${FFMES_SHARE}/tesseract"
			else
				Tesseract_Arg="--oem 2 --tessdata-dir ${FFMES_SHARE}/tesseract"
			fi
			break
		;;
		"q"|"Q")
			Restart
		;;
			*)
			if [[ "$SubLang" = "chi_sim" ]];then
				Tesseract_Arg="--oem 2 --psm 6 -c preserve_interword_spaces=1 --tessdata-dir ${FFMES_SHARE}/tesseract"
			else
				Tesseract_Arg="--oem 2 --tessdata-dir ${FFMES_SHARE}/tesseract"
			fi
			break
			;;
	esac
	done

	# traineddata
	# Check tesseract traineddata dir
	if [[ ! -d "$FFMES_SHARE"/tesseract ]]; then
		mkdir "$FFMES_SHARE"/tesseract
	fi

	# Check tesseract traineddata file is empty
	if [[ -f "${FFMES_SHARE}/tesseract/$SubLang.traineddata" ]] \
	&& [[ ! -s "${FFMES_SHARE}/tesseract/$SubLang.traineddata" ]]; then
		rm "${FFMES_SHARE}/tesseract/$SubLang.traineddata"
	fi

	# Check tesseract traineddata file
	if [[ ! -f "${FFMES_SHARE}/tesseract/$SubLang.traineddata" ]]; then

		StartLoading "Downloading Tesseract trained models: ${SubLang}.traineddata"

		if [[ "$VERBOSE" = "1" ]]; then
			wget https://github.com/tesseract-ocr/tessdata/blob/main/"$SubLang".traineddata?raw=true \
				-O "$FFMES_SHARE"/tesseract/"$SubLang".traineddata
		else
			wget https://github.com/tesseract-ocr/tessdata/blob/main/"$SubLang".traineddata?raw=true \
				-O "$FFMES_SHARE"/tesseract/"$SubLang".traineddata &>/dev/null
		fi

		StopLoading $?

	fi

	# Check tesseract traineddata file still empty
	if [[ -f "${FFMES_SHARE}/tesseract/$SubLang.traineddata" ]] \
	&& [[ ! -s "${FFMES_SHARE}/tesseract/$SubLang.traineddata" ]]; then
		rm "${FFMES_SHARE}/tesseract/$SubLang.traineddata"
		Echo_Mess_Error "An error occurred, Tesseract trained models (${SubLang}.traineddata) was not downloaded"
		exit
	fi

	# Convert loop
	echo
	Echo_Separator_Light
	for files in "${LSTSUB[@]}"; do

		# Test idx index choose exist, if not use 0
		if [[ "$sub_id_selected" != "0" ]]; then
			mapfile -t list_sub_id < <(< "$files" grep "id:" )
			for i in "${!list_sub_id[@]}"; do
				if [[ $i -eq $sub_id_selected ]]; then
					sub_id="$sub_id_selected"
					break
				else
					sub_id="0"
				fi
			done
		else
			sub_id="0"
		fi

		# Extract tiff
		StartLoading "${files%.*}: Extract tiff files"
		if [[ "$VERBOSE" = "1" ]]; then
			subp2tiff --sid="$sub_id" -n "${files%.*}"
		else
			subp2tiff --sid="$sub_id" -n "${files%.*}" &>/dev/null
		fi
		StopLoading $?

		# Convert tiff in text
		TOTAL=(*.tif)
		for tfiles in *.tif; do
			# Counter
			TIFF_NB=$(( COUNTER + 1 ))
			COUNTER=$TIFF_NB
			# Progress
			ProgressBar "" "${COUNTER}" "${#TOTAL[@]}" "tif to text files" "1" 
			(
			if [[ "$VERBOSE" = "1" ]]; then
				tesseract $Tesseract_Arg "$tfiles" "$tfiles" -l "$SubLang"
			else
				tesseract $Tesseract_Arg "$tfiles" "$tfiles" -l "$SubLang" &>/dev/null
			fi
			) &
			if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
				wait -n
			fi
		done
		wait

		StartLoading "${files%.*}: Convert text files in srt"

		# Convert text in srt
		if [[ "$VERBOSE" = "1" ]]; then
			subptools -s -w -t srt -i "${files%.*}".xml -o "${files%.*}_${sub_id}_${SubLang}".srt
		else
			subptools -s -w -t srt -i "${files%.*}".xml -o "${files%.*}_${sub_id}_${SubLang}".srt &>/dev/null
		fi

		# Remove ^L/\f/FF/form-feed/page-break character
		sed -i 's/\o14//g' "${files%.*}_${sub_id}_${SubLang}".srt &>/dev/null

		StopLoading $?
		echo

		# Clean
		COUNTER=0
		rm -- *.tif &>/dev/null
		rm -- *.txt &>/dev/null
		rm -- *.xml &>/dev/null

	done

fi
}

## Blu-ray
BLURAYrip() {							# Option 0  	- Blu-ray Rip
# Local variables
local BD_disk
local bd_disk_name
local bd_track_audio_test
local bd_track_subtitle_test
local temp_bd_title_audio
local temp_bd_title_subtitle
local stream_counter

# Arrays
unset bd_title_pass_extract
unset bd_title_pass
unset bd_title_duration
unset bd_title_filesize
unset bd_title_video_format
unset bd_title_video_codec
unset bd_title_audio
unset bd_track_audio_nb
unset bd_title_audio_stream
unset bd_title_subtitle
unset bd_track_subtitle_nb
unset bd_title_subtitle_tracks_lang
unset bd_title_subtitle_metadata
unset bd_title_subtitle_stream

clear
echo
echo " Blu-ray rip"
echo " notes: * for ISO, launch ffmes in directory with one ISO"
echo "        * for disk directory, launch ffmes in Blu-ray disk directory (must writable)"
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
elif [[ -z "$BD_disk" ]] && [[ "${#LSTISO[@]}" -eq "1" ]]; then
	BD_disk="${LSTISO[0]}"
else
	echo
	Echo_Mess_Error "No ISO or Blu-Ray directory"
	echo
fi

if [[ -n "$BD_disk" ]]; then

	# Record global json - jq sub "space" by "_" in key
	bluray_info -j "$BD_disk" 2>/dev/null \
		| "$json_parser" 'walk( if type == "object" then with_entries( .key |= ( gsub( " "; "_"))) else . end )' > "$BDINFO_CACHE"

	# BD name
	bd_disk_name=$(bd_jqparse_main_info "disk_name")
	# Try another key
	if [[ -z "$bd_disk_name" ]]; then
		bd_disk_name=$(bd_jqparse_main_info "disc_name")
	fi
	# Still empty
	if [[ -z "$bd_disk_name" ]]; then
		bd_disk_name="UnknownBD"
	fi

	# Extract view Stat
	echo
	Display_Line_Truncate " Blu-ray: $bd_disk_name"

	# Size of table
	horizontal_separator_string_length=$(( 7 * 5 ))
	separator_string_length=$(( 3 + 4 + 8 + 5 + 5 + 32 + 8 + horizontal_separator_string_length ))

	# Print title raw of table0
	echo
	printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo
	paste <(printf "%-3.3s\n" "") <(printf "%s\n" "|") \
			<(printf "%-4.4s\n" "Size") <(printf "%s\n" "|") \
			<(printf "%-8.8s\n" "Duration") <(printf "%s\n" "|") \
			<(printf "%-5.5s\n" "Fmt") <(printf "%s\n" "|") \
			<(printf "%-5.5s\n" "Codec") <(printf "%s\n" "|") \
			<(printf "%-32b" "Audio") <(printf "%s\n" "|") \
			<(printf "%-8b\n" "Subtitle") | column -s $'\t' -t
	printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo

	# Titles stats
	mapfile -t bd_titles < <("$json_parser" -r '.titles[] | .title' "$BDINFO_CACHE")
	for title in "${bd_titles[@]}"; do

		# Raw duration for exclude no interesting data (10s)
		bd_title_raw_duration=$(bd_jqparse_title "$title" "msecs")
		if [[ "$bd_title_raw_duration" -gt "1000" ]]; then

			# Add title in the available files array
			bd_title_pass+=( "$title" )

			# Shared
			bd_title_duration+=( "$(bd_jqparse_title "$title" "length" | awk -F"." '{ print $1 }')" )
			bd_title_filesize+=( "$(bd_jqparse_title "$title" "filesize" | numfmt --to=iec)" )

			# Video
			bd_title_video_format+=( "$("$json_parser" -r ".titles[] \
									| select(.title==$title) | .video[] \
									| .format" "$BDINFO_CACHE" 2>/dev/null)" )
			bd_title_video_codec+=( "$("$json_parser" -r ".titles[] \
									| select(.title==$title) | .video[] \
									| .codec" "$BDINFO_CACHE" 2>/dev/null)" )

			# Audio
			bd_track_audio_test=$("$json_parser" -r ".titles[] \
								| select(.title==$title) | .audio[] \
								| select(.track==1)" "$BDINFO_CACHE")
			if [[ -n "$bd_track_audio_test" ]]; then
				mapfile -t bd_title_audio_tracks < <("$json_parser" -r ".titles[] \
													| select(.title==$title) | .audio[] \
													| .track" "$BDINFO_CACHE" 2>/dev/null \
													| sed s#null##g)
				for audio_track in "${bd_title_audio_tracks[@]}"; do
					if [[ "${bd_title_audio_tracks[-1]}" != "$audio_track" ]]; then
						temp_bd_title_audio+="$(bd_jqparse_title_audio "$title" "$audio_track")\n"
					else
						temp_bd_title_audio+="$(bd_jqparse_title_audio "$title" "$audio_track")"
					fi
				done
			else
				temp_bd_title_audio="~"
			fi
			bd_title_audio+=( "$temp_bd_title_audio" )
			unset temp_bd_title_audio

			# Subtitle
			bd_track_subtitle_test=$("$json_parser" -r ".titles[] \
									| select(.title==$title) | .subtitles[] \
									| select(.track==1)" "$BDINFO_CACHE")
			if [[ -n "$bd_track_subtitle_test" ]]; then
				mapfile -t bd_title_subtitle_tracks < <("$json_parser" -r ".titles[] \
														| select(.title==$title) | .subtitles[] \
														| .track" "$BDINFO_CACHE" 2>/dev/null \
														| sed s#null##g)
				for subtitle_track in "${bd_title_subtitle_tracks[@]}"; do
					if [[ "${bd_title_subtitle_tracks[-1]}" != "$subtitle_track" ]]; then
						if [[ "${temp_bd_title_subtitle: -1}" = " " ]]; then
							temp_bd_title_subtitle+="$(bd_jqparse_title_subtitles "$title" "$subtitle_track")\n"
						else
							temp_bd_title_subtitle+="$(bd_jqparse_title_subtitles "$title" "$subtitle_track"), "
						fi
					else
						temp_bd_title_subtitle+="$(bd_jqparse_title_subtitles "$title" "$subtitle_track")"
					fi
				done
			else
				temp_bd_title_subtitle="~"
			fi
			bd_title_subtitle+=( "$temp_bd_title_subtitle" )
			unset temp_bd_title_subtitle

			# Print title stats
			paste <(printf "%-3.3s\n" "${title}") <(printf "%s\n" ".") \
					<(printf "%-4.4s\n" "${bd_title_filesize[-1]}") <(printf "%s\n" ".") \
					<(printf "%-8.8s\n" "${bd_title_duration[-1]}") <(printf "%s\n" ".") \
					<(printf "%-5.5s\n" "${bd_title_video_format[-1]}") <(printf "%s\n" ".") \
					<(printf "%-5.5s\n" "${bd_title_video_codec[-1]}") <(printf "%s\n" ".") \
					<(printf "%-32b" "${bd_title_audio[-1]}") <(printf "%s\n" ".") \
					<(printf "%-8b\n" "${bd_title_subtitle[-1]}") | column -s $'\t' -t
			printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "."; echo

		fi
	done

	echo " Select one or all files:"
	echo
	echo "  [a] > for all"
	echo "  [n] > for n as title number"
	echo "  [q] > for exit"
	while true; do
		read -r -e -p "  -> " bdtitlerep
		if [[ "$bdtitlerep" = "q" ]]; then
			Restart
		fi
		if [[ "$bdtitlerep" = "a" ]]; then
			bd_title_pass_extract=( "${bd_title_pass[@]}" )
			break 2
		fi
		for test in "${bd_title_pass[@]}"; do
			if [[ "$test" = "$bdtitlerep" ]]; then
				bd_title_pass_extract+=( "${bdtitlerep}" )
				break 2
			fi
		done
		Echo_Mess_Error "Please select a title number display in the table."
	done

	for title in "${bd_title_pass_extract[@]}"; do

		# Reset array
		unset bd_title_audio_stream
		unset bd_track_subtitle_nb
		unset bd_title_subtitle_stream
		unset bd_title_subtitle_tracks_lang
		unset bd_title_subtitle_metadata

		# Extract audio stream
		mapfile -t bd_track_audio_nb < <("$json_parser" -r ".titles[] \
										| select(.title==$title) | .audio[] | .track" "$BDINFO_CACHE")
		if (( "${#bd_track_audio_nb[@]}" )); then
			# Stream
			for i in ${!bd_track_audio_nb[*]}; do
				bd_title_audio_stream+=( "-map 0:a:${i}" )
			done
		fi

		# Extract subtitle stream & metadata
		mapfile -t bd_track_subtitle_nb < <("$json_parser" -r ".titles[] \
											| select(.title==$title) | .subtitles[] | .track" "$BDINFO_CACHE")
		if (( "${#bd_track_subtitle_nb[@]}" )); then
			# Stream
			for i in ${!bd_track_subtitle_nb[*]}; do
				bd_title_subtitle_stream+=( "-map 0:s:${i}" )
			done

			# Metadata
			mapfile -t bd_title_subtitle_tracks_lang < <("$json_parser" -r ".titles[] \
														| select(.title==$title) | .subtitles[] \
														| .language" "$BDINFO_CACHE" 2>/dev/null \
														| sed s#null##g)
			stream_counter="0"
			for subtitle_lang in "${bd_title_subtitle_tracks_lang[@]}"; do
				bd_title_subtitle_metadata+=( "-metadata:s:s:${stream_counter} language=${subtitle_lang}" )
				((stream_counter=stream_counter+1))
			done
		fi

		# Extract chapters
		bluray_info -t "$title" -g "$BD_disk" 2>/dev/null > "${bd_disk_name}.${title}".chapter

		# Remux
		bluray_copy "$BD_disk" -t "$title" -o - 2>/dev/null \
			| "$ffmpeg_bin" -hide_banner -y -i - -threads 0 \
				-map 0:v \
				$(IFS=' ';echo "${bd_title_audio_stream[*]}";IFS=$' \t\n') \
				$(IFS=' ';echo "${bd_title_subtitle_stream[*]}";IFS=$' \t\n') \
				-codec copy \
				$(IFS=' ';echo "${bd_title_subtitle_metadata[*]}";IFS=$' \t\n') \
				-ignore_unknown -max_muxing_queue_size 4096 \
				"${bd_disk_name}.${title}".Remux.mkv \
				&& echo "  ${bd_disk_name}.${title}.Remux.mkv remux done" \
				|| Echo_Mess_Error "${bd_disk_name}.${title}.Remux.mkv remux fail"

		# Add chapters
		if [[ "$VERBOSE" = "1" ]]; then
			mkvpropedit --add-track-statistics-tags -c "${bd_disk_name}.${title}".chapter \
				"${bd_disk_name}.${title}".Remux.mkv
		else
			mkvpropedit --add-track-statistics-tags -q -c "${bd_disk_name}.${title}".chapter \
			"${bd_disk_name}.${title}".Remux.mkv 2>/dev/null \
				&& echo "  ${bd_disk_name}.${title}.Remux.mkv add chapters done" \
				|| Echo_Mess_Error "${bd_disk_name}.${title}.Remux.mkv add chapters fail"
		fi

		# Clean
		rm "${bd_disk_name}.${title}".chapter 2>/dev/null

	done

fi
}

## VIDEO
Video_FFmpeg_cmd() {					# FFmpeg video encoding command
# Local variables
local PERC
local total_source_files_size
local total_target_files_size
local START
local END
# Array
unset filesInLoop

# Start time counter
START=$(date +%s)

# Disable the enter key
EnterKeyDisable

# Encoding
for i in "${!LSTVIDEO[@]}"; do

	# Target files pass in loop for validation test
	filesInLoop+=( "${LSTVIDEO[i]%.*}.$videoformat.$extcont" )

	# Progress bar
	if [[ "${#LSTVIDEO[@]}" = "1" ]] || [[ "$NVENC" = "0" ]]; then
		# No relaunch Media_Source_Info_Record for first array item
		if [[ "$i" != "0" ]]; then
			Media_Source_Info_Record "${LSTVIDEO[i]}"
		fi
		FFMES_FFMPEG_PROGRESS="$FFMES_CACHE/ffmpeg-progress-$(date +%Y%m%s%N).info"
		FFMPEG_PROGRESS="-stats_period 0.3 -progress $FFMES_FFMPEG_PROGRESS"
	fi
	(
	if [[ "$VERBOSE" = "1" ]]; then
		if [[ "$PASS2" = "1" ]]; then
		"$ffmpeg_bin" $FFMPEG_LOG_LVL \
			-analyzeduration 1G -probesize 1G \
			$GPUDECODE \
			-y -i "${LSTVIDEO[i]}" \
			$FFMPEG_PROGRESS \
			-threads 0 \
			$vstream $videoconf $soundconf $subtitleconf -max_muxing_queue_size 4096 \
			-x265-params pass=1 -f null /dev/null \
			| ProgressBar "${LSTVIDEO[i]} Pass 1" "$((i+1))" "${#LSTVIDEO[@]}" "Encoding"
		"$ffmpeg_bin" $FFMPEG_LOG_LVL \
			-analyzeduration 1G -probesize 1G \
			$GPUDECODE \
			-y -i "${LSTVIDEO[i]}" \
			$FFMPEG_PROGRESS \
			-threads 0 \
			$vstream $videoconf $soundconf $subtitleconf -max_muxing_queue_size 4096 \
			-x265-params pass=2 \
			-f $container "${LSTVIDEO[i]%.*}".$videoformat.$extcont \
			| ProgressBar "${LSTVIDEO[i]}" "$((i+1))" "${#LSTVIDEO[@]}" "Encoding"
		else
		"$ffmpeg_bin" $FFMPEG_LOG_LVL \
			-analyzeduration 1G -probesize 1G \
			$GPUDECODE \
			-y -i "${LSTVIDEO[i]}" \
			$FFMPEG_PROGRESS \
			-threads 0 \
			$vstream $videoconf $soundconf $subtitleconf -max_muxing_queue_size 4096 \
			-f $container "${LSTVIDEO[i]%.*}".$videoformat.$extcont \
			| ProgressBar "${LSTVIDEO[i]}" "$((i+1))" "${#LSTVIDEO[@]}" "Encoding"
		fi
	else
		if [[ "$PASS2" = "1" ]]; then
		"$ffmpeg_bin" $FFMPEG_LOG_LVL\
			-analyzeduration 1G -probesize 1G \
			$GPUDECODE \
			-y -i "${LSTVIDEO[i]}" \
			$FFMPEG_PROGRESS \
			-threads 0 \
			$vstream $videoconf $soundconf $subtitleconf -max_muxing_queue_size 4096 \
			-x265-params pass=1 -f null /dev/null 2>/dev/null \
			| ProgressBar "${LSTVIDEO[i]} Pass 1" "$((i+1))" "${#LSTVIDEO[@]}" "Encoding"
		"$ffmpeg_bin" $FFMPEG_LOG_LVL \
			-analyzeduration 1G -probesize 1G \
			$GPUDECODE \
			-y -i "${LSTVIDEO[i]}" \
			$FFMPEG_PROGRESS \
			-threads 0 \
			$vstream $videoconf $soundconf $subtitleconf -max_muxing_queue_size 4096 \
			-x265-params pass=2 \
			-f $container "${LSTVIDEO[i]%.*}".$videoformat.$extcont 2>/dev/null \
			| ProgressBar "${LSTVIDEO[i]}" "$((i+1))" "${#LSTVIDEO[@]}" "Encoding"
		else
		"$ffmpeg_bin" $FFMPEG_LOG_LVL \
			-analyzeduration 1G -probesize 1G \
			$GPUDECODE \
			-y -i "${LSTVIDEO[i]}" \
			$FFMPEG_PROGRESS \
			-threads 0 \
			$vstream $videoconf $soundconf $subtitleconf -max_muxing_queue_size 4096 \
			-f $container "${LSTVIDEO[i]%.*}".$videoformat.$extcont 2>/dev/null \
			| ProgressBar "${LSTVIDEO[i]}" "$((i+1))" "${#LSTVIDEO[@]}" "Encoding"
		fi
	fi
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
Video_Custom_Video() {					# Option 1  	- Conf video codec & filters
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
if [[ "$qv" = "q" ]]; then
	Restart

# Video stream edition
elif [[ "$qv" = "e" ]]; then

	# Set video encoding
	ENCODV="1"

	# Codec choice
	Display_Video_Custom_Info_choice
	echo " Choice the video codec to use:"
	echo
	echo "  [x264]       > for libx264 codec"
	echo " *[x265]       > for libx265 codec"
	if [[ -n "$VAAPI_device" ]] && [[ -n "$GPUDECODE" ]]; then
		echo "  [hevc_vaapi] > for hevc_vaapi codec; GPU encoding"
	fi
	echo "  [libaom]     > for AV1 libaom-av1 codec"
	if [[ -n "$ffmpeg_test_libsvtav1_codec" ]]; then
		echo "  [libsvtav1]  > for AV1 libsvtav1 codec"
	fi
	echo "  [mpeg4]      > for xvid codec"
	echo "  [q]          > for exit"
	read -r -e -p "-> " yn
	case $yn in
		"x264")
			codec="libx264"
			chvcodec="H264"
			Video_Custom_Filter_deinterlace
			Video_Custom_Filter_resolution
			Video_Custom_Filter_rotation
			Video_Custom_Filter_hdr
			Video_x264_5_Config
		;;
		"x265")
			codec="libx265"
			chvcodec="HEVC"
			Video_Custom_Filter_deinterlace
			Video_Custom_Filter_resolution
			Video_Custom_Filter_rotation
			Video_Custom_Filter_hdr
			Video_x264_5_Config
		;;
		"hevc_vaapi")
			codec="hevc_vaapi"
			chvcodec="HEVC_VAAPI"
			vfilter+=( "format=nv12|vaapi,hwupload" )
			Video_Custom_Filter_deinterlace
			Video_Custom_Filter_resolution
			Video_hevc_vaapi_Config
		;;
		"libaom")
			codec="libaom-av1"
			chvcodec="AV1"
			Video_Custom_Filter_deinterlace
			Video_Custom_Filter_resolution
			Video_Custom_Filter_rotation
			Video_Custom_Filter_hdr
			Video_av1_Config
		;;
		"libsvtav1")
			codec="libsvtav1"
			chvcodec="AV1"
			Video_Custom_Filter_deinterlace
			Video_Custom_Filter_resolution
			Video_Custom_Filter_rotation
			Video_Custom_Filter_hdr
			Video_av1_Config
		;;
		"mpeg4")
			codec="mpeg4 -vtag xvid"
			chvcodec="XVID"
			Video_Custom_Filter_deinterlace
			Video_Custom_Filter_resolution
			Video_Custom_Filter_rotation
			Video_MPEG4_Config
		;;
		"q"|"Q")
			Restart
		;;
		*)
			codec="libx265"
			chvcodec="HEVC"
			Video_Custom_Filter_deinterlace
			Video_Custom_Filter_resolution
			Video_Custom_Filter_rotation
			Video_Custom_Filter_hdr
			Video_x264_5_Config
		;;
	esac

# Tune VAAPI ffmpeg argument for encoding or decoding
TestVAAPI

# No video change
else
	# Set video configuration variable
	chvidstream="Copy"
	chvcodec="vcopy"
	codec="copy"
fi


# Construc final filter variable
if (( "${#vfilter[@]}" )); then
	vfilter_final="-vf $(IFS=',';echo "${vfilter[*]}";IFS=$' \t\n')"
fi

# Set video configuration variable
vcodec="$codec"
filevcodec="$chvcodec"
videoconf="$vfilter_final -c:v $vcodec $preset $profile $tune $vkb"
}
Video_Custom_Filter_deinterlace() {		# Option 1  	- Conf filter video, deinterlace
Display_Video_Custom_Info_choice
if [[ "$ffprobe_Interlaced" = "1" ]]; then
	echo " Video SEEMS interlaced, you want deinterlace:"
else
	echo " Video not seems interlaced, you want force deinterlace:"
fi
echo " Note: The detection is not 100% reliable, a visual check of the video will guarantee it"
echo
echo "  [y] > for yes "
echo " *[↵] > for no change"
echo "  [q] > for exit"
read -r -e -p "-> " yn
case $yn in
	"y"|"Y")
		chdes="Yes"
		if [[ "$codec" = "hevc_vaapi" ]]; then
			vfilter+=( "deinterlace_vaapi" )
		else
			vfilter+=( "yadif" )
		fi
	;;
	"q"|"Q")
		Restart
	;;
	*)
		chdes="No change"
	;;
esac
}
Video_Custom_Filter_resolution() {		# Option 1  	- Conf filter video, resolution
if [[ "${#LSTVIDEO[@]}" = "1" ]]; then
	# Local variables
	local ch_width
	local RATIO
	local WIDTH
	local HEIGHT

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
			echo "  [9] > 2560px - 1440p, WQXGA+"
			echo " [10] > 3840px - 2160p, UHD-1"
			echo " [11] > 4096px - 4K"
			echo " [12] > 5120px - 4K WHXGA, Ultra wide"
			echo " [13] > 7680px - UHD-2"
			echo " [14] > 8192px - 8K"
			echo "  [c] > for no change"
			echo "  [q] > for exit"
			while :
			do
			read -r -e -p "-> " ch_width
			case $ch_width in
				1) WIDTH="640"; break;;
				2) WIDTH="720"; break;;
				3) WIDTH="768"; break;;
				4) WIDTH="1024"; break;;
				5) WIDTH="1280"; break;;
				6) WIDTH="1680"; break;;
				7) WIDTH="1920"; break;;
				8) WIDTH="2048"; break;;
				9) WIDTH="2560"; break;;
				10) WIDTH="3840"; break;;
				11) WIDTH="4096"; break;;
				12) WIDTH="5120"; break;;
				13) WIDTH="7680"; break;;
				14) WIDTH="8192"; break;;
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

	if [[ -n "$WIDTH" ]]; then

		for i in "${!ffprobe_StreamIndex[@]}"; do
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

		# Scale filter
		if ! [[ "$HEIGHT" =~ ^[0-9]+$ ]]; then			# In not integer
			if [[ "$codec" = "hevc_vaapi" ]]; then
				vfilter+=( "scale_vaapi=w=$WIDTH:h=-2" )
			else
				vfilter+=( "scale=$WIDTH:-2" )
			fi
		else
			if [[ "$codec" = "hevc_vaapi" ]]; then
				vfilter+=( "scale_vaapi=w=$WIDTH:h=-1" )
			else
				vfilter+=( "scale=$WIDTH:-1" )
			fi
		fi

		# Displayed width x height
		chwidth="${WIDTH}x${HEIGHT%.*}"
	fi
else
	chwidth="No change in batch"
fi
}
Video_Custom_Filter_rotation() {		# Option 1  	- Conf filter video, rotation
if [[ "${#LSTVIDEO[@]}" = "1" ]]; then
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
	while :; do
	read -r -e -p "-> " ynrotat
	case $ynrotat in
		[0-4])
			vfilter+=( "transpose=$ynrotat" )

			if [[ "$ynrotat" = "0" ]]; then
				chrotation="90° CounterCLockwise and Vertical Flip"
			elif [[ "$ynrotat" = "1" ]]; then
				chrotation="90° Clockwise"
			elif [[ "$ynrotat" = "2" ]]; then
				chrotation="90° CounterClockwise"
			elif [[ "$ynrotat" = "3" ]]; then
				chrotation="90° Clockwise and Vertical Flip"
			elif [[ "$ynrotat" = "4" ]]; then
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
else
	chrotation="No change in batch"
fi
}
Video_Custom_Filter_hdr() {				# Option 1  	- Conf filter video, HDR
if [[ "${#LSTVIDEO[@]}" = "1" ]]; then
	if [[ -n "$ffprobe_hdr" ]]; then
		Display_Video_Custom_Info_choice
		echo " Apply HDR to SDR filter:"
		echo " Note: * This option is necessary to keep an acceptable colorimetry,"
		echo "         if the source video is in HDR and you don't want to keep it."
		echo "       * For prevent fail, remove attached pic."
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
				chsdr2hdr="Yes"
				vfilter+=( "zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:r=tv,format=yuv420p" )
				;;
		esac
	fi
else
	chsdr2hdr="No change in batch"
fi
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
if [[ "$qa" = "q" ]]; then
	Restart
elif [[ "$qa" = "e" ]]; then

	# Set audio encoding
	ENCODA="1"

	# Codec choice
	Video_Custom_Audio_Codec

# Remove audio stream
elif [[ "$qa" = "r" ]]; then
	chsoundstream="Remove"
	fileacodec="aremove"
	soundconf="-an"

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
		AudioCodecType="libopus"
		acodec="libopus"
		chacodec="OPUS"
		Audio_Opus_Config
		Audio_Channels_Config
	;;
	"vorbis")
		AudioCodecType="libvorbis"
		acodec="libvorbis"
		chacodec="OGG"
		Audio_OGG_Config
		Audio_Channels_Config
	;;
	"ac3")
		AudioCodecType="ac3"
		acodec="ac3"
		chacodec="AC3"
		Audio_AC3_Config
		Audio_Channels_Config
	;;
	"flac")
		AudioCodecType="flac"
		acodec="flac"
		chacodec="FLAC"
		Audio_FLAC_Config
		Audio_Channels_Config
	;;
	"q"|"Q")
		Restart
	;;
	*)
		AudioCodecType="libopus"
		acodec="libopus"
		chacodec="OPUS"
		Audio_Opus_Config
		Audio_Channels_Config
	;;
esac
fileacodec="$chacodec"
soundconf="$afilter -c:a $acodec $akb $asamplerate $confchan"
}
Video_Custom_Stream() {					# Option 1,2	- Conf stream selection
# Local variables
local rpstreamch
local rpstreamch_parsed
local streams_invalid

# Array
unset VINDEX
unset VCODECTYPE
unset stream

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
	if [[ -z "$rpstreamch" ]]; then							# If -map 0
		# Construct arrays
		VINDEX=( "${ffprobe_StreamIndex[@]}" )
		VCODECTYPE=("${ffprobe_StreamType[@]}")
		#stream+=("-map 0")
		break

	elif [[ "$rpstreamch_parsed" == "q" ]]; then			# Quit
		Restart

	elif ! [[ "$rpstreamch_parsed" =~ ^-?[0-9]+$ ]]; then	# Not integer retry
		Echo_Mess_Error "Map option must be an integer"

	elif [[ "$rpstreamch_parsed" =~ ^-?[0-9]+$ ]]; then		# If valid integer continue
		# Reset streams_invalid
		unset streams_invalid

		# Construct arrays
		unset VINDEX
		unset VCODECTYPE
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
			stream+=("-map 0:${VINDEX[i]}")
			;;

		# Audio Stream
		audio)
			if [[ "$chsoundstream" != "Remove" ]]; then
				stream+=("-map 0:${VINDEX[i]}")
			fi
			;;

		# Subtitle Stream
		subtitle)
			stream+=("-map 0:${VINDEX[i]}")
			if [[ -z "$subtitleconf" ]]; then
				if [[ "$extcont" = "mkv" ]]; then
					subtitleconf="-c:s copy"
				elif [[ "$extcont" = "mp4" ]]; then
					subtitleconf="-c:s mov_text"
				fi
			fi
			;;
	esac
done
vstream="${stream[*]}"

# Set file name if $videoformat variable empty
if [[ -z "$videoformat" ]]; then
	videoformat="$filevcodec.$fileacodec"
fi

# Reset display (last question before encoding)
if [[ "$ffmes_option" -le "3" ]]; then
	Display_Video_Custom_Info_choice
fi
}
Video_Custom_Container() {				# Option 1  	- Conf container mkv/mp4
# Local variables
local chcontainer

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
if [[ "${#ffprobe_StreamIndex[@]}" -lt "3" ]]; then
	Display_Video_Custom_Info_choice
fi
}
Video_MPEG4_Config() {					# Option 1  	- Conf Xvid 
# Local variables
local rpvkb
local rpvkb_unit

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
# Get unit
rpvkb_unit="${rpvkb: -1}"
if [[ "$rpvkb_unit" = "k" ]] || [[ "$rpvkb_unit" = "K" ]]; then
	# Remove all after k/K from variable for prevent syntax error
	video_stream_kb="${rpvkb%k*}"
	video_stream_kb="${video_stream_kb%K*}"
	vkb="-b:v $video_stream_kb"
elif [[ "$rpvkb" = "1" ]]; then
	vkb="-q:v 1"
elif [[ "$rpvkb" = "2" ]]; then
	vkb="-q:v 5"
elif [[ "$rpvkb" = "3" ]]; then
	vkb="-q:v 10"
elif [[ "$rpvkb" = "4" ]]; then
	vkb="-q:v 15"
elif [[ "$rpvkb" = "5" ]]; then
	vkb="-q:v 20"
elif [[ "$rpvkb" = "6" ]]; then
	vkb="-q:v 25"
elif [[ "$rpvkb" = "7" ]]; then
	vkb="-q:v 30"
elif [[ "$rpvkb" = "q" ]]; then
	Restart
else
	vkb="-q:v 10"
fi
}
Video_x264_5_Config() {					# Option 1  	- Conf x264/x265
# Local variables
local pass
local rpvkb
local rpvkb_unit
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
if [[ -n "$reppreset" ]]; then
	preset="-preset $reppreset"
	chpreset="; preset $reppreset"
elif [[ "$reppreset" = "q" ]]; then
	Restart
else
	preset="-preset medium"
	chpreset="; preset slow"
fi

# Tune x264/x265
Display_Video_Custom_Info_choice
if [[ "$chvcodec" = "H264" ]]; then
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
	if [[ "$reptune" = "film" ]]; then
		tune="-tune $reptune"
	elif [[ "$reptune" = "animation" ]]; then
		tune="-tune $reptune"
	elif [[ "$reptune" = "grain" ]]; then
		tune="-tune $reptune"
	elif [[ "$reptune" = "stillimage" ]]; then
		tune="-tune $reptune"
	elif [[ "$reptune" = "fastdecode" ]]; then
		tune="-tune $reptune"
	elif [[ "$reptune" = "zerolatency" ]]; then
		tune="-tune $reptune"
	elif [[ "$reptune" = "cfilm" ]]; then
		tune="-fast-pskip 0 -bf 10 -b_strategy 2 -me_method umh -me_range 24 -trellis 2 -refs 4 -subq 9"
	elif [[ "$reptune" = "canimation" ]]; then
		tune="-fast-pskip 0 -bf 10 -b_strategy 2 -me_method umh -me_range 24 -trellis 2 -refs 4 -subq 9 -deblock -2:-2 -psy-rd 1.0:0.25 -aq 0.5 -qcomp 0.8"
	elif [[ "$reptune" = "no" ]]; then
		unset tune
	elif [[ "$reptune" = "q" ]]; then
		Restart
	else
		tune="-fast-pskip 0 -bf 10 -b_strategy 2 -me_method umh -me_range 24 -trellis 2 -refs 4 -subq 9"
	fi
	# Menu display tune
	chtune="; tune $reptune"
elif [[ "$chvcodec" = "HEVC" ]]; then
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
	if [[ "$reptune" = "psnr" ]]; then
		tune="-tune $reptune"
	elif [[ "$reptune" = "ssim" ]]; then
		tune="-tune $reptune"
	elif [[ "$reptune" = "grain" ]]; then
		tune="-tune $reptune"
	elif [[ "$reptune" = "fastdecode" ]]; then
		tune="-tune $reptune"
	elif [[ "$reptune" = "zerolatency" ]]; then
		tune="-tune $reptune"
	elif [[ "$reptune" = "q" ]]; then
		Restart
	else
		chtune="; tune default"
	fi
	# Menu display tune
	if [[ -n "$tune" ]]; then
		chtune="; tune $reptune"
	else
		chtune="; tune default"
	fi
fi

# Profile x264/x265
Display_Video_Custom_Info_choice
if [[ "$chvcodec" = "H264" ]]; then
	echo " Choose the profile:"
	echo " Note: The choice of the profile affects the compatibility of the result,"
	echo "       be careful not to apply any more parameters to the source file (no positive effect)"
	echo
	echo "                                        | max  | max definition/fps by level   |"
	echo "        | lvl | profile  | bit | chroma | Mb/s | res.     >fps                 |"
	echo "        |-----|----------|-----|--------|------|-------------------------------|"
	echo "  [1] > | 3.0 | Baseline | 8   | 4:2:0  | 10   | 720×576  >25                  |"
	echo "  [2] > | 3.1 | main     | 8   | 4:2:0  | 14   | 720×576  >66                  |"
	echo "  [3] > | 4.0 | Main     | 8   | 4:2:0  | 20   | 2048×1024>30                  |"
	echo "  [4] > | 4.0 | High     | 8   | 4:2:0  | 25   | 2048×1024>30                  |"
	echo " *[5] > | 4.1 | High     | 8   | 4:2:0  | 63   | 2048×1024>30                  |"
	echo "  [6] > | 4.1 | high10   | 10  | 4:2:0  | 150  | 2048×1088>60                  |"
	echo "  [7] > | 5.1 | High     | 8   | 4:2:0  | 300  | 2560×1920>30                  |"
	echo "  [8] > | 5.1 | High     | 10  | 4:2:0  | 720  | 4096×2048>30                  |"
	echo "  [9] > | 6.2 | high10   | 10  | 4:2:0  | 2400 | 8192×4320>120                 |"
	echo "  [q] > for exit"
	read -r -e -p "-> " repprofile
	if [[ "$repprofile" = "1" ]]; then
		profile="-profile:v baseline -level 3.0 -pix_fmt yuv420p"
		chprofile="; profile baseline 3.0 - 8 bit - 4:2:0"
	elif [[ "$repprofile" = "2" ]]; then
		profile="-profile:v main -level 3.1 -pix_fmt yuv420p"
		chprofile="; profile main 3.1 - 8 bit - 4:2:0"
	elif [[ "$repprofile" = "3" ]]; then
		profile="-profile:v main -level 4.0 -pix_fmt yuv420p"
		chprofile="; profile main 4.0 - 8 bit - 4:2:0"
	elif [[ "$repprofile" = "4" ]]; then
		profile="-profile:v high -level 4.0 -pix_fmt yuv420p"
		chprofile="; profile high 4.0 - 8 bit - 4:2:0"
	elif [[ "$repprofile" = "5" ]]; then
		profile="-profile:v high -level 4.1 -pix_fmt yuv420p"
		chprofile="; profile high 4.1 - 8 bit - 4:2:0"
	elif [[ "$repprofile" = "6" ]]; then
		profile="-profile:v high10 -level 4.2 -pix_fmt yuv420p10le"
		chprofile="; profile high10 4.2 - 10 bit - 4:2:0"
	elif [[ "$repprofile" = "7" ]]; then
		profile="-profile:v high -level 5.1 -pix_fmt yuv420p"
		chprofile="; profile high 5.1 - 8 bit - 4:2:0"
	elif [[ "$repprofile" = "8" ]]; then
		profile="-profile:v high10 -level 5.1 -pix_fmt yuv420p10le"
		chprofile="; profile high10 5.1 - 10 bit - 4:2:0"
	elif [[ "$repprofile" = "9" ]]; then
		profile="-profile:v high10 -level 6.2 -pix_fmt yuv420p10le"
		chprofile="; profile high10 6.2 - 10 bit - 4:2:0"
	elif [[ "$repprofile" = "q" ]]; then
		Restart
	else
		profile="-profile:v high -level 4.1"
		chprofile="; profile High 4.1"
	fi
elif [[ "$chvcodec" = "HEVC" ]]; then
	echo " Choose a profile or make your profile manually:"
	echo " Notes: * For bit and chroma settings, if the source is below the parameters,"
	echo "          FFmpeg will not replace them but will be at the same level."
	echo "        * The level (lvl) parameter must be chosen judiciously according to"
	echo "          the bit rate of the source file and the result you expect."
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
	echo "                                      | max  | max definition/fps by level |"
	echo "         | lvl | high  | bit | chroma | Mb/s | res.     >fps               |"
	echo "         |-----|-------|-----|--------|------|-----------------------------|"
	echo "   [1] > | 3.1 | 0     | 8   | 4:2:0  | 10   | 1280×720 >30                |"
	echo "   [2] > | 4.1 | 0     | 8   | 4:2:0  | 20   | 2048×1080>60                |"
	echo "  *[3] > | 4.1 | 1     | 8   | 4:2:0  | 50   | 2048×1080>60                |"
	echo "   [4] > | 4.1 | 1     | 10  | 4:2:0  | 50   | 2048×1080>60                |"
	echo "   [5] > | 5.1 | 1     | 8   | 4:2:0  | 160  | 4096×2160>60                |"
	echo "   [6] > | 5.1 | 1     | 10  | 4:2:0  | 160  | 4096×2160>60                |"
	echo "   [7] > | 6.1 | 1     | 10  | 4:2:0  | 480  | 8192×4320>60                |"
	echo "   [q] > for exit"
	read -r -e -p "-> " repprofile
	if echo "$repprofile" | grep -q 'profile'; then
		profile="$repprofile"
		chprofile="; profile $repprofile"
	elif [[ "$repprofile" = "1" ]]; then
		profile="-profile:v main -x265-params ${X265_LOG_LVL}level=3.1 -pix_fmt yuv420p"
		chprofile="; profile main 3.1 - 8 bit - 4:2:0"
	elif [[ "$repprofile" = "2" ]]; then
		profile="-profile:v main -x265-params ${X265_LOG_LVL}level=4.1 -pix_fmt yuv420p"
		chprofile="; profile main 4.1 - 8 bit - 4:2:0"
	elif [[ "$repprofile" = "3" ]]; then
		profile="-profile:v main -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1 -pix_fmt yuv420p"
		chprofile="; profile high 4.1 - 8 bit - 4:2:0"
	elif [[ "$repprofile" = "4" ]]; then
		profile="-profile:v main10 -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1 -pix_fmt yuv420p10le"
		chprofile="; profile high 4.1 - 10 bit - 4:2:0"
	elif [[ "$repprofile" = "5" ]]; then
		profile="-profile:v main -x265-params ${X265_LOG_LVL}level=5.1:high-tier=1 -pix_fmt yuv420p"
		chprofile="; profile high 5.1 - 8 bit - 4:2:0"
	elif [[ "$repprofile" = "6" ]]; then
		profile="-profile:v main10 -x265-params ${X265_LOG_LVL}level=5.1:high-tier=1 -pix_fmt yuv420p10le"
		chprofile="; profile high 5.1 - 10 bit - 4:2:0"
	elif [[ "$repprofile" = "7" ]]; then
		profile="-profile:v main10 -x265-params ${X265_LOG_LVL}level=6.2:high-tier=1 -pix_fmt yuv420p10le"
		chprofile="; profile high 6.1 - 10 bit - 4:2:0"
	elif [[ "$repprofile" = "q" ]]; then
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
echo "       * libx265: which can offer 25–50% bitrate savings compared to libx264."
echo "       * libx265: one input & cbr (or total size choise) allow 2 pass encoding."
echo
echo " [1200k]     Example of input for cbr desired bitrate in kb/s"
echo " [1500m]     Example of input for aproximative total size of video stream in Mb (not recommended in batch)"
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
# Get unit
rpvkb_unit="${rpvkb: -1}"
if [[ "$rpvkb_unit" = "k" ]] || [[ "$rpvkb_unit" = "K" ]]; then
	# Remove all after k/K from variable for prevent syntax error
	video_stream_kb="${rpvkb%k*}"
	video_stream_kb="${video_stream_kb%K*}"
	# Set cbr variable
	vkb="-b:v ${video_stream_kb}k"
elif [[ "$rpvkb_unit" = "m" ]] || [[ "$rpvkb_unit" = "M" ]]; then
	# Remove all after m/M from variable
	video_stream_size="${rpvkb%m*}"
	video_stream_size="${video_stream_size%M*}"
	# Bitrate calculation
	video_stream_kb=$(bc <<< "scale=0; ($video_stream_size * 8192)/$ffprobe_Duration")
	# Set cbr variable
	vkb="-b:v ${video_stream_kb}k"
elif echo "$rpvkb" | grep -q 'crf'; then
	vkb="$rpvkb"
elif [[ "$rpvkb" = "1" ]]; then
	vkb="-crf 0"
elif [[ "$rpvkb" = "2" ]]; then
	vkb="-crf 5"
elif [[ "$rpvkb" = "3" ]]; then
	vkb="-crf 10"
elif [[ "$rpvkb" = "4" ]]; then
	vkb="-crf 15"
elif [[ "$rpvkb" = "5" ]]; then
	vkb="-crf 20"
elif [[ "$rpvkb" = "6" ]]; then
	vkb="-crf 22"
elif [[ "$rpvkb" = "7" ]]; then
	vkb="-crf 25"
elif [[ "$rpvkb" = "8" ]]; then
	vkb="-crf 30"
elif [[ "$rpvkb" = "9" ]]; then
	vkb="-crf 35"
elif [[ "$rpvkb" = "q" ]]; then
	Restart
else
	vkb="-crf 20"
fi

# Pass question if CBR & HEVC & one file
rpvkb_unit="${vkb: -1}"
if [[ "$rpvkb_unit" = "k" ]] \
&& [[ "$chvcodec" = "HEVC" ]] \
&& [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
	read -r -p " 1 or 2 pass encoding? [*1/2]: " pass
	case $pass in
		"2")
			PASS2="1"
			chpass="; 2 pass"
		;;
		*)
			unset PASS2
			chpass="; 1 pass"
		;;
	esac
else
	unset PASS2
	chpass="; 1 pass"
fi
}
Video_hevc_vaapi_Config() {				# Option 1  	- Conf hevc_vaapi
# Local variables
local rpvkb
local rpvkb_unit
local video_stream_kb
local video_stream_size

# Bitrate
Display_Video_Custom_Info_choice
echo " Choose a QP number, video strem size, or enter the desired bitrate:"
echo " Note: * HEVC which can offer 25–50% bitrate savings compared to libx264."
echo "       * At same bitrate, the quality of hevc_vaapi if inferior at the libx265 codec,"
echo "         but the encoding speed is much faster."
echo "       * 10 bits encoding not supported."
echo
echo " [1200k]    Example of input for cbr desired bitrate in kb/s"
echo " [1500m]    Example of input for aproximative total size of video stream in Mb (not recommended in batch)"
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
# Get unit
rpvkb_unit="${rpvkb: -1}"
if [[ "$rpvkb_unit" = "k" ]] || [[ "$rpvkb_unit" = "K" ]]; then
	# Remove all after k/K from variable for prevent syntax error
	video_stream_kb="${rpvkb%k*}"
	video_stream_kb="${video_stream_kb%K*}"
	# Set cbr variable
	vkb="-rc_mode 2 -b:v ${video_stream_kb}k"
elif [[ "$rpvkb_unit" = "m" ]] || [[ "$rpvkb_unit" = "M" ]]; then
	# Remove all after m/M from variable
	video_stream_size="${rpvkb%m*}"
	video_stream_size="${video_stream_size%M*}"
	# Bitrate calculation
	video_stream_kb=$(bc <<< "scale=0; ($video_stream_size * 8192)/$ffprobe_Duration")
	# Set cbr variable
	vkb="-rc_mode 2 -b:v ${video_stream_kb}k"
elif echo "$rpvkb" | grep -q 'qp'; then
	vkb="-rc_mode 2 $rpvkb"
elif [[ "$rpvkb" = "1" ]]; then
	vkb="-rc_mode 1 -qp 0"
elif [[ "$rpvkb" = "2" ]]; then
	vkb="-rc_mode 1 -qp 5"
elif [[ "$rpvkb" = "3" ]]; then
	vkb="-rc_mode 1 -qp 10"
elif [[ "$rpvkb" = "4" ]]; then
	vkb="-rc_mode 1 -qp 15"
elif [[ "$rpvkb" = "5" ]]; then
	vkb="-rc_mode 1 -qp 20"
elif [[ "$rpvkb" = "6" ]]; then
	vkb="-rc_mode 1 -qp 22"
elif [[ "$rpvkb" = "7" ]]; then
	vkb="-rc_mode 1 -qp 25"
elif [[ "$rpvkb" = "8" ]]; then
	vkb="-rc_mode 1 -qp 30"
elif [[ "$rpvkb" = "9" ]]; then
	vkb="-rc_mode 1 -qp 35"
elif [[ "$rpvkb" = "q" ]]; then
	Restart
else
	vkb="-rc_mode 1 -qp 25"
fi
}
Video_av1_Config() {					# Option 1  	- Conf av1
# Local variables
local rpvkb
local rpvkb_unit
local video_stream_kb
local video_stream_size

# Config
if [[ "$codec" = "libaom-av1" ]]; then
	Display_Video_Custom_Info_choice
	echo " Choose libaom cpu-used efficient compression value (preset):"
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
	if [[ -n "$reppreset" ]]; then
		preset="-cpu-used $reppreset -row-mt 1 -tiles 4x1"
		chpreset="; cpu-used: $reppreset"
	elif [[ "$reppreset" = "q" ]]; then
		Restart
	else
		preset="-cpu-used 2 -row-mt 1 -tiles 4x1"
		chpreset="; cpu-used: 2"
	fi
elif [[ "$codec" = "libsvtav1" ]]; then
	Display_Video_Custom_Info_choice
	echo " Choose libsvtav1 preset:"
	echo
	echo "  [0]  > for preset 0    ∧ |"
	echo "  [1]  > for preset 1    | |"
	echo "  [2]  > for preset 2    | |"
	echo "  [3]  > for preset 3   Q| |"
	echo "  [4]  > for preset 4   U| |S"
	echo "  [5]  > for preset 5   A| |P"
	echo " *[6]  > for preset 6   L| |E"
	echo "  [7]  > for preset 7   I| |E"
	echo "  [8]  > for preset 8   T| |D"
	echo "  [9]  > for preset 9   Y| |"
	echo "  [10] > for preset 10   | |"
	echo "  [11] > for preset 11   | |"
	echo "  [12] > for preset 12   | ∨"
	echo "  [q] > for exit"
	read -r -e -p "-> " reppreset
	if [[ -n "$reppreset" ]]; then
		preset="-preset $reppreset"
		chpreset="; preset: $reppreset"
	elif [[ "$reppreset" = "q" ]]; then
		Restart
	else
		preset="-preset 6"
		chpreset="; preset: 6"
	fi
fi

# Bitrate AV1
Display_Video_Custom_Info_choice
echo " Choose a CRF number, video strem size, or enter the desired bitrate:"
echo " Note: * This settings influences size and quality, crf is a better choise in 90% of cases."
echo "       * AV1 can save about 30% bitrate compared to VP9 and H.265 / HEVC,"
echo "         and about 50% over H.264, while retaining the same visual quality. "
echo
echo " [1200k]     Example of input for cbr desired bitrate in kb/s"
echo " [1500m]     Example of input for aproximative total size of video stream in Mb (not recommended in batch)"
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
# Get unit
rpvkb_unit="${rpvkb: -1}"
if [[ "$rpvkb_unit" = "k" ]] || [[ "$rpvkb_unit" = "K" ]]; then
	# Remove all after k/K from variable for prevent syntax error
	video_stream_kb="${rpvkb%k*}"
	video_stream_kb="${rpvkb%K*}"
	# Set cbr variable
	vkb="-b:v ${video_stream_kb}k"
elif [[ "$rpvkb_unit" = "m" ]] || [[ "$rpvkb_unit" = "M" ]]; then
	# Remove all after m/M from variable
	video_stream_size="${rpvkb%m*}"
	video_stream_size="${rpvkb%M*}"
	# Bitrate calculation
	video_stream_kb=$(bc <<< "scale=0; ($video_stream_size * 8192)/$ffprobe_Duration")
	# Set cbr variable
	vkb="-b:v ${video_stream_kb}k"
elif echo "$rpvkb" | grep -q 'crf'; then
	vkb="$rpvkb -b:v 0"
elif [[ "$rpvkb" = "1" ]]; then
	vkb="-crf 0 -b:v 0"
elif [[ "$rpvkb" = "2" ]]; then
	vkb="-crf 10 -b:v 0"
elif [[ "$rpvkb" = "3" ]]; then
	vkb="-crf 20 -b:v 0"
elif [[ "$rpvkb" = "4" ]]; then
	vkb="-crf 30 -b:v 0"
elif [[ "$rpvkb" = "5" ]]; then
	vkb="-crf 40 -b:v 0"
elif [[ "$rpvkb" = "6" ]]; then
	vkb="-crf 50 -b:v 0"
elif [[ "$rpvkb" = "7" ]]; then
	vkb="-crf 60 -b:v 0"
elif [[ "$rpvkb" = "q" ]]; then
	Restart
else
	vkb="-crf 30 -b:v 0"
fi
}
Video_Add_OPUS_NightNorm() {			# Option 3		- Add audio stream with night normalization in opus/stereo/320kb
# Local variables
local subtitleconf
# Array
unset INDEX
unset VINDEX

Display_Media_Stats_One "${LSTVIDEO[@]}"

echo " Select one audio stream:"
echo " Note: * The selected audio will be encoded in a new stream in opus/stereo/320kb."
echo "       * Night normalization reduce amplitude between heavy and weak sounds."
echo
echo "  [0 3 1] > example for select stream"
echo "  [q]     > for exit"
while true; do
	read -r -e -p "-> " rpstreamch
	if [[ "$rpstreamch" == "q" ]]; then
		Restart

	elif ! [[ "$rpstreamch" =~ ^-?[0-9]+$ ]]; then
		Echo_Mess_Error "Map option must be an integer"

	elif [[ "$rpstreamch" =~ ^-?[0-9]+$ ]]; then
		# Construct index array
		IFS=" " read -r -a INDEX <<< "$rpstreamch"

		# Test if selected stream is audio
		for i in "${INDEX[@]}"; do
			if [[ "${ffprobe_StreamType[i]}" != "audio" ]]; then
				Echo_Mess_Error "The stream $i is not audio stream"
			else
				# Get audio map
				for j in ${!ffprobe_StreamType[*]}; do
					if [[ "${ffprobe_StreamIndex[j]}" = "${INDEX[*]}" ]]; then
						VINDEX+=( "${ffprobe_a_StreamIndex[j]}" )
					fi
				done
				break 2
			fi
		done

	fi
done

# Start time counter
START=$(date +%s)

# Encoding
for files in "${LSTVIDEO[@]}"; do

	for i in ${!VINDEX[*]}; do

		# For progress bar
		FFMES_FFMPEG_PROGRESS="$FFMES_CACHE/ffmpeg-progress-$(date +%Y%m%s%N).info"
		FFMPEG_PROGRESS="-stats_period 0.3 -progress $FFMES_FFMPEG_PROGRESS"
	
		# Encoding new track
		"$ffmpeg_bin"  $FFMPEG_LOG_LVL -y -i "$files" \
			$FFMPEG_PROGRESS \
			-map 0:v -c:v copy -map 0:s? -c:s copy -map 0:a -map 0:a:${VINDEX[i]}? \
			-c:a copy -metadata:s:a:${VINDEX[i]} title="Opus 2.0 Night Mode" -c:a:${VINDEX[i]} libopus \
			-b:a:${VINDEX[i]} 320K -ac 2 \
			-filter:a:${VINDEX[i]} acompressor=threshold=0.031623:attack=200:release=1000:detection=0,loudnorm \
			"${files%.*}".OPUS-NightNorm.mkv \
			| ProgressBar "$files" "" "" "Encoding"

		# Check Target if valid
		Test_Target_File "0" "video" "${files%.*}.OPUS-NightNorm.mkv"

	done

done

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"
total_source_files_size=$(Calc_Files_Size "${LSTVIDEO[@]}")
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" "$total_source_files_size"
}
Video_Custom_One_Audio() {				# Option 4		- One audio stream encoding
# Local variables
local astream
local subtitleconf
# Array
unset VINDEX
unset stream

Display_Media_Stats_One "${LSTVIDEO[@]}"

echo " Select one audio stream to encode:"
echo
echo "  [0 3 1] > example for select stream"
echo "  [q]     > for exit"
while true; do
	read -r -e -p "-> " rpstreamch
	if [[ "$rpstreamch" == "q" ]]; then
		Restart

	elif ! [[ "$rpstreamch" =~ ^-?[0-9]+$ ]]; then
		Echo_Mess_Error "Map option must be an integer"

	elif [[ "$rpstreamch" =~ ^-?[0-9]+$ ]]; then
		# Construct index array
		IFS=" " read -r -a VINDEX <<< "$rpstreamch"

		# Test if selected stream is audio
		for i in "${VINDEX[@]}"; do
			if [[ "${ffprobe_StreamType[i]}" != "audio" ]]; then
				Echo_Mess_Error "The stream $i is not audio stream"
			else

				# Codec option choise
				chvidstream="N/A"
				extcont="mkv"
				vstream="N/A"
				ENCODA="1"
				Video_Custom_Audio_Codec
				Display_Video_Custom_Info_choice

				# Get audio map
				for j in ${!ffprobe_StreamType[*]}; do
					if [[ "${ffprobe_StreamIndex[j]}" != "${VINDEX[*]}" ]] \
					&& [[ "${ffprobe_StreamType[j]}" = "audio" ]]; then
						stream+=("-map 0:a:${ffprobe_a_StreamIndex[j]} -c:a:${ffprobe_a_StreamIndex[j]} copy")
					elif [[ "${ffprobe_StreamIndex[j]}" = "${VINDEX[*]}" ]] \
					&& [[ "${ffprobe_StreamType[j]}" = "audio" ]]; then
						if [[ -n "$afilter" ]]; then
							afilter="-filter:a:${ffprobe_a_StreamIndex[j]} aformat=channel_layouts='7.1|6.1|5.1|stereo' -mapping_family 1"
						fi
						stream+=("$afilter -map 0:a:${ffprobe_a_StreamIndex[j]} -c:a:${ffprobe_a_StreamIndex[j]} $acodec $akb $asamplerate $confchan")
					fi
				done
				astream="${stream[*]}"
				break 2

			fi
		done

	fi
done

# Start time counter
START=$(date +%s)

# Encoding
for files in "${LSTVIDEO[@]}"; do

	for i in ${!VINDEX[*]}; do

		# For progress bar
		FFMES_FFMPEG_PROGRESS="$FFMES_CACHE/ffmpeg-progress-$(date +%Y%m%s%N).info"
		FFMPEG_PROGRESS="-stats_period 0.3 -progress $FFMES_FFMPEG_PROGRESS"

		# Encoding
		"$ffmpeg_bin"  $FFMPEG_LOG_LVL -y -i "$files" \
			$FFMPEG_PROGRESS \
			-map_metadata 0 -map 0:v -c:v copy \
			$astream \
			-map 0:s -c:s copy \
			"${files%.*}".$fileacodec.mkv \
			| ProgressBar "$files" "" "" "Encoding"

		# Check Target if valid
		Test_Target_File "0" "video" "${files%.*}.$fileacodec.mkv"

	done

done

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"
total_source_files_size=$(Calc_Files_Size "${LSTVIDEO[@]}")
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" "$total_source_files_size"
}
Video_Merge_Files() {					# Option 10 	- Add audio stream or subtitle in video file
# Local variables
local MERGE_LSTAUDIO
local MERGE_LSTSUB

# Keep extention with wildcard for current audio and sub
mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex \
						'.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null \
						| sort | sed 's/^..//')
if (( "${#LSTAUDIO[@]}" )); then
	MERGE_LSTAUDIO=$(printf '*.%s ' "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
fi
if (( "${#LSTSUB[@]}" )); then
	MERGE_LSTSUB=$(printf '*.%s ' "${LSTSUB[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
fi

# Summary message
Display_Media_Stats_One "${LSTVIDEO[@]}"
echo "  You will merge the following files:"
echo "   ${LSTVIDEO[0]##*/}"
if (( "${#LSTAUDIO[@]}" )); then
	printf '   %s\n' "${LSTAUDIO[@]}"
fi
if (( "${#LSTSUB[@]}" )); then
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
if (( "${#LSTSUB[@]}" )); then
	for files in "${LSTSUB[@]}"; do
		if [[ "${files##*.}" != "idx" ]] && [[ "${files##*.}" != "sup" ]]; then
			CHARSET_DETECT=$(uchardet "$files" 2>/dev/null)
			if [[ "$CHARSET_DETECT" != "UTF-8" ]]; then
				iconv -c -f "$CHARSET_DETECT" -t UTF-8 "$files" > utf-8-"$files"
				mkdir SUB_BACKUP 2>/dev/null
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
Video_Concatenate() {					# Option 11 	- Concatenate video
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
if [[ "$concatrep" = "q" ]]; then
		Restart
else
	# Start time counter
	START=$(date +%s)

	echo
	Echo_Separator_Light

	# Add date id to created filename, prevent infinite loop of ffmpeg is target=source filename
	filename_id="Concatenate_Output-$(date +%s).${LSTVIDEO[0]##*.}"
	
	# Concatenate
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -f concat -safe 0 \
		-i <(for f in *."${LSTVIDEO[0]##*.}"; do echo "file '$PWD/$f'"; done) \
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
Video_Extract_Stream() {				# Option 12 	- Extract stream
# Local variables
local rpstreamch_parsed
local streams_invalid
local MKVEXTRACT
local PCM_EXTRACT
local MOV_TEXT_EXTRACT
local FILE_EXT

# Array
unset VINDEX
unset VCODECNAME
unset filesInLoop

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
	if [[ -z "$rpstreamch" ]]; then							# If -map 0
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
		unset VINDEX
		unset VCODECNAME
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
				PCM_EXTRACT="1"
				FILE_EXT=wav
				;;
			pcm_bluray)
				PCM_EXTRACT="1"
				FILE_EXT=wav
				;;

			subrip)
				FILE_EXT=srt ;;
			ass) FILE_EXT=ass ;;
			mov_text)
				MOV_TEXT_EXTRACT="1"
				FILE_EXT=srt ;;
			hdmv_pgs_subtitle) FILE_EXT=sup ;;
			dvd_subtitle)
				MKVEXTRACT="1"
				FILE_EXT=idx
				;;
			esac

			# For progress bar
			FFMES_FFMPEG_PROGRESS="$FFMES_CACHE/ffmpeg-progress-$(date +%Y%m%s%N).info"
			FFMPEG_PROGRESS="-stats_period 0.3 -progress $FFMES_FFMPEG_PROGRESS"

			# Extract
			if [[ "$MKVEXTRACT" = "1" ]]; then
				mkvextract "$files" tracks "${VINDEX[i]}":"${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT"

			elif [[ "$MPEG2EXTRACT" = "1" ]]; then
				"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -fflags +genpts -analyzeduration 1G -probesize 1G -i "$files" \
					$FFMPEG_PROGRESS \
					-c copy -map 0:"${VINDEX[i]}" "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" \
					| ProgressBar "${files%.*}-Stream-${VINDEX[i]}.$FILE_EXT" "" "" "Extract"

			elif [[ "$PCM_EXTRACT" = "1" ]]; then
				"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "$files" \
					$FFMPEG_PROGRESS \
					-map 0:"${VINDEX[i]}" -c:a pcm_s24le \
					"${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" \
					| ProgressBar "${files%.*}-Stream-${VINDEX[i]}.$FILE_EXT" "" "" "Extract"

			elif [[ "$MOV_TEXT_EXTRACT" = "1" ]]; then
				"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "$files" \
					$FFMPEG_PROGRESS \
					-c:s srt -map 0:"${VINDEX[i]}" "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" \
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
Video_Cut_File() {						# Option 13 	- Cut video
# Local variables
local qcut0
local qcut
local CutStart
local CutEnd
local split_output
local CutSegment
# Array
unset filesInLoop

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

# For progress bar
FFMES_FFMPEG_PROGRESS="$FFMES_CACHE/ffmpeg-progress-$(date +%Y%m%s%N).info"
FFMPEG_PROGRESS="-stats_period 0.3 -progress $FFMES_FFMPEG_PROGRESS"

# Segment
if [[ -n "$CutSegment" ]]; then
	# Create file path & directory for segmented files
	split_output_files="${LSTVIDEO[0]##*/}"
	split_output="splitted_raw_${split_output_files%.*}"
	if ! [[ -d "$split_output" ]]; then
		mkdir "$split_output"
	fi

	# Segment
	"$ffmpeg_bin" $FFMPEG_LOG_LVL \
		-analyzeduration 1G -probesize 1G \
		-y -i "${LSTVIDEO[0]}" \
		$FFMPEG_PROGRESS \
		-f segment -segment_time "$CutSegment" \
		-c copy -map 0 -map_metadata 0 -reset_timestamps 1 \
		"$split_output"/"${split_output_files%.*}"_segment_%04d."${LSTVIDEO[0]##*.}" \
		| ProgressBar "${LSTVIDEO[0]}" "" "" "Segment"

	# map array of target files
	mapfile -t filesInLoop < <(find "$split_output" -maxdepth 1 -type f -regextype posix-egrep \
		-iregex '.*\.('${LSTVIDEO[0]##*.}')$' 2>/dev/null | sort)

# Cut
else
	"$ffmpeg_bin" $FFMPEG_LOG_LVL \
		-analyzeduration 1G -probesize 1G \
		-y -i "${LSTVIDEO[0]}" \
		$FFMPEG_PROGRESS \
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
Video_Split_By_Chapter() {				# Option 14 	- Split by chapter
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
# Local variables
local NEW_VIDEO_EXT_AVAILABLE

if [[ "$NBVEXT" -gt "1" ]]; then
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
	if [[ "$NEW_VIDEO_EXT_AVAILABLE" = "q" ]]; then
		Restart
	elif [[ -n "$NEW_VIDEO_EXT_AVAILABLE" ]]; then
		mapfile -t LSTVIDEO < <(find "$PWD" -maxdepth 1 -type f -regextype posix-egrep \
			-regex '.*\.('$NEW_VIDEO_EXT_AVAILABLE')$' 2>/dev/null | sort)
	fi
fi
}

## AUDIO
Audio_FFmpeg_cmd() {					# FFmpeg audio encoding loop
# Local variables
local filesToTest_realpath
local PERC
local file_source_files_size
local file_target_files_size
local total_source_files_size
local total_target_files_size
local START
local END
# Array
unset filesInLoop
unset filesOverwrite
unset filesToTest
unset filesPass
unset filesSourcePass
unset filesReject
unset filesPassSizeReduction
## Encoding array
unset FilesTargetAfilter
unset FilesTargetAconfchan
unset FilesTargetAkb
unset FilesTargetAsamplerate
unset FilesTargetAbitdeph
unset FilesTargetAstream

# Start time counter
START=$(date +%s)

# Copy $extcont for test and reset inside loop
ExtContSource="$extcont"

# Disable the enter key
EnterKeyDisable

# Prepare encoding command
## Start Loading
StartLoading "Preparation of the encoding"
## Prepare arrays & variable
for i in "${!LSTAUDIO[@]}"; do
	# Audio filter array include: test volume & normalization
	Audio_ffmpeg_cmd_Filter "${LSTAUDIO[i]}"
	# Audio channel array include: channel test mono or stereo
	Audio_ffmpeg_cmd_Channel "${LSTAUDIO[i]}"
	# Audio bitrate array include: OPUS & AAC auto adapted bitrate
	Audio_ffmpeg_cmd_Bitrate "${LSTAUDIO[i]}"
	# Audio sampling rate array include: FLAC & WavPack limitation
	Audio_ffmpeg_cmd_Sample_Rate "${LSTAUDIO[i]}"
	# Audio bit depth array include: FLAC & WavPack bit depht source detection (if not set)
	Audio_ffmpeg_cmd_Bit_Depth "${LSTAUDIO[i]}"
	# Audio stream array include: map audio & cover 
	Audio_ffmpeg_cmd_Stream
	# If source extention same as target
	## Reset $extcont
	extcont="$ExtContSource"
	if [[ "${LSTAUDIO[i]##*.}" = "$extcont" ]]; then
		extcont="new.$extcont"
		filesOverwrite+=( "${LSTAUDIO[i]}" )
	else
		filesOverwrite+=( "$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')" )
	fi
done
## Stop loading
StopLoading $?
Display_Remove_Previous_Line

# Encoding
echo
Echo_Separator_Light
for i in "${!LSTAUDIO[@]}"; do
	# Cover extraction
	Audio_Cover_Extraction "${LSTAUDIO[i]}"

	# Stock files pass in loop
	filesInLoop+=( "${LSTAUDIO[i]}" )

	# Progress bar
	if [[ "${#LSTAUDIO[@]}" = "1" ]] || [[ "$NPROC" = "1" ]]; then
		# No relaunch Media_Source_Info_Record for first array item
		if [[ "$i" != "0" ]]; then
			Media_Source_Info_Record "${LSTAUDIO[i]}"
		fi
		FFMES_FFMPEG_PROGRESS="$FFMES_CACHE/ffmpeg-progress-$(date +%Y%m%s%N).info"
		FFMPEG_PROGRESS="-stats_period 0.3 -progress $FFMES_FFMPEG_PROGRESS"
	fi

	(
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "${LSTAUDIO[i]}" \
		$FFMPEG_PROGRESS \
		${FilesTargetAfilter[i]} \
		${FilesTargetAstream[i]} \
		$acodec \
		${FilesTargetAkb[i]} \
		${FilesTargetAbitdeph[i]} \
		${FilesTargetAsamplerate[i]} \
		${FilesTargetAconfchan[i]} \
		"${LSTAUDIO[i]%.*}".$extcont \
		| ProgressBar "${LSTAUDIO[i]}" "${#filesInLoop[@]}" "${#LSTAUDIO[@]}" "Encoding"
	) &
	if [[ $(FFmpeg_instance_count) -ge $NPROC ]]; then
		wait -n
	fi
done
wait

# Test results
# Reset $extcont
extcont="$ExtContSource"
# File to test array
for i in "${!filesInLoop[@]}"; do
	if [[ "${filesInLoop[i]%.*}" = "${filesOverwrite[i]%.*}" ]]; then
		filesToTest+=( "${filesInLoop[i]%.*}.new.${extcont}" )
	else
		filesToTest+=( "${filesInLoop[i]%.*}.$extcont" )
	fi
done
# Tests & error log generation
for i in "${!filesToTest[@]}"; do
	(
	"$ffmpeg_bin" -v error -i "${filesToTest[i]}" \
		-max_muxing_queue_size 9999 -f null - 2>"${FFMES_CACHE}/${filesToTest[i]##*/}.$i.error.log"
	) &
	if [[ $(FFmpeg_instance_count) -ge $NPROC ]]; then
		wait -n
	fi
	ProgressBar "$files" "$((i+1))" "${#filesToTest[@]}" "Validation" "1"
done
wait

# Check error files
for i in "${!filesInLoop[@]}"; do
	# File reject
	if [[ -s "${FFMES_CACHE}/${filesToTest[i]##*/}.$i.error.log" ]]; then
		filesToTest_realpath=$(realpath "${filesToTest[i]}")
		mv "${FFMES_CACHE}/${filesToTest[i]##*/}.$i.error.log" \
			"${filesToTest_realpath%/*}/${filesToTest[i]##*/}.error.log" 2>/dev/null
		rm "${filesToTest[i]}" 2>/dev/null
		filesReject+=( "${filesToTest[i]}" )
	# File pass
	else
		rm "${FFMES_CACHE}/${filesToTest[i]##*/}.$i.error.log" 2>/dev/null
		if [[ "${filesToTest[i]}" = "${filesInLoop[i]%.*}.new.${extcont}" ]]; then
			mv "${filesInLoop[i]}" "${filesInLoop[i]%.*}.back.${extcont}" 2>/dev/null
			mv "${filesInLoop[i]%.*}.new.${extcont}" "${filesInLoop[i]}" 2>/dev/null
			filesSourcePass+=( "${filesInLoop[i]%.*}.back.${extcont}" )
		else
			filesSourcePass+=( "${filesInLoop[i]}" )
		fi
		filesPass+=( "${filesInLoop[i]%.*}"."$extcont" )

		# Make statistics of indidual processed files
		file_source_files_size=$(Calc_Files_Size_bytes "${filesSourcePass[-1]}")
		file_target_files_size=$(Calc_Files_Size_bytes "${filesPass[-1]}")
		PERC=$(Calc_Percent "$file_source_files_size" "$file_target_files_size")
		filesPassSizeReduction+=( "$PERC" )
	fi
done

# Enable the enter key
EnterKeyEnable

# End time counter
END=$(date +%s)

# Make statistics of all processed files
Calc_Elapsed_Time "$START" "$END"
total_source_files_size=$(Calc_Files_Size "${filesSourcePass[@]}")
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "${#LSTAUDIO[@]}" "$total_target_files_size" "$total_source_files_size"
}
Audio_ffmpeg_cmd_Filter() {				# FFmpeg audio cmd - filter 
if [[ "$PeakNorm" = "1" ]]; then

	# Local variables
	local TestDB
	local TestDB_diff
	local DB
	local afilter_db
	# Argument = file
	files="$1"

	TestDB=$("$ffmpeg_bin" -i "$files" \
			-af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 \
			| grep "max_volume" | awk '{print $5;}')
	TestDB_diff=$(echo "${TestDB/-/} > $PeakNormDB" | bc -l 2>/dev/null)

	# Apply if db detected < default peak db variable
	if [[ "${TestDB:0:1}" == "-" ]] && [[ "$TestDB_diff" = "1" ]]; then

		# Difference of db to be applied
		DB="$(echo "${TestDB/-/}" | awk -v var="$PeakNormDB" '{print $1-var}')dB"
		afilter_db="-af volume=$DB"

		# Array
		FilesTargetAfilter+=( "$afilter_db" )

	# No apply if db detected > default peak db variable
	else

		# Array
		FilesTargetAfilter+=( "$afilter" )

	fi

else

	# Array
	FilesTargetAfilter+=( "$afilter" )

fi
}
Audio_ffmpeg_cmd_Channel() {			# FFmpeg audio cmd - channel
if [[ "$TestFalseStereo" = "1" ]]; then

	# Local variables
	local TESTLEFT
	local TESTRIGHT
	local confchan_mono
	# Argument = file
	files="$1"

	# Test
	TESTLEFT=$("$ffmpeg_bin" -i "$files" -map_channel 0.0.0 -f md5 - 2>/dev/null)
	TESTRIGHT=$("$ffmpeg_bin" -i "$files" -map_channel 0.0.1 -f md5 - 2>/dev/null)
	# Array
	if [[ "$TESTLEFT" = "$TESTRIGHT" ]]; then
		confchan_mono="-channel_layout mono"
		FilesTargetAconfchan+=( "$confchan_mono" )
	else
		FilesTargetAconfchan+=( "$confchan" )
	fi

else

	# Array
	if [[ -n "$confchan" ]]; then
		FilesTargetAconfchan+=( "$confchan" )
	fi

fi
}
Audio_ffmpeg_cmd_Bitrate() {			# FFmpeg audio cmd - bitrate
if [[ "$AdaptedBitrate" = "1" ]]; then
	# Local variable
	local TestBitrate
	local TestChannel
	local akb_modified
	local asamplerate_modified
	# Argument = file
	files="$1"

	# Test bitrate
	if (( "${#mediainfo_bin}" )); then
		TestBitrate=$("$mediainfo_bin" --Language=raw \
						--Inform="Audio;%BitRate%" "$files")
	else
		TestBitrate=$("$ffprobe_bin" -hide_banner -v quiet \
						-select_streams a -show_entries stream=bit_rate \
						-of default=noprint_wrappers=1:nokey=1 "$files")
		if [[ "$TestBitrate" = "N/A" ]] || [[ -z "$TestBitrate" ]]; then
			TestBitrate=$("$ffmpeg_bin" -i "$files" 2>&1 \
							| grep -Po "bitrate: \K.*" \
							| cut -f1 -d" ")
		fi
	fi

	# If opus mono & source > 320k - apply hard codec limitation
	if [[ "$acodec" = "libopus" || "$AudioCodecType" = "libopus" ]]; then
		if [[ "$confchan" = "-channel_layout mono" ]]; then
			if [[ "$TestBitrate" -ge 320000 ]]; then
				akb_modified="-b:a 96K"
			fi
		else
			if (( "${#mediainfo_bin}" )); then
				TestChannel=$("$mediainfo_bin" --Language=raw \
								--Inform="Audio;%Channel(s)%" "$files")
			else
				TestChannel=$("$ffprobe_bin" -hide_banner -v quiet \
								-select_streams a -show_entries stream=channels \
								-of default=noprint_wrappers=1:nokey=1 "$files")
			fi
			if [[ "$TestChannel" = "1" ]]; then
				akb_modified="-b:a 96K"
			fi
		fi
	fi

	# If not integer = file not valid
	if [[ -z "$akb_modified" ]]; then
		if ! [[ "$TestBitrate" =~ ^[0-9]+$ ]]; then
			unset akb
		elif [[ "$TestBitrate" -ge 1 ]] && [[ "$TestBitrate" -le 97000 ]]; then
			akb_modified="-b:a 64K"
			asamplerate_modified="-cutoff 15000"
		elif [[ "$TestBitrate" -ge 97001 ]] && [[ "$TestBitrate" -le 129000 ]]; then
			akb_modified="-b:a 96K"
			asamplerate_modified="-cutoff 16000"
		elif [[ "$TestBitrate" -ge 129001 ]] && [[ "$TestBitrate" -le 161000 ]]; then
			akb_modified="-b:a 128K"
			asamplerate_modified="-cutoff 16000"
		elif [[ "$TestBitrate" -ge 161001 ]] && [[ "$TestBitrate" -le 193000 ]]; then
			akb_modified="-b:a 160K"
			asamplerate_modified="-cutoff 17000"
		elif [[ "$TestBitrate" -ge 193001 ]]; then
			akb_modified="-b:a 192K"
			asamplerate_modified="-cutoff 18000"
		else
			akb_modified="-b:a 192K"
			asamplerate_modified="-cutoff 20000"
		fi
	fi

	# Array
	FilesTargetAkb+=( "$akb_modified" )
	FilesTargetAsamplerate+=( "$asamplerate_modified" )

else

	# Array
	if [[ -n "$akb" ]]; then
		FilesTargetAkb+=( "$akb" )
	fi

fi
}
Audio_ffmpeg_cmd_Sample_Rate() {		# FFmpeg audio cmd - sample rate
# lossless case
if [[ "$extcont" = "flac" ]] \
|| [[ "$extcont" = "wav" ]] \
|| [[ "$extcont" = "wv" ]]; then

	# Local variable
	local TestSamplingRateSet
	local TestSamplingRate
	local asamplerate_modified
	# Argument = file
	files="$1"

	# Sampling rate test
	TestSamplingRateSet=$(echo "$asamplerate" | awk -F " " '{print $NF}')
	if (( "${#mediainfo_bin}" )); then
		TestSamplingRate=$("$mediainfo_bin" --Language=raw \
							--Inform="Audio;%SamplingRate%" "$files")
	else
		TestSamplingRate=$("$ffprobe_bin" -hide_banner -v quiet \
							-select_streams a -show_entries stream=sample_rate \
							-print_format csv=p=0 "$files")
	fi

	# If sampling rate not set + flac/wv : limit to 384kHz
	if [[ -z "$asamplerate" ]] && [[ "$TestSamplingRate" -gt "384000" ]]; then
		if [[ "$extcont" = "flac" ]] || [[ "$extcont" = "wv" ]]; then

			# If libsoxr resampler
			if [[ -n "$ffmpeg_test_libsoxr_filter" ]]; then
				if [[ -z "${FilesTargetAfilter[-1]}" ]]; then
					FilesTargetAfilter[-1]="-af aresample=resampler=soxr"
				else
					FilesTargetAfilter[-1]="${FilesTargetAfilter[-1]},aresample=resampler=soxr:precision=33:cutoff=0.995"
				fi
			fi
			asamplerate_modified="-ar 384000"

		else 
			asamplerate_modified=""
		fi

	# Set sampling rate if !=
	elif [[ -n "$asamplerate" ]] && [[ "$TestSamplingRateSet" != "$TestSamplingRate" ]]; then

		# If libsoxr resampler
		if [[ -n "$ffmpeg_test_libsoxr_filter" ]]; then
			if [[ -z "${FilesTargetAfilter[-1]}" ]]; then
				FilesTargetAfilter[-1]="-af aresample=resampler=soxr"
			else
				FilesTargetAfilter[-1]="${FilesTargetAfilter[-1]},aresample=resampler=soxr:precision=33:cutoff=0.995"
			fi
		fi
		asamplerate_modified="-ar $TestSamplingRateSet"

	# No set sampling rate
	else
		asamplerate_modified=""
	fi

	# Array
	FilesTargetAsamplerate+=( "$asamplerate_modified" )

# lossy case
else

	# Array
	FilesTargetAsamplerate+=( "$asamplerate" )

fi
}
Audio_ffmpeg_cmd_Bit_Depth() {			# FFmpeg audio cmd - bit depth
if [[ "$AudioCodecType" = "flac" ]] || [[ "$AudioCodecType" = "wavpack" ]]; then
	if ! [[ "$akb" == *"sample_fmt"* ]]; then
		# Local variable
		local TestBitDepth
		local abitdeph_modified

		# Argument = file
		files="$1"

		TestBitDepth=$("$ffprobe_bin" -hide_banner -v quiet \
						-select_streams a -show_entries stream=sample_fmt \
						-of default=noprint_wrappers=1:nokey=1 "$files")
		if [[ "$TestBitDepth" == "u8"* ]]; then			# 8 bits
			if [[ "$AudioCodecType" = "flac" ]]; then
				abitdeph_modified="-sample_fmt s16"
			elif [[ "$AudioCodecType" = "wavpack" ]]; then
				abitdeph_modified="-sample_fmt u8p"
			fi
		elif [[ "$TestBitDepth" == "s16"* ]]; then		# 16 bits
			if [[ "$AudioCodecType" = "flac" ]]; then
				abitdeph_modified="-sample_fmt s16"
			elif [[ "$AudioCodecType" = "wavpack" ]]; then
				abitdeph_modified="-sample_fmt s16p"
			fi
		elif [[ "$TestBitDepth" == "s32"* ]] || [[ "$TestBitDepth" = "fltp" ]]; then	# 32 bits
			if [[ "$AudioCodecType" = "flac" ]]; then
				abitdeph_modified="-sample_fmt s32"
			elif [[ "$AudioCodecType" = "wavpack" ]]; then
				abitdeph_modified="-sample_fmt s32p"
			fi
		elif [[ "$TestBitDepth" == "s64"* ]] || [[ "$TestBitDepth" = "dblp" ]]; then	# 64 bits
			if [[ "$AudioCodecType" = "flac" ]]; then
				abitdeph_modified="-sample_fmt s32"
			elif [[ "$AudioCodecType" = "wavpack" ]]; then
				abitdeph_modified="-sample_fmt s32p"
			fi
		fi

		# Array
		FilesTargetAbitdeph+=( "$abitdeph_modified" )
	fi
else
	# Array
	if [[ -n "$abitdeph" ]]; then
		FilesTargetAbitdeph+=( "$abitdeph" )
	fi
fi
}
Audio_ffmpeg_cmd_Stream() {				# FFmpeg audio cmd - stream selection
if [[ "$ExtractCover" = "1" ]] && [[ "$extcont" != "opus" ]]; then
	astream="-map 0 -c:v copy"
else
	astream="-map 0:a"
fi
# Array
FilesTargetAstream+=( "$astream" )
}
Audio_Cover_Extraction() {				# FFmpeg audio cmd - cover extraction
# Argument = file
files="$1"

if [[ "$ExtractCover" = "0" ]]; then
	if [[ ! -e "${files%/*}"/cover.jpg ]] && [[ ! -e cover.jpg ]]; then
		"$ffmpeg_bin" -n -i "$files" "${files%.*}".jpg 2>/dev/null
		mv "${files%.*}".jpg "${files%/*}"/cover.jpg 2>/dev/null
		mv "${files%.*}".jpg cover.jpg 2>/dev/null
	fi
fi
}
Audio_Channels_Config() {				#
if [[ "$ffmes_option" -lt "20" ]]; then          # if profile 0 or 1 display
	Display_Video_Custom_Info_choice
fi
if [[ "$acodec" = "libopus" || "$AudioCodecType" = "libopus" ]]; then
	echo " Choose desired audio channels configuration:"
	echo
	echo "  [1] > for channel_layout 1.0 (Mono)"
	echo "  [2] > for channel_layout 2.0 (Stereo)"
	echo "  [3] > for channel_layout 3.0 (FL+FR+FC)"
	echo "  [4] > for channel_layout 5.1 (FL+FR+FC+LFE+BL+BR)"
	echo " *[↵] > for no change"
	echo "  [q] > for exit"
	read -r -e -p "-> " rpchan
	if [[ "$rpchan" = "q" ]]; then
		Restart
	elif [[ "$rpchan" = "1" ]]; then
		confchan="-channel_layout mono"
		rpchannel="1.0 (Mono)"
	elif [[ "$rpchan" = "2" ]]; then
		confchan="-channel_layout stereo"
		rpchannel="2.0 (Stereo)"
	elif [[ "$rpchan" = "3" ]]; then
		confchan="-channel_layout 3.0"
		rpchannel="3.0 (FL+FR+FC)"
	elif [[ "$rpchan" = "4" ]]; then
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
	if [[ "$rpchan" = "q" ]]; then
		Restart
	elif [[ "$rpchan" = "1" ]]; then
		confchan="-channel_layout mono"
		rpchannel="1.0 (Mono)"
	elif [[ "$rpchan" = "2" ]]; then
		confchan="-channel_layout stereo"
		rpchannel="2.0 (Stereo)"
	elif [[ "$rpchan" = "3" ]]; then
		confchan="-channel_layout 2.1"
		rpchannel="2.1 (FL+FR+LFE)"
	elif [[ "$rpchan" = "4" ]]; then
		confchan="-channel_layout 3.0"
		rpchannel="3.0 (FL+FR+FC)"
	elif [[ "$rpchan" = "5" ]]; then
		confchan="-channel_layout 3.1"
		rpchannel="3.1 (FL+FR+FC+LFE)"
	elif [[ "$rpchan" = "6" ]]; then
		confchan="-channel_layout 4.0"
		rpchannel="4.0 (FL+FR+FC+BC)"
	elif [[ "$rpchan" = "7" ]]; then
		confchan="-channel_layout 4.1"
		rpchannel="4.1 (FL+FR+FC+LFE+BC)"
	elif [[ "$rpchan" = "8" ]]; then
		confchan="-channel_layout 5.0"
		rpchannel="5.0 (FL+FR+FC+BL+BR)"
	elif [[ "$rpchan" = "9" ]]; then
		confchan="-channel_layout 5.1"
		rpchannel="5.1 (FL+FR+FC+LFE+BL+BR)"
	else
		rpchannel="No change"
	fi
fi
}
Audio_PCM_Config() {					# Option 21 	- Audio to wav (PCM)
# Local variables
local rpakb

if [[ "$ffmes_option" -lt "20" ]]; then		# If in video encoding
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
if [[ "$rpakb" = "q" ]]; then
	Restart
elif [[ "$rpakb" = "1" ]]; then
	acodec="-c:a u8"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "2" ]]; then
	acodec="-c:a s8"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "3" ]]; then
	acodec="-c:a pcm_s16le"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "4" ]]; then
	acodec="-c:a pcm_s24le"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "5" ]]; then
	acodec="-c:a pcm_s32le"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "6" ]]; then
	acodec="-c:a u8"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "7" ]]; then
	acodec="-c:a s8"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "8" ]]; then
	acodec="-c:a pcm_s16le"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "9" ]]; then
	acodec="-c:a pcm_s24le"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "10" ]]; then
	acodec="-c:a pcm_s32le"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "11" ]]; then
	acodec="-c:a u8"
elif [[ "$rpakb" = "12" ]]; then
	acodec="-c:a s8"
elif [[ "$rpakb" = "13" ]]; then
	acodec="-c:a pcm_s16le"
elif [[ "$rpakb" = "14" ]]; then
	acodec="-c:a pcm_s24le"
elif [[ "$rpakb" = "15" ]]; then
	acodec="-c:a pcm_s32le"
else
	acodec="-c:a pcm_s16le"
fi
}
Audio_FLAC_Config() {					# Option 1,22 	- Conf audio/video flac, audio to flac
# Local variables
local rpakb

if [[ "$ffmes_option" -lt "20" ]]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi

echo " Choose FLAC (${AudioCodecType}) desired configuration:"
echo " Notes: * ffmpeg FLAC uses a compression level: 0 (fastest) & 12 (slowest)."
echo "        * If you choose and audio bit depth superior of source file, the encoding will fail."
echo "        * Option tagued [auto] = same value of source file."
echo "        * Max value of sample rate is 384kHz."
echo
echo " Choose a number:"
echo
echo "         | comp. | sample |   bit |"
echo "         | level |   rate | depth |"
echo "         |-------|--------|-------|"
echo "  [1]  > |   12  |  44kHz |    16 |"
echo "  [2]  > |    0  |  44kHz |       |"
echo "  [3]  > |   12  |  48kHz |       |"
echo "  [4]  > |    0  |  48kHz |       |"
echo "         |-------|--------|-------|"
echo "  [5]  > |   12  |  44kHz |    24 |"
echo "  [6]  > |    0  |  44kHz |       |"
echo "  [7]  > |   12  |  48kHz |       |"
echo "  [8]  > |    0  |  48kHz |       |"
echo "         |-------|--------|-------|"
echo " *[9]  > |   12  |   auto |  auto |"
echo "  [10] > |    0  |   auto |  auto |"
echo "         |------------------------|"
echo "  [q]  > | for exit"
read -r -e -p "-> " rpakb
if [[ "$rpakb" = "q" ]]; then
	Restart
elif echo "$rpakb" | grep -q 'c' ; then
	akb="$rpakb"
elif [[ "$rpakb" = "1" ]]; then
	akb="-compression_level 12 -sample_fmt s16"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "2" ]]; then
	akb="-compression_level 0 -sample_fmt s16"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "3" ]]; then
	akb="-compression_level 12 -sample_fmt s16"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "4" ]]; then
	akb="-compression_level 0 -sample_fmt s16"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "5" ]]; then
	akb="-compression_level 12 -sample_fmt s32"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "6" ]]; then
	akb="-compression_level 0 -sample_fmt s32"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "7" ]]; then
	akb="-compression_level 12 -sample_fmt s32"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "8" ]]; then
	akb="-compression_level 0 -sample_fmt s32"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "9" ]]; then
	akb="-compression_level 12"
elif [[ "$rpakb" = "10" ]]; then
	akb="-compression_level 0"
else
	akb="-compression_level 12"
fi
}
Audio_WavPack_Config() {				# Option 23 	- audio to wavpack
# Local variables
local rpakb

if [[ "$ffmes_option" -lt "20" ]]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi

echo " Choose WavPack (${AudioCodecType}) desired configuration:"
echo " Notes: * ffmes WavPack uses a compression level: 0 (fastest) & 3 (slowest)."
echo "        * Option tagued [auto] = same value of source file."
echo "        * Max value of sample rate is 384kHz."
echo
echo " Choose a number:"
echo
echo "         | comp. | sample |   bit |"
echo "         | level |   rate | depth |"
echo "         |-------|--------|-------|"
echo "  [1]  > |    3  |  44kHz |    16 |"
echo "  [2]  > |    0  |  44kHz |       |"
echo "  [3]  > |    3  |  48kHz |       |"
echo "  [4]  > |    0  |  48kHz |       |"
echo "         |-------|--------|-------|"
echo "  [5]  > |    3  |  44kHz |    24 |"
echo "  [6]  > |    0  |  44kHz |       |"
echo "  [7]  > |    3  |  48kHz |       |"
echo "  [8]  > |    0  |  48kHz |       |"
echo "         |-------|--------|-------|"
echo " *[9]  > |    3  |   auto |  auto |"
echo "  [10] > |    0  |   auto |  auto |"
echo "         |------------------------|"
echo "  [q]  > | for exit"
read -r -e -p "-> " rpakb
if [[ "$rpakb" = "q" ]]; then
	Restart
elif echo "$rpakb" | grep -q 'c' ; then
	akb="$rpakb"
elif [[ "$rpakb" = "1" ]]; then
	akb="-compression_level 3 -sample_fmt s16p"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "2" ]]; then
	akb="-compression_level 0 -sample_fmt s16p"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "3" ]]; then
	akb="-compression_level 3 -sample_fmt s16p"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "4" ]]; then
	akb="-compression_level 0 -sample_fmt s16p"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "5" ]]; then
	akb="-compression_level 3 -sample_fmt s32p"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "6" ]]; then
	akb="-compression_level 0 -sample_fmt s32p"
	asamplerate="-ar 44100"
elif [[ "$rpakb" = "7" ]]; then
	akb="-compression_level 3 -sample_fmt s32p"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "8" ]]; then
	akb="-compression_level 0 -sample_fmt s32p"
	asamplerate="-ar 48000"
elif [[ "$rpakb" = "9" ]]; then
	akb="-compression_level 3"
elif [[ "$rpakb" = "10" ]]; then
	akb="-compression_level 0"
else
	akb="-compression_level 3"
fi
}
Audio_Opus_Config() {					# Option 1,26 	- Conf audio/video opus, audio to opus (libopus)
# Local variables
local rpakb

if [[ "$ffmes_option" -lt "20" ]]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi

echo
echo "        | kb/s | Descriptions            |"
echo "        |------|-------------------------|"
echo "  [1] > |  64k | audiobooks / podcasts   |"
echo "  [2] > |  96k | music streaming / radio |"
echo "  [3] > | 128k | music storage           |"
echo "  [4] > | 160k | music storage           |"
if [[ "$AudioCodecType" = "libopus" ]] && [[ "$ENCODA" != "1" ]]; then
	echo "  [5] > | 192k | music (transparent)     |"
else
	echo " *[5] > | 192k | music (transparent)     |"
fi
echo "  [6] > | 256k | 5.1 audio source        |"
echo "  [7] > | 450k | 7.1 audio source        |"
echo "  [8] > | 510k | highest bitrate of opus |"
if [[ "$AudioCodecType" = "libopus" ]] && [[ "$ENCODA" != "1" ]]; then
	echo "  -----------------------------------------"
	echo " *[X] > |    adaptive bitrate     |"
	echo "         |-------------------------|"
	echo "         | Target |     Source     |"
	echo "         |--------|----------------|"
	echo "         |   64k  |   1kb ->  96kb |"
	echo "         |   96k  |  97kb -> 128kb |"
	echo "         |  128k  | 129kb -> 160kb |"
	echo "         |  160k  | 161kb -> 192kb |"
	echo "         |  192k  | 193kb -> ∞     |"
fi
echo "  [q]  > | for exit"
read -r -e -p "-> " rpakb
if [[ "$rpakb" = "q" ]]; then
	Restart
elif [[ "$rpakb" = "1" ]]; then
	akb="-b:a 64K"
elif [[ "$rpakb" = "2" ]]; then
	akb="-b:a 96K"
elif [[ "$rpakb" = "3" ]]; then
	akb="-b:a 128K"
elif [[ "$rpakb" = "4" ]]; then
	akb="-b:a 160K"
elif [[ "$rpakb" = "5" ]]; then
	akb="-b:a 192K"
elif [[ "$rpakb" = "6" ]]; then
	akb="-b:a 256K"
elif [[ "$rpakb" = "7" ]]; then
	akb="-b:a 450K"
elif [[ "$rpakb" = "8" ]]; then
	akb="-b:a 510K"
elif [[ "$rpakb" = "X" ]] \
  && [[ "$acodec" = "libopus" || "$AudioCodecType" = "libopus" ]]; then
	AdaptedBitrate="1"
else
	if [[ "$AudioCodecType" = "libopus" ]] && [[ "$ENCODA" != "1" ]]; then
		AdaptedBitrate="1"
	else
		akb="-b:a 192K"
	fi
fi
}
Audio_OGG_Config() {					# Option 1,25 	- Conf audio/video libvorbis, audio to ogg (libvorbis)
# Local variables
local rpakb

if [[ "$ffmes_option" -lt "20" ]]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi

echo " Choose Ogg (${AudioCodecType}) desired configuration:"
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
if [[ "$rpakb" = "q" ]]; then
	Restart
elif echo "$rpakb" | grep -q 'k' ; then
	akb="-b:a $rpakb"
elif [[ "$rpakb" = "1" ]]; then
	akb="-q 2"
	asamplerate="-cutoff 14000 -ar 44100"
elif [[ "$rpakb" = "2" ]]; then
	akb="-q 3"
	asamplerate="-cutoff 15000 -ar 44100"
elif [[ "$rpakb" = "3" ]]; then
	akb="-q 4"
	asamplerate="-cutoff 15000 -ar 44100"
elif [[ "$rpakb" = "4" ]]; then
	akb="-q 5"
	asamplerate="-cutoff 16000 -ar 44100"
elif [[ "$rpakb" = "5" ]]; then
	akb="-q 6"
	asamplerate="-cutoff 17000 -ar 44100"
elif [[ "$rpakb" = "6" ]]; then
	akb="-q 7"
	asamplerate="-cutoff 18000 -ar 44100"
elif [[ "$rpakb" = "7" ]]; then
	akb="-q 8 "
	asamplerate="-cutoff 19000 -ar 44100"
elif [[ "$rpakb" = "8" ]]; then
	akb="-q 9"
	asamplerate="-cutoff 20000 -ar 44100"
elif [[ "$rpakb" = "9" ]]; then
	akb="-q 10"
	asamplerate="-cutoff 22050 -ar 44100"
elif [[ "$rpakb" = "10" ]]; then
	akb="-q 10"
else
	akb="-q 10"
	asamplerate="-cutoff 22050 -ar 44100"
fi
}
Audio_MP3_Config() {					# Option 24 	- Audio to mp3 (libmp3lame)
# Local variables
local rpakb

if [[ "$ffmes_option" -lt "20" ]]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi

echo " Choose MP3 (${AudioCodecType}) desired configuration:"
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
if [[ "$rpakb" = "q" ]]; then
	Restart
elif echo "$rpakb" | grep -q 'k' ; then
	akb="-b:a $rpakb"
elif [[ "$rpakb" = "1" ]]; then
	akb="-q:a 4"
elif [[ "$rpakb" = "2" ]]; then
	akb="-q:a 3"
elif [[ "$rpakb" = "3" ]]; then
	akb="-q:a 2"
elif [[ "$rpakb" = "4" ]]; then
	akb="-q:a 1"
elif [[ "$rpakb" = "5" ]]; then
	akb="-q:a 0"
elif [[ "$rpakb" = "6" ]]; then
	akb="-b:a 320k"
else
	akb="-b:a 320k"
fi
}
Audio_AAC_Config() {					# Option 27 	- Conf audio aac or libfdk_aac, audio to m4a (aac)
# Local variables
local rpakb

if [[ "$ffmes_option" -lt "20" ]]; then
	Display_Video_Custom_Info_choice
else
	Display_Media_Stats_One "${LSTAUDIO[@]}"
	Audio_Source_Info_Detail_Question
fi

# Question
echo " Choose AAC (${AudioCodecType}) desired configuration:"
echo " Notes: * The cutoff allows to lose bitrate on high frequencies,"
echo "          to gain bitrate on audible frequencies."
echo
echo "                 |  cut  |"
echo "          | kb/s |  off  | Descriptions      |"
echo "          |------|-------|-------------------|"
echo "   [1]  > |  64k | 14kHz | 2.0 ~ mp3 96k     |"
echo "   [2]  > |  96k | 15kHz | 2.0 ~ mp3 120k    |"
echo "   [3]  > | 128k | 16kHz | 2.0 ~ mp3 160k    |"
echo "   [4]  > | 160k | 17kHz | 2.0 ~ mp3 192k    |"
echo "   [5]  > | 192k | 18kHz | 2.0 ~ mp3 280k    |"
echo "   [6]  > | 220k | 19kHz | 2.0 ~ mp3 320k    |"
echo "   [7]  > | 320k | 20kHz | 2.0 > mp3         |"
echo "   [8]  > | 384k | 20kHz | 5.1 audio source  |"
echo "   [9]  > | 512k | 20kHz | 7.1 audio source  |"
echo "   -------------------------------------------"
echo "  [10]  > | vbr1 | 15kHz | 20-32k  / channel |"
echo "  [11]  > | vbr2 | 15kHz | 32-40k  / channel |"
echo "  [12]  > | vbr3 | 17kHz | 48-56k  / channel |"
echo "  [13]  > | vbr4 | 18kHz | 64-72k  / channel |"
echo " *[14]  > | vbr5 | 20kHz | 96-112k / channel |"
echo "   [q]  > | for exit"
read -r -e -p "-> " rpakb
if [[ "$rpakb" = "q" ]]; then
	Restart
elif [[ "$rpakb" = "1" ]]; then
	akb="-b:a 64K"
	asamplerate="-cutoff 14000"
elif [[ "$rpakb" = "2" ]]; then
	akb="-b:a 96K"
	asamplerate="-cutoff 15000"
elif [[ "$rpakb" = "3" ]]; then
	akb="-b:a 128K"
	asamplerate="-cutoff 16000"
elif [[ "$rpakb" = "4" ]]; then
	akb="-b:a 160K"
	asamplerate="-cutoff 17000"
elif [[ "$rpakb" = "5" ]]; then
	akb="-b:a 192K"
	asamplerate="-cutoff 18000"
elif [[ "$rpakb" = "6" ]]; then
	akb="-b:a 220K"
	asamplerate="-cutoff 19000"
elif [[ "$rpakb" = "7" ]]; then
	akb="-b:a 320K"
	asamplerate="-cutoff 20000"
elif [[ "$rpakb" = "8" ]]; then
	akb="-b:a 384K"
	asamplerate="-cutoff 20000"
elif [[ "$rpakb" = "9" ]]; then
	akb="-b:a 512K"
	asamplerate="-cutoff 20000"
elif [[ "$rpakb" = "10" ]]; then
	akb="-vbr 1"
	asamplerate="-cutoff 15000"
elif [[ "$rpakb" = "11" ]]; then
	akb="-vbr 2"
	asamplerate="-cutoff 15000"
elif [[ "$rpakb" = "12" ]]; then
	akb="-vbr 3"
	asamplerate="-cutoff 17000"
elif [[ "$rpakb" = "13" ]]; then
	akb="-vbr 4"
	asamplerate="-cutoff 18000"
elif [[ "$rpakb" = "14" ]]; then
	akb="-vbr 5"
	asamplerate="-cutoff 20000"
else
	akb="-vbr 5"
	asamplerate="-cutoff 20000"
fi
}
Audio_AC3_Config() {					# Option 1 		- Conf audio/video AC3
# Local variables
local rpakb

Display_Video_Custom_Info_choice
echo " Choose AC3 (${AudioCodecType}) desired configuration:"
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
if [[ "$rpakb" = "q" ]]; then
	Restart
elif echo "$rpakb" | grep -q 'k' ; then
	akb="-b:a $rpakb"
elif [[ "$rpakb" = "1" ]]; then
	akb="-b:a 140k"
elif [[ "$rpakb" = "2" ]]; then
	akb="-b:a 240k"
elif [[ "$rpakb" = "3" ]]; then
	akb="-b:a 340k"
elif [[ "$rpakb" = "4" ]]; then
	akb="-b:a 440k"
elif [[ "$rpakb" = "5" ]]; then
	akb="-b:a 540k"
elif [[ "$rpakb" = "6" ]]; then
	akb="-b:a 640k"
else
	akb="-b:a 640k"
fi
}
Audio_Source_Info_Detail_Question() {	# Option 31
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
# if number of channel forced, no display option
if [[ -z "$confchan" ]] && [[ -z "$TestFalseStereo" ]]; then
	read -r -p " Apply a -${PeakNormDB}db peak normalization (1st file DB peak:${ffmpeg_peakdb})? [y/N]" qarm
	case $qarm in
		"Y"|"y")
			PeakNorm="1"
		;;
		*)
			return
		;;
	esac
fi
}
Audio_False_Stereo_Question() {			#
# if number of channel forced, no display option
if [[ -z "$confchan" ]] && [[ -z "$PeakNorm" ]]; then
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
		if [[ "$acodec" = "libopus" || "$AudioCodecType" = "libopus" ]]; then
			afilter="-af aformat=channel_layouts='7.1|6.1|5.1|stereo' -mapping_family 1"
		fi
		return
	;;
esac
}
Audio_Multiple_Extention_Check() {		# If sources audio multiple extention question
if [[ "$NBAEXT" -gt "1" ]]; then
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
	if [[ "$NEW_AUDIO_EXT_AVAILABLE" = "q" ]]; then
		Restart
	elif [[ -n "$NEW_AUDIO_EXT_AVAILABLE" ]]; then
		StartLoading "Search the files processed"
		mapfile -t LSTAUDIO < <(find . -maxdepth 5 -type f -regextype posix-egrep \
			-regex '.*\.('$NEW_AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
		mapfile -t LSTAUDIOEXT < <(echo "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
		StopLoading $?
	fi
fi
}
Audio_Generate_Spectrum_Img() {			# Option 32 	- PNG of audio spectrum
# Local variables
local total_target_files_size
local START
local END
# Array
unset filesPass
unset filesReject

clear
echo
echo " Create spectrum image:"

# Start time counter
START=$(date +%s)

Echo_Separator_Light
for i in "${!LSTAUDIO[@]}"; do

	# Generate target file array
	LSTPNG+=( "${LSTAUDIO[i]%.*}.png" )

	(
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "${LSTAUDIO[i]}" \
		-lavfi showspectrumpic "${LSTAUDIO[i]%.*}".png \
		| ProgressBar "" "$((i+1))" "${#LSTAUDIO[@]}" "Spectrum creation" "1"
	) &
	if [[ $(FFmpeg_instance_count) -gt $NPROC ]]; then
		wait -n
	fi

done
wait

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
Audio_Concatenate_Files() {				# Option 33 	- Concatenate audio files
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
if [[ "$concatrep" = "q" ]]; then
		Restart
else

	echo
	Echo_Separator_Light
	
	# Start time counter
	START=$(date +%s)

	# Add date id to created filename, prevent infinite loop of ffmpeg is target=source filename
	filename_id="Concatenate_Output-$(date +%s).${LSTAUDIO[0]##*.}"

	# For progress bar
	FFMES_FFMPEG_PROGRESS="$FFMES_CACHE/ffmpeg-progress-$(date +%Y%m%s%N).info"
	FFMPEG_PROGRESS="-stats_period 0.3 -progress $FFMES_FFMPEG_PROGRESS"

	# Concatenate
	if [[ "${LSTAUDIO[0]##*.}" = "flac" ]] || [[ "${LSTAUDIO[0]##*.}" = "FLAC" ]]; then
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -f concat -safe 0 \
			-i <(for f in *."${LSTAUDIO[0]##*.}"; do echo "file '$PWD/$f'"; done) \
			$FFMPEG_PROGRESS "$filename_id" \
			| ProgressBar "" "1" "1" "Concatenate" "1"
	else
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -f concat -safe 0 \
			-i <(for f in *."${LSTAUDIO[0]##*.}"; do echo "file '$PWD/$f'"; done) \
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
Audio_Cut_File() {						# Option 34 	- Cut audio file
# Local variables
local total_source_files_size
local total_target_files_size
local qcut
local CutStart
local CutEnd
local PERC
local START
local END
local split_output
local CutSegment
# Array
unset filesInLoop

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

	# For progress bar
	FFMES_FFMPEG_PROGRESS="$FFMES_CACHE/ffmpeg-progress-$(date +%Y%m%s%N).info"
	FFMPEG_PROGRESS="-stats_period 0.3 -progress $FFMES_FFMPEG_PROGRESS"

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
Audio_CUE_Split() {						# Option 20 	- CUE Splitter to flac
# Local variables
local charset_detect
local flac_level
local backup_dir
local total_source_files_size
local total_target_files_size
local PERC
local START
local END

# Limit to current directory
mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep \
	-iregex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

if [[ "${#LSTAUDIO[@]}" -eq "0" ]]; then
	Echo_Mess_Error "No audio file in the working directory"
elif [[ "${#LSTAUDIO[@]}" -gt "1" ]]; then
	Echo_Mess_Error "More than one audio file in working directory"
elif [[ "${#LSTCUE[@]}" -eq "1" ]] && [[ "${#LSTAUDIO[@]}" -eq "1" ]]; then

	# Display
	echo
	Echo_Separator_Light
	echo " CUE Split, choose FLAC compression:"
	echo " Notes: * FLAC uses a compression level parameter that varies from 0 (fastest) to 8 (slowest)."
	echo "          The compressed files are always perfect, lossless representations of the original data."
	echo "          Although the compression process involves a tradeoff between speed and size, "
	echo "          the decoding process is always quite fast and not dependent on the level of compression."
	echo
	echo " Choose a number:"
	echo
	echo "        | compression level "
	echo "        |-------------------"
	echo "  [1] > |   -0"
	echo "  [2] > |   -5"
	echo " *[3] > |   -8"
	echo "  [4] > |   --lax -8pl32"
	echo "  [q] > | for exit"
	read -r -e -p "-> " rpakb
	if [[ "$rpakb" = "q" ]]; then
		Restart
	elif [[ "$rpakb" = "1" ]]; then
		flac_level="-0"
	elif [[ "$rpakb" = "2" ]]; then
		flac_level="-5"
	elif [[ "$rpakb" = "3" ]]; then
		flac_level="-8"
	elif [[ "$rpakb" = "4" ]]; then
		flac_level="--lax -8pl32"
	else
		flac_level="-8"
	fi

	# Start time counter
	START=$(date +%s)

	# Backup dir
	backup_dir="backup"
	if [[ ! -d "$backup_dir" ]]; then
		mkdir "$backup_dir" 2>/dev/null
	fi
	
	# Backup Original CUE
	cp "${LSTCUE[0]}" "$backup_dir"/"${LSTCUE[0]}".original.backup

	# UTF-8 convert
	charset_detect=$(uchardet "${LSTCUE[0]}" 2>/dev/null)
	if [[ "$charset_detect" != "UTF-8" ]]; then
		iconv -c -f "$CHARSET_DETECT" -t UTF-8 "${LSTCUE[0]}" > utf-8.cue
		rm "${LSTCUE[0]}" 2>/dev/null
		mv -f utf-8.cue "${LSTCUE[0]}"
	fi

	# Remove empty line in CUE
	sed -i '/^[[:space:]]*$/d' "${LSTCUE[0]}"
	# Replace '' by ' = prevent cuetag error
	sed -i "s/''/'/g" "${LSTCUE[0]}"

	# If tak, tta, wavpack -> WAV
	if [[ "${LSTAUDIO[0]##*.}" = "ape" ]] \
	|| [[ "${LSTAUDIO[0]##*.}" = "tak" ]] \
	|| [[ "${LSTAUDIO[0]##*.}" = "tta" ]] \
	|| [[ "${LSTAUDIO[0]##*.}" = "wv" ]]; then
		echo "[${LSTAUDIO[0]}] --> [${LSTAUDIO[0]%.*}.wav]"
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -y \
			-i "${LSTAUDIO[0]}" \
			-c:a pcm_s16le \
			"${LSTAUDIO[0]%.*}.wav" 2>/dev/null
		# Clean
		if test $? -eq 0; then
			mv "${LSTAUDIO[0]}" "$backup_dir"/"${LSTAUDIO[0]}".backup 2>/dev/null
			LSTAUDIO=( "${LSTAUDIO[0]%.*}.wav" )
		else
			Echo_Separator_Light
			echo "  CUE Splitting fail on extraction"
			Echo_Separator_Light
			return 1
		fi
	fi

	# Split file
	shnsplit -w -f "${LSTCUE[0]}" \
		-t "%n - %t" "${LSTAUDIO[0]}" \
		-o "flac flac $flac_level -s -o %f -"

	# Clean
	if test $? -eq 0; then
		rm 00*.flac 2>/dev/null

		# Move source audio file
		mv "${LSTAUDIO[0]}" "$backup_dir"/"${LSTAUDIO[0]}".backup 2>/dev/null

		# Generate target file array
		mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep \
									-iregex '.*\.('flac')$' 2>/dev/null \
									| sort \
									| sed 's/^..//')
		# Tag target
		cuetag "${LSTCUE[0]}" "${LSTAUDIO[@]}" 2>/dev/null

		# Move source cue
		mv "${LSTCUE[0]}" "$backup_dir"/"${LSTCUE[0]}".backup 2>/dev/null
	else
		Echo_Separator_Light
		echo "  CUE Splitting fail on shnsplit file"
		Echo_Separator_Light
		return 1
	fi

	# File validation
	Test_Target_File "1" "audio" "${LSTAUDIO[@]}"

	# End time counter
	END=$(date +%s)

	# Make statistics of processed files
	Calc_Elapsed_Time "$START" "$END"
	total_target_files_size=$(Calc_Files_Size "${LSTAUDIO[@]}")

	# End encoding messages "pass_files" "total_files" "target_size" "source_size"
	Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" ""

	# Clean
	Remove_Audio_Split_Backup_Dir
fi
}
Audio_File_Tester() {					# Option 35 	- ffmpeg file test
# Local variables
local START
local END
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

# Test loop
for files in "${LSTAUDIO[@]}"; do
	# Stock files pass in loop
	filesInLoop+=("$files")

	# Test integrity
	(
	tmp_error=$(mktemp)
	"$ffmpeg_bin" -v error -i "$files" -max_muxing_queue_size 9999 -f null - 2>"$tmp_error"
	if [[ -s "$tmp_error" ]]; then
		cp "$tmp_error" "${files%.*}-error.log"
		echo "  $files" >> "$FFMES_CACHE_INTEGRITY"
	fi
	) &
	if [[ $(FFmpeg_instance_count) -ge $NPROC ]]; then
		wait -n
	fi

	ProgressBar "" "${#filesInLoop[@]}" "${#LSTAUDIO[@]}" "Integrity check" "1"

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
if [[ -s "$FFMES_CACHE_INTEGRITY" ]]; then
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

for i in "${!LSTAUDIO[@]}"; do
	StartLoading "" "Tag: ${LSTAUDIO[$i]}"

	# Parsing
	if [[ "$tag_option" = "ftitle" ]]; then
		tag_value="${LSTAUDIO[$i]%.*}"
	elif [[ "$tag_option" = "stitle" ]]; then
		tag_value="${TAG_TITLE[$i]:${tag_cut}}"
		# Remove leading space
		tag_value="${tag_value#"${tag_value%%[![:space:]]*}"}"
	elif [[ "$tag_option" = "etitle" ]]; then
		# Prevent negative sub error
		if [[ "${tag_cut}" -gt "${#TAG_TITLE[$i]}" ]]; then
			tag_cut="${#TAG_TITLE[$i]}"
		fi
		tag_value="${TAG_TITLE[$i]:0:-${tag_cut}}"
	elif [[ "$tag_option" = "ptitle" ]]; then
		tag_value="${TAG_TITLE[$i]//$tag_cut}"
	elif [[ "$tag_option" = "track" ]]; then
		tag_value="${TAG_TRACK_COUNT[$i]}"
	fi

	(
	# APEv2
	if [[ "${LSTAUDIO[$i]##*.}" = "wv" ]] \
	|| [[ "${LSTAUDIO[$i]##*.}" = "ape" ]]; then
		# Proper tag
		tag_label="${tag_label//track/Track}"
		tag_label="${tag_label//album/Album}"
		tag_label="${tag_label//artist/Artist}"
		tag_label="${tag_label//date/Year}"
		tag_label="${tag_label//title/Title}"
		tag_label="${tag_label//disk/Disc}"
		# Tag
		if [[ "${LSTAUDIO[$i]##*.}" = "wv" ]]; then
			wvtag -q \
				-d "$tag_label" \
				-w "$tag_label"="$tag_value" \
				"${LSTAUDIO[$i]}" &>/dev/null
		elif [[ "${LSTAUDIO[$i]##*.}" = "ape" ]] \
		  && [[ -z "$apev2_error" ]]; then
			mac "${LSTAUDIO[$i]}" \
				-t "$tag_label"="$tag_value" &>/dev/null
		fi

	# Vorbis comment
	elif [[ "${LSTAUDIO[$i]##*.}" = "flac" ]] \
	  || [[ "${LSTAUDIO[$i]##*.}" = "ogg" ]] \
	  || [[ "${LSTAUDIO[$i]##*.}" = "opus" ]]; then
		# Proper tag
		tag_label="${tag_label//track/TRACKNUMBER}"
		tag_label="${tag_label//album/ALBUM}"
		tag_label="${tag_label//artist/ARTIST}"
		tag_label="${tag_label//date/DATE}"
		tag_label="${tag_label//title/TITLE}"
		tag_label="${tag_label//disk/DISCNUMBER}"
		# Tag
		if [[ "${LSTAUDIO[$i]##*.}" = "flac" ]]; then
			metaflac \
				--remove-tag="$tag_label" \
				--set-tag="$tag_label"="$tag_value" \
				"${LSTAUDIO[$i]}" &>/dev/null
		elif [[ "${LSTAUDIO[$i]##*.}" = "ogg" ]]; then
			vorbiscomment \
				-d "$tag_label" \
				-a -t "$tag_label"="$tag_value" \
				"${LSTAUDIO[$i]}" &>/dev/null
		elif [[ "${LSTAUDIO[$i]##*.}" = "opus" ]]; then
			opustags -i \
				-s "$tag_label"="$tag_value" \
				"${LSTAUDIO[$i]}" &>/dev/null
		fi

	# iTunes
	elif [[ "${LSTAUDIO[$i]##*.}" = "m4a" ]]; then
		# Proper tag
		tag_label="${tag_label//track/tracknum}"
		tag_label="${tag_label//album/album}"
		tag_label="${tag_label//artist/artist}"
		tag_label="${tag_label//date/year}"
		tag_label="${tag_label//title/title}"
		tag_label="${tag_label//disk/disk}"
		# Tag
		AtomicParsley "${LSTAUDIO[$i]}" --"$tag_label" "$tag_value" \
			--overWrite &>/dev/null

	# ID3v2
	elif [[ "${LSTAUDIO[$i]##*.}" = "mp3" ]]; then
		# Proper tag
		tag_label="${tag_label//track/TRCK}"
		tag_label="${tag_label//album/TALB}"
		tag_label="${tag_label//artist/TPE1}"
		tag_label="${tag_label//date/TDRC}"
		tag_label="${tag_label//title/TIT2}"
		tag_label="${tag_label//disk/TPOS}"
		# Tag
		mid3v2 --"$tag_label" "$tag_value" \
			"${LSTAUDIO[$i]}" &>/dev/null

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
# Local variables
local rename_option
local tag_track_proper
local tag_disc_proper
local ParsedTrack
local ParsedTitle
local ParsedArtist
local ParsedFilename

# Argument
rename_option="$1"

# Max total digit, ignore slash
tag_track_total_digit=$(printf "%s\n" "${TAG_TRACK[@]}" \
						| awk -F"/" '{ print $1 }' \
						| wc -L)

for i in "${!LSTAUDIO[@]}"; do

	# Remove leading 0, ignore slash
	tag_track_proper="$(echo "${TAG_TRACK[i]}" \
						| awk -F"/" '{ print $1 }' \
						| sed 's/^0*//')"
	tag_disc_proper="$(echo "${TAG_DISC[i]}" \
						| awk -F"/" '{ print $1 }' \
						| sed 's/^0*//')"

	# If no tag tracknumber - use TAG_TRACK_COUNT
	if [[ -z "${TAG_TRACK[i]}" ]]; then
		ParsedTrack="${TAG_TRACK_COUNT[i]}"
	# If tag tracknumber
	else
		# If integer
		if [[ "${tag_track_proper}" =~ ^-?[0-9]+$ ]]; then
			# Lead 0 condition
			if [[ "$tag_track_total_digit" -eq "1" ]] && [[ "${#tag_track_proper}" = "1" ]]; then
				ParsedTrack="${tag_track_proper}"

			elif [[ "$tag_track_total_digit" -eq "2" ]] && [[ "${#tag_track_proper}" = "1" ]]; then
				ParsedTrack="0$tag_track_proper"
			elif [[ "$tag_track_total_digit" -eq "2" ]] && [[ "${#tag_track_proper}" = "2" ]]; then
				ParsedTrack="$tag_track_proper"

			elif [[ "$tag_track_total_digit" -eq "3" ]] && [[ "${#tag_track_proper}" = "1" ]]; then
				ParsedTrack="00$tag_track_proper"
			elif [[ "$tag_track_total_digit" -eq "3" ]] && [[ "${#tag_track_proper}" = "2" ]]; then
				ParsedTrack="0$tag_track_proper"
			elif [[ "$tag_track_total_digit" -eq "3" ]] && [[ "${#tag_track_proper}" = "3" ]]; then
				ParsedTrack="$tag_track_proper"

			elif [[ "$tag_track_total_digit" -eq "4" ]] && [[ "${#tag_track_proper}" = "1" ]]; then
				ParsedTrack="000$tag_track_proper"
			elif [[ "$tag_track_total_digit" -eq "4" ]] && [[ "${#tag_track_proper}" = "2" ]]; then
				ParsedTrack="00$tag_track_proper"
			elif [[ "$tag_track_total_digit" -eq "4" ]] && [[ "${#tag_track_proper}" = "3" ]]; then
				ParsedTrack="0$tag_track_proper"
			elif [[ "$tag_track_total_digit" -eq "4" ]] && [[ "${#tag_track_proper}" = "4" ]]; then
				ParsedTrack="$tag_track_proper"
			fi
		# Used for vinyl type A, B...
		else
			ParsedTrack="${TAG_TRACK[i]}"
		fi
	fi

	# If no tag title
	if [[ -z "${TAG_TITLE[i]}" ]]; then
		ParsedTitle="[untitled]"
	else
		# Replace eventualy / , " , : in string
		ParsedTitle="${TAG_TITLE[i]////-}"
		ParsedTitle="${ParsedTitle//:/-}"
		ParsedTitle="${ParsedTitle//\"/-}"
		# Remove leading space
		ParsedTitle="${ParsedTitle#"${ParsedTitle%%[![:space:]]*}"}"
		# Remove ending space
		shopt -s extglob
		ParsedTitle="${ParsedTitle%%+([[:space:]])}"
		shopt -u extglob
	fi

	# If no tag artist
	if [[ -z "${TAG_ARTIST[i]}" ]]; then
		ParsedArtist="[unknown]"
	else
		# Replace eventualy / , " , : in string
		ParsedArtist="${TAG_ARTIST[i]////-}"
		ParsedArtist="${ParsedArtist//:/-}"
		ParsedArtist="${ParsedArtist//\"/-}"
		# Remove leading space
		ParsedArtist="${ParsedArtist#"${ParsedArtist%%[![:space:]]*}"}"
		# Remove ending space
		shopt -s extglob
		ParsedArtist="${ParsedArtist%%+([[:space:]])}"
		shopt -u extglob
	fi

	# Filename construct
	(
	if [[ -f "${LSTAUDIO[i]}" && -s "${LSTAUDIO[i]}" ]]; then
		if [[ "$rename_option" = "rename" ]]; then
			ParsedFilename="$ParsedTrack - ${ParsedTitle}.${LSTAUDIO[i]##*.}"
		elif [[ "$rename_option" = "arename" ]]; then
			ParsedFilename="$ParsedTrack - $ParsedArtist - ${ParsedTitle}.${LSTAUDIO[i]##*.}"
		elif [[ "$rename_option" = "drename" ]]; then
			if [[ -n "${TAG_DISC[i]}" ]]; then
				ParsedFilename="${tag_disc_proper}-${ParsedTrack} - ${ParsedTitle}.${LSTAUDIO[i]##*.}"
			else
				ParsedFilename="$ParsedTrack - ${ParsedTitle}.${LSTAUDIO[i]##*.}"
			fi
		elif [[ "$rename_option" = "darename" ]]; then
			if [[ -n "${TAG_DISC[i]}" ]]; then
				ParsedFilename="${tag_disc_proper}-${ParsedTrack} - $ParsedArtist - ${ParsedTitle}.${LSTAUDIO[i]##*.}"
			else
				ParsedFilename="$ParsedTrack - $ParsedArtist - ${ParsedTitle}.${LSTAUDIO[i]##*.}"
			fi
		fi
	fi
	# Rename
	if [[ "${LSTAUDIO[i]}" != "$ParsedFilename" ]] \
	&& [[ "${LSTAUDIO[i]}" != "${LSTAUDIO[i]%/*}/${ParsedFilename}" ]]; then
		StartLoading "" "Rename: ${LSTAUDIO[i]}"
		if [[ "${LSTAUDIO[i]}" = "${LSTAUDIO[i]%/*}" ]]; then
			mv "${LSTAUDIO[i]}" "$ParsedFilename" &>/dev/null
		else
			mv "${LSTAUDIO[i]}" "${LSTAUDIO[i]%/*}/${ParsedFilename}" &>/dev/null
		fi
		StopLoading $?
	fi
	) &
	if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
		wait -n
	fi

	# Reset
	unset ParsedTrack

done
wait
}
Audio_Tag_Editor() {					# Option 30 	- Tag editor
# Local variables
local tag_date_raw0
local tag_date_raw1
local tag_date_raw2
local tag_date_raw3
local ParsedAlbum
local ParsedArtist
local ParsedDate
local ParsedDisc
local ParsedTitle
local ParsedTrack
local tag_artist_string_length
local tag_disk_string_length
local tag_track_string_length
local tag_title_string_length
local tag_artist_string_length
local tag_album_string_length
local tag_date_string_length
local filename_string_length
local horizontal_separator_string_length
# Reset
unset TAG_DISC
unset TAG_TRACK
unset TAG_TITLE
unset TAG_ARTIST
unset TAG_ALBUM
unset TAG_DATE
unset TAG_TRACK_COUNT
unset PrtSep
unset apev2_error

# Loading on
StartLoading "Grab current tags" ""

# Limit to current directory & audio file ext. tested
mapfile -t LSTAUDIO < <(find . -maxdepth 2 -type f -regextype posix-egrep -iregex \
						'.*\.('$AUDIO_TAG_EXT_AVAILABLE')$' 2>/dev/null | sort -V | sed 's/^..//')

# Get tag with ffprobe
for i in "${!LSTAUDIO[@]}"; do
	(
	"$ffprobe_bin" -hide_banner -loglevel panic -select_streams a -show_streams -show_format \
		"${LSTAUDIO[$i]}" > "$FFMES_CACHE_TAG-[$i]"
	) &
	if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
		wait -n
	fi
done
wait

# Populate array with tag
for i in "${!LSTAUDIO[@]}"; do
	TAG_DISC+=( "$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:disc=" | awk -F'=' '{print $NF}')" )
	if [[ -z "${TAG_DISC[-1]}" ]]; then
		TAG_DISC[-1]=$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:disk=" | awk -F'=' '{print $NF}')
	fi
	TAG_TRACK+=( "$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:track=" | awk -F'=' '{print $NF}')" )
	TAG_TITLE+=( "$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:title=" | awk -F'=' '{print $NF}')" )
	TAG_ARTIST+=( "$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:artist=" | awk -F'=' '{print $NF}')" )
	TAG_ALBUM+=( "$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:album=" | awk -F'=' '{print $NF}')" )
	tag_date_raw0=$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:date=" | awk -F'=' '{print $NF}')
	if [[ -n "$tag_date_raw0" ]]; then
		TAG_DATE+=( "$tag_date_raw0" )
	else
		tag_date_raw1=$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:Year=" | awk -F'=' '{print $NF}')
		tag_date_raw2=$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:Originaldate=" | awk -F'=' '{print $NF}')
		tag_date_raw3=$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:ORIGINALYEAR=" | awk -F'=' '{print $NF}')
		if [[ -n "$tag_date_raw1" ]]; then
			TAG_DATE+=( "$tag_date_raw1" )
		elif [[ -n "$tag_date_raw2" ]]; then
			TAG_DATE+=( "$tag_date_raw2" )
		elif [[ -n "$tag_date_raw3" ]]; then
			TAG_DATE+=( "$tag_date_raw3" )
		else
			TAG_DATE+=( " " )
		fi
	fi
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
tag_disk_string_length="1"
tag_track_string_length=$(Calc_Table_width "${TAG_TRACK[@]}")
tag_title_string_length="20"
tag_album_string_length="20"
tag_date_string_length="4"
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
separator_string_length=$(( filename_string_length + tag_disk_string_length \
							+ tag_track_string_length + tag_title_string_length \
							+ tag_artist_string_length + tag_album_string_length \
							+ tag_date_string_length + horizontal_separator_string_length ))

# Loading off
StopLoading $?

# Display tags
# In table if term is wide enough, or in ligne
clear
echo
echo "Audio files tags:"
if [[ "$separator_string_length" -le "$TERM_WIDTH" ]]; then
	printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo
	paste <(printf "%-${filename_string_length}.${filename_string_length}s\n" "Files") <(printf "%s\n" "|") \
			<(printf "%-${tag_disk_string_length}.${tag_disk_string_length}s\n" "D") <(printf "%s\n" "|") \
			<(printf "%-${tag_track_string_length}.${tag_track_string_length}s\n" "Track") <(printf "%s\n" "|") \
			<(printf "%-${tag_title_string_length}.${tag_title_string_length}s\n" "Title") <(printf "%s\n" "|") \
			<(printf "%-${tag_artist_string_length}.${tag_artist_string_length}s\n" "Artist") <(printf "%s\n" "|") \
			<(printf "%-${tag_album_string_length}.${tag_album_string_length}s\n" "Album") <(printf "%s\n" "|") \
			<(printf "%-${tag_date_string_length}.${tag_date_string_length}s\n" "date") | column -s $'\t' -t
	printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo
	paste <(printf "%-${filename_string_length}.${filename_string_length}s\n" "${LSTAUDIO[@]}" | iconv -c -s -f utf-8 -t utf-8) \
			<(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_disk_string_length}.${tag_disk_string_length}s\n" "${TAG_DISC[@]}") \
			<(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_track_string_length}.${tag_track_string_length}s\n" "${TAG_TRACK[@]}") \
			<(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_title_string_length}.${tag_title_string_length}s\n" "${TAG_TITLE[@]}" | iconv -c -s -f utf-8 -t utf-8) \
			<(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_artist_string_length}.${tag_artist_string_length}s\n" "${TAG_ARTIST[@]}" | iconv -c -s -f utf-8 -t utf-8) \
			<(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_album_string_length}.${tag_album_string_length}s\n" "${TAG_ALBUM[@]}" | iconv -c -s -f utf-8 -t utf-8) \
			<(printf "%s\n" "${PrtSep[@]}") \
			<(printf "%-${tag_date_string_length}.${tag_date_string_length}s\n" "${TAG_DATE[@]}") \
			| column -s $'\t' -t 2>/dev/null
	printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo
else
	printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo
	for i in "${!LSTAUDIO[@]}"; do
		Display_Line_Truncate "${LSTAUDIO[$i]}"
		echo " disk: ${TAG_DISC[$i]}, track: ${TAG_TRACK[$i]}"
		echo " title: ${TAG_TITLE[$i]}"
		echo " artist: ${TAG_ARTIST[$i]}"
		echo " album: ${TAG_ALBUM[$i]}"
		echo " date: ${TAG_DATE[$i]}"
		printf "%*s" "$TERM_WIDTH_TRUNC" "" | tr ' ' "-"; echo
	done
fi

# Display menu
echo
echo " Select tag option:"
echo " Notes: it is not at all recommended to threat more than one album at a time."
if [[ "$separator_string_length" -le "$TERM_WIDTH" ]]; then
	echo
	echo "                 | actions                    | descriptions"
	echo "                 |----------------------------|------------------------------------------------------|"
	echo '  [rename]     > | rename files               | rename in "Track - Title"                            |'
	echo '  [arename]    > | rename files with artist   | rename in "Track - Artist - Title"                   |'
	echo '  [drename]    > | rename files with disc     | rename in "Disc-Track - Title"                       |'
	echo '  [darename]   > | rename with disc & artist  | rename in "Disc-Track - Artist - Title"              |'
	echo "  [disc]       > | change or add disc number  | ex. of input [disk 1]                                |"
	echo "  [track]      > | change or add tag track    | apply to all files by alphabetic sorting             |"
	echo "  [album x]    > | change or add tag album    | ex. of input [album Conan the Barbarian]             |"
	echo "  [artist x]   > | change or add tag artist   | ex. of input [artist Basil Poledouris]               |"
	echo "  [uartist]    > | change artist by [unknown] |                                                      |"
	echo "  [date x]     > | change or add tag date     | ex. of input [date 1982]                             |"
	echo "  [ftitle]     > | change title by [filename] |                                                      |"
	echo "  [utitle]     > | change title by [untitled] |                                                      |"
	echo "  [stitle x]   > | remove N at begin of title | ex. [stitle 3] -> remove 3 first characters at start |"
	echo "  [etitle x]   > | remove N at end of title   | ex. [etitle 1] -> remove 1 first characters at end   |"
	echo '  [ptitle "x"] > | remove pattern in title    | ex. [ptitle "test"] -> remove test pattern in title  |'
	echo "  [r]          > | for restart tag editor"
	echo "  [q]          > | for exit"
	echo
else
	echo
	echo '  [rename]   > rename files in "Track - Title"'
	echo '  [arename]  > rename files in "Track - Artist - Title"'
	echo '  [drename]  > rename files in "Disc-Track - Title"'
	echo '  [darename]  > rename files in "Disc-Track - Artist - Title"'
	echo "  [disc]     > change or add disk number"
	echo "  [track]    > change or add tag track (alphabetic sorting)"
	echo "  [album x]  > change or add tag album"
	echo "  [artist x] > change or add tag artist"
	echo "  [date x]   > change or add tag date"
	echo "  [uartist]  > change artist by [unknown]"
	echo "  [ftitle]   > change title by [filename]"
	echo "  [utitle]   > change title by [untitled]"
	echo "  [stitle x] > remove N at begin of title"
	echo "  [etitle x] > remove N at end of title"
	echo "  [ptitle x] > remove pattern in title"
	echo "  [r]        > for restart tag editor"
	echo "  [q]        > for exit"
	echo
fi
if ! command -v mac &>/dev/null; then
	apev2_error="1"
	Echo_Mess_Error "mac (monkeys-audio) not installed, ape files will not be tagged"
	echo
fi

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
		drename)
			Audio_Tag_Rename "drename"
			Audio_Tag_Editor
		;;
		darename)
			Audio_Tag_Rename "darename"
			Audio_Tag_Editor
		;;
		disc?[0-9])
			ParsedDisc="${rpstag##* }"
			Audio_Tag_cmd "disk" "$ParsedDisc"
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
		stitle?[1-9]|stitle?[1-9][0-9])
			ParsedTitle=$(echo "$rpstag" | awk '{print $2}')
			Audio_Tag_cmd "title" "" "stitle" "$ParsedTitle"
			Audio_Tag_Editor
		;;
		etitle?[1-9]|etitle?[1-9][0-9])
			ParsedTitle=$(echo "$rpstag" | awk '{print $2}')
			Audio_Tag_cmd "title" "" "etitle" "$ParsedTitle"
			Audio_Tag_Editor
		;;
		ptitle*)
			ParsedTitle=$(echo "$rpstag" | awk -F'"' '$0=$2')
			Audio_Tag_cmd "title" "" "ptitle" "$ParsedTitle"
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
}

# Arguments variables
initial_working_dir="$PWD"
ffmes_args_full=( "$@" )
while [[ $# -gt 0 ]]; do
	ffmes_args="$1"
	case "$ffmes_args" in
	-h|--help)
		# Help
		Usage
		exit
		;;
	-ca|--compare_audio)
		# Compare current audio files informations
		shift
		force_compare_audio="1"
		ffmes_option="31"
		;;
	-i|--input)
		# Input file or dir
		shift
		InputFileDir="$1"
		# If directory
		if [[ -d "$InputFileDir" ]]; then
			cd "$InputFileDir" || exit
		# If file
		elif [[ -f "$InputFileDir" ]]; then

			# Variable filter
			InputFileExt="${InputFileDir##*.}"
			all_ext_available="${VIDEO_EXT_AVAILABLE}| \
							   ${AUDIO_EXT_AVAILABLE}| \
							   ${ISO_EXT_AVAILABLE}| \
							   ${SUBTI_EXT_AVAILABLE}"
			all_ext_available="${all_ext_available//[[:blank:]]/}"
			mapfile -t arr_all_ext_available < <( echo "${all_ext_available//|/$'\n'}" )

			# Ext. test
			shopt -s nocasematch
			for files_ext in "${arr_all_ext_available[@]}"; do
				if [[ "$files_ext" = "$InputFileExt" ]]; then
					ext_test_result_off="1"
				fi
			done
			shopt -u nocasematch

			# If test pass = no error
			if [[ "$ext_test_result_off" != "1" ]]; then
				echo
				Echo_Mess_Error "\"$1\" is not supported"
				Echo_Mess_Error "Supported Video: ${VIDEO_EXT_AVAILABLE//|/, }"
				Echo_Mess_Error "Supported Audio: ${AUDIO_EXT_AVAILABLE//|/, }"
				Echo_Mess_Error "Supported DVD Image: ${ISO_EXT_AVAILABLE//|/, }"
				Echo_Mess_Error "Supported Subtitle: ${SUBTI_EXT_AVAILABLE//|/, }"
				echo
				exit
			else
				InputFileArg="$InputFileDir"
			fi
		elif ! [[ -f "$InputFileDir" ]]; then
			Echo_Mess_Error "\"$1\" does not exist" "1"
			exit
		fi
		;;
	-j|--videojobs)
		# For number of parallel job
		shift
		if ! [[ "$1" =~ ^[0-9]*$ ]]; then
			Echo_Mess_Error "Video jobs option must be an positive integer" "1"
			exit
		else
			unset NVENC
			if [[ "$NVENC" -lt 0 ]]; then
				Echo_Mess_Error "Video jobs must be greater than zero" "1"
				exit
			else
				NVENC=$(( "$1" - 1 ))
			fi
		fi
		;;
	-kc|--keep_cover)
		# Force keep cover in audio file
		unset ExtractCover
		ExtractCover="1"
		;;
	--novaapi)
		# No VAAPI 
		unset VAAPI_device
		;;
	-s|--select)
		# By-pass main menu
		shift
		ffmes_option="$1"
		;;
	-pk|--peaknorm)
		# Change default peak db norm
		shift
		if [[ "$1" =~ ^[0-9]*[.][0-9]*$ ]] || [[ "$1" =~ ^[0-9]*$ ]]; then
			unset PeakNormDB
			PeakNormDB="$1"
		else
			Echo_Mess_Error "Peak db normalization option must be a positive number" "1"
			exit
		fi
		;;
	-v|--verbose)
		# Set verbose lvl 1
		VERBOSE="1"
		unset FFMPEG_LOG_LVL
		unset X265_LOG_LVL
		FFMPEG_LOG_LVL="-loglevel info -stats"
		unset FFMPEG_PROGRESS
		;;
	-vv|--fullverbose)
		# Set verbose lvl 2
		VERBOSE="1"
		unset FFMPEG_LOG_LVL
		unset X265_LOG_LVL
		FFMPEG_LOG_LVL="-loglevel debug -stats"
		unset FFMPEG_PROGRESS
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
CheckJQCommand
CheckMediaInfoCommand
CheckFFmesDirectory
CheckCustomBin
CheckFFmpegVersion
TestVAAPI
Display_Term_Size
StartLoading "Listing of media files to be processed"
SetGlobalVariables
DetectDVD
StopLoading $?
# Set Ctrl+c clean trap for exit all script
trap TrapExit INT TERM
trap "kill 0" EXIT
# Set Ctrl+z clean trap for exit current loop (for debug)
trap TrapStop SIGTSTP
# By-pass main menu if using command argument
if [[ -z "$ffmes_option" ]]; then
	Display_Main_Menu
fi

while true; do

	# By-pass selection if using command argument
	if [[ -z "$ffmes_option" ]]; then
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
			"0") # DVD rip
				CheckDVDCommand
				DVDRip
				Video_Custom_Video
				Video_Custom_Audio
				Video_Custom_Container
				Video_Custom_Stream
				Video_FFmpeg_cmd
				Remove_File_Source
				Clean
			;;
			"1") # Blu-ray rip
				if [[ "${#LSTISO[@]}" -gt "1" ]]; then
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
		if (( "${#LSTVIDEO[@]}" )); then
			Video_Multiple_Extention_Check
			Video_Custom_Video
			Video_Custom_Audio
			Video_Custom_Container
			Video_Custom_Stream
			Video_FFmpeg_cmd
			Remove_File_Source
			Remove_File_Target
			Clean
		else
			Echo_Mess_Error "$MESS_NO_VIDEO_FILE" "1"
		fi
		;;

	 2 ) # video -> mkv|copy|copy
		if (( "${#LSTVIDEO[@]}" )); then
			videoconf="-c:v copy"
			soundconf="-c:a copy"
			extcont="mkv"
			container="matroska"
			videoformat="avcopy"
			Video_Multiple_Extention_Check
			Video_Custom_Stream
			Video_FFmpeg_cmd
			Remove_File_Source
			Clean
		else
			Echo_Mess_Error "$MESS_NO_VIDEO_FILE" "1"
		fi
		;;

	 3 ) # Audio night normalization
		if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
			Video_Add_OPUS_NightNorm
			Clean
		else
			Echo_Mess_Error "$MESS_ONE_VIDEO_ONLY" "1"
		fi
		;;

	 4 ) # One audio stream encoding
		if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
			Video_Custom_One_Audio
			Remove_File_Source
			Clean
		else
			Echo_Mess_Error "$MESS_ONE_VIDEO_ONLY" "1"
		fi
		;;

	 10 ) # video -> mkv|copy|add audio|add sub
		if [[ "${#LSTVIDEO[@]}" -eq "1" ]] \
		&& [[ "${#LSTSUB[@]}" -gt 0 || "${#LSTAUDIO[@]}" -gt 0 ]]; then
			videoformat="addcopy"
			Video_Merge_Files
			Clean
		else
			Echo_Mess_Error "One video, with several audio and/or subtitle files" "1"
		fi
		;;

	 11 ) # Concatenate video
		if [[ "${#LSTVIDEO[@]}" -gt "1" ]] \
		&& [[ "$NBVEXT" -eq "1" ]]; then
			Video_Concatenate
			Video_Custom_Video
			Video_Custom_Audio
			Video_Custom_Container
			Video_Custom_Stream
			Video_FFmpeg_cmd
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

	 12 ) # Extract stream video
		if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
			Video_Extract_Stream
			Clean
		else
			Echo_Mess_Error "$MESS_ONE_VIDEO_ONLY" "1"
		fi
		;;

	 13 ) # Cut video
		if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
			Video_Cut_File
			Clean
		else
			Echo_Mess_Error "$MESS_ONE_VIDEO_ONLY" "1"
		fi
		;;

	 14 ) # Split by chapter mkv
		if [[ "${#LSTVIDEO[@]}" -eq "1" ]] \
		&& [[ "${LSTVIDEO[0]##*.}" = "mkv" ]]; then
			Video_Split_By_Chapter
			Clean
		else
			Echo_Mess_Error "$MESS_ONE_VIDEO_ONLY" "1"
		fi
		;;

	 15 ) # Change color palette of DVD subtitle
		if [[ "${LSTSUBEXT[*]}" = *"idx"* ]]; then
			DVDSubColor
			Clean
		else
			Echo_Mess_Error "Only DVD subtitle extention type (idx/sub)" "1"
		fi
		;;

	 16 ) # Convert DVD subtitle to srt
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
		if [[ "${#LSTCUE[@]}" -eq "0" ]]; then
			Echo_Mess_Error "No CUE file in the working director" "1"
		elif [[ "${#LSTCUE[@]}" -gt "1" ]]; then
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
			acodec="-c:a $AudioCodecType"
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
			acodec="-c:a $AudioCodecType"
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
			acodec="-c:a $AudioCodecType"
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
			acodec="-c:a $AudioCodecType"
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
			acodec="-c:a $AudioCodecType"
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
			AudioCodecType="$ffmpeg_aac_encoder"
			Audio_Multiple_Extention_Check
			Audio_AAC_Config
			Audio_Channels_Question
			acodec="-c:a $AudioCodecType"
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
			# Change number of process for increase speed, here *4
			NPROC=$(grep -cE 'processor' /proc/cpuinfo | awk '{ print $1 * 4 }')
			Audio_Tag_Editor
			# Reset number of process
			NPROC=$(grep -cE 'processor' /proc/cpuinfo)
			Clean
		else
				echo
				Echo_Mess_Error "No audio file to supported"
				Echo_Mess_Error "Supported files: ${AUDIO_TAG_EXT_AVAILABLE//|/, }"
				echo
		fi
		;;

	 31 ) # tools -> multi file view stats
		if (( "${#LSTAUDIO[@]}" )); then
			Display_Audio_Stats_List "${LSTAUDIO[@]}"
			Clean
		else
			Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
		fi
		if [[ "$force_compare_audio" = "1" ]]; then
			exit
		fi
		;;

	 32 ) # audio -> generate png of audio spectrum
		if (( "${#LSTAUDIO[@]}" )); then
			Audio_Multiple_Extention_Check
			Audio_Generate_Spectrum_Img
			Clean
		else
			Echo_Mess_Error "$MESS_NO_AUDIO_FILE" "1"
		fi
		;;

	 33 ) # Concatenate audio
		if [[ "${#LSTAUDIO[@]}" -gt "1" ]] \
		&& [[ "$NBAEXT" -eq "1" ]]; then
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

	 34 ) # Cut audio
		if [[ "${#LSTAUDIO[@]}" -eq "1" ]]; then
			Audio_Cut_File
			Clean
		else
			Echo_Mess_Error "$MESS_ONE_AUDIO_ONLY" "1"
		fi
		;;

	 35 ) # File check
		if [[ "${#LSTAUDIO[@]}" -ge "1" ]]; then
			ProgressBarOption="1"
			NPROC=$(grep -cE 'processor' /proc/cpuinfo | awk '{ print $1 * 4 }')
			Audio_File_Tester
			Clean
			# Reset
			NPROC=$(grep -cE 'processor' /proc/cpuinfo)
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

	# By-pass selection if using command argument
	unset ffmes_option

done
exit
