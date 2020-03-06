# ffmes - ffmpeg media encode script 

Terminal tool handling media files, DVD, audio CD, and VGM. Mainly with ffmpeg. In batch or single file.

Source media files, supported extension:
* Video in *.mkv *.m4v *.m2ts *.avi *.ts *.mts *.mpg *.flv *.mp4 *.mov *.wmv *.3gp *.vob *.mpeg *.vp9 *.webm *.ogv *.bik
* Audio in *.ac3 *.ape *.wma *.m4a *.mp3 *.flac *.ogg *.mpc *.ac3 *.aac *.spx *.wav *.dsf *.aud *.tta *.opus *.mod *.mpg *.wv
* VGM in *.bfstm *.bfwav *.gbs *.minipsf *.miniusf *.minissf *.rak *.ssf *.spc *.psf *.vgm *.vgz *.xa *.psf2 *.minipsf2 *.ads *.mod *.mus *.tak *.adx *.ss2 *.adp *.dsp *.hps *.snd *.sndh *.vag *.int *.thp *.vpk *.voc *.dsf *.spsd *.dat *.eam *.at3 *.raw *.bin
* Subtitle in *.srt *.ssa

--------------------------------------------------------------------------------------------------
## Dependencies
`ffmpeg mkvtoolnix abcde sox mediainfo lsdvd dvdbackup shntool cuetools uchardet coreutils findutils bc libao bchunk`

## Install
* `cd`
* `wget https://github.com/Jocker666z/ffmes/archive/master.zip`
* `unzip master.zip && mv ffmes-master ffmes`
* `rm master.zip`
* `cd ffmes`
* `chmod a+x ffmes.sh`
* `echo "alias ffmes=\"bash ~/ffmes/ffmes.sh\"" >> ~/.bash_aliases && source ~/.bash_aliases` (alias optional but recommended & handy)

## Use
1. if no alias: 
    * `bash ~/ffmes/ffmes.sh` with audio/video in same directory of script
    * `bash ~/ffmes/ffmes.sh DIRECTORY-TO.EDIT` for directory
    * `bash ~/ffmes/ffmes.sh FILE-TO.EDIT` for single video or audio
2. elif with alias (recommended):
    * `ffmes` with audio/video in directory
    * `ffmes DIRECTORY-TO.EDIT` for directory
    * `ffmes FILE-TO.EDIT` for single video or audio
3. elif with nemo action:
`nano ~/.local/share/nemo/actions/ffmes.nemo_action`
```
[Nemo Action]
Active=true
Name=ffmes %N
Comment=ffmes %N
Exec=gnome-terminal -- bash -c "~/ffmes/ffmes.sh '%F'; bash"
Selection=any
Extensions=any;
```

## Test
ffmes is tested, under debian stable and testing almost every day.
If you encounter problems or have proposals, I am open to discussion.

## Embeds binaries
All binaries come from open source programs.
* binmerge - https://github.com/putnam/binmerge
* espctag - https://sourceforge.net/projects/espctag/
* gbsinfo - https://github.com/mmitch/gbsplay
* gbsplay - https://github.com/mmitch/gbsplay
* info68 - https://sourceforge.net/projects/sc68/
* opustags - https://github.com/fmang/opustags
* sc68 - https://sourceforge.net/projects/sc68/
* vspcplay - https://github.com/raphnet/vspcplay
* vgm2wav - https://github.com/vgmrips/vgmplay
* vgmstream-cli - https://github.com/losnoco/vgmstream
* vgmtag - https://github.com/vgmrips/vgmtools
* zxtune - https://zxtune.bitbucket.io/

--------------------------------------------------------------------------------------------------
## Documentations

### Main menu options
* Video:
	* 0, DVD rip (vob, ISO, or disc)
	* 1, video encoding, full custom options
	* 2, copy stream to mkv with map option
* Video tools:
	* 10, view detailed video file informations
	* 11, add audio stream or subtitle in video file
	* 12, concatenate video files
	* 13, extract stream(s) of video file
	* 14, cut video file
* Audio :
	* 20, CD rip
	* 21, VGM Rip to flac (Linux x86_64 only)
	* 22, CUE Splitter to flac
	* 23, audio to wav
	* 24, audio to flac
	* 25, audio to mp3
	* 26, audio to aac
	* 27, audio to ogg
	* 28, audio to opus
* Audio tools :
	* 30, tag editor
	* 31, view detailed audio file informations
	* 32, generate png image of audio spectrum
	* 33, concatenate audio files 
	* 34, cut audio file

### Option 0 details - DVD rip (vob, ISO, or disc)
* Rip DVD, ISO, or vob
* Fix timestamp and ratio to mkv file (stream copy)
* launch option 1 (optional)
    
### Option 1 details - video encoding, full custom options
* Video
	* Stream copy or encoding
	* Encoding options:
		* crop video
		* rotate video
		* change resolution
		* deinterlace
		* fix frame rate to 24fps
		* codecs:
			* x264: profile, tune, preset & bitrate (crf & cbr)
			* x265: profile, tune, preset & bitrate (crf & cbr)
			* mpeg4 (xvid): bitrate (qscale & cbr)
* Audio
	* Stream copy or encoding
	* Encoding options (apply to all streams):
		* codecs:
			* aac (libfdk_aac): bitrate (vbr & cbr)
			* ogg (libvorbis): bitrate (vbr & cbr)
			* mp3 (libmp3lame): bitrate (vbr & cbr)
			* ac3 (ac3): bitrate (vbr & cbr)
			* opus (libopus): bitrate (vbr)
			* flac (libflac): compression
		* Channels layout 1.0 to 5.1 (depending on the support of the chosen codec)
* Map streams selection

### Option 2 details - copy stream to mkv with map option
* Copy stream in mkv file, with streams selection if source have more than 2 streams.

### Option 21 details - VGM Rip to flac
This function limited to Linux x86_64, it embeds binaries compiled for this platform, so it remains (and will) unstable as a whole.
Encoding automated apply 0db peak normalization and false stereo files detection.

Files supported :
* Amiga/Atari: mod, snd, sndh
* Microsoft Xbox: xwav
* Nintendo GB & GBC: gbs
* Nintendo GameCube: dsp, hps, adp, thp
* Nintendo N64: miniusf
* Nintendo SNES: spc
* Sega Saturn: minissf, ssf
* Sega Dreamcast: dsf, spsd
* Sony Playstation: psf, minipsf, xa, vag
* Sony Playstation 2: psf2, minipsf2, ss2, vag, int, vpk
* PC: mod, voc
* Various machines: vgm, vgz, adx, ads, bfstm, bfwav, rak, tak, mus, dat, eam, at3, raw, bin/cue

### Option 23 details - PCM encoding
* Encoding options:
	* Quality :
		* signed 16-bit little-endian
		* signed 24-bit little-endian
		* signed 32-bit little-endian
		* signed 8-bit
		* unsigned 8-bit
	* Channels layout 1.0 to 5.1
	* False stereo files detection
	* 0db peak normalization

### Option 24 details - FLAC encoding
* Encoding options:
	* Quality :
		* full custom option
		* 24 bit support
	* Channels layout 1.0 to 5.1
	* False stereo files detection
	* 0db peak normalization

### Option 28 details - opus encoding
* Encoding options:
	* bitrate
		* vbr, 64kb to 510kb, via options choice.
		* Also, one mode "accurate auto adapted bitrate from source", particularly useful for processing very large batches of files.
	* Channels layout 1.0 to 5.1
	* False stereo files detection
	* 0db peak normalization

### Option 30 details - tag editor
Options:
* Rename files in "Track - Title" (add track number if not present)
* Change or add tag track, by alphabetic sorting, to use if no file has this tag
* Change or add tag album
* Change or add tag artist
* Change or add tag date
* Change tag title for filename
* Change tag title for untitled
* Remove N character at begin of tag title, but limited to 9 characters.
Limitation:
* max depth directory 1
* asian character not supported (display in degrading mode)

### In script options (variables)
* NVENC = Set number of video encoding in same time, default 2 encoding at time. The countdown starts at 0. So 0 is worth one encoding at a time (0=1;1=2...)

--------------------------------------------------------------------------------------------------
## Issue
* rename bug with mv and CIFS mount: add `cache=loose` in your mount option

--------------------------------------------------------------------------------------------------
## Holy reading
* Video codecs:
	* https://github.com/leandromoreira/digital_video_introduction#how-does-a-video-codec-work
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
* VGM:
	* http://loveemu.hatenablog.com/entry/Conversion_Tools_for_Video_Game_Music
