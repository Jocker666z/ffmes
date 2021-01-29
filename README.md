# ffmes - ffmpeg media encode script 

Bash tool handling media files, DVD and audio CD. Mainly with ffmpeg. In batch or single file.

Source media files, supported extension:
* Video in *.mkv *.m4v *.m2ts *.avi *.ts *.mts *.mpg *.flv *.mp4 *.mov *.wmv *.3gp *.vob *.mpeg *.vp9 *.webm *.ogv *.bik
* Audio in *.ac3 *.ape *.wma *.m4a *.mp3 *.flac *.ogg *.mpc *.ac3 *.aac *.spx *.wav *.dsf *.aud *.tta *.opus *.mod *.mpg *.wv *.dts
* Subtitle in *.srt *.ssa *.sub *.sup

Note: VGM encoding removed from ffmes, I cut the script in half for easier maintainability, the vgm encoding is now done with vgm2flac -> https://github.com/Jocker666z/vgm2flac

--------------------------------------------------------------------------------------------------
## Dependencies
`ffmpeg ffprobe mkvtoolnix mediainfo abcde sox ogmtools ogmrip lsdvd dvdbackup shntool cuetools uchardet coreutils findutils bc libao bchunk setcd tesseract-ocr tesseract-ocr-all wget`

## Install
* `cd && wget https://github.com/Jocker666z/ffmes/archive/master.zip`
* `unzip master.zip && mv ffmes-master ffmes && rm master.zip`
* `cd ffmes && chmod a+x ffmes.sh`
* `echo "alias ffmes=\"bash ~/ffmes/ffmes.sh\"" >> ~/.bash_aliases && source ~/.bash_aliases` (alias optional but recommended & handy)
* Nemo action:
`nano ~/.local/share/nemo/actions/ffmes.nemo_action`
```
[Nemo Action]
Active=true
Name=ffmes %N
Comment=ffmes %N
Exec=gnome-terminal -- bash -c "cd '%P' && ~/ffmes/ffmes.sh -i '%F'; bash"
Quote=double
EscapeSpaces=true
Selection=any
Extensions=any;
```

## Use
Options:
* without option treat current directory
* -i|--input <file> : treat one file
* -i|--input <directory> : treat in batch a specific directory
* -h|--help : display help
* --novaapi : no use vaapi for decode video.
* -j|--videojobs <number> : number of video encoding in same time (default: 3)
* -s|--select <number> : preselect option 
* -v|--verbose : display ffmpeg log level as info
* -vv|--fullverbose : display ffmpeg log level as debug

Exemples:
1. if no alias: 
    * `bash ~/ffmes/ffmes.sh` with audio/video in same directory of script
    * `bash ~/ffmes/ffmes.sh -i DIRECTORY-TO.EDIT` for directory
    * `bash ~/ffmes/ffmes.sh -i FILE-TO.EDIT` for single video or audio
2. elif with alias (recommended):
    * `ffmes` with audio/video in directory
    * `ffmes -i DIRECTORY-TO.EDIT` for directory
    * `ffmes -i FILE-TO.EDIT` for single video or audio
    * `ffmes -vv -i FILE-TO.EDIT` for single video or audio, with ffmpeg in log level as debug
    * `ffmes -s 1 -i FILE-TO.EDIT` for single video, select option 1 by-passing the main menu

## Test
ffmes is tested, under Debian stable and unstable almost every day.
If you encounter problems or have proposals, I am open to discussion.

## Embed binarie
* opustags - https://github.com/fmang/opustags

--------------------------------------------------------------------------------------------------
## Documentations

### Main menu options
* Video:
	* 0, DVD rip (vob, ISO, or disc)
	* 1, video encoding
	* 2, copy stream to mkv with map option
* Video tools:
	* 10, view detailed video file informations
	* 11, add audio stream or subtitle in video file
	* 12, concatenate video files
	* 13, extract stream(s) of video file
	* 14, cut video file
	* 15, add audio stream with night normalization
	* 16, split mkv by chapter
	* 17, change color of DVD subtitle (idx/sub)
	* 18, convert DVD subtitle (idx/sub) to srt
* Audio :
	* 20, CD rip
	* 21, CUE splitter to flac
	* 22, audio to wav (PCM)
	* 23, audio to flac
	* 24, audio to wavpack
	* 25, audio to mp3 (libmp3lame)
	* 26, audio to ogg (libvorbis)
	* 27, audio to opus (libopus)
* Audio tools :
	* 30, tag editor
	* 31, view detailed audio file informations
	* 32, generate png image of audio spectrum
	* 33, concatenate audio files 
	* 34, cut audio file

### Option 0 details - DVD rip (vob, ISO, or disc)
* Rip DVD, include ISO and VIDEO_TS VOB
* Chapters integration
* Fix timestamp and display ratio to mkv file (stream copy)
* launch option 1 (optional)
    
### Option 1 details - video encoding, full custom options
* Video:
	* Stream copy or encoding
	* Encoding options:
		* crop video
		* rotate video
		* HDR to SDR
		* change resolution
		* deinterlace
		* fix frame rate to 24fps
		* codecs:
			* x264: profile, tune, preset & bitrate (video stream total size, crf & cbr)
			* x265: profile, tune, HDR, preset & bitrate (video stream total size, crf & cbr)
			* mpeg4 (xvid): bitrate (qscale & cbr)
		* if VAAPI device found at /dev/dri/renderD128, it's used for decode video
* Audio:
	* Stream copy or encoding
	* Encoding options (apply to all streams):
		* codecs:
			* ac3 (ac3): bitrate (vbr & cbr)
			* opus (libopus): bitrate (vbr)
			* vorbis (libvorbis): bitrate (vbr & cbr)
			* flac (libflac): compression
		* Channels layout for ac3, flac, vorbis: 1.0, 2.0, 2.1, 3.0, 3.1, 4.0, 4.1, 5.1
		* Channels layout for opus: 1.0, 2.0, 3.0, 5.1
* Container selection
	* mkv & mp4 support
* Map streams selection

### Option 2 details - copy stream to mkv with map option
Copy stream in mkv file, with streams selection if source have more than 2 streams.

### Option 15 details - add audio stream with night normalization
From inplace matroska video (with audio), add stream with night mode normalization (the amplitude of sound between heavy and weak sounds will decrease).
The new stream is in opus, stereo, 320kb.

### Option 16 details - split mkv by chapter
Cut one matroska video per chapter, mkvtoolnix package must be installed.

### Option 17 details - change color of DVD subtitle (idx/sub)
You must run the option in a directory containing one or more pairs of idx/sub files with the same filename.

Colors palette available:
* white font / black border
* black font / white border
* yellow font / black border
* yellow font / white border

### Option 18 details - convert DVD subtitle (idx/sub) to srt
You must have installed tesseract-ocr with your language support, but also ogmrip package (includes subp2tiff and subptools binaries).

Language supported: english, french, deutsch, spanish, portuguese, italian, japanese, chinese simplified, arabic, korean, russian.

Tesseract engine available:
* By recognizing character patterns, fast but not reliable
* By neural net (LSTM), slow but reliable (default)

### Option 22 details - PCM encoding
* Encoding options:
	* Quality :
		* signed 16-bit little-endian
		* signed 24-bit little-endian
		* signed 32-bit little-endian
		* signed 8-bit
		* unsigned 8-bit
	* Channels layout 1.0 to 5.1
	* False stereo files detection (if a channels configuration not selected)
	* 0db peak normalization
	* Silence detect & remove, at start & end (only wav & flac source)
	* After encoding, option for remove all source files, if not for remove created files

### Option 23 details - FLAC encoding
* Encoding options:
	* Quality :
		* Sample rate: 44kHz, 48kHz, or auto
		* 24 bits support
		* Full command line option
	* Channels layout 1.0 to 5.1
	* False stereo files detection (if a channels configuration not selected)
	* 0db peak normalization
	* Silence detect & remove, at start & end (only wav & flac source)
	* After encoding, option for remove all source files, if not for remove created files

### Option 24 details - WavPack encoding
* Encoding options:
	* Quality :
		* Sample rate: 44kHz, 48kHz, or auto
		* 24/32 bits support
		* Full command line option
	* Channels layout 1.0 to 5.1
	* False stereo files detection (if a channels configuration not selected)
	* 0db peak normalization
	* Silence detect & remove, at start & end (only wav & flac source)
	* After encoding, option for remove all source files, if not for remove created files

### Option 25 details - opus encoding
* Encoding options:
	* Bitrate
		* vbr, 64kb to 510kb (selectable options).
		* OR mode "accurate auto adapted bitrate from source", particularly useful for processing very large batches of files.
	* Channels layout 1.0, 2.0, 3.0, 5.1
	* False stereo files detection (if a channels configuration not selected)
	* 0db peak normalization
	* Silence detect & remove, at start & end (only wav & flac source)
	* After encoding, option for remove all source files, if not for remove created files

### Option 30 details - tag editor
Options:
* Change or add tag disc number
* Rename files in "Track - Title" (add track number if not present)
* Change or add tag track, by alphabetic sorting, to use if no file has this tag
* Change or add tag album
* Change or add tag disc number
* Change or add tag artist
* Change or add tag date
* Change tag title for filename
* Change tag title for untitled
* Remove N character at begin of tag title (9 characters at once).
* Remove N character at end of tag title (9 characters at once).
Restriction:
* Max depth directory 1
* Asian character not supported (display in degrading mode)
* Monkey's Audio (APE) not supported

--------------------------------------------------------------------------------------------------
## In script options (variables)
### Video
* NVENC (default=1)
	* Description: Number of video encoding in same time, the countdown starts at 0 (0=1;1=2...)
### Audio
* ExtractCover (default=0)
	* Description: action performed during encoding
	* 0=extract cover from source and remove in output
	* 1=keep cover from source in output (not compatible with opus)
	* empty=remove cover in output
* RemoveM3U (default=1)
	* Description: action performed after encoding at "Remove source audio?" question
	* 0=no remove
	* 1=remove
* PeakNormDB (default=0)
	* Description: Peak db normalization option, this value is written as positive but is used in negative (e.g. 4 = -4)

--------------------------------------------------------------------------------------------------
## Issue
* rename bug with mv and CIFS mount: add `cache=loose` in your mount option
* CUE split fail with 24bits audio

--------------------------------------------------------------------------------------------------
## Holy reading
* Video codecs:
	* https://github.com/leandromoreira/digital_video_introduction#how-does-a-video-codec-work
	* https://slhck.info/video/2017/03/01/rate-control.html
	* x264:
		* https://trac.ffmpeg.org/wiki/Encode/H.264
		* https://sites.google.com/site/linuxencoding/x264-ffmpeg-mapping
		* http://www.chaneru.com/Roku/HLS/X264_Settings.htm
		* http://filthypants.blogspot.fr/2008/07/comparison-of-x264h264-advanced-options.html
	* x265:
		* https://x265.readthedocs.io/en/default/
		* https://trac.ffmpeg.org/wiki/Encode/H.265
		* https://en.wikipedia.org/wiki/High_Efficiency_Video_Coding#Profiles
		* https://en.wikipedia.org/wiki/High_Efficiency_Video_Coding_tiers_and_levels
		* https://x265.readthedocs.io/en/default/presets.html
* Audio codecs:
	* https://wiki.hydrogenaud.io/index.php?title=Lossless_comparison
