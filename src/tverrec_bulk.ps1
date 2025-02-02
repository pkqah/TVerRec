###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		一括ダウンロード処理スクリプト
#
#	Copyright (c) 2022 dongaba
#
#	Licensed under the Apache License, Version 2.0 (the "License");
#	you may not use this file except in compliance with the License.
#	You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" BASIS,
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#	See the License for the specific language governing permissions and
#	limitations under the License.
#
###################################################################################
using namespace System.Text.RegularExpressions

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Set-StrictMode -Version Latest
try {
	if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
		$currentDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
	} else {
		$currentDir = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
		if (!$currentDir) { $currentDir = '.' }
	}
	Set-Location $currentDir
	$confDir = $(Join-Path $currentDir '..\conf')
	$sysFile = $(Join-Path $confDir 'system_setting.conf')
	$confFile = $(Join-Path $confDir 'user_setting.conf')
	$devDir = $(Join-Path $currentDir '..\dev')
	$devConfFile = $(Join-Path $devDir 'dev_setting.conf')
	$devFunctionFile = $(Join-Path $devDir 'dev_funcitons.ps1')

	#----------------------------------------------------------------------
	#外部設定ファイル読み込み
	Get-Content $sysFile -Encoding UTF8 | `
			Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression
	Get-Content $confFile -Encoding UTF8 | `
			Where-Object { $_ -notmatch '^\s*$' } | `
			Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
			Invoke-Expression

	#----------------------------------------------------------------------
	#開発環境用に設定上書き
	if (Test-Path $devConfFile) {
		Get-Content $devConfFile -Encoding UTF8 | `
				Where-Object { $_ -notmatch '^\s*$' } | `
				Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
				Invoke-Expression
	}

	#----------------------------------------------------------------------
	#外部関数ファイルの読み込み
	if ($PSVersionTable.PSEdition -eq 'Desktop') {
		. '.\common_functions_5.ps1'
		. '.\tver_functions_5.ps1'
		if (Test-Path $devFunctionFile) { 
			Write-Host '========================================================' -ForegroundColor Green
			Write-Host '  PowerShell Coreではありません                         ' -ForegroundColor Green
			Write-Host '========================================================' -ForegroundColor Green
			exit 1
		}
	} else {
		. '.\common_functions.ps1'
		. '.\tver_functions.ps1'
		if (Test-Path $devFunctionFile) { 
			. $devFunctionFile 
			Write-Host '========================================================' -ForegroundColor Green
			Write-Host '  開発ファイルを読み込みました                          ' -ForegroundColor Green
			Write-Host '========================================================' -ForegroundColor Green
		}
	}
} catch { Write-Host '設定ファイルの読み込みに失敗しました' -ForegroundColor Green ; exit 1 }

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Write-Host ''
Write-Host '===========================================================================' -ForegroundColor Cyan
Write-Host '---------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '  tverrec : TVerビデオダウンローダ                                         ' -ForegroundColor Cyan
Write-Host "                      一括ダウンロード版 version. $appVersion              " -ForegroundColor Cyan
Write-Host '---------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '===========================================================================' -ForegroundColor Cyan
Write-Host ''

#----------------------------------------------------------------------
#動作環境チェック
checkLatestYtdlp					#yt-dlpの最新化チェック
checkLatestFfmpeg					#ffmpegの最新化チェック
checkRequiredFile					#設定で指定したファイル・フォルダの存在チェック
#checkGeoIP							#日本のIPアドレスでないと接続不可のためIPアドレスをチェック

$keywordNames = loadKeywordList			#ダウンロード対象ジャンルリストの読み込み

$timer = [System.Diagnostics.Stopwatch]::StartNew()
$keywordNum = 0						#キーワードの番号
if ($keywordNames -is [array]) {
	$keywordTotal = $keywordNames.Length	#トータルキーワード数
} else { $keywordTotal = 1 }

#======================================================================
#個々のジャンルページチェックここから
foreach ($keywordName in $keywordNames) {

	#ジャンルページチェックタイトルの表示
	Write-Host ''
	Write-Host '==========================================================================='
	Write-Host "【 $keywordName 】 のダウンロードを開始します。"
	Write-Host '==========================================================================='

	$keywordNum = $keywordNum + 1		#キーワード数のインクリメント

	if ($timer.Elapsed.TotalMilliseconds -ge 1000) {
		Write-Progress `
			-Id 1 `
			-Activity "$($keywordNum)/$($keywordTotal)" `
			-PercentComplete $($( $keywordNum / $keywordTotal ) * 100) `
			-Status 'キーワードの動画を取得中'
		$timer.Reset(); $timer.Start()
	}

	$videoLinks = getVideoLinksFromKeyword ($keywordName)
	$keywordName = $keywordName.Replace('https://tver.jp/', '').Replace('http://tver.jp/', '')

	$videoNum = 0						#ジャンル内の処理中のビデオの番号
	if ($videoLinks -is [array]) {
		$videoTotal = $videoLinks.Length	#ジャンル内のトータルビデオ数
	} else { $videoTotal = 1 }

	#----------------------------------------------------------------------
	#個々のビデオダウンロードここから
	foreach ($videoID in $videoLinks) {

		#いろいろ初期化
		$videoNum = $videoNum + 1		#ジャンル内のビデオ番号のインクリメント
		$videoPageURL = ''

		if ($timer.Elapsed.TotalMilliseconds -ge 1000) {
			Write-Progress `
				-Id 2 `
				-ParentId 1 `
				-Activity "$($videoNum)/$($videoTotal)" `
				-PercentComplete $($( $videoNum / $videoTotal ) * 100) `
				-Status "$($keywordName)"
			$timer.Reset(); $timer.Start()
		}

		Write-Host '----------------------------------------------------------------------'
		Write-Host "[ $keywordName - $videoNum / $videoTotal ] をダウンロードします。 ($(getTimeStamp))"
		Write-Host '----------------------------------------------------------------------'

		#保存先ディレクトリの存在確認
		if (Test-Path $downloadBaseDir -PathType Container) {}
		else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します' -ForegroundColor Green ; exit 1 }

		#yt-dlpプロセスの確認と、yt-dlpのプロセス数が多い場合の待機
		waitTillYtdlpProcessGetFewer $parallelDownloadFileNum

		$videoPageURL = 'https://tver.jp' + $videoID
		Write-Host $videoPageURL

		downloadTVerVideo $keywordName				#TVerビデオダウンロードのメイン処理

		Start-Sleep -Seconds 1
	}
	#----------------------------------------------------------------------

}
#======================================================================

#yt-dlpのプロセスが終わるまで待機
waitTillYtdlpProcessIsZero ($isWin)

Write-Host '---------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '処理を終了しました。                                                       ' -ForegroundColor Cyan
Write-Host '---------------------------------------------------------------------------' -ForegroundColor Cyan
