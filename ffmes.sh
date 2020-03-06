#!/bin/bash
# ffmes - ffmpeg media encode script
# Terminal tool handling media files, DVD, audio CD, and VGM. Mainly with ffmpeg. Batch or single file.
#
# Author : Romain Barbarot
# https://github.com/Jocker666z/ffmes/
#
# licence : GNU GPL-2.0

# Version
VERSION=v0.35

# Paths
FFMES_PATH="$( cd "$( dirname "$0" )" && pwd )"												# set ffmes.sh path for restart from any directory
FFMES_CACHE="/home/$USER/.cache/ffmes"														# cache directory
FFMES_CACHE_STAT="/home/$USER/.cache/ffmes/stat-$(date +%Y%m%s%N).info"						# stat-DATE.info, stats of source file
FFMES_CACHE_MAP="/home/$USER/.cache/ffmes/map-$(date +%Y%m%s%N).info"						# map-DATE.info, map file
FFMES_CACHE_TAG="/home/$USER/.cache/ffmes/tag-$(date +%Y%m%s%N).info"						# tag-DATE.info, audio tag file
LSDVD_CACHE="/home/$USER/.cache/ffmes/lsdvd-$(date +%Y%m%s%N).info"							# lsdvd cache
ABCDE_EXTRACT="/home/$USER/Music"															# abcde extract directory
ABCDE_CONF="$FFMES_PATH/conf/abcde-ffmes.conf"												# abcde configuration file
VGM_TAG="/home/$USER/.cache/ffmes/vgmtag.info"												# vgm tag cache
DVD_DEVICE="/dev/$(cat /proc/sys/dev/cdrom/info 2>/dev/null | grep "drive name:" | awk '{print $3}')"	# CD/DVD player drive name

# General variables
NPROC=$(nproc --all| awk '{ print $1 - 1 }')							# Set number of processor
KERNEL_TYPE=$(uname -sm)												# Grep type of kernel, use for limit usage of VGM rip to Linux x86_64
TERM_WIDTH=$(stty size | awk '{print $2}' | awk '{ print $1 - 10 }')	# Get terminal width, and truncate
COMMAND_NEEDED=(ffmpeg abcde sox mediainfo lsdvd mkvmerge dvdbackup find nproc shntool cuetag uchardet iconv wc bc du awk bchunk)
CUE_EXT_AVAILABLE="cue"

# Video variables
FFMPEG_LOG_LVL="-hide_banner -loglevel panic -stats"					# Comment for view all ffmpeg log
VIDEO_EXT_AVAILABLE="mkv|vp9|m4v|m2ts|avi|ts|mts|mpg|flv|mp4|mov|wmv|3gp|vob|mpeg|webm|ogv|bik"
SUBTI_EXT_AVAILABLE="srt|ssa"
ISO_EXT_AVAILABLE="iso"
VOB_EXT_AVAILABLE="vob"
X265_LOG_LVL="log-level=error:"											# Comment for view all x265 codec log
NVENC="1"																# Set number of video encoding in same time, the countdown starts at 0, so 0 is worth one encoding at a time (0=1;1=2...)

# Audio variables
AUDIO_EXT_AVAILABLE="aif|wma|opus|aud|dsf|wav|ac3|aac|ape|m4a|mp3|flac|ogg|mpc|spx|mod|mpg|wv"

# VGM variables
VGM_EXT_AVAILABLE="ads|adp|adx|ast|at3|bfstm|bfwav|gbs|dat|dsp|dsf|eam|hps|int|minipsf|miniusf|minipsf2|mod|mus|rak|raw|snd|sndh|spsd|ss2|ssf|spc|psf|psf2|vag|vgm|vgz|vpk|tak|thp|voc|xa|xwav"
VGM_ISO_EXT_AVAILABLE="bin"
M3U_EXT_AVAILABLE="m3u"
SPC_VSPCPLAY=""																	# Experimental, spc encoding with vspcplay, leave empty for desactivate, note '1' for activate.
PULSE_MONITOR="pulseaudio alsa_output.pci-0000_00_14.2.analog-stereo.monitor"	# Experimental, used for encoding spc with vspcplay, to get to know him typing: = 'pacmd list | grep ".monitor"', example output: 'pulseaudio alsa_output.pci-0000_00_14.2.analog-stereo.monitor'

# Messages
MESS_ZERO_FILE_AUTH="	-/!\- No file to process. Restart ffmes by selecting a file or in a directory containing it."
MESS_INVALID_ANSWER="	-/!\- Invalid answer, please try again."
MESS_ONE_VIDEO_FILE_AUTH="	-/!\- Only one video file at a time. Restart ffmes to select one video or in a directory containing one."
MESS_ONE_AUDIO_FILE_AUTH="	-/!\- Only one audio file at a time. Restart ffmes to select one audio or in a directory containing one."
MESS_BATCH_FILE_AUTH="	-/!\- Only more than one file file at a time. Restart ffmes in a directory containing several files."
MESS_EXT_FILE_AUTH="	-/!\- Only one extention type at a time."
MESS_UNAME_AUTH="	-/!\- Only for Linux x86_64."

# Arguments variables
if [ -d "$1" ]; then			# If target is directory
    cd "$1" || exit				# Move to directory
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
elif test -n "$1"; then                             # If don't understand/help
	echo "ffmes $VERSION - GNU GPL-2.0 Copyright - Written by Romain Barbarot <https://github.com/Jocker666z/ffmes>"
	echo
    echo "Usage: ffmes [option]"
    echo
    echo "ffmes options (set in alias):"
    echo "	ffmes				for launch main menu"
    echo "	ffmes file			for treat one file"
    echo "	ffmes /directory		for treat in batch a specific directory"
    echo
    echo "If ffmes is not set in alias replace \"ffmes\" by \"bash ~/ffmes/ffmes.sh\"."
    echo "However, it is strongly recommended to use an alias, "
    echo "but you can still continue to hurt yourself."
    echo
    exit
fi

## BINARIES SECTION
binmerge() { 
"$FFMES_PATH"/bin/binmerge "$@"
	}
espctag() { 
env LD_LIBRARY_PATH="$FFMES_PATH/bin/lib/" "$FFMES_PATH"/bin/espctag "$@"
	}
gbsplay() { 
"$FFMES_PATH"/bin/gbsplay "$@"
	}
gbsinfo() { 
"$FFMES_PATH"/bin/gbsinfo "$@"
	}
info68() { 
"$FFMES_PATH"/bin/info68 "$@"
	}
opustags() { 
"$FFMES_PATH"/bin/opustags "$@"
	}
sc68() { 
"$FFMES_PATH"/bin/sc68 "$@"
	}
vgm2wav() { 
"$FFMES_PATH"/bin/vgm2wav "$@"
	}
vgmstream-cli() { 
"$FFMES_PATH"/bin/vgmstream-cli "$@"
	}
vgm_tag() { 
"$FFMES_PATH"/bin/vgm_tag "$@"
	}
vspcplay() { 
"$FFMES_PATH"/bin/vspcplay "$@"
	}
zxtune123() { 
"$FFMES_PATH"/bin/zxtune123 "$@"
	}
## VARIABLES & MENU SECTION
SetGlobalVariables() {
	if test -n "$TESTARGUMENT"; then		# if argument
		if [[ $TESTARGUMENT == *"Video"* ]]; then
			LSTVIDEO=()
			LSTVIDEO+=("$ARGUMENT")
		elif [[ $TESTARGUMENT == *"Audio"* ]]; then
			LSTAUDIO=()
			LSTAUDIO+=("$ARGUMENT")
		elif [[ $TESTARGUMENT == *"ISO"* ]]; then
			LSTISO=()
			LSTISO+=("$ARGUMENT")
		fi
	else									# if no argument -> batch
		# List source(s) video file(s) & number of differents extentions
		mapfile -t LSTVIDEO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.+.('$VIDEO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
		mapfile -t LSTVIDEOEXT < <(echo "${LSTVIDEO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
		# List source(s) audio file(s) & number of differents extentions
		mapfile -t LSTAUDIO < <(find . -maxdepth 5 -type f -regextype posix-egrep -iregex '.+.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
		mapfile -t LSTAUDIOEXT < <(echo "${LSTAUDIO[@]##*.}" | awk -v RS="[ \n]+" '!n[$0]++')
		# List source(s) ISO file(s)
		mapfile -t LSTISO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.+.('$ISO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	fi
	# List source(s) subtitle file(s)
	mapfile -t LSTSUB < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.+.('$SUBTI_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	# List source(s) CUE file(s)
	mapfile -t LSTCUE < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.+.('$CUE_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	# List source(s) VOB file(s)
	mapfile -t LSTVOB < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.+.('$VOB_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	# List source(s) VGM file(s) & number of differents extentions
	mapfile -t LSTVGM < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.+.('$VGM_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	mapfile -t LSTVGMEXT < <(echo "${LSTVGM[@]##*.}")
	# List source(s) VGM ISO file(s)
	mapfile -t LSTVGMISO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.+.('$VGM_ISO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	# List source(s) M3U file(s)
	mapfile -t LSTM3U < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.+.('$M3U_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

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
Restart () {					# Restart script, for keep argument
	Clean
	if [ -f "$ARGUMENT" ]; then                              # If target is file
		bash "$FFMES_PATH"/ffmes.sh "$ARGUMENT" && exit
	else
		bash "$FFMES_PATH"/ffmes.sh && exit
	fi
}
TrapExit () {					# Ctrl+c Trap exit, for clean temp
	Clean
	echo
	echo
	exit
}
Clean() {
	find "$FFMES_CACHE/" -type f -mtime +3 -exec /bin/rm -f {} \;			# consider if file exist in cache directory after 3 days, delete it
	rm "$FFMES_CACHE_STAT" &>/dev/null
	rm "$FFMES_CACHE_MAP" &>/dev/null
	rm "$LSDVD_CACHE" &>/dev/null
	rm "$VGM_TAG" &>/dev/null
}
CheckCacheDirectory() {         # Check if cache directory exist
	if [ ! -d $FFMES_CACHE ]; then
		mkdir /home/$USER/.cache/ffmes
	fi
}
CheckFiles() {                  # Promp a message to user with number of video, audio, sub to edit, and command not found
	# Video
	if  [[ $TESTARGUMENT == *"Video"* ]]; then
		echo "  * Video to edit: $LSTVIDEO" | Truncate
	elif  [[ $TESTARGUMENT != *"Video"* ]] && [ "$NBV" -eq "1" ]; then
		echo "  * Video to edit: $LSTVIDEO" | Truncate
	elif [ "$NBV" -gt "1" ]; then                 # If no arg + 1> videos
		echo -e "  * Video to edit: $NBV files"
	fi

	# Audio
	if  [[ $TESTARGUMENT == *"Audio"* ]]; then
		echo "  * Audio to edit: $LSTAUDIO" | Truncate
	elif [[ $TESTARGUMENT != *"Audio"* ]] && [ "$NBA" -eq "1" ]; then
		echo "  * Audio to edit: $LSTAUDIO" | Truncate
	elif test -z "$ARGUMENT" && [ "$NBA" -gt "1" ]; then                 # If no arg + 1> videos
		echo -e "  * Audio to edit: $NBA files"
	fi

	# ISO
	if  [[ $TESTARGUMENT == *"ISO"* ]]; then
		echo "  * ISO to edit: $LSTISO" | Truncate
	elif [[ $TESTARGUMENT != *"ISO"* ]] && [ "$NBISO" -eq "1" ]; then
		echo "  * ISO to edit: $LSTISO" | Truncate
	fi

	# Subtitle
	if [ "$NBSUB" -eq "1" ]; then
		echo "  * Subtitle to edit: $LSTSUB" | Truncate
	elif [ "$NBSUB" -gt "1" ]; then
		echo "  * Subtitle to edit: $NBSUB"
	fi

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
MainMenu() {                    # Main menu
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
echo "  -----------------------------------------------------"
echo "  20 - CD rip                                         |"
echo "  21 - VGM rip to flac                                |-Audio"
echo "  22 - CUE Splitter to flac                           |"
echo "  23 - audio to wav (pcm)                             |"
echo "  24 - audio to flac                                  |"
echo "  25 - audio to mp3 (libmp3lame)                      |"
echo "  26 - audio to aac (libfdk_aac)                      |"
echo "  27 - audio to ogg (libvorbis)                       |"
echo "  28 - audio to opus (libopus)                        |"
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
Truncate() {
cut -c 1-"$TERM_WIDTH" | awk '{print $0"..."}'
}
Loading() {
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
StartLoading() {
	task=$1
	Ltask="${#task}"
	if [ "$Ltask" -gt "$TERM_WIDTH" ]; then
		task=$(echo "${task:0:$TERM_WIDTH}" | awk '{print $0"..."}')
	fi
	msg=$2
	Lmsg="${#msg}"
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
StopLoading() {
    # $1 : command exit status
	tput cnorm		# normal cursor
    Loading "stop" "${task}" "${msg}" $_sp_pid
    unset _sp_pid
}
ffmesUpdate() {
mkdir "$FFMES_PATH"/update-temp
cd "$FFMES_PATH"/update-temp
wget https://github.com/Jocker666z/ffmes/archive/master.zip
unzip master.zip && mv ffmes-master ffmes
rm master.zip
cp -R -- ffmes/* "$FFMES_PATH"/
cd "$FFMES_PATH"
rm -R update-temp
}
## VIDEO SECTION
FFmpeg_video_cmd() {
	START=$(date +%s)							# Start time counter

	for files in "${LSTVIDEO[@]}"; do

		if [ "${files##*.}" != "mkv" ]; then
			StartLoading "Test timestamp of: $files"
			TimestampTest=$(ffprobe -loglevel error -select_streams v:0 -show_entries packet=pts_time,flags -of csv=print_section=0 "$files" | awk -F',' '/K/ {print $1}' | tail -1)
			if [ "$TimestampTest" = "N/A" ]; then
				TimestampRegen="-fflags +genpts"
			fi
			StopLoading $?
		fi

		echo "FFmpeg processing: "${files%.*}"."$videoformat"."$extcont""
		(
		ffmpeg $FFMPEG_LOG_LVL $TimestampRegen -analyzeduration 1G -probesize 1G -y -i "$files" -threads 0 $stream $videoconf $soundconf -codec:s copy -max_muxing_queue_size 1024 -f $container "${files%.*}".$videoformat.$extcont
		) &
		if [[ $(jobs -r -p | wc -l) -gt $NVENC ]]; then
			wait -n
		fi
	done
	wait

	END=$(date +%s)								# End time counter
	
	# Check Target if valid (size test) and clean
	filesPass=()
	filesReject=()
	filesSourcePass=()
	for files in "${LSTVIDEO[@]}"; do
			if [[ $(stat --printf="%s" "${files%.*}".$videoformat.$extcont 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
				filesPass+=("${files%.*}".$videoformat.$extcont)
				filesSourcePass+=("$files")
			else																	# if file<30 KBytes rejected
				filesReject+=("${files%.*}".$videoformat.$extcont)
				rm "${files%.*}".$videoformat.$extcont 2>/dev/null
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
	echo " Created file(s) size: "$TSSIZE"MB, a difference of $PERC% from the source(s) ("$SSIZVIDEO"MB)."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo
}
Mkvmerge() {
	# Keep extention with wildcard for current audio and sub
	mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.+.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	NBA="${#LSTAUDIO[@]}"
	if [ "$NBA" -gt 0 ] ; then
		MERGE_LSTAUDIO=$(printf '*.%s ' "${LSTAUDIO[@]##*.}")
	fi
	if [ "$NBSUB" -gt 0 ] ; then
		MERGE_LSTSUB=$(printf '*.%s ' "${LSTSUB[@]##*.}")
	fi
	
	# Summary message
	clear
    echo
    cat "$FFMES_CACHE_STAT"
    echo
	echo "  You will merge the following files:"
	echo "   $LSTVIDEO"
	printf '   %s\n' "${LSTAUDIO[@]}"
	printf '   %s\n' "${LSTSUB[@]}"
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

	# If sub add, convert in UTF-8
	if [ "$NBSUB" -gt 0 ] ; then
		for files in "${LSTSUB[@]}"; do
			CHARSET_DETECT=$(uchardet "$files" 2> /dev/null)
			if [ "$CHARSET_DETECT" != "UTF-8" ]; then
				iconv -f $CHARSET_DETECT -t UTF-8 "$files" > utf-8-"$files"
				mkdir SUB_BACKUP 2> /dev/null
				mv "$files" SUB_BACKUP/"$files".back
				mv -f utf-8-"$files" "$files"
			fi
		done
	fi

	# Merge
	mkvmerge -o "${LSTVIDEO[0]%.*}".$videoformat.mkv "${LSTVIDEO[0]}" $MERGE_LSTAUDIO $MERGE_LSTSUB

	END=$(date +%s)                         # End time counter
	
	# Check Target if valid (size test)
	filesPass=()
	filesReject=()
	if [[ $(stat --printf="%s" "${LSTVIDEO%.*}".$videoformat.mkv 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
		filesPass+=("${LSTVIDEO%.*}".$videoformat.mkv)
	else																	# if file<30 KBytes rejected
		filesReject+=("${LSTVIDEO%.*}".$videoformat.mkv)
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
	echo " Created file(s) size: "$TSSIZE"MB."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo
}
VideoSourceInfo() {
	# Add all stats in temp.stat.info
	ffprobe -analyzeduration 1G -probesize 1G -i "$LSTVIDEO" 2> "$FFMES_CACHE"/temp.stat.info

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

	# Grep source size & add file name and size
	SourceSize=$(wc -c "$LSTVIDEO" | awk '{print $1;}' | awk '{ foo = $1 / 1024 / 1024 ; print foo }')
	sed -i '1 i\    '"$LSTVIDEO, size: $SourceSize MB"'' "$FFMES_CACHE_STAT"

	# Add title & complete formatting
	sed -i '1 i\ Source file stats:' "$FFMES_CACHE_STAT"
	sed -i '1 i\--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"
	sed -i -e '$a--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"

	# Clean temp file
	rm $FFMES_CACHE"/temp.stat.info" &>/dev/null

	# Grep if interlaced video and width/height of source (with mediainfo)
	INTERLACED=$(mediainfo --Inform="Video;%ScanType/String%" "$LSTVIDEO")
	SWIDTH=$(mediainfo --Inform="Video;%Width%" "$LSTVIDEO")
	SHEIGHT=$(mediainfo --Inform="Video;%Height%" "$LSTVIDEO")
}
CustomInfoChoice() {
	clear
    cat "$FFMES_CACHE_STAT"
	echo " Target configuration:"
	echo "  Video stream: $chvidstream"
	if [ "$ENCODV" = "YES" ]; then
		echo "   * Crop: $cropresult"
		echo "   * Rotation: $chrotation"
		echo "   * Resolution: $chwidth"
		echo "   * Deinterlace: $chdes"
		echo "   * Frame rate: $chfps"
		echo "   * Codec: $chvcodec $chpreset $chtune $chprofile"
		echo "   * Bitrate: $vkb"
	fi
	echo "  Audio stream: $chsoundstream"
	if [ "$ENCODA" = "YES" ]; then
		echo "   * Codec: $chacodec"
		echo "   * Bitrate: $akb"
		echo "   * Channels: $rpchannel"
	fi
	echo "  Container: $extcont"
	echo "--------------------------------------------------------------------------------------------------"
	echo
	}
CustomVideoEncod() {
    CustomInfoChoice
    echo " Encoding or copying the video stream:"           # Video stream choice, encoding or copy
    echo
    echo "  [e]   for encode"
    echo "  [↵]*  for copy"
    echo "  [q]   for exit"
    echo -n " -> "
    read -r qv
    echo
	if [ "$qv" = "q" ]; then
		Restart

	elif [ "$qv" = "e" ]; then							# Start edit video

		ENCODV="YES"

		# Crop
        CustomInfoChoice
        echo " Crop the video?"
		echo " Note: Auto detection is not 100% reliable, a visual check of the video will guarantee it."
        echo
        echo "  [y]   for yes in auto detection mode"
        echo "  [m]   for yes in manual mode (knowing what you are doing is required)"
        echo "  [↵]*  for no change"
        echo "  [q]   for exit"
        echo -n " -> "
        read -r yn
		case $yn in
			"y"|"Y")
				StartLoading "Crop auto detection in progress"
				cropresult=$(ffmpeg -i "$LSTVIDEO" -ss 00:03:30 -t 00:04:30 -vf cropdetect -f null - 2>&1 | awk '/crop/ { print $NF }' | tail -1 2> /dev/null)  # grep auto crop with ffmpeg
				StopLoading $?
				vfilter="-vf $cropresult"
				nbvfilter=$((nbvfilter+1))
			;;
			"m"|"M")
				echo
				echo " Enter desired crop: "
				echo
				echo "  [crop=688:448:18:56]  example"
				echo "  [c]                   for no change"
				echo "  [q]                   for exit"
				while :
				do
				echo -n " -> "
				read -r cropresult
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
		echo "  [0]   90° CounterCLockwise and Vertical Flip"
		echo "  [1]   90° Clockwise"
		echo "  [2]   90° CounterClockwise"
		echo "  [3]   90° Clockwise and Vertical Flip"
		echo "  [4]   180°"
        echo "  [↵]*  for no change"
        echo "  [q]   for exit"
        while :
		do
        echo -n " -> "
        read -r ynrotat
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

		# Resolution
        CustomInfoChoice
        echo " Resolution changed:"
        echo " Note: if crop is applied is not recommended to combine the two."
        echo
        echo "  [y]   for yes"
        echo "  [↵]*  for no change"
        echo "  [q]   for exit"
        echo -n " -> "
        read -r yn
        echo
        case $yn in
			"y"|"Y")
				echo " Enter only the width of the video"
				echo " Notes: * Width must be a integer"
				echo "        * Original ratio is respected"
				echo
				echo "  [1280]  example for 1280px width"
				echo "  [c]     for no change"
				echo "  [q]     for exit"
				while :
				do
				echo -n " -> "
				read -r WIDTH1
				WIDTH=$(echo "$WIDTH1" | cut -f1 -d",")		# remove comma and all after
				case $WIDTH in
					[100-5000]*)
						nbvfilter=$((nbvfilter+1))
						RATIO=$(echo "$SWIDTH/$WIDTH" | bc -l | awk 'sub("\\.*0+$","")')
						HEIGHT=$(echo $(echo "scale=1;$SHEIGHT/$RATIO" | bc -l | sed '/\./ s/\.\{0,1\}0\{1,\}$//'))		# display decimal only if not integer
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
						DHEIGHT=$(echo $(echo "scale=0;$SHEIGHT/$RATIO" | bc -l | sed '/\./ s/\.\{0,1\}0\{1,\}$//'))		# not decimal
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
			echo " Video seems interlaced, you want deinterlace:"
		else
			echo " Video seems not interlaced, you want force deinterlace:"
		fi
		echo " Note: the auto detection is not 100% reliable, a visual check of the video will guarantee it."
		echo
		echo "  [y]   for yes "
        echo "  [↵]*  for no change"
        echo "  [q]   for exit"
        echo -n " -> "
		read -r yn
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
        echo "  [y]   for yes "
        echo "  [↵]*  for no change"
        echo "  [q]   for exit"
        echo -n " -> "
        read -r yn
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
        echo "  [x264]      https://trac.ffmpeg.org/wiki/Encode/H.264"
        echo "  [x265][↵]*  https://trac.ffmpeg.org/wiki/Encode/H.265"
        echo "  [mpeg4]     https://trac.ffmpeg.org/wiki/Encode/MPEG-4"
        echo "  [q]         for exit"
        echo -n " -> "
        read -r yn
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
CustomAudioEncod() {
	CustomInfoChoice
	echo " Encoding or copying the audio stream(s):"                      # Audio stream choice, encoding or copy
	echo
    echo "  [e]      for encode stream(s)"
    echo "  [c][↵]*  for copy stream(s)"
    echo "  [r]      for no or remove stream(s)"
    echo "  [q]      for exit"
        echo -n " -> "
        read -r qa
        echo
    if [ "$qa" = "q" ]; then
            Restart
	elif [ "$qa" = "e" ]; then
	
		ENCODA="YES"
		CustomInfoChoice
		
		# Codec choice
        echo " Choice the audio codec to use:"
        echo " Notes: * Consider quality of source before choice codec"
        echo "        * Size: flac > ac3 > ogg >= aac > mp3 (also bitrate dependent)"
        echo "        * Quality: flac > ogg > aac > ac3 >= mp3 ( also bitrate dependent)"
        echo "        * Compatibility: mp3 > ac3 >= aac > ogg > flac"
        echo
        echo "                           |   Max    |"
        echo "                  Codec    | channels | Documentations"
		echo "  [opus][↵]* +   libopus   |   7.1>   | https://wiki.xiph.org/index.php?title=Opus_Recommended_Settings"
        echo "  [aac]      +  libfdk_aac |   7.1>   | https://trac.ffmpeg.org/wiki/Encode/AAC"
        echo "  [ogg]      +  libvorbis  |   7.1>   | https://trac.ffmpeg.org/wiki/TheoraVorbisEncodingGuide"
        echo "  [mp3]      +  libmp3lame |   2.0    | https://trac.ffmpeg.org/wiki/Encode/MP3"
        echo "  [ac3]      +     ac3     |   5.1    | https://trac.ffmpeg.org/wiki/Encode/HighQualityAudio"
        echo "  [flac]     +   libflac   |   7.1>   |"
        echo "  [q]        +     exit"
		echo -n " -> "
		read -r chacodec
		case $chacodec in
			"aac")
				codeca="libfdk_aac"
				chacodec="libfdk_aac"
				ConfAAC
				ConfChannels
			;;
			"opus")
				codeca="libopus"
				ConfOPUS
				ConfChannels
			;;
			"ogg")
				codeca="libvorbis"
				ConfOGG
				ConfChannels
			;;
			"ac3")
				codeca="ac3"
				ConfAC3
				ConfChannels
			;;
			"mp3")
				codeca="libmp3lame"
				ConfMP3
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

	elif [ "$qa" = "r" ]; then

        chsoundstream="No audio"                               # For no audio video or remove audio
        fileacodec="noaudio"
        soundconf=""

	else

        chsoundstream="Copy"                              # No audio change
        fileacodec="acopy"
        soundconf="-acodec copy"
	fi
	}
CustomVideoStream() {
    if [ "$nbstream" -gt 2 ] ; then            # if $nbstream > 2 = map question

        if [ "$reps" -le 1 ]; then             # display summary target if in profile 1 or 0
            CustomInfoChoice
        fi

        if [ "$reps" -gt 1 ]; then              # Display streams stats if no in profile 1 (already make by CustomInfoChoice)
            clear
            echo
            cat "$FFMES_CACHE_STAT"
            echo
        fi

    echo " Select video, audio(s) & subtitle(s) streams, or leave for keep unchanged:"
    echo " Note: * the order of the streams you specify will be the order of in final file"
    echo "       * remove data stream for not have any encoding issue"
    if test -z $probeaudio && [ "$qa" = "r" ]; then                                                    # Alert if remove audio selected
		echo
		echo -e "      [!] Be careful you have selected previously no audio stream, do not \e[1m\033[31mmap\033[0m them."
    fi
	echo
	echo "  [map 0 3 1] Example of input format for select stream"
	echo "  [enter]*    for no change"
    echo "  [q]         for exit"
		read -e -p " -> " rpstreamch
        if [ "$rpstreamch" = "q" ]; then
            Restart
		elif echo $rpstreamch | grep -q 'map' ; then

		    echo "$rpstreamch" | sed 's/.\{4\}//' > $FFMES_CACHE_MAP        # remove map in variable
            sed -i 's/ /\n/g' $FFMES_CACHE_MAP                              # make multiline
            sed -i 's/^/0:/' $FFMES_CACHE_MAP                               # add 0:
            sed -i 's/^/-map /' $FFMES_CACHE_MAP                            # add -map
            sed -i ':a;N;$!ba;s/\n/ /g' $FFMES_CACHE_MAP                    # all in one line

            if test -z "addsubtitle"; then                                  # for sub add
                sed -i '1s/$/ -map 1:s/' $FFMES_CACHE_MAP
            fi

            stream=$(cat $FFMES_CACHE_MAP)                                  # set map variable

        elif [ "$extcont" = mkv ]; then

            if test -z "addsubtitle"; then
                stream="-map 0 -map 1:s"                                         # for sub add
            else
                stream="-map 0"                                                  # if mkv keep all stream in certain stream
            fi

        else
            stream=""
        fi
	fi
	
	
	# Set file name if variable empty
    if test -z "$videoformat"; then
        videoformat=$filevcodec.$fileacodec
    fi
	}
CustomVideoContainer() {
	CustomInfoChoice

	echo " Choose container:"
	echo " Note: avi recommended only if you make a file readable by very old player"
	echo
	echo "  [mkv][↵]*"
	echo "  [mp4]"
	echo "  [avi]"
	echo -n " -> "
	read -r chcontainer
	case $chcontainer in
		"mkv")
			extcont="mkv"
			container="matroska"
		;;
		"mp4")
			extcont="mp4"
			container="mp4"
		;;
		"avi")
			extcont="avi"
			container="avi"
		;;
		"q"|"Q")
			Restart
		;;
		*)
			extcont="mkv"
			container="matroska"
		;;
	esac

	echo
	CustomInfoChoice

	}
Confmpeg4() {
	CustomInfoChoice

	echo " Choose a number OR enter the desired bitrate:"
	echo
	echo "  [1200k]  Example of input format for desired bitrate"
	echo
	echo "  [1]     Q∧ |    -qscale 1    |"
	echo "  [2]     U| |S   -qscale 5    |HD"
	echo "  [3]↵]*  A| |I   -qscale 10   |"
	echo "  [4]     L| |Z   -qscale 15   -"
	echo "  [5]     I| |E   -qscale 20   |"
	echo "  [6]     T| |    -qscale 15   |SD"
	echo "  [7]     Y| V    -qscale 30   |"
		echo -n " -> "
		read -r rpvkb
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
Confx264_5() {
	CustomInfoChoice
	echo " Choose the preset:"                   # Preset
	echo "	-----------------------------------------------> Slow Encoding"
	echo "	veryfast - faster - fast* -  medium - slow - slower - veryslow"
	echo "	--------------------------------> Better quality & compression"
		echo -n "-> "
		read -r reppreset
		if test -n "$reppreset"; then
			preset="-preset $reppreset"
			chpreset="$reppreset"
		else
			preset="-preset fast"
			chpreset="fast"
		fi

    CustomInfoChoice
    if [ "$chvcodec" = "x264" ]; then              # Tune
    echo "  Choose tune:"
    echo "  This settings influences the final rendering of the image, and speed of encoding."
    echo
    echo "      [cfilm][↵]*     for movie content, ffmes custom tuning (high quality)"
    echo "      [canimation]    for animation content, ffmes custom tuning (high quality)"
    echo
    echo "      [no]            for no tuning"
    echo "      [film]          for movie content; lower debloking"
    echo "      [animation]     for animation; more deblocking and reference frames"
    echo "      [grain]         for preserves the grain structure in old, grainy film material"
    echo "      [stillimage]    for slideshow-like content "
    echo "      [fastdecode]    for allows faster decoding (disabling certain filters)"
    echo "      [zerolatency]   for fast encoding and low-latency streaming "
        echo -n " -> "
        read -r reptune
        echo
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
    echo "  Choose tune:"
    echo "  This settings influences the final rendering of the image, and speed of encoding."
    echo "  Note, by default x265 always tunes for highest perceived visual."
    echo
    echo "      [default][↵]*   for movie content; default, intermediate tuning of the two following"
    echo "      [psnr]          for movie content; disables adaptive quant, psy-rd, and cutree"
    echo "      [ssim]          for movie content; enables adaptive quant auto-mode, disables psy-rd"
    echo "      [grain]         for preserves the grain structure in old, grainy film material"
    echo "      [fastdecode]    for allows faster decoding (disabling certain filters)"
    echo "      [zerolatency]   for fast encoding and low-latency streaming "
        echo -n " -> "
        read -r reptune
        echo
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

    CustomInfoChoice
    if [ "$chvcodec" = "x264" ]; then                  # Profile
    echo "  Choose the profile:"
    echo "  The choice of the profile affects the compatibility of the result,"
    echo "  be careful not to apply any more parameters to the source file (no positive effect)"
    echo
    echo "                                      | Example definition and frames per second by level"
    echo "           | lvl | Profile  | Max db  | Res.     >fps"
    echo "      [1]  | 3.0 | Baseline | 10 Mb/s | 720×480  >30  || 720×576  >25"
    echo "      [2]  | 3.1 | main     | 14 Mb/s | 1280×720 >30  || 720×576  >66"
    echo "      [3]  | 4.0 | Main     | 20 Mb/s | 1920×1080>30  || 2048×1024>30"
    echo "      [4]  | 4.0 | High     | 25 Mb/s | 1920×1080>30  || 2048×1024>30"
    echo "   [↵][5]* | 4.1 | High     | 63 Mb/s | 1920×1080>30  || 2048×1024>30"
    echo "      [6]  | 4.2 | High     | 63 Mb/s | 1920×1080>64  || 2048×1088>60"
    echo "      [7]  | 5.0 | High     | 169Mb/s | 1920×1080>72  || 2560×1920>30"
    echo "      [8]  | 5.1 | High     | 300Mb/s | 1920×1080>120 || 4096×2048>30"
    echo "      [9]  | 5.2 | High     | 300Mb/s | 1920×1080>172 || 4096×2160>60"
		echo -n "-> "
		read -r rep
		if [ "$rep" = "1" ]; then
			profile="-profile:v baseline -level 3.0"
			chprofile="Baseline 3.0"
		elif [ "$rep" = "2" ]; then
			profile="-profile:v baseline -level 3.1"
			chprofile="Baseline 3.1"
		elif [ "$rep" = "3" ]; then
			profile="-profile:v main -level 4.0"
			chprofile="Baseline 4.0"
		elif [ "$rep" = "4" ]; then
			profile="-profile:v high -level 4.0"
			chprofile="High 4.0"
		elif [ "$rep" = "5" ]; then
			profile="-profile:v high -level 4.1"
			chprofile="High 4.1"
		elif [ "$rep" = "6" ]; then
			profile="-profile:v high -level 4.2"
			chprofile="High 4.2"
		elif [ "$rep" = "7" ]; then
			profile="-profile:v high -level 5.0"
			chprofile="High 5.0"
		elif [ "$rep" = "8" ]; then
			profile="-profile:v high -level 5.1"
			chprofile="High 5.1"
		elif [ "$rep" = "9" ]; then
			profile="-profile:v high -level 5.2"
			chprofile="High 5.2"
		else
			profile="-profile:v high -level 4.1"
			chprofile="High 4.1"
		fi

	elif [ "$chvcodec" = "x265" ]; then
	echo "  Choose a profile or make your profile manually:"
    echo "  Notes: * For bit and chroma settings, if the source is below the parameters, FFmpeg will not replace them but will be at the same level."
    echo "          * The level (lvl) parameter must be chosen judiciously according to the bit rate of the source file and the result you expect."
    echo "          * The choice of the profile affects the player compatibility of the result."
    echo
    echo "  Manually options (expert):"
    echo "  8bit profiles: main, main-intra, main444-8, main444-intra"
    echo "  10bit profiles: main10, main10-intra, main422-10, main422-10-intra, main444-10, main444-10-intra"
    echo "  12bit profiles: main12, main12-intra, main422-12, main422-12-intra, main444-12, main444-12-intra"
    echo "  Level: 1, 2, 2.1, 3.1, 4, 4.1, 5, 5.1, 5.2, 6, 6.1, 6.2"
    echo "  High level: high-tier=1"
    echo "  No high level: no-high"
    echo "  Example of input format for manually profile [-profile:v main -x265-params level=3.1:no-high-tier]"
    echo
    echo "  ffmes predefined profiles:"
    echo "                                                | Max db | Max definition and frames per second by level"
    echo "           | lvl | Hight | Intra | Bit | Chroma | Mb/s   | Res.     >fps"
    echo "      [1]  | 3.1 | 0     | 0     | 8   | 4:2:0  | 10     | 1280×720 >30"
    echo "      [2]  | 4.1 | 0     | 0     | 8   | 4:2:0  | 20     | 2048×1080>60"
    echo "   [↵][3]* | 4.1 | 1     | 0     | 8   | 4:2:0  | 50     | 2048×1080>60"
    echo "      [4]  | 4.1 | 1     | 0     | 12  | 4:4:4  | 150    | 2048×1080>60"
    echo "      [5]  | 4.1 | 1     | 1     | 12  | 4:4:4  | 1800   | 2048×1080>60"
    echo "      [6]  | 5.2 | 1     | 0     | 8   | 4:2:0  | 240    | 4096×2160>120"
    echo "      [7]  | 5.2 | 1     | 0     | 12  | 4:4:4  | 720    | 4096×2160>120"
    echo "      [8]  | 5.2 | 1     | 1     | 12  | 4:4:4  | 8640   | 4096×2160>120"
    echo "      [9]  | 6.2 | 1     | 0     | 12  | 4:4:4  | 2400   | 8192×4320>120"
    echo "     [10]  | 6.2 | 1     | 1     | 12  | 4:4:4  | 28800  | 8192×4320>120"
	echo -n "-> "
		read -r rep
		if echo "$rep" | grep -q 'profil'; then
				profile="$rep"
				chprofile="$rep"
		elif [ "$rep" = "1" ]; then
				profile="-profile:v main -x265-params "$X265_LOG_LVL"level=3.1"
				chprofile="3.1 - 8 bit - 4:2:0"
		elif [ "$rep" = "2" ]; then
				profile="-profile:v main -x265-params "$X265_LOG_LVL"level=4.1"
				chprofile="4.1 - 8 bit - 4:2:0"
		elif [ "$rep" = "3" ]; then
				profile="-profile:v main -x265-params "$X265_LOG_LVL"level=4.1:high-tier=1"
				chprofile="4.1 - 8 bit - 4:2:0"
		elif [ "$rep" = "4" ]; then
				profile="-profile:v main444-12 -x265-params "$X265_LOG_LVL"level=4.1:high-tier=1"
				chprofile="4.1 - 12 bit - 4:4:4"
		elif [ "$rep" = "5" ]; then
				profile="-profile:v main444-12-intra -x265-params "$X265_LOG_LVL"level=4.1:high-tier=1"
				chprofile="4.1 - 12 bit - 4:4:4 - intra"
		elif [ "$rep" = "6" ]; then
				profile="-profile:v main -x265-params "$X265_LOG_LVL"level=5.2:high-tier=1"
				chprofile="5.2 - 8 bit - 4:2:0"
		elif [ "$rep" = "7" ]; then
				profile="-profile:v main444-12 -x265-params "$X265_LOG_LVL"level=5.2:high-tier=1"
				chprofile="5.2 - 12 bit - 4:4:4"
		elif [ "$rep" = "8" ]; then
				profile="-profile:v main444-12-intra -x265-params "$X265_LOG_LVL"level=5.2:high-tier=1"
				chprofile="5.2 - 12 bit - 4:4:4 - intra"
		elif [ "$rep" = "9" ]; then
				profile="-profile:v main444-12 -x265-params "$X265_LOG_LVL"level=6.2:high-tier=1"
				chprofile="6.2 - 12 bit - 4:4:4"
		elif [ "$rep" = "10" ]; then
				profile="-profile:v main444-12-intra -x265-params "$X265_LOG_LVL"level=6.2:high-tier=1"
				chprofile="6.2 - 12 bit - 4:4:4 - intra"
		else
				profile="-profile:v main -x265-params "$X265_LOG_LVL"level=4.1:high-tier=1"
				chprofile="High 4.1 - 8 bit - 4:2:0"
		fi
	fi

	CustomInfoChoice
    echo "  Choose a number OR enter the desired bitrate:"       # Bitrate
    echo "  This settings influences size and quality, crf is a better choise in 90% of cases."
    echo
    echo "      [1200k]     Example of input format for cbr desired bitrate"
    echo "      [-crf 21]   Example of input format for crf desired level"
    echo
    echo "      [1]   ∧ |    for -crf 0"
    echo "      [2]  Q| |    for -crf 5"
    echo "      [3]  U| |S   for -crf 10"
    echo "      [4]  A| |I   for -crf 15"
    echo "      [5]  L| |Z   for -crf 20"
    echo "   [↵][6]* I| |E   for -crf 23"
    echo "      [7]  T| |    for -crf 25"
    echo "      [8]  Y| |    for -crf 30"
    echo "      [9]   | ∨    for -crf 35"
        echo -n " -> "
		read -r rpvkb
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
			vkb="-crf 23"
		elif [ "$rpvkb" = "7" ]; then
			vkb="-crf 25"
		elif [ "$rpvkb" = "8" ]; then
			vkb="-crf 30"
		elif [ "$rpvkb" = "9" ]; then
			vkb="-crf 35"
		else
			vkb="-crf 23"
		fi
	}
ExtractPartVideo() {
	clear
    echo
    cat "$FFMES_CACHE_STAT"

    echo "  Select Video, audio(s) &/or subtitle(s) streams, one or severale"
    echo "  Notes: extracted files saved in source directory."
	echo
	echo "  [all]    ->  Input format for extract all streams"
	echo "  [0 2 5]  ->  Example of input format for select streams"
	echo "  [q]      ->  for quit"
	echo
	echo -n "-> "
	while :
	do
	read -e -r rpstreamch
	case $rpstreamch in
	
		"all")
			mapfile -t VINDEX < <(ffprobe -analyzeduration 1G -probesize 1G -v error -show_entries stream=index -print_format csv=p=0 "${LSTVIDEO[0]}")
			mapfile -t VCODECNAME < <(ffprobe -analyzeduration 1G -probesize 1G -v error -show_entries stream=codec_name -print_format csv=p=0 "${LSTVIDEO[0]}")
			break
		;;
		[0-9]*)
			VINDEX=($rpstreamch)
			# Keep codec used
			mapfile -t VCODECNAME1 < <(ffprobe -analyzeduration 1G -probesize 1G -v error -show_entries stream=codec_name -print_format csv=p=0 "${LSTVIDEO[0]}")
			VCODECNAME=()
			for i in "${VINDEX[@]}"; do
				VCODECNAME+=(${VCODECNAME1[$i]})
			done
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
	
	# Start time counter
	START=$(date +%s)							# Start time counter
	for files in "${LSTVIDEO[0]}"; do

		filesPass=()
		filesReject=()
		for i in ${!VINDEX[*]}; do

			case "${VCODECNAME[i]}" in
				h264) FILE_EXT=mkv ;;
				hevc) FILE_EXT=mkv ;;
				av1) FILE_EXT=mkv ;;
				mpeg4) FILE_EXT=mkv ;;

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

				subrip) FILE_EXT=srt ;;
				ass) FILE_EXT=ass ;;
				hdmv_pgs_subtitle) FILE_EXT=sup ;;
				esac

				StartLoading "" "${files%.*}-Stream-${VINDEX[i]}.$FILE_EXT"
				ffmpeg  -y -i "$files" -c copy -map 0:"${VINDEX[i]}" "${files%.*}"-Stream-"${VINDEX[i]}"."$FILE_EXT" &>/dev/null
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
	if [ "$NBVO" -eq 0 ] ; then
		TSSIZE="0"
	else
		TSSIZE=$(du -chsm "${filesPass[@]}" | tail -n1 | awk '{print $1;}')				# Target(s) size
	fi
	
	# End: encoding messages
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
	echo " Created file(s) size: "$TSSIZE"MB."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo

        }
ConcatenateVideo() {
	echo "  Concatenate video files?"
	echo "  Note: * Before you start, make sure that the files all have the same height/width, codecs and bitrates."
	echo
	echo "  Files to concatenate:"
	printf '   %s\n' "${LSTVIDEO[@]}"
	echo
	echo "  [↵]*        for continue"
	echo "  [q]         for quit"
	echo -n " -> "
	read -r concatrep
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
		if [ $(stat --printf="%s" Concatenate-Output."${LSTVIDEO[0]##*.}") -gt 30720 ]; then		# if file>30 KBytes accepted
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
		echo " Created file(s) size: "$TSSIZE"MB, a difference of $PERC% from the source(s) ("$SSIZVIDEO"MB)."
		echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
		echo " -----------------------------------------------------"
		echo
		
		
		# Next encoding question
		read -p "You want encoding concatenating video? [y/N]:" qarm
			case $qarm in
				"Y"|"y")
					LSTVIDEO=("Concatenate-Output."${LSTVIDEO[0]##*.}"")
				;;
				*)
					Restart
				;;
			esac
	fi
}
CutVideo() {
	clear
    echo
    cat "$FFMES_CACHE_STAT"

    echo "  Enter duration of cut:"
    echo "  Note, time is contruct as well:"
    echo "    * for hours :   HOURS:MM:SS.MICROSECONDS"
    echo "    * for minutes : MM:SS.MICROSECONDS"
    echo "    * for seconds : SS.MICROSECONDS"
    echo "    * microseconds is optional, you can not indicate them"
    echo
	echo "  Examples of input:"
	echo "    [s.20]       -> remove video after 20 second"
	echo "    [e.01:11:20] -> remove video before 1 hour 11 minutes 20 second"
    echo
    echo "  [s.time]      for remove end"
    echo "  [e.time]      for remove start"
    echo "  [t.time.time] for remove start and end"
    echo "  [q]           for quit  "
    echo
       	while :
		do
		echo -n " -> "
		read -r qcut0
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
	echo "FFmpeg processing: "${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}""
	ffmpeg $FFMPEG_LOG_LVL -i "${LSTVIDEO[0]}" -ss "$CutStart" -to "$CutEnd" -c copy -map_metadata 0 "${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}"

	# End time counter
	END=$(date +%s)

	# Check Target if valid (size test)
	filesPass=()
	filesReject=()
	if [ $(stat --printf="%s" "${LSTVIDEO[0]%.*}".cut."${LSTVIDEO[0]##*.}") -gt 30720 ]; then		# if file>30 KBytes accepted
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
	echo " Created file(s) size: "$TSSIZE"MB, a difference of $PERC% from the source(s) ("$SSIZVIDEO"MB)."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo
}
MultipleVideoExtention() {
	if [ "$NBVEXT" -gt "1" ]; then
		echo
		echo "  Different source video file extensions have been found, would you like to select one or more?"
		echo "  Note: * It is recommended not to batch process different sources, in order to control the result as well as possible."
		echo
		echo "  Extensions found: $(echo "${LSTVIDEOEXT[@]}")"
		echo
		echo "  [avi]       Example of input format for select one extension"
		echo "  [mkv|mp4]   Example of input format for multiple selection"
		echo "  [↵]*        for no selection"
		echo "  [q]         for quit"
		echo -n " -> "
		read -r VIDEO_EXT_AVAILABLE
		if [ "$VIDEO_EXT_AVAILABLE" = "q" ]; then
			Restart
		elif test -n "$VIDEO_EXT_AVAILABLE"; then
			mapfile -t LSTVIDEO < <(find . -maxdepth 1 -type f -regextype posix-egrep -regex '.+.('$VIDEO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
			NBV="${#LSTVIDEO[@]}"
		fi
	fi
}
RemoveVideoSource() {
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
DVDRip() {
    clear
    echo
    echo "  DVD rip"
    echo "  notes: * for DVD, launch ffmes in directory without ISO & VOB"
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
		VOBSET="1"
	elif [ "$NBISO" -eq "1" ]; then
		DVD="${LSTISO[0]}"
		ISOSET="1"
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
	AspectRatio=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null | grep "aspect ratio of the main feature" | tail -1 | awk '{print $NF}')
	DVDtitle=$(env -u LANGUAGE LC_ALL=C dvdbackup -i "$DVD" -I 2>/dev/null | grep "DVD with title" | tail -1 | awk '{print $NF}' | sed "s/\"//g")
	mapfile -t DVD_TITLES < <(lsdvd "$DVD" | grep Title | awk '{print $2}' |  grep -o '[[:digit:]]*') # Use for extract all title
	
	# Question
	if [ "$NBVOB" -ge "1" ]; then
		echo "  "$NBVOB" file(s) are been detected, choice one or more title to rip:"
	else
		echo "  "$DVDtitle" DVD video have been detected, choice one or more title to rip:"
	fi
	echo
	cat "$LSDVD_CACHE"
	echo
	echo "  [02 13]   Example of input format for select title 02 and 13"
	echo "  [all]     for rip all titles"
	echo "  [q]       for exit"
	echo -n " -> "
	while :
	do
	IFS=" " read -r -a qtitle
	echo
	case $qtitle in

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
		read -p "  What is the name of the DVD?: " qdvd
		case $qdvd in
			*)
				DVDtitle="$qdvd"
			;;
			"")
				echo
				echo "$MESS_INVALID_ANSWER"
				echo
			;;
		esac
	fi

	for title in "${qtitle[@]}"; do
		RipFileName=("$DVDtitle"-"$title")

		# Extract vob
		StartLoading "Extract VOB - title $title"
		dvdbackup -p -t "$title" -i "$DVD" -n "$RipFileName" 2> /dev/null
		StopLoading $?

		# Concatenate, remove data stream, fix DAR, and change container
		mapfile -t LSTVOB < <(find ./"$RipFileName" -maxdepth 3 -type f -regextype posix-egrep -iregex '.+.('$VOB_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')

		# Concatenate
		StartLoading "Concatenate VOB - title $title"
		cat -- "${LSTVOB[@]}" > "$RipFileName".VOB 2> /dev/null
		StopLoading $?

		# Remove data stream, fix DAR, and change container
		StartLoading "Make clean mkv - title $title"
		# If no audio or sub -> not map
		NoAudio=$(mediainfo "$RipFileName".VOB | grep Audio)
		NoSub=$(ffprobe -analyzeduration 1G -probesize 1G -v error -show_entries stream=codec_name -print_format csv=p=0 "$RipFileName".VOB | grep dvd_subtitle)
		if test -n "$NoAudio"; then
			MapAudio="-map 0:a"
		fi
		if test -n "$NoSub"; then
			MapSub="-map 0:s"
		fi
		ffmpeg $FFMPEG_LOG_LVL -y -fflags +genpts -analyzeduration 1G -probesize 1G -i "$RipFileName".VOB -map 0:v $MapAudio $MapSub -c copy -aspect $AspectRatio "$RipFileName".mkv 2>/dev/null
		StopLoading $?

		# Check Target if valid (size test) and clean
		if [[ $(stat --printf="%s" "$RipFileName".mkv 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
			# Clean
			rm -f "$RipFileName".VOB 2> /dev/null
			rm -R -f "$RipFileName" 2> /dev/null
		else																			# if file<30 KBytes rejected
			echo "X FFmpeg pass of DVD Rip fail"
			rm -R -f "$RipFileName" 2> /dev/null
		fi
	done

	# map
	unset TESTARGUMENT
	SetGlobalVariables

	# encoding question if more 1 vob
	if [ "$NBV" -gt "1" ]; then
	echo
	echo " $NBV files are been detected:"
	printf '  %s\n' "${LSTVIDEO[@]}"
	echo
	read -p "  Would you like encode it in batch (not recommended)? [y/N]:" q
	case $q in
		"Y"|"y")

		;;
		*)
			Restart
		;;
	esac
	fi
    }
## AUDIO SECTION
AudioSourceInfo() {
	# Add all stats in temp.stat.info
	ffprobe -analyzeduration 100M -probesize 100M -i "$LSTAUDIO" 2> "$FFMES_CACHE"/temp.stat.info

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

	# Add title & complete formatting
	sed -i '1 i\ Source file stats:' "$FFMES_CACHE_STAT"                             # Add title
	sed -i '1 i\--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"
	sed -i -e '$a--------------------------------------------------------------------------------------------------' "$FFMES_CACHE_STAT"

	# Clean temp file
	rm $FFMES_CACHE"/temp.stat.info" &>/dev/null
}
SplitCUE() {
	if [ "$NBCUE" -eq "0" ]; then                                         # If 0 cue
		echo "  No CUE file in the working directory"
		echo
	elif [ "$NBCUE" -gt "1" ]; then                                       # If more than 1 cue
		echo "  More than one CUE file in working directory"
		echo
	elif [ "$NBCUE" -eq "1" ] & [ "$NBA" -eq "1" ]; then                  # One cue and audio file supported
		
		# Start time counter
		START=$(date +%s)
		
		CHARSET_DETECT=$(uchardet "$LSTCUE" 2> /dev/null)
		if [ "$CHARSET_DETECT" != "UTF-8" ]; then
			iconv -f $CHARSET_DETECT -t UTF-8 "$LSTCUE" > utf-8.cue
			mkdir BACK 2> /dev/null
			mv "$LSTCUE" BACK/"$LSTCUE".back
			mv -f utf-8.cue "$LSTCUE"
		fi

		shntool split "$LSTAUDIO" -t "%n - %t" -f "$LSTCUE" -o flac

		# Clean
		rm 00*.flac 2> /dev/null
		cuetag "$LSTCUE" *.flac 2> /dev/null
		if [ ! -d BACK/ ]; then
			mkdir BACK 2> /dev/null
		fi
		mv "$LSTAUDIO" BACK/ 2> /dev/null
		mv "$LSTCUE" BACK/ 2> /dev/null

		# End time counter
		END=$(date +%s)
		
		# Check Target
		mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.+.('flac')$' 2>/dev/null | sort | sed 's/^..//')

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
		echo " -----------------------------------------------------"
		echo " $NBAO file(s) have been processed."
		if test -n "$LSTAUDIO"; then
			echo " File(s) created:"
			printf '  %s\n' "${LSTAUDIO[@]}"
		fi
		echo " -----------------------------------------------------"
		echo " Created file(s) size: "$TSSIZE"MB."
		echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
		echo " -----------------------------------------------------"
	echo
	
	fi
}
CDRip() {
if command -v abcde &>/dev/null; then						# If abcde installed
	clear
	echo
    echo "  ffmes audio CD rip"
    echo "  Notes: * abcde is used for rip audio CD"
    echo "         * temporary & finals files extracted in \""$ABCDE_EXTRACT"\" directory"
    echo
    echo "  Choose desired codec:"
    echo "  --------------------------------------------------------------"
    echo "                    |  quality |"
    echo "  [1][↵]* +  | flac | lossless |"
    echo "  [2]     +  |  ogg |    500kb |"
    echo "  [3]     +  | opus |    256kb |"
    echo "  [4]     +  |  mp3 |    320kb |"
    echo "  [q]     +  | quit"
    echo
		while :
		do
		echo -n " -> "
		read -r rpripcd
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

	abcde -o "$cdripcodec" -a default,getalbumart -N -f -d "$DVD_DEVICE" -c "$ABCDE_CONF"

else
	echo
	echo "	abcde is not present, install it for audio CD Rip"
	echo
fi
}
FFmpeg_audio_cmd() {
	# Try to extract cover if no cover in directory
	if [ ! -f cover.jpg ] && [ ! -f cover.png ] && [ ! -f cover.jpeg ]; then
		for file in "${LSTAUDIO[@]}"; do
			DIR=$(echo $(cd "$(dirname "$file")"; pwd)/)
			ffmpeg -n -i "$file" "$DIR"cover.jpg 2> /dev/null
			break # exit loop after first file
		done
	fi

	# Start time counter
	START=$(date +%s)

	# Encoding
	for files in "${LSTAUDIO[@]}"; do
		# Test Volume and set normalization variable
		if [ "$PeakNorm" = "1" ]; then
			TESTDB=$(ffmpeg -i "$files" -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
			if [ -n "$afilter" ] && [[ "$codeca" = "libopus" || "$AudioCodecType" = "Opus" ]]; then			# Opus trick for peak normalization
				if [[ $TESTDB = *"-"* ]]; then
					GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
					afilter="-af aformat=channel_layouts='7.1|5.1|stereo',volume=$GREPVOLUME -mapping_family 1"
				fi
			else
				if [[ $TESTDB = *"-"* ]]; then
					GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
					afilter="-af volume=$GREPVOLUME"
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
		# Opus auto adapted bitrate
		if [ "$AdaptedBitrate" = "1" ]; then
			TestBitrate=$(mediainfo --Output="General;%OverallBitRate%" "$files")
			if [ "$TestBitrate" -ge 1 -a "$TestBitrate" -le 96000 ]; then
				akb="-b:a 64K"
			elif [ "$TestBitrate" -ge 96001 -a "$TestBitrate" -le 128000 ]; then
				akb="-b:a 96K"
			elif [ "$TestBitrate" -ge 129000 -a "$TestBitrate" -le 160000 ]; then
				akb="-b:a 128K"
			elif [ "$TestBitrate" -ge 161000 -a "$TestBitrate" -le 192000 ]; then
				akb="-b:a 160K"
			elif [ "$TestBitrate" -ge 193000 -a "$TestBitrate" -le 256000 ]; then
				akb="-b:a 192K"
			elif [ "$TestBitrate" -ge 257000 -a "$TestBitrate" -le 280000 ]; then
				akb="-b:a 220K"
			elif [ "$TestBitrate" -ge 281000 -a "$TestBitrate" -le 320000 ]; then
				akb="-b:a 256K"
			elif [ "$TestBitrate" -ge 321000 -a "$TestBitrate" -le 400000 ]; then
				akb="-b:a 280K"
			elif [ "$TestBitrate" -ge 400001 ]; then
				akb="-b:a 320K"
			fi
			soundconf="$acodec $akb"
		fi
		( 
		StartLoading "" "$files"
		ffmpeg -y -i "$files" $afilter $stream $confchan $soundconf "${files%.*}".$extcont &>/dev/null
		StopLoading $?
		) &
		if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
			wait -n
		fi
	done
	wait

	# End time counter
	END=$(date +%s)

	# Check Target if valid (size test) and clean
	filesPass=()
	filesReject=()
	filesSourcePass=()
	for files in "${LSTAUDIO[@]}"; do
			if [[ $(stat --printf="%s" "${files%.*}".$extcont 2>/dev/null) -gt 30720 ]]; then		# if file>30 KBytes accepted
				filesPass+=("${files%.*}".$extcont)
				filesSourcePass+=("$files")
			else																	# if file<30 KBytes rejected
				filesReject+=("${files%.*}".$extcont)
				rm "${files%.*}".$extcont 2>/dev/null
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
	echo " $NBAO/$NBA file(s) have been processed."
	echo " Created file(s) size: "$TSSIZE"MB, a difference of $PERC% from the source(s) ("$SSIZAUDIO"MB)."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo
}
ConfChannels() {
if [ "$reps" -le 1 ]; then          # if profile 0 or 1 display
    CustomInfoChoice
fi
    echo
    echo " Choose desired audio channels configuration:"
    echo " note: * applied to the all audio stream"
    echo " -----------------------------------------------------------------"
    echo
    echo "  [1]    -channel_layout 1.0"
    echo "  [2]    -channel_layout 2.0"
    echo "  [3]    -channel_layout 5.1"
    echo "  [↵]*   for no change"
    echo "  [q]    for exit"
        echo -n " -> "
        read -r rpchan
            if [ "$rpchan" = "q" ]; then
                Restart
            elif [ "$rpchan" = "1" ]; then
                confchan="-channel_layout mono"
                rpchannel="1.0 (Mono)"
			elif [ "$rpchan" = "2" ]; then
				confchan="-channel_layout stereo"
				rpchannel="2.0 (Stereo)"
			elif [ "$rpchan" = "3" ]; then
				confchan="-channel_layout 5.1"
				rpchannel="5.1"
			elif [ -z "$rpchan" ] && [[ "$codeca" = "libopus" || "$AudioCodecType" = "Opus" ]]; then
				afilter="-af aformat=channel_layouts='7.1|5.1|stereo' -mapping_family 1"
				rpchannel="No change"
			else
				rpchannel="No change"
			fi
	}
ConfPeakNorm() {
	echo
	read -p " Want to apply a 0db peak normalization? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			PeakNorm="1"
		;;
		*)
			return
		;;
	esac
	}
ConfTestFalseStereo() {
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
ConfPCM() {
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of $NBA files to edit."
    cat "$FFMES_CACHE_STAT"
    echo
fi
    echo "  Choose PCM desired configuration:"
    echo
    echo "      \        integer represent. & | sample |   bit    /"
    echo "       \_____  coding               |   rate | depth  _/"
    echo "  [1]     +  | unsigned             |  44kHz |     8 |"
    echo "  [2]     +  | signed               |  44kHz |     8 |"
    echo "  [3]     +  | signed little-endian |  44kHz |    16 |"
    echo "  [4]     +  | signed little-endian |  44kHz |    24 |"
    echo "  [5]     +  | signed little-endian |  44kHz |    32 |"
    echo "  [6]     +  | unsigned             |  48kHz |     8 |"
    echo "  [7]     +  | signed               |  48kHz |     8 |"
    echo "  [8]     +  | signed little-endian |  48kHz |    16 |"
    echo "  [9]     +  | signed little-endian |  48kHz |    24 |"
    echo "  [10]    +  | signed little-endian |  48kHz |    32 |"
    echo "  [11]    +  | unsigned             |   auto |     8 |"
    echo "  [12]    +  | signed               |   auto |     8 |"
    echo "  [13]*   +  | signed little-endian |   auto |    16 |"
    echo "  [14]    +  | signed little-endian |   auto |    24 |"
    echo "  [15]    +  | signed little-endian |   auto |    32 |"
	echo
		echo -n " -> "
		read -r rpakb
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
ConfFLAC() {
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of $NBA files to edit."
    cat "$FFMES_CACHE_STAT"
    echo
fi
    echo "  Choose Flac desired configuration:"
    echo "  Notes: * libFLAC uses a compression level parameter that varies from 0 (fastest) to 8 (slowest)."
	echo "           The compressed files are always perfect, lossless representations of the original data."
	echo "           Although the compression process involves a tradeoff between speed and size, "
	echo "           the decoding process is always quite fast and not dependent on the level of compression."
	echo "         * If you choose and audio bit depth superior of source file, the encoding will fail."
	echo "         * Option tagued [no], leave this option as source file."
    echo
    echo "  --------------------------------------------------------------"
    echo "  For complete control of configuration:"
    echo "  [-compression_level 12 -cutoff 24000 -sample_fmt s16 -ar 48000] -> Example of input format"
    echo
    echo "  --------------------------------------------------------------"
    echo "  Otherwise choose a number:"
    echo
    echo "      \ compression | sample |   bit    /"
    echo "       \_____ level |   rate | depth  _/"
    echo "  [1]     +  |  12  |  44kHz |    16 |"
    echo "  [2]     +  |  12  |  44kHz |    24 |"
    echo "  [3]     +  |  12  |  44kHz |  auto |"
    echo "  [4]     +  |  12  |  48kHz |    16 |"
    echo "  [5]     +  |  12  |  48kHz |    24 |"
    echo "  [6]     +  |  12  |  48kHz |  auto |"
    echo "  [7][↵]* +  |  12  |   auto |    16 |"
    echo "  [8]     +  |  12  |   auto |    24 |"
	echo
		echo -n " -> "
		read -r rpakb
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
ConfOPUS() {
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of $NBA files to edit."
    cat "$FFMES_CACHE_STAT"
    echo
fi
    echo "  Choose Opus (libopus) desired configuration:"
    echo "  Note: All options have cutoff at 48kHz"
    echo
    echo "  --------------------------------------------------------------"
    echo "  vbr compression target:"

    echo "       \_____  kb/s | Descriptions             /"
    echo "  [1]     +  |  64k | comparable to mp3 96k   |"
    echo "  [2]     +  |  96k | comparable to mp3 120k  |"
    echo "  [3]     +  | 128k | comparable to mp3 160k  |"
    echo "  [4]     +  | 160k | comparable to mp3 192k  |"
    echo "  [5]     +  | 192k | comparable to mp3 280k  |"
    echo "  [6][↵]* +  | 220k | comparable to mp3 320k  |"
    echo "  [7]     +  | 256k | 5.1 audio source        |"
    echo "  [8]     +  | 320k | 7.1 audio source        |"
    echo "  [9]     +  | 450k | 7.1 audio source        |"
    echo " [10]     +  | 510k | highest bitrate of opus |"
    if [[ "$AudioCodecType" = "Opus" ]]; then
    echo "  --------------------------------------------|"
	echo "  [X]     +  | Accurate auto adapted bitrate  |"
	echo "              \_____  Target |     Source     |"
	echo "                    |   64k  |   1kb ->  96kb |"
	echo "                    |   96k  |  97kb -> 128kb |"
	echo "                    |  128k  | 129kb -> 160kb |"
	echo "                    |  160k  | 161kb -> 192kb |"
	echo "                    |  192k  | 193kb -> 256kb |"
	echo "                    |  220k  | 257kb -> 280kb |"
	echo "                    |  256k  | 281kb -> 320kb |"
	echo "                    |  280k  | 321kb -> 400kb |"
	echo "                     \ 320k  | 400kb -> ∞    /"
	fi
	echo
		echo -n " -> "
		read -r rpakb
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
ConfOGG() {
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of $NBA files to edit."
    cat "$FFMES_CACHE_STAT"
    echo
fi
    echo "  Choose Ogg (libvorbis) desired configuration:"
    echo "  Notes: * The reference is the variable bitrate (vbr), it allows to allocate more information to"
    echo "           compressdifficult passages and to save space on less demanding passages."
    echo "         * A constant bitrate (cbr) is valid for streaming in order to maintain bitrate regularity."
    echo "         * The cutoff parameter is the cutoff frequency after which the encoding is not performed,"
    echo "           this makes it possible to avoid losing bitrate on too high frequencies."
    echo
    echo "  --------------------------------------------------------------"
    echo "  For crb:"
    echo "  [192k] -> Example of input format for desired bitrate"
    echo "  --------------------------------------------------------------"
    echo "  For vbr:                |  cut  |"
    echo "                   | kb/s |  off  | examples of use"
    echo "  [1]     +  -q 2  |  96k | 14kHz |"
    echo "  [2]     +  -q 3  | 112k | 15kHz |"
    echo "  [3]     +  -q 4  | 128k | 15kHz |"
    echo "  [4]     +  -q 5  | 160k | 16kHz |"
    echo "  [5]     +  -q 6  | 192k | 17kHz |"
    echo "  [6]     +  -q 7  | 224k | 18kHz |"
    echo "  [7]     +  -q 8  | 256k | 19kHz |"
    echo "  [8]     +  -q 9  | 320k | 20kHz |"
    echo "  [9][↵]* +  -q 10 | 500k | 22kHz | lossless source in 44.11kHz and more"
    echo "  [10]    +  -q 10 | 500k |  N/A  | lossless vgm source"
	echo
		echo -n " -> "
		read -r rpakb
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
ConfAAC() {
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of $NBA files to edit."
    cat "$FFMES_CACHE_STAT"
    echo
fi
    echo "  Choose AAC (libfdk_aac) desired configuration:"
    echo
    echo " Description:"
    echo "  * With specific bitrate (cbr), the value is divided between all channels"
    echo "  * With variable bitrate (vbr) each channels has an assigned a bitrate limit according to its "
    echo "    type, mono or stereo"
    echo
    echo " Advice : make your choice in taking into account the number of channels chosen, and especially"
    echo "          the quality of the source audio file. Miracles are done in the church."
    echo
    echo "  --------------------------------------------------------------"
    echo "  For crb:"
    echo "  [192k] -> Example of input format for desired bitrate"
    echo "  --------------------------------------------------------------"
    echo "  For vbr:                          ||  examples high limit kbps"
    echo "                    |kbps by channel||    few channel layout"
    echo "                    | mono | stereo ||  2.0 |  2.1 |  4.1 |  5.1"
    echo "  [1]     +  -vbr 1 |  32k |    20k ||  40k |  72k | 112k | 144k"
    echo "  [2]     +  -vbr 2 |  40k |    32k ||  64k | 120k | 184k | 224k"
    echo "  [3]     +  -vbr 3 |  56k |    48k ||  96k | 152k | 248k | 304k"
    echo "  [4][↵]* +  -vbr 4 |  72k |    64k || 128k | 200k | 328k | 400k"
    echo "  [5]     +  -vbr 5 | 112k |    96k || 192k | 304k | 496k | 608k"
        echo -n " -> "
		read -r rpakb
		if echo $rpakb | grep -q 'k' ; then
			akb="-b:a $rpakb"
		elif [ "$rpakb" = "1" ]; then
			akb="-vbr 1"
		elif [ "$rpakb" = "2" ]; then
			akb="-vbr 2"
		elif [ "$rpakb" = "3" ]; then
			akb="-vbr 3"
		elif [ "$rpakb" = "4" ]; then
			akb="-vbr 4"
		elif [ "$rpakb" = "5" ]; then
			akb="-vbr 5"
		else
			akb="-vbr 4"
		fi
	}
ConfMP3() {
if [ "$reps" -eq 1 ]; then
    CustomInfoChoice
else
    clear
    echo
    echo " Under, first on the list of $NBA files to edit."
    cat "$FFMES_CACHE_STAT"
    echo
fi
    echo "  Choose MP3 (libmp3lame) desired configuration:"
    echo
    echo "  [192k] -> Example of input format for desired bitrate"
    echo "  --------------------------------------------------------------"
	echo
	echo "  [1]     +  -q:a 4 ≈ 140-185kb/s"
	echo "  [2]     +  -q:a 3 ≈ 150-195kb/s"
	echo "  [3]     +  -q:a 2 ≈ 170-210kb/s"
	echo "  [4]     +  -q:a 1 ≈ 190-250kb/s"
	echo "  [5]     +  -q:a 0 ≈ 220-260kb/s"
	echo "  [6][↵]* +  320kb/s"
	echo
		echo -n " -> "
		read -r rpakb
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
ConfAC3() {
    echo
    echo "  Choose AC3 desired configuration:"
    echo
    echo "  [192k] -> Example of input format for desired bitrate"
    echo "  --------------------------------------------------------------"
	echo
	echo "  [1]     +  140kb/s"
	echo "  [2]     +  240kb/s"
	echo "  [3]     +  340kb/s"
	echo "  [4]     +  440kb/s"
	echo "  [5]     +  540kb/s"
	echo "  [6][↵]* +  640kb/s"
	echo
		echo -n " -> "
		read -r rpakb
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
RemoveAudioSource() {
	if [ "$NBAO" -gt 0 ] ; then
		read -p " Remove source audio? [y/N]:" qarm
		case $qarm in
			"Y"|"y")
				for f in "${filesSourcePass[@]}"; do
					rm -f "$f"
				done
			;;
			*)
				Restart
			;;
		esac
	fi
}
MultipleAudioExtention() {
	if [ "$NBAEXT" -gt "1" ]; then
		echo
		echo "  Different source audio file extensions have been found, would you like to select one or more?"
		echo "  Notes: * It is recommended not to batch process different sources, in order to control the result as well as possible."
		echo "         * If target have same extention of source file, it will not processed."
		echo
		echo "  Extensions found: $(echo "${LSTAUDIOEXT[@]}")"
		echo
		echo "  [m4a]       Example of input format for select one extension"
		echo "  [m4a|mp3]   Example of input format for multiple selection"
		echo "  [↵]*        for no selection"
		echo "  [q]         for quit"
		echo -n " -> "
		read -r AUDIO_EXT_AVAILABLE
		if [ "$AUDIO_EXT_AVAILABLE" = "q" ]; then
			Restart
		elif test -n "$AUDIO_EXT_AVAILABLE"; then
			StartLoading "Search the files processed"
			mapfile -t LSTAUDIO < <(find . -maxdepth 5 -type f -regextype posix-egrep -regex '.+.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
			NBA="${#LSTAUDIO[@]}"
			StopLoading $?
		fi
	fi
}
AudioSpectrum() {
    clear
    echo
    cat "$FFMES_CACHE_STAT"
    
    echo "  Choose size of spectrum:"
    echo
    echo "              width | height | description "
    echo "  [1]      +  800   |    450 | 2.0 thumb"
    echo "  [2]      +  1280  |    720 | 2.0 readable / 5.1 thumb"
    echo "  [3][↵]*  +  1920  |   1080 | 2.0 detail   / 5.1 readable"
    echo "  [4]      +  3840  |   2160 | 5.1 detail (unstable for tracks exceeding 1h)"
    echo "  [5]      +  7680  |   4320 | Shoryuken (unstable for tracks exceeding 1h)"
    echo "  [q]      +  exit"
        echo -n " -> "
        read -r qspek
        echo
    if [ "$qspek" = "q" ]; then
        restart
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
	echo " Created file(s) size: "$TSSIZE"MB."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo
}
ConcatenateAudio() {
	echo
	echo "  Concatenate audio files?"
	echo "  Note: * Before you start, make sure that the files all have the same codec and bitrate."
	echo
	echo "  Files to concatenate:"
	printf '   %s\n' "${LSTAUDIO[@]}"
	echo
	echo "  [↵]*        for continue"
	echo "  [q]         for quit"
	echo -n " -> "
	read -r concatrep
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
		echo " Created file(s) size: "$TSSIZE"MB, a difference of $PERC% from the source(s) ("$SSIZAUDIO"MB)."
		echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
		echo " -----------------------------------------------------"
		echo

	fi
}
CutAudio() {
	clear
    echo
    cat "$FFMES_CACHE_STAT"

    echo "  Enter duration of cut:"
    echo "  Note, time is contruct as well:"
    echo "    * for hours :   HOURS:MM:SS.MICROSECONDS"
    echo "    * for minutes : MM:SS.MICROSECONDS"
    echo "    * for seconds : SS.MICROSECONDS"
    echo "    * microseconds is optional, you can not indicate them"
    echo
	echo "  Examples of input:"
	echo "    [s.20]       -> remove audio after 20 second"
	echo "    [e.01:11:20] -> remove audio before 1 hour 11 minutes 20 second"
    echo
    echo "  [s.time]      for remove end"
    echo "  [e.time]      for remove start"
    echo "  [t.time.time] for remove start and end"
    echo "  [q]           for quit  "
    echo
       	while :
		do
		echo -n " -> "
		read -r qcut0
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
	if [ $(stat --printf="%s" "${LSTAUDIO[0]%.*}".cut."${LSTAUDIO[0]##*.}") -gt 30720 ]; then		# if file>30 KBytes accepted
		filesPass+=("${LSTAUDIO[0]%.*}".cut."${LSTAUDIO[0]##*.}")
	else																	# if file<30 KBytes rejected
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
	echo " Created file(s) size: "$TSSIZE"MB, a difference of $PERC% from the source(s) ("$SSIZAUDIO"MB)."
	echo " End of processing: $(date +%D\ at\ %Hh%Mm), duration: $((DIFFS/3600))h$((DIFFS%3600/60))m$((DIFFS%60))s."
	echo " -----------------------------------------------------"
	echo
}
## AUDIO TAG SECTION
AudioTagEditor() {
	StartLoading "Grab current tags" ""

	# Limit to current directory
	mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -iregex '.+.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
	NBA="${#LSTAUDIO[@]}"

	# Populate array with tag
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
	
	# Display Tag in table
	clear
	echo
	echo "Inplace file tags:"
	printf '%.0s-' {1..133}; echo
	paste <(printf "%-40.40s\n" "Files") <(printf "%s\n" "|") <(printf "%-5.5s\n" "Track") <(printf "%s\n" "|") <(printf "%-20.20s\n" "Title") <(printf "%s\n" "|") <(printf "%-17.17s\n" "Artist") <(printf "%s\n" "|") <(printf "%-20.20s\n" "Album") <(printf "%s\n" "|") <(printf "%-5.5s\n" "date") | column -s $'\t' -tn
	printf '%.0s-' {1..133}; echo
	paste <(printf "%-40.40s\n" "${LSTAUDIO[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_TRACK[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_TITLE[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-17.17s\n" "${TAG_ARTIST[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_ALBUM[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_DATE[@]}") | column -s $'\t' -tn 2>/dev/null
	# Degrading mode display for asian character
	DisplayTest=$(paste <(printf "%-40.40s\n" "${LSTAUDIO[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_TRACK[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_TITLE[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-17.17s\n" "${TAG_ARTIST[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_ALBUM[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_DATE[@]}") | column -s $'\t' -tn 2>/dev/null)
	if [[ -z "$DisplayTest" ]]; then
		paste <(printf "%-40.40s\n" "${LSTAUDIO[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_TRACK[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_TITLE[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-17.17s\n" "${TAG_ARTIST[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-20.20s\n" "${TAG_ALBUM[@]}") <(printf "%s\n" "${PrtSep[@]}") <(printf "%-5.5s\n" "${TAG_DATE[@]}")
	fi
	printf '%.0s-' {1..133}; echo
	
	echo
	echo "  Select tag option:"
	echo "  Notes: it is not at all recommended to threat more than one album at a time."
	echo
	echo "                                            | Descriptions"
	echo '  [rename]   ->  Rename files               | rename in "Track - Title" (add track number if not present)'
	echo "  [track]    ->  Change or add tag track    | alphabetic sorting, to use if no file has this tag"
	echo "  [album x]  ->  Change or add tag album    | ex. of input [album Conan the Barbarian]"
	echo "  [artist x] ->  Change or add tag artist   | ex. of input [artist Basil Poledouris]"
	echo "  [date x]   ->  Change or add tag date     | ex. of input [date 1982]"
	echo "  [ftitle]   ->  Change title by filename   |"
	echo "  [utitle]   ->  Change title by [untitled] |"
	echo "  [stitle x] ->  Remove N in begin of title | ex. of input [stitle 3] -> remove 3 first characters in all titles (Limited to 9)"
	echo "  [r]        ->  restart tag edition"
	echo "  [q]        ->  for quit"
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
					if [ "${LSTAUDIO[$i]##*.}" != "opus" ]; then
						ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TRACK="$TAG_TRACK_COUNT" tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null && mv tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" "${LSTAUDIO[$i]}" &>/dev/null
					else
						opustags "${LSTAUDIO[$i]}" --add TRACK="$TAG_TRACK_COUNT" --delete TRACK -o temp-"${LSTAUDIO[$i]}" &>/dev/null
						rm "${LSTAUDIO[$i]}" &>/dev/null
						mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
					fi
				fi
				if [[ "${#TAG_TRACK[$i]}" -eq "1" ]] ; then				# if integer in one digit
					TAG_TRACK[$i]="0${TAG_TRACK[$i]}"
					if [ "${LSTAUDIO[$i]##*.}" != "opus" ]; then
						ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TRACK="${TAG_TRACK[$i]}" tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null && mv tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" "${LSTAUDIO[$i]}" &>/dev/null
					else
						opustags "${LSTAUDIO[$i]}" --add TRACK="$TAG_TRACK_COUNT" --delete TRACK -o temp-"${LSTAUDIO[$i]}" &>/dev/null
						rm "${LSTAUDIO[$i]}" &>/dev/null
						mv temp-"${LSTAUDIO[$i]}" "${LSTAUDIO[$i]}" &>/dev/null
					fi
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
				mv "${LSTAUDIO[$i]}" "${TAG_TRACK[$i]} - $ParsedTitle"."${LSTAUDIO[$i]##*.}" &>/dev/null
				StopLoading $?
			done
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
				if [ "${LSTAUDIO[$i]##*.}" != "opus" ]; then
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TRACK="$TAG_TRACK_COUNT" tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null && mv tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" "${LSTAUDIO[$i]}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add TRACK="$TAG_TRACK_COUNT" --delete TRACK -o temp-"${LSTAUDIO[$i]}" &>/dev/null
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
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata ALBUM="$ParsedAlbum" tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null && mv tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" "${LSTAUDIO[$i]}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add ALBUM="$ParsedAlbum" --delete ALBUM -o temp-"${LSTAUDIO[$i]}" &>/dev/null
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
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata ARTIST="$ParsedArtist" tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null && mv tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" "${LSTAUDIO[$i]}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add ARTIST="$ParsedArtist" --delete ARTIST -o temp-"${LSTAUDIO[$i]}" &>/dev/null
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
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata DATE="$ParsedDate" tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null && mv tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" "${LSTAUDIO[$i]}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add DATE="$ParsedDate" --delete DATE -o temp-"${LSTAUDIO[$i]}" &>/dev/null
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
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TITLE="$ParsedTitle" tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null && mv tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" "${LSTAUDIO[$i]}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add TITLE="$ParsedTitle" --delete TITLE -o temp-"${LSTAUDIO[$i]}" &>/dev/null
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
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TITLE="[untitled]" tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null && mv tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" "${LSTAUDIO[$i]}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add TITLE="[untitled]" --delete TITLE -o temp-"${LSTAUDIO[$i]}" &>/dev/null
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
					ffmpeg $FFMPEG_LOG_LVL -i "${LSTAUDIO[$i]}" -c:v copy -c:a copy -metadata TITLE="$ParsedTitle" tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" &>/dev/null && mv tem."${LSTAUDIO[$i]%.*}"."${LSTAUDIO[$i]##*.}" "${LSTAUDIO[$i]}" &>/dev/null
				else
					opustags "${LSTAUDIO[$i]}" --add TITLE="$ParsedTitle" --delete TITLE -o temp-"${LSTAUDIO[$i]}" &>/dev/null
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
FFmpeg_vgm_cmd() { 
		# Test Volume, set normalization variable, silence remove at start & end
		TESTDB=$(ffmpeg -i "${files%.*}".wav -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
		if [[ $TESTDB = *"-"* ]]; then
			GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
		#	afilter="-af volume=$GREPVOLUME,silenceremove=window=0:detection=peak:start_periods=1:stop_periods=1"
		#else
		#	afilter="-af silenceremove=window=0:detection=peak:start_periods=1:stop_periods=1"
		fi

		# Channel test mono or stereo
		TESTLEFT=$(ffmpeg -i "${files%.*}".wav -map_channel 0.0.0 -f md5 - 2>/dev/null)
		TESTRIGHT=$(ffmpeg -i "${files%.*}".wav -map_channel 0.0.1 -f md5 - 2>/dev/null)
		if [ "$TESTLEFT" = "$TESTRIGHT" ]; then
			confchan="-channel_layout mono"
		else
			confchan=""
		fi

		# Encoding flac
		StartLoading "" "Encoding: ${files%.*}.flac"
		ffmpeg -y -i "${files%.*}".wav $afilter $confchan -acodec flac -compression_level 12 -sample_fmt s16 $SamplingRate -metadata TRACK="$TAG_TRACK" -metadata title="$TAG_SONG" -metadata album="$TAG_ALBUM" -metadata artist="$TAG_ARTIST" -metadata date="$TAG_DATE" "${files%.*}".flac  &>/dev/null
		StopLoading $?
	}
VGMRip() {
	echo
	echo " VGM Rip"
	echo

	# VGM ISO
	if [ "$NBCUE" -eq "0" ]; then                                         # If 0 cue
		echo "  No CUE file in the working directory"
		echo
	elif [ "$NBCUE" -gt "1" ]; then                                       # If more than 1 cue
		echo "  More than one CUE file in working directory"
		echo
	elif [ "$NBCUE" -eq "1" ] & [ "$NBVGMISO" -gt "1" ]; then              # If more than 1 bin = merge
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

	if [ "$NBCUE" -eq "1" ] & [ "$NBVGMISO" -eq "1" ]; then                # If 1 cue and bin file
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
		rm Track-01.iso			# Remove data track
		# Encoding Flac
		AUDIO_EXT_AVAILABLE="wav"
		mapfile -t LSTAUDIO < <(find . -maxdepth 1 -type f -regextype posix-egrep -regex '.+.('$AUDIO_EXT_AVAILABLE')$' 2>/dev/null | sort | sed 's/^..//')
		for files in "${LSTAUDIO[@]}"; do
			# Track tag (counter)
			TAG_TRACK=$(($COUNTER+1))
			COUNTER=$TAG_TRACK
			(
			FFmpeg_vgm_cmd
			) &
			if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
				wait -n
			fi
		done
		wait
	fi


	# VGM Files
	for files in "${LSTVGM[@]}"; do

		# Track tag (counter)
		TAG_TRACK=$(($COUNTER+1))
		COUNTER=$TAG_TRACK

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
								#afilter="-af volume=$GREPVOLUME,silenceremove=window=0:detection=peak:start_periods=1:stop_periods=1"
								afilter="-af volume=$GREPVOLUME"
							else
								#afilter="-af silenceremove=window=0:detection=peak:start_periods=1:stop_periods=1"
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
						# Test Volume, remove silence and set normalization variable
						TESTDB=$(ffmpeg -i "$SUBSONG".wav -af "volumedetect" -vn -sn -dn -f null /dev/null 2>&1 | grep "max_volume" | awk '{print $5;}')
						if [[ $TESTDB = *"-"* ]]; then
							GREPVOLUME=$(echo "$TESTDB" | cut -c2-)dB
							afilter="-af volume=$GREPVOLUME,silenceremove=window=0:detection=peak:start_periods=1:stop_periods=1"
						else
							afilter="-af silenceremove=window=0:detection=peak:start_periods=1:stop_periods=1"
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

				*VGM|*vgm|*VGZ|*vgz)		# Various machines - vgm2wav decode
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
					vgm2wav "$files" "${files%.*}".wav
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
					fi
				;;

				*tak|*TAK)		# Various machines - ffmpeg decode
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
					# Rename VGM
					mv "${files%.*}".tak "${files%.*}".wav &>/dev/null							# Rename trick
					mv "${files%.*}".TAK "${files%.*}".wav &>/dev/null							# Rename trick
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
					fi
				;;

				*dsf|*DSF)					# Sega Dreamcast - zxtune123 decode
					# Extract Tag
					tail -10 "$files" > "$VGM_TAG"													# Tag record
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
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
					fi
				;;

				*minissf|*MINISSF|*ssf|*SSF)					# Sega Saturn - zxtune123 decode
					# Extract Tag
					tail -15 "$files" > "$VGM_TAG"													# Tag record
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
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
					fi
				;;

				*psf|*PSF|*minipsf|*MINIPSF)					# Sony Playstation - zxtune123 decode
					# Extract Tag
					tail -15 "$files" > "$VGM_TAG"													# Tag record
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
					TAG_SONG=$(cat "$VGM_TAG" | grep -i -a title | sed 's/^.*=//')
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
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
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
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
					fi
				;;

				*ast|*AST|*at3|*AT3|*dat|*DAT|*mus|*MUS|*voc|*VOC)					# Various Machine
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
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
					fi
				;;

				*psf2|*PSF2|*minipsf2|*MINIPSF2)					# Sony Playstation 2
					# Extract Tag
					tail -15 "$files" > "$VGM_TAG"													# Tag record
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
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
					fi
				;;

				*ads|*ADS|*adp|*ADP|*ss2|*SS2|*adx|*ADX|*bfstm|*BFSTM|*bfwav|*BFWAV|*dsp|*DSP|*eam|*EAM|*hps|*HPS|*int|*INT|*rak|*RAK|*raw|*RAW|*spsd|*SPSD|*thp|*THP|*vag|*VAG|*vpk|*VPK|*xwav|*Xwav)					# Various Machines
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
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
					fi
				;;

				*spc|*SPC)					# Nintendo SNES
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
					if test -n "$SPC_VSPCPLAY"; then
						sox -t "$PULSE_MONITOR" -r 48000 -b 16 -t wav "${files%.*}".wav &
						vspcplay --ignore_tag_time --default_time "$TAG_TDURATION" --novideo --status_line "$files"
						killall -9 sox
						ffmpeg $FFMPEG_LOG_LVL -y -i "${files%.*}".wav -t $TAG_TDURATION -af "afade=t=out:st=$TAG_DURATION:d=$TAG_SFADING" -acodec pcm_s16le -f wav temp-"${files%.*}".wav
						rm "${files%.*}".wav
						mv temp-"${files%.*}".wav "${files%.*}".wav
					else
						ffmpeg $FFMPEG_LOG_LVL -y -i "$files" -t $TAG_TDURATION -af "afade=t=out:st=$TAG_DURATION:d=$TAG_SFADING" -acodec pcm_s16le -ar 32000 -f wav "${files%.*}".wav
					fi
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
					fi
				;;

				*miniusf|*MINIUSF)					# Nintendo N64 - zxtune123 decode
					# Extract Tag
					tail -15 "$files" > "$VGM_TAG"													# Tag record
					if test -z "$TAG_GAME"; then
						TAG_GAME=$(cat "$VGM_TAG" | grep -i -a game | sed 's/^.*=//' | head -1)
						if test -z "$TAG_GAME"; then
							echo "Please indicate the game title"
							echo -n " -> "
							read -e -p TAG_GAME
							echo
						fi
					fi
					if test -z "$TAG_DATE"; then
						TAG_DATE=$(cat "$VGM_TAG" | grep -i -a year | sed 's/^.*=//')
						if test -z "$TAG_DATE"; then
							echo "Please indicate the date of release"
							echo -n " -> "
							read -e -p TAG_DATE
							echo
						fi
					fi
					TAG_SONG=$(cat "$VGM_TAG" | grep -i -a title | sed 's/^.*=//')
					if test -z "$TAG_SONG"; then
						TAG_SONG="${files%.*}"
					fi
					TAG_ARTIST=$(cat "$VGM_TAG" | grep -i -a artist | sed 's/^.*=//')
					TAG_MACHINE="N64"																# Album part 2
					TAG_ALBUM="$TAG_GAME ($TAG_MACHINE)"											# Album
					# Extract VGM
					echo
					zxtune123 --wav filename=[Filename].wav "$files"
					mv "${files%.*}".miniusf.wav "${files%.*}".wav &>/dev/null						# Rename trick
					mv "${files%.*}".MINIUSF.wav "${files%.*}".wav &>/dev/null						# Rename trick
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
					fi
				;;

				*mod|*MOD)						# PC, Amiga
					# Extract Tag
					if test -z "$TAG_GAME"; then
						echo "Please indicate the game title"
						echo -n " -> "
						read -e -p TAG_GAME
						echo
					fi
					if test -z "$TAG_ARTIST"; then
						echo "Please indicate the artist"
						echo -n " -> "
						read -e -p TAG_ARTIST
						echo
					fi
					if test -z "$TAG_DATE"; then
						echo "Please indicate the date of release"
						echo -n " -> "
						read -e -p TAG_DATE
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
					# Encoding flac
					(
					FFmpeg_vgm_cmd
					) &
					if [[ $(jobs -r -p | wc -l) -gt $NPROC ]]; then
						wait -n
					fi
				;;

			esac

	done
	wait

	# Arrange
	VGM_DIR1="$TAG_GAME ($TAG_DATE) ($TAG_MACHINE)"
	VGM_DIR=$(echo $VGM_DIR1 | sed s#/#-#g)				# Replace eventualy "/" in string
	if [ ! -d "$VGM_DIR" ]; then
		mkdir "$VGM_DIR"
	fi
	mv -- *.flac "$VGM_DIR"
	
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


CheckCacheDirectory                     # Check if cache directory exist
StartLoading "Search the files processed"
SetGlobalVariables                      # Set global variable
StopLoading $?
trap TrapExit 2 3						# Set Ctrl+c clean trap
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
	if [[ "$NBV" -eq "1" ]]; then
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
        echo "$MESS_ONE_VIDEO_FILE_AUTH"
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

 20 ) # audio ->  CD Rip
	CDRip										   # quality questions & launch abcde
	;;

 21 ) # vgm ->  audio
	if [ "$KERNEL_TYPE" = "Linux x86_64" ] && [[ "$NBVGM" -gt "0" || "$NBVGMISO" -gt "0" ]] && [ "$NBGBS" -le "1" ]; then
	VGMRip
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
	if [ "$GBSCOUNT" -gt "1" ]; then
		echo
		echo "	-/!\- Only one gbs file at a time."
		echo
	fi
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
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # AUDIO ---------------------------------------------------------------------------------
    stream="-map 0:a"
    #acodec="-acodec pcm_s16le"
    soundconf="$acodec $akb"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="wav"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    FFmpeg_audio_cmd                               # encoding
    RemoveAudioSource
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
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # AUDIO ---------------------------------------------------------------------------------
    stream="-map 0:a"
    acodec="-acodec flac"
    soundconf="$acodec $akb"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="flac"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    FFmpeg_audio_cmd                               # encoding
    RemoveAudioSource
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
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # AUDIO ---------------------------------------------------------------------------------
    stream="-map 0:a"
    acodec="-acodec libmp3lame"
    confchan="-ac 2"
    soundconf="$acodec $akb"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="mp3"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    FFmpeg_audio_cmd                               # encoding
    RemoveAudioSource
    Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
    ;;

 26 ) # audio -> m4a
	if [ "$NBA" -gt "0" ]; then
	MultipleAudioExtention
	AudioSourceInfo
	ConfAAC
	ConfChannels
	ConfPeakNorm
	ConfTestFalseStereo
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # AUDIO ---------------------------------------------------------------------------------
    stream="-map 0:a"
    acodec="-acodec libfdk_aac -cutoff 20000"
    soundconf="$acodec $akb"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="m4a"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
	FFmpeg_audio_cmd                               # encoding
	RemoveAudioSource
	Clean                                          # clean temp files
	else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
	;;

 27 ) # audio -> ogg
	if [ "$NBA" -gt "0" ]; then
	MultipleAudioExtention
    AudioSourceInfo
    ConfOGG
    ConfChannels
    ConfPeakNorm
    ConfTestFalseStereo
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # AUDIO ---------------------------------------------------------------------------------
    stream="-map 0:a"
    acodec="-acodec libvorbis"
    soundconf="$acodec $akb"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="ogg"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    FFmpeg_audio_cmd                               # encoding
    RemoveAudioSource
    Clean                                          # clean temp files
    else
        echo
        echo "$MESS_ZERO_FILE_AUTH"
        echo
	fi
    ;;

 28 ) # audio -> opus
	if [ "$NBA" -gt "0" ]; then
	AudioCodecType="Opus"
	MultipleAudioExtention
    AudioSourceInfo
    ConfOPUS
    ConfChannels
    ConfPeakNorm
    ConfTestFalseStereo
    # CONF_START ////////////////////////////////////////////////////////////////////////////
    # AUDIO ---------------------------------------------------------------------------------
    stream="-map 0:a"
    acodec="-vn -acodec libopus"
    soundconf="$acodec $akb"
    # CONTAINER -----------------------------------------------------------------------------
    extcont="opus"
    #CONF_END ///////////////////////////////////////////////////////////////////////////////
    FFmpeg_audio_cmd                               # encoding
    RemoveAudioSource
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

 34 ) # Cut video
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
