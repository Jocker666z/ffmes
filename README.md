# ffmes - ffmpeg media encode script 

Bash tool handling media files, and DVD. Mainly with ffmpeg. In batch or single file.

Source media files, supported extension:
* Video in 3gp, avi, bik, flv, m2ts, m4v, mkv, mp4, mov, mpeg, mts, ogv, ts, vob, vp9, webm, wmv
* Audio in 8svx, aac, ac3, aif, aiff, amb, ape, aud, caf, dff, dsf, dts, flac, m4a, mka, mlp, mod, mp2, mp3, mqa, mpc, mpg, ogg, ops, opus, rmvb, shn, spx, tta, w64, wav, wma, wv
* Subtitle in idx/sub, srt, ssa, sup

**Note**: VGM encoding is now dissociated from ffmes, see **vgm2flac -> https://github.com/Jocker666z/vgm2flac**

--------------------------------------------------------------------------------------------------
## Install & update
`curl https://raw.githubusercontent.com/Jocker666z/ffmes/master/ffmes.sh > /home/$USER/.local/bin/ffmes && chmod +rx /home/$USER/.local/bin/ffmes`

## Dependencies

### Essential 
`ffmpeg ffprobe jq mkvtoolnix mediainfo sox uchardet coreutils findutils bc`

### CUE Splitting
`cuetools flac monkeys-audio shntool`

### DVD rip
`dvdbackup lsdvd ogmtools pv`

### DVD Subtitle
`ogmrip tesseract-ocr tesseract-ocr-all wget`

### Audio tag
`flac monkeys-audio audiotools python-mutagen wavpack`

## Use
```
Usage: ffmes options
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
                          Default: 1 (-1 db)
  -v|--verbose            Display ffmpeg log level as info.
  -vv|--fullverbose       Display ffmpeg log level as debug
```

Exemples:
* `ffmes` with audio/video in directory
* `ffmes -i DIRECTORY-TO.EDIT` for directory
* `ffmes -i FILE-TO.EDIT` for single video or audio
* `ffmes -vv -i FILE-TO.EDIT` for single video or audio, with ffmpeg in log level as debug
* `ffmes -s 1 -i FILE-TO.EDIT` for single video, select option 1 by-passing the main menu

### Nemo action
`nano ~/.local/share/nemo/actions/ffmes.nemo_action`
```
[Nemo Action]
Active=true
Name=ffmes %N
Comment=ffmes %N
Exec=gnome-terminal -- bash -c "cd '%P' && ~/.local/bin/ffmes -i '%F'; bash"
Selection=any
Extensions=any;
```

## Test
ffmes is tested, under Debian unstable almost every day.
If you encounter problems or have proposals, I am open to discussion.

--------------------------------------------------------------------------------------------------
## Documentations

### Main menu options
* Video:
	* 0, DVD rip (vob, ISO, or disc)
	* 1, video encoding
	* 2, copy stream to mkv with map option
	* 3, encode audio stream only
	* 4, add audio stream with night normalization
* Video tools:
	* 10, view detailed video file informations
	* 11, add audio stream or subtitle in video file
	* 12, concatenate video files
	* 13, extract stream(s) of video file
	* 14, cut video file
	* 15, split mkv by chapter
	* 16, change color of DVD subtitle (idx/sub)
	* 17, convert DVD subtitle (idx/sub) to srt
* Audio:
	* 20, CUE splitter to flac
	* 21, audio to wav (PCM)
	* 22, audio to flac
	* 23, audio to wavpack
	* 24, audio to mp3 (libmp3lame)
	* 25, audio to vorbis (libvorbis)
	* 26, audio to opus (libopus)
	* 27, audio to aac
* Audio tools:
	* 30, audio tag editor
	* 31, view one audio file stats
	* 32, compare audio files stats
	* 33, generate png image of audio spectrum
	* 34, concatenate audio files 
	* 35, cut audio file
	* 36, audio file tester
	* 37, find untagged audio files

--------------------------------------------------------------------------------------------------
### Video options
#### Option 0 details - DVD rip (vob, ISO, or disc)
* Rip DVD, include ISO and VIDEO_TS VOB
* Chapters integration
* Fix timestamp and display ratio to mkv file (stream copy)
* launch option 1 (optional)
    
#### Option 1 details - video encoding, full custom options
* Video:
	* Stream copy or encoding
	* Encoding options:
		* rotate video
		* HDR to SDR
		* change resolution
		* desinterlace
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

#### Option 2 details - copy stream to mkv with map option
Copy stream in mkv file, with streams selection if source have more than 2 streams.

#### Option 3 details - encode audio stream only
Encode the selected audio streams of video files (or all of them).

#### Option 4 details - add audio stream with night normalization
From inplace matroska video (with audio), add stream with night mode normalization (the amplitude of sound between heavy and weak sounds will decrease).
The new stream is in opus, stereo, 320kb.

#### Option 15 details - split mkv by chapter
Cut one matroska video per chapter, mkvtoolnix package must be installed.

#### Option 16 details - change color of DVD subtitle (idx/sub)
You must run the option in a directory containing one or more pairs of idx/sub files with the same filename.

Colors palette available:
* white font / black border
* black font / white border
* yellow font / black border
* yellow font / white border

#### Option 17 details - convert DVD subtitle (idx/sub) to srt
You must have installed tesseract-ocr with your language support, but also ogmrip package (includes subp2tiff and subptools binaries).

Language supported: english, french, deutsch, spanish, portuguese, italian, japanese, chinese simplified, arabic, korean, russian.

Tesseract engine available:
* By recognizing character patterns, fast but not reliable
* By neural net (LSTM), slow but reliable (default)

--------------------------------------------------------------------------------------------------
### Audio options

#### Option 21 details - PCM encoding
* Encoding options:
	* Quality:
		* signed 16-bit little-endian
		* signed 24-bit little-endian
		* signed 32-bit little-endian
		* signed 8-bit
		* unsigned 8-bit
	* Channels layout 1.0 to 5.1
	* False stereo files detection (if a channels configuration not selected)
	* -1db peak normalization (only files that have a value less than)
	* Silence detect & remove, at start & end (only wav & flac source)
	* After encoding, option for remove all source files, if not for remove created files

#### Option 22 details - FLAC encoding
* Encoding options:
	* Quality:
		* Sample rate: 44kHz, 48kHz, or auto (384kHz max)
		* Bit depth: 16, 24 bits, or auto
	* Channels layout 1.0 to 5.1
	* False stereo files detection (if a channels configuration not selected)
	* -1db peak normalization (only files that have a value less than)
	* Silence detect & remove, at start & end (only wav & flac source)
	* After encoding, option for remove all source files, if not for remove created files

#### Option 23 details - WavPack encoding
* Encoding options:
	* Quality:
		* Sample rate: 44kHz, 48kHz, or auto (384kHz max)
		* Bit depth: 16, 24/32 bits, or auto
	* Channels layout 1.0 to 5.1
	* False stereo files detection (if a channels configuration not selected)
	* -1db peak normalization (only files that have a value less than)
	* Silence detect & remove, at start & end (only wav & flac source)
	* After encoding, option for remove all source files, if not for remove created files

#### Option 26 details - Opus encoding
* Encoding options:
	* Bitrate
		* vbr, 64kb to 510kb
		* OR mode "accurate auto adapted bitrate from source", particularly useful for processing very large batches of files.
	* Channels layout 1.0, 2.0, 3.0, 5.1
	* False stereo files detection (if a channels configuration not selected)
	* -1db peak normalization (only files that have a value less than)
	* Silence detect & remove, at start & end (only wav & flac source)
	* After encoding, option for remove all source files, if not for remove created files

#### Option 27 details - AAC encoding
* Codec used: if the libfdk_aac codec is available (present in non-free configuration), it will be chosen by default. Otherwise it is the aac codec which will be chosen (present in the free configuration).
* Encoding options:
	* Bitrate
		* vbr 1 to 5
		* cbr 64kb to 560kb
		* OR mode "accurate auto adapted bitrate from source", particularly useful for processing very large batches of files.
	* Channels layout 1.0, 2.0, 3.0, 5.1
	* False stereo files detection (if a channels configuration not selected)
	* -1db peak normalization (only files that have a value less than)
	* Silence detect & remove, at start & end (only wav & flac source)
	* After encoding, option for remove all source files, if not for remove created files

#### Option 30 details - tag editor
Tag for aiff, ape, flac, m4a, mp3, ogg, opus, wv files

Options:
* Change or add tag disc number
* Rename files in "Track - Title"
* Rename files in "Track - Artist - Title"
* Change or add tag track, by alphabetic sorting
* Change or add tag album
* Change or add tag disc number
* Change or add tag artist
* Change tag artist by "unknown"
* Change or add tag date
* Change tag title for filename
* Change tag title for "untitled"
* Remove N character at begin in tag title (9 characters at once)
* Remove N character at end in tag title (9 characters at once)
* Remove text pattern in tag title.

Restriction:
* Max depth directory 1
* Asian character not supported (display degrading)

--------------------------------------------------------------------------------------------------
## In script options (variables)
### Various
* FFMPEG_CUSTOM_BIN: change default ffmpeg system bin for other location
* FFPROBE_CUSTOM_BIN: change default ffprobe system bin for other location
* SOX_CUSTOM_BIN: change default sox system bin for other location
### Video
* NVENC (default=0)
	* Description: Number of video encoding in same time, the countdown starts at 0 (0=1;1=2...)
### Audio
* ExtractCover (default=0)
	* Description: action performed during encoding
	* 0=extract cover from source and remove in output
	* 1=keep cover from source in output
	* empty=remove cover in output
* RemoveM3U (default=0)
	* Description: action performed after encoding at "Remove source audio?" question
	* 0=no remove
	* 1=remove
* PeakNormDB (default=1)
	* Description: Peak db normalization option, this value is written as positive but is used in negative (e.g. 4 = -4)

--------------------------------------------------------------------------------------------------
## Issue
* rename bug with mv and CIFS mount: add `cache=loose` in your mount option
* CUE split fail with 24bits audio (shnsplit bug)

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
	* https://wiki.hydrogenaud.io/index.php/LAME
