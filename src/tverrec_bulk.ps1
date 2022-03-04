﻿###################################################################################
#  tverrec : TVerビデオダウンローダ
#
#		一括ダウンロード処理スクリプト
#
#	Copyright (c) 2021 dongaba
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
using namespace Microsoft.VisualBasic
using namespace System.Text.RegularExpressions

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#環境設定
#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#Set-StrictMode -Off
Set-StrictMode -Version Latest
$currentDir = Split-Path $MyInvocation.MyCommand.Path
Set-Location $currentDir
$configDir = $(Join-Path $currentDir '..\config')
$sysFile = $(Join-Path $configDir 'system_setting.ini')
$iniFile = $(Join-Path $configDir 'user_setting.ini')

#----------------------------------------------------------------------
#外部設定ファイル読み込み
Get-Content $sysFile | Where-Object { $_ -notmatch '^\s*$' } | `
		Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
		Invoke-Expression
Get-Content $iniFile | Where-Object { $_ -notmatch '^\s*$' } | `
		Where-Object { !($_.TrimStart().StartsWith('^\s*;#')) } | `
		Invoke-Expression

#----------------------------------------------------------------------
#必要モジュールの読み込み
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Windows.Forms

#----------------------------------------------------------------------
#開発環境用に設定上書き
if ((Test-Path 'R:\' -PathType Container) ) {
	$VerbosePreference = 'Continue'						#詳細メッセージ
	$DebugPreference = 'Continue'						#デバッグメッセージ
}

#----------------------------------------------------------------------
#外部関数ファイルの読み込み
. '.\common_functions.ps1'
. '.\tver_functions.ps1'

#━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#メイン処理
Write-Host ''
Write-Host '==================================================================================' -ForegroundColor Cyan
Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '  tverrec : TVerビデオダウンローダ                                                ' -ForegroundColor Cyan
Write-Host "                      一括ダウンロード版 version. $appVersion                     " -ForegroundColor Cyan
Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '==================================================================================' -ForegroundColor Cyan
Write-Host ''

#----------------------------------------------------------------------
#動作環境チェック
. '.\update_ffmpeg.ps1'				#ffmpegの最新化チェック
. '.\update_yt-dlp.ps1'				#yt-dlpの最新化チェック
checkRequiredFile					#設定で指定したファイル・フォルダの存在チェック
#checkGeoIP							#日本のIPアドレスでないと接続不可のためIPアドレスをチェック

#ダウンロード対象ジャンルリストの読み込み
$genres = (Get-Content $keywordFile -Encoding UTF8 | `
			Where-Object { !($_ -match '^\s*$') } | `
			Where-Object { !($_ -match '^#.*$') } | `
			Where-Object { !($_ -match '^;.*$') } ) `
	-as [string[]]

#ダウンロード対象外番組リストの読み込み
$ignoreTitles = (Get-Content $ignoreFile -Encoding UTF8 | `
			Where-Object { !($_ -match '^\s*$') } | `
			Where-Object { !($_ -match '^;.*$') } ) `
	-as [string[]]

#----------------------------------------------------------------------
#個々のジャンルページチェックここから
foreach ($genre in $genres) {

	#ジャンルページチェックタイトルの表示
	Write-Host ''
	Write-Host '=================================================================================='
	Write-Host "【 $genre 】 のダウンロードを開始します。"
	Write-Host '=================================================================================='

	#ジャンルページからビデオページのLinkを取得
	$genreLink = 'https://tver.jp/' + $genre
	Write-Host $genreLink
	$genrePage = Invoke-WebRequest $genreLink
	$ErrorActionPreference = 'silentlycontinue'
	$videoLinks = $genrePage.Links | Where-Object href -Like '*corner*'  | Select-Object href
	$videoLinks += $genrePage.Links | Where-Object href -Like '*feature*'  | Select-Object href
	$videoLinks += $genrePage.Links | Where-Object href -Like '*lp*'  | Select-Object href
	$ErrorActionPreference = 'continue'

	#saveGenrePage						#デバッグ用ジャンルページの保存

	#----------------------------------------------------------------------
	#個々のビデオダウンロードここから
	$videoNum = 0						#ジャンル内の処理中のビデオの番号
	$videoTotal = $videoLinks.Length	#ジャンル内のトータルビデオ数
	foreach ($videoLink in $videoLinks) {

		#いろいろ初期化
		$videoNum = $videoNum + 1		#ジャンル内のビデオ番号のインクリメント
		$videoID = '' ; $videoPage = '' ; $videoName = '' ; $videoPath = '' ;
		$broadcastDate = '' ; $title = '' ; $subtitle = '' ; $media = '' ; $description = '' ;
		$videoInfo = $null
		#		$tverApiBaseURL = '' ; $tverApiTokenLink = '' ; $token = '' ; $teverApiVideoURL = '' ; 
		$ignore = $false
		$videoLists = $null ; $newVideo = $null

		#保存先ディレクトリの存在確認
		if (Test-Path $downloadBasePath -PathType Container) {} else { Write-Error 'ビデオ保存先フォルダが存在しません。終了します。' ; exit }

		Write-Host '----------------------------------------------------------------------'
		Write-Host "[ $genre - $videoNum / $videoTotal ] をダウンロードします。 ( $(getTimeStamp) )"
		Write-Host '----------------------------------------------------------------------'

		#yt-dlpプロセスの確認と、yt-dlpのプロセス数が多い場合の待機
		getYtdlpProcessList $parallelDownloadNum

		$videoID = $videoLink.href
		$videoPage = 'https://tver.jp' + $videoID

		#TVerの番組説明の場合はビデオがないのでスキップ
		if ($videoPage -match '/episode/') {
			Write-Host 'ビデオではなくオンエア情報のようです。スキップします。' -ForegroundColor DarkGray
			continue			#次のビデオへ
		}

		#ダウンロードリストの読み込み
		try {
			$listMatch = Import-Csv $listFile -Encoding UTF8 | Where-Object { $_.videoPage -eq $videoPage } 
		} catch {
			Write-Host 'ダウンロードリストを読み書きできなかったのでスキップしました。'
			continue			#次回再度トライするためダウンロードリストに追加せずに次のビデオへ
		}

		#すでにダウンロードリストに存在する場合はスキップ
		if ( $null -ne $listMatch ) {
			Write-Host '過去に処理したビデオです。スキップします。' -ForegroundColor DarkGray
			continue			#次のビデオへ
		}

		#TVerのAPIを叩いてビデオ情報取得
		try {
			$videoInfo = callTVerAPI ($videoID)
		} catch {
			Write-Host 'TVerから情報を取得できませんでした。スキップします。' -ForegroundColor DarkGray
			continue			#次回再度トライするためダウンロードリストに追加せずに次のビデオへ
		}

		#取得したビデオ情報を整形
		$broadcastDate = getBroadcastDate ($videoInfo)
		$title = $(conv2Narrow ($videoInfo.title).Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').Replace('?', '？').Replace('!', '！')).trim()
		$subtitle = $(conv2Narrow ($videoInfo.subtitle).Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '').Replace('?', '？').Replace('!', '！')).trim()
		$media = $(conv2Narrow ($videoInfo.media).Replace('&amp;', '&').Replace('"', '').Replace('“', '').Replace('”', '')).trim()
		$description = $(conv2Narrow ($videoInfo.note.text).Replace('&amp;', '&')).trim()

		#ビデオファイル情報をセット
		$videoName = setVideoName $title $subtitle $broadcastDate		#保存ファイル名を設定
		$savePath = $(Join-Path $downloadBasePath (removeInvalidFileNameChars $title))
		$videoPath = $(Join-Path $savePath $videoName)

		#ビデオ情報のコンソール出力
		writeVideoInfo $videoName $broadcastDate $media $description 
		writeVideoDebugInfo $videoPage $genre $title $subtitle $videoPath $(getTimeStamp)

		#ビデオタイトルが取得できなかった場合はスキップ次のビデオへ
		if ($videoName -eq '.mp4') {
			Write-Host 'ビデオタイトルを特定できませんでした。スキップします。' -ForegroundColor DarkGray
			continue			#次回再度ダウンロードをトライするためダウンロードリストに追加せずに次のビデオへ
		}

		#ダウンロード済みの場合はスキップフラグを立ててダウンロードリストに書き込み処理へ
		if (Test-Path $videoPath) {
			$ignore = $true
			Write-Host 'すでにダウンロード済みのビデオです。スキップします。' -ForegroundColor DarkGray
		} else {
			#無視リストに入っている番組の場合はスキップフラグを立ててダウンロードリストに書き込み処理へ
			foreach ($ignoreTitle in $ignoreTitles) {
				if ($(conv2Narrow $title) -eq $(conv2Narrow $ignoreTitle)) {
					$ignore = $true
					Write-Host '無視リストに入っているビデオです。スキップします。' -ForegroundColor DarkGray
					break
				} 
			}
		}

		#スキップフラグが立っているかチェック
		if ($ignore -ne $true) {
			#ダウンロードリストに行追加
			Write-Verbose 'ダウンロードするファイルをダウンロードリストに追加します。'
			$newVideo = [pscustomobject]@{ 
				videoPage      = $videoPage ;
				genre          = $genre ;
				title          = $title ;
				subtitle       = $subtitle ;
				media          = $media ;
				broadcastDate  = $broadcastDate ;
				downloadDate   = $(getTimeStamp) ;
				videoName      = $videoName ;
				videoPath      = $videoPath ;
				videoValidated = '0' ;
			}
		} else {
			#ダウンロードリストに行追加
			Write-Verbose 'スキップしたファイルをダウンロードリストに追加します。'
			$newVideo = [pscustomobject]@{ 
				videoPage      = $videoPage ;
				genre          = $genre ;
				title          = $title ;
				subtitle       = $subtitle ;
				media          = $media ;
				broadcastDate  = $broadcastDate ;
				downloadDate   = $(getTimeStamp) ;
				videoName      = '-- SKIPPED --' ;
				videoPath      = $videoPath ;
				videoValidated = '0' ;
			}
		}

		try {
			#ダウンロードリストCSV書き出し
			Write-Debug 'ダウンロードリストを読み込みます。'
			$videoLists = Import-Csv $listFile -Encoding UTF8
			$newVideo | Export-Csv $listFile -NoTypeInformation -Encoding UTF8 -Append
			Write-Debug 'ダウンロードリストを書き込みました。'
		} catch {
			Write-Host 'ダウンロードリストを読み書きできなかったのでスキップしました。'
			continue			#次回再度トライするためダウンロードリストに追加せずに次のビデオへ
		}

		#無視リストに入っていなければffmpeg起動
		if ($ignore -eq $true ) { 
			continue		#無視リストに入っているビデオは飛ばして次のファイルへ
		} else {

			#保存作ディレクトリがなければ作成
			if (-Not (Test-Path $savePath -PathType Container)) {
				$null = New-Item -ItemType directory -Path $savePath
			}

			#yt-dlp起動
			startYtdlp $videoPath $videoPage $ytdlpPath

			Start-Sleep -Seconds 10			#10秒待機
		}

	}
	#個々のビデオダウンロードここまで
	#----------------------------------------------------------------------

}
#個々のジャンルページチェックここまで
#----------------------------------------------------------------------

Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
Write-Host '  処理を終了しました。                                                            ' -ForegroundColor Cyan
Write-Host '----------------------------------------------------------------------------------' -ForegroundColor Cyan
