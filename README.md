## frame-refiller
영상의 중복 프레임을 검출한 뒤 프레임 보간하기
<br>
<br>
## 유의사항
위 작업물은 게임 영상과 같은 약간의 스터터링을 보간하는 목적으로 만들어졌습니다.
<br>
그 외의 작업에는 적합하지 않을 수 있습니다.
<br>

## 필수 라이브러리
* [FFmpeg](https://www.gyan.dev/ffmpeg/builds/) (환경변수 설정 권장)
* [RIFE-ncnn-vulkan](https://github.com/TNTwise/rife-ncnn-vulkan) (환경변수 설정 권장)
<br>

## 사용법
1. .ps1 파일을 동영상 경로로 이동
2. 동영상 경로의 탐색기 주소창에 cmd 입력
3. 아래 명령문을 실행한다.
```
powershell.exe -File "frame-refiller.ps1" -i <File-Name> -t <Threshould> -f <Output-FrameRate> -cache <작업물 여부>
```
```
-i <string> 원본 비디오 파일
-t <double> 중복 프레임의 차지 비중
-f <double> 프레임 추출 작업을 위한 프레임 속도
-cache <bool> 프로세스 작업물 삭제 여부. false 시 삭제 
```

사용 예시
```
powershell.exe -File "frame-refiller.ps1" -i "input.mp4" -t 0.1 -f  -cache false
```
