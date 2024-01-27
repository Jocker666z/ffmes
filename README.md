# ffmes - ffmpeg media encode script 

Bash tool handling media files, DVD & Blu-ray. Mainly with ffmpeg. In batch or single file.

Source media files, supported extension:
* Video in 3gp, avi, bik, flv, m2ts, m4v, mkv, mp4, mov, mpeg, mts, ogv, rm, rmvb, ts, vob, vp9, webm, wmv
* Audio in 8svx, aac, ac3, aif, aiff, amb, ape, aptx, aud, caf, dff, dsf, dts, eac3, flac, m4a, mka, mlp, mod, mp2, mp3, mqa, mpc, mpg, oga, ogg, ops, opus, ra, ram, sbc, shn, spx, tak, thd, tta, w64, wav, wma, wv
* Subtitle in ass, idx/sub, srt, ssa, sup

--------------------------------------------------------------------------------------------------
## Install & update
`curl https://raw.githubusercontent.com/Jocker666z/ffmes/master/ffmes.sh > /home/$USER/.local/bin/ffmes && chmod +rx /home/$USER/.local/bin/ffmes`

## Dependencies
### Essential 
`ffmpeg ffprobe jq mkvtoolnix uchardet coreutils findutils bc`
### Optional
* `gojq`: faster than jq
* `mediainfo`: faster than ffmpeg & ffprobe
### CUE Splitting
`cuetools flac monkeys-audio shntool wavpack`
### DVD rip
`dvdbackup lsdvd ogmtools setcd pv`
### DVD Subtitle
`ogmrip tesseract-ocr tesseract-ocr-all wget`
### Blu-Ray rip
`bluray_copy bluray_info`
### Audio tag
`atomicparsley flac monkeys-audio python-mutagen vorbis-tools wavpack`

## Use
```
Usage:
  Select all currents: ffmes
  Select file:         ffmes -i [INPUTFILE]
  Select directory:    ffmes -i [INPUTDIR]

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
                          Default: 1 (-1 db)
  -v|--verbose            Display ffmpeg log level as info.
  -vv|--fullverbose       Display ffmpeg log level as debug.
```
Examples:
* `ffmes` with audio/video in directory
* `ffmes -i DIRECTORY-TO.EDIT` for directory
* `ffmes -i FILE-TO.EDIT` for single video, audio, or subtitle
* `ffmes -vv -i FILE-TO.EDIT` for single video or audio, with ffmpeg in log level as debug
* `ffmes -s 1 -i FILE-TO.EDIT` for single video, select option 1 by-passing the main menu

## Test
ffmes is tested, under Debian unstable almost every day.
If you encounter bugs or have proposals, I'm open to discussion.

--------------------------------------------------------------------------------------------------
## Documentations

### Main menu options
* Video:
	* 0, DVD & Blu-ray rip
	* 1, video encoding with custom options
	* 2, copy stream to mkv with map option
	* 3, add audio stream with night normalization
	* 4, one audio stream encoding
* Video tools:
	* 10, add audio stream or subtitle in video file
	* 11, concatenate video files
	* 12, extract stream(s) of video file
	* 13, split or cut video file by time
	* 14, split mkv by chapter
	* 15, change color of DVD subtitle (idx/sub)
	* 16, convert DVD subtitle (idx/sub) to srt
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
	* 31, compare audio files stats
	* 32, generate png image of audio spectrum
	* 33, concatenate audio files 
	* 34, split or cut audio file by time
	* 35, audio file tester

--------------------------------------------------------------------------------------------------
### Video options

#### Option 0 details - DVD & Blu-ray rip
##### DVD:
* Rip DVD, include ISO and VIDEO_TS VOB
* Choose title
* Remux all stream in mkv
* Chapters integration
* launch option 1 (optional)

##### Blu-ray:
* Rip ISO & disc directory
* Choose one title or all
* Remux all stream in mkv
* Subtitles metadata integration
* Chapters integration
* https://github.com/beandog/bluray_info must be installed (see install help bellow)

#### Option 1 details - video encoding, custom options
* Video:
	* Stream copy or encoding
	* Encoding options:
		* desinterlace
		* change resolution
		* rotate video (except hevc_vaapi)
		* HDR to SDR (except hevc_vaapi & mpeg4)
		* codecs:
			* libx264: profile, tune, preset & bitrate (video stream total size, crf & cbr)
			* libx265: profile, tune, preset, bitrate (video stream total size, crf & cbr), 1 or 2 pass encoding (not in batch)
			* hevc_vaapi: profile, bitrate (video stream total size, qp & cbr); need ffmpeg --enable-vaapi & proper system configuration; note at same bitrate low quality than libx265 but the encoding speed is much faster
			* AV1:
				* libaom-av1: cpu-used (preset), bitrate (video stream total size, crf & cbr)
				* libsvtav1: preset, bitrate (video stream total size, crf & cbr); need ffmpeg --enable-libsvtav1
			* mpeg4 (xvid): bitrate (qscale & cbr)
* Audio:
	* All stream copy or encoding
	* Encoding options (apply to all streams):
		* codecs:
			* ac3 (ac3): bitrate (vbr & cbr)
			* opus (libopus): bitrate (vbr)
			* vorbis (libvorbis): bitrate (vbr & cbr)
			* flac (libflac): compression
		* Channels layout for ac3, flac, vorbis: 1.0, 2.0, 2.1, 3.0, 3.1, 4.0, 4.1, 5.1
		* Channels layout for opus: 1.0, 2.0, 3.0, 5.1
* Container:
	* mkv & mp4 support
* Map streams selection

#### Option 2 details - copy stream to mkv with map option
Copy stream in mkv file, with streams selection if source have more than 2 streams.

#### Option 3 details - add audio stream with night normalization
Add stream with night mode normalization (the amplitude of sound between heavy and weak sounds will decrease).
The new stream is in opus, stereo, 320kb. The final will be a mkv

#### Option 4 details - encode one audio stream only
Encode the selected audio stream of a video file, with the same settings as option 1. The final will be a mkv.

#### Option 13 details - split or cut video file by time
Cut or split one video by time. Examples of input:

* [s.20]        > remove video after 20 second
* [e.01:11:20]  > remove video before 1 hour 11 minutes 20 second
* [p.00:02:00]  > split video in parts of 2 minutes

#### Option 14 details - split mkv by chapter
Cut one matroska video per chapter, mkvtoolnix package must be installed.

#### Option 15 details - change color of DVD subtitle (idx/sub)
You must run the option in a directory containing one or more pairs of idx/sub files with the same filename.

Colors palette available:
* white font / black border
* black font / white border
* yellow font / black border
* yellow font / white border

#### Option 16 details - convert DVD subtitle (idx/sub) to srt
You must have installed tesseract-ocr, and ogmrip package (includes subp2tiff and subptools binaries).

Support :
* Language: english, french, deutsch, spanish, portuguese, italian, japanese, chinese simplified, arabic, korean, russian.
* multi index idx/sub

Tesseract engine available:
* By recognizing character patterns, fast but not reliable
* By recognizing character patterns + neural net (LSTM), slow but reliable (default)

--------------------------------------------------------------------------------------------------
### Audio options

#### Option 21 details - PCM encoding
* Encoding options:
	* Quality:
		* unsigned 8-bit
		* signed 8-bit
		* signed 16-bit little-endian
		* signed 24-bit little-endian
		* signed 32-bit little-endian
		* Sample rate: 44kHz, 48kHz, or auto (use libsoxr resampler if possible)
	* Channels layout 1.0 to 5.1
	* False stereo files detection (if a channels configuration not selected)
	* -1db peak normalization (only files that have a value less than) (if a channels configuration not selected)
	* After encoding, option for remove all source files, if not for remove created files

#### Option 22 details - FLAC encoding
* Encoding options:
	* Quality:
		* Compression level: 0 (fastest) & 12 (slowest)
		* Sample rate: 44kHz, 48kHz, or auto (384kHz max) (use libsoxr resampler if possible)
		* Bit depth: 16, 24 bits, or auto
	* Channels layout 1.0 to 5.1
	* False stereo files detection (if a channels configuration not selected)
	* -1db peak normalization (only files that have a value less than) (if a channels configuration not selected)
	* After encoding, option for remove all source files, if not for remove created files

#### Option 23 details - WavPack encoding
* Encoding options:
	* Quality:
		* Compression level: 0 (fastest) & 3 (slowest)
		* Sample rate: 44kHz, 48kHz, or auto (384kHz max) (use libsoxr resampler if possible)
		* Bit depth: 16, 24/32 bits, or auto
	* Channels layout 1.0 to 5.1
	* False stereo files detection (if a channels configuration not selected)
	* -1db peak normalization (only files that have a value less than) (if a channels configuration not selected)
	* After encoding, option for remove all source files, if not for remove created files

#### Option 26 details - Opus encoding
* Encoding options:
	* Bitrate
		* vbr, 64kb to 510kb
		* OR mode "accurate auto adapted bitrate from source", particularly useful for processing very large batches of files
	* Channels layout 1.0, 2.0, 3.0, 5.1
	* After encoding, option for remove all source files, if not for remove created files

#### Option 27 details - AAC encoding
* Codec used: if the libfdk_aac codec is available (present in non-free configuration), it will be chosen by default. Otherwise it is the aac codec which will be chosen (present in the free configuration).
* Encoding options:
	* Bitrate
		* vbr 1 to 5
		* cbr 64kb to 560kb
		* OR mode "accurate auto adapted bitrate from source", particularly useful for processing very large batches of files
	* Channels layout 1.0 to 5.1
	* After encoding, option for remove all source files, if not for remove created files

#### Option 30 details - tag editor
Tag for ape, flac, m4a, mp3, ogg, opus, wv files.

Options:
* Change or add tag disc number
* Rename files in "Track - Title"
* Rename files in "Track - Artist - Title"
* Rename files in "Disc-Track - Title"
* Rename files in "Disc-Track - Artist - Title"
* Change or add tag track, by alphabetic sorting
* Change or add tag album
* Change or add tag disc number
* Change or add tag artist
* Change tag artist by "unknown"
* Change or add tag date
* Change tag title for filename
* Change tag title for "untitled"
* Remove N character at begin in tag title
* Remove N character at end in tag title
* Remove text pattern in tag title.

Restriction:
* Max depth directory 2
* Asian character not supported (display degrading)

#### Option 35 details - split or cut audio file by time
Cut or split one audio by time. Examples of input:

* [s.20]        > remove audio after 20 second
* [e.01:11:20]  > remove audio before 1 hour 11 minutes 20 second
* [p.00:02:00]  > split audio in parts of 2 minutes

--------------------------------------------------------------------------------------------------
## In script options (variables)
### Various
* FFMPEG_CUSTOM_BIN: used for everything except video encoding; change default ffmpeg system bin for other location
* FFPROBE_CUSTOM_BIN: change default ffprobe system bin for other location
### Video
* NVENC (default=0)
	* Description: number of video encoding in same time, the countdown starts at 0 (0=1;1=2...)
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
## Dependencies installation
### bluray_info & bluray_copy
Dependencies: `libbluray-dev libaacs-dev`

```
git clone https://github.com/beandog/bluray_info && cd bluray_info
autoreconf -fi && ./configure
make
su -c "make install" -m "root"
```

--------------------------------------------------------------------------------------------------
## Known errors
* ffmpeg output error with CIFS mount solutions:
	* in your `/etc/fstab`, add option `cache=none`
	* or use NFS instead samba
* CUE split fail with 24bits audio (shnsplit bug)

--------------------------------------------------------------------------------------------------
## Holy reading
* Video:
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
	* SVT-AV1:
		* https://gitlab.com/AOMediaCodec/SVT-AV1/-/tree/master/Docs
* Audio:
	* https://wiki.hydrogenaud.io/index.php?title=Lossless_comparison
	* https://wiki.hydrogenaud.io/index.php/LAME
	* https://digitalcardboard.com/blog/2009/08/25/the-sox-of-silence/
* Tags:
	* https://picard-docs.musicbrainz.org/en/appendices/tag_mapping.html

### FFmpeg static
* https://github.com/BtbN/FFmpeg-Builds/wiki/Latest#latest-autobuilds
	* pro: compiled
	* pro: lgpl compliant (include vaapi & more)
	* con: without non-free codec
* https://johnvansickle.com/ffmpeg/
	* pro: compiled
	* pro: official
	* con: without non-free codec
* https://github.com/markus-perl/ffmpeg-build-script
	* pro: with non-free codec
	* con: not compiled

--------------------------------------------------------------------------------------------------
## Holy tools
* Subtitle:
	* https://github.com/smacke/ffsubsync
