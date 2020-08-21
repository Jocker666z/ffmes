#!/bin/bash
# ffmes - ffmpeg media encode script
# Terminal tool handling media files, DVD, audio CD, and VGM. Mainly with ffmpeg. Batch or single file.
#
# Author : Romain Barbarot
# https://github.com/Jocker666z/ffmes/
#
# licence : GNU GPL-2.0

# Version
VERSION=v0.55

# Paths
FFMES_PATH="$( cd "$( dirname "$0" )" && pwd )"												# set ffmes.sh path for restart from any directory
FFMES_CACHE="/home/$USER/.cache/ffmes"														# cache directory
FFMES_CACHE_STAT="/home/$USER/.cache/ffmes/stat-$(date +%Y%m%s%N).info"						# stat-DATE.info, stats of source file
FFMES_CACHE_MAP="/home/$USER/.cache/ffmes/map-$(date +%Y%m%s%N).info"						# map-DATE.info, map file
FFMES_CACHE_TAG="/home/$USER/.cache/ffmes/tag-$(date +%Y%m%s%N).info"						# tag-DATE.info, audio tag file
LSDVD_CACHE="/home/$USER/.cache/ffmes/lsdvd-$(date +%Y%m%s%N).info"							# lsdvd cache
ABCDE_EXTRACT="/home/$USER/Music"															# abcde extract directory
ABCDE_CONF="$FFMES_PATH/conf/abcde-ffmes.conf"												# abcde configuration file
VGM_TAG="/home/$USER/.cache/ffmes/vgmtag-$(date +%Y%m%s%N).info"							# vgm tag cache
OPTICAL_DEVICE=(/dev/sr0 /dev/sr1 /dev/sr2 /dev/sr3)										# CD/DVD player drives names

# General variables
NPROC=$(nproc --all| awk '{ print $1 - 1 }')												# Set number of processor
KERNEL_TYPE=$(uname -sm)																	# Grep type of kernel, use for limit usage of VGM rip to Linux x86_64
TERM_WIDTH=$(stty size | awk '{print $2}' | awk '{ print $1 - 10 }')						# Get terminal width, and truncate
COMMAND_NEEDED=(ffmpeg abcde sox mediainfo lsdvd dvdxchap setcd mkvmerge mkvpropedit dvdbackup find nproc shntool cuetag uchardet iconv wc bc du awk bchunk python3 tesseract subp2tiff subptools)
LIB_NEEDED=(libao)
CUE_EXT_AVAILABLE="cue"
FFMPEG_LOG_LVL="-hide_banner -loglevel panic -stats"										# Comment for view default ffmpeg log
#FFMPEG_LOG_LVL="-loglevel debug -stats"													# Debug ffmpeg log

# Video variables
X265_LOG_LVL="log-level=error:"																# Comment for view all x265 codec log
VIDEO_EXT_AVAILABLE="mkv|vp9|m4v|m2ts|avi|ts|mts|mpg|flv|mp4|mov|wmv|3gp|vob|mpeg|webm|ogv|bik"
SUBTI_EXT_AVAILABLE="srt|ssa|idx|sup"
ISO_EXT_AVAILABLE="iso"
VOB_EXT_AVAILABLE="vob"
NVENC="1"																					# Set number of video encoding in same time, the countdown starts at 0, so 0 is worth one encoding at a time (0=1;1=2...)

# Audio variables
AUDIO_EXT_AVAILABLE="aif|wma|opus|aud|dsf|wav|ac3|aac|ape|m4a|mp3|flac|ogg|mpc|spx|mod|mpg|wv"
ExtractCover="0"																			# Extract cover, 0=extract cover from source and remove in output, 1=keep cover from source in output, empty=remove cover in output
RemoveM3U="1"																				# Remove m3u playlist, 0=no remove, 1=remove

# VGM variables
VGM_EXT_AVAILABLE="ads|adp|adx|aif|aifc|ast|at3|bcstm|bcwav|bfstm|bfwav|bin|gbs|dat|dsp|dsf|eam|fsb|hes|hps|int|ktss|mini2sf|minigsf|minipsf|miniusf|minipsf2|mod|msf|mus|nsf|rak|raw|s98|S98|snd|sndh|sng|spsd|ss2|ssf|spc|str|psf|psf2|vag|vgm|vgz|vpk|tak|thp|vgs|voc|wem|xa|xwav"
VGM_ISO_EXT_AVAILABLE="bin|iso"
M3U_EXT_AVAILABLE="m3u"

# Messages
MESS_SEPARATOR=" --------------------------------------------------------------"
MESS_ZERO_FILE_AUTH="	-/!\- No file to process. Restart ffmes by selecting a file or in a directory containing it."
MESS_INVALID_ANSWER="	-/!\- Invalid answer, please try again."
MESS_ONE_VIDEO_FILE_AUTH="	-/!\- Only one video file at a time. Restart ffmes to select one video or in a directory containing one."
MESS_ONE_AUDIO_FILE_AUTH="	-/!\- Only one audio file at a time. Restart ffmes to select one audio or in a directory containing one."
MESS_BATCH_FILE_AUTH="	-/!\- Only more than one file file at a time. Restart ffmes in a directory containing several files."
MESS_EXT_FILE_AUTH="	-/!\- Only one extention type at a time."
MESS_UNAME_AUTH="	-/!\- Only for Linux x86_64."

## EMBEDS BINARIES SECTION
binmerge() {					# https://github.com/putnam/binmerge
"$FFMES_PATH"/bin/binmerge "$@"
}
espctag() {						# https://sourceforge.net/projects/espctag/
env LD_LIBRARY_PATH="$FFMES_PATH/bin/lib/" "$FFMES_PATH"/bin/espctag "$@"
}
gbsplay() {						# https://github.com/mmitch/gbsplay
"$FFMES_PATH"/bin/gbsplay "$@"
}
gbsinfo() {						# https://github.com/mmitch/gbsplay
"$FFMES_PATH"/bin/gbsinfo "$@"
}
info68() {						# https://sourceforge.net/projects/sc68/
env LD_LIBRARY_PATH="$FFMES_PATH/bin/lib/" "$FFMES_PATH"/bin/info68 "$@"
}
opustags() {					# https://github.com/fmang/opustags
"$FFMES_PATH"/bin/opustags "$@"
}
sc68() {						# https://sourceforge.net/projects/sc68/
env LD_LIBRARY_PATH="$FFMES_PATH/bin/lib/" "$FFMES_PATH"/bin/sc68 "$@"
}
vgm2wav() {						# https://github.com/vgmrips/vgmplay
"$FFMES_PATH"/bin/vgm2wav "$@"
}
vgmstream-cli() {				# https://github.com/losnoco/vgmstream
"$FFMES_PATH"/bin/vgmstream_cli "$@"
	}
vgm_tag() {						# https://github.com/vgmrips/vgmplay
"$FFMES_PATH"/bin/vgm_tag "$@"
}
zxtune123() {					# https://zxtune.bitbucket.io/
"$FFMES_PATH"/bin/zxtune123 "$@"
}
## VARIABLES, DISPLAY & MENU SECTION
Usage() {
cat <<- EOF
ffmes $VERSION - GNU GPL-2.0 Copyright - Written by Romain Barbarot <https://github.com/Jocker666z/ffmes>

Usage: ffmes [option]
ffmes               for launch main menu
ffmes file          for treat one file
ffmes directory     for treat in batch a specific directory

If ffmes is not set in alias replace "ffmes" by "bash ~/ffmes/ffmes.sh".
However, it is strongly recommended to use an alias, but you can still continue to hurt yourself.
EOF
}
DetectCDDVD () {				# CD/DVD detection
for DEVICE in "${OPTICAL_DEVICE[@]}"; do
    DeviceTest=$(setcd -i "$DEVICE")
    case "$DeviceTest" in
        *'Disc found'*)
			DVD_DEVICE="$DEVICE"
            break
            ;;
    esac
done
}
SetGlobalVariables() {			# Construct variables with files accepted
if test -n "$TESTARGUMENT"; then		# if argument
	if [[ $TESTARGUMENT == *"Video"* ]]; then
		LSTVIDEO=()
		LSTVIDEO+=("$ARGUMENT")
		LSTVIDEOEXT=$(echo "${LSTVIDEO[@]##*.}")
	elif [[ $TESTARGUMENT == *"Audio"* ]]; then
		LSTAUDIO=()
		LSTAUDIO+=("$ARGUMENT")
		LSTAUDIOEXT=$(echo "${LSTAUDIO[@]##*.}")
	elif [[ $TESTARGUMENT == *"ISO"* ]]; then
		LSTISO=()
		LSTISO+=("$ARGUMENT")
	fi
else									# if no argument -> batch
	# List source(s) video file(s) & number of differents extentions
	mapfile -t LSTVIDEO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$VIDEO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	mapfile -t LSTVIDEOEXT < <(echo "${LSTVIDEO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	# List source(s) audio file(s) & number of differents extentions
	#mapfile -t LSTAUDIO < <(find . -maxdepth 5 -type f -regextype posix-egrep -iregex '.+.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	mapfile -t LSTAUDIO < <(find . -maxdepth 5 -type f -regextype posix-egrep -iregex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	mapfile -t LSTAUDIOEXT < <(echo "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	# List source(s) ISO file(s)
	mapfile -t LSTISO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$ISO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
fi
# List source(s) subtitle file(s)
mapfile -t LSTSUB < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$SUBTI_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
mapfile -t LSTSUBEXT < <(echo "${LSTSUB[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
# List source(s) CUE file(s)
mapfile -t LSTCUE < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$CUE_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
# List source(s) VOB file(s)
mapfile -t LSTVOB < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$VOB_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
# List source(s) VGM file(s) & number of differents extentions
mapfile -t LSTVGM < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$VGM_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
mapfile -t LSTVGMEXT < <(echo "${LSTVGM[@]##*.}")
# List source(s) VGM ISO file(s)
mapfile -t LSTVGMISO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$VGM_ISO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
# List source(s) M3U file(s)
mapfile -t LSTM3U < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$M3U_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

# Count source(s) file(s)
NBV="${#LSTVIDEO[@]}"
NBVEXT=$(echo "${LSTVIDEOEXT[@]##*.}" | uniq -u | wc -w)
NBA="${#LSTAUDIO[@]}"
NBAEXT=$(echo "${LSTAUDIOEXT[@]##*.}" | uniq -u | wc -w)
NBSUB="${#LSTSUB[@]}"
NBCUE="${#LSTCUE[@]}"
NBISO="${#LSTISO[@]}"
NBVOB="${#LSTVOB[@]}"
## VGM
NBVGM="${#LSTVGM[@]}"
NBVGMISO="${#LSTVGMISO[@]}"
NBGBS=$(echo "${LSTVGMEXT[@]##*.}" | uniq -u | grep gbs | wc -w)
NBM3U="${#LSTM3U[@]}"
}
Restart () {					# Restart script & for keep argument
Clean
if [ -f "$ARGUMENT" ]; then                              # If target is file
	bash "$FFMES_PATH"/ffmes.sh "$ARGUMENT" && exit
else
	bash "$FFMES_PATH"/ffmes.sh && exit
fi
}
TrapStop () {					# Ctrl+z Trap for loop exit
Clean
kill -s SIGTERM $!
}
TrapExit () {					# Ctrl+c Trap for script exit
Clean
echo
echo
exit
}
Clean() {						# Clean Temp
find "$FFMES_CACHE/" -type f -mtime +3 -exec /bin/rm -f {} \;			# consider if file exist in cache directory after 3 days, delete it
rm "$FFMES_CACHE_STAT" &>/dev/null
rm "$FFMES_CACHE_MAP" &>/dev/null
rm "$LSDVD_CACHE" &>/dev/null
rm "$VGM_TAG" &>/dev/null
}
CheckCacheDirectory() {			# Check if cache directory exist
if [ ! -d $FFMES_CACHE ]; then
	mkdir /home/$USER/.cache/ffmes
fi
}
CheckFiles() {					# Promp a message to user with number of video, audio, sub to edit, and command not found
# Video
if  [[ $TESTARGUMENT == *"Video"* ]]; then
	echo "  * Video to edit: ${LSTVIDEO[0]}" | DisplayTruncate
elif  [[ $TESTARGUMENT != *"Video"* ]] && [ "$NBV" -eq "1" ]; then
	echo "  * Video to edit: ${LSTVIDEO[0]}" | DisplayTruncate
elif [ "$NBV" -gt "1" ]; then                 # If no arg + 1> videos
	echo -e "  * Video to edit: $NBV files"
fi

# Audio
if  [[ $TESTARGUMENT == *"Audio"* ]]; then
	echo "  * Audio to edit: ${LSTAUDIO[0]}" | DisplayTruncate
elif [[ $TESTARGUMENT != *"Audio"* ]] && [ "$NBA" -eq "1" ]; then
	echo "  * Audio to edit: ${LSTAUDIO[0]}" | DisplayTruncate
elif test -z "$ARGUMENT" && [ "$NBA" -gt "1" ]; then                 # If no arg + 1> videos
	echo -e "  * Audio to edit: $NBA files"
fi

# ISO
if  [[ $TESTARGUMENT == *"ISO"* ]]; then
	echo "  * ISO to edit: ${LSTISO[0]}" | DisplayTruncate
elif [[ $TESTARGUMENT != *"ISO"* ]] && [ "$NBISO" -eq "1" ]; then
	echo "  * ISO to edit: ${LSTISO[0]}" | DisplayTruncate
fi

# Subtitle
if [ "$NBSUB" -eq "1" ]; then
	echo "  * Subtitle to edit: ${LSTSUB[0]}" | DisplayTruncate
elif [ "$NBSUB" -gt "1" ]; then
	echo "  * Subtitle to edit: $NBSUB"
fi

# Lib needed info
n=0;
for lib in "${LIB_NEEDED[@]}"; do
	if /usr/sbin/ldconfig -p | grep "$lib" &>/dev/null
	then
		let c++
	else
		echo -e "  * [!] \e[1m\033[31m$lib\033[0m is not installed"
		let n++
	fi
done

# Command needed info
n=0;
for command in "${COMMAND_NEEDED[@]}"; do
	if hash "$command" &>/dev/null
	then
		let c++
	else
		echo -e "  * [!] \e[1m\033[31m$command\033[0m is not installed"
		let n++
	fi
done
}
MainMenu() {					# Main menu
clear
echo
echo "  / ffmes $VERSION /"
echo "  -----------------------------------------------------"
echo "   0 - DVD rip                                        |"
echo "   1 - video encoding, full custom options            |-Video"
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
echo "  20 - CD rip                                         |"
echo "  21 - VGM rip to flac                                |-Audio"
echo "  22 - CUE Splitter to flac                           |"
echo "  23 - audio to wav (pcm)                             |"
echo "  24 - audio to flac                                  |"
echo "  25 - audio to mp3 (libmp3lame)                      |"
echo "  26 - audio to ogg (libvorbis)                       |"
echo "  27 - audio to opus (libopus)                        |"
echo "  -----------------------------------------------------"
echo "  30 - tag editor                                     |"
echo "  31 - view detailed audio file informations          |"
echo "  32 - generate png image of audio spectrum           |-Audio Tools"
echo "  33 - concatenate audio files                        |"
echo "  34 - cut audio file                                 |"
echo "  -----------------------------------------------------"
CheckFiles
echo "  -----------------------------------------------------"
}
DisplayTruncate() {				# Line width truncate
cut -c 1-"$TERM_WIDTH" | awk '{print $0"..."}'
}
Loading() {						# Loading animation
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
		kill $_sp_pid > /dev/null 2>&1
		printf "${CL}✓ ${task} ${msg}\n"
		;;
esac
}
StartLoading() {				# Start loading animation
task=$1
Ltask="${#task}"
if [ "$Ltask" -gt "$TERM_WIDTH" ]; then
	task=$(echo "${task:0:$TERM_WIDTH}" | awk '{print $0"..."}')
fi
msg=$2
if [ "$Ltask" -gt "$TERM_WIDTH" ]; then
	msg=$(echo "${msg:0:$TERM_WIDTH}" | awk '{print $0"..."}')
fi
# $1 : msg to display
tput civis		# hide cursor
Loading "start" "${task}" &
# set global spinner pid
_sp_pid=$!
disown
}
StopLoading() {					# Stop loading animation
# $1 : command exit status
tput cnorm		# normal cursor
Loading "stop" "${task}" "${msg}" $_sp_pid
unset _sp_pid
}
ffmesUpdate() {					# Option 99  	- Ugly update ffmes to last version (hidden option)
mkdir "$FFMES_PATH"/update-temp
cd "$FFMES_PATH"/update-temp
wget https://github.com/Jocker666z/ffmes/archive/master.zip
unzip master.zip && mv ffmes-master ffmes
rm "$FFMES_PATH"/update-temp/master.zip
rm -R "$FFMES_PATH"/bin
cp -R -- "$FFMES_PATH"/update-temp/ffmes/* "$FFMES_PATH"/
rm -R "$FFMES_PATH"/update-temp
}
## VIDEO SECTION
FFmpeg_video_cmd() {			# FFmpeg video encoding command
	START=$(date +%s)							# Start time counter

	stty igncr									# Disable the enter key
	for files in "${LSTVIDEO[@]}"; do

		if [ "$ENCODV" != "1" ]; then
			StartLoading "Test timestamp of: $files"
			TimestampTest=$(ffprobe -loglevel error -select_streams v:0 -show_entries packet=pts_time,flags -of csv=print_section=0 "$files" | awk -F',' '/K/ {print $1}' | tail -1)
			shopt -s nocasematch
			if [[ "${files##*.}" = "vob" || "$TimestampTest" = "N/A" ]]; then
				TimestampRegen="-fflags +genpts"
			fi
			shopt -u nocasematch
			StopLoading $?
		fi

		echo "FFmpeg processing: ${files%.*}.$videoformat.$extcont"
		(
		ffmpeg $FFMPEG_LOG_LVL $TimestampRegen -analyzeduration 1G -probesize 1G -y -i "$files" -threads 0 $stream $videoconf $soundconf $subtitleconf -max_muxing_queue_size 1024 -f $container "${files%.*}".$videoformat.$extcont
		) &
		if [[ $(jobs -r -p | wc -l) -gt $NVENC ]]; then
			wait -n
		fi
	done
	wait
	stty -igncr									# Enable the enter key

	END=$(date +%s)								# End time counter
	
	# Check target if valid (size test), if valid mkv fix target stats, and and clean
	filesPass=()
	filesReject=()
	filesSourcePass=()
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
	DIFFS=$(($END-$START))															# counter in seconds
	NBVO="${#filesPass[@]}"															# Count file(s) passed
	if [ "$NBVO" -eq 0 ] ; then
		SSIZVIDEO="0"
		TSSIZE="0"
		PERC="0"
	else
		SSIZVIDEO=$(du -chsm "${filesSourcePass[@]}" | tail -n1 | awk '{print $1;}')	# Source file(s) size
		TSSIZE=$(du -chsm "${filesPass[@]}" | tail -n1 | awk '{print $1;}')				# Target(s) size
		PERC=$(bc <<< "scale=2; ($TSSIZE - $SSIZVIDEO)/$SSIZVIDEO * 100")				# Size difference between source and target
	fi
	
	# End: encoding messages
	echo
	echo " -----------------------------------------------------"
	if test -n "$filesPass"; then
		echo " File(s) created:"
		printf '  %s\n' "${filesPass[@]}"
	fi
	if test -n "$filesReject"; then
		echo " File(s) in error:"
		printf '  %s\n' "${filesReject[@]}"
	fi
	echo " -----------------------------------------------------"
	echo " $NBVO/$NBV file(s) have been processed."
	echo " Created file(s) size: $TSSIZE MB, a difference of $PERC% from the source(s) ($SSIZVIDEO MB)."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo
}
Mkvmerge() {					# Merge command
	# Keep extention with wildcard for current audio and sub
	mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	NBA="${#LSTAUDIO[@]}"
	if [ "$NBA" -gt 0 ] ; then
		MERGE_LSTAUDIO=$(printf '*.%s ' "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	fi
	if [ "$NBSUB" -gt 0 ] ; then
		MERGE_LSTSUB=$(printf '*.%s ' "${LSTSUB[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
	fi
	
	# Summary message
	clear
    echo
    cat "$FFMES_CACHE_STAT"
    echo
	echo "  You will merge the following files:"
	echo "   ${LSTVIDEO[0]}"
	if [ "$NBA" -gt 0 ] ; then
		printf '   %s\n' "${LSTAUDIO[@]}"
	fi
	if [ "$NBSUB" -gt 0 ] ; then
		printf '   %s\n' "${LSTSUB[@]}"
	fi
	echo
	read -e -p "Continue? [Y/n]:" qarm
	case $qarm in
		"N"|"n")
			Restart
		;;
		*)
		;;
	esac

	START=$(date +%s)                       # Start time counter

	# If sub add, convert in UTF-8, srt and ssa
	if [ "$NBSUB" -gt 0 ] ; then
		for files in "${LSTSUB[@]}"; do
			if [ "${files##*.}" != "idx" ] && [ "${files##*.}" != "sup" ]; then
				CHARSET_DETECT=$(uchardet "$files" 2> /dev/null)
				if [ "$CHARSET_DETECT" != "UTF-8" ]; then
					iconv -f $CHARSET_DETECT -t UTF-8 "$files" > utf-8-"$files"
					mkdir SUB_BACKUP 2> /dev/null
					mv "$files" SUB_BACKUP/"$files".back
					mv -f utf-8-"$files" "$files"
				fi
			fi
		done
	fi

	# Merge
	mkvmerge -o "${LSTVIDEO[0]%.*}"."$videoformat".mkv "${LSTVIDEO[0]}" $MERGE_LSTAUDIO $MERGE_LSTSUB

	END=$(date +%s)                         # End time counter
	
	# Check Target if valid (size test)
	filesPass=()
	filesReject=()
	if [[ $(stat --printf="%s" "${LSTVIDEO%.*}"."$videoformat".mkv 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
		filesPass+=("${LSTVIDEO%.*}"."$videoformat".mkv)
	else																	# if file<30 KBytes rejected
		filesReject+=("${LSTVIDEO%.*}"."$videoformat".mkv)
	fi

	# Make statistics of processed files
	DIFFS=$(($END-$START))
	NBVO="${#filesPass[@]}"
	TSSIZE=$(du -chsm "${filesPass[@]}" | tail -n1 | awk '{print $1;}')		# Target(s) size

	# End encoding messages
	echo
	echo " -----------------------------------------------------"
	echo " $NBVO file(s) have been processed."
	if test -n "$filesPass"; then
		echo " File(s) created:"
		printf '  %s\n' "${filesPass[@]}"
	fi
	if test -n "$filesReject"; then
		echo " File(s) in error:"
		printf '  %s\n' "${filesReject[@]}"
	fi
	echo " -----------------------------------------------------"
	echo " Created file(s) size: $TSSIZE MB."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo
}
VideoSourceInfo() {				# Video source stats
	# Add all stats in temp.stat.info
	ffprobe -analyzeduration 1G -probesize 1G -i "${LSTVIDEO[0]}" 2> "$FFMES_CACHE"/temp.stat.info

	# Grep stream in stat.info
	< "$FFMES_CACHE"/temp.stat.info grep Stream > "$FFMES_CACHE_STAT"

	# Remove line with "Guessed Channel" (not used)
	sed -i '/Guessed Channel/d' "$FFMES_CACHE_STAT"

	# Probe audio stream (use in custom audio)
	probeaudio=$(< "$FFMES_CACHE_STAT" grep audio)

	# Count line = number of streams, and set variable associate
	nbstream=$(wc -l "$FFMES_CACHE_STAT" | awk '{print $1;}')

	# Add fps unit
	sed -i '1s/fps.*//' "$FFMES_CACHE_STAT"
	sed -i '1s/$/fps/' "$FFMES_CACHE_STAT"

	# Grep & add source duration
	SourceDuration=$(< $FFMES_CACHE/temp.stat.info grep Duration)
	sed -i '1 i\  '"$SourceDuration"'' "$FFMES_CACHE_STAT"

	# Grep source size, chapter number && add file name, size, chapter number
	ChapterNumber=$(< $FFMES_CACHE/temp.stat.info grep Chapter | tail -1 | awk '{print $4, "chapters"}')
	SourceSize=$(wc -c "${LSTVIDEO[0]}" | awk '{print $1;}' | awk '{ foo = $1 / 1024 / 1024 ; print foo }')
	sed -i '1 i\    '"$LSTVIDEO, size: $SourceSize MB, $ChapterNumber"'' "$FFMES_CACHE_STAT"

	# Add title & complete formatting
	sed -i '1 i\ Source file stats:' "$FFMES_CACHE_STAT"
	sed -i '1 i\--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"
	sed -i -e '$a--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"

	# Clean temp file
	rm $FFMES_CACHE"/temp.stat.info" &>/dev/null

	# Grep interlaced, hdr, and width/height, Overall bit rate of source (with mediainfo)
	INTERLACED=$(mediainfo --Inform="Video;%ScanType/String%" "${LSTVIDEO[0]}")
	HDR=$(mediainfo --Inform="Video;%HDR_Format/String%" "${LSTVIDEO[0]}")
	SWIDTH=$(mediainfo --Inform="Video;%Width%" "${LSTVIDEO[0]}")
	SHEIGHT=$(mediainfo --Inform="Video;%Height%" "${LSTVIDEO[0]}")
}
VideoAudioSourceInfo() {		# Video source stats / Audio only with stream order
	# Add all stats in temp.stat.info
	ffprobe -analyzeduration 1G -probesize 1G -i "${LSTVIDEO[0]}" 2> "$FFMES_CACHE"/temp.stat.info

	# Grep stream in stat.info
	< "$FFMES_CACHE"/temp.stat.info grep Audio > "$FFMES_CACHE_STAT"

	# Add audio stream number
	awk '{$0 = "     Audio Steam:"i++ "    -" OFS $0} 1' "$FFMES_CACHE_STAT" > "$FFMES_CACHE"/temp2.stat.info
	mv "$FFMES_CACHE"/temp2.stat.info "$FFMES_CACHE_STAT"

	# Remove line with "Guessed Channel" (not used)
	sed -i '/Guessed Channel/d' "$FFMES_CACHE_STAT"

	# Grep & add source duration
	SourceDuration=$(< $FFMES_CACHE/temp.stat.info grep Duration)
	sed -i '1 i\  '"$SourceDuration"'' "$FFMES_CACHE_STAT"

	# Grep source size & add file name and size
	SourceSize=$(wc -c "${LSTVIDEO[0]}" | awk '{print $1;}' | awk '{ foo = $1 / 1024 / 1024 ; print foo }')
	sed -i '1 i\    '"$LSTVIDEO, size: $SourceSize MB"'' "$FFMES_CACHE_STAT"

	# Add title & complete formatting
	sed -i '1 i\ Source file stats:' "$FFMES_CACHE_STAT"
	sed -i '1 i\--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"
	sed -i -e '$a--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"

	# Clean temp file
	rm "$FFMES_CACHE"/temp.stat.info &>/dev/null
	rm "$FFMES_CACHE"/temp2.stat.info &>/dev/null
}
DVDRip() {						# Option 0  	- DVD Rip
    clear
    echo
    echo "  DVD rip"
    echo "  notes: * for DVD, launch ffmes in directory without ISO & VOB, if you have more than one drive, insert only one DVD."
    echo "         * for ISO, launch ffmes in directory without VOB (one iso)"
    echo "         * for VOB, launch ffmes in directory with VOB (in VIDEO_TS/)"
    echo
    echo "  ----------------------------------------------------------------------------------------"
	read -p "  Continue? [Y/n]:" q
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
	if [ "$NBVOB" -ge "1" ]; then
		DVD="./"
	elif [ "$NBISO" -eq "1" ]; then
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
	DVDtitle=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null | grep "DVD with title" | tail -1 | awk '{print $NF}' | sed "s/\"//g")
	mapfile -t DVD_TITLES < <(lsdvd "$DVD" 2>/dev/null | grep Title | awk '{print $2}' |  grep -o '[[:digit:]]*') # Use for extract all title

	# Question
	if [ "$NBVOB" -ge "1" ]; then
		echo " $NBVOB file(s) are been detected, choice one or more title to rip:"
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
			MainMenu
			break
		;;
		*)
			echo
			echo "$MESS_INVALID_ANSWER"
			echo
			;;
	esac
	done 

	if [ "$NBVOB" -ge "1" ]; then
		# DVD Title question
		read -e -p "  What is the name of the DVD?: " qdvd
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
		RipFileName=("$DVDtitle"-"$title")

		# Get aspect ratio
		TitleParsed="${title##*0}"
		AspectRatio=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null | grep "The aspect ratio of title set $TitleParsed" | tail -1 | awk '{print $NF}')
		if test -z "$ARatio"; then			# if aspect ratio empty, get main feature aspect
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
		PCM=$(ffprobe -analyzeduration 1G -probesize 1G -v error -show_entries stream=codec_name -print_format csv=p=0 "$RipFileName".VOB | grep pcm_dvd)
		if test -n "$PCM"; then			# pcm_dvd audio track trick
			pcm_dvd="-c:a pcm_s16le"
		fi
		# FFmpeg - clean mkv
		ffmpeg $FFMPEG_LOG_LVL -y -fflags +genpts -analyzeduration 1G -probesize 1G -i "$RipFileName".VOB -map 0:v -map 0:a? -map 0:s? -c copy $pcm_dvd -aspect $AspectRatio "$RipFileName".mkv 2>/dev/null
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
	NBV="${#LSTVIDEO[@]}"

	# encoding question
	if [ "$NBV" -gt "0" ]; then
		echo
		echo " $NBV files are been detected:"
		printf '  %s\n' "${LSTVIDEO[@]}"
		echo
		read -p " Would you like encode it? [y/N]:" q
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
CustomInfoChoice() {			# Option 1  	- Summary of configuration
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
	echo "--------------------------------------------------------------------------------------------------"
	echo
	}
CustomVideoEncod() {			# Option 1  	- Conf video
    CustomInfoChoice
    echo " Encoding or copying the video stream:"           # Video stream choice, encoding or copy
    echo
    echo "  [e] > for encode"
    echo " *[↵] > for copy"
    echo "  [q] > for exit"
    read -e -p "-> " qv
	if [ "$qv" = "q" ]; then
		Restart

	elif [ "$qv" = "e" ]; then							# Start edit video

		ENCODV="1"	# If video encoding

		# Crop
        CustomInfoChoice
        echo " Crop the video?"
		echo " Note: Auto detection is not 100% reliable, a visual check of the video will guarantee it."
        echo
        echo "  [y] > for yes in auto detection mode"
        echo "  [m] > for yes in manual mode (knowing what you are doing is required)"
        echo " *[↵] > for no change"
        echo "  [q] > for exit"
        read -e -p "-> " yn
		case $yn in
			"y"|"Y")
				StartLoading "Crop auto detection in progress"
				cropresult=$(ffmpeg -i "${LSTVIDEO[0]}" -ss 00:03:30 -t 00:04:30 -vf cropdetect -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1 2> /dev/null)  # grep auto crop with ffmpeg
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
				read -e -p "-> " cropresult
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
		echo "  [4] > fot 180°"
        echo " *[↵] > for no change"
        echo "  [q] > for exit"
        while :
		do
		read -e -p "-> " ynrotat
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
			*[1-9]|[5-9]*)
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
        read -e -p "-> " yn
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
        echo " Note: if crop is applied is not recommended to combine the two."
        echo
        echo "  [y] > for yes"
        echo " *[↵] > for no change"
        echo "  [q] > for exit"
        read -e -p "-> " yn
        case $yn in
			"y"|"Y")
				echo " Enter only the width of the video"
				echo " Notes: * Width must be a integer"
				echo "        * Original ratio is respected"
				echo
				echo " [1280] > example for 1280px width"
				echo " [c]    > for no change"
				echo " [q]    > for exit"
				while :
				do
				read -e -p "-> " WIDTH1
				WIDTH=$(echo "$WIDTH1" | cut -f1 -d",")		# remove comma and all after
				case $WIDTH in
					[100-5000]*)
						nbvfilter=$((nbvfilter+1))
						RATIO=$(echo "$SWIDTH/$WIDTH" | bc -l | awk 'sub("\\.*0+$","")')
						HEIGHT=$(echo "$(echo "scale=1;$SHEIGHT/$RATIO" | bc -l | sed '/\./ s/\.\{0,1\}0\{1,\}$//')")		# display decimal only if not integer
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
						DHEIGHT=$(echo "$(echo "scale=0;$SHEIGHT/$RATIO" | bc -l | sed '/\./ s/\.\{0,1\}0\{1,\}$//')")		# not decimal
						chwidth=("$WIDTH"x"$DHEIGHT")
						break
					;;
					"c"|"C")
						echo
						chwidth="No change"
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
        read -e -p "-> " yn
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
		read -e -p "-> " yn
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
		read -e -p "-> " yn
		case $yn in
			"x264")
                codec="libx264 -x264-params colorprim=bt709:transfer=bt709:colormatrix=bt709:fullrange=off -pix_fmt yuv420p"
                chvcodec="x264"
                Confx264_5
			;;
			"x265")
				codec="libx265"
				chvcodec="x265"
				Confx264_5
			;;
			"mpeg4")
				codec="mpeg4 -vtag xvid"
				Confmpeg4
			;;
			"q"|"Q")
				Restart
			;;
			*)
				codec="libx265"
				chvcodec="x265"
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
		filevcodec="vcopy"
		videoconf="-vcodec copy"                                            # Set video variable

	fi

	}
CustomAudioEncod() {			# Option 1  	- Conf audio
	CustomInfoChoice
	echo " Encoding or copying the audio stream(s):"
	echo
	echo "  [e] > for encode stream(s)"
	echo " *[c] > for copy stream(s)"
	echo "  [r] > for no or remove stream(s)"
	echo "  [q] > for exit"
	read -e -p "-> " qa
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
		read -e -p "-> " chacodec
		case $chacodec in
			"opus")
				codeca="libopus"
				ConfOPUS
				ConfChannels
			;;
			"vorbis")
				codeca="libvorbis"
				ConfOGG
				ConfChannels
			;;
			"ac3")
				codeca="ac3"
				ConfAC3
				ConfChannels
			;;
			"flac")
				codeca="flac"
				ConfFLAC
				ConfChannels
			;;
			"q"|"Q")
				Restart
			;;
			*)
				codeca="libopus"
				chacodec="libopus"
				ConfOPUS
				ConfChannels
			;;
		esac

		fileacodec=$chacodec
		soundconf="$afilter -acodec $codeca $akb $confchan"

	else

        chsoundstream="Copy"                              # No audio change
        fileacodec="acopy"
        soundconf="-acodec copy"
	fi
	}
CustomVideoStream() {			# Option 1,2	- Conf stream selection
	if [ "$nbstream" -gt 2 ] ; then				# If $nbstream > 2 = map question
		if [ "$reps" -le 1 ]; then				# Display summary target if in profile 1 or 0
			CustomInfoChoice
		else 									# Display streams stats if no in profile 1 (already make by CustomInfoChoice)
			clear
			echo
			cat "$FFMES_CACHE_STAT"
			echo
		fi

		# Choice Stream
		echo " Select video, audio(s) & subtitle(s) streams, or leave for keep unchanged:"
		echo " Notes: * The order of the streams you specify will be the order of in final file."
		echo "        * Remove data stream for not have any encoding issue."
		if test -z $probeaudio && [ "$qa" = "r" ]; then						# Alert if remove audio selected
			echo
			echo -e "      [!] Be careful you have selected previously no audio stream, do not \e[1m\033[31mmap\033[0m them."
		fi
		echo
		echo "  [map 0 3 1] > Example of input format for select stream"
		echo " *[enter]     > for no change"
		echo "  [q]         > for exit"
		read -e -p "-> " rpstreamch
		if [ "$rpstreamch" = "q" ]; then
			Restart
		elif echo $rpstreamch | grep -q 'map' ; then
			echo "$rpstreamch" | sed 's/.\{4\}//' > $FFMES_CACHE_MAP		# remove map in variable
			sed -i 's/ /\n/g' $FFMES_CACHE_MAP								# make multiline
			sed -i 's/^/0:/' $FFMES_CACHE_MAP								# add 0:
			sed -i 's/^/-map /' $FFMES_CACHE_MAP							# add -map
			sed -i ':a;N;$!ba;s/\n/ /g' $FFMES_CACHE_MAP					# all in one line
			stream=$(cat $FFMES_CACHE_MAP)									# set map variable
			if [ "$extcont" = mkv ]; then
				subtitleconf="-codec:s copy"								# mkv subtitle variable
			elif [ "$extcont" = mp4 ]; then
				subtitleconf="-codec:s mov_text"							# mp4 subtitle variable
			fi
		elif [ "$extcont" = mkv ]; then
			stream="-map 0"													# if mkv keep all stream
			subtitleconf="-codec:s copy"									# mkv subtitle variable
		elif [ "$extcont" = mp4 ]; then
			stream="-map 0"													# if mkv keep all stream
			subtitleconf="-codec:s mov_text"								# mp4 subtitle variable
		fi
	else																	# If $nbstream <= 2
		if [ "$reps" -le 1 ]; then											# Refresh summary $nbstream <= 2
				CustomInfoChoice
		fi
		if [ "$extcont" = mkv ]; then
			stream="-map 0"													# if mkv keep all stream
			subtitleconf="-codec:s copy"									# mkv subtitle variable
		elif [ "$extcont" = mp4 ]; then
			stream="-map 0"													# if mkv keep all stream
			subtitleconf="-codec:s mov_text"								# mp4 subtitle variable
		else
			stream=""
		fi
	fi

	# Set file name if $videoformat variable empty
    if test -z "$videoformat"; then
        videoformat=$filevcodec.$fileacodec
    fi
	}
CustomVideoContainer() {		# Option 1  	- Conf container mkv/mp4
	CustomInfoChoice
	echo " Choose container:"
	echo
	echo " *[mkv] > for mkv"
	echo "  [mp4] > for mp4"
	echo "  [q]   > for exit"
	read -e -p "-> " chcontainer
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
	}
Confmpeg4() {					# Option 1  	- Conf Xvid 
	CustomInfoChoice
	echo " Choose a number OR enter the desired bitrate:"
	echo
	echo "$MESS_SEPARATOR"
	echo " [1200k] -> Example of input format for desired bitrate"
	echo
	echo "  [1] > for qscale 1   |"
	echo "  [2] > for qscale 5   |HD"
	echo " *[3] > for qscale 10  |"
	echo "  [4] > for qscale 15  -"
	echo "  [5] > for qscale 20  |"
	echo "  [6] > for qscale 15  |SD"
	echo "  [7] > for qscale 30  |"
	read -e -p "-> " rpvkb
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
Confx264_5() {					# Option 1  	- Conf x264/x265
	# Preset x264/x265
	CustomInfoChoice
	echo " Choose the preset:"
	echo
	echo "  ----------------------------------------------> Encoding Speed"
	echo "  veryfast - faster - fast -  medium - slow* - slower - veryslow"
	echo "  -----------------------------------------------------> Quality"
	read -e -p "-> " reppreset
	if test -n "$reppreset"; then
		preset="-preset $reppreset"
		chpreset="$reppreset"
	else
		preset="-preset medium"
		chpreset="slow"
	fi

	# Tune x264/x265
	CustomInfoChoice
	if [ "$chvcodec" = "x264" ]; then
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
		read -e -p " -> " reptune
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
	elif [ "$chvcodec" = "x265" ]; then
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
		read -e -p "-> " reptune
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
    if [ "$chvcodec" = "x264" ]; then
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
		read -e -p "-> " repprofile
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
	elif [ "$chvcodec" = "x265" ]; then
		echo " Choose a profile or make your profile manually:"
		echo " Notes: * For bit and chroma settings, if the source is below the parameters, FFmpeg will not replace them but will be at the same level."
		echo "        * The level (lvl) parameter must be chosen judiciously according to the bit rate of the source file and the result you expect."
		echo "        * The choice of the profile affects the player compatibility of the result."
		echo
		echo
		echo "$MESS_SEPARATOR"
		echo " Manually options (expert):"
		echo "  * 8bit profiles: main, main-intra, main444-8, main444-intra"
		echo "  * 10bit profiles: main10, main10-intra, main422-10, main422-10-intra, main444-10, main444-10-intra"
		echo "  * 12bit profiles: main12, main12-intra, main422-12, main422-12-intra, main444-12, main444-12-intra"
		echo "  * Level: 1, 2, 2.1, 3.1, 4, 4.1, 5, 5.1, 5.2, 6, 6.1, 6.2"
		echo "  * High level: high-tier=1"
		echo "  * No high level: no-high"
		echo " [-profile:v main -x265-params level=3.1:no-high-tier] -> Example of input format for manually profile"
		echo
		echo "$MESS_SEPARATOR"
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
		read -e -p "-> " repprofile
		if echo "$repprofile" | grep -q 'profil'; then
				profile="$repprofile"
				chprofile="$repprofile"
		elif [ "$repprofile" = "1" ]; then
				profile="-profile:v main -x265-params "$X265_LOG_LVL"level=3.1 -pix_fmt yuv420p"
				chprofile="3.1 - 8 bit - 4:2:0"
		elif [ "$repprofile" = "2" ]; then
				profile="-profile:v main -x265-params "$X265_LOG_LVL"level=4.1 -pix_fmt yuv420p"
				chprofile="4.1 - 8 bit - 4:2:0"
		elif [ "$repprofile" = "3" ]; then
				profile="-profile:v main -x265-params "$X265_LOG_LVL"level=4.1:high-tier=1 -pix_fmt yuv420p"
				chprofile="4.1 - 8 bit - 4:2:0"
		elif [ "$repprofile" = "4" ]; then
				profile="-profile:v main444-12 -x265-params "$X265_LOG_LVL"level=4.1:high-tier=1 -pix_fmt yuv420p12le"
				chprofile="4.1 - 12 bit - 4:4:4"
		elif [ "$repprofile" = "5" ]; then
				profile="-profile:v main444-12 -x265-params "$X265_LOG_LVL"level=4.1:high-tier=1:hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,10) -pix_fmt yuv420p12le"
				chprofile="4.1 - 12 bit - 4:4:4 - HDR"
		elif [ "$repprofile" = "6" ]; then
				profile="-profile:v main444-12-intra -x265-params "$X265_LOG_LVL"level=4.1:high-tier=1 -pix_fmt yuv420p12le"
				chprofile="4.1 - 12 bit - 4:4:4 - intra"
		elif [ "$repprofile" = "7" ]; then
				profile="-profile:v main -x265-params "$X265_LOG_LVL"level=5.2:high-tier=1 -pix_fmt yuv420p"
				chprofile="5.2 - 8 bit - 4:2:0"
		elif [ "$repprofile" = "8" ]; then
				profile="-profile:v main444-12 -x265-params "$X265_LOG_LVL"level=5.2:high-tier=1 -pix_fmt yuv420p12le"
				chprofile="5.2 - 12 bit - 4:4:4"
		elif [ "$repprofile" = "9" ]; then
				profile="-profile:v main444-12 -x265-params "$X265_LOG_LVL"level=5.2:high-tier=1:hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,10) -pix_fmt yuv420p12le"
				chprofile="5.2 - 12 bit - 4:4:4 - HDR"
		elif [ "$repprofile" = "10" ]; then
				profile="-profile:v main444-12-intra -x265-params "$X265_LOG_LVL"level=5.2:high-tier=1 -pix_fmt yuv420p12le"
				chprofile="5.2 - 12 bit - 4:4:4 - intra"
		elif [ "$repprofile" = "11" ]; then
				profile="-profile:v main444-12 -x265-params "$X265_LOG_LVL"level=6.2:high-tier=1 -pix_fmt yuv420p12le"
				chprofile="6.2 - 12 bit - 4:4:4"
		elif [ "$repprofile" = "12" ]; then
				profile="-profile:v main444-12 -x265-params "$X265_LOG_LVL"level=6.2:high-tier=1:hdr-opt=1:repeat-headers=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,10) -pix_fmt yuv420p12le"
				chprofile="6.2 - 12 bit - 4:4:4 - HDR"
		elif [ "$repprofile" = "13" ]; then
				profile="-profile:v main444-12-intra -x265-params "$X265_LOG_LVL"level=6.2:high-tier=1 -pix_fmt yuv420p12le"
				chprofile="6.2 - 12 bit - 4:4:4 - intra"
		else
				profile="-profile:v main -x265-params "$X265_LOG_LVL"level=4.1:high-tier=1 -pix_fmt yuv420p"
				chprofile="High 4.1 - 8 bit - 4:2:0"
		fi
	fi

	# Bitrate x264/x265
	CustomInfoChoice
	echo " Choose a number or enter the desired bitrate:"
	echo " Note: This settings influences size and quality, crf is a better choise in 90% of cases."
	echo
	echo "$MESS_SEPARATOR"
	echo " [1200k]     Example of input format for cbr desired bitrate"
	echo " [-crf 21]   Example of input format for crf desired level"
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
	read -e -p "-> " rpvkb
	if echo $rpvkb | grep -q 'k'; then
		vkb="-b:v $rpvkb"
	elif echo $rpvkb | grep -q 'crf'; then
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
ConcatenateVideo() {			# Option 12 	- Concatenate video
	clear
	echo
	echo " Concatenate video files?"
	echo " Note: * Before you start, make sure that the files all have the same height/width, codecs and bitrates."
	echo
	echo " Files to concatenate:"
	printf '  %s\n' "${LSTVIDEO[@]}"
	echo
	echo " *[↵] > for continue"
	echo "  [q] > for exit"
	read -e -p "-> " concatrep
	if [ "$concatrep" = "q" ]; then
			Restart
	else
		# Start time counter
		START=$(date +%s)
		
		# List file to contatenate
		for files in "${LSTVIDEO[@]}"; do
			quote0="'"
			quote1="'\\\\\\''"
			parsedFile=$(echo "$files" | sed "s/$quote0/$quote1/g")
			echo "file '$parsedFile'" >> concat-list.info
		done

		# Concatenate
		ffmpeg $FFMPEG_LOG_LVL -f concat -safe 0 -i concat-list.info -map 0 -c copy Concatenate-Output."${LSTVIDEO[0]##*.}"

		# Clean
		rm concat-list.info

		# End time counter
		END=$(date +%s)

		# Check Target if valid (size test)
		filesPass=()
		filesReject=()
		if [ "$(stat --printf="%s" Concatenate-Output."${LSTVIDEO[0]##*.}")" -gt 30720 ]; then		# if file>30 KBytes accepted
			filesPass+=(Concatenate-Output."${LSTVIDEO[0]##*.}")
		else																	# if file<30 KBytes rejected
			filesReject+=(Concatenate-Output."${LSTVIDEO[0]##*.}")
		fi

		# Make statistics of processed files
		DIFFS=$(($END-$START))															# counter in seconds
		NBVO="${#filesPass[@]}"															# Count file(s) passed
		if [ "$NBVO" -eq 0 ] ; then
			SSIZVIDEO="0"
			TSSIZE="0"
			PERC="0"
		else
			SSIZVIDEO=$(du -chsm "${LSTVIDEO[@]}" | tail -n1 | awk '{print $1;}')			# Source file(s) size
			TSSIZE=$(du -chsm "${filesPass[@]}" | tail -n1 | awk '{print $1;}')				# Target(s) size
			PERC=$(bc <<< "scale=2; ($TSSIZE - $SSIZVIDEO)/$SSIZVIDEO * 100")				# Size difference between source and target
		fi

		# End: encoding messages
		echo
		echo " -----------------------------------------------------"
		if test -n "$filesPass"; then
			echo " File(s) created:"
			printf '  %s\n' "${filesPass[@]}"
		fi
		if test -n "$filesReject"; then
			echo " File(s) in error:"
			printf '  %s\n' "${filesReject[@]}"
		fi
		echo " -----------------------------------------------------"
		echo " Created file(s) size: $TSSIZE MB, a difference of $PERC% from the source(s) ($SSIZVIDEO MB)."
		echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
		echo " -----------------------------------------------------"
		echo
		
		
		# Next encoding question
		read -p "You want encoding concatenating video? [y/N]:" qarm
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
ExtractPartVideo() {			# Option 13 	- Extract stream
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
	read -e -p "-> " rpstreamch
	case $rpstreamch in
	
		"all")
			mapfile -t VINDEX < <(ffprobe -analyzeduration 1G -probesize 1G -v error -show_entries stream=index -print_format csv=p=0 "${LSTVIDEO[0]}")
			mapfile -t VCODECNAME < <(ffprobe -analyzeduration 1G -probesize 1G -v error -show_entries stream=codec_name -print_format csv=p=0 "${LSTVIDEO[0]}")
			break
		;;
		[0-9]*)
			VINDEX=("$rpstreamch")
			# Keep codec used
			mapfile -t VCODECNAME1 < <(ffprobe -analyzeduration 1G -probesize 1G -v error -show_entries stream=codec_name -print_format csv=p=0 "${LSTVIDEO[0]}")
			VCODECNAME=()
			for i in "${VINDEX[@]}"; do
				VCODECNAME+=("${VCODECNAME1[$i]}")
			done
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

		filesPass=()
		filesReject=()
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
					FILE_EXT=sub
					;;
				esac

				StartLoading "" "${files%.*}-Stream-${VINDEX[i]}.$FILE_EXT"
				if [ "$MKVEXTRACT" = "1" ]; then
					mkvextract "$files" tracks "${VINDEX[i]}":"${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" &>/dev/null
				elif [ "$MPEG2EXTRACT" = "1" ]; then
					ffmpeg -y -fflags +genpts -analyzeduration 1G -probesize 1G -i "$files" -c copy -map 0:"${VINDEX[i]}" "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" &>/dev/null
				elif [ "$DVDPCMEXTRACT" = "1" ]; then
					ffmpeg  -y -i "$files" -map 0:"${VINDEX[i]}" -acodec pcm_s16le -ar 48000 "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" &>/dev/null
				else
					ffmpeg  -y -i "$files" -c copy -map 0:"${VINDEX[i]}" "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" &>/dev/null
				fi
				StopLoading $?

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
	DIFFS=$(($END-$START))															# counter in seconds
	NBVO="${#filesPass[@]}"															# Count file(s) passed
	if [ "$NBVO" -eq 0 ]; then
		TSSIZE="0"
	else
		TSSIZE=$(du -chsm "${filesPass[@]}" | tail -n1 | awk '{print $1;}')				# Target(s) size
	fi
	
	# End: encoding messages
	echo
	echo "$MESS_SEPARATOR"
	echo " $NBVO file(s) have been processed."
	if test -n "$filesPass"; then
		echo " File(s) created:"
		printf '  %s\n' "${filesPass[@]}"
	fi
	if test -n "$filesReject"; then
		echo " File(s) in error:"
		printf '  %s\n' "${filesReject[@]}"
	fi
	echo "$MESS_SEPARATOR"
	echo " Created file(s) size: $TSSIZE MB."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo "$MESS_SEPARATOR"
	echo
	}
CutVideo() {					# Option 14 	- Cut video
	clear
    echo
    cat "$FFMES_CACHE_STAT"

    echo " Enter duration of cut:"
    echo " Notes: * for hours :   HOURS:MM:SS.MICROSECONDS"
    echo "        * for minutes : MM:SS.MICROSECONDS"
    echo "        * for seconds : SS.MICROSECONDS"
    echo "        * microseconds is optional, you can not indicate them"
    echo
	echo "$MESS_SEPARATOR"
	echo " Examples of input:"
	echo "  [s.20]       -> remove video after 20 second"
	echo "  [e.01:11:20] -> remove video before 1 hour 11 minutes 20 second"
	echo
	echo "$MESS_SEPARATOR"
    echo
    echo "  [s.time]      > for remove end"
    echo "  [e.time]      > for remove start"
    echo "  [t.time.time] > for remove start and end"
    echo "  [q]           > for exit"
	while :
	do
	read -e -p "-> " qcut0
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
	ffmpeg $FFMPEG_LOG_LVL -y -i "${LSTVIDEO[0]}" -ss "$CutStart" -to "$CutEnd" -c copy -map 0 -map_metadata 0 "${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}"

	# End time counter
	END=$(date +%s)

	# Check Target if valid (size test)
	filesPass=()
	filesReject=()
	if [ "$(stat --printf="%s" "${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}")" -gt 30720 ]; then		# if file>30 KBytes accepted
		filesPass+=("${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}")
	else																	# if file<30 KBytes rejected
		filesReject+=("${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}")
		fi

	# Make statistics of processed files
	DIFFS=$(($END-$START))															# Counter in seconds
	NBVO="${#filesPass[@]}"															# Count file(s) passed
	if [ "$NBVO" -eq 0 ] ; then
		SSIZVIDEO="0"
		TSSIZE="0"
		PERC="0"
	else
		SSIZVIDEO=$(du -chsm "${LSTVIDEO[@]}" | tail -n1 | awk '{print $1;}')			# Source file(s) size
		TSSIZE=$(du -chsm "${filesPass[@]}" | tail -n1 | awk '{print $1;}')				# Target(s) size
		PERC=$(bc <<< "scale=2; ($TSSIZE - $SSIZVIDEO)/$SSIZVIDEO * 100")				# Size difference between source and target
	fi

	# End: encoding messages
	echo
	echo " -----------------------------------------------------"
	if test -n "$filesPass"; then
		echo " File(s) created:"
		printf '  %s\n' "${filesPass[@]}"
	fi
	if test -n "$filesReject"; then
		echo " File(s) in error:"
		printf '  %s\n' "${filesReject[@]}"
	fi
	echo " -----------------------------------------------------"
	echo " Created file(s) size: $TSSIZE MB, a difference of $PERC% from the source(s) ($SSIZVIDEO MB)."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo
}
AddAudioNightNorm() {			# Option 15 	- Add audio stream with night normalization in opus/stereo/350kb
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
	read -e -p "-> " rpstreamch
	case $rpstreamch in
	
		[0-9])
			VINDEX=("$rpstreamch")
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

		filesPass=()
		filesReject=()
		for i in ${!VINDEX[*]}; do

			echo "FFmpeg processing: ${files%.*}-NightNorm.mkv"
			# Encoding new track
			ffmpeg  $FFMPEG_LOG_LVL -y -i "$files" -map 0:v -c:v copy -map 0:s? -c:s copy -map 0:a -map 0:a:${VINDEX[i]}? -c:a copy -metadata:s:a:${VINDEX[i]} title="Opus 2.0 Night Mode" -c:a:${VINDEX[i]} libopus  -b:a:${VINDEX[i]} 320K -ac 2 -filter:a:${VINDEX[i]} acompressor=threshold=0.031623:attack=200:release=1000:detection=0,loudnorm "${files%.*}"-NightNorm.mkv
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
	DIFFS=$(($END-$START))															# counter in seconds
	NBVO="${#filesPass[@]}"															# Count file(s) passed
	if [ "$NBVO" -eq 0 ]; then
		TSSIZE="0"
	else
		TSSIZE=$(du -chsm "${filesPass[@]}" | tail -n1 | awk '{print $1;}')				# Target(s) size
	fi
	
	# End: encoding messages
	echo
	echo "$MESS_SEPARATOR"
	echo " $NBVO file(s) have been processed."
	if test -n "$filesPass"; then
		echo " File(s) created:"
		printf '  %s\n' "${filesPass[@]}"
	fi
	if test -n "$filesReject"; then
		echo " File(s) in error:"
		printf '  %s\n' "${filesReject[@]}"
	fi
	echo "$MESS_SEPARATOR"
	echo " Created file(s) size: $TSSIZE MB."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo "$MESS_SEPARATOR"
	echo
	}
SplitByChapter() {				# Option 16 	- Split by chapter
	clear
	echo
	cat "$FFMES_CACHE_STAT"
	read -p " Split by chapter, continue? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			mkvmerge -o "${LSTVIDEO[0]%.*}"-Chapter.mkv --split chapters:all "${LSTVIDEO[0]}"
		;;
		*)
			Restart
		;;
	esac
}
DVDSubColor() {					# Option 17 	- Change color of DVD sub
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
	read -e -p "-> " rpspalette
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
DVDSub2Srt() {					# Option 18 	- DVD sub to srt
clear
echo
echo " Select subtitle language for:"
printf '  %s\n' "${LSTSUB[@]}"
echo
echo "  [0] > eng     - english"
echo "  [1] > fra     - french"
echo "  [2] > deu     - deutsch"
echo "  [3] > spa     - spanish"
echo "  [4] > por     - portuguese"
echo "  [5] > ita     - italian"
echo "  [6] > jpn     - japan"
echo "  [7] > chi-sim - chinese simplified"
echo "  [8] > arabic  - ara"
echo "  [q] > for exit"
while :
do
read -e -p "-> " rpspalette
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

# Convert loop
for files in "${LSTSUB[@]}"; do

	# Extract tiff
	StartLoading "${files%.*}: Extract tiff files"
	subp2tiff --sid=0 -n "${files%.*}" &>/dev/null
	StopLoading $?

	# Convert tiff in text
	TOTAL=$(ls *.tif | wc -l)
	for tfiles in *.tif; do
		(
		tesseract  "$tfiles" "$tfiles" -l "$SubLang" &>/dev/null
		) &
		if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
			wait -n
		fi
		# Counter
		TIFF_NB=$(($COUNTER+1))
		COUNTER=$TIFF_NB
		# Print eta
		echo -ne "  $COUNTER/$TOTAL tiff converted in text files"\\r
	done
	wait

	StartLoading "${files%.*}: Convert text files in srt"
	# Convert text in srt
	subptools -s -w -t srt -i "${files%.*}".xml -o "${files%.*}".srt &>/dev/null
	# Remove ^L/\f/FF/form-feed/page-break character
	sed -i 's/\o14//g' "${files%.*}".srt &>/dev/null
	StopLoading $?
done

# Clean
rm *.tif &>/dev/null
rm *.txt &>/dev/null
rm *.xml &>/dev/null
	}
MultipleVideoExtention() {		# Sources video multiple extention question
	if [ "$NBVEXT" -gt "1" ]; then
		echo
		echo " Different source video file extensions have been found, would you like to select one or more?"
		echo " Note: * It is recommended not to batch process different sources, in order to control the result as well as possible."
		echo
		echo " Extensions found: $(echo "${LSTVIDEOEXT[@]}")"
		echo
		echo "  [avi]     > Example of input format for select one extension"
		echo "  [mkv|mp4] > Example of input format for multiple selection"
		echo " *[↵]       > for no selection"
		echo "  [q]       > for exit"
		read -e -p "-> " VIDEO_EXT_AVAILABLE
		if [ "$VIDEO_EXT_AVAILABLE" = "q" ]; then
			Restart
		elif test -n "$VIDEO_EXT_AVAILABLE"; then
			mapfile -t LSTVIDEO < <(find . -maxdepth 1 -type f -regextype posix-egrep -regex '.*\.('$VIDEO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
			NBV="${#LSTVIDEO[@]}"
		fi
	fi
}
RemoveVideoSource() {			# Clean video source
	if [ "$NBVO" -gt 0 ] ; then
		read -p " Remove source video? [y/N]:" qarm
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
## AUDIO SECTION
AudioSourceInfo() {				# Audio source stats
	# Add all stats in temp.stat.info
	ffprobe -analyzeduration 100M -probesize 100M -i "${LSTAUDIO[0]}" 2> "$FFMES_CACHE"/temp.stat.info

	# Grep stream in stat.info
	< "$FFMES_CACHE"/temp.stat.info grep Stream > "$FFMES_CACHE_STAT"

	# Remove line with "Guessed Channel" (not used)
	sed -i '/Guessed Channel/d' "$FFMES_CACHE_STAT"

	# Add fps unit
	sed -i '1s/fps.*//' "$FFMES_CACHE_STAT"
	sed -i '1s/$/fps/' "$FFMES_CACHE_STAT"

	# Grep & Add source duration
	SourceDuration=$(< $FFMES_CACHE/temp.stat.info grep Duration)
	sed -i '1 i\  '"$SourceDuration"'' "$FFMES_CACHE_STAT"

	# Grep source size & add file name and size
	SourceSize=$(wc -c "$LSTAUDIO" | awk '{print $1;}' | awk '{ foo = $1 / 1024 / 1024 ; print foo }')
	sed -i '1 i\    '"$LSTAUDIO, size: $SourceSize MB"'' "$FFMES_CACHE_STAT"

	# Grep audio db peak & add
	LineDBPeak=$(cat "$FFMES_CACHE_STAT" | grep -nE -- ".*Stream.*.*Audio.*" | cut -c1)
	TestDBPeak=$(ffmpeg -analyzeduration 100M -probesize 100M -i "${LSTAUDIO[0]}" -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
	sed -i "${LineDBPeak}s/.*/& , DB peak:$TestDBPeak/" "$FFMES_CACHE_STAT"

	# Add title & complete formatting
	sed -i '1 i\ Source file stats:' "$FFMES_CACHE_STAT"                             # Add title
	sed -i '1 i\--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"
	sed -i -e '$a--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"

	# Clean temp file
	rm $FFMES_CACHE"/temp.stat.info" &>/dev/null
}
SplitCUE() {					# Option 22 	- CUE Splitter to flac
	if [ "$NBCUE" -eq "0" ]; then                                         # If 0 cue
		echo "  No CUE file in the working directory"
		echo
	elif [ "$NBCUE" -gt "1" ]; then                                       # If more than 1 cue
		echo "  More than one CUE file in working directory"
		echo
	elif [ "$NBCUE" -eq "1" ] & [ "$NBA" -eq "1" ]; then                  # One cue and audio file supported
		
		# Start time counter
		START=$(date +%s)
		
		CHARSET_DETECT=$(uchardet "${LSTCUE[0]}" 2> /dev/null)
		if [ "$CHARSET_DETECT" != "UTF-8" ]; then
			iconv -f $CHARSET_DETECT -t UTF-8 "${LSTCUE[0]}" > utf-8.cue
			mkdir BACK 2> /dev/null
			mv "${LSTCUE[0]}" BACK/"${LSTCUE[0]}".back
			mv -f utf-8.cue "${LSTCUE[0]}"
		fi

		shntool split "${LSTAUDIO[0]}" -t "%n - %t" -f "${LSTCUE[0]}" -o flac

		# Clean
		rm 00*.flac 2> /dev/null
		cuetag "${LSTCUE[0]}" *.flac 2> /dev/null
		if [ ! -d BACK/ ]; then
			mkdir BACK 2> /dev/null
		fi
		mv "${LSTAUDIO[0]}" BACK/ 2> /dev/null
		mv "${LSTCUE[0]}" BACK/ 2> /dev/null

		# End time counter
		END=$(date +%s)
		
		# Check Target
		mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('flac')$' 2>/dev/null | sort | sed 's/^..//')

		# Make statistics of processed files
		DIFFS=$(($END-$START))
		NBAO="${#LSTAUDIO[@]}"
		if [ "$NBAO" -eq 0 ] ; then
			TSSIZE="0"
		else
			TSSIZE=$(du -chsm "${LSTAUDIO[@]}" | tail -n1 | awk '{print $1;}')		# Target(s) size
		fi

		# End encoding messages
		echo
		echo "$MESS_SEPARATOR"
		echo " $NBAO file(s) have been processed."
		if test -n "$LSTAUDIO"; then
			echo " File(s) created:"
			printf '  %s\n' "${LSTAUDIO[@]}"
		fi
		echo "$MESS_SEPARATOR"
		echo " Created file(s) size: $TSSIZE MB."
		echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
		echo "$MESS_SEPARATOR"
	echo
	
	fi
}
CDRip() {						# Option 20 	- Audio CD Rip with abcde
if command -v abcde &>/dev/null; then						# If abcde installed
	clear
	echo
    echo " Audio CD rip"
    echo " Notes: * abcde is used for rip audio CD"
    echo "        * if you have more than one drive, insert only one CDROM."
    echo "        * temporary & finals files extracted in \"$ABCDE_EXTRACT\" directory"
    echo
    echo "$MESS_SEPARATOR"
    echo " Choose desired option:"
    echo
    echo "        | codec |  quality |"
    echo "        |-------|----------|"
    echo " *[1] > |  flac | lossless |"
    echo "  [2] > |   ogg |    500kb |"
    echo "  [3] > |  opus |    256kb |"
    echo "  [4] > |   mp3 |    320kb |"
    echo "  [q] > |  quit"
    echo
		while :
		do
		read -e -p "-> " rpripcd
		case $rpripcd in
			"1"|"")
				cdripcodec="flac"
				break
			;;
			"2")
				cdripcodec="ogg:-q 10"
				break
			;;
			"3")
				cdripcodec="opus:--vbr --bitrate 256"
				break
			;;
			"4")
				cdripcodec="mp3:-b 320"
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

	abcde -o "$cdripcodec" -a default,getalbumart -N -f -d "$DVD_DEVICE" -c "$ABCDE_CONF"

else
	echo
	echo "	abcde is not present, install it for audio CD Rip"
	echo
fi
}
FFmpeg_audio_cmd() {			# FFmpeg audio encoding command
	# Start time counter
	START=$(date +%s)

	# Message
	echo
	echo "$MESS_SEPARATOR"
	echo " File(s) in processing:"

	# Copy $extcont for test and reset inside loop
	ExtContSource="$extcont"
	# Set files overwrite array
	filesOverwrite=()

	# Encoding
	stty igncr									# Disable the enter key
	for files in "${LSTAUDIO[@]}"; do
		# Reset $extcont
		extcont="$ExtContSource"
		# Test Volume and set normalization variable
		if [ "$PeakNorm" = "1" ]; then
			TESTDB=$(ffmpeg -i "$files" -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
			if [ -n "$afilter" ] && [[ "$codeca" = "libopus" || "$AudioCodecType" = "Opus" ]]; then			# Opus trick for peak normalization
				if [[ $TESTDB = *"-"* ]]; then
					GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
					afilter="-af aformat=channel_layouts='7.1|6.1|5.1|stereo',volume=$GREPVOLUME -mapping_family 1"
				else
					afilter="-af aformat=channel_layouts='7.1|6.1|5.1|stereo' -mapping_family 1"
				fi
			else
				if [[ $TESTDB = *"-"* ]]; then
					GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
					afilter="-af volume=$GREPVOLUME"
				else
					afilter=""
				fi
			fi
		fi
		# Channel test mono or stereo
		if [ "$TestFalseStereo" = "1" ]; then
			TESTLEFT=$(ffmpeg -i "$files" -map_channel 0.0.0 -f md5 - 2>/dev/null)
			TESTRIGHT=$(ffmpeg -i "$files" -map_channel 0.0.1 -f md5 - 2>/dev/null)
			if [ "$TESTLEFT" = "$TESTRIGHT" ]; then
				confchan="-channel_layout mono"
			else
				confchan=""
			fi
		fi
		# Silence detect & remove, at start & end (only for wav and flac source files)
		if [ "$SilenceDetect" = "1" ]; then
			if [[ "${files##*.}" = "wav" || "${files##*.}" = "flac" ]]; then
				TEST_DURATION=$(mediainfo --Output="General;%Duration%" "${files%.*}"."${files##*.}")
				if [[ "$TEST_DURATION" -gt 10000 ]] ; then
					sox "${files%.*}"."${files##*.}" temp-out."${files##*.}" silence -l 1 0.1 0.01% -1 2.0 0.01%
					rm "${files%.*}"."${files##*.}" &>/dev/null
					mv temp-out."${files##*.}" "${files%.*}"."${files##*.}" &>/dev/null
				fi
			fi
		fi
		# Opus auto adapted bitrate
		if [ "$AdaptedBitrate" = "1" ]; then
			TestBitrate=$(mediainfo --Output="General;%OverallBitRate%" "$files")
			if [ "$TestBitrate" -ge 1 ] && [ "$TestBitrate" -le 96000 ]; then
				akb="-b:a 64K"
			elif [ "$TestBitrate" -ge 96001 ] && [ "$TestBitrate" -le 128000 ]; then
				akb="-b:a 96K"
			elif [ "$TestBitrate" -ge 129000 ] && [ "$TestBitrate" -le 160000 ]; then
				akb="-b:a 128K"
			elif [ "$TestBitrate" -ge 161000 ] && [ "$TestBitrate" -le 192000 ]; then
				akb="-b:a 160K"
			elif [ "$TestBitrate" -ge 193000 ] && [ "$TestBitrate" -le 256000 ]; then
				akb="-b:a 192K"
			elif [ "$TestBitrate" -ge 257000 ] && [ "$TestBitrate" -le 280000 ]; then
				akb="-b:a 220K"
			elif [ "$TestBitrate" -ge 281000 ] && [ "$TestBitrate" -le 320000 ]; then
				akb="-b:a 256K"
			elif [ "$TestBitrate" -ge 321000 ] && [ "$TestBitrate" -le 400000 ]; then
				akb="-b:a 280K"
			elif [ "$TestBitrate" -ge 400001 ]; then
				akb="-b:a 320K"
			else
				akb="-b:a 320K"
			fi
			soundconf="$acodec $akb"
		fi
		# Stream set & cover extract
		if [ "$ExtractCover" = "0" ] && [ ! -f cover.* ]; then
			ffmpeg -n -i "$files" "${files%.*}".jpg 2> /dev/null
			mv "${files%.*}".jpg "${files%/*}"/cover.jpg 2>/dev/null
			mv "${files%.*}".jpg cover.jpg 2>/dev/null
			stream="-map 0:a"
		elif [ "$ExtractCover" = "1" ] && [ "$AudioCodecType" != "Opus" ]; then
			stream="-map 0"
		else
			stream="-map 0:a"
		fi
		StartLoading "" "$files"
		# Stock files pass in loop
		filesInLoop+=("$files")					# Populate array
		# If source extention same as target
		if [[ "${files##*.}" = "$extcont" ]]; then
			extcont="new.$extcont"
			filesOverwrite+=("$files")			# Populate array
		else
			filesOverwrite+=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')		# Populate array with random strimg
		fi
		# Encoding
		(
		ffmpeg -y -i "$files" $afilter $stream $confchan $soundconf "${files%.*}".$extcont &>/dev/null
		StopLoading $?
		) &
		if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
			wait -n
		fi
	done
	wait
	stty -igncr									# Enable the enter key

	# End time counter
	END=$(date +%s)

	# Check Target if valid (size test) and clean
	extcont="$ExtContSource"	# Reset $extcont
	filesPass=()				# Files pass
	filesReject=()				# Files fail
	filesSourcePass=()			# Source files pass
	#for files in "${LSTAUDIO[@]}"; do
	for (( i=0; i<=$(( ${#filesInLoop[@]} -1 )); i++ )); do
		if [[ "${filesInLoop[i]%.*}" = "${filesOverwrite[i]%.*}" ]]; then										# If file overwrite
			if [[ $(stat --printf="%s" "${filesInLoop[i]%.*}".new.$extcont 2>/dev/null) -gt 30720 ]]; then		# If file>30 KBytes accepted
				mv "${filesInLoop[i]}" "${filesInLoop[i]%.*}".back.$extcont 2>/dev/null
				mv "${filesInLoop[i]%.*}".new.$extcont "${filesInLoop[i]}" 2>/dev/null
				filesPass+=("${filesInLoop[i]}")
				filesSourcePass+=("${filesInLoop[i]%.*}".back.$extcont)
			else																								# If file<30 KBytes rejected
				filesReject+=("${filesInLoop[i]%.*}".new.$extcont)
				rm "${filesInLoop[i]%.*}".new."$extcont" 2>/dev/null
			fi
		else																									# If no file overwrite
			if [[ $(stat --printf="%s" "${filesInLoop[i]%.*}".$extcont 2>/dev/null) -gt 30720 ]]; then			# If file>30 KBytes accepted
				filesPass+=("${filesInLoop[i]%.*}".$extcont)
				filesSourcePass+=("${filesInLoop[i]}")
			else																								# If file<30 KBytes rejected
				filesReject+=("${filesInLoop[i]%.*}".$extcont)
				rm "${filesInLoop[i]%.*}".$extcont 2>/dev/null
			fi
		fi
	done

	# Make statistics of processed files
	DIFFS=$(($END-$START))
	NBAO="${#filesPass[@]}"
	if [ "$NBAO" -eq 0 ] ; then
		SSIZAUDIO="0"
		TSSIZE="0"
		PERC="0"
	else
		SSIZAUDIO=$(du -chsm "${filesSourcePass[@]}" | tail -n1 | awk '{print $1;}')
		TSSIZE=$(du -chsm "${filesPass[@]}" | tail -n1 | awk '{print $1;}')		# Target(s) size
		PERC=$(bc <<< "scale=2; ($TSSIZE - $SSIZAUDIO)/$SSIZAUDIO * 100")
	fi

	# End encoding messages
	echo "$MESS_SEPARATOR"
	if test -n "$filesPass"; then
		echo " File(s) created:"
		printf '  %s\n' "${filesPass[@]}"
	fi
	if test -n "$filesReject"; then
		echo " File(s) in error:"
		printf '  %s\n' "${filesReject[@]}"
	fi
	echo "$MESS_SEPARATOR"
	echo " $NBAO/$NBA file(s) have been processed."
	echo " Created file(s) size: $TSSIZE MB, a difference of $PERC% from the source(s) ($SSIZAUDIO MB)."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo "$MESS_SEPARATOR"
	echo
}
ConfChannels() {				#
if [ "$reps" -le 1 ]; then          # if profile 0 or 1 display
    CustomInfoChoice
fi
if [[ "$codeca" = "libopus" || "$AudioCodecType" = "Opus" ]]; then
	echo
	echo " Choose desired audio channels configuration:"
	echo " note: * applied to the all audio stream"
	echo "$MESS_SEPARATOR"
	echo
	echo "  [1]  > for channel_layout 1.0 (Mono)"
	echo "  [2]  > for channel_layout 2.0 (Stereo)"
	echo "  [3]  > for channel_layout 3.0 (FL+FR+FC)"
	echo "  [4]  > for channel_layout 5.1 (FL+FR+FC+LFE+BL+BR)"
	echo "  [↵]* > for no change"
	echo "  [q]  > for exit"
	read -e -p "-> " rpchan
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
	echo "$MESS_SEPARATOR"
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
	read -e -p "-> " rpchan
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
ConfPeakNorm() {				# 
echo
read -p " Apply a 0db peak normalization? [y/N]:" qarm
case $qarm in
	"Y"|"y")
		PeakNorm="1"
	;;
	*)
		return
	;;
esac
}
ConfTestFalseStereo() {			# 
read -p " Detect and convert false stereo files in mono? [y/N]:" qarm
case $qarm in
	"Y"|"y")
		TestFalseStereo="1"
	;;
	*)
		return
	;;
esac
}
ConfSilenceDetect() {			# 
TESTWAV=$(echo "${LSTAUDIOEXT[@]}" | grep wav )
TESTFLAC=$(echo "${LSTAUDIOEXT[@]}" | grep flac)
if [[ -n "$TESTWAV" || -n "$TESTFLAC" ]]; then
	read -p " Detect and remove silence at start and end of files (flac & wav source only)? [y/N]:" qarm
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
ConfPCM() {						# 
if [ "$reps" -eq 1 ]; then		# If in video encoding
    CustomInfoChoice
else							# If not in video encoding
    clear
    echo
    echo " Under, first on the list of $NBA files to edit."
    cat "$FFMES_CACHE_STAT"
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
    read -e -p "-> " rpakb
	if [ "$rpakb" = "1" ]; then
		acodec="-acodec u8"
		akb="-ar 44100"
	elif [ "$rpakb" = "2" ]; then
		acodec="-acodec s8"
		akb="-ar 44100"
	elif [ "$rpakb" = "3" ]; then
		acodec="-acodec pcm_s16le"
		akb="-ar 44100"
	elif [ "$rpakb" = "4" ]; then
		acodec="-acodec pcm_s24le"
		akb="-ar 44100"
	elif [ "$rpakb" = "5" ]; then
		acodec="-acodec pcm_s32le"
		akb="-ar 44100"
	elif [ "$rpakb" = "6" ]; then
		acodec="-acodec u8"
		akb="-ar 48000"
	elif [ "$rpakb" = "7" ]; then
		acodec="-acodec s8"
		akb="-ar 48000"
	elif [ "$rpakb" = "8" ]; then
		acodec="-acodec pcm_s16le"
		akb="-ar 48000"
	elif [ "$rpakb" = "9" ]; then
		acodec="-acodec pcm_s24le"
		akb="-ar 48000"
	elif [ "$rpakb" = "10" ]; then
		acodec="-acodec pcm_s32le"
		akb="-ar 48000"
	elif [ "$rpakb" = "11" ]; then
		acodec="-acodec u8"
		akb=""
	elif [ "$rpakb" = "12" ]; then
		acodec="-acodec s8"
		akb=""
	elif [ "$rpakb" = "13" ]; then
		acodec="-acodec pcm_s16le"
		akb=""
	elif [ "$rpakb" = "14" ]; then
		acodec="-acodec pcm_s24le"
		akb=""
	elif [ "$rpakb" = "15" ]; then
		acodec="-acodec pcm_s32le"
		akb=""
	else
		acodec="-acodec pcm_s16le"
		akb=""
	fi
	}
ConfFLAC() {					# 
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of $NBA files to edit."
    cat "$FFMES_CACHE_STAT"
fi
    echo " Choose Flac desired configuration:"
    echo " Notes: * libFLAC uses a compression level parameter that varies from 0 (fastest) to 8 (slowest)."
	echo "          The compressed files are always perfect, lossless representations of the original data."
	echo "          Although the compression process involves a tradeoff between speed and size, "
	echo "          the decoding process is always quite fast and not dependent on the level of compression."
	echo "        * If you choose and audio bit depth superior of source file, the encoding will fail."
	echo "        * Option tagued [no], leave this option as source file."
    echo
	echo "$MESS_SEPARATOR"
    echo " For complete control of configuration:"
    echo " [-compression_level 12 -cutoff 24000 -sample_fmt s16 -ar 48000] -> Example of input format"
    echo
	echo "$MESS_SEPARATOR"
    echo " Otherwise choose a number:"
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
    echo " *[7] > |   12  |   auto |    16 |"
    echo "  [8] > |   12  |   auto |    24 |"
	read -e -p "-> " rpakb
	if echo $rpakb | grep -q 'c' ; then
		akb="$rpakb"
	elif [ "$rpakb" = "1" ]; then
		akb="-compression_level 12 -sample_fmt s16 -ar 44100"
	elif [ "$rpakb" = "2" ]; then
		akb="-compression_level 12 -sample_fmt s32 -ar 44100"
	elif [ "$rpakb" = "3" ]; then
		akb="-compression_level 12 -ar 44100"
	elif [ "$rpakb" = "4" ]; then
		akb="-compression_level 12 -sample_fmt s16 -ar 48000"
	elif [ "$rpakb" = "5" ]; then
		akb="-compression_level 12 -sample_fmt s32 -ar 48000"
	elif [ "$rpakb" = "6" ]; then
		akb="-compression_level 12 -ar 48000"
	elif [ "$rpakb" = "7" ]; then
		akb="-compression_level 12 -sample_fmt s16"
	elif [ "$rpakb" = "8" ]; then
		akb="-compression_level 12 -sample_fmt s32"
	else
		akb="-compression_level 12 -sample_fmt s16"
	fi
	}
ConfOPUS() {					# 
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of $NBA files to edit."
    cat "$FFMES_CACHE_STAT"
fi
    echo " Choose Opus (libopus) desired configuration:"
    echo " Note: * All options have cutoff at 48kHz"
    echo "       * All options are compression target"
    echo
    echo "         | kb/s | Descriptions            |"
    echo "         |------|-------------------------|"
    echo "  [1]  > |  64k | comparable to mp3 96k   |"
    echo "  [2]  > |  96k | comparable to mp3 120k  |"
    echo "  [3]  > | 128k | comparable to mp3 160k  |"
    echo "  [4]  > | 160k | comparable to mp3 192k  |"
    echo "  [5]  > | 192k | comparable to mp3 280k  |"
    echo " *[6]  > | 220k | comparable to mp3 320k  |"
    echo "  [7]  > | 256k | 5.1 audio source        |"
    echo "  [8]  > | 320k | 7.1 audio source        |"
    echo "  [9]  > | 450k | 7.1 audio source        |"
    echo "  [10] > | 510k | highest bitrate of opus |"
    if [[ "$AudioCodecType" = "Opus" ]]; then
    echo "  -----------------------------------------"
	echo "  [X]  > |    adaptive bitrate     |"
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
	read -e -p "-> " rpakb
	if [ "$rpakb" = "1" ]; then
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
	elif [ "$rpakb" = "X" ]  && [[ "$codeca" = "libopus" || "$AudioCodecType" = "Opus" ]]; then
		AdaptedBitrate="1"
	else
		akb="-b:a 220K"
	fi
	}
ConfOGG() {						# 
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of $NBA files to edit."
    cat "$FFMES_CACHE_STAT"
fi
    echo " Choose Ogg (libvorbis) desired configuration:"
    echo " Notes: * The reference is the variable bitrate (vbr), it allows to allocate more information to"
    echo "          compressdifficult passages and to save space on less demanding passages."
    echo "        * A constant bitrate (cbr) is valid for streaming in order to maintain bitrate regularity."
    echo "        * The cutoff parameter is the cutoff frequency after which the encoding is not performed,"
    echo "          this makes it possible to avoid losing bitrate on too high frequencies."
    echo
    echo "$MESS_SEPARATOR"
    echo " For crb:"
    echo " [192k] -> Example of input format for desired bitrate"
	echo
    echo "$MESS_SEPARATOR"
    echo " For vbr:"
    echo
    echo "         |      |  cut  |"
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
	read -e -p "-> " rpakb
	if echo $rpakb | grep -q 'k' ; then
		akb="-b:a $rpakb"
	elif [ "$rpakb" = "1" ]; then
		akb="-q 2 -cutoff 14000 -ar 44100"
	elif [ "$rpakb" = "2" ]; then
		akb="-q 3 -cutoff 15000 -ar 44100"
	elif [ "$rpakb" = "3" ]; then
		akb="-q 4 -cutoff 15000 -ar 44100"
	elif [ "$rpakb" = "4" ]; then
		akb="-q 5 -cutoff 16000 -ar 44100"
	elif [ "$rpakb" = "5" ]; then
		akb="-q 6 -cutoff 17000 -ar 44100"
	elif [ "$rpakb" = "6" ]; then
		akb="-q 7 -cutoff 18000 -ar 44100"
	elif [ "$rpakb" = "7" ]; then
		akb="-q 8 -cutoff 19000 -ar 44100"
	elif [ "$rpakb" = "8" ]; then
		akb="-q 9 -cutoff 20000 -ar 44100"
	elif [ "$rpakb" = "9" ]; then
		akb="-q 10 -cutoff 22050 -ar 44100"
	elif [ "$rpakb" = "10" ]; then
		akb="-q 10"
	else
		akb="-q 10 -cutoff 22050 -ar 44100"
	fi
	}
ConfMP3() {						# 
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of $NBA files to edit."
    cat "$FFMES_CACHE_STAT"
fi
    echo " Choose MP3 (libmp3lame) desired configuration:"
    echo
    echo "$MESS_SEPARATOR"
    echo " For crb:"
    echo " [192k] -> Example of input format for desired bitrate"
	echo
    echo "$MESS_SEPARATOR"
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
	read -e -p "-> " rpakb
	if echo $rpakb | grep -q 'k' ; then
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
ConfAC3() {						# 
    echo " Choose AC3 desired configuration:"
    echo
	echo "$MESS_SEPARATOR"
    echo " [192k] -> Example of input format for desired bitrate"
    echo
    echo "$MESS_SEPARATOR"
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
	read -e -p "-> " rpakb
	if echo $rpakb | grep -q 'k' ; then
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
RemoveAudioSource() {			# Clean audio source
	if [ "$NBAO" -gt 0 ] ; then
		read -p " Remove source audio? [y/N]:" qarm
		case $qarm in
			"Y"|"y")
				# Remove audio source files
				for f in "${filesSourcePass[@]}"; do
					rm -f "$f"
				done
				# Remove m3u
				if [ "$RemoveM3U" = "1" ]; then
					for f in "${LSTM3U[@]}"; do
						rm -f "$f"
					done
				fi
			;;
			*)
				SourceNotRemoved="1"
			;;
		esac
	fi
}
RemoveAudioTarget() {			# Clean audio target
	if [ "$SourceNotRemoved" = "1" ] ; then
		read -p " Remove target audio? [y/N]:" qarm
		case $qarm in
			"Y"|"y")
				# Remove audio source files
				for f in "${filesPass[@]}"; do
					rm -f "$f"
				done
			;;
			*)
				Restart
			;;
		esac
	fi
}
MultipleAudioExtention() {		# Sources audio multiple extention question
	if [ "$NBAEXT" -gt "1" ]; then
		echo
		echo " Different source audio file extensions have been found, would you like to select one or more?"
		echo " Notes: * It is recommended not to batch process different sources, in order to control the result as well as possible."
		echo "        * If target have same extention of source file, it will not processed."
		echo
		echo " Extensions found: $(echo "${LSTAUDIOEXT[@]}")"
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
			NBA="${#LSTAUDIO[@]}"
			StopLoading $?
		fi
	fi
}
AudioSpectrum() {				# 
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
    read -e -p "-> " qspek
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
		( ffmpeg -y -i "$files" -lavfi showspectrumpic=s=$spekres:mode=separate:gain=1.4:color=2 "${files%.*}".png 2>/dev/null &&
		echo "  $files ... Processed"
		) &
		if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
			wait -n
		fi
	done
	wait
	
	END=$(date +%s)				# End time counter

	# Check Target if valid (size test)
	filesPass=()
	filesReject=()
	filesSourcePass=()
	for files in "${LSTAUDIO[@]}"; do
			if [[ $(stat --printf="%s" "${files%.*}".png 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
				filesPass+=("${files%.*}".png)
			else																	# if file<30 KBytes rejected
				filesReject+=("${files%.*}".png)
			fi
	done

	# Make statistics of processed files
	DIFFS=$(($END-$START))
	NBAO="${#filesPass[@]}"
	TSSIZE=$(du -chsm "${filesPass[@]}" | tail -n1 | awk '{print $1;}')		# Target(s) size

	# End encoding messages
	echo
	echo " -----------------------------------------------------"
	echo " $NBAO/$NBA file(s) have been processed."
	if test -n "$filesPass"; then
		echo " File(s) created:"
		printf '  %s\n' "${filesPass[@]}"
	fi
	if test -n "$filesReject"; then
		echo " File(s) in error:"
		printf '  %s\n' "${filesReject[@]}"
	fi
	echo " -----------------------------------------------------"
	echo " Created file(s) size: $TSSIZE MB."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo
}
ConcatenateAudio() {			# 
	echo
	echo " Concatenate audio files:"
	echo " Note: * Before you start, make sure that the files all have the same codec and bitrate."
	echo
	echo " Files to concatenate:"
	printf '  %s\n' "${LSTAUDIO[@]}"
	echo
	echo " *[↵] > for continue"
	echo "  [q] > for exit"
	read -e -p "-> " concatrep
	if [ "$concatrep" = "q" ]; then
			Restart
	else
		# Start time counter
		START=$(date +%s)
		
		# List file to contatenate
		for files in "${LSTAUDIO[@]}"; do
			quote0="'"
			quote1="'\\\\\\''"
			parsedFile=$(echo "$files" | sed "s/$quote0/$quote1/g")
			echo "file '$parsedFile'" >> concat-list.info
		done

		# Concatenate
		if [ "${LSTAUDIO[0]##*.}" = "flac" ]; then
			shntool join *.flac -o flac -a Concatenate-Output
		else
			ffmpeg -f concat -safe 0 -i concat-list.info -c copy Concatenate-Output."${LSTAUDIO[0]##*.}"
		fi

		# Clean
		rm concat-list.info

		# End time counter
		END=$(date +%s)

		# Check Target if valid (size test)
		filesPass=()
		filesReject=()
		filesSourcePass=()
		if [[ $(stat --printf="%s" Concatenate-Output."${LSTAUDIO[0]##*.}" 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
			filesPass+=(Concatenate-Output."${LSTAUDIO[0]##*.}")
		else																	# if file<30 KBytes rejected
			filesReject+=(Concatenate-Output."${LSTAUDIO[0]##*.}")
		fi
		for files in "${LSTAUDIO[@]}"; do
				filesSourcePass+=("$files")
		done

		# Make statistics of processed files
		DIFFS=$(($END-$START))															# counter in seconds
		NBAO="${#filesPass[@]}"															# Count file(s) passed
		if [ "$NBAO" -eq 0 ] ; then
			SSIZAUDIO="0"
			TSSIZE="0"
			PERC="0"
		else
			SSIZAUDIO=$(du -chsm "${LSTAUDIO[@]}" | tail -n1 | awk '{print $1;}')			# Source file(s) size
			TSSIZE=$(du -chsm "${filesPass[@]}" | tail -n1 | awk '{print $1;}')				# Target(s) size
			PERC=$(bc <<< "scale=2; ($TSSIZE - $SSIZAUDIO)/$SSIZAUDIO * 100")				# Size difference between source and target
		fi

		# End: encoding messages
		echo
		echo " -----------------------------------------------------"
		if test -n "$filesPass"; then
			echo " File(s) created:"
			printf '  %s\n' "${filesPass[@]}"
		fi
		if test -n "$filesReject"; then
			echo " File(s) in error:"
			printf '  %s\n' "${filesReject[@]}"
		fi
		echo " -----------------------------------------------------"
		echo " Created file(s) size: $TSSIZE MB, a difference of $PERC% from the source(s) ($SSIZAUDIO MB)."
		echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
		echo " -----------------------------------------------------"
		echo

	fi
}
CutAudio() {					# 
	clear
    echo
    cat "$FFMES_CACHE_STAT"

    echo " Enter duration of cut:"
    echo " Notes: * for hours :   HOURS:MM:SS.MICROSECONDS"
    echo "        * for minutes : MM:SS.MICROSECONDS"
    echo "        * for seconds : SS.MICROSECONDS"
    echo "        * microseconds is optional, you can not indicate them"
    echo
	echo "$MESS_SEPARATOR"
	echo " Examples of input:"
	echo "  [s.20]       -> remove audio after 20 second"
	echo "  [e.01:11:20] -> remove audio before 1 hour 11 minutes 20 second"
	echo
	echo "$MESS_SEPARATOR"
    echo
    echo "  [s.time]      > for remove end"
    echo "  [e.time]      > for remove start"
    echo "  [t.time.time] > for remove start and end"
    echo "  [q]           > for exit"
	while :
	do
	read -e -p "-> " qcut0
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
		ffmpeg -i "${LSTAUDIO[0]}" -ss "$CutStart" -to "$CutEnd" -map_metadata 0 "${LSTAUDIO[0]%.*}".cut."${LSTAUDIO[0]##*.}"
	else
		ffmpeg -i "${LSTAUDIO[0]}" -ss "$CutStart" -to "$CutEnd" -c copy -map_metadata 0 "${LSTAUDIO[0]%.*}".cut."${LSTAUDIO[0]##*.}"
	fi

	# End time counter
	END=$(date +%s)

	# Check Target if valid (size test)
	filesPass=()
	filesReject=()
	if [ "$(stat --printf="%s" "${LSTAUDIO[0]%.*}".cut."${LSTAUDIO[0]##*.}")" -gt 30720 ]; then		# if file>30 KBytes accepted
		filesPass+=("${LSTAUDIO[0]%.*}".cut."${LSTAUDIO[0]##*.}")
	else																							# if file<30 KBytes rejected
		filesReject+=("${LSTAUDIO[0]%.*}".cut."${LSTAUDIO[0]##*.}")
	fi

	# Make statistics of processed files
	DIFFS=$(($END-$START))															# counter in seconds
	NBVO="${#filesPass[@]}"															# Count file(s) passed
	if [ "$NBVO" -eq 0 ] ; then
		SSIZAUDIO="0"
		TSSIZE="0"
		PERC="0"
	else
		SSIZAUDIO=$(du -chsm "${LSTAUDIO[@]}" | tail -n1 | awk '{print $1;}')			# Source file(s) size
		TSSIZE=$(du -chsm "${filesPass[@]}" | tail -n1 | awk '{print $1;}')				# Target(s) size
		PERC=$(bc <<< "scale=2; ($TSSIZE - $SSIZAUDIO)/$SSIZAUDIO * 100")				# Size difference between source and target
	fi

	# End: encoding messages
	echo
	echo " -----------------------------------------------------"
	if test -n "$filesPass"; then
		echo " File(s) created:"
		printf '  %s\n' "${filesPass[@]}"
	fi
	if test -n "$filesReject"; then
		echo " File(s) in error:"
		printf '  %s\n' "${filesReject[@]}"
	fi
	echo " -----------------------------------------------------"
	echo " Created file(s) size: $TSSIZE MB, a difference of $PERC% from the source(s) ($SSIZAUDIO MB)."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo
}
## AUDIO TAG SECTION
AudioTagEditor() {				# Option 30 	- Tag editor
	StartLoading "Grab current tags" ""

	# Limit to current directory
	mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	NBA="${#LSTAUDIO[@]}"

	# Populate array with tags
	TAG_DISC=()
	TAG_TRACK=()
	TAG_TITLE=()
	TAG_ARTIST=()
	TAG_ALBUM=()
	TAG_DATE=()
	PrtSep=()
	for (( i=0; i<=$(( $NBA -1 )); i++ )); do
		(
		ffprobe -hide_banner -loglevel panic -select_streams a -show_streams -show_format "${LSTAUDIO[$i]}" > "$FFMES_CACHE_TAG-[$i]"
		) &
		if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
			wait -n
		fi
	done
	wait
	for (( i=0; i<=$(( $NBA -1 )); i++ )); do
		TAG_DISC1=$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:disc=" | awk -F'=' '{print $NF}')
		TAG_DISC+=("$TAG_DISC1")
		TAG_TRACK1=$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:track=" | awk -F'=' '{print $NF}')
		TAG_TRACK+=("$TAG_TRACK1")
		TAG_TITLE1=$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:title=" | awk -F'=' '{print $NF}')
		TAG_TITLE+=("$TAG_TITLE1")
		TAG_ARTIST1=$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:artist=" | awk -F'=' '{print $NF}')
		TAG_ARTIST+=("$TAG_ARTIST1")
		TAG_ALBUM1=$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:album=" | awk -F'=' '{print $NF}')
		TAG_ALBUM+=("$TAG_ALBUM1")
		TAG_DATE1=$(cat "$FFMES_CACHE_TAG-[$i]" | grep -i "TAG:date=" | awk -F'=' '{print $NF}')
		TAG_DATE+=("$TAG_DATE1")
		# Table separator trick
		PrtSep+=("|")
		# Clean
		rm "$FFMES_CACHE_TAG-[$i]" &>/dev/null
	done
	wait
	StopLoading $?
	
	# Display tags in table
	clear
	echo
	echo "Inplace file tags:"
	printf '%.0s-' {1..141}; echo
	paste <(printf "%-40.40s\n" "Files") <(printf "%s\n" "|") <(printf "%-4.4s\n" "Disc") <(printf "%s\n" "|") <(printf "%-5.5s\n" "Track") <(printf "%s\n" "|") <(printf "%-20.20s\n" "Title") <(printf "%s\n" "|") <(printf "%-17.17s\n" "Artist") <(printf "%s\n" "|") <(printf "%-20.20s\n" "Album") <(printf "%s\n" "|") <(printf "%-5.5s\n" "date") | column -s $'\t' -t
	printf '%.0s-' {1..141}; echo
	paste <(printf "%-40.40s\n" "${LSTAUDIO[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-4.4s\n" "${TAG_DISC[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_TRACK[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_TITLE[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-17.17s\n" "${TAG_ARTIST[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_ALBUM[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_DATE[@]}") | column -s $'\t' -t 2>/dev/null
	# Degrading mode display for asian character
	DisplayTest=$(paste <(printf "%-40.40s\n" "${LSTAUDIO[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-4.4s\n" "${TAG_DISC[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_TRACK[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_TITLE[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-17.17s\n" "${TAG_ARTIST[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_ALBUM[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_DATE[@]}") | column -s $'\t' -t 2>/dev/null)
	if [[ -z "$DisplayTest" ]]; then
		paste <(printf "%-40.40s\n" "${LSTAUDIO[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-4.4s\n" "${TAG_DISC[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_TRACK[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_TITLE[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-17.17s\n" "${TAG_ARTIST[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_ALBUM[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_DATE[@]}")
	fi
	printf '%.0s-' {1..141}; echo
	
	echo
	echo " Select tag option:"
	echo " Notes: it is not at all recommended to threat more than one album at a time."
	echo
	echo "               | actions                    | descriptions"
	echo "               |----------------------------|-----------------------------------------------------------------------------------|"
	echo '  [rename]   > | rename files               | rename in "Track - Title" (add track number if not present)                       |'
	echo "  [disc]     > | change or add disc number  | ex. of input [disc 1]                                                             |"
	echo "  [track]    > | change or add tag track    | alphabetic sorting, to use if no file has this tag                                |"
	echo "  [album x]  > | change or add tag album    | ex. of input [album Conan the Barbarian]                                          |"
	echo "  [artist x] > | change or add tag artist   | ex. of input [artist Basil Poledouris]                                            |"
	echo "  [date x]   > | change or add tag date     | ex. of input [date 1982]                                                          |"
	echo "  [ftitle]   > | change title by [filename] |                                                                                   |"
	echo "  [utitle]   > | change title by [untitled] |                                                                                   |"
	echo "  [stitle x] > | remove N at begin of title | ex. of input [stitle 3] -> remove 3 first characters at start (limited to 9)      |"
	echo "  [etitle x] > | remove N at end of title   | ex. of input [etitle 1] -> remove 1 first characters at end (limited to 9)        |"
	echo "  [r]        > | for restart tag edition"
	echo "  [q]        > | for exit"
	echo
	while :
	do
	read -e -p "-> " rpstag
	case $rpstag in
	
		rename)
			TAG_TRACK_COUNT=()
			COUNT=()
			for (( i=0; i<=$(( $NBA -1 )); i++ )); do
				StartLoading "" "Rename: ${LSTAUDIO[$i]}"
				# If no tag track valid
				if ! [[ "${TAG_TRACK[$i]}" =~ ^[0-9]+$ ]] ; then		# If not integer
					TAG_TRACK_COUNT=$(($COUNT+1))
					COUNT=$TAG_TRACK_COUNT
					TAG_TRACK[$i]="$TAG_TRACK_COUNT"
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TRACKNUMBER="$TAG_TRACK_COUNT" -metadata TRACK="$TAG_TRACK_COUNT" temp-"${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null
				fi
				if [[ "${#TAG_TRACK[$i]}" -eq "1" ]] ; then				# if integer in one digit
					TAG_TRACK[$i]="0${TAG_TRACK[$i]}"
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TRACKNUMBER="${TAG_TRACK[$i]}" -metadata TRACK="${TAG_TRACK[$i]}" temp-"${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null
				fi
				# If temp-file exist remove source and rename
				if [[ -f "temp-${LSTAUDIO[$i]}" && -s "temp-${LSTAUDIO[$i]}" ]]; then
					rm "${LSTAUDIO[$i]}" &>/dev/null
					mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
				fi
				# If no tag title
				if test -z "${TAG_TITLE[$i]}"; then						# if no title
					TestName=$(echo "${LSTAUDIO[$i]%.*}" | head -c2)
					if ! [[ "$TestName" =~ ^[0-9]+$ ]] ; then			# If not integer at start of filename, use filename as title
						TAG_TITLE[$i]="${LSTAUDIO[$i]%.*}"
					elif test -n "${TAG_TITLE[$i]}"; then				# If album tag present, use as title
						TAG_TITLE[$i]="${TAG_ALBUM[$i]}"
					else
						TAG_TITLE[$i]="[untitled]"						# Otherwise, use "[untitled]"
					fi
				fi
				# Rename
				ParsedTitle=$(echo "${TAG_TITLE[$i]}" | sed s#/#-#g)				# Replace eventualy "/" in string
				if [[ -f "${LSTAUDIO[$i]}" && -s "${LSTAUDIO[$i]}" ]]; then
					mv "${LSTAUDIO[$i]}" "${TAG_TRACK[$i]}"\ -\ "$ParsedTitle"."${LSTAUDIO[$i]##*.}" &>/dev/null
				fi
				StopLoading $?
			done
			AudioTagEditor
		;;
		disc?[0-9])
			ParsedDisc=$(echo "$rpstag" | awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}')
			for (( i=0; i<=$(( $NBA -1 )); i++ )); do
				(
				StartLoading "" "Tag: ${LSTAUDIO[$i]}"
				ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata DISCNUMBER="$ParsedDisc" -metadata DISC="$ParsedDisc" temp-"${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null
				# If temp-file exist remove source and rename
				if [[ -f "temp-${LSTAUDIO[$i]}" && -s "temp-${LSTAUDIO[$i]}" ]]; then
					rm "${LSTAUDIO[$i]}" &>/dev/null
					mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
				fi
				StopLoading $?
				) &
				if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
					wait -n
				fi
			done
			wait
			AudioTagEditor
		;;
		track)
			TAG_TRACK_COUNT=()
			COUNT=()
			for (( i=0; i<=$(( $NBA -1 )); i++ )); do
				StartLoading "" "Tag: ${LSTAUDIO[$i]}"
				TAG_TRACK_COUNT=$(($COUNT+1))
				COUNT=$TAG_TRACK_COUNT
				if [[ "${#TAG_TRACK_COUNT}" -eq "1" ]] ; then				# if integer in one digit
					TAG_TRACK_COUNT="0$TAG_TRACK_COUNT" 
				fi
				ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TRACKNUMBER="$TAG_TRACK_COUNT" -metadata TRACK="$TAG_TRACK_COUNT" temp-"${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null
				# If temp-file exist remove source and rename
				if [[ -f "temp-${LSTAUDIO[$i]}" && -s "temp-${LSTAUDIO[$i]}" ]]; then
					rm "${LSTAUDIO[$i]}" &>/dev/null
					mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
				fi
				StopLoading $?
			done
			AudioTagEditor
		;;
		album*)
			ParsedAlbum=$(echo "$rpstag" | awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}')
			for (( i=0; i<=$(( $NBA -1 )); i++ )); do
				(
				StartLoading "" "Tag: ${LSTAUDIO[$i]}"
				if [ "${LSTAUDIO[$i]##*.}" != "opus" ]; then
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata ALBUM="$ParsedAlbum" temp-"${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add ALBUM="$ParsedAlbum" --delete ALBUM -o temp-"${LSTAUDIO[$i]}" &>/dev/null
				fi
				# If temp-file exist remove source and rename
				if [[ -f "temp-${LSTAUDIO[$i]}" && -s "temp-${LSTAUDIO[$i]}" ]]; then
					rm "${LSTAUDIO[$i]}" &>/dev/null
					mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
				fi
				StopLoading $?
				) &
				if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
					wait -n
				fi
			done
			wait
			AudioTagEditor
		;;
		artist*)
			ParsedArtist=$(echo "$rpstag" | awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}')
			for (( i=0; i<=$(( $NBA -1 )); i++ )); do
				( 
				StartLoading "" "Tag: ${LSTAUDIO[$i]}"
				if [ "${LSTAUDIO[$i]##*.}" != "opus" ]; then
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata ARTIST="$ParsedArtist" temp-"${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add ARTIST="$ParsedArtist" --delete ARTIST -o temp-"${LSTAUDIO[$i]}" &>/dev/null
				fi
				# If temp-file exist remove source and rename
				if [[ -f "temp-${LSTAUDIO[$i]}" && -s "temp-${LSTAUDIO[$i]}" ]]; then
					rm "${LSTAUDIO[$i]}" &>/dev/null
					mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
				fi
				StopLoading $?
				) &
				if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
					wait -n
				fi
			done
			wait
			AudioTagEditor
		;;
		date*)
			ParsedDate=$(echo "$rpstag" | awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}')
			for (( i=0; i<=$(( $NBA -1 )); i++ )); do
				(
				StartLoading "" "Tag: ${LSTAUDIO[$i]}"
				if [ "${LSTAUDIO[$i]##*.}" != "opus" ]; then
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata DATE="$ParsedDate" temp-"${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add DATE="$ParsedDate" --delete DATE -o temp-"${LSTAUDIO[$i]}" &>/dev/null
				fi
				# If temp-file exist remove source and rename
				if [[ -f "temp-${LSTAUDIO[$i]}" && -s "temp-${LSTAUDIO[$i]}" ]]; then
					rm "${LSTAUDIO[$i]}" &>/dev/null
					mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
				fi
				StopLoading $?
				) &
				if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
					wait -n
				fi
			done
			wait
			AudioTagEditor
		;;
		ftitle)
			for (( i=0; i<=$(( $NBA -1 )); i++ )); do
				StartLoading "" "Tag: ${LSTAUDIO[$i]}"
				ParsedTitle=$(echo "${LSTAUDIO[$i]%.*}")
				if [ "${LSTAUDIO[$i]##*.}" != "opus" ]; then
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TITLE="$ParsedTitle" temp-"${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add TITLE="$ParsedTitle" --delete TITLE -o temp-"${LSTAUDIO[$i]}" &>/dev/null
				fi
				# If temp-file exist remove source and rename
				if [[ -f "temp-${LSTAUDIO[$i]}" && -s "temp-${LSTAUDIO[$i]}" ]]; then
					rm "${LSTAUDIO[$i]}" &>/dev/null
					mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
				fi
				StopLoading $?
			done
			AudioTagEditor
		;;
		utitle)
			for (( i=0; i<=$(( $NBA -1 )); i++ )); do
				(
				StartLoading "" "Tag: ${LSTAUDIO[$i]}"
				if [ "${LSTAUDIO[$i]##*.}" != "opus" ]; then
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TITLE="[untitled]" temp-"${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add TITLE="[untitled]" --delete TITLE -o temp-"${LSTAUDIO[$i]}" &>/dev/null
				fi
				# If temp-file exist remove source and rename
				if [[ -f "temp-${LSTAUDIO[$i]}" && -s "temp-${LSTAUDIO[$i]}" ]]; then
					rm "${LSTAUDIO[$i]}" &>/dev/null
					mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
				fi
				StopLoading $?
				) &
				if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
					wait -n
				fi
			done
			wait
			AudioTagEditor
		;;
		stitle?[0-9])
			Cut1=$(echo "$rpstag" | awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}')
			Cut=$( expr $Cut1 + 1 )
			for (( i=0; i<=$(( $NBA -1 )); i++ )); do
				StartLoading "" "Tag: ${LSTAUDIO[$i]}"
				ParsedTitle=$(echo "${TAG_TITLE[$i]}" | cut -c "$Cut"-)
				if [ "${LSTAUDIO[$i]##*.}" != "opus" ]; then
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TITLE="$ParsedTitle" temp-"${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add TITLE="$ParsedTitle" --delete TITLE -o temp-"${LSTAUDIO[$i]}" &>/dev/null
				fi
				# If temp-file exist remove source and rename
				if [[ -f "temp-${LSTAUDIO[$i]}" && -s "temp-${LSTAUDIO[$i]}" ]]; then
					rm "${LSTAUDIO[$i]}" &>/dev/null
					mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
				fi
				StopLoading $?
			done
			AudioTagEditor
		;;
		etitle?[0-9])
			Cut1=$(echo "$rpstag" | awk '{for (i=2; i<NF; i++) printf $i " "; print $NF}')
			Cut=$( expr $Cut1 + 1 )
			for (( i=0; i<=$(( $NBA -1 )); i++ )); do
				StartLoading "" "Tag: ${LSTAUDIO[$i]}"
				ParsedTitle=$(echo "${TAG_TITLE[$i]}" | rev | cut -c"$Cut"- | rev)
				if [ "${LSTAUDIO[$i]##*.}" != "opus" ]; then
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TITLE="$ParsedTitle" temp-"${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add TITLE="$ParsedTitle" --delete TITLE -o temp-"${LSTAUDIO[$i]}" &>/dev/null
				fi
				# If temp-file exist remove source and rename
				if [[ -f "temp-${LSTAUDIO[$i]}" && -s "temp-${LSTAUDIO[$i]}" ]]; then
					rm "${LSTAUDIO[$i]}" &>/dev/null
					mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
				fi
				StopLoading $?
			done
			AudioTagEditor
		;;
		"r"|"R")
			AudioTagEditor
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
## VGM SECTION
RenameOneDigit() {				# Rename trick, add 0 if one digit - for keep good order
	for wav in *.wav ; do
		number=$(echo $wav | sed 's/[^0-9]*//g')
		padded=$(printf "%02d" "${number#0}")
		new_name=$(echo $wav | sed "s/${number}/${padded}/")
		mv "$wav" "$new_name" &>/dev/null
	done
	}
Sox_vgm_cmd_silence() {			# Sox remove silence from audio command
	# Remove silence from audio files while leaving gaps, if audio during more than 10s
	TEST_DURATION=$(mediainfo --Output="General;%Duration%" "${files%.*}".wav)
	if [[ "$TEST_DURATION" -gt 10000 ]] ; then
		sox "${files%.*}".wav temp-out.wav silence -l 1 0.1 0.01% -1 2.0 0.01%
		rm "${files%.*}".wav &>/dev/null
		mv temp-out.wav "${files%.*}".wav &>/dev/null
	fi
	}
FFmpeg_vgm_cmd_norm_stereo() {	# FFmpeg normalization & test channel command
	# Test Volume, set normalization variable
	TESTDB=$(ffmpeg -i "${files%.*}".wav -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
	if [[ $TESTDB = *"-"* ]]; then
		GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
		afilter="-af volume=$GREPVOLUME"
	else
		afilter=""
	fi

	# Channel test mono or stereo
	TESTLEFT=$(ffmpeg -i "${files%.*}".wav -map_channel 0.0.0 -f md5 - 2>/dev/null)
	TESTRIGHT=$(ffmpeg -i "${files%.*}".wav -map_channel 0.0.1 -f md5 - 2>/dev/null)
	if [ "$TESTLEFT" = "$TESTRIGHT" ]; then
		confchan="-channel_layout mono"
	else
		confchan=""
	fi

	# Encoding Wav
	ffmpeg $FFMPEG_LOG_LVL -y -i "${files%.*}".wav $afilter $confchan -acodec pcm_s16le -f wav temp-out.wav &>/dev/null
	rm "${files%.*}".wav &>/dev/null
	mv temp-out.wav "${files%.*}".wav &>/dev/null
	}
FFmpeg_vgm_cmd() {				# FFmpeg vgm encoding command
	# Encoding flac
	StartLoading "" "Encoding: ${files%.*}.flac"
	ffmpeg -y -i "${files%.*}".wav -acodec flac -compression_level 12 -sample_fmt s16 -metadata TRACK="$TAG_TRACK" -metadata title="$TAG_SONG" -metadata album="$TAG_ALBUM" -metadata artist="$TAG_ARTIST" -metadata date="$TAG_DATE" "${files%.*}".flac  &>/dev/null
	StopLoading $?
	# Rename if possible
	if [ -n "$TAG_TRACK" ] && [ -n "$TAG_SONG" ]; then
		mv "${files%.*}".flac "$TAG_TRACK - $TAG_SONG".flac &>/dev/null
	fi
	}
VGMRip_amiga() {				# Option 211 	- VGM rip amiga (hidden option)
	echo
	# Rename One Digit
	for f in * ; do
		number=$(echo $f | sed 's/[^0-9]*//g')
		padded=$(printf "%02d" "${number#0}")
		new_name=$(echo $f | sed "s/${number}/${padded}/" 2> /dev/null)
		mv "$f" "$new_name" &>/dev/null
	done
	# Extract Tag 1
	if test -z "$TAG_GAME"; then
		echo "Please indicate the game title"
		read -e -p " -> " TAG_GAME
		echo
	fi
	if test -z "$TAG_ARTIST"; then
		echo "Please indicate the artist"
		read -e -p " -> " TAG_ARTIST
		echo
	fi
	if test -z "$TAG_DATE"; then
		echo "Please indicate the date of release"
		read -e -p " -> " TAG_DATE
		echo
	fi
	TAG_MACHINE="Amiga"
	TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"
	# Extract VGM
	mod2ogg2.sh --no-norm --wave *
	# Encoding Flac
	AUDIO_EXT_AVAILABLE="wav"
	mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -regex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	for files in "${LSTAUDIO[@]}"; do
		# Extract Tag 2
		TAG_TRACK=$(($COUNTER+1))
		COUNTER=$TAG_TRACK
		TAG_SONG="${files%.*}"
		# Track leading 0
		number=$(echo "$TAG_TRACK" | sed 's/[^0-9]*//g')
		padded=$(printf "%02d" $number)
		TAG_TRACK=$(echo "$TAG_TRACK" | sed "s/${number}/${padded}/")
		# Remove silence
		Sox_vgm_cmd_silence
		# Normalization & false stereo detection
		FFmpeg_vgm_cmd_norm_stereo
		# Encoding flac
		FFmpeg_vgm_cmd
	done
	}
VGMRip() {						# Option 21 	- VGM rip
	echo
	echo " VGM Rip"
	echo

	# VGM ISO
	if [ "$NBCUE" -gt "1" ]; then                                       # If more than 1 cue
		echo "  More than one CUE file in working directory"
		echo
	elif [ "$NBCUE" -eq "1" ] && [ "$NBVGMISO" -gt "1" ]; then              # If more than 1 bin = merge
		echo "  More than one bin files in working directory, merge it"
		binmerge "${LSTCUE[0]}" "${LSTCUE[0]%.*}"-Merged
		mkdir iso-backup
		for files in "${LSTVGMISO[@]}"; do
			mv "$files" iso-backup/
		done
		mv "${LSTCUE[0]}" iso-backup/
		SetGlobalVariables                                                 # Rebuild global variable
		echo
	fi

	if [ "$NBCUE" -eq "1" ] && [ "$NBVGMISO" -eq "1" ]; then                # If 1 cue and bin file
		# Extract Tag
		if test -z "$TAG_GAME"; then
			echo "Please indicate the game title"
			read -e -p " -> " TAG_GAME
			echo
		fi
		if test -z "$TAG_ARTIST"; then
			echo "Please indicate the artist"
			read -e -p " -> " TAG_ARTIST
			echo
		fi
		if test -z "$TAG_DATE"; then
			echo "Please indicate the date of release"
			read -e -p " -> " TAG_DATE
			echo
		fi
		if test -z "$TAG_MACHINE"; then
			echo "Please indicate the platform of release"
			read -e -p " -> " TAG_MACHINE
			echo
		fi
		TAG_SONG="[untitled]"
		TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"
		# Extract VGM
		bchunk -w "${LSTVGMISO[0]}" "${LSTCUE[0]}" Track-
		# Clean
		rm -- Track-*.iso			# Remove data track
		# Rename trick, add 0 if one digit - for keep good order
		RenameOneDigit
		# Encoding Flac
		AUDIO_EXT_AVAILABLE="wav"
		mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -regex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
		for files in "${LSTAUDIO[@]}"; do
			# Track tag (counter)
			TAG_TRACK=$(($COUNTER+1))
			COUNTER=$TAG_TRACK
			# Track leading 0
			number=$(echo "$TAG_TRACK" | sed 's/[^0-9]*//g')
			padded=$(printf "%02d" $number)
			TAG_TRACK=$(echo "$TAG_TRACK" | sed "s/${number}/${padded}/")
			# Remove silence
			Sox_vgm_cmd_silence
			# Normalization & false stereo detection
			FFmpeg_vgm_cmd_norm_stereo
			# Encoding flac
			FFmpeg_vgm_cmd
		done
	fi


	# VGM Files
	for files in "${LSTVGM[@]}"; do

		# Track tag (counter)
		TAG_TRACK=$(($COUNTER+1))
		COUNTER=$TAG_TRACK
		# Track leading 0
		number=$(echo "$TAG_TRACK" | sed 's/[^0-9]*//g')
		padded=$(printf "%02d" $number)
		TAG_TRACK=$(echo "$TAG_TRACK" | sed "s/${number}/${padded}/")

			# Extract VGM
			case "${LSTVGM[@]##*.}" in

				*gbs|*GBS)				# Nintendo Game Boy and Game Boy Color - gbsplay decode
					# Extract Tag
					gbsinfo "$files" > "$VGM_TAG"													# Tag record

					if test -z "$TAG_GAME"; then
						TAG_GAME=$(cat "$VGM_TAG" | grep "Title" | awk -F'"' '$0=$2')
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_ARTIST"; then
						TAG_ARTIST=$(cat "$VGM_TAG" | grep "Author" | awk -F'"' '$0=$2')				# Artist
						if test -z "$TAG_ARTIST"; then
							echo "Please indicate the artist"
							read -e -p " -> " TAG_ARTIST
							echo
						fi
					fi
					echo "Please indicate the date of release"
					read -e -p " -> " TAG_DATE
					echo
					echo "Please indicate the platform of release, Game Boy or Game Boy Color?"
					read -e -p " -> " TAG_MACHINE
					TAG_SONG="${files%.*}"
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album

					if [ "$NBM3U" -gt "0" ]; then		# If m3u
						for m3ufiles in "${LSTM3U[@]}"; do
							SUBSONG=$(($COUNT+1))
							COUNT=$SUBSONG
							# Extract VGM
							gbsplay -o stdout -f 0 -t 360 -T 2 "$files" $SUBSONG $SUBSONG </dev/null | sox -t raw -r 88.2k -e signed -b 16 - -t wav "${m3ufiles%.*}".wav
							# Grep duration, test volume and set normalization variable
							TAG_DURATION=$(grep -o '[^[:blank:]]:[^[:blank:]]*' "$m3ufiles" | tail -1 | awk -F"," '{ print $1 }')	# Total duration in m:s
							TAG_FADING=$(tail -1 "$m3ufiles" | sed 's/\,$//' | awk -F"," '{ print $NF }')							# Fade out duration in s
							TAG_SDURATION=$(echo $TAG_DURATION | awk -F":" '{ print ($1 * 60) + $2 }')								# Total duration in s
							if [[ "$TAG_FADING" -ge "$TAG_SDURATION" ]] ; then														# prevent incoherence duration between fade out and total duration
								TAG_FADING="1"
							fi
							TAG_FDURATION=$(expr $TAG_SDURATION - $TAG_FADING)														# Total duration - Fade out duration
							TESTDB=$(ffmpeg -i "${m3ufiles%.*}".wav -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
							if [[ $TESTDB = *"-"* ]]; then
								GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
								afilter="-af volume=$GREPVOLUME,afade=t=out:st=$TAG_FDURATION:d=$TAG_FADING"
							else
								afilter="-af afade=t=out:st=$TAG_FDURATION:d=$TAG_FADING"
							fi

							# Channel test mono or stereo
							TESTLEFT=$(ffmpeg -i "${m3ufiles%.*}".wav -map_channel 0.0.0 -f md5 - 2>/dev/null)
							TESTRIGHT=$(ffmpeg -i "${m3ufiles%.*}".wav -map_channel 0.0.1 -f md5 - 2>/dev/null)
							if [ "$TESTLEFT" = "$TESTRIGHT" ]; then
								confchan="-channel_layout mono"
							else
								confchan=""
							fi

							# Encoding flac
							StartLoading "" "Encoding: ${m3ufiles%.*}.flac"
							ffmpeg -y -i "${m3ufiles%.*}".wav -t $TAG_DURATION $afilter $confchan -acodec flac -compression_level 12 -sample_fmt s16 -ar 44100 -metadata TRACK="$SUBSONG" -metadata title="$TAG_SONG" -metadata album="$TAG_ALBUM" -metadata artist="$TAG_ARTIST" -metadata date="$TAG_DATE" "${m3ufiles%.*}".flac &>/dev/null
							StopLoading $?

							for (( i=0; i<=$(( $NBA -1 )); i++ )); do
								StartLoading "" "Tag: ${LSTAUDIO[$i]}"
								ParsedTitle=$(echo "${TAG_TITLE[$i]}" | cut -c "$Cut"-)
								if [ "${LSTAUDIO[$i]##*.}" != "opus" ]; then
									ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TITLE="$ParsedTitle" tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null && mv tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" "${LSTAUDIO[$i]}" &>/dev/null
								else
									opustags "${LSTAUDIO[$i]}" --add TITLE="$ParsedTitle" --delete TITLE -o temp-"${LSTAUDIO[$i]}" &>/dev/null
									rm "${LSTAUDIO[$i]}" &>/dev/null
									mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
								fi
								StopLoading $?
							done

						done
					else								# If no m3u
						SUBSONG=$(gbsinfo "$files" | grep "Subsongs:" | awk '{print $2;}')
						for SUBSONG in `seq -w 1 $SUBSONG`; do
							# Extract VGM
							gbsplay -qqq -o stdout "$files" -T 1 $SUBSONG $SUBSONG </dev/null | sox -t raw -r 88.2k -e signed -b 16 - -t wav "$SUBSONG".wav
							# Test Volume and set normalization variable
							TESTDB=$(ffmpeg -i "$SUBSONG".wav -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
							if [[ $TESTDB = *"-"* ]]; then
								GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
								afilter="-af volume=$GREPVOLUME"
							else
								afilter=""
							fi

							# Channel test mono or stereo
							TESTLEFT=$(ffmpeg -i "$SUBSONG".wav -map_channel 0.0.0 -f md5 - 2>/dev/null)
							TESTRIGHT=$(ffmpeg -i "$SUBSONG".wav -map_channel 0.0.1 -f md5 - 2>/dev/null)
							if [ "$TESTLEFT" = "$TESTRIGHT" ]; then
								confchan="-channel_layout mono"
							else
								confchan=""
							fi

							# Encoding flac
							StartLoading "" "Encoding: $SUBSONG.flac"
							ffmpeg -y -i "$SUBSONG".wav $afilter $confchan -acodec flac -compression_level 12 -sample_fmt s16 -ar 44100 -metadata TRACK="$SUBSONG" -metadata title="$TAG_SONG" -metadata album="$TAG_ALBUM" -metadata artist="$TAG_ARTIST" -metadata date="$TAG_DATE" "$SUBSONG - $TAG_GAME".flac  &>/dev/null
							StopLoading $?
						done
					fi
				;;

				*snd|*SND|*sndh|*SNDH)				# amiga/atari - sc68 decode
					# Extract Tag
					info68 -A "$files" > "$VGM_TAG"													# Tag record
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(cat "$VGM_TAG" | grep -i -a title | sed 's/^.*: //' | head -1)
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_ARTIST"; then
						TAG_ARTIST=$(cat "$VGM_TAG" | grep -i -a artist | sed 's/^.*: //' | head -1)				# Artist
						if test -z "$TAG_ARTIST"; then
							echo "Please indicate the artist"
							read -e -p " -> " TAG_ARTIST
							echo
						fi
					fi
					echo "Please indicate the date of release"
					read -e -p " -> " TAG_DATE
					echo
					echo "Please indicate the platform of release, Amiga or Atari ST?"
					read -e -p " -> " TAG_MACHINE
					TAG_SONG="${files%.*}"
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album

					SUBSONG=$(cat "$VGM_TAG" | grep -i -a track | sed 's/^.*: //' | head -1)
					for SUBSONG in `seq -w 1 $SUBSONG`; do
						# Extract VGM
						sc68 -t $SUBSONG "$files" -w -o "$SUBSONG".wav

						# Remove silence from audio files while leaving gaps, if audio during more than 10s
						TEST_DURATION=$(mediainfo --Output="General;%Duration%" "$SUBSONG".wav)
						if [[ "$TEST_DURATION" -gt 10000 ]] ; then
							sox "$SUBSONG".wav temp-out.wav silence -l 1 0.1 1% -1 2.0 1%
							rm "$SUBSONG".wav &>/dev/null
							mv temp-out.wav "$SUBSONG".wav &>/dev/null
						fi

						# Test Volume, remove silence and set normalization variable
						TESTDB=$(ffmpeg -i "$SUBSONG".wav -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
						if [[ $TESTDB = *"-"* ]]; then
							GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
							afilter="-af volume=$GREPVOLUME"
						fi

						# Channel test mono or stereo
						TESTLEFT=$(ffmpeg -i "$SUBSONG".wav -map_channel 0.0.0 -f md5 - 2>/dev/null)
						TESTRIGHT=$(ffmpeg -i "$SUBSONG".wav -map_channel 0.0.1 -f md5 - 2>/dev/null)
						if [ "$TESTLEFT" = "$TESTRIGHT" ]; then
							confchan="-channel_layout mono"
						else
							confchan=""
						fi

						# Encoding flac
						StartLoading "" "Encoding: $SUBSONG.flac"
						ffmpeg -y -i "$SUBSONG".wav $afilter $confchan -acodec flac -compression_level 12 -sample_fmt s16 -ar 44100 -metadata TRACK="$SUBSONG" -metadata title="$TAG_SONG" -metadata album="$TAG_ALBUM" -metadata artist="$TAG_ARTIST" -metadata date="$TAG_DATE" "$SUBSONG - $TAG_GAME".flac &>/dev/null
						StopLoading $?
					done
				;;

				*VGM|*vgm|*VGZ|*vgz)									# Various machines - vgm2wav decode
					# Extract Tag
					vgm_tag "$files" > "$VGM_TAG"													# Tag record
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(sed -n 's/Game Name:/&\n/;s/.*\n//p' "$VGM_TAG" | awk '{$1=$1}1')
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_ARTIST"; then
					TAG_ARTIST=$(sed -n 's/Composer:/&\n/;s/.*\n//p' "$VGM_TAG" | awk '{$1=$1}1')
						if test -z "$TAG_ARTIST"; then
							echo "Please indicate the artist"
							read -e -p " -> " TAG_ARTIST
							echo
						fi
					fi
					if test -z "$TAG_MACHINE"; then
						TAG_MACHINE=$(sed -n 's/System:/&\n/;s/.*\n//p' "$VGM_TAG" | awk '{$1=$1}1')
						if test -z "$TAG_MACHINE"; then
							echo "Please indicate the platform of release"
							read -e -p " -> " TAG_MACHINE
							echo
						fi
					fi
					if test -z "$TAG_DATE"; then
						TAG_DATE=$(sed -n 's/Release:/&\n/;s/.*\n//p' "$VGM_TAG" | awk '{$1=$1}1')
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							read -e -p " -> " TAG_DATE
							echo
						fi
					fi
					TAG_SONG=$(sed -n 's/Track Title:/&\n/;s/.*\n//p' "$VGM_TAG" | awk '{$1=$1}1')
					if test -z "$TAG_SONG"; then
						TAG_SONG="${files%.*}"
					fi
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"
					# Extract VGM
					vgm2wav "$files" "${files%.*}".wav &>/dev/null
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*s98|*S98)									# NEC PC-6001, PC-6601, PC-8801, PC-9801; Sharp X1; Fujitsu FM-7, FM Towns - vgm2wav decode
					# Extract Tag
					strings "$files" > "$VGM_TAG"													# Tag record
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(cat "$VGM_TAG" | grep -i -a game | sed 's/^.*=//' | head -1)
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_ARTIST"; then
						TAG_ARTIST=$(cat "$VGM_TAG" | grep -i -a artist | sed 's/^.*=//' | head -1)
						if test -z "$TAG_ARTIST"; then
							echo "Please indicate the artist"
							read -e -p " -> " TAG_ARTIST
							echo
						fi
					fi
					if test -z "$TAG_MACHINE"; then
						TAG_MACHINE=$(cat "$VGM_TAG" | grep -i -a system | sed 's/^.*=//' | head -1)
						if test -z "$TAG_MACHINE"; then
							echo "Please indicate the platform of release"
							read -e -p " -> " TAG_MACHINE
							echo
						fi
					fi
					if test -z "$TAG_DATE"; then
						TAG_DATE=$(cat "$VGM_TAG" | grep -i -a year | sed 's/^.*=//' | head -1)
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							read -e -p " -> " TAG_DATE
							echo
						fi
					fi
					TAG_SONG=$(cat "$VGM_TAG" | grep -i -a title | sed 's/^.*=//' | head -1)
					if test -z "$TAG_SONG"; then
						TAG_SONG="[untitled]"
					fi
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"
					# Extract VGM
					vgm2wav --loops 1 "$files" "${files%.*}".wav &>/dev/null
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*dsf|*DSF)											# Sega Dreamcast - zxtune123 decode
					# Extract Tag
					strings "$files" > "$VGM_TAG"													# Tag record
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(cat "$VGM_TAG" | grep -i -a game | sed 's/^.*=//' | head -1)
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_ARTIST"; then
						echo "Please indicate the artist"
						read -e -p " -> " TAG_ARTIST
						echo
					fi
					if test -z "$TAG_DATE"; then
						TAG_DATE=$(cat "$VGM_TAG" | grep -i -a year | sed 's/^.*=//')
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							read -e -p " -> " TAG_DATE
							echo
						fi
					fi
					TAG_SONG="${files%.*}"															# Track name
					TAG_MACHINE="Dreamcast"															# Album part 2
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album
					# Extract VGM
					zxtune123 --wav filename=[Filename].wav "$files"
					mv "${files%.*}".dsf.wav "${files%.*}".wav &>/dev/null							# Rename trick
					mv "${files%.*}".DSF.wav "${files%.*}".wav &>/dev/null							# Rename trick
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*minissf|*MINISSF|*ssf|*SSF)					# Sega Saturn - zxtune123 decode
					# Extract Tag
					strings "$files" > "$VGM_TAG"													# Tag record
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(cat "$VGM_TAG" | grep -i -a game | sed 's/^.*=//' | head -1)
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_DATE"; then
						TAG_DATE=$(cat "$VGM_TAG" | grep -i -a year | sed 's/^.*=//')
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							read -e -p " -> " TAG_DATE
							echo
						fi
					fi
					TAG_ARTIST=$(cat "$VGM_TAG" | grep -i -a artist | sed 's/^.*=//')
					TAG_SONG="${files%.*}"															# Track name
					TAG_MACHINE="Saturn"															# Album part 2
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album
					# Extract VGM
					echo
					zxtune123 --wav filename=[Filename].wav "$files"
					mv "${files%.*}".ssf.wav "${files%.*}".wav &>/dev/null							# Rename trick
					mv "${files%.*}".SSF.wav "${files%.*}".wav &>/dev/null							# Rename trick
					mv "${files%.*}".minissf.wav "${files%.*}".wav &>/dev/null						# Rename trick
					mv "${files%.*}".MINISSF.wav "${files%.*}".wav &>/dev/null						# Rename trick
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*psf|*PSF|*minipsf|*MINIPSF)					# Sony Playstation - zxtune123 decode
					# Extract Tag
					strings "$files" > "$VGM_TAG"													# Tag record
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(cat "$VGM_TAG" | grep -i -a game= | sed 's/^.*=//' | head -1)
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_DATE"; then
						TAG_DATE=$(cat "$VGM_TAG" | grep -i -a year= | sed 's/^.*=//')
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							read -e -p " -> " TAG_DATE
							echo
						fi
					fi
					TAG_ARTIST=$(cat "$VGM_TAG" | grep -i -a artist= | sed 's/^.*=//')
					TAG_SONG=$(cat "$VGM_TAG" | grep -i -a title= | sed 's/^.*=//')
					if test -z "$TAG_SONG"; then
						TAG_SONG="${files%.*}"
					fi
					TAG_MACHINE="PS1"																# Album part 2
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album
					# Extract VGM
					echo
					zxtune123 --wav filename=[Filename].wav "$files"
					mv "${files%.*}".psf.wav "${files%.*}".wav &>/dev/null							# Rename trick
					mv "${files%.*}".PSF.wav "${files%.*}".wav &>/dev/null							# Rename trick
					mv "${files%.*}".minipsf.wav "${files%.*}".wav &>/dev/null						# Rename trick
					mv "${files%.*}".MINIPSF.wav "${files%.*}".wav &>/dev/null						# Rename trick
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;&

				*psf2|*PSF2|*minipsf2|*MINIPSF2)					# Sony Playstation 2 - zxtune123 decode
					# Extract Tag
					strings "$files" > "$VGM_TAG"
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(cat "$VGM_TAG" | grep -i -a game | sed 's/^.*=//' | head -1)
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_DATE"; then
						TAG_DATE=$(cat "$VGM_TAG" | grep -i -a year | sed 's/^.*=//')
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							read -e -p " -> " TAG_DATE
							echo
						fi
					fi
					TAG_SONG=$(cat "$VGM_TAG" | grep -i -a title | sed 's/^.*=//')
					if test -z "$TAG_SONG"; then
						TAG_SONG="${files%.*}"
					fi
					if test -z "$TAG_ARTIST"; then
						TAG_ARTIST=$(cat "$VGM_TAG" | grep -i -a artist | sed 's/^.*=//')
						if test -z "$TAG_ARTIST"; then
							echo "Please indicate the artist"
							read -e -p " -> " TAG_ARTIST
							echo
						fi
					fi
					TAG_MACHINE="PS2"																# Album part 2
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album
					# Extract VGM
					echo
					zxtune123 --wav filename=[Filename].wav "$files"
					mv "${files%.*}".psf2.wav "${files%.*}".wav &>/dev/null							# Rename trick
					mv "${files%.*}".PSF2.wav "${files%.*}".wav &>/dev/null							# Rename trick
					mv "${files%.*}".minipsf2.wav "${files%.*}".wav &>/dev/null						# Rename trick
					mv "${files%.*}".MINIPSF2.wav "${files%.*}".wav &>/dev/null						# Rename trick
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;&

				*miniusf|*MINIUSF)					# Nintendo N64 - zxtune123 decode
					# Extract Tag
					strings "$files" > "$VGM_TAG"													# Tag record
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(cat "$VGM_TAG" | grep -i -a game | sed 's/^.*=//' | head -1)
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							echo -n " -> "
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_DATE"; then
						TAG_DATE=$(cat "$VGM_TAG" | grep -i -a year | sed 's/^.*=//')
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							read -e -p " -> " TAG_DATE
							echo
						fi
					fi
					TAG_SONG=$(cat "$VGM_TAG" | grep -i -a title | sed 's/^.*=//')
					if test -z "$TAG_SONG"; then
						TAG_SONG="${files%.*}"
					fi
					if test -z "$TAG_ARTIST"; then
						TAG_ARTIST=$(cat "$VGM_TAG" | grep -i -a artist | sed 's/^.*=//')
						if test -z "$TAG_ARTIST"; then
							echo "Please indicate the artist"
							read -e -p " -> " TAG_ARTIST
							echo
						fi
					fi
					TAG_MACHINE="N64"																# Album part 2
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album
					# Extract VGM
					echo
					zxtune123 --wav filename=[Filename].wav "$files"
					mv "${files%.*}".miniusf.wav "${files%.*}".wav &>/dev/null						# Rename trick
					mv "${files%.*}".MINIUSF.wav "${files%.*}".wav &>/dev/null						# Rename trick
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*minigsf|*MINIGSF)					# Nintendo GBA - zxtune123 decode
					# Extract Tag
					strings "$files" > "$VGM_TAG"													# Tag record
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(cat "$VGM_TAG" | grep -i -a game | sed 's/^.*=//' | head -1)
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_DATE"; then
						TAG_DATE=$(cat "$VGM_TAG" | grep -i -a year | sed 's/^.*=//')
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							read -e -p " -> " TAG_DATE
							echo
						fi
					fi
					TAG_SONG=$(cat "$VGM_TAG" | grep -i -a title | sed 's/^.*=//')
					if test -z "$TAG_SONG"; then
						TAG_SONG="${files%.*}"
					fi
					if test -z "$TAG_ARTIST"; then
						TAG_ARTIST=$(cat "$VGM_TAG" | grep -i -a artist | sed 's/^.*=//')
						if test -z "$TAG_ARTIST"; then
							echo "Please indicate the artist"
							read -e -p " -> " TAG_ARTIST
							echo
						fi
					fi
					TAG_MACHINE="GBA"																# Album part 2
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album
					# Extract VGM
					echo
					zxtune123 --wav filename=[Filename].wav "$files"
					mv "${files%.*}".minigsf.wav "${files%.*}".wav &>/dev/null						# Rename trick
					mv "${files%.*}".MINIGSF.wav "${files%.*}".wav &>/dev/null						# Rename trick
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*mini2sf|*MINI2SF)					# Nintendo DS - zxtune123 decode
					# Extract Tag
					strings "$files" > "$VGM_TAG"													# Tag record
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(cat "$VGM_TAG" | grep -i -a game | sed 's/^.*=//' | head -1)
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_DATE"; then
						TAG_DATE=$(cat "$VGM_TAG" | grep -i -a year | sed 's/^.*=//')
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							read -e -p " -> " TAG_DATE
							echo
						fi
					fi
					TAG_SONG=$(cat "$VGM_TAG" | grep -i -a title | sed 's/^.*=//')
					if test -z "$TAG_SONG"; then
						TAG_SONG="${files%.*}"
					fi
					if test -z "$TAG_ARTIST"; then
						TAG_ARTIST=$(cat "$VGM_TAG" | grep -i -a artist | sed 's/^.*=//')
						if test -z "$TAG_ARTIST"; then
							echo "Please indicate the artist"
							read -e -p " -> " TAG_ARTIST
							echo
						fi
					fi
					TAG_MACHINE="GBA"																# Album part 2
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album
					# Extract VGM
					echo
					zxtune123 --wav filename=[Filename].wav "$files"
					mv "${files%.*}".mini2sf.wav "${files%.*}".wav &>/dev/null						# Rename trick
					mv "${files%.*}".MINI2SF.wav "${files%.*}".wav &>/dev/null						# Rename trick
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*mod|*MOD)						# PC, Amiga - zxtune123 decode
					# Extract Tag
					if test -z "$TAG_GAME"; then
						echo "Please indicate the game title"
						read -e -p " -> " TAG_GAME
						echo
					fi
					if test -z "$TAG_ARTIST"; then
						echo "Please indicate the artist"
						read -e -p " -> " TAG_ARTIST
						echo
					fi
					if test -z "$TAG_DATE"; then
						echo "Please indicate the date of release"
						read -e -p " -> " TAG_DATE
						echo
					fi
					if test -z "$TAG_MACHINE"; then
						echo "Please indicate the platform of release"
						read -e -p " -> " TAG_MACHINE
						echo
					fi
					TAG_SONG="${files%.*}"
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"
					# Extract VGM
					zxtune123 --wav filename=[Filename].wav "$files"
					mv "${files%.*}".mod.wav "${files%.*}".wav &>/dev/null						# Rename trick
					mv "${files%.*}".MOD.wav "${files%.*}".wav &>/dev/null						# Rename trick
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*nsf|*NSF)						# Nintendo NES 
					if [ "$NBM3U" -gt "0" ]; then		# If m3u

						# Extract Tag
						# nsf parser
						strings "$files" | head -4 > "$VGM_TAG"										# Tag record
						if test -z "$TAG_GAME"; then
							TAG_GAME=$(cat "$VGM_TAG" | sed '2q;d')
							if test -z "$TAG_GAME"; then
								echo "Please indicate the game title"
								read -e -p " -> " TAG_GAME
								echo
							fi
						fi
						if test -z "$TAG_ARTIST"; then
							TAG_ARTIST=$(cat "$VGM_TAG" | sed '3q;d')
							if test -z "$TAG_ARTIST"; then
								echo "Please indicate the artist"
								read -e -p " -> " TAG_ARTIST
								echo
							fi
						fi
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							read -e -p " -> " TAG_DATE
							echo
						fi
						TAG_MACHINE="NES"
						TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album

						# m3u parser
						cat "${LSTM3U[0]}" | sed '/^#/d' | uniq | sed -r '/^\s*$/d' | sort -t, -k2,2 -n  > "$VGM_TAG"			# Tag record 2
						NSF-m3u-parser() {
							TAG_TRACKM3U=()
							TAG_TRACK1=()
							TAG_SONG=()
							TAG_SONG1=()
							TAG_DURATION=()
							TAG_DURATION1=()
							TAG_FADING=()
							TAG_FADING1=()
							while IFS=',' read FileFormat1 TAG_TRACK1 TAG_SONG1 TAG_DURATION1 Loop1 TAG_FADING1; do
								TAG_TRACKM3U+=("$TAG_TRACK1")
								TAG_SONG+=("$TAG_SONG1")
								TAG_DURATION+=("$TAG_DURATION1")
								TAG_FADING+=("$TAG_FADING1")
							done < "$VGM_TAG"
						}

						# M3U parser
						NSF-m3u-parser
						# NSF/m3u track count
						NSFTrackNumber=$(ffprobe "$files" 2>&1 | grep "track" | awk '{print $NF}')
						M3UTrackNumber=$(wc -l "$VGM_TAG" | awk '{print $1}')

						# Make clean m3u loop
						while true; do 
							for (( i=0; i<=$(( $NSFTrackNumber -1 )); i++ )); do
								if [ "${TAG_TRACKM3U[i]}" != $(($i+1)) ]; then
									NB=$(($i+1))
									if [[ "$NB" -lt "$M3UTrackNumber" ]]; then
										sed -i "${NB} i \\X.nsf::NSF,${NB},[untitled],0:03:00,,0:00:00" "$VGM_TAG"
									else
										echo "X.nsf::NSF,$NB,[untitled],0:03:00,,0:00:00" >> "$VGM_TAG"
									fi
									#exit
									NSF-m3u-parser															# relaunch M3U parser
									M3UTrackNumber=$(wc -l "$VGM_TAG" | awk '{print $1}')
								fi
								if [[ "$NSFTrackNumber" -eq "$M3UTrackNumber" ]]; then
									break
								fi
							done
							if [[ "$NSFTrackNumber" -eq "$M3UTrackNumber" ]]; then
								break
							fi
						done

						# Extract VGM
						zxtune123 --wav filename=[Subpath].wav "$files"

						# Rename trick, add 0 if one digit - for keep good order
						RenameOneDigit

						# generate files source array
						mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -regex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
						NBA="${#LSTAUDIO[@]}"

						# mu3/wav/flac loop
						unset TAG_TRACK
						TAG_SDURATION=()
						for (( i=0; i<=$(( $NBA -1 )); i++ )); do
							# Tag Track increment
							TAG_TRACK=$(($i+1))
							# Track leading 0
							number=$(echo "$TAG_TRACK" | sed 's/[^0-9]*//g')
							padded=$(printf "%02d" $number)
							TAG_TRACK=$(echo "$TAG_TRACK" | sed "s/${number}/${padded}/")

							# Duration treat
							if [ -n "${TAG_DURATION[i]}" ]; then
								TAG_SDURATION[i]=$(echo ${TAG_DURATION[i]} | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')		# Total duration in s
								TAG_FADING[i]=$(echo ${TAG_FADING[i]} | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')			# Fading duration in s
								if (( $(echo "${TAG_FADING[i]} > ${TAG_SDURATION[i]}" | bc -l) )); then								# prevent incoherence duration between fade out and total duration
									TAG_FADING[i]="0"
								elif [ "${TAG_FADING[i]}" = "0" ] && (( $(echo "${TAG_SDURATION[i]} > 30" | bc -l) )); then			# If no fading for audio > 30s, add 3s of fade
									TAG_FADING[i]="3"
								fi
								TAG_FDURATION=$(echo "${TAG_SDURATION[i]} - ${TAG_FADING[i]}" | bc)									# Total duration - Fade out duration

								# Duration/fading clean
								ffmpeg $FFMPEG_LOG_LVL -y -i "${LSTAUDIO[i]}" -t ${TAG_SDURATION[i]} -af "afade=t=out:st=$TAG_FDURATION:d=${TAG_FADING[i]}" -acodec pcm_s16le -ar 44100 -f wav temp-"${LSTAUDIO[i]%.*}".wav &>/dev/null
								rm "${LSTAUDIO[i]%.*}".wav
								mv temp-"${LSTAUDIO[i]%.*}".wav "${LSTAUDIO[i]%.*}".wav
							fi

							# Sox remove silence
							TEST_DURATION=$(mediainfo --Output="General;%Duration%" "${LSTAUDIO[i]%.*}".wav)
							if [[ "$TEST_DURATION" -gt 10000 ]] ; then
								sox "${LSTAUDIO[i]%.*}".wav temp-out.wav silence -l 1 0.1 0.01% -1 2.0 0.01%
								rm "${LSTAUDIO[i]%.*}".wav &>/dev/null
								mv temp-out.wav "${LSTAUDIO[i]%.*}".wav &>/dev/null
							fi

							# FFmpeg normalization & test channel
							TESTDB=$(ffmpeg -i "${LSTAUDIO[i]%.*}".wav -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
							if [[ $TESTDB = *"-"* ]]; then
								GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
								afilter="-af volume=$GREPVOLUME"
							else
								afilter=""
							fi
							TESTLEFT=$(ffmpeg -i "${LSTAUDIO[i]%.*}".wav -map_channel 0.0.0 -f md5 - 2>/dev/null)
							TESTRIGHT=$(ffmpeg -i "${LSTAUDIO[i]%.*}".wav -map_channel 0.0.1 -f md5 - 2>/dev/null)
							if [ "$TESTLEFT" = "$TESTRIGHT" ]; then
								confchan="-channel_layout mono"
							else
								confchan=""
							fi
							ffmpeg $FFMPEG_LOG_LVL -y -i "${LSTAUDIO[i]%.*}".wav $afilter $confchan -acodec pcm_s16le -f wav temp-out.wav &>/dev/null
							rm "${LSTAUDIO[i]%.*}".wav &>/dev/null
							mv temp-out.wav "${LSTAUDIO[i]%.*}".wav &>/dev/null

							# FFmpeg final flac encoding
							StartLoading "" "Encoding: $TAG_TRACK - ${TAG_SONG[i]}.flac"
							ffmpeg -y -i "${LSTAUDIO[i]%.*}".wav -acodec flac -compression_level 12 -sample_fmt s16 -metadata TRACK="$TAG_TRACK" -metadata title="${TAG_SONG[i]}" -metadata album="$TAG_ALBUM" -metadata artist="$TAG_ARTIST" -metadata date="$TAG_DATE" "$TAG_TRACK - ${TAG_SONG[i]}".flac  &>/dev/null
							StopLoading $?
						done

					else								# if no m3u
						# Extract Tag
						strings "$files" | head -4 > "$VGM_TAG"										# Tag record
						if test -z "$TAG_GAME"; then
							TAG_GAME=$(cat "$VGM_TAG" | sed '2q;d')
							if test -z "$TAG_GAME"; then
								echo "Please indicate the game title"
								read -e -p " -> " TAG_GAME
								echo
							fi
						fi
						if test -z "$TAG_ARTIST"; then
							TAG_ARTIST=$(cat "$VGM_TAG" | sed '3q;d')
							if test -z "$TAG_ARTIST"; then
								echo "Please indicate the artist"
								read -e -p " -> " TAG_ARTIST
								echo
							fi
						fi
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							read -e -p " -> " TAG_DATE
							echo
						fi
						TAG_SONG="[untitled]"
						TAG_MACHINE="NES"
						TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"
						# Extract VGM
						zxtune123 --wav filename=[Subpath].wav "$files"

						# Rename trick, add 0 if one digit - for keep good order
						RenameOneDigit

						# generate files source array
						mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -regex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
						NBA="${#LSTAUDIO[@]}"

						for files in "${LSTAUDIO[@]}"; do
							# Remove silence
							Sox_vgm_cmd_silence
							# Normalization & false stereo detection
							FFmpeg_vgm_cmd_norm_stereo
							# Encoding flac
							FFmpeg_vgm_cmd
							# Track tag
							TAG_TRACK=$(($COUNTER+1))
							COUNTER=$TAG_TRACK
							# Track leading 0
							number=$(echo "$TAG_TRACK" | sed 's/[^0-9]*//g')
							padded=$(printf "%02d" $number)
							TAG_TRACK=$(echo "$TAG_TRACK" | sed "s/${number}/${padded}/")
						done
					fi
				;;

				*hes|*HES)						# NEC PC-Engine / TurboGrafx-16
					# Tags record 1
					if test -z "$TAG_GAME"; then
						echo "Please indicate the game title"
						read -e -p " -> " TAG_GAME
						echo
					fi
					if test -z "$TAG_ARTIST"; then
						echo "Please indicate the artist"
						read -e -p " -> " TAG_ARTIST
						echo
					fi
					if test -z "$TAG_DATE"; then
						echo "Please indicate the date of release"
						read -e -p " -> " TAG_DATE
						echo
					fi
					TAG_MACHINE="PC-Engine"
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album

					if [ "$NBM3U" -gt "0" ]; then		# If m3u

						cat "${LSTM3U[0]}" | sed '/^#/d' | uniq | sed -r '/^\s*$/d' | tr -d '$' \
						| awk --non-decimal-data -F ',' -v OFS=',' '$1 {$2=("0x"$2)+1; print}' \
						| sort -t, -k2,2 -n  > "$VGM_TAG"			# Tags record 2

						HES-m3u-parser() {
							TAG_TRACKM3U=()
							TAG_TRACK1=()
							TAG_SONG=()
							TAG_SONG1=()
							TAG_DURATION=()
							TAG_DURATION1=()
							TAG_FADING=()
							TAG_FADING1=()
							while IFS=',' read FileFormat1 TAG_TRACK1 TAG_SONG1 TAG_DURATION1 Loop1 TAG_FADING1; do
								TAG_TRACKM3U+=("$TAG_TRACK1")
								TAG_SONG+=("$TAG_SONG1")
								TAG_DURATION+=("$TAG_DURATION1")
								TAG_FADING+=("$TAG_FADING1")
							done < "$VGM_TAG"
						}

						# M3U parser
						HES-m3u-parser
						# NSF/m3u track count
						HESTrackNumber=$(ffprobe "$files" 2>&1 | grep "track" | awk '{print $NF}')
						M3UTrackNumber=$(wc -l "$VGM_TAG" | awk '{print $1}')

						# Make clean m3u loop
						while true; do 
							for (( i=0; i<=$(( $HESTrackNumber -1 )); i++ )); do
								if [ "${TAG_TRACKM3U[i]}" != $(($i+1)) ]; then
									NB=$(($i+1))
									if [[ "$NB" -lt "$M3UTrackNumber" ]]; then
										sed -i "${NB} i \\X.hes::HES,${NB},[untitled],0:03:00,,0:00:00" "$VGM_TAG"
									else
										echo "X.hes::HES,$NB,[untitled],0:03:00,,0:00:00" >> "$VGM_TAG"
									fi
									#exit
									HES-m3u-parser															# relaunch M3U parser
									M3UTrackNumber=$(wc -l "$VGM_TAG" | awk '{print $1}')
								fi
								if [[ "$HESTrackNumber" -eq "$M3UTrackNumber" ]]; then
									break
								fi
							done
							if [[ "$HESTrackNumber" -eq "$M3UTrackNumber" ]]; then
								break
							fi
						done

						# Extract VGM
						zxtune123 --wav filename=[Subpath].wav "$files"

						# Rename trick, add 0 if one digit - for keep good order
						RenameOneDigit

						# generate files source array
						mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -regex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
						NBA="${#LSTAUDIO[@]}"

						# mu3/wav/flac loop
						unset TAG_TRACK
						TAG_SDURATION=()
						for (( i=0; i<=$(( $NBA -1 )); i++ )); do
							# Tag Track increment
							TAG_TRACK=$(($i+1))
							# Track leading 0
							number=$(echo "$TAG_TRACK" | sed 's/[^0-9]*//g')
							padded=$(printf "%02d" $number)
							TAG_TRACK=$(echo "$TAG_TRACK" | sed "s/${number}/${padded}/")

							# Duration process
							if [ -n "${TAG_DURATION[i]}" ]; then
								if [[ "${TAG_DURATION[i]}" == *":"* ]]; then
									TAG_SDURATION=$(echo ${TAG_DURATION[i]} | awk -F: '{ print ($1 * 60) + $2 }')					# Total duration in s
								else
									TAG_SDURATION=$(echo "${TAG_DURATION[i]}")
								fi
								if [[ "${TAG_FADING[i]}" == *":"* ]]; then
									TAG_FADING[i]=$(echo ${TAG_FADING[i]/$'\r'/} | awk -F: '{ print ($1 * 60) + $2 }')				# Fading duration in s
								else
									TAG_FADING[i]=$(echo "${TAG_FADING[i]/$'\r'/}")
								fi
								if (( $(echo "${TAG_FADING[i]} > $TAG_SDURATION" | bc -l) )); then									# prevent incoherence duration between fade out and total duration
									TAG_FADING[i]="0"
								elif [ "${TAG_FADING[i]}" = "0" ] && (( $(echo "$TAG_SDURATION > 30" | bc -l) )); then				# If no fading for audio > 30s, add 3s of fade
									TAG_FADING[i]="3"
								fi
								TAG_FDURATION=$(echo "$TAG_SDURATION - ${TAG_FADING[i]}" | bc -l)									# Total duration - Fade out duration

								# Duration/fading clean
								ffmpeg $FFMPEG_LOG_LVL -y -i "${LSTAUDIO[i]}" -t $TAG_SDURATION -af "afade=t=out:st=$TAG_FDURATION:d=${TAG_FADING[i]}" -acodec pcm_s16le -ar 44100 -f wav temp-"${LSTAUDIO[i]%.*}".wav &>/dev/null
								rm "${LSTAUDIO[i]%.*}".wav
								mv temp-"${LSTAUDIO[i]%.*}".wav "${LSTAUDIO[i]%.*}".wav
							fi

							# Sox remove silence
							TEST_DURATION=$(mediainfo --Output="General;%Duration%" "${LSTAUDIO[i]%.*}".wav)
							if [[ "$TEST_DURATION" -gt 10000 ]] ; then
								sox "${LSTAUDIO[i]%.*}".wav temp-out.wav silence -l 1 0.1 0.01% -1 2.0 0.01%
								rm "${LSTAUDIO[i]%.*}".wav &>/dev/null
								mv temp-out.wav "${LSTAUDIO[i]%.*}".wav &>/dev/null
							fi

							# FFmpeg normalization & test channel
							TESTDB=$(ffmpeg -i "${LSTAUDIO[i]%.*}".wav -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
							if [[ $TESTDB = *"-"* ]]; then
								GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
								afilter="-af volume=$GREPVOLUME"
							else
								afilter=""
							fi
							TESTLEFT=$(ffmpeg -i "${LSTAUDIO[i]%.*}".wav -map_channel 0.0.0 -f md5 - 2>/dev/null)
							TESTRIGHT=$(ffmpeg -i "${LSTAUDIO[i]%.*}".wav -map_channel 0.0.1 -f md5 - 2>/dev/null)
							if [ "$TESTLEFT" = "$TESTRIGHT" ]; then
								confchan="-channel_layout mono"
							else
								confchan=""
							fi
							ffmpeg $FFMPEG_LOG_LVL -y -i "${LSTAUDIO[i]%.*}".wav $afilter $confchan -acodec pcm_s16le -f wav temp-out.wav &>/dev/null
							rm "${LSTAUDIO[i]%.*}".wav &>/dev/null
							mv temp-out.wav "${LSTAUDIO[i]%.*}".wav &>/dev/null

							# FFmpeg final flac encoding
							StartLoading "" "Encoding: $TAG_TRACK - ${TAG_SONG[i]}.flac"
							ffmpeg -y -i "${LSTAUDIO[i]%.*}".wav -acodec flac -compression_level 12 -sample_fmt s16 -metadata TRACK="$TAG_TRACK" -metadata title="${TAG_SONG[i]}" -metadata album="$TAG_ALBUM" -metadata artist="$TAG_ARTIST" -metadata date="$TAG_DATE" "$TAG_TRACK - ${TAG_SONG[i]}".flac  &>/dev/null
							StopLoading $?
						done

					else								# if no m3u
						# Tag
						TAG_SONG="[untitled]"

						# Extract VGM
						zxtune123 --wav filename=[Subpath].wav "$files"

						# Rename trick, add 0 if one digit - for keep good order
						RenameOneDigit

						# generate files source array
						mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -regex '.*\.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
						NBA="${#LSTAUDIO[@]}"

						for files in "${LSTAUDIO[@]}"; do
							# Remove silence
							Sox_vgm_cmd_silence
							# Normalization & false stereo detection
							FFmpeg_vgm_cmd_norm_stereo
							# Encoding flac
							FFmpeg_vgm_cmd
							# Track tag
							TAG_TRACK=$(($COUNTER+1))
							COUNTER=$TAG_TRACK
							# Track leading 0
							number=$(echo "$TAG_TRACK" | sed 's/[^0-9]*//g')
							padded=$(printf "%02d" $number)
							TAG_TRACK=$(echo "$TAG_TRACK" | sed "s/${number}/${padded}/")
						done
						wait
					fi
				;;

				*xa|*XA)					# Sony Playstation - ffmpeg decode
					# Extract Tag
					if test -z "$TAG_GAME"; then
						echo "Please indicate the game title"
						read -e -p " -> " TAG_GAME
						echo
					fi
					if test -z "$TAG_ARTIST"; then
						echo "Please indicate the artist"
						read -e -p " -> " TAG_ARTIST
						echo
					fi
					if test -z "$TAG_DATE"; then
						echo "Please indicate the date of release"
						read -e -p " -> " TAG_DATE
						echo
					fi
					TAG_MACHINE="PS1"
					TAG_SONG="${files%.*}"
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"
					# Extract VGM
					ffmpeg $FFMPEG_LOG_LVL -y -i "$files" -acodec pcm_s16le -ar 37800 -f wav "${files%.*}".wav
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*ast|*AST|*at3|*AT3|*dat|*DAT|*mus|*MUS|*voc|*VOC|*tak|*TAK)					# Various Machine - ffmpeg decode
					# Extract Tag
					if test -z "$TAG_GAME"; then
						echo "Please indicate the game title"
						read -e -p " -> " TAG_GAME
						echo
					fi
					if test -z "$TAG_ARTIST"; then
						echo "Please indicate the artist"
						read -e -p " -> " TAG_ARTIST
						echo
					fi
					if test -z "$TAG_DATE"; then
						echo "Please indicate the date of release"
						read -e -p " -> " TAG_DATE
						echo
					fi
					if test -z "$TAG_MACHINE"; then
						echo "Please indicate the platform of release"
						read -e -p " -> " TAG_MACHINE
						echo
					fi
					TAG_SONG="${files%.*}"
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"
					# Extract VGM
					ffmpeg $FFMPEG_LOG_LVL -y -i "$files" -acodec pcm_s16le -f wav "${files%.*}".wav
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*spc|*SPC)					# Nintendo SNES - ffmpeg decode
					# Extract Tag
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(espctag -G "$files" | cut -c14-)
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							read -e -p " -> " TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_DATE"; then
						echo "Please indicate the date of release"
						read -e -p " -> " TAG_DATE
						echo
					fi
					TAG_SONG=$(espctag -S "$files" | cut -c14-)
					if test -z "$TAG_SONG"; then
						TAG_SONG="${files%.*}"
					fi
					TAG_ARTIST=$(espctag -A "$files" | cut -c10-)
					TAG_MACHINE="SNES"																# Album part 2
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album
					TAG_DURATION=$(espctag -L "$files" | awk '{print $3;}')
					TAG_FADING=$(espctag -F "$files" | awk '{print $4;}')
					TAG_SFADING=$(($TAG_FADING/1000))
					TAG_TDURATION=$(($TAG_DURATION+$TAG_SFADING))

					# Extract VGM
					ffmpeg $FFMPEG_LOG_LVL -y -i "$files" -t $TAG_TDURATION -af "afade=t=out:st=$TAG_DURATION:d=$TAG_SFADING" -acodec pcm_s16le -ar 32000 -f wav "${files%.*}".wav &>/dev/null
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*ads|*ADS|*adp|*ADP|*aif|*AIF|*aifc|*AIFC|*ss2|*SS2|*adx|*ADX|*bfstm|*BFSTM|*bfwav|*BFWAV|*dsp|*DSP|*eam|*EAM|*hps|*HPS|*int|*INT|*rak|*RAK|*raw|*RAW|*sng|*SNG|*spsd|*SPSD|*str|*STR|*thp|*THP|*vag|*VAG|*vgs|*VGS|*vpk|*VPK|*wem|*WEM|*xwav|*XWAV|*bcstm|*BCSTM|*bcwav|*BCWAV|*fsb|*FSB|*msf|*MSF|*ktss|*KTSS)					# Various Machines
					# Extract Tag
					if test -z "$TAG_GAME"; then
						echo "Please indicate the game title"
						read -e -p " -> " TAG_GAME
						echo
					fi
					if test -z "$TAG_ARTIST"; then
						echo "Please indicate the artist"
						read -e -p " -> " TAG_ARTIST
						echo
					fi
					if test -z "$TAG_DATE"; then
						echo "Please indicate the date of release"
						read -e -p " -> " TAG_DATE
						echo
					fi
					if test -z "$TAG_MACHINE"; then
						echo "Please indicate the platform of release"
						read -e -p " -> " TAG_MACHINE
						echo
					fi
					TAG_SONG="${files%.*}"
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"
					# Extract VGM
					vgmstream-cli -o "${files%.*}".wav "$files"
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
				;;

				*bin|*BIN)						# Various Machines CD-DA bin
					if [ "$NBCUE" -eq "0" ]; then                                       # If no cue
					# Extract Tag
					if test -z "$TAG_GAME"; then
						echo "Please indicate the game title"
						read -e -p " -> " TAG_GAME
						echo
					fi
					if test -z "$TAG_ARTIST"; then
						echo "Please indicate the artist"
						read -e -p " -> " TAG_ARTIST
						echo
					fi
					if test -z "$TAG_DATE"; then
						echo "Please indicate the date of release"
						read -e -p " -> " TAG_DATE
						echo
					fi
					if test -z "$TAG_MACHINE"; then
						echo "Please indicate the platform of release"
						read -e -p " -> " TAG_MACHINE
						echo
					fi
					TAG_SONG="[untitled]"
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"
					# Extract VGM
					sox -t raw -r 44100 -b 16 -c 2 -L -e signed-integer "$files" "${files%.*}".wav
					# Remove silence
					Sox_vgm_cmd_silence
					# Normalization & false stereo detection
					FFmpeg_vgm_cmd_norm_stereo
					# Encoding flac
					FFmpeg_vgm_cmd
					fi
				;;

			esac

	done
}
VGMRip_Clean() {				# Clean & arrange VGM rip files
	# Arrange
	VGM_DIR1="$TAG_GAME ($TAG_DATE) ($TAG_MACHINE)"
	VGM_DIR=$(echo $VGM_DIR1 | sed s#/#-#g)				# Replace eventualy "/" in string
	if [ ! -d "$VGM_DIR" ]; then
		mkdir "$VGM_DIR"
	fi
	mv -- *.flac "$VGM_DIR" &>/dev/null
	
	# Clean
	read -p " Remove wav source audio? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			rm -- *.wav &>/dev/null
			Restart
		;;
		*)
			Restart
		;;
	esac
}

# Arguments variables & usage
if [ -d "$1" ]; then								# If target is directory
    cd "$1" || exit									# Move to directory
elif [ -f "$1" ]; then                              # If target is file
    TESTARGUMENT1=$(mediainfo "$1" | grep -E 'Video|Audio|ISO' | head -n1)
    TESTARGUMENT2=$(file "$1" | grep -i -E 'Video|Audio')
    if [[ -z "$TESTARGUMENT1" ]] && [[ -n "$TESTARGUMENT2" ]] ; then
		TESTARGUMENT="$TESTARGUMENT2"
	else
		TESTARGUMENT="$TESTARGUMENT1"
	fi
    if test -n "$TESTARGUMENT"; then
        ARGUMENT="$1"
    else
        echo
        echo "  Missed, \"$1\" is not a video, audio or ISO file."
        echo
        exit
    fi
elif test -n "$1"; then								# If don't understand/help
	Usage
    exit
fi

CheckCacheDirectory                     # Check if cache directory exist
StartLoading "Search the files processed"
SetGlobalVariables                      # Set global variable
DetectCDDVD								# CD/DVD detection
StopLoading $?
trap TrapExit 2 3						# Set Ctrl+c clean trap for exit all script
trap TrapStop 20						# Set Ctrl+z clean trap for exit current loop (for debug)
MainMenu                                # Display main menu

while true; do
echo "  [q]exit [m]menu [r]restart"
read -e -p "  -> " reps

case $reps in

 restart | rst | r )
    Restart
    ;;

 exit | quit | q )
    TrapExit
    ;;

 main | menu | m )
    MainMenu
    ;;

 0 ) # DVD rip (experimental)
    DVDRip
    StartLoading "Analysis of the file: ${LSTVIDEO[0]}"
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
	if [ "$NBV" -gt "0" ]; then
	MultipleVideoExtention
    StartLoading "Analysis of the file: ${LSTVIDEO[0]}"
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
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
	;;

 2 ) # video -> mkv|copy|copy
 	if [ "$NBV" -gt "0" ]; then
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # VIDEO ---------------------------------------------------------------------------------
    videoconf="-c:v copy"
    # AUDIO ---------------------------------------------------------------------------------
    soundconf="-c:a copy"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="mkv"
    container="matroska"
    # NAME ----------------------------------------------------------------------------------
    videoformat="avcopy.acopy"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    MultipleVideoExtention
    StartLoading "Analysis of the file: ${LSTVIDEO[0]}"
	VideoSourceInfo
	StopLoading $?
    CustomVideoStream                              # question for make stream custom encoding (appear source have more of 2 streams)
	FFmpeg_video_cmd                               # encoding
	RemoveVideoSource
	Clean                                          # clean temp files
	else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
	;;

 10 ) # tools -> view stats
	if [ "$NBV" -gt "0" ]; then
	echo
	mediainfo "${LSTVIDEO[0]}"
	else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
	;;

 11 ) # video -> mkv|copy|add audio|add sub
	if [[ "$NBV" -eq "1" ]] && [[ "$NBSUB" -gt 0 || "$NBA" -gt 0 ]]; then
	# CONF_START ////////////////////////////////////////////////////////////////////////////
    # NAME ----------------------------------------------------------------------------------
    videoformat="addcopy"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    StartLoading "Analysis of the file: ${LSTVIDEO[0]}"
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
	if [ "$NBV" -gt "1" ] && [ "$NBVEXT" -eq "1" ]; then
	ConcatenateVideo
    StartLoading "Analysis of the file: ${LSTVIDEO[0]}"
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
        if [[ "$NBV" -le "1" ]]; then
			echo "$MESS_BATCH_FILE_AUTH"
        fi
        if [[ "$NBVEXT" != "1" ]]; then
			echo "$MESS_EXT_FILE_AUTH"
        fi
        echo
	fi
	;;

 13 ) # Extract stream video
	if [[ "$NBV" -eq "1" ]]; then
    StartLoading "Analysis of the file: ${LSTVIDEO[0]}"
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
	if [[ "$NBV" -eq "1" ]]; then
    StartLoading "Analysis of the file: ${LSTVIDEO[0]}"
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
	if [[ "$NBV" -eq "1" ]]; then
    StartLoading "Analysis of the file: ${LSTVIDEO[0]}"
	VideoAudioSourceInfo
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
	if [ "$NBV" -eq "1" ] && [[ "${LSTVIDEO[0]##*.}" = "mkv" ]]; then
    StartLoading "Analysis of the file: ${LSTVIDEO[0]}"
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
	if [[ $(echo "${LSTSUBEXT[@]}") = "idx" ]]; then
    DVDSubColor
	Clean                                          # clean temp files
	else
        echo
        echo "	-/!\- Only DVD subtitle extention type (idx/sub)."
        echo
	fi
	;;

 18 ) # Convert DVD subtitle to srt
	if [[ $(echo "${LSTSUBEXT[@]}") = "idx" ]]; then
    DVDSub2Srt
	Clean                                          # clean temp files
	else
        echo
        echo "	-/!\- Only DVD subtitle extention type (idx/sub)."
        echo
	fi
	;;

 20 ) # audio ->  CD Rip
	CDRip										   # quality questions & launch abcde
	;;

 21 ) # vgm ->  audio
	if [ "$KERNEL_TYPE" = "Linux x86_64" ] && [[ "$NBVGM" -gt "0" || "$NBVGMISO" -gt "0" ]] && [ "$NBGBS" -le "1" ]; then
	VGMRip
	VGMRip_Clean
    Clean                                          # clean temp files
    fi
	if [ "$KERNEL_TYPE" != "Linux x86_64" ]; then
		echo
		echo "$MESS_UNAME_AUTH"
		echo
	fi
	if [ "$NBVGM" -eq "0" ]; then
		echo
		echo "$MESS_ZERO_FILE_AUTH"
		echo
	fi
	if [[ "$GBSCOUNT" -gt "1" ]]; then
		echo
		echo "	-/!\- Only one gbs file at a time."
		echo
	fi
	;;

 211 ) # vgm amiga ->  audio
	# CONF_START ////////////////////////////////////////////////////////////////////////////
	PeakNorm="1"
	TestFalseStereo="1"
	SilenceDetect="1"
    # AUDIO ---------------------------------------------------------------------------------
    stream="-map 0:a"
    acodec="-acodec flac"
    akb="-compression_level 12 -sample_fmt s16"
    soundconf="$acodec $akb" 
    # CONTAINER -----------------------------------------------------------------------------
    extcont="flac"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
	VGMRip_amiga
	VGMRip_Clean
	Clean                                          # clean temp files
	;;

 22 ) # audio -> CUE splitter
	if [ "$NBA" -gt "0" ]; then
    SplitCUE
    Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
    ;;

 23 ) # audio -> PCM
	if [ "$NBA" -gt "0" ]; then
	MultipleAudioExtention
    AudioSourceInfo
    ConfPCM
    ConfChannels
    ConfPeakNorm
    ConfTestFalseStereo
    ConfSilenceDetect
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # AUDIO ---------------------------------------------------------------------------------
    soundconf="$acodec $akb"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="wav"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    FFmpeg_audio_cmd                               # encoding
    RemoveAudioSource
    RemoveAudioTarget
    Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
    ;;

 24 ) # audio -> flac lossless
	if [ "$NBA" -gt "0" ]; then
	MultipleAudioExtention
    AudioSourceInfo
    ConfFLAC
    ConfChannels
    ConfPeakNorm
    ConfTestFalseStereo
    ConfSilenceDetect
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # AUDIO ---------------------------------------------------------------------------------
    acodec="-acodec flac"
    soundconf="$acodec $akb"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="flac"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    FFmpeg_audio_cmd                               # encoding
    RemoveAudioSource
    RemoveAudioTarget
    Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
    ;;

 25 ) # audio -> mp3 @ vbr190-250kb
	if [ "$NBA" -gt "0" ]; then
	MultipleAudioExtention
    AudioSourceInfo
    ConfMP3
    ConfPeakNorm
    ConfTestFalseStereo
    ConfSilenceDetect
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # AUDIO ---------------------------------------------------------------------------------
    acodec="-acodec libmp3lame"
    confchan="-ac 2"
    soundconf="$acodec $akb"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="mp3"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    FFmpeg_audio_cmd                               # encoding
    RemoveAudioSource
    RemoveAudioTarget
    Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
    ;;

 26 ) # audio -> ogg
	if [ "$NBA" -gt "0" ]; then
	MultipleAudioExtention
    AudioSourceInfo
    ConfOGG
    ConfChannels
    ConfPeakNorm
    ConfTestFalseStereo
    ConfSilenceDetect
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # AUDIO ---------------------------------------------------------------------------------
    acodec="-acodec libvorbis"
    soundconf="$acodec $akb"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="ogg"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    FFmpeg_audio_cmd                               # encoding
    RemoveAudioSource
    RemoveAudioTarget
    Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
    ;;

 27 ) # audio -> opus
	if [ "$NBA" -gt "0" ]; then
	AudioCodecType="Opus"
	MultipleAudioExtention
    AudioSourceInfo
    ConfOPUS
    ConfChannels
    ConfPeakNorm
    ConfTestFalseStereo
    ConfSilenceDetect
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # AUDIO ---------------------------------------------------------------------------------
    acodec="-acodec libopus"
    soundconf="$acodec $akb"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="opus"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    FFmpeg_audio_cmd                               # encoding
    RemoveAudioSource
    RemoveAudioTarget
    Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
    ;;

 30 ) # tools -> view stats
	if [ "$NBA" -gt "0" ]; then
	AudioTagEditor
	else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
	;;


 31 ) # tools -> view stats
	if [ "$NBA" -gt "0" ]; then
	MultipleAudioExtention
	echo
	mediainfo "${LSTAUDIO[0]}"
	else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
	;;

 32 ) # audio -> generate png of audio spectrum
	if [ "$NBA" -gt "0" ]; then
	MultipleAudioExtention
    AudioSourceInfo
    AudioSpectrum
    Clean
    else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
    ;;

 33 ) # Concatenate audio
	if [ "$NBA" -gt "1" ] && [ "$NBAEXT" -eq "1" ]; then
	ConcatenateAudio
	RemoveAudioSource
	Clean                                          # clean temp files
	else
        echo
        if [[ "$NBA" -le "1" ]]; then
			echo "$MESS_BATCH_FILE_AUTH"
        fi
        if [[ "$NBAEXT" != "1" ]]; then
			echo "$MESS_EXT_FILE_AUTH"
        fi
        echo
	fi
	;;

 34 ) # Cut audio
	if [[ "$NBA" -eq "1" ]]; then
	AudioSourceInfo
    CutAudio
	Clean                                          # clean temp files
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

esac
done
exit
