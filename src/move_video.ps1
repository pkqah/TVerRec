###################################################################################
#  TVerRec : TVerビデオダウンローダ
#
#		動画移動処理スクリプト
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

#======================================================================
#保存先ディレクトリの存在確認
if (Test-Path $downloadBaseDir -PathType Container) {}
else { Write-Error 'ビデオ保存先フォルダにアクセスできません。終了します。' -ForegroundColor Green ; exit 1 }
if (Test-Path $saveBaseDir -PathType Container) {}
else { Write-Error 'ビデオ移動先フォルダにアクセスできません。終了します。' -ForegroundColor Green ; exit 1 }

#======================================================================
#1/2 移動先フォルダを起点として、配下のフォルダを取得
Write-Host '==========================================================================='
Write-Host 'ビデオファイルを移動しています'
Write-Host '==========================================================================='
Write-Progress `
	-Id 1 `
	-Activity '処理 1/2' `
	-PercentComplete $($( 1 / 4 ) * 100) `
	-Status 'フォルダ一覧を作成中'

$moveToPaths = Get-ChildItem $saveBaseDir -Recurse | `
		Where-Object { $_.PSisContainer } | `
		Sort-Object 

$moveToPathNum = 0						#移動先パス番号
if ($moveToPaths -is [array]) {
	$moveToPathTotal = $moveToPaths.Length	#移動先パス合計数
} else { $moveToPathTotal = 1 }

Write-Progress `
	-Id 1 `
	-Activity '処理 1/2' `
	-PercentComplete $($( 1 / 2 ) * 100) `
	-Status 'ファイルを移動中'

foreach ($moveToPath in $moveToPaths) {
	Write-Host '----------------------------------------------------------------------'
	Write-Host "$moveToPath を処理中"
	$moveToPathNum = $moveToPathNum + 1
	Write-Progress `
		-Id 2 `
		-ParentId 1 `
		-Activity "$($moveToPathNum)/$($moveToPathTotal)" `
		-PercentComplete $($( $moveToPathNum / $moveToPathTotal ) * 100) `
		-Status "$($moveToPath)"

	$targetFolderName = Split-Path -Leaf $moveToPath
	#同名フォルダが存在する場合は配下のファイルを移動
	$moveFromPath = $(Join-Path $downloadBaseDir $targetFolderName)
	if (Test-Path $moveFromPath) {
		$moveFromPath = $moveFromPath + '\*.mp4'
		Write-Host "  └「$($moveFromPath)」を移動します"
		try {
			Move-Item $moveFromPath -Destination $moveToPath -Force
		} catch {}
	}
}

#======================================================================
#2/2 空フォルダと隠しファイルしか入っていないフォルダを一気に削除
Write-Host '----------------------------------------------------------------------'
Write-Host '空フォルダ と 隠しファイルしか入っていないフォルダを削除します'
Write-Host '----------------------------------------------------------------------'
Write-Progress `
	-Id 1 `
	-Activity '処理 2/2' `
	-PercentComplete $($( 2 / 2 ) * 100) `
	-Status '空フォルダを削除'

$allSubDirs = @((Get-ChildItem -Path $downloadBaseDir -Recurse).Where({ $_.PSIsContainer })).FullName | `
		Sort-Object -Descending

$subDirNum = 0						#サブディレクトリの番号
if ($allSubDirs -is [array]) {
	$subDirTotal = $allSubDirs.Length	#サブディレクトリの合計数
} else { $subDirTotal = 1 }

foreach ($subDir in $allSubDirs) {
	$subDirNum = $subDirNum + 1
	Write-Progress `
		-Id 2 `
		-ParentId 1 `
		-Activity "$($subDirNum)/$($subDirTotal)" `
		-PercentComplete $($( $subDirNum / $subDirTotal ) * 100) `
		-Status "$($subDir)"

	Write-Host '----------------------------------------------------------------------'
	Write-Host "$($subDir)を処理中"
	if (@((Get-ChildItem -LiteralPath $subDir -Recurse).Where({ ! $_.PSIsContainer })).Count -eq 0) {
		try {
			Write-Host "  └「$($subDir)」を削除します"
			Remove-Item `
				-LiteralPath $subDir `
				-Recurse `
				-Force `
				-ErrorAction SilentlyContinue
		} catch { Write-Host "空フォルダの削除に失敗しました: $subDir" -ForegroundColor Green }
	}
}

