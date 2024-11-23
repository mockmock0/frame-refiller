Param([string]$i, [double]$t=0.3, [int]$f=0, [bool]$cache=$false, [double]$d=0.33)
chcp 65001 | Out-Null
cls
$dateTime = [String](Get-Date -Format "yyyy_MM_dd_HH_mm_ss.fff")
New-Item -Path $dateTime -ItemType Directory | Out-Null
$inputVideo = $i

$BaseVideoName = (Get-Item $inputVideo).BaseName
$datePath = ".\" + $dateTime + "\test.txt"
$framePath = ".\" + $dateTime + "\frames.txt"
$fr = (ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate $inputVideo)
if ($f -eq 0) {$fr = Invoke-Expression $fr} else {$fr = $f}
if ($t -eq 0) {[int]$minframeItvl = 10000000} else {[int]$minframeItvl = $t * $fr}

# mpdecimate 로그 저장
Write-Output "Calculating Duplicated Frames ..."
ffmpeg -i $inputVideo -vsync cfr -vf "fps=$fr, mpdecimate=max=0:hi=1000:lo=300:frac=$d" -loglevel debug -f null - 2>&1 | Select-String "drop pts" >> $datePath | Out-Null


# 타임스탬프 저장
$FILE = Get-Content $datePath -Raw
$LINES = $FILE -split "`n"
$framecounter = 0
# 중복 프레임 번호 저장
foreach ($LINE in $LINES) {
    if ($LINE -match "pts_time:\s*(\d+\.\d+)") {
        # $timestamp = [math]::Round([double]$matches[1] * $fr)
        $timestamp = ([double]$matches[1]).ToString("F5") + "*" + $fr
        $PTS = Invoke-Expression $timestamp
        $PTS = [math]::Round($PTS) + 1
        Write-Output "$PTS" >> $framePath | Out-Null
        $framecounter++
    }
}
if ($framecounter -eq 0) {
    Write-Output "No Duplicated Frame Detected"
    ffmpeg -r $fr -i $inputVideo -vcodec hevc_nvenc -tune:v hq -preset p7 -qp 15 -acodec copy $BaseVideoName"_final.mp4"
    Remove-Item .\$dateTime -Recurse
    Exit
}

Set-Location "$dateTime"
mkdir "input" | Out-Null
mkdir "interpolate" | Out-Null
mkdir "output" | Out-Null
$inputFrame = ".\" + $dateTime + "\input\"
$OutputFrame = ".\" + $dateTime + "\interpolate\"
$finalOutputFrame = ".\" + $dateTime + "\output\"
Set-Location ..

# 프레임 추출 작업
ffmpeg -i $inputVideo -r $fr -q:v 0 $inputFrame%08d.jpg | Out-null
$fileCnt = Get-ChildItem $inputFrame | Measure-Object
# 전체 프레임
[int[]]$frames = Get-Content $framePath
$finalFrames = New-Object System.Collections.Generic.List[int]
foreach($items in $frames) { $finalFrames.add($items) }

$firstFrame = 0
$cnter = 1

#중복 프레임 중 특정 수 이상 프레임이 연속되는 경우 무시하기
for($idx = 0; $idx -lt $frames.count; $idx++) {
    $currentFrame = $frames[$idx]
    $nextFrame = $frames[$idx + 1]
    if (($nextFrame - $currentFrame) -eq 1) {
        $cnter++
    } else {

        if ($cnter -gt $minframeItvl) {
            $firstFrame = $currentFrame - $cnter
            for($j = $firstFrame; $j -lt $currentFrame; $j++) {
                $finalFrames.Remove($j) | Out-Null
            }
            
            $cnter = 1
        }
    }
}

Write-Output "Removing Duplicated Frames ..."
# 중복 프레임 삭제 작업
foreach($LINE in $finalFrames) {
    $numFormat = $LINE.ToString("00000000")
    if (($LINE -ne 1)) {
        if (($LINE -ne ($fileCnt.count))) {
            Remove-Item $inputFrame$numFormat.jpg
        }
    }
}
$counter = 1
$isStart = 1
$pageCnt = 0
$tmpNumber = 0
[int[]]$dupFrameOrigin = Get-Content -Path $framePath
Clear-Host

for (($index = 0); $index -lt $dupFrameOrigin.count; $index++) {
    $pageCnt++
    $startFrameNums = $tmpNumber
    $targetFrameNums = $dupFrameOrigin[$index]
    $endFrameNums = $dupFrameOrigin[$index] + 1
    $startFrameName = $startFrameNums.ToString("00000000")
    $targetFrameNames = $targetFrameNums.ToString("00000000")
    $endFrameName = $endFrameNums.ToString("00000000")
    $intervals = $endFrameNums - $startFrameNums + 1
    $intervalStr = $intervals.ToString("00000000")
    if (($dupFrameOrigin[$index + 1] - $dupFrameOrigin[$index]) -ne 1) {
        # 프레임 그룹화됨
        if ($isStart -eq 1) {
            Clear-Host
            Write-Output "Interpolating Frames ..."
            $LOGTotal = $pageCnt / $frames.count * 100
	    $LOGTotal = [Math]::Round($LOGTotal, 3)
	    $strTmp = [string]$LOGTotal + "`% (Cur: " + $pageCnt + ", Dup: " + $frames.count + ")"
            $LOGCnt = [string]($dupFrameOrigin[$index]) + " / " + [string]$fileCnt.count
            Write-Output $strTmp
            Write-Output $LOGCnt
            # 첫번째니? > 전후 프레임 이동 > interpolate > 다시 옮기기
            if ($dupFrameOrigin[$index] -eq 1) {
                # 1번 프레임부터 중복이면 아무것도 안함
                Write-Output ""
            } else {
                $startFrameNums = $dupFrameOrigin[$index] - 1
                $startFrameName = $startFrameNums.ToString("00000000")
                Copy-Item -Path $inputFrame$startFrameName".jpg" -Destination $OutputFrame$startFrameName".jpg" -Force
                Copy-Item -Path $inputFrame$endFrameName".jpg" -Destination $OutputFrame$endFrameName".jpg" -Force
                rife-ncnn-vulkan -m "rife-v4.24" -0 $OutputFrame$startFrameName".jpg" -1 $OutputFrame$endFrameName".jpg" -n 3 -o $finalOutputFrame$targetFrameNames".jpg"
                Get-ChildItem -Path $finalOutputFrame -Recurse -File | Copy-Item -Destination $inputFrame -Force
            }
        }
        else {
            Clear-Host
            Write-Output "Interpolating Frames ..."
            $LOGTotal = $pageCnt / $frames.count * 100
	    $LOGTotal = [Math]::Round($LOGTotal, 3)
	    $strTmp = [string]$LOGTotal + "`% (Cur: " + $pageCnt + ", Dup: " + $frames.count + ")"
            $LOGCnt = [string]($dupFrameOrigin[$index]) + " / " + [string]$fileCnt.count
            Write-Output $strTmp
            Write-Output $LOGCnt
            #첫번쨰 아니니? > 후 프레임 이동 + 첫 프레임 tmp로 받아와 이동
            Copy-Item -Path $inputFrame$startFrameName".jpg" -Destination $OutputFrame"00000001.jpg" -Force
            Copy-Item -Path $inputFrame$endFrameName".jpg" -Destination $OutputFrame$intervalStr".jpg" -Force
            rife-ncnn-vulkan -m "rife-v4.24" -i $OutputFrame -n $intervals -o $finalOutputFrame -f %09d.jpg
            $counter = $tmpNumber
            Get-ChildItem -Path $finalOutputFrame -Filter *.jpg | Sort-Object Name | ForEach-Object {
                $newName = "{0:D8}" -f $counter + ".jpg"
                Rename-Item $_.FullName $newName
                $counter++
            }
            Get-ChildItem -Path $finalOutputFrame -Recurse -File | Copy-Item -Destination $inputFrame -Force
            $counter = 1
            $isStart = 1
        }
        Remove-Item -Path $OutputFrame"*" -Recurse
        Remove-Item -Path $finalOutputFrame"*" -Recurse
    } else {
        if ($isStart -eq 1) {
            # 첫번째니? > # tmp 첫 프레임
            $tmpNumber = $dupFrameOrigin[$index] - 1
            $isStart = 0
            if ($dupFrameOrigin[$index] -eq 1) {
                # 1번 프레임부터 중복이면
                $tmpNumber = $dupFrameOrigin[$index]
            }
        }
    }
}

# 오디오 추출 작업
$succeedcode = 1
ffmpeg -y -i $inputVideo -vn -acodec aac -b:a 256k $BaseVideoName".aac"; if (-not $?) {$succeedcode = 0}

# muxing
if ($succeedcode -eq 1) {
	ffmpeg -r $fr -i $inputFrame%08d.jpg -i $BaseVideoName".aac" -vcodec hevc_nvenc -tune:v hq -preset p7 -qp 15 -acodec copy $BaseVideoName"_final.mp4"
	# 잔여파일/폴더 제거
	Remove-Item $BaseVideoName".aac"
} else {
	ffmpeg -r $fr -i $inputFrame%08d.jpg -vcodec hevc_nvenc -tune:v hq -preset p7 -qp 15 $BaseVideoName"_final.mp4"
}

if ($cache -eq $false) {Remove-Item .\$dateTime -Recurse}
