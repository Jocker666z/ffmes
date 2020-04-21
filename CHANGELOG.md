# Changelog
v0.40:
* Video:
	* add - option 1, now HDR to SDR option, displayed only if source is in HDR, option set SDR by default
	* add - option 1, libx265, now option for make HDR encoding
	* fix - option 15, night normalization, now work with video without subtitle

v0.39:
* Video:
	* add - option 15, night normalization, now display audio stream number 0,1,2...
	* fix - option 15, night normalization, now work with all audio stream after 0

v0.38:
* Video:
	* add - extract dvd_subtitle with .idx/.sub extention (with mkvextract)
	* add - merge hdmv_pgs_subtitle & dvd_subtitle with .idx/.sub & .sup extention (with mkvmerge)
	* add - option 15, add night normalization audio stream, with night "acompressor=threshold=0.031623:attack=200:release=1000:detection=0,loudnorm"
	* fix - merge, multiple audio and sub with same extention, now no longer multiplies by the number of files
	* fix - dvdrip, mapfile use for extract all title, if error now not displayed
* Audio:
	* add - it is now possible to remove files with the same extension as the source
	* add - ExtractCover variable, 0=extract cover from files and remove from files, 1=keep cover in outpout files, empty=remove cover from files
	* add - AudioSourceInfo, now test db peak of first source audio file, and display at end of the audio stream line
* Various
	* add - setcd in command needed
	* modified - improve find command for populate array, much more accurate
	* modified - menu standardization

v0.37:
* Video:
	* fix - now map option work for mp4 (include subtitle)
	* remove - avi container output, now too old and hard to maintain
	* remove - mp3 as audio option for video, too old and limited
	* remove - ogg as audio option for video, appears to be a less effective duplicate than the opus
	* remove - libfdk_aac option, non-free, libopus more powerful, removing it makes ffmes compatible with distributions that don't deliver ffmpeg in a non-free version.
* Audio:
	* add - silence detect & remove, at start & end, only for wav and flac source
	* add - it is now possible to encode files with the same extension as the source
	* fix - audio normalization in batch
	* remove - libfdk_aac option 26, non-free, libopus more powerful, removing it makes ffmes compatible with distributions that don't deliver ffmpeg in a non-free version.
* VGM:
	* add - support of PS2 vgs, sng files
	* add - support of PS4 wem files
	* add - support of iso/cue files
	* add - support of amiga files, with uade, now instable, option hidden (211)
	* modified - remove silence refine to 0.01% of volume
	* fix - audio normalization in batch
	* update - vgmstream to r1050-2861-g126e3b41-11-ge7da81ef Mar 27 2020
	* update - vgm2wav to git Mar 15 2020
* Various:
	* add - Lib needed info
	* add - many comments
	* modified - readability improvement

v0.36:
* Video:
	* fix - x265 bit depth change, now work
* Audio tag:
	* add - disc number implementation
	* modified - max depth directory 1 to 2
* VGM:
	* add - support of 3DO aifc, str files
	* add - support of Nintendo GBA minigsf files
	* add - add sox command for remove silence
	* modified - split ffmpeg filter and encoding flac
	* fix - audio normalization
	* fix - undo to v0.34 build of sc68 and info68

v0.35:
* Video:
	* fix - resolution change now work (error "height not divisible by 2")
	* fix - concatenate now work with several stream
* VGM:
	* modified - refactor bin/cue treatment to prevent infinite loops
	* add - support of xbox xwav files
	* update - vgmstream to r1050-2812-g24e9d177 Feb 23 2020
	* update - replace info68 and sc68 by static build

v0.34:
* Video:
	* add - customizable variable (NVENC) at start of script, for set number of video encoding in same time, default 2 at time.
* VGM:
	* add - support of raw files
	* add - support of bin/cue image files, extract wav and encoding flac with bchunk
	* add - binmerge python3 script (https://github.com/putnam/binmerge)
	* add - vspcplay bin (https://github.com/raphnet/vspcplay)
	* add - experimental spc encoding with vspcplay, can only be activated by changing variables
	* update - zxtune123 to r4880 Jan 31 2020

v0.33a:
* Audio:
	* fix - multiple opus regression

v0.33:
* Audio:
	* add - PCM audio encoding
	* modified - rework FLAC options
* Audio tag:
	* fix - opustags now use temp files for prevent CIFS issue
* Video:
	* add - option 11 -  convert sub in UTF-8 before merge
* VGM:
	* add - support of dat files (adpcm_ea_r1)
	* add - support of eam files (Electronic Arts EA-XA 4-bit ADPCM v2)
	* add - support of at3 files (atrac3)
* Various:
	* add - implement truncate display (get terminal width and truncate at width - 10)
	* fix - in bash mapfile, add 2>/dev/null with find command, for remove error print

v0.32:
* Audio:
	* add - support of WavPack files (*.wv)
* Audio tag:
	* fix - now "cover" no displayed as title of track (ffprobe -select_streams a)
* VGM:
	* add - gbs files - set duration and fade out included in m3u
	* add - question for remove wav file generate during processing
	* fix - silenceremove regression with gbs files
	* update - gbsplay to 30 Nov 2019 version (fix issue: ioread from 0xff05 unimplemented)

v0.31:
* Audio tag:
	* add - opustags bin (https://github.com/fmang/opustags)
	* modified - now tags of opus files (*.opus) are made by opustags (ffmpeg not stable)
	* fix - various
* Various:
	* split README.md and CHANGELOG.md

v0.30:
* Audio:
	* add - support of mpg files (MPEG-PS, Version 1, Layer 2)
	* add - peak normalization for opus encoding
	* remove - cutoff option for FLAC encoding (useless)
	* add - option 30 as audio tag editor (display in degrading mode for asian character)
* VGM:
	* add - support of PS2 files in vpk
	* add - support of PC files in mus & voc (pcm_u8)
	* add - support of Dreamcast files in dsf, spsd
	* add - silence remove at start & end of each file
	* fix - add libunice68.so in lib, she's missing at info68
	* update - vgmstream-cli to r1050-2743-gc479bdb5 Jan 11 2020
	
v0.29:
* Video:
	* fix - now multiple video extention is case sensitive
* Audio:
	* fix - now multiple audio extention is case sensitive
	* fix - opus encoding audio in 5.1
	* add - opus accurate auto adapted bitrate from source (particularly useful for processing very large batches of files)
* VGM:
	* add - sc68 and info68 bin, for amiga/atari audio files (libao needed)
	* update - vgmstream-cli to r1050-2733-g000f0a72 Dec 31 2019
	* add - support of amiga/atari files in snd, sndh
	* add - support of Saturn files in minissf
	* add - support of PSX files in vag
	* add - support of PS2 files in vag, int
	* add - support of gamecube file in thp
	* fix - output name file for gbs encoding

v0.28a:
* Audio:
	* fix - add abcde conf file in directory and rename
* VGM:
	* add - support of GameCube files in adp, dsp, hps
	* fix - add lib of espctag

v0.27:
* VGM:
	* add - now encoding FLAC in parallel
	* add - support of various machine files in tak (in fact, it's WAV file), adx, ss2
	* fix - omission of the composer for vgz/vgm files
	* fix - now file in bfstm, bfwav, rak; classed in various machine

v0.26:
* Video:
	* add - experimental support of bink file (*.bik)
	* fix - many x264 options not displayed
* Audio:
	* fix - concatenate flac now with shntool (ffmpeg fail contruct duration with copy option)
* VGM:
	* add - support of Sony PS2 files psf2, minipsf2, ads
	* add - support of PC file mod
* Various:
	* add - now double test argument file, mediainfo and file command

v0.25:
* audio:
	* add - support of audio source file in *.MOD (https://en.wikipedia.org/wiki/MOD_(file_format))
* VGM:
	* fix - add call to bin/vgmstream-cli

v0.24a:
* Audio:
	* Another fix 0db peak normalization and false stereo detection in batch
	* Remove for 0db peak normalization in opus until we find something better

v0.24:
* Audio:
	* fix 0db peak normalization and false stereo detection in batch

v0.23:
* Video:
	* fix - x265 output info log in main level 3.1 and 4.1
	* fix - miss file target for time timestamp test
* VGM:
	* add - support of Nintendo Switch files bfstm, bfwav, rak

v0.22:
* VGM:
	* fix - spc $TAG_DATE fail
	* fix - xa remove duration trick causing flac encoding fail

v0.21:
* Various:
	* Rework almost all script from scratch for clean, improve stability, efficiency, and maintainability.
	* Clean main menu
	* add - source file remove question after process
* Video:
	* add - timestamp test for no mkv file
	* add - concatenate video option
* Audio:
	* add - recursive directory encoding for audio (maxdepth 5)
	* Add - VGM Rip to flac option
	* add - concatenate video option

v0.20:
* audio:
	* add - support of audio source file in *.aif (Audio Interchange File Format) (https://en.wikipedia.org/wiki/Audio_Interchange_File_Format)
* profiles:
	* add - profile 25 - opus audio encoding
	* move - CUE splitter in profile 26
	* modified - profile 1 
		* add, opus audio option
		* modified, opus now default audio encoding option
* functions:
	* DVDRip(): fix - select good output file after rip
	* ConfChannels(): remove channel selection 2.1 to 4.0, not useful
	* MultipleAudioExtention(): add - for profile 22 to 25, question when multiple audio extension present in directory
	* SplitCUE(): modified - now converts the CUE file not UTF-8 to UTF-8

v0.19:
* video:
    * add - support of video source file in *.webm (https://en.wikipedia.org/wiki/WebM)
* audio:
	* now it's possible to add audio track to video with profile 10
* subtitle: Rework all processing of subtitle
	* removed subtitle option in profile 1 (CustomSubtitle() function)
	* removed incrust profile 11
	* profile 10 now used for add subtitle with mkvmerge (faster than ffmpeg)
* functions:
	* Checkdependencies(): removed - now check at launch and promp a message if a dependencies lack via CheckFiles() function
* profiles: 
	* removed - profile 33 (rotation now make in profile 1)
* Various:
	* fix - now profile launch only if compatible file detected
	* fix - removed possibility to launch ffmes with audio files in argument

v0.18:
* functions:
	* CustomVideoEncod(): add - rotation option, 90°, 90° flip, -90°, -90° flip, 180° (profile 1)
	* CustomVideoEncod(): fix - fail when use multiple video filter in same command (profile 1)
	* PartVideoExtract(): add - batch mode if more than one video selected. Limit: one stream selection for extraction

v0.17:
* audio:
    * add - support of audio source file in *.wma (Windows Media Audio) (https://en.wikipedia.org/wiki/Windows_Media_Audio)
* functions:
	* SplitCUE(): improved cuetag operation
* Various:
	* add - $NPROC variable, count number of processor for gnu parallel command


v0.16:
* profiles: 
	* modified - profile 3 (x265) no more experimental
* functions:
	* Confx264_5(): add profile configuration for x265 codec, 10 profiles or make your profile manually


v0.15:
* functions:
	* FFmpeg_audio_cmd(): add loop for detect audio normalization of source and apply correction
	* CustomSubtitle(): fix add subtitle when encoding video
	* ConfPeakNorm(): add question for peak audio normalization to 0db

v0.14b:
* functions:
	* CustomVideoEncod():
		* fix resolution change, no more error on height with add ratio calculation

v0.14a:
* video:
	* add GPU video decoding possiblity. Reserved for informed users, edit variable ($GPU_DEC) at top of script (see https://trac.ffmpeg.org/wiki/HWAccelIntro), otherwise leave it empty for no change.
* functions:
	* FFmpeg_video_cmd():
		* add GPU decoding variable
		* fix compare size between source and encoded file, fail when no argument and one file in directory

v0.14:
* functions:
	* ReRunOnError(), remove function, no longer used
	* Checkdependencies(), remove check library
	* MainMenu(), add option 20 for audio CD Rip
	* CDRip(), add function using abcde for for audio CD Rip, also add configuration file of it
	* ConfFLAC(), add function with full options of configuration for encoding flac
	* AddVideoFile(), fix, remove empty space at the end of variable
	* AddAudioFile(), fix, remove empty space at the end of variable
	* CustomAudioEncod(), add flac codec for option 1 (full custom video)
	* FFmpeg_video_cmd(), add, now compare size between source and encoded file (don't work for batch encoding), report at end of process
	* SetGlobalVariables(), add, bc now needed for comparing size
	* FFmpeg_audio_cmd():
		* add, now compare size between source(s) and encoded file(s), report at end of process
		* fix, with add a trick for encoding file with same extention of source
	* Clean():
		* fix, regression of v0.13 that does not delete ffmpeg logs
		* add, consider if file exist in cache directory 3 days after creation, delete it
	* FFmpeg_extract_cmd(): simplification, no more useless check file
	* Cut(), fix last option, which never worked
	* PartVideoExtract(), now work properly
	* SourceInfo():
		* remove DAR alert
		* check if video is interlaced (https://gist.github.com/aktau/6660848)

v0.13:
* video:
    * add - support of video source file in *.vp9 (https://en.wikipedia.org/wiki/VP9)
* audio:
    * add - support of audio source file in *.opus (Opus Interactive Audio Codec) (https://en.wikipedia.org/wiki/Opus_(audio_format))
* functions:
    * CustomVideoEncod(), rework of x265 codec option, now fully work, add options for tuning and profile
    * FFmpeg_audio_cmd(), now use gnu parallel is possible (if installed) (encoding speed increase is around 2)
    * FFmpeg_spectrum_cmd(), now use gnu parallel is possible (if installed)
    * SourceInfo():
		* now clean temp.stat.info
		* replace ffmpeg command by ffprobe
    * Restart(), add tricky function for self restart script and keep argument
    * TrapExit (), add another tricky function for clean temp when press ctrl+c
* profiles:
	* Now Profile 3 is x265 encoding (experimental)
* various :
	* Now all temp files have unique id (date), fix an error when launch multiple instance of ffmes

v0.12a:
* video:
    * fix - x265 10bits to x264 8bits compression now rework with option "-pix_fmt yuv420p"

v0.12:
* documentation:
    * add test result for convert animation movie in h265 (HEVC) to x264
* video:
    * fix - add option "-max_muxing_queue_size 1024" in video command, for fix a recent muxing regression in ffmpeg
* audio:
    * add - support of audio source file in *.dsf (Direct Stream Digital) (https://en.wikipedia.org/wiki/Direct_Stream_Digital)
    * add - support of audio source file in *.xa (PS1 audio file)
    * add - support of audio source file in *.aud (Westwood Studios audio file)
    * add - support of audio source file in *.tta (https://en.wikipedia.org/wiki/TTA_(codec))
    * add - CUE splitter (option 25), various source to flac, then tag files with CUE (experimental).
* functions:
    * DVDRip():
        * modified - now only one ISO file in working directory is allowed
        * modified - now dvdbackup replace vobcopy (work better)
    * CustomVideoEncod(),
        * add - possibility to fix frame rate at 24 images per second
    * SourceInfo(): 
        * modified - resolution cheking (DAR), now considered as "mornalized": 160:87 (1.85:1)
        * fix - now DAR is checked with the first result in stream list, generally video (rework later with composed grep)

v0.11:
* various:
    * now ffmes is bash script
    * various and huge clean, normalization and simplification
    * add DVD_DEVICE variable, drive name of DVD/CD player, fix bug at start of copyvob
* functions:
    * modified, SourceInfo():
        * add resolution cheking (DAR), now considered as "mornalized": 16:49, 16:10, 4:3, 21:9, 14:10, 19:10, 3:2, 160:67 (2.40:1). If not in list, a message is shown to the user.
        * clean call to ffmpeg for stats, now one call
        * now in batch use, "ffmpeg -i" not launch on all file, just on first file of last type authorized. Effect = huge increased speed of function in directory with a lot of media.
        * add display source file size
    * Modified, DVDRip(), for DVDROM extract now target mount point (avoid error at start of extract by vobcopy)

v0.10a:
* funtions:
    * fix - CustomVideoEncod(), regression break encoding if no crop selected

v0.10:
* video:
    * add - checked video files *.vob *.mpeg
* audio:
    * add - checked audio files *.wav
* functions:
    * add - DVDRip(), for merge VOB, or extract vob from ISO or DVD.
    * add - FFmpeg_spectrum_cmd(), functions command generate spectrum of audio file
    * add - CustomAudioSpectrum(), function question for size of spectrum
    * add - ConfOGG(), function for choice bitrate of libvorbis ogg
    * add - FFmpeg_extract_cover_cmd(), try to extract cover if no cover in directory
    * add - Cut(), question for cut video or audio
    * add - FFmpeg_cut_cmd(), FFmpeg command for cut video or audio
    * modified - MainMenu(), add profile 0, DVD Rip
    * modified - CustomVideoEncod(), add crop video option
    * modified - CustomAudioEncod():
        * add libvorbis choice as audio codec
        * add option for no or remove audio stream(s)
    * modified - CustomContainerEncod() to CustomVideoContainer()
    * modified - CustomVideoStream(), now when you choosing stream it is necessary to indicate the video
    * modified - FFmpeg_video_cmd():
        * add "-codec:s copy" to the ffmpeg command line, necessary for raw dvd sub
        * add "analyzeduration 100M -probesize 100M", to the ffmpeg command line, often necessary for vob
        * modified, replace "-deinterlace" by "-vf yadif=1:-1:0,mcdeint=2:1:10", for better result
    * modified - FFmpeg_audio_cmd(), if cover in audio, no more kept
    * modified - SourceInfo(): 
        * add "analyzeduration 100M -probesize 100M", to the ffmpeg command line, often necessary for vob
        * add variablie for probe audio stream (use in custom audio)
        * add duration and bitrate info
    * modified - Confx264_5(), add custom tune in x264 option (identic to profiles 8 & 9)
    * fix - PartVideoExtract(), forget to assign .cache repertory implanted in 0.09
    * fix - FFmpeg_extract_cmd(), forget argument implanted in 0.09
    * fix - Confx264_5(), replace "-qp 0" by "-crf 0"
* profiles:
    * add - profile 0, for make dvdrip
    * add - profile 34, for generate png file of audio spectrum
    * modified - profile 24, now have quality and channels question
    * modified - profile 21 now 22, and 22 now 21
    * modified - profile 3, replace "-deinterlace" by "-vf yadif=1:-1:0,mcdeint=2:1:10", for better result

v0.09:
* various:
    * add - path variable for restart ffmes.sh from any directory
    * add - now it's possible to designate a working directory in argument. Ex: tape `ffmes /home/user/videos`, all media in /home/user/videos will be threat
    * add - help message is displayed if argument not valid
    * add - test argument, if the file in not a video -> exit
    * add - cache directory in .cache/ffmes, for place log and text files generated by ffmes
    * add - in first level of ffmes, now it's possible of call main menu via "m" or "main" or "menu"
* functions:
    * add - MainMenu(), main menu is now in this function
    * modified - AddVideoFile(), check no video for stop process
    * modified - AddAudioFile(), check no audio for stop process
    * modified - SourceInfo(), check no audio for stop process
    * modified - SetGlobalVariables(), remove uchardet fron $_needed_commands (no more use)
    * modified - FFmpeg_video_cmd(), display time of treatment duration and date of finish
    * modified - FFmpeg_audio_cmd(), display time of treatment duration and date of finish
    * fix - Clean(), add -maxdepth 1 at find
    * fix - SourceInfo(), some version of ffmpeg create bad count of streams (in parse)
    * fix - CustomVideoStream(), now if video stream is not on 0:0, encoding work
    * clean - SubError(), just rework the function
* profiles:
    * add - profile 9: for make animation video in hdlight, profile is very slow but with very good result
    * modified - profile 1:
        * x264, x265, default preset in now "slow" instead "normal"
        * x264, x265, add exact crf choice is now possible
    * modfied - profile 7:
        * x264, trellis = 0 -> 2, best result for minor speed impact
        * x264, subq 9 = add, for best result
    * modfied - profile 8:
        * x264, level, 5.0 -> 4.1, after test 5.0 break a large compatibility
        * x264, trellis = 0 -> 2, best result for minor speed impact
        * x264, me_method = full -> umh, equivalent result for better speed
        * x264, fast-pskip = add, at value "0", better render of color
        * x264, subq 9 = add, for best result
    * fix - all video profile with x264, color and brightness should now exact same as source. However, this patch force color "bt709" and so requires extensive testing, possible edge effects according to the source video
    * fix - all video profile, fix "-map 0" was not applied if no choice stream (if more than 2). Now works by deplacing configurations variables at start of profiles

v0.08:
* various:
    * add - launch ffmes with argument is now possible. See readme for use.
* functions:
    * modified - CheckFiles():
        * taken into account the argument variable variable
        * improvement the message to user at launch (in display alert and count of files video, audio and sub)
    * modified - SetGlobalVariables(), taken into account the argument variable variable
    * modified - FFmpeg_video_cmd(), taken into account the argument variable variable
    * modified - SourceInfo():
        * taken into account the argument variable variable
    * fix - CustomVideoStream(), forgetfulness that prevent copying streams in the profile 1
* profiles:
    * add - profile 23, libfdk_aac audio, m4a at cbr 250kb and cutoff at 20kHz
    * add - profile 24, libvorbis audio, ogg at vbr q9 (320kb) and cutoff at 22kHz
    * modified - profile 7, after tests change:
        * x264, crf, 24 -> 22
        * x264, rf, 6 -> 4 (reference frame)
    * modified - profile 8, after tests change:
        * x264, crf, 24 -> 22
        * x264, preset, slower -> veryslow
        * x264, level, 4.1 -> 5.0
    * modified - profile 5:
        * x264, preset, fast -> medium
        * x264, crf, 19 -> 20
        * mp3 -q:a 3 -> aac -vbr 4
    * modified - profile 4:
        * resolution is now fixed at normalized 720p (1280/720px)
        * mp3 -q:a 3 -> aac -vbr 4
        * avi -> mkv

v0.07:
* functions:
    * add - SetGlobalVariables(), set global variable used in many other functions
    * add - Checkdependencies(), dependencies test
    * add - CheckFiles(), in main menu, display an error if no subtitle file or more than one in working directory
    * add - SubError(), block profile use's subtitle if no subtitle file or more than one in working directory
    * add - In some question functions possibility to quit [q]
    * add - CustomInfoChoice(), add view of stat.info, for view source file during configuration of profile 1
    * add - CustomVideoEncod(), add call de SourceInfo() for generate stat.info and $nbstream variable at start of profile 1
    * modified - integrate all functions in ffmes.sh
    * modified - massive clean and simplification
    * modified - FFmpeg_video_cmd(), video encoding now make with one function instead of two
    * modified - Underscore(), no more use for video and audio - leave for subtitle (no simple solution for now)
    * modified - SubCharset(), remove undesired outpout
    * modified - CustomAudioEncod(), for AAC now configure channels is possible
    * modified - CustomAudioEncod(), now use libfdk_aac as AAC codec, not GPL but best quality
    * fix - ConfChannels(), libfdk_aac not support 2.1, 3.1 & 4.1, by default downgrade the lower channel layout
    * fix - SourceInfo(), source file name now display in all call
    * rename - CustomSoundEncod(), to CustomAudioEncod() because its better
    * rename - InfoChoice(), to CustomInfoChoice() because is displayed only in profile 1 (custom)
    * remove - ConfStereoChannels(), no more use
* profiles:
    * add - profile 8, for make hdlight encoding very slow but with better quality and compression than profile 7
    * add - profile 22, make flac lossless audio
    * add - profile 32, tools for extract stream(s) (subtitle, video or audio) of stream video file
    * add - for several profiles add a question for make stream custom encoding (appear source have more of 2 streams)
    * add - profile 1, add option for subtitle if sub file in repertory
    * add - profile 99, dependencies test
    * modified - profile 7, for make hdlight enconding "quite fast"
    * modified - profile 8, (rotation) rename in 33, now in tools category
    * modified - profile 3, change quality of mp3 to VBR190-250kb
    * modified - quality level change in many profiles
    * fix - profile 1, aac sound no channel now change work
    * fix - profile 1, if choice avi/mp4 container, if no choice in map question, now no apply "-map 0"
* various:
    * add - checked audio files *.ape (Monkey's Audio), *.spx (Speex) & *.ac3
    * add - check and treat encode error "H.264 bitstream malformed"
    * modified - regrouping script
    * modified - readme
    * modified - main menu interface, now it's a (fake) table

v0.06:
* fix get profile 21
* add deinterlace to profile 3
* add *.MTS in checked video files
* add *.3gp & *.3GP in checked video files
* add profile 6 for smartphone video
* add choice profile 5.0, 5.1, 5.2, in full custom option (1)
* add profile 7 rotate smartphone video
* various fix

v0.05:
* various fix & clean
* Add profile 3 (various source -> x264 in cfr21 and mp3, Use for reduce size of camera video)
* Add sound support with MP3 VBR150-195kb Stereo profile
* Add map option for option 1 (Full custom)
* Add option 31 for view stats of Stream(s) of the local media file
* README update

v0.04:
* various add for option 1:
    * add audio bitrate selection for MP3 & AC3
    * add support of multi audio channels configuration for AC3, 1.0 to 5.1
    * add support of stereo configuration for AAC (MP3 not support more than 2 channels)
    * add support of container, avi, mkv or mp4
* add error msg if no sub in directory for option 10 & 11

v0.03:
* add custom encoding video in option 1, with support of this:
    * resolution changed option
    * deinterlace option
    * video codecs x264, x265 & mpeg4
    * audio codecs AAC, MP3 & AC3
    * subtitle option if file present in repertory
* various fix

v0.02:
* add check video & sound file in main repertory, for display count of file & alarm for number of video file > 1.
* add menu entry for quit (exit or quit or q) and restart (restart or rst or r) script.
* errors functions, now merged in one function.
* rework batchs management, now a specific function list and increment text file with extention of videos in repertory. This list put in ffmpeg cmd.
* improvement of error response due to more accurate batchs management

v0.01:
* initial version
* profile 2, 3, 4, 10 & 11 integrated and tested
* subtitle charset detect and changed to UTF-8
* manage error AAC extradata  for mvk copy - container is remplace by mp4
* manage error timestamp for mvk copy - apply option -fflags +genpts
