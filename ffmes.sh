#!/bin/bash
# ffmes - ffmpeg media encode script
# Bash tool handling media files and DVD. Mainly with ffmpeg. Batch or single file.
#
# Author : Romain Barbarot
# https://github.com/Jocker666z/ffmes/
#
# licence : GNU GPL-2.0

# Version
VERSION=v0.85

# Paths
export PATH=$PATH:/home/$USER/.local/bin													# For case of launch script outside a terminal & bin in user directory
FFMES_BIN=$(basename "${0}")																# Set script name for prevent error when rename script
FFMES_PATH="$( cd "$( dirname "$0" )" && pwd )"												# Set ffmes path for restart from any directory
FFMES_CACHE="/home/$USER/.cache/ffmes"														# cache directory
FFMES_CACHE_STAT="/home/$USER/.cache/ffmes/stat-$(date +%Y%m%s%N).info"						# stat-DATE.info, stats of source file
FFMES_FFPROBE_CACHE_STAT_DETAILED="/home/$USER/.cache/ffmes/stat-ffprobe-detailled-$(date +%Y%m%s%N).info"	# 
FFMES_FFMPEG_CACHE_STAT_DETAILED="/home/$USER/.cache/ffmes/stat-ffmpeg-detailled-$(date +%Y%m%s%N).info"	# 
FFMES_CACHE_MAP="/home/$USER/.cache/ffmes/map-$(date +%Y%m%s%N).info"						# map-DATE.info, map file
FFMES_CACHE_TAG="/home/$USER/.cache/ffmes/tag-$(date +%Y%m%s%N).info"						# tag-DATE.info, audio tag file
FFMES_CACHE_INTEGRITY="/home/$USER/.cache/ffmes/interity-$(date +%Y%m%s%N).info"			# integrity-DATE.info, list of files fail interity check
FFMES_CACHE_UNTAGGED="/home/$USER/.cache/ffmes/untagged-$(date +%Y%m%s%N).info"				# integrity-DATE.info, list of files untagged
LSDVD_CACHE="/home/$USER/.cache/ffmes/lsdvd-$(date +%Y%m%s%N).info"							# lsdvd cache
OPTICAL_DEVICE=(/dev/dvd /dev/sr0 /dev/sr1 /dev/sr2 /dev/sr3)								# DVD player drives names

# General variables
CORE_COMMAND_NEEDED=(ffmpeg ffprobe sox mediainfo mkvmerge mkvpropedit find nproc uchardet iconv wc bc du awk)
NPROC=$(nproc --all)																		# Set number of process
TERM_WIDTH=$(stty size | awk '{print $2}')													# Get terminal width
TERM_WIDTH_TRUNC=$(stty size | awk '{print $2}' | awk '{ print $1 - 8 }')					# Get terminal width truncate
TERM_WIDTH_PROGRESS_TRUNC=$(stty size | awk '{print $2}' | awk '{ print $1 - 32 }')			# Get terminal width truncate
FFMPEG_LOG_LVL="-hide_banner -loglevel panic -stats"										# FFmpeg log level

# Custom binary location
FFMPEG_CUSTOM_BIN=""																		# FFmpeg binary, enter location of bin, if variable empty use system bin
FFPROBE_CUSTOM_BIN=""																		# FFprobe binary, enter location of bin, if variable empty use system bin
SOX_CUSTOM_BIN=""																			# Sox binary, enter location of bin, if variable empty use system bin

# DVD rip variables
DVD_COMMAND_NEEDED=(dvdbackup dvdxchap lsdvd)
ISO_EXT_AVAILABLE="iso"
VOB_EXT_AVAILABLE="vob"

# Video variables
X265_LOG_LVL="log-level=error:"																# Hide x265 codec log
VIDEO_EXT_AVAILABLE="mkv|vp9|m4v|m2ts|avi|ts|mts|mpg|flv|mp4|mov|wmv|3gp|vob|mpeg|webm|ogv|bik"
NVENC="1"																					# Set number of video encoding in same time, the countdown starts at 0, so 0 is worth one encoding at a time (0=1;1=2...)
VAAPI_device="/dev/dri/renderD128"															# VAAPI device location

# Subtitle variables
SUBTI_COMMAND_NEEDED=(subp2tiff subptools tesseract wget)
SUBTI_EXT_AVAILABLE="srt|ssa|idx|sup"

# Audio variables
CUE_SPLIT_COMMAND_NEEDED=(flac mac cuetag shnsplit wvunpack)
AUDIO_EXT_AVAILABLE="8svx|aac|aif|aiff|ac3|amb|ape|aud|caf|dff|dsf|dts|flac|m4a|mka|mlp|mp2|mp3|mod|mqa|mpc|mpg|ogg|ops|opus|rmvb|shn|spx|w64|wav|wma|wv"
CUE_EXT_AVAILABLE="cue"
M3U_EXT_AVAILABLE="m3u|m3u8"
ExtractCover="0"																			# Extract cover, 0=extract cover from source and remove in output, 1=keep cover from source in output, empty=remove cover in output
RemoveM3U="1"																				# Remove m3u playlist, 0=no remove, 1=remove
PeakNormDB="1"																				# Peak db normalization option, this value is written as positive but is used in negative, e.g. 4 = -4

# Tag variables
TAG_COMMAND_NEEDED=(mac metaflac mid3v2 tracktag wvtag)
AUDIO_TAG_EXT_AVAILABLE="aif|aiff|ape|flac|m4a|mp3|ogg|opus|wv"

# Messages
MESS_ZERO_VIDEO_FILE_AUTH="   -/!\- No video file to process. Restart ffmes by selecting a file or in a directory containing it."
MESS_ZERO_AUDIO_FILE_AUTH="   -/!\- No audio file to process. Restart ffmes by selecting a file or in a directory containing it."
MESS_INVALID_ANSWER="   -/!\- Invalid answer, please try again."
MESS_ONE_VIDEO_FILE_AUTH="   -/!\- Only one video file at a time. Restart ffmes to select one video or in a directory containing one."
MESS_ONE_AUDIO_FILE_AUTH="   -/!\- Only one audio file at a time. Restart ffmes to select one audio or in a directory containing one."
MESS_BATCH_FILE_AUTH="   -/!\- Only more than one file at a time. Restart ffmes in a directory containing several files."
MESS_EXT_FILE_AUTH="   -/!\- Only one extention type at a time."

## SOURCE FILE VARIABLES
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

# Populate array
if test -n "$TESTARGUMENT"; then		# if argument
	if [[ $TESTARGUMENT == *"Video"* ]]; then
		LSTVIDEO+=("$ARGUMENT")
		mapfile -t LSTVIDEOEXT < <(echo "${LSTVIDEO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	elif [[ $TESTARGUMENT == *"Audio"* ]]; then
		LSTAUDIO+=("$ARGUMENT")
		mapfile -t LSTAUDIOEXT < <(echo "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	elif [[ $TESTARGUMENT == *"ISO"* ]]; then
		LSTISO+=("$ARGUMENT")
	fi
else									# if no argument -> batch
	# List source(s) video file(s) & number of differents extentions
	mapfile -t LSTVIDEO < <(find "$PWD" -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$VIDEO_EXT_AVAILABLE')$' 2>/dev/null | sort)
	mapfile -t LSTVIDEOEXT < <(echo "${LSTVIDEO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	# List source(s) audio file(s) & number of differents extentions
	mapfile -t LSTAUDIO < <(find . -maxdepth 5 -type f -regextype posix-egrep -iregex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	mapfile -t LSTAUDIOEXT < <(echo "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	# List source(s) ISO file(s)
	mapfile -t LSTISO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$ISO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
fi
# List source(s) audio file(s) that can be tagged
mapfile -t LSTAUDIOTAG < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$AUDIO_TAG_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
# List source(s) subtitle file(s)
mapfile -t LSTSUB < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$SUBTI_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
mapfile -t LSTSUBEXT < <(echo "${LSTSUB[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
# List source(s) CUE file(s)
mapfile -t LSTCUE < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$CUE_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
# List source(s) VOB file(s)
mapfile -t LSTVOB < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$VOB_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
# List source(s) M3U file(s)
mapfile -t LSTM3U < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$M3U_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

# Count uniq extension
NBVEXT=$(echo "${LSTVIDEOEXT[@]##*.}" | uniq -u | wc -w)
NBAEXT=$(echo "${LSTAUDIOEXT[@]##*.}" | uniq -u | wc -w)
}

## CHECK FILES & BIN
CheckCustomBin() {
if [[ -f "$FFMPEG_CUSTOM_BIN" ]]; then
	ffmpeg_bin="$FFMPEG_CUSTOM_BIN"
else
	ffmpeg_bin=$(which ffmpeg)
fi
if [[ -f "$FFPROBE_CUSTOM_BIN" ]]; then
	ffprobe_bin="$FFPROBE_CUSTOM_BIN"
else
	ffprobe_bin=$(which ffprobe)
fi
if [[ -f "$SOX_CUSTOM_BIN" ]]; then
	sox_bin="$SOX_CUSTOM_BIN"
else
	sox_bin=$(which sox)
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
if [[ "$command" = "cuetag" ]]; then
	command="$command (cuetools package)"
fi
if [[ "$command" = "mkvmerge" ]] || [[ "$command" = "mkvpropedit" ]]; then
	command="$command (mkvtoolnix package)"
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
		command_fail+=(" [!] $command")
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
		command_fail+=(" [!] $command")
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
		command_fail+=(" [!] $command")
		(( n++ )) || true
	fi
done
CheckCommandDisplay "DVD rip"
}
CheckSubtitleCommand() {
n=0;
for command in "${SUBTI_COMMAND_NEEDED[@]}"; do
	if hash "$command" &>/dev/null; then
		(( c++ )) || true
	else
		CheckCommandLabel
		command_fail+=(" [!] $command")
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
		command_fail+=(" [!] $command")
		(( n++ )) || true
	fi
done
CheckCommandDisplay "tag"
}
CheckCacheDirectory() {					# Check if cache directory exist
if [ ! -d "$FFMES_CACHE" ]; then
	mkdir /home/"$USER"/.cache/ffmes
fi
}
CheckFiles() {							# Promp a message to user with number of video, audio, sub to edit, and command not found
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
	echo "  -/!\- No file to process"
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
                          Default: 2
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
echo "   0 - DVD rip                                        |"
echo "   1 - video encoding                                 |-Video"
echo "   2 - copy stream to mkv with map option             |"
echo "  -----------------------------------------------------"
echo "  10 - view detailed video file informations          |"
echo "  11 - add audio stream or subtitle in video file     |-Video Tools"
echo "  12 - concatenate video files                        |"
echo "  13 - extract stream(s) of video file                |"
echo "  14 - cut video file                                 |"
echo "  15 - add audio stream with night normalization      |"
echo "  16 - split mkv by chapter                           |"
echo "  17 - change color of DVD subtitle (idx/sub)         |"
echo "  18 - convert DVD subtitle (idx/sub) to srt          |"
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
echo "  31 - view one audio file stats                      |"
echo "  32 - compare audio files stats                      |-Audio Tools"
echo "  33 - generate png image of audio spectrum           |"
echo "  34 - concatenate audio files                        |"
echo "  35 - cut audio file                                 |"
echo "  36 - audio file tester                              |"
echo "  37 - find untagged audio files                      |"
echo "  -----------------------------------------------------"
CheckFiles
echo "  -----------------------------------------------------"
}
Display_Separator() {					# Horizontal separator
echo "----------------------------------------------------------------------------------------------"
}
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
Display_End_Encoding_Message() {		# Summary of encoding
local total_files
local pass_files
local source_size
local target_size

pass_files="$1"
total_files="$2"
target_size="$3"
source_size="$4"

echo
if (( "${#filesPass[@]}" )); then
	Display_Separator
	echo " File(s) created:"
	Display_List_Truncate "${filesPass[@]}"
fi
if (( "${#filesReject[@]}" )); then
	Display_Separator
	echo " File(s) in error:"
	Display_List_Truncate "${filesReject[@]}"
fi
Display_Separator
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
Display_Separator
echo
}

# CALCULATION FUNCTIONS
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
rm "$FFMES_CACHE_STAT" &>/dev/null
rm "$FFMES_FFPROBE_CACHE_STAT_DETAILED" &>/dev/null
rm "$FFMES_FFMPEG_CACHE_STAT_DETAILED" &>/dev/null
rm "$FFMES_CACHE_MAP" &>/dev/null
rm "$FFMES_CACHE_INTEGRITY" &>/dev/null
rm "$FFMES_CACHE_UNTAGGED" &>/dev/null
rm "$FFMES_CACHE_TAG" &>/dev/null
rm "$LSDVD_CACHE" &>/dev/null
}
ffmesUpdate() {							# Option 99  	- ffmes update to lastest version (hidden option)
curl https://raw.githubusercontent.com/Jocker666z/ffmes/master/ffmes.sh > /home/"$USER"/.local/bin/ffmes && chmod +rx /home/"$USER"/.local/bin/ffmes
restart
}
TestVAAPI() {							# VAAPI device test
if [ -e "$VAAPI_device" ]; then
	GPUDECODE="-hwaccel vaapi -hwaccel_device /dev/dri/renderD128"
else
	GPUDECODE=""
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
			printf "${CL}✓ ${task} ${msg}\n"
			;;
		stop)
			kill "$_sp_pid" > /dev/null 2>&1
			printf "${CL}✓ ${task} ${msg}\n"
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
ProgressBar() {							# Audio encoding progress bar
_progress=$(( ( (($1 * 100) / $2) * 100 ) / 100 ))
_done=$(( (_progress * 4) / 10 ))
_left=$(( 40 - _done ))
_done=$(printf "%${_done}s")
_left=$(printf "%${_left}s")

echo -e "\r\e[0K File(s) in processing: [${3}]"
echo -e "\r\e[0K Progress: [${_done// /#}${_left// /-}] ${_progress}%"

if [[ "$_progress" = "100" ]]; then
	printf "\033[0A"
else
	printf "\033[2A"
fi
}
ProgressBarClean() {					# Audio encoding progress bar, vertical clean trick
tput el
tput cuu 1 && tput el
}

## VIDEO
FFmpeg_video_cmd() {					# FFmpeg video encoding command
# Local variables
local PERC
local total_source_files_size
local total_target_files_size
local START
local END
# Array
filesPass=()
filesSourcePass=()
filesReject=()

# Start time counter
START=$(date +%s)

# Disable the enter key
EnterKeyDisable

for files in "${LSTVIDEO[@]}"; do
	TagTitle="${files##*/}"

	if [ "$ENCODV" != "1" ]; then
		StartLoading "Test timestamp of: ${files##*/}"
		TimestampTest=$("$ffprobe_bin" -loglevel error -select_streams v:0 -show_entries packet=pts_time,flags -of csv=print_section=0 "$files" | awk -F',' '/K/ {print $1}' | tail -1)
		shopt -s nocasematch
		if [[ "${files##*.}" = "vob" || "$TimestampTest" = "N/A" ]]; then
			TimestampRegen="-fflags +genpts"
		fi
		shopt -u nocasematch
		StopLoading $?
	fi

	echo "FFmpeg processing: ${files##*/}"
	(
	"$ffmpeg_bin" $FFMPEG_LOG_LVL $TimestampRegen -analyzeduration 1G -probesize 1G $GPUDECODE -y -i "$files" \
			-threads 0 $vstream $videoconf $soundconf $subtitleconf -metadata title="${TagTitle%.*}" -max_muxing_queue_size 4096 \
			-f $container "${files%.*}".$videoformat.$extcont
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

# Check target if valid (size test), if valid mkv fix target stats, and and clean
for files in "${LSTVIDEO[@]}"; do
		if [[ $(stat --printf="%s" "${files%.*}"."$videoformat"."$extcont" 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
			# if mkv regenerate stats
			if [ "$extcont" = "mkv" ]; then
				mkvpropedit --add-track-statistics-tags "${files%.*}".$videoformat.$extcont >/dev/null 2>&1
			fi
			# populate array
			filesPass+=("${files%.*}"."$videoformat"."$extcont")
			filesSourcePass+=("$files")
		else																	# if file<30 KBytes rejected
			filesReject+=("${files%.*}"."$videoformat"."$extcont")
			rm "${files%.*}"."$videoformat"."$extcont" 2>/dev/null
		fi
done

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"								# Get elapsed time
total_source_files_size=$(Calc_Files_Size "${filesSourcePass[@]}")			# Source file(s) size
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")						# Target(s) size
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")						# Size difference between source and target

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "${#LSTVIDEO[@]}" "$total_target_files_size" "$total_source_files_size"
}
VideoSourceInfo() {						# Video source stats
# Local variables
local ColorsValue
local ColorSpace
local ColorPrimaries
local ColorTransfer
local HDRTest
local testChapter

# Grep info for in script use
INTERLACED=$(mediainfo --Inform="Video;%ScanType/String%" "${LSTVIDEO[0]}")
SWIDTH=$(mediainfo --Inform="Video;%Width%" "${LSTVIDEO[0]}")
SHEIGHT=$(mediainfo --Inform="Video;%Height%" "${LSTVIDEO[0]}")
SourceDurationSecond=$("$ffprobe_bin" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${LSTVIDEO[0]}")
VideoStreamSize=$(mediainfo --Inform="Video;%StreamSize%" "${LSTVIDEO[0]}" | awk '{ foo = $1 / 1024 / 1024 ; print foo " MB" }')
# HDR double check
HDRTest=$(mediainfo --Inform="Video;%HDR_Format/String%" "${LSTVIDEO[0]}")
if test -n "$HDRTest"; then
	HDR="1"
else				# adapted from https://video.stackexchange.com/a/28715
	mapfile -t ColorsValue < <("$ffprobe_bin" -show_streams -v error "${LSTVIDEO[0]}" | grep -E "^color_transfer|^color_space=|^color_primaries=" | head -3)
	for Color in "${ColorsValue[@]}"; do
		if [[ "$Color" = "color_space="* ]]; then
				ColorSpace="${Color##*=}"
		elif [[ "$Color" = "color_transfer="* ]]; then
				ColorTransfer="${Color##*=}"
		elif [[ "$Color" = "color_primaries="* ]]; then
				ColorPrimaries="${Color##*=}"
		fi
	done
	if [ "$ColorSpace" = "bt2020nc" ] && [ "$ColorTransfer" = "smpte2084" ] && [ "$ColorPrimaries" = "bt2020" ]; then 
			HDR="1"
	fi
fi

# Add all stats in temp.stat.info
"$ffprobe_bin" -analyzeduration 1G -probesize 1G -i "${LSTVIDEO[0]}" 2> "$FFMES_CACHE"/temp.stat.info

# Grep stream in stat.info
< "$FFMES_CACHE"/temp.stat.info grep Stream > "$FFMES_CACHE_STAT"

# Remove line with "Guessed Channel" (not used)
sed -i '/Guessed Channel/d' "$FFMES_CACHE_STAT"

# Count line = number of streams, and set variable associate
nbstream=$(wc -l < "$FFMES_CACHE_STAT")

# Add fps unit & video stream size
sed -i '1s/fps.*//' "$FFMES_CACHE_STAT"
sed -i '1s/$/fps, '"$VideoStreamSize"'/' "$FFMES_CACHE_STAT"

# Grep & add source duration
SourceDuration=$(< "$FFMES_CACHE"/temp.stat.info grep Duration)
sed -i '1 i\  '"$SourceDuration"'' "$FFMES_CACHE_STAT"

# Grep source size, chapter number && add file name, size, chapter number
testChapter=$(< "$FFMES_CACHE"/temp.stat.info grep -c "Chapter")
if [[ "$testChapter" -gt 1 ]]; then
	ChapterNumber=$(echo "$testChapter" | awk '{ print $1 - 1 }' | awk '{print $1, "chapters"}' | sed 's/^/, /')
fi
SourceSize=$(Calc_Files_Size "${LSTVIDEO[0]}")
sed -i '1 i\    '"${LSTVIDEO[0]##*/}, size: $SourceSize MB$ChapterNumber"'' "$FFMES_CACHE_STAT"

# Add title & complete formatting
sed -i '1 i\ Video file stats:' "$FFMES_CACHE_STAT"
sed -i '1 i\----------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"
sed -i -e '$a==============================================================================================' "$FFMES_CACHE_STAT"

# Clean temp file
rm "$FFMES_CACHE"/temp.stat.info &>/dev/null
}
VideoAudio_Source_Info() {				# Video source stats / Audio only with stream order (for audio night normalization)
# Add all stats in temp.stat.info
"$ffprobe_bin" -analyzeduration 1G -probesize 1G -i "${LSTVIDEO[0]}" 2> "$FFMES_CACHE"/temp.stat.info

# Grep stream in stat.info
< "$FFMES_CACHE"/temp.stat.info grep Audio > "$FFMES_CACHE_STAT"

# Add audio stream number
awk '{$0 = "    Audio Steam: "i++ " ->" OFS $0} 1' "$FFMES_CACHE_STAT" > "$FFMES_CACHE"/temp2.stat.info
mv "$FFMES_CACHE"/temp2.stat.info "$FFMES_CACHE_STAT"

# Remove line with "Guessed Channel" (not used)
sed -i '/Guessed Channel/d' "$FFMES_CACHE_STAT"

# Grep & add source duration
SourceDuration=$(< "$FFMES_CACHE"/temp.stat.info grep Duration)
sed -i '1 i\  '"$SourceDuration"'' "$FFMES_CACHE_STAT"

# Grep source size & add file name and size
SourceSize=$(Calc_Files_Size "${LSTVIDEO[0]}")
sed -i '1 i\    '"${LSTVIDEO[0]}, size: $SourceSize MB"'' "$FFMES_CACHE_STAT"

# Add title & complete formatting
sed -i '1 i\ Source file stats:' "$FFMES_CACHE_STAT"
sed -i '1 i\--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"
sed -i -e '$a--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"

# Clean temp file
rm "$FFMES_CACHE"/temp.stat.info &>/dev/null
rm "$FFMES_CACHE"/temp2.stat.info &>/dev/null
}
DVDRip() {								# Option 0  	- DVD Rip
    clear
    echo
    echo "  DVD rip"
    echo "  notes: * for DVD, launch ffmes in directory without ISO & VOB, if you have more than one drive, insert only one DVD."
    echo "         * for ISO, launch ffmes in directory without VOB (one iso)"
    echo "         * for VOB, launch ffmes in directory with VOB (in VIDEO_TS/)"
    echo
    echo "  ----------------------------------------------------------------------------------------"
	read -r -p "  Continue? [Y/n]:" q
	case $q in
			"N"|"n")
				Restart
			;;
			*)
				# Relaunch function if user move files after read message
				SetGlobalVariables
			;;
	esac

	# Assign input
	if [ "${#LSTVOB[@]}" -ge "1" ]; then
		DVD="./"
	elif [ "${#LSTISO[@]}" -eq "1" ]; then
		DVD="${LSTISO[0]}"
	else
		while true; do
			DVDINFO=$(setcd -i "$DVD_DEVICE")
			case "$DVDINFO" in
				*'Disc found'*)
					DVD="$DVD_DEVICE"
					break
					;;
				*'not ready'*)
					echo "  Please waiting drive not ready"
					sleep 3
					;;
				*)
					echo "  No DVD in drive, ffmes restart"
					sleep 3
					Restart
			esac
		done
	fi

	# Grep stat
	lsdvd -a -s "$DVD" 2>/dev/null | awk -F', AP:' '{print $1}' | awk -F', Subpictures' '{print $1}' | awk ' {gsub("Quantization: drc, ","");print}' | sed 's/^/    /' > "$LSDVD_CACHE"
	DVDtitle=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null | grep "DVD with title" | tail -1 | awk -F'"' '{print $2}')
	mapfile -t DVD_TITLES < <(lsdvd "$DVD" 2>/dev/null | grep Title | awk '{print $2}' |  grep -o '[[:digit:]]*') # Use for extract all title

	# Question
	if [ "${#LSTVOB[@]}" -ge "1" ]; then
		echo " ${#LSTVIDEO[@]}OB file(s) are been detected, choice one or more title to rip:"
	else
		echo " $DVDtitle DVD video have been detected, choice one or more title to rip:"
	fi
	echo
	cat "$LSDVD_CACHE"
	echo
	echo " [02 13] > Example of input format for select title 02 and 13"
	echo " [all]   > for rip all titles"
	echo " [q]     > for exit"
	echo -n " -> "
	while :
	do
	IFS=" " read -r -a qtitle
	echo
	case "${qtitle[0]}" in
		[0-9]*)
			break
		;;
		"all")
			qtitle=("${DVD_TITLES[@]}")
			break
		;;
		"q"|"Q")
			Display_Main_Menu
			break
		;;
		*)
			echo
			echo "$MESS_INVALID_ANSWER"
			echo
			;;
	esac
	done 

	if [ "${#LSTVOB[@]}" -ge "1" ]; then
		# DVD Title question
		read -r -e -p "  What is the name of the DVD?: " qdvd
		case $qdvd in
			"")
				echo
				echo "$MESS_INVALID_ANSWER"
				echo
			;;
			*)
				DVDtitle="$qdvd"
			;;
		esac
	fi

	for title in "${qtitle[@]}"; do
		RipFileName=$(echo "${DVDtitle}-${title}")

		# Get aspect ratio
		TitleParsed="${title##*0}"
		AspectRatio=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null | grep "The aspect ratio of title set $TitleParsed" | tail -1 | awk '{print $NF}')
		if test -z "$AspectRatio"; then			# if aspect ratio empty, get main feature aspect
			AspectRatio=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null | grep "The aspect ratio of the main feature is" | tail -1 | awk '{print $NF}')
		fi

		# Extract chapters
		StartLoading "Extract chapters - $DVDtitle - title $title"
		dvdxchap -t "$title" "$DVD" 2>/dev/null > "$RipFileName".chapters
		StopLoading $?

		# Extract vob
		StartLoading "Extract VOB - $DVDtitle - title $title"
		dvdbackup -p -t "$title" -i "$DVD" -n "$RipFileName" >/dev/null 2>&1
		StopLoading $?

		# Populate array with VOB
		mapfile -t LSTVOB < <(find ./"$RipFileName" -maxdepth 3 -type f -regextype posix-egrep -iregex '.*\.('$VOB_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

		# Concatenate
		StartLoading "Concatenate VOB - $DVDtitle - title $title"
		cat -- "${LSTVOB[@]}" > "$RipFileName".VOB 2> /dev/null
		StopLoading $?

		# Remove data stream, fix DAR, add chapters, and change container
		StartLoading "Make clean mkv - $DVDtitle - title $title"
		# Fix pcm_dvd is present
		PCM=$("$ffprobe_bin" -analyzeduration 1G -probesize 1G -v error -show_entries stream=codec_name -print_format csv=p=0 "$RipFileName".VOB | grep pcm_dvd)
		if test -n "$PCM"; then			# pcm_dvd audio track trick
			pcm_dvd="-c:a pcm_s16le"
		fi
		# FFmpeg - clean mkv
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -fflags +genpts -analyzeduration 1G -probesize 1G -i "$RipFileName".VOB -map 0:v -map 0:a? -map 0:s? -c copy $pcm_dvd -aspect $AspectRatio "$RipFileName".mkv 2>/dev/null
		# mkvmerge - add chapters
		mkvmerge "$RipFileName".mkv --chapters "$RipFileName".chapters -o "$RipFileName"-chapters.mkv >/dev/null 2>&1
		StopLoading $?

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
		echo
		echo " ${#LSTVIDEO[@]} files are been detected:"
		printf '  %s\n' "${LSTVIDEO[@]}"
		echo
		read -r -p " Would you like encode it? [y/N]:" q
		case $q in
			"Y"|"y")

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
CustomInfoChoice() {					# Option 1  	- Summary of configuration
	clear
    cat "$FFMES_CACHE_STAT"
	echo " Target configuration:"
	echo "  Video stream: $chvidstream"
	if [ "$ENCODV" = "1" ]; then
		echo "   * Crop: $cropresult"
		echo "   * Rotation: $chrotation"
		if test -n "$HDR"; then						# display only if HDR source
			echo "   * HDR to SDR: $chsdr2hdr"
		fi
		echo "   * Resolution: $chwidth"
		echo "   * Deinterlace: $chdes"
		echo "   * Frame rate: $chfps"
		echo "   * Codec: $chvcodec $chpreset $chtune $chprofile"
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
	echo "--------------------------------------------------------------------------------------------------"
	echo
	}
CustomVideoEncod() {					# Option 1  	- Conf video
# Local variables
local nbvfilter
local cropresult

CustomInfoChoice
echo " Encoding or copying the video stream:"			# Video stream choice, encoding or copy
echo
echo "  [e] > for encode"
echo " *[↵] > for copy"
echo "  [q] > for exit"
read -r -e -p "-> " qv
if [ "$qv" = "q" ]; then
	Restart

elif [ "$qv" = "e" ]; then								# Start edit video

	ENCODV="1"	# Set video encoding

	# Crop
	CustomInfoChoice
	echo " Crop the video?"
	echo " Note: Auto detection is not 100% reliable, a visual check of the video will guarantee it."
	echo
	echo "  [y] > for yes in auto detection mode"
	echo "  [m] > for yes in manual mode (knowing what you are doing is required)"
	echo " *[↵] > for no change"
	echo "  [q] > for exit"
	read -r -e -p "-> " yn
	case $yn in
		"y"|"Y")
			StartLoading "Crop auto detection in progress"
			cropresult=$("$ffmpeg_bin" -i "${LSTVIDEO[0]}" -ss 00:03:30 -t 00:04:30 -vf cropdetect -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1 2> /dev/null)  # grep auto crop with ffmpeg
			StopLoading $?
			vfilter="-vf $cropresult"
			nbvfilter=$((nbvfilter+1))
		;;
		"m"|"M")
			echo
			echo " Enter desired crop: "
			echo
			echo " [crop=688:448:18:56] > Example of input format"
			echo " [c]                  > for no change"
			echo " [q]                  > for exit"
			while :
			do
			read -r -e -p "-> " cropresult
			case $cropresult in
				crop*)
					vfilter="-vf $cropresult"
					nbvfilter=$((nbvfilter+1))
					break
				;;
				"c"|"C")
					cropresult="No change"
					break
				;;
				"q"|"Q")
					Restart
					break
				;;
					*)
					echo
					echo "$MESS_INVALID_ANSWER"
					echo
				;;
			esac
			done
		;;
		"q"|"Q")
			Restart
		;;
		*)
			cropresult="No change"
		;;
	esac

	# Rotation
	CustomInfoChoice
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
			nbvfilter=$((nbvfilter+1))
			if [ "$nbvfilter" -gt 1 ] ; then
				vfilter+=",transpose=$ynrotat"
			else
				vfilter="-vf transpose=$ynrotat"
			fi

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
			echo "$MESS_INVALID_ANSWER"
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

	# HDR / SDR
	if test -n "$HDR"; then						# display only if HDR source
	CustomInfoChoice
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

	# Resolution
	CustomInfoChoice
	echo " Resolution changed:"
	echo " Note: If crop is applied is not recommended to combine the two."
	echo
	echo "  [y] > for yes"
	echo " *[↵] > for no change"
	echo "  [q] > for exit"
	read -r -e -p "-> " yn
	case $yn in
		"y"|"Y")
			CustomInfoChoice
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
				1) ConfVideoResolution 640; break;;
				2) ConfVideoResolution 720; break;;
				3) ConfVideoResolution 768; break;;
				4) ConfVideoResolution 1024; break;;
				5) ConfVideoResolution 1280; break;;
				6) ConfVideoResolution 1680; break;;
				7) ConfVideoResolution 1920; break;;
				8) ConfVideoResolution 2048; break;;
				9) ConfVideoResolution 2560; break;;
				10) ConfVideoResolution 3840; break;;
				11) ConfVideoResolution 4096; break;;
				12) ConfVideoResolution 5120; break;;
				13) ConfVideoResolution 7680; break;;
				14) ConfVideoResolution 8192; break;;
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
					echo "$MESS_INVALID_ANSWER"
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

	# Deinterlace
	CustomInfoChoice
	if [ "$INTERLACED" = "Interlaced" ]; then
		echo " Video SEEMS interlaced, you want deinterlace:"
	else
		echo " Video seems not interlaced, you want force deinterlace:"
	fi
	echo " Note: the auto detection is not 100% reliable, a visual check of the video will guarantee it."
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
				vfilter+=",yadif"
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

	# Frame rate
	CustomInfoChoice
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

	# Codec choice
	CustomInfoChoice
	echo " Choice the video codec to use:"
	echo
	echo "  [x264]  > for libx264 codec"
	echo " *[x265]  > for libx265 codec"
	echo "  [mpeg4] > for xvid codec"
	echo "  [q]     > for exit"
	read -r -e -p "-> " yn
	case $yn in
		"x264")
			codec="libx264 -x264-params colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off -pix_fmt yuv420p"
			chvcodec="H264"
			Confx264_5
		;;
		"x265")
			codec="libx265"
			chvcodec="HEVC"
			Confx264_5
		;;
		"mpeg4")
			codec="mpeg4 -vtag xvid"
			chvcodec="XVID"
			Confmpeg4
		;;
		"q"|"Q")
			Restart
		;;
		*)
			codec="libx265"
			chvcodec="HEVC"
			Confx264_5
		;;
	esac

	# Set video configuration variable
	vcodec="$codec"
	filevcodec="$chvcodec"
	videoconf="$framerate $vfilter -vcodec $vcodec $preset $profile $tune $vkb"

else                                                                    # No video edit

	# Set video configuration variable
	chvidstream="Copy"
	filevcodec="VCOPY"
	videoconf="-c:v copy"                                            # Set video variable

fi

}
CustomAudioEncod() {					# Option 1  	- Conf audio
CustomInfoChoice
echo " Encoding or copying the audio stream(s):"
echo
echo "  [e] > for encode stream(s)"
echo " *[c] > for copy stream(s)"
echo "  [r] > for remove stream(s)"
echo "  [q] > for exit"
read -r -e -p "-> " qa
if [ "$qa" = "q" ]; then
	Restart
elif [ "$qa" = "e" ]; then

	ENCODA="1"			# If audio encoding

	# Codec choice
	CustomInfoChoice
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
	echo " *[opus] >   | libopus   |   7.1>   |"
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
	soundconf="$afilter -acodec $codeca $akb $asamplerate $confchan"

elif [ "$qa" = "r" ]; then
	chsoundstream="Remove"							# Remove audio stream
	fileacodec="AREMOVE"
	soundconf=""

else
	chsoundstream="Copy"							# No audio change
	fileacodec="ACOPY"
	soundconf="-acodec copy"
fi
}
CustomVideoStream() {					# Option 1,2	- Conf stream selection
# Local variables
local rpstreamch
local rpstreamch_parsed
# Array
VINDEX=()
VCODECTYPE=()
VCODECTYPE1=()
stream=()

if [ "$reps" -le 1 ] ; then				# Display summary target if in profile 0, 1
	CustomInfoChoice
else 									# Display streams stats if no in profile 1 (already make by CustomInfoChoice)
	clear
	echo
	cat "$FFMES_CACHE_STAT"
	echo
fi

if [ "$nbstream" -gt 2 ] ; then				# If $nbstream > 2 = map question

	# Choice Stream
	echo " Select video, audio(s) & subtitle(s) streams, or leave for keep unchanged:"
	echo " Notes: * The order of the streams you specify will be the order of in final file."
	echo
	echo "  [0 3 1]     > Example of input format for select stream"
	echo " *[enter]     > for no change"
	echo "  [q]         > for exit"
	while true; do
		read -r -e -p "-> " rpstreamch
		rpstreamch_parsed="${rpstreamch// /}"					# For test
		if [ -z "$rpstreamch" ]; then							# If -map 0
			rpstreamch_parsed="all"
			break
		elif [[ "$rpstreamch_parsed" == "q" ]]; then			# Quit
			Restart
		elif ! [[ "$rpstreamch_parsed" =~ ^-?[0-9]+$ ]]; then	# Not integer retry
			echo "   -/!\- Map option must be an integer."
		elif [[ "$rpstreamch_parsed" =~ ^-?[0-9]+$ ]]; then		# If valid integer continue
			break
		fi
	done
else															# If $nbstream <= 2
	rpstreamch_parsed="all"
	if [ "$reps" -le 1 ]; then									# Refresh summary $nbstream <= 2
			CustomInfoChoice
	fi
	if [ "$extcont" = mkv ]; then
		subtitleconf="-codec:s copy"							# mkv subtitle variable
	elif [ "$extcont" = mp4 ]; then
		subtitleconf="-codec:s mov_text"						# mp4 subtitle variable
	else
		stream=""
	fi
fi

# Get stream info
case "$rpstreamch_parsed" in
	"all")
		mapfile -t VINDEX < <("$ffprobe_bin" -analyzeduration 1G -probesize 1G -v panic -show_entries stream=index -print_format csv=p=0 "${LSTVIDEO[0]}" | awk 'NF')
		mapfile -t VCODECTYPE < <("$ffprobe_bin" -analyzeduration 1G -probesize 1G -v panic -show_entries stream=codec_type -print_format csv=p=0 "${LSTVIDEO[0]}" | awk 'NF')
		;;
	*)
		IFS=" " read -r -a VINDEX <<< "$rpstreamch"
		# Keep codec used
		mapfile -t VCODECTYPE1 < <("$ffprobe_bin" -analyzeduration 1G -probesize 1G -v panic -show_entries stream=codec_type -print_format csv=p=0 "${LSTVIDEO[0]}" | awk 'NF')
		for i in "${VINDEX[@]}"; do
			VCODECTYPE+=("${VCODECTYPE1[$i]}")
		done
		;;
esac

# Get -map arguments
for i in ${!VINDEX[*]}; do
	case "${VCODECTYPE[i]}" in
		# Video Stream
		video)
			stream+=("-map 0:${VINDEX[i]}")
			;;
		
		# Audio Stream
		audio)
			if ! [[ "$chsoundstream" = "Remove" ]]; then
				stream+=("-map 0:${VINDEX[i]}")
			fi
			;;

		# Subtitle Stream
		subtitle)
			stream+=("-map 0:${VINDEX[i]}")
			if test -z "$subtitleconf"; then
				if [ "$extcont" = mkv ]; then
					subtitleconf="-c:s copy"										# mkv subtitle variable
				elif [ "$extcont" = mp4 ]; then
					subtitleconf="-c:s mov_text"									# mp4 subtitle variable
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
if [ "$reps" -le 1 ]; then											# Refresh summary $nbstream <= 2
		CustomInfoChoice
fi
}
CustomVideoContainer() {				# Option 1  	- Conf container mkv/mp4
	CustomInfoChoice
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
	if [ "$nbstream" -lt 3 ] ; then
		# Reset display (last question before encoding)
		CustomInfoChoice
	fi
	}
ConfVideoResolution() {					# Option 1  	- Conf change Resolution 
# Local variables
local RATIO
local WIDTH

WIDTH="$1"

# Ratio calculation
RATIO=$(bc -l <<< "$SWIDTH / $WIDTH")

# Height calculation, display decimal only if not integer
HEIGHT=$(bc -l <<< "$SHEIGHT / $RATIO" | sed 's!\.0*$!!')

# Increment filter counter
nbvfilter=$((nbvfilter+1))
# Scale filter
if ! [[ "$HEIGHT" =~ ^[0-9]+$ ]] ; then			# In not integer
	if [ "$nbvfilter" -gt 1 ] ; then
		vfilter+=",scale=$WIDTH:-2"
	else
		vfilter="-vf scale=$WIDTH:-2"
	fi
else
	if [ "$nbvfilter" -gt 1 ] ; then
		vfilter+=",scale=$WIDTH:-1"
	else
		vfilter="-vf scale=$WIDTH:-1"
	fi
fi
# Displayed width x height
chwidth="${WIDTH}x${HEIGHT%.*}"
}
Confmpeg4() {							# Option 1  	- Conf Xvid 
CustomInfoChoice
echo " Choose a number OR enter the desired bitrate:"
echo
Display_Separator
echo " [1200k] -> Example of input format for desired bitrate"
echo
echo "  [1] > for qscale 1   |"
echo "  [2] > for qscale 5   |HD"
echo " *[3] > for qscale 10  |"
echo "  [4] > for qscale 15  -"
echo "  [5] > for qscale 20  |"
echo "  [6] > for qscale 15  |SD"
echo "  [7] > for qscale 30  |"
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
else
	vkb="-q:v 10"
fi
}
Confx264_5() {							# Option 1  	- Conf x264/x265
# Local variables
local video_stream_kb
local video_stream_size

# Preset x264/x265
CustomInfoChoice
echo " Choose the preset:"
echo
echo "  ----------------------------------------------> Encoding Speed"
echo "  veryfast - faster - fast -  medium - slow* - slower - veryslow"
echo "  -----------------------------------------------------> Quality"
read -r -e -p "-> " reppreset
if test -n "$reppreset"; then
	preset="-preset $reppreset"
	chpreset="$reppreset"
else
	preset="-preset medium"
	chpreset="slow"
fi

# Tune x264/x265
CustomInfoChoice
if [ "$chvcodec" = "H264" ]; then
	echo " Choose tune:"
	echo " Note: This settings influences the final rendering of the image, and speed of encoding."
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
	read -r -e -p " -> " reptune
	if [ "$reptune" = "film" ]; then
		tune="-tune $reptune"
		chtune="$reptune"
	elif [ "$reptune" = "animation" ]; then
		tune="-tune $reptune"
		chtune="$reptune"
	elif [ "$reptune" = "grain" ]; then
		tune="-tune $reptune"
		chtune="$reptune"
	elif [ "$reptune" = "stillimage" ]; then
		tune="-tune $reptune"
		chtune="$reptune"
	elif [ "$reptune" = "fastdecode" ]; then
		tune="-tune $reptune"
		chtune="$reptune"
	elif [ "$reptune" = "zerolatency" ]; then
		tune="-tune $reptune"
		chtune="$reptune"
	elif [ "$reptune" = "cfilm" ]; then
		tune="-fast-pskip 0 -bf 10 -b_strategy 2 -me_method umh -me_range 24 -trellis 2 -refs 4 -subq 9"
		chtune="ffmes-film"
	elif [ "$reptune" = "canimation" ]; then
		tune="-fast-pskip 0 -bf 10 -b_strategy 2 -me_method umh -me_range 24 -trellis 2 -refs 4 -subq 9 -deblock -2:-2 -psy-rd 1.0:0.25 -aq 0.5 -qcomp 0.8"
		chtune="ffmes-animation"
	elif [ "$reptune" = "no" ]; then
		tune=""
		chtune=""
	else
		tune="-fast-pskip 0 -bf 10 -b_strategy 2 -me_method umh -me_range 24 -trellis 2 -refs 4 -subq 9"
		chtune="ffmes-film"
	fi
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
	echo "  [zerolatency] > for fast encoding and low-latency streaming "
	read -r -e -p "-> " reptune
	if [ "$reptune" = "psnr" ]; then
		tune="-tune $reptune"
		chtune="$reptune"
	elif [ "$reptune" = "ssim" ]; then
		tune="-tune $reptune"
		chtune="$reptune"
	elif [ "$reptune" = "grain" ]; then
		tune="-tune $reptune"
		chtune="$reptune"
	elif [ "$reptune" = "fastdecode" ]; then
		tune="-tune $reptune"
		chtune="$reptune"
	elif [ "$reptune" = "zerolatency" ]; then
		tune="-tune $reptune"
		chtune="$reptune"
	elif [ "$reptune" = "no" ]; then
		tune=""
		chtune="$reptune tuning"
	else
		tune=""
		chtune="default tuning"
	fi
fi

# Profile x264/x265
CustomInfoChoice
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
	read -r -e -p "-> " repprofile
	if [ "$repprofile" = "1" ]; then
		profile="-profile:v baseline -level 3.0"
		chprofile="Baseline 3.0"
	elif [ "$repprofile" = "2" ]; then
		profile="-profile:v baseline -level 3.1"
		chprofile="Baseline 3.1"
	elif [ "$repprofile" = "3" ]; then
		profile="-profile:v main -level 4.0"
		chprofile="Baseline 4.0"
	elif [ "$repprofile" = "4" ]; then
		profile="-profile:v high -level 4.0"
		chprofile="High 4.0"
	elif [ "$repprofile" = "5" ]; then
		profile="-profile:v high -level 4.1"
		chprofile="High 4.1"
	elif [ "$repprofile" = "6" ]; then
		profile="-profile:v high -level 4.2"
		chprofile="High 4.2"
	elif [ "$repprofile" = "7" ]; then
		profile="-profile:v high -level 5.0"
		chprofile="High 5.0"
	elif [ "$repprofile" = "8" ]; then
		profile="-profile:v high -level 5.1"
		chprofile="High 5.1"
	elif [ "$repprofile" = "9" ]; then
		profile="-profile:v high -level 5.2"
		chprofile="High 5.2"
	else
		profile="-profile:v high -level 4.1"
		chprofile="High 4.1"
	fi
elif [ "$chvcodec" = "HEVC" ]; then
	echo " Choose a profile or make your profile manually:"
	echo " Notes: * For bit and chroma settings, if the source is below the parameters, FFmpeg will not replace them but will be at the same level."
	echo "        * The level (lvl) parameter must be chosen judiciously according to the bit rate of the source file and the result you expect."
	echo "        * The choice of the profile affects the player compatibility of the result."
	echo
	echo
	Display_Separator
	echo " Manually options (expert):"
	echo "  * 8bit profiles: main, main-intra, main444-8, main444-intra"
	echo "  * 10bit profiles: main10, main10-intra, main422-10, main422-10-intra, main444-10, main444-10-intra"
	echo "  * 12bit profiles: main12, main12-intra, main422-12, main422-12-intra, main444-12, main444-12-intra"
	echo "  * Level: 1, 2, 2.1, 3.1, 4, 4.1, 5, 5.1, 5.2, 6, 6.1, 6.2"
	echo "  * High level: high-tier=1"
	echo "  * No high level: no-high"
	echo " [-profile:v main -x265-params level=3.1:no-high-tier] -> Example of input format for manually profile"
	echo
	Display_Separator
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
	read -r -e -p "-> " repprofile
	if echo "$repprofile" | grep -q 'profil'; then
			profile="$repprofile"
			chprofile="$repprofile"
	elif [ "$repprofile" = "1" ]; then
			profile="-profile:v main -x265-params ${X265_LOG_LVL}level=3.1 -pix_fmt yuv420p"
			chprofile="3.1 - 8 bit - 4:2:0"
	elif [ "$repprofile" = "2" ]; then
			profile="-profile:v main -x265-params ${X265_LOG_LVL}level=4.1 -pix_fmt yuv420p"
			chprofile="4.1 - 8 bit - 4:2:0"
	elif [ "$repprofile" = "3" ]; then
			profile="-profile:v main -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1 -pix_fmt yuv420p"
			chprofile="4.1 - 8 bit - 4:2:0"
	elif [ "$repprofile" = "4" ]; then
			profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1 -pix_fmt yuv420p12le"
			chprofile="4.1 - 12 bit - 4:4:4"
	elif [ "$repprofile" = "5" ]; then
			profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1:hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,10) -pix_fmt yuv420p12le"
			chprofile="4.1 - 12 bit - 4:4:4 - HDR"
	elif [ "$repprofile" = "6" ]; then
			profile="-profile:v main444-12-intra -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1 -pix_fmt yuv420p12le"
			chprofile="4.1 - 12 bit - 4:4:4 - intra"
	elif [ "$repprofile" = "7" ]; then
			profile="-profile:v main -x265-params ${X265_LOG_LVL}level=5.2:high-tier=1 -pix_fmt yuv420p"
			chprofile="5.2 - 8 bit - 4:2:0"
	elif [ "$repprofile" = "8" ]; then
			profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=5.2:high-tier=1 -pix_fmt yuv420p12le"
			chprofile="5.2 - 12 bit - 4:4:4"
	elif [ "$repprofile" = "9" ]; then
			profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=5.2:high-tier=1:hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,10) -pix_fmt yuv420p12le"
			chprofile="5.2 - 12 bit - 4:4:4 - HDR"
	elif [ "$repprofile" = "10" ]; then
			profile="-profile:v main444-12-intra -x265-params ${X265_LOG_LVL}level=5.2:high-tier=1 -pix_fmt yuv420p12le"
			chprofile="5.2 - 12 bit - 4:4:4 - intra"
	elif [ "$repprofile" = "11" ]; then
			profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=6.2:high-tier=1 -pix_fmt yuv420p12le"
			chprofile="6.2 - 12 bit - 4:4:4"
	elif [ "$repprofile" = "12" ]; then
			profile="-profile:v main444-12 -x265-params ${X265_LOG_LVL}level=6.2:high-tier=1:hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,10) -pix_fmt yuv420p12le"
			chprofile="6.2 - 12 bit - 4:4:4 - HDR"
	elif [ "$repprofile" = "13" ]; then
			profile="-profile:v main444-12-intra -x265-params ${X265_LOG_LVL}level=6.2:high-tier=1 -pix_fmt yuv420p12le"
			chprofile="6.2 - 12 bit - 4:4:4 - intra"
	else
			profile="-profile:v main -x265-params ${X265_LOG_LVL}level=4.1:high-tier=1 -pix_fmt yuv420p"
			chprofile="High 4.1 - 8 bit - 4:2:0"
	fi
fi

# Bitrate x264/x265
CustomInfoChoice
echo " Choose a CRF number, video strem size or enter the desired bitrate:"
echo " Note: This settings influences size and quality, crf is a better choise in 90% of cases."
echo
Display_Separator
echo " [1200k]     Example of input for cbr desired bitrate in kb"
echo " [1500m]     Example of input for aproximative total size of video stream in mb (not recommended in batch)"
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
	video_stream_kb=$(bc <<< "scale=0; ($video_stream_size * 8192)/$SourceDurationSecond")
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
else
	vkb="-crf 20"
fi
}
Mkvmerge() {							# Option 11 	- Add audio stream or subtitle in video file
# Local variables
local MERGE_LSTAUDIO
local MERGE_LSTSUB
# Array
filesPass=()
filesReject=()

# Keep extention with wildcard for current audio and sub
mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
if [ "${#LSTAUDIO[@]}" -gt 0 ] ; then
	MERGE_LSTAUDIO=$(printf '*.%s ' "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
fi
if [ "${#LSTSUB[@]}" -gt 0 ] ; then
	MERGE_LSTSUB=$(printf '*.%s ' "${LSTSUB[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
fi

# Summary message
clear
echo
cat "$FFMES_CACHE_STAT"
echo
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

START=$(date +%s)						# Start time counter

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


# Check Target if valid (size test)
if [[ $(stat --printf="%s" "${LSTVIDEO%.*}"."$videoformat".mkv 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
	filesPass+=("${LSTVIDEO%.*}"."$videoformat".mkv)
else																	# if file<30 KBytes rejected
	filesReject+=("${LSTVIDEO%.*}"."$videoformat".mkv)
fi

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"								# Get elapsed time
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")						# Target(s) size

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" ""
}
ConcatenateVideo() {					# Option 12 	- Concatenate video
# Local variables
local filename_id
# Array
filesPass=()
filesReject=()

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

	# Add date id to created filename, prevent infinite loop of ffmpeg is target=source filename
	filename_id="Concatenate_Output-$(date +%s).${LSTVIDEO[0]##*.}"
	
	# Concatenate
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -f concat -safe 0 -i <(for f in *."${LSTVIDEO[0]##*.}"; do echo "file '$PWD/$f'"; done) \
		-c copy "$filename_id"

	# End time counter
	END=$(date +%s)

	# Check Target if valid (size test)
	if [ "$(stat --printf="%s" "$filename_id")" -gt 30720 ]; then		# if file>30 KBytes accepted
		filesPass+=( "$filename_id" )
	else																	# if file<30 KBytes rejected
		filesReject+=( "$filename_id" )
	fi

	# Make statistics of processed files
	Calc_Elapsed_Time "$START" "$END"								# Get elapsed time
	total_source_files_size=$(Calc_Files_Size "${LSTVIDEO[@]}")					# Source file(s) size
	total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")						# Target(s) size
	PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")						# Size difference between source and target

	# End encoding messages "pass_files" "total_files" "target_size" "source_size"
	Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" "$total_source_files_size"

	# Next encoding question
	read -r -p "You want encoding concatenating video? [y/N]:" qarm
		case $qarm in
			"Y"|"y")
				LSTVIDEO=("Concatenate-Output.${LSTVIDEO[0]##*.}")
			;;
			*)
				Restart
			;;
		esac
fi
}
ExtractPartVideo() {					# Option 13 	- Extract stream
# Local variables
local rpstreamch_parsed
# Array
VINDEX=()
VCODECNAME=()
VCODECNAME1=()
filesPass=()
filesReject=()

clear
echo
cat "$FFMES_CACHE_STAT"

echo " Select Video, audio(s) &/or subtitle(s) streams, one or severale:"
echo " Note: extracted files saved in source directory."
echo
echo "  [all]   > Input format for extract all streams"
echo "  [0 2 5] > Example of input format for select streams"
echo "  [q]     > for exit"
while :
do
read -r -e -p "-> " rpstreamch
rpstreamch_parsed="${rpstreamch// /}"
case "$rpstreamch_parsed" in
	"all")
		mapfile -t VINDEX < <("$ffprobe_bin" -analyzeduration 1G -probesize 1G -v error -show_entries stream=index -print_format csv=p=0 "${LSTVIDEO[0]}" | awk 'NF')
		mapfile -t VCODECNAME < <("$ffprobe_bin" -analyzeduration 1G -probesize 1G -v error -show_entries stream=codec_name -print_format csv=p=0 "${LSTVIDEO[0]}" | awk 'NF')
		break
		;;
	"q"|"Q")
		Restart
		break
		;;
	*)
		IFS=" " read -r -a VINDEX <<< "$rpstreamch"
		# Keep codec used
		mapfile -t VCODECNAME1 < <("$ffprobe_bin" -analyzeduration 1G -probesize 1G -v error -show_entries stream=codec_name -print_format csv=p=0 "${LSTVIDEO[0]}" | awk 'NF')
		for i in "${VINDEX[@]}"; do
			VCODECNAME+=("${VCODECNAME1[$i]}")
		done
		break
		;;
esac
done 

# Start time counter
START=$(date +%s)							# Start time counter
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

			subrip) FILE_EXT=srt ;;
			ass) FILE_EXT=ass ;;
			hdmv_pgs_subtitle) FILE_EXT=sup ;;
			dvd_subtitle)
				MKVEXTRACT="1"
				FILE_EXT=idx
				;;
			esac

			#StartLoading "" "${files%.*}-Stream-${VINDEX[i]}.$FILE_EXT"
			if [ "$MKVEXTRACT" = "1" ]; then
				mkvextract "$files" tracks "${VINDEX[i]}":"${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT"
			elif [ "$MPEG2EXTRACT" = "1" ]; then
				"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -fflags +genpts -analyzeduration 1G -probesize 1G -i "$files" \
					-c copy -map 0:"${VINDEX[i]}" "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT"
			elif [ "$DVDPCMEXTRACT" = "1" ]; then
				"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "$files" -map 0:"${VINDEX[i]}" -acodec pcm_s16le -ar 48000 \
					"${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT"
			else
				"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "$files" -c copy -map 0:"${VINDEX[i]}" "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT"
			fi
			#StopLoading $?

			# Check Target if valid (size test) and clean
			if [[ $(stat --printf="%s" "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
				filesPass+=("${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT")
			else																	# if file<30 KBytes rejected
				filesReject+=("${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT")
				rm "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" 2>/dev/null
			fi

		done
done

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"								# Get elapsed time
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")						# Target(s) size

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" ""
}
CutVideo() {							# Option 14 	- Cut video
# Local variables
local qcut
local CutStart
local CutEnd
# Array
filesPass=()
filesReject=()

clear
echo
cat "$FFMES_CACHE_STAT"

echo " Enter duration of cut:"
echo " Notes: * for hours :   HOURS:MM:SS.MICROSECONDS"
echo "        * for minutes : MM:SS.MICROSECONDS"
echo "        * for seconds : SS.MICROSECONDS"
echo "        * microseconds is optional, you can not indicate them"
echo
Display_Separator
echo " Examples of input:"
echo "  [s.20]       -> remove video after 20 second"
echo "  [e.01:11:20] -> remove video before 1 hour 11 minutes 20 second"
echo
Display_Separator
echo
echo "  [s.time]      > for remove end"
echo "  [e.time]      > for remove start"
echo "  [t.time.time] > for remove start and end"
echo "  [q]           > for exit"
while :
do
read -r -e -p "-> " qcut0
case $qcut0 in
	s.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')												# Replace [.] by [ ] in variable
		CutStart=$(< "$FFMES_CACHE_STAT" grep Duration | awk '{print $4;}' | sed s'/.$//')
		CutEnd=$(echo "$qcut" | awk '{print $2;}')
		break
	;;
	e.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')
		CutStart=$(echo "$qcut" | awk '{print $2;}')
		CutEnd=$(< "$FFMES_CACHE_STAT" grep Duration | awk '{print $2;}' | sed s'/.$//')
		break
	;;
	t.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')
		CutStart=$(echo "$qcut" | awk '{print $2;}')
		CutEnd=$(echo "$qcut" | awk '{print $3;}')
		break
	;;
	"q"|"Q")
		Restart
		break
	;;
		*)
			echo
			echo "$MESS_INVALID_ANSWER"
			echo
		;;
	esac
	done

# Start time counter
START=$(date +%s)

# Cut
echo
echo "FFmpeg processing: ${LSTVIDEO[0]%.*}.cut.${LSTVIDEO[0]##*.}"
"$ffmpeg_bin" $FFMPEG_LOG_LVL -analyzeduration 1G -probesize 1G -y -i "${LSTVIDEO[0]}" -ss "$CutStart" -to "$CutEnd" \
	-c copy -map 0 -map_metadata 0 "${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}"

# End time counter
END=$(date +%s)

# Check Target if valid (size test)
if [ "$(stat --printf="%s" "${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}")" -gt 30720 ]; then		# if file>30 KBytes accepted
	filesPass+=("${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}")
else																							# if file<30 KBytes rejected
	filesReject+=("${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}")
fi

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"								# Get elapsed time
total_source_files_size=$(Calc_Files_Size "${LSTVIDEO[@]}")					# Source file(s) size
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")						# Target(s) size
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")						# Size difference between source and target

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" "$total_source_files_size"
}
AddAudioNightNorm() {					# Option 15 	- Add audio stream with night normalization in opus/stereo/320kb
# Array
VINDEX=()
filesPass=()
filesReject=()

clear
echo
cat "$FFMES_CACHE_STAT"

echo " Select one audio stream (first in the line):"
echo " Note: The selected audio will be encoded in a new stream in opus/stereo/320kb with night normalization."
echo "       To summarize the amplitude of sound between heavy and weak sounds will decrease."
echo
echo "  [0 2 5] > Example of input format for select streams"
echo "  [q]     > for exit"
while :
do
read -r -e -p "-> " rpstreamch
case $rpstreamch in

	[0-9])
		IFS=" " read -r -a VINDEX <<< "$rpstreamch"
		break
	;;
	"q"|"Q")
		Restart
		break
	;;
		*)
			echo
			echo "$MESS_INVALID_ANSWER"
			echo
		;;
esac
done 

# Start time counter
START=$(date +%s)							# Start time counter
for files in "${LSTVIDEO[@]}"; do

	for i in ${!VINDEX[*]}; do

		echo "FFmpeg processing: ${files%.*}-NightNorm.mkv"

		# Encoding new track
		"$ffmpeg_bin"  $FFMPEG_LOG_LVL -y -i "$files" -map 0:v -c:v copy -map 0:s? -c:s copy -map 0:a -map 0:a:${VINDEX[i]}? \
			-c:a copy -metadata:s:a:${VINDEX[i]} title="Opus 2.0 Night Mode" -c:a:${VINDEX[i]} libopus \
			-b:a:${VINDEX[i]} 320K -ac 2 -filter:a:${VINDEX[i]} acompressor=threshold=0.031623:attack=200:release=1000:detection=0,loudnorm \
			"${files%.*}"-NightNorm.mkv

		# fix statistic of new track
		mkvpropedit --add-track-statistics-tags "${files%.*}"-NightNorm.mkv >/dev/null 2>&1


		# Check Target if valid (size test) and clean
		if [[ $(stat --printf="%s" "${files%.*}"-NightNorm.mkv 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
			filesPass+=("${files%.*}"-NightNorm.mkv)
		else																	# if file<30 KBytes rejected
			filesReject+=("${files%.*}"-NightNorm.mkv)
			rm "${files%.*}"-NightNorm.mkv 2>/dev/null
		fi

		done

done

# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"								# Get elapsed time
total_source_files_size=$(Calc_Files_Size "${LSTVIDEO[@]}")					# Source file(s) size
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")						# Target(s) size
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")						# Size difference between source and target

# End encoding messages "pass_files" "total_files" "target_size" "source_size"
Display_End_Encoding_Message "${#filesPass[@]}" "" "$total_target_files_size" "$total_source_files_size"
}
SplitByChapter() {						# Option 16 	- Split by chapter
	clear
	echo
	cat "$FFMES_CACHE_STAT"
	read -r -p " Split by chapter, continue? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			mkvmerge -o "${LSTVIDEO[0]%.*}"-Chapter.mkv --split chapters:all "${LSTVIDEO[0]}"
		;;
		*)
			Restart
		;;
	esac
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
			echo "$MESS_INVALID_ANSWER"
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
			echo "$MESS_INVALID_ANSWER"
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
		# Print eta
		echo -ne "  ${COUNTER}/${#TOTAL[@]} tiff converted in text files"\\r
	done
	wait

	StartLoading "${files%.*}: Convert text files in srt"

	# Convert text in srt
	subptools -s -w -t srt -i "${files%.*}".xml -o "${files%.*}".srt &>/dev/null

	# Remove ^L/\f/FF/form-feed/page-break character
	sed -i 's/\o14//g' "${files%.*}".srt &>/dev/null

	StopLoading $?

	# Clean
	COUNTER=0
	rm -- *.tif &>/dev/null
	rm -- *.txt &>/dev/null
	rm -- *.xml &>/dev/null
done
	}
MultipleVideoExtention() {				# Sources video multiple extention question
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
	read -r -e -p "-> " VIDEO_EXT_AVAILABLE
	if [ "$VIDEO_EXT_AVAILABLE" = "q" ]; then
		Restart
	elif test -n "$VIDEO_EXT_AVAILABLE"; then
		mapfile -t LSTVIDEO < <(find "$PWD" -maxdepth 1 -type f -regextype posix-egrep -regex '.*\.('$VIDEO_EXT_AVAILABLE')$' 2>/dev/null | sort)
	fi
fi
}
RemoveVideoSource() {					# Clean video source
if [ "${#filesPass[@]}" -gt 0 ] ; then
	read -r -p " Remove source video? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			for f in "${filesSourcePass[@]}"; do
				rm -f "$f" 2> /dev/null
			done
		;;
		*)
			Restart
		;;
	esac
fi
}

## AUDIO
Audio_Source_Info() {					# One audio file source stats (first in loop)
# Add all stats in temp.stat.info
"$ffprobe_bin" -analyzeduration 20M -probesize 20M -i "${LSTAUDIO[0]}" 2> "$FFMES_CACHE"/temp.stat.info

# Grep stream in stat.info
< "$FFMES_CACHE"/temp.stat.info grep Stream > "$FFMES_CACHE_STAT"

# Remove line with "Guessed Channel" (not used)
sed -i '/Guessed Channel/d' "$FFMES_CACHE_STAT"

# Grep & Add source duration
SourceDuration=$(< "$FFMES_CACHE"/temp.stat.info grep Duration)
sed -i '1 i\  '"$SourceDuration"'' "$FFMES_CACHE_STAT"

# Grep source size & add file name and size
SourceSize=$(Calc_Files_Size "${LSTAUDIO[0]}")
sed -i '1 i\    '"${LSTAUDIO[0]}, size: $SourceSize MB"'' "$FFMES_CACHE_STAT"

# Grep audio db peak & add
LineDBPeak=$(< "$FFMES_CACHE_STAT" grep -nE -- ".*Stream.*.*Audio.*" | cut -c1)
TestDBPeak=$("$ffmpeg_bin" -analyzeduration 100M -probesize 100M -i "${LSTAUDIO[0]}" -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')dB
sed -i "${LineDBPeak}s/.*/&, DB peak: $TestDBPeak/" "$FFMES_CACHE_STAT"

# Add title & complete formatting
sed -i '1 i\ Audio file stats:' "$FFMES_CACHE_STAT"                             # Add title
sed -i '1 i\----------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"
sed -i -e '$a==============================================================================================' "$FFMES_CACHE_STAT"

# Clean temp file
rm $FFMES_CACHE"/temp.stat.info" &>/dev/null
}
Audio_Source_Info_Detail() {			# All audio files source stats
# Local variables - info parsing
local ffprobe_Duration_Total_Second
local ffprobe_Duration_Minute
local ffprobe_Duration_Second
# Local variables - display
local codec_string_length
local bitrate_string_length
local SampleFormat_string_length
local SampleRate_string_length
local bitrate_string_length
local duration_string_length
local peakdb_string_length
local meandb_string_length
local filename_string_length
local FilesSize_string_length
local horizontal_separator_string_length
local FilesSize
local TotalSize
# Array
ffmpeg_Bitrate=()
ffmpeg_meandb=()
ffmpeg_peakdb=()
ffprobe_Channel=()
ffprobe_Codec=()
ffprobe_Duration=()
ffprobe_SampleFormat=()
ffprobe_SampleRate=()
PrtSep=()

# Loading on
if [ "$force_compare_audio" = "1" ]; then
	Display_Remove_Previous_Line
fi
StartLoading "Grab current files informations" ""

# Get total file size with du
TotalSize=$(Calc_Files_Size "${LSTAUDIO[@]}")

# Get stats with ffprobe
for (( i=0; i<=$(( ${#LSTAUDIO[@]} - 1 )); i++ )); do
	(
	"$ffprobe_bin" -hide_banner -loglevel panic -select_streams a -show_streams -show_format \
		"${LSTAUDIO[$i]}" > "$FFMES_FFPROBE_CACHE_STAT_DETAILED-[$i]"
	) &
	if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
		wait -n
	fi
done
wait

# Get stats with ffmpeg
for (( i=0; i<=$(( ${#LSTAUDIO[@]} - 1 )); i++ )); do
	(
	"$ffmpeg_bin" -i "${LSTAUDIO[$i]}" -af "volumedetect" -vn -sn -dn -f null - &> "$FFMES_FFMPEG_CACHE_STAT_DETAILED-[$i]"
	) &
	if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
		wait -n
	fi
done
wait

# Populate array with stats & clean cache
for (( i=0; i<=$(( ${#LSTAUDIO[@]} - 1 )); i++ )); do
	ffmpeg_Bitrate+=( "$(mediainfo --Output="General;%OverallBitRate%" "${LSTAUDIO[$i]}" \
						| awk '{ kbyte=$1/1024; print kbyte }' | sed 's/\..*$//')" )
	ffmpeg_meandb+=( "$(cat "$FFMES_FFMPEG_CACHE_STAT_DETAILED-[$i]" | grep "mean_volume:" | awk '{print $5}')" )
	ffmpeg_peakdb+=( "$(cat "$FFMES_FFMPEG_CACHE_STAT_DETAILED-[$i]" | grep "max_volume:" | awk '{print $5}')" )
	ffprobe_Channel+=( "$(cat "$FFMES_FFPROBE_CACHE_STAT_DETAILED-[$i]" | grep -i "channels=" | awk -F'=' '{print $NF}' | head -1)" )
	ffprobe_Codec+=( "$(cat "$FFMES_FFPROBE_CACHE_STAT_DETAILED-[$i]" | grep -i "codec_name=" | awk -F'=' '{print $NF}' | head -1)" )
	ffprobe_SampleFormat+=( "$(cat "$FFMES_FFPROBE_CACHE_STAT_DETAILED-[$i]" | grep -i "sample_fmt=" | awk -F'=' '{print $NF}' | head -1)" )
	ffprobe_SampleRate+=( "$(cat "$FFMES_FFPROBE_CACHE_STAT_DETAILED-[$i]" | grep -i "sample_rate=" \
							| awk -F'=' '{print $NF}' | head -1 | awk '{print $1/1000}')" )

	# Duration
	ffprobe_Duration_Total_Second=$(cat "$FFMES_FFPROBE_CACHE_STAT_DETAILED-[$i]" | grep -i "duration=" \
									| awk -F'=' '{print $NF}' | head -1 | awk -F'.' '{print $1}')
	ffprobe_Duration_Minute=$(( ffprobe_Duration_Total_Second / 60 ))
	ffprobe_Duration_Second=$(( ffprobe_Duration_Total_Second % 60 ))
	if [[ "${#ffprobe_Duration_Second}" -eq "1" ]] ; then
		ffprobe_Duration_Second="0$ffprobe_Duration_Second"
	fi
	ffprobe_Duration+=( "${ffprobe_Duration_Minute}:${ffprobe_Duration_Second}" )

	# File size
	FilesSize+=( "$(Calc_Files_Size "${LSTAUDIO[$i]}")" )

	# Table separator trick
	PrtSep+=("|")

	# Clean
	rm "$FFMES_FFPROBE_CACHE_STAT_DETAILED-[$i]" &>/dev/null
	rm "$FFMES_FFMPEG_CACHE_STAT_DETAILED-[$i]" &>/dev/null
done

# Calcul larger of column
codec_string_length=$(Calc_Table_width "${ffprobe_Codec[@]}")
bitrate_string_length=$(Calc_Table_width "${ffmpeg_Bitrate[@]}")
SampleFormat_string_length=$(Calc_Table_width "${ffprobe_SampleFormat[@]}")
SampleRate_string_length=$(Calc_Table_width "${ffprobe_SampleRate[@]}")
Channel_string_length="2"
duration_string_length=$(Calc_Table_width "${ffprobe_Duration[@]}")
peakdb_string_length=$(Calc_Table_width "${ffmpeg_peakdb[@]}")
meandb_string_length=$(Calc_Table_width "${ffmpeg_meandb[@]}")
FilesSize_string_length=$(Calc_Table_width "${FilesSize[@]}")
filename_string_length=$(Calc_Table_width "${LSTAUDIO[@]}")
horizontal_separator_string_length=$(( 9 * 5 ))
# If Codec field is wide enough, print codec label
if [[ "$codec_string_length" -ge "5" ]]; then
	codec_label="Codec"
fi
# filename correction
if [[ "$filename_string_length" -gt "40" ]]; then
	filename_string_length="40"
fi
# Separator
separator_string_length=$(( codec_string_length + bitrate_string_length + SampleFormat_string_length \
							+ SampleRate_string_length + duration_string_length + peakdb_string_length \
							+ meandb_string_length + filename_string_length + Channel_string_length \
							+ FilesSize_string_length + horizontal_separator_string_length ))

# Loading off
StopLoading $?

# Display stats
if [ "$force_compare_audio" = "1" ]; then
	Display_Remove_Previous_Line
	Display_Remove_Previous_Line
	echo
else
	clear
fi

# In table if term is wide enough, or in ligne
echo "${#LSTAUDIO[@]} audio files - ${TotalSize} MB"
if [[ "$separator_string_length" -le "$TERM_WIDTH" ]]; then
	printf '%*s' "$separator_string_length" | tr ' ' "-"; echo
	paste <(printf "%-${codec_string_length}.${codec_string_length}s\n" "$codec_label") <(printf "%s\n" "|") \
		<(printf "%-${bitrate_string_length}.${bitrate_string_length}s\n" "kb/s") <(printf "%s\n" "|") \
		<(printf "%-${SampleFormat_string_length}.${SampleFormat_string_length}s\n" "fmt") <(printf "%s\n" "|") \
		<(printf "%-${SampleRate_string_length}.${SampleRate_string_length}s\n" "kHz") <(printf "%s\n" "|") \
		<(printf "%-${Channel_string_length}.${Channel_string_length}s\n" "ch") <(printf "%s\n" "|") \
		<(printf "%-${duration_string_length}.${duration_string_length}s\n" "m:s") <(printf "%s\n" "|") \
		<(printf "%-${peakdb_string_length}.${peakdb_string_length}s\n" "Peak") <(printf "%s\n" "|") \
		<(printf "%-${meandb_string_length}.${meandb_string_length}s\n" "Mean") <(printf "%s\n" "|") \
		<(printf "%-${FilesSize_string_length}.${FilesSize_string_length}s\n" "MB") <(printf "%s\n" "|") \
		<(printf "%-${filename_string_length}.${filename_string_length}s\n" "Files") | column -s $'\t' -t
	printf '%*s' "$separator_string_length" | tr ' ' "-"; echo
	paste <(printf "%-${codec_string_length}.${codec_string_length}s\n" "${ffprobe_Codec[@]}") <(printf "%s\n" "${PrtSep[@]}") \
		<(printf "%-${bitrate_string_length}.${bitrate_string_length}s\n" "${ffmpeg_Bitrate[@]}") <(printf "%s\n" "${PrtSep[@]}") \
		<(printf "%-${SampleFormat_string_length}.${SampleFormat_string_length}s\n" "${ffprobe_SampleFormat[@]}") <(printf "%s\n" "${PrtSep[@]}") \
		<(printf "%-${SampleRate_string_length}.${SampleRate_string_length}s\n" "${ffprobe_SampleRate[@]}") <(printf "%s\n" "${PrtSep[@]}") \
		<(printf "%-${Channel_string_length}.${Channel_string_length}s\n" "${ffprobe_Channel[@]}") <(printf "%s\n" "${PrtSep[@]}") \
		<(printf "%-${duration_string_length}.${duration_string_length}s\n" "${ffprobe_Duration[@]}") <(printf "%s\n" "${PrtSep[@]}") \
		<(printf "%-${peakdb_string_length}.${peakdb_string_length}s\n" "${ffmpeg_peakdb[@]}") <(printf "%s\n" "${PrtSep[@]}") \
		<(printf "%-${meandb_string_length}.${meandb_string_length}s\n" "${ffmpeg_meandb[@]}") <(printf "%s\n" "${PrtSep[@]}") \
		<(printf "%-${FilesSize_string_length}.${FilesSize_string_length}s\n" "${FilesSize[@]}") <(printf "%s\n" "${PrtSep[@]}") \
		<(printf "%-${filename_string_length}.${filename_string_length}s\n" "${LSTAUDIO[@]}") | column -s $'\t' -t 2>/dev/null
	printf '%*s' "$separator_string_length" | tr ' ' "-"; echo
else
	printf '%*s' "$TERM_WIDTH_TRUNC" | tr ' ' "-"; echo
	for (( i=0; i<=$(( ${#LSTAUDIO[@]} - 1 )); i++ )); do
		Display_Line_Truncate "${LSTAUDIO[$i]}"
		echo "${ffprobe_Codec[$i]}, ${ffmpeg_Bitrate[$i]} kb/s, ${ffprobe_SampleFormat[$i]}, ${ffprobe_SampleRate[$i]} kHz, ${ffprobe_Duration[$i]}, peak db: ${ffmpeg_peakdb[$i]}, mean db: ${ffmpeg_meandb[$i]}, ${FilesSize[$i]} MB"
		printf '%*s' "$TERM_WIDTH_TRUNC" | tr ' ' "-"; echo
	done
fi

# Only display if launched in argument
if [ "$force_compare_audio" = "1" ]; then
	echo
fi
}
Audio_FFmpeg_cmd() {					# FFmpeg audio encoding loop
# Local variables
local PERC
local total_source_files_size
local total_target_files_size
local START
local END
local file_test
local filesRejectRm
local filename_trunk
# Array
filesInLoop=()
filesOverwrite=()
filesPass=()
filesSourcePass=()
filesReject=()

# Start time counter
START=$(date +%s)

# Message
echo
Display_Separator

# Copy $extcont for test and reset inside loop
ExtContSource="$extcont"

# Disable the enter key
EnterKeyDisable

# Encoding
for files in "${LSTAUDIO[@]}"; do
	# Reset $extcont
	extcont="$ExtContSource"
	# Test Volume and set normalization variable
	Audio_Peak_Normalization_Action
	# Channel test mono or stereo
	Audio_False_Stereo_Action
	# Silence detect & remove, at start & end (only for wav and flac source files)
	Audio_Silent_Detection_Action
	# Opus auto adapted bitrate
	Audio_Opus_AAC_Auto_Bitrate
	# Flac & WavPack sampling rate limitation
	Audio_Sample_Rate_Limitation
	# Flac & WavPack bit depht source detection (if not set)
	Audio_Bit_Depth_Detection
	# Stream set & cover extract
	Audio_Cover_Process
	# Stock files pass in loop
	filesInLoop+=("$files")					# Populate array
	# If source extention same as target
	if [[ "${files##*.}" = "$extcont" ]]; then
		extcont="new.$extcont"
		filesOverwrite+=("$files")			# Populate array
	else
		filesOverwrite+=("$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')")		# Populate array with random strimg
	fi

	# Encoding / Test integrity / Untagged test
	(
	if [[ -n "$Untagged" ]]; then
		"$ffprobe_bin" -hide_banner -loglevel panic -select_streams a -show_streams -show_format "$files" \
			| grep -i "$untagged_type" 1>/dev/null || echo "  $files" >> "$FFMES_CACHE_UNTAGGED"
	elif [[ -z "$VERBOSE" ]]; then
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "$files" $afilter $astream $acodec $akb $abitdeph \
			$asamplerate $confchan "${files%.*}".$extcont &>/dev/null
	else
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "$files" $afilter $astream $acodec $akb $abitdeph \
			$asamplerate $confchan "${files%.*}".$extcont
	fi
	) &
	if [[ $(jobs -r -p | wc -l) -ge $NPROC ]]; then
		wait -n
	fi

	# Progress
	if [[ -z "$VERBOSE" ]]; then
		filename_trunk=$(Display_Line_Progress_Truncate "${files##*/}")
		ProgressBar "${#filesInLoop[@]}" "${#LSTAUDIO[@]}" "$filename_trunk"
	fi

done
wait

# Display
ProgressBarClean
Display_Remove_Previous_Line

# Test results
if [[ -z "$Untagged" ]]; then

# Display
echo "✓ File(s) encoding"
StartLoading "Validation of created file(s)"

	# Check Target if valid (size test) and clean
	extcont="$ExtContSource"	# Reset $extcont
	for (( i=0; i<=$(( ${#filesInLoop[@]} - 1 )); i++ )); do

		# File to test
		if [[ "${filesInLoop[i]%.*}" = "${filesOverwrite[i]%.*}" ]]; then										# If file overwrite
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

				if [[ "${filesInLoop[i]%.*}" = "${filesOverwrite[i]%.*}" ]]; then								# If file overwrite
					mv "${filesInLoop[i]}" "${filesInLoop[i]%.*}".back."$extcont" 2>/dev/null
					mv "${filesInLoop[i]%.*}".new."$extcont" "${filesInLoop[i]}" 2>/dev/null
					filesPass+=("${filesInLoop[i]}")
					filesSourcePass+=("${filesInLoop[i]%.*}".back."$extcont")
				else
					filesPass+=("${filesInLoop[i]%.*}"."$extcont")
					filesSourcePass+=("${filesInLoop[i]}")
				fi

		fi

		# Remove rejected
		rm "$filesRejectRm" 2>/dev/null
	done

StopLoading $?

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
			"$sox_bin" "${files%.*}"."${files##*.}" temp-out."${files##*.}" silence 1 0.2 -85d reverse silence 1 0.2 -85d reverse
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
if [ "$reps" -le 1 ]; then          # if profile 0 or 1 display
    CustomInfoChoice
fi
if [[ "$codeca" = "libopus" || "$AudioCodecType" = "libopus" ]]; then
	echo
	echo " Choose desired audio channels configuration:"
	echo " note: * applied to the all audio stream"
	Display_Separator
	echo
	echo "  [1]  > for channel_layout 1.0 (Mono)"
	echo "  [2]  > for channel_layout 2.0 (Stereo)"
	echo "  [3]  > for channel_layout 3.0 (FL+FR+FC)"
	echo "  [4]  > for channel_layout 5.1 (FL+FR+FC+LFE+BL+BR)"
	echo "  [↵]* > for no change"
	echo "  [q]  > for exit"
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
	echo " note: * applied to the all audio stream"
	Display_Separator
	echo
	echo "  [1]  > for channel_layout 1.0 (Mono)"
	echo "  [2]  > for channel_layout 2.0 (Stereo)"
	echo "  [3]  > for channel_layout 2.1 (FL+FR+LFE)"
	echo "  [4]  > for channel_layout 3.0 (FL+FR+FC)"
	echo "  [5]  > for channel_layout 3.1 (FL+FR+FC+LFE)"
	echo "  [6]  > for channel_layout 4.0 (FL+FR+FC+BC)"
	echo "  [7]  > for channel_layout 4.1 (FL+FR+FC+LFE+BC)"
	echo "  [8]  > for channel_layout 5.0 (FL+FR+FC+BL+BR)"
	echo "  [9]  > for channel_layout 5.1 (FL+FR+FC+LFE+BL+BR)"
	echo "  [↵]* > for no change"
	echo "  [q]  > for exit"
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
if [ "$reps" -eq 1 ]; then		# If in video encoding
    CustomInfoChoice
else							# If not in video encoding
    clear
    echo
    echo " Under, first on the list of ${#LSTAUDIO[@]} files to edit."
    cat "$FFMES_CACHE_STAT"
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
if [ "$reps" -eq 1 ]; then
	CustomInfoChoice
else
	clear
	echo
	echo " Under, first on the list of ${#LSTAUDIO[@]} files to edit."
	cat "$FFMES_CACHE_STAT"
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
	Display_Separator
	echo " Choose a number:"
	echo
	echo "        | comp. | sample |   bit |"
	echo "        | level |   rate | depth |"
	echo "        |-------|--------|-------|"
	echo "  [1] > |   12  |  44kHz |    16 |"
	echo "  [2] > |   12  |  44kHz |    24 |"
	echo " *[3] > |   12  |  44kHz |  auto |"
	echo "  [4] > |   12  |  48kHz |    16 |"
	echo "  [5] > |   12  |  48kHz |    24 |"
	echo "  [6] > |   12  |  48kHz |  auto |"
	echo "  [7] > |   12  |   auto |    16 |"
	echo "  [8] > |   12  |   auto |    24 |"
	echo "  [9] > |   12  |   auto |  auto |"
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
		asamplerate="-ar 44100"
	fi
	}
Audio_WavPack_Config() {				# Option 23 	- audio to wavpack
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of ${#LSTAUDIO[@]} files to edit."
    cat "$FFMES_CACHE_STAT"
    Audio_Source_Info_Detail_Question
fi
    echo " Choose WavPack desired configuration:"
    echo " Notes: * WavPack uses a compression level parameter that varies from 0 (fastest) to 8 (slowest)."
	echo "          The value 3 allows a very good compression without having a huge encoding time."
	echo "        * Option tagued [auto] = same value of source file."
	echo "        * Max value of sample rate is 384kHz."
    echo
	Display_Separator
    echo " Choose a number:"
    echo
    echo "         | comp. | sample |   bit |"
    echo "         | level |   rate | depth |"
    echo "         |-------|--------|-------|"
    echo "  [1]  > |    3  |  44kHz |    16 |"
    echo "  [2]  > |    3  |  44kHz | 24/32 |"
    echo " *[3]  > |    3  |  44kHz |  auto |"
    echo "  [4]  > |    1  |  44kHz |  auto |"
    echo "  [5]  > |    3  |  48kHz |    16 |"
    echo "  [6]  > |    3  |  48kHz | 24/32 |"
    echo "  [7]  > |    3  |  48kHz |  auto |"
    echo "  [8]  > |    1  |  48kHz |  auto |"
    echo "  [9]  > |    3  |   auto |    16 |"
    echo "  [10] > |    3  |   auto | 24/32 |"
    echo "  [11] > |    3  |   auto |  auto |"
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
		asamplerate="-ar 44100"
	fi
	}
Audio_Opus_Config() {					# Option 1,26 	- Conf audio/video opus, audio to opus (libopus)
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of ${#LSTAUDIO[@]} files to edit."
    cat "$FFMES_CACHE_STAT"
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
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of ${#LSTAUDIO[@]} files to edit."
    cat "$FFMES_CACHE_STAT"
    Audio_Source_Info_Detail_Question
fi
echo " Choose Ogg (libvorbis) desired configuration:"
echo " Notes: * The reference is the variable bitrate (vbr), it allows to allocate more information to"
echo "          compressdifficult passages and to save space on less demanding passages."
echo "        * A constant bitrate (cbr) is valid for streaming in order to maintain bitrate regularity."
echo "        * The cutoff allows to lose bitrate on high frequencies,"
echo "          to gain bitrate on audible frequencies."
echo
Display_Separator
echo " For crb:"
echo " [192k] -> Example of input format for desired bitrate"
echo
Display_Separator
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
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of ${#LSTAUDIO[@]} files to edit."
    cat "$FFMES_CACHE_STAT"
    Audio_Source_Info_Detail_Question
fi
echo " Choose MP3 (libmp3lame) desired configuration:"
echo
Display_Separator
echo " For crb:"
echo " [192k] -> Example of input format for desired bitrate"
echo
Display_Separator
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
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of ${#LSTAUDIO[@]} files to edit."
    cat "$FFMES_CACHE_STAT"
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
echo " Choose AC3 desired configuration:"
echo
Display_Separator
echo " [192k] -> Example of input format for desired bitrate"
echo
Display_Separator
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
read -r -p " View all files stats in current loop (can be long, it's recursive)? [y/N]" qarm
case $qarm in
	"Y"|"y")
		Display_Remove_Previous_Line
		Audio_Source_Info_Detail
	;;
	*)
		Display_Remove_Previous_Line
		return
	;;
esac
}
Audio_Peak_Normalization_Question() {	#
read -r -p " Apply a -${PeakNormDB}db peak normalization (1st file DB peak:$TestDBPeak)? [y/N]" qarm
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
Audio_Remove_File_Source() {			# Remove audio source
if [ "${#filesPass[@]}" -gt 0 ] ; then
	read -r -p " Remove source audio? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			# Remove audio source files
			for f in "${filesSourcePass[@]}"; do
				rm -f "$f" 2>/dev/null
			done
			# Remove m3u
			if [ "$RemoveM3U" = "1" ]; then
				for f in "${LSTM3U[@]}"; do
					rm -f "$f" 2>/dev/null
				done
			fi
		;;
		*)
			SourceNotRemoved="1"
		;;
	esac
fi
}
Audio_Remove_File_Target() {			# Remove audio target
if [ "$SourceNotRemoved" = "1" ] ; then
	read -r -p " Remove target audio? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			# Remove audio source files
			for f in "${filesPass[@]}"; do
				rm -f "$f" 2>/dev/null
			done
			# Rename if extention same as source
			for (( i=0; i<=$(( ${#filesInLoop[@]} -1 )); i++ )); do
				if [[ "${filesInLoop[i]%.*}" = "${filesOverwrite[i]%.*}" ]]; then										# If file overwrite
					mv "${filesInLoop[i]%.*}".back.$extcont "${filesInLoop[i]}" 2>/dev/null
				fi
			done
		;;
		*)
			Restart
		;;
	esac
fi
}
Audio_Multiple_Extention_Check() {		# Question if sources with multiple extention
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
	read -r AUDIO_EXT_AVAILABLE
	if [ "$AUDIO_EXT_AVAILABLE" = "q" ]; then
		Restart
	elif test -n "$AUDIO_EXT_AVAILABLE"; then
		StartLoading "Search the files processed"
		mapfile -t LSTAUDIO < <(find . -maxdepth 5 -type f -regextype posix-egrep -regex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
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
filesInLoop=()
filesPass=()
filesReject=()

clear
echo
cat "$FFMES_CACHE_STAT"

echo " Choose size of spectrum:"
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

START=$(date +%s)               # Start time counter

for files in "${LSTAUDIO[@]}"; do

	# Stock files pass in loop
	filesInLoop+=("$files")

	(
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -y -i "$files" -lavfi showspectrumpic=s=$spekres:mode=separate:gain=1.4:color=2 "${files%.*}".png 2>/dev/null
	) &
	if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
		wait -n
	fi

	# Progress
	if [[ -z "$VERBOSE" ]]; then
		filename_trunk=$(Display_Line_Progress_Truncate "${files##*/}")
		ProgressBar "${#filesInLoop[@]}" "${#LSTAUDIO[@]}" "$filename_trunk"
	fi

done
wait

# Check Target if valid (size test)
for files in "${LSTAUDIO[@]}"; do
	if [[ $(stat --printf="%s" "${files%.*}".png 2>/dev/null) -gt 30720 ]]; then	# if file>30 KBytes accepted
		filesPass+=("${files%.*}".png)
	else																			# if file<30 KBytes rejected
		filesReject+=("${files%.*}".png)
	fi
done

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
# Array
filesPass=()
filesReject=()

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

	# Start time counter
	START=$(date +%s)

	# Concatenate
	if [ "${LSTAUDIO[0]##*.}" = "flac" ]; then
		shntool join *.flac -o flac -a Concatenate-Output 1> /dev/null
	else
		"$ffmpeg_bin" $FFMPEG_LOG_LVL -f concat -safe 0 -i <(for f in *."${LSTAUDIO[0]##*.}"; do echo "file '$PWD/$f'"; done) \
			-c copy Concatenate-Output."${LSTAUDIO[0]##*.}"
	fi

	# File validation
	if ! "$ffmpeg_bin" -v error -t 1 -i "Concatenate-Output.${LSTAUDIO[0]##*.}" -max_muxing_queue_size 9999 -f null - &>/dev/null ; then
		filesReject+=("Concatenate-Output.${LSTAUDIO[0]##*.}")
		rm "Concatenate-Output.${LSTAUDIO[0]##*.}" 2>/dev/null
	else
		filesPass+=("Concatenate-Output.${LSTAUDIO[0]##*.}")
	fi

	# End time counter
	END=$(date +%s)

	# Make statistics of processed files
	Calc_Elapsed_Time "$START" "$END"
	total_source_files_size=$(Calc_Files_Size "${LSTAUDIO[@]}")
	total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")
	PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")		# Size difference between source and target

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
# Array
filesPass=()
filesReject=()

clear
echo
cat "$FFMES_CACHE_STAT"

echo " Enter duration of cut:"
echo " Notes: * for hours :   HOURS:MM:SS.MICROSECONDS"
echo "        * for minutes : MM:SS.MICROSECONDS"
echo "        * for seconds : SS.MICROSECONDS"
echo "        * microseconds is optional, you can not indicate them"
echo
Display_Separator
echo " Examples of input:"
echo "  [s.20]       -> remove audio after 20 second"
echo "  [e.01:11:20] -> remove audio before 1 hour 11 minutes 20 second"
echo
Display_Separator
echo
echo "  [s.time]      > for remove end"
echo "  [e.time]      > for remove start"
echo "  [t.time.time] > for remove start and end"
echo "  [q]           > for exit"
while :
do
read -r -e -p "-> " qcut0
case $qcut0 in
	s.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')												# Replace [.] by [ ] in variable
		CutStart=$(< "$FFMES_CACHE_STAT" grep Duration | awk '{print $4;}' | sed s'/.$//')
		CutEnd=$(echo "$qcut" | awk '{print $2;}')
		break
	;;
	e.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')												# Replace [.] by [ ] in variable
		CutStart=$(echo "$qcut" | awk '{print $2;}')
		CutEnd=$(< "$FFMES_CACHE_STAT" grep Duration | awk '{print $2;}' | sed s'/.$//')
		break
	;;
	t.*)
		qcut=$(echo "$qcut0" | sed -r 's/[.]+/ /g')												# Replace [.] by [ ] in variable
		CutStart=$(echo "$qcut" | awk '{print $2;}')
		CutEnd=$(echo "$qcut" | awk '{print $3;}')
		break
	;;
	"q"|"Q")
		Restart
		break
	;;
		*)
			echo
			echo "$MESS_INVALID_ANSWER"
			echo
		;;
esac
done

# Start time counter
START=$(date +%s)

# Cut
if  [[ "${LSTAUDIO[0]##*.}" == *"flac" ]] || [[ "${LSTAUDIO[0]##*.}" == *"FLAC" ]]; then			# Flac exception for reconstruc duration
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -i "${LSTAUDIO[0]}" -ss "$CutStart" -to "$CutEnd" -map_metadata 0 "${LSTAUDIO[0]%.*}".cut."${LSTAUDIO[0]##*.}"
else
	"$ffmpeg_bin" $FFMPEG_LOG_LVL -i "${LSTAUDIO[0]}" -ss "$CutStart" -to "$CutEnd" -c copy -map_metadata 0 "${LSTAUDIO[0]%.*}".cut."${LSTAUDIO[0]##*.}"
fi

# File validation
if ! "$ffmpeg_bin" -v error -t 1 -i "${LSTAUDIO[0]%.*}.cut.${LSTAUDIO[0]##*.}" -max_muxing_queue_size 9999 -f null - &>/dev/null ; then
	filesReject+=("${LSTAUDIO[0]%.*}.cut.${LSTAUDIO[0]##*.}")
	rm "${LSTAUDIO[0]%.*}.cut.${LSTAUDIO[0]##*.}" 2>/dev/null
else
	filesPass+=("${LSTAUDIO[0]%.*}.cut.${LSTAUDIO[0]##*.}")
fi


# End time counter
END=$(date +%s)

# Make statistics of processed files
Calc_Elapsed_Time "$START" "$END"
total_source_files_size=$(Calc_Files_Size "${LSTAUDIO[@]}")
total_target_files_size=$(Calc_Files_Size "${filesPass[@]}")
PERC=$(Calc_Percent "$total_source_files_size" "$total_target_files_size")		# Size difference between source and target

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
# Array
filesPass=()
filesReject=()

# Limit to current directory
mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

if [ "${#LSTAUDIO[@]}" -eq "0" ]; then
	echo "  No audio file in the working directory"
	echo
elif [ "${#LSTAUDIO[@]}" -gt "1" ]; then
	echo "  More than one audio file in working directory"
	echo
elif [[ "${#LSTCUE[@]}" -eq "1" ]] && [[ "${#LSTAUDIO[@]}" -eq "1" ]]; then

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
			Display_Separator
			echo "  CUE Splitting fail on WavPack extraction"
			Display_Separator
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
		Display_Separator
		echo "  CUE Splitting fail on shnsplit file"
		Display_Separator
		return 1
	fi

	# Check Target
	mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('flac')$' 2>/dev/null | sort | sed 's/^..//')

	# Tag
	cuetag "${LSTCUE[0]}" "${LSTAUDIO[@]}" 2> /dev/null

	# File validation
	StartLoading "Validation of created file(s)"
	for files in "${LSTAUDIO[@]}"; do
		if ! "$ffmpeg_bin" -v error -t 1 -i "$files" -max_muxing_queue_size 9999 -f null - &>/dev/null ; then
			filesReject+=("$files")
			rm "$files" 2>/dev/null
		else
			filesPass+=("$files")
		fi
	done
	StopLoading

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
Display_Separator
echo " Audio file integrity check"

# Disable the enter key
EnterKeyDisable

# Encoding
for files in "${LSTAUDIO[@]}"; do
	# Stock files pass in loop
	filesInLoop+=("$files")					# Populate array

	# Test integrity
	(
	"$ffmpeg_bin" -v error -t 1 -i "$files" -f null - &>/dev/null || echo "  $files" >> "$FFMES_CACHE_INTEGRITY"
	) &
	if [[ $(jobs -r -p | wc -l) -ge $NPROC ]]; then
		wait -n
	fi

	# Progress
	if [[ -z "$VERBOSE" ]]; then
		filename_trunk=$(Display_Line_Truncate "${files##*/}")
		ProgressBar "${#filesInLoop[@]}" "${#LSTAUDIO[@]}" "$filename_trunk"
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
ProgressBarClean
echo
if [ -s "$FFMES_CACHE_INTEGRITY" ]; then
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
			mv "${LSTAUDIO[$i]}" "$ParsedTrack"\ -\ "$ParsedTitle"."${LSTAUDIO[$i]##*.}"
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
			echo "$MESS_INVALID_ANSWER"
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
		reps="32"
	;;
    -i|--input)
		shift
		InputFileDir="$1"
			if [ -d "$InputFileDir" ]; then															# If target is directory
				cd "$InputFileDir" || exit															# Move to directory
			elif [ -f "$InputFileDir" ]; then														# If target is file
				TESTARGUMENT1=$(mediainfo "$InputFileDir" | grep -E 'Video|Audio|ISO' | head -n1)	# Test files 1
				TESTARGUMENT2=$(file "$InputFileDir" | grep -i -E 'Video|Audio')					# Test files 2
				if [[ -z "$TESTARGUMENT1" ]] && [[ -n "$TESTARGUMENT2" ]] ; then
					TESTARGUMENT="$TESTARGUMENT2"
				else
					TESTARGUMENT="$TESTARGUMENT1"
				fi
				if test -n "$TESTARGUMENT"; then
					ARGUMENT="$InputFileDir"
				else
					echo
					echo "   -/!\- Missed, \"$1\" is not a video, audio or ISO file."
					echo
					exit
				fi
			fi
    ;;
    -j|--videojobs)																					# Select 
		shift
		if ! [[ "$1" =~ ^[0-9]*$ ]] ; then															# If not integer
			echo "   -/!\- Video jobs option must be an integer."
			exit
		else
			unset NVENC																				# Unset default NVENC
			NVENC="$1"																				# Set NVENC
			if [[ "$NVENC" -lt 0 ]] ; then															# If result inferior than 0
				echo "   -/!\- Video jobs must be greater than zero."
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
		reps="$1"
    ;;
    -pk|--peaknorm)																					# Peak db 
		shift
		if [[ "$1" =~ ^[0-9]*[.][0-9]*$ ]] || [[ "$1" =~ ^[0-9]*$ ]]; then							# If integer or float
			unset PeakNormDB																		# Unset default PeakNormDB
			PeakNormDB="$1"																			# Set PeakNormDB
		else
			echo "   -/!\- Peak db normalization option must be a positive number."
			exit
		fi
    ;;
    -v|--verbose)
		VERBOSE="1"																					# Set verbose, for dev/null and loading disable
		unset FFMPEG_LOG_LVL																		# Unset default ffmpeg log
		unset X265_LOG_LVL																			# Unset, for display x265 info log
		FFMPEG_LOG_LVL="-loglevel info -stats"														# Set ffmpeg log level to stats
    ;;
    -vv|--fullverbose)
		VERBOSE="1"																					# Set verbose, for dev/null and loading disable
		unset FFMPEG_LOG_LVL																		# Unset default ffmpeg log
		unset X265_LOG_LVL																			# Unset, for display x265 info log
		FFMPEG_LOG_LVL="-loglevel debug -stats"														# Set ffmpeg log level to debug
    ;;
    *)
		Usage
		exit
    ;;
esac
shift
done
CheckCoreCommand
CheckCacheDirectory							# Check if cache directory exist
CheckCustomBin
StartLoading "Listing of media files to be processed"
SetGlobalVariables							# Set global variable
DetectDVD									# DVD detection
TestVAAPI									# VAAPI detection
StopLoading $?
trap TrapExit SIGINT SIGQUIT				# Set Ctrl+c clean trap for exit all script
trap TrapStop SIGTSTP						# Set Ctrl+z clean trap for exit current loop (for debug)
if [ -z "$reps" ]; then						# By-pass main menu if using command argument
	Display_Main_Menu						# Display main menu
fi

while true; do

if [ -z "$reps" ]; then						# By-pass selection if using command argument
	echo "  [q]exit [m]menu [r]restart"
	read -r -e -p "  -> " reps
fi

case $reps in

 restart | rst | r )
    Restart
    ;;

 exit | quit | q )
    TrapExit
    ;;

 main | menu | m )
    Display_Main_Menu
    ;;

 0 ) # DVD rip (experimental)
	CheckDVDCommand
    DVDRip
    StartLoading "Analysis of: ${LSTVIDEO[0]}"
	VideoSourceInfo
	StopLoading $?
	CustomVideoEncod                               # question for make video custom encoding
	CustomAudioEncod                               # question for make sound custom encoding
	CustomVideoContainer                           # question for make container custom encoding
	CustomVideoStream                              # question for make stream custom encoding (appear source have more of 2 streams)
	FFmpeg_video_cmd                               # encoding
	RemoveVideoSource
	Clean                                          # clean temp files
	;;

 1 ) # video -> full custom
	if [ "${#LSTVIDEO[@]}" -gt "0" ]; then
	MultipleVideoExtention
    StartLoading "Analysis of: ${LSTVIDEO[0]}"
	VideoSourceInfo
	StopLoading $?
	CustomVideoEncod                               # question for make video custom encoding
	CustomAudioEncod                               # question for make sound custom encoding
	CustomVideoContainer                           # question for make container custom encoding
	CustomVideoStream                              # question for make stream custom encoding (appear source have more of 2 streams)
	FFmpeg_video_cmd                               # encoding
	RemoveVideoSource
	Clean                                          # clean temp files
	else
        echo
        echo "$MESS_ZERO_VIDEO_FILE_AUTH"
        echo
	fi
	;;

 2 ) # video -> mkv|copy|copy
 	if [ "${#LSTVIDEO[@]}" -gt "0" ]; then
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # VIDEO ---------------------------------------------------------------------------------
    videoconf="-c:v copy"
    # AUDIO ---------------------------------------------------------------------------------
    soundconf="-c:a copy"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="mkv"
    container="matroska"
    # NAME ----------------------------------------------------------------------------------
    videoformat="AVCOPY"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    MultipleVideoExtention
    StartLoading "Analysis of: ${LSTVIDEO[0]}"
	VideoSourceInfo
	StopLoading $?
    CustomVideoStream                              # question for make stream custom encoding (appear source have more of 2 streams)
	FFmpeg_video_cmd                               # encoding
	RemoveVideoSource
	Clean                                          # clean temp files
	else
        echo
        echo "$MESS_ZERO_VIDEO_FILE_AUTH"
        echo
	fi
	;;

 10 ) # tools -> view stats
	if [ "${#LSTVIDEO[@]}" -gt "0" ]; then
	echo
	mediainfo "${LSTVIDEO[0]}"
	else
        echo
        echo "$MESS_ZERO_VIDEO_FILE_AUTH"
        echo
	fi
	;;

 11 ) # video -> mkv|copy|add audio|add sub
	if [[ "${#LSTVIDEO[@]}" -eq "1" ]] && [[ "${#LSTSUB[@]}" -gt 0 || "${#LSTAUDIO[@]}" -gt 0 ]]; then
	# CONF_START ////////////////////////////////////////////////////////////////////////////
    # NAME ----------------------------------------------------------------------------------
    videoformat="addcopy"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    StartLoading "Analysis of: ${LSTVIDEO[0]}"
	VideoSourceInfo
	StopLoading $?
	Mkvmerge
	Clean                                          # clean temp files
	else
        echo
        echo "	-/!\- One video, with several audio and/or subtitle files."
        echo
	fi
	;;

 12 ) # Concatenate video
	if [ "${#LSTVIDEO[@]}" -gt "1" ] && [ "$NBVEXT" -eq "1" ]; then
	ConcatenateVideo
    StartLoading "Analysis of: ${LSTVIDEO[0]}"
	VideoSourceInfo
	StopLoading $?
	CustomVideoEncod                               # question for make video custom encoding
	CustomAudioEncod                               # question for make sound custom encoding
	CustomVideoContainer                           # question for make container custom encoding
	CustomVideoStream                              # question for make stream custom encoding (appear source have more of 2 streams)
	FFmpeg_video_cmd                               # encoding
	RemoveVideoSource
	Clean                                          # clean temp files
	else
        echo
        if [[ "${#LSTVIDEO[@]}" -le "1" ]]; then
			echo "$MESS_BATCH_FILE_AUTH"
        fi
        if [[ "$NBVEXT" != "1" ]]; then
			echo "$MESS_EXT_FILE_AUTH"
        fi
        echo
	fi
	;;

 13 ) # Extract stream video
	if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
    StartLoading "Analysis of: ${LSTVIDEO[0]}"
	VideoSourceInfo
	StopLoading $?
    ExtractPartVideo
	Clean                                          # clean temp files
	else
        echo
        echo "$MESS_ONE_VIDEO_FILE_AUTH"
        echo
	fi
	;;

 14 ) # Cut video
	if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
    StartLoading "Analysis of: ${LSTVIDEO[0]}"
	VideoSourceInfo
	StopLoading $?
    CutVideo
	Clean                                          # clean temp files
	else
        echo
        echo "$MESS_ONE_VIDEO_FILE_AUTH"
        echo
	fi
	;;


 15 ) # Audio night normalization
	if [[ "${#LSTVIDEO[@]}" -eq "1" ]]; then
    StartLoading "Analysis of: ${LSTVIDEO[0]}"
	VideoAudio_Source_Info
	StopLoading $?
    AddAudioNightNorm
	Clean                                          # clean temp files
	else
        echo
        echo "$MESS_ONE_VIDEO_FILE_AUTH"
        echo
	fi
	;;

 16 ) # Split by chapter mkv
	if [ "${#LSTVIDEO[@]}" -eq "1" ] && [[ "${LSTVIDEO[0]##*.}" = "mkv" ]]; then
    StartLoading "Analysis of: ${LSTVIDEO[0]}"
	VideoSourceInfo
	StopLoading $?
    SplitByChapter
	Clean                                          # clean temp files
	else
        echo
        echo "$MESS_ONE_VIDEO_FILE_AUTH"
        echo
	fi
	;;

 17 ) # Change color palette of DVD subtitle
	if [[ "${LSTSUBEXT[*]}" = *"idx"* ]]; then
    DVDSubColor
	Clean                                          # clean temp files
	else
        echo
        echo "	-/!\- Only DVD subtitle extention type (idx/sub)."
        echo
	fi
	;;

 18 ) # Convert DVD subtitle to srt
	CheckSubtitleCommand
	if [[ "${LSTSUBEXT[*]}" = *"idx"* ]]; then
    DVDSub2Srt
	Clean                                          # clean temp files
	else
        echo
        echo "	-/!\- Only DVD subtitle extention type (idx/sub)."
        echo
	fi
	;;

 20 ) # audio -> CUE splitter
	CheckCueSplitCommand
	if [ "${#LSTCUE[@]}" -eq "0" ]; then
		echo "  No CUE file in the working directory"
		echo
	elif [ "${#LSTCUE[@]}" -gt "1" ]; then
		echo "  More than one CUE file in working directory"
		echo
	else
		Audio_CUE_Split
		Clean
	fi
    ;;

 21 ) # audio -> PCM
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="pcm"
		Audio_Multiple_Extention_Check
		Audio_Source_Info
		Audio_PCM_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		# CONF_START ////////////////////////////////////////////////////////////////////////////
		# CONTAINER -----------------------------------------------------------------------------
		extcont="wav"
		#CONF_END ///////////////////////////////////////////////////////////////////////////////
		Audio_FFmpeg_cmd                               # encoding
		Audio_Remove_File_Source
		Audio_Remove_File_Target
		Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_AUDIO_FILE_AUTH"
        echo
	fi
    ;;

 22 ) # audio -> flac lossless
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="flac"
		Audio_Multiple_Extention_Check
		Audio_Source_Info
		Audio_FLAC_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		# CONF_START ////////////////////////////////////////////////////////////////////////////
		# AUDIO ---------------------------------------------------------------------------------
		acodec="-acodec flac"
		# CONTAINER -----------------------------------------------------------------------------
		extcont="flac"
		#CONF_END ///////////////////////////////////////////////////////////////////////////////
		Audio_FFmpeg_cmd                               # encoding
		Audio_Remove_File_Source
		Audio_Remove_File_Target
		Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_AUDIO_FILE_AUTH"
        echo
	fi
    ;;

 23 ) # audio -> wavpack lossless
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="wavpack"
		Audio_Multiple_Extention_Check
		Audio_Source_Info
		Audio_WavPack_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		# CONF_START ////////////////////////////////////////////////////////////////////////////
		# AUDIO ---------------------------------------------------------------------------------
		acodec="-acodec wavpack"
		# CONTAINER -----------------------------------------------------------------------------
		extcont="wv"
		#CONF_END ///////////////////////////////////////////////////////////////////////////////
		Audio_FFmpeg_cmd                               # encoding
		Audio_Remove_File_Source
		Audio_Remove_File_Target
		Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_AUDIO_FILE_AUTH"
        echo
	fi
    ;;

 24 ) # audio -> mp3 @ vbr190-250kb
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="libmp3lame"
		Audio_Multiple_Extention_Check
		Audio_Source_Info
		Audio_MP3_Config
		Audio_Peak_Normalization_Question
		Audio_Silent_Detection_Question
		# CONF_START ////////////////////////////////////////////////////////////////////////////
		# AUDIO ---------------------------------------------------------------------------------
		acodec="-acodec libmp3lame"
		confchan="-ac 2"
		# CONTAINER -----------------------------------------------------------------------------
		extcont="mp3"
		#CONF_END ///////////////////////////////////////////////////////////////////////////////
		Audio_FFmpeg_cmd                               # encoding
		Audio_Remove_File_Source
		Audio_Remove_File_Target
		Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_AUDIO_FILE_AUTH"
        echo
	fi
    ;;

 25 ) # audio -> ogg
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="libvorbis"
		Audio_Multiple_Extention_Check
		Audio_Source_Info
		Audio_OGG_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		# CONF_START ////////////////////////////////////////////////////////////////////////////
		# AUDIO ---------------------------------------------------------------------------------
		acodec="-acodec libvorbis"
		# CONTAINER -----------------------------------------------------------------------------
		extcont="ogg"
		#CONF_END ///////////////////////////////////////////////////////////////////////////////
		Audio_FFmpeg_cmd                               # encoding
		Audio_Remove_File_Source
		Audio_Remove_File_Target
		Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_AUDIO_FILE_AUTH"
        echo
	fi
    ;;

 26 ) # audio -> opus
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="libopus"
		Audio_Multiple_Extention_Check
		Audio_Source_Info
		Audio_Opus_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		# CONF_START ////////////////////////////////////////////////////////////////////////////
		# AUDIO ---------------------------------------------------------------------------------
		acodec="-acodec libopus"
		# CONTAINER -----------------------------------------------------------------------------
		extcont="opus"
		#CONF_END ///////////////////////////////////////////////////////////////////////////////
		Audio_FFmpeg_cmd                               # encoding
		Audio_Remove_File_Source
		Audio_Remove_File_Target
		Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_AUDIO_FILE_AUTH"
        echo
	fi
    ;;

 27 ) # audio -> aac
	if (( "${#LSTAUDIO[@]}" )); then
		AudioCodecType="aac"
		Audio_Multiple_Extention_Check
		Audio_Source_Info
		Audio_AAC_Config
		Audio_Channels_Question
		Audio_Peak_Normalization_Question
		Audio_False_Stereo_Question
		Audio_Silent_Detection_Question
		# CONF_START ////////////////////////////////////////////////////////////////////////////
		# CONTAINER -----------------------------------------------------------------------------
		extcont="m4a"
		#CONF_END ///////////////////////////////////////////////////////////////////////////////
		Audio_FFmpeg_cmd                               # encoding
		Audio_Remove_File_Source
		Audio_Remove_File_Target
		Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_AUDIO_FILE_AUTH"
        echo
	fi
    ;;

 30 ) # tools -> audio tag
	CheckTagCommand
	if (( "${#LSTAUDIOTAG[@]}" )); then
		NPROC=$(nproc --all | awk '{ print $1 * 4 }')	# Change number of process for increase speed, here 4*nproc
		Audio_Tag_Editor
		NPROC=$(nproc --all)							# Reset number of process
		Clean
	else
			echo
			echo "   -/!\- No audio file to supported."
			echo "         Supported files: ${AUDIO_TAG_EXT_AVAILABLE//|/, }"
			echo
	fi
	;;

 31 ) # tools -> one file view stats
	if (( "${#LSTAUDIO[@]}" )); then
		Audio_Multiple_Extention_Check
		echo
		mediainfo "${LSTAUDIO[0]}"
	else
        echo
        echo "$MESS_ZERO_AUDIO_FILE_AUTH"
        echo
	fi
	;;

 32 ) # tools -> multi file view stats
	if (( "${#LSTAUDIO[@]}" )); then
		echo
		Audio_Source_Info_Detail
		Clean
	else
        echo
        echo "$MESS_ZERO_AUDIO_FILE_AUTH"
        echo
	fi
	if [ "$force_compare_audio" = "1" ]; then
		exit
	fi
	;;

 33 ) # audio -> generate png of audio spectrum
	if (( "${#LSTAUDIO[@]}" )); then
		Audio_Multiple_Extention_Check
		Audio_Source_Info
		Audio_Generate_Spectrum_Img
		Clean
    else
        echo
        echo "$MESS_ZERO_AUDIO_FILE_AUTH"
        echo
	fi
    ;;

 34 ) # Concatenate audio
	if [ "${#LSTAUDIO[@]}" -gt "1" ] && [ "$NBAEXT" -eq "1" ]; then
		Audio_Concatenate_Files
		Audio_Remove_File_Source
		Clean                                          # clean temp files
	else
        echo
        if [[ "${#LSTAUDIO[@]}" -le "1" ]]; then
			echo "$MESS_BATCH_FILE_AUTH"
        fi
        if [[ "$NBAEXT" != "1" ]]; then
			echo "$MESS_EXT_FILE_AUTH"
        fi
        echo
	fi
	;;

 35 ) # Cut audio
	if [[ "${#LSTAUDIO[@]}" -eq "1" ]]; then
		Audio_Source_Info
		Audio_Cut_File
		Clean                                          # clean temp files
	else
        echo
        echo "$MESS_ONE_AUDIO_FILE_AUTH"
        echo
	fi
	;;

 36 ) # File check
	if [[ "${#LSTAUDIO[@]}" -ge "1" ]]; then
		NPROC=$(nproc --all | awk '{ print $1 * 4 }')	# Change number of process for increase speed, here 4*nproc
		Audio_File_Tester
		Clean											# clean temp files
		NPROC=$(nproc --all)							# Reset number of process
	else
        echo
        echo "$MESS_ONE_AUDIO_FILE_AUTH"
        echo
	fi
	;;

 37 ) # Untagged search
	if (( "${#LSTAUDIO[@]}" )); then
		Untagged="1"
		NPROC=$(nproc --all | awk '{ print $1 * 4 }')	# Change number of process for increase speed, here 4*nproc
		Audio_Tag_Search_Untagged
		Audio_FFmpeg_cmd
		Clean											# clean temp files
		NPROC=$(nproc --all)							# Reset number of process
		unset Untagged
	else
        echo
        echo "$MESS_ONE_AUDIO_FILE_AUTH"
        echo
	fi
	;;

 99 ) # update
	ffmesUpdate
	Restart
	;;

 * ) # update
        echo
        echo "$MESS_INVALID_ANSWER"
        echo
	;;

esac
unset reps		# By-pass selection if using command argument

done
exit
