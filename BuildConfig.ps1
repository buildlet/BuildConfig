<###############################################################################
 The MIT License (MIT)

 Copyright (c) 2018-2019 Daiki Sakamoto

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
################################################################################>

<#

.SYNOPSIS
Visual Studio ソリューションの操作・設定をサポートするツールを提供します。

.DESCRIPTION
このファイルはソリューション ディレクトリのひとつ上の階層に配置してください。

.INPUTS
なし
このスクリプトはパイプラインからの入力を受け取りません。

.OUTPUTS
なし
このスクリプトのパイプラインへの出力はありません。

.EXAMPLE
BuildConfig.ps1 -New -SolutionName Solution1
新しいソリューション Solution1 のためのソリューション ディレクトリを作成します。

.EXAMPLE
BuildConfig.ps1 -Clean -SolutionName Solution1
ソリューション Solution1 をクリーニングします。

.EXAMPLE
PowerShell.exe -File $(SolutionDir)..\BuildConfig.ps1 -PostBuildEvent -SolutionName $(SolutionName) -ProjectName $(ProjectName) -ConfigurationName $(ConfigurationName) -TargetFileNames $(TargetFileName)
ビルド後イベント (PostBuildEvent) のコマンドラインで、出力ファイルに $(TargetFileName) を指定します。

.EXAMPLE
PowerShell.exe -File $(SolutionDir)..\BuildConfig.ps1 -PostBuildEvent -SolutionName $(SolutionName) -ProjectName $(ProjectName) -ConfigurationName $(ConfigurationName) -TargetFileNames $(TargetFileName),$(TargetName).xml
ビルド後イベント (PostBuildEvent) のコマンドラインで、出力ファイルに $(TargetFileName) および $(TargetName).xml を指定します。

.EXAMPLE
PowerShell.exe -File $(SolutionDir)..\BuildConfig.ps1 -PreBuildEvent -SolutionName $(SolutionName) -ProjectName $(ProjectName) -ConfigurationName $(ConfigurationName) -ReferenceFileNames redist1.dll,redist2.dll,redist3.dll
ビルド前イベント (PreBuildEvent) のコマンドラインで、参照ファイルに redist1.dll, redist2.dll および redist3.dll を指定します。

.EXAMPLE
PowerShell.exe -File $(SolutionDir)..\BuildConfig.ps1 -PowerShellModule -PostBuildEvent -SolutionName PowerShellUtilities -ProjectName PowerShellUtilitiesModule -PowerShellModuleName Foo.PowerShell.Utilities
PowerShell モジュールのビルド後イベント (PostBuildEvent) のコマンドラインを指定します。

.LINK
https://github.com/buildlet/BuildConfig

#>

# CmdletBinding
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'high')]

# Parameters
Param(

    [Parameter(ParameterSetName = 'Version', Position = 0)]
    [switch]
    # このスクリプトのバージョン情報を表示します。
    $Version,

    [Parameter(ParameterSetName = 'PowerShellModule', Mandatory = $true, Position = 0)]
    [switch]
    # PowerShell モジュールを指定します。
    # (ビルド後イベント: PostBuildEvent のみがサポートされます。)
    # プロジェクト ディレクトリにある *.psd1 および *psm1 ファイルを、ソリューションの出力ディレクトリ
    # ($SolutionName\bin\$ConfigurationName\) にコピーします。
    # また、プロジェクト ディレクトリに *.Tests.ps1 ファイルがあると、$PowerShellModuleName で指定した
    # PowerShell モジュールを、ソリューションの出力ディレクトリからプロジェクトの出力ディレクトリ
    # ($SolutionName\$ProjectName\bin\$ConfigurationName\) にコピーします。
    $PowerShellModule,

    [Parameter(ParameterSetName = 'New', Mandatory = $true, Position = 0)]
    [switch]
    # 新しいソリューション ディレクトリを作成します。
    # 指定された名前のソリューション ディレクトリを作成し、その直下に次のディレクトリを作成します。
    #   - .images
    #   - Licenses   (for 'LICENSE')
    #   - Packages   (for NuGet Packages)
    #   - Properties (for 'AssemblyInfoBase.cs')
    #   - Readme
    #   - Resources
    #   - TestData
    #   - TestResults (for Test Results of MSTest)
    # Licenses ディレクトリに LICENSE ファイルを作成します。
    # Properties ディレクトリに AssemblyInfoBase ファイル ('AssemblyInfoBase.cs') を作成します。
    $New,

    [Parameter(ParameterSetName = 'Clean', Mandatory = $true, Position = 0)]
    [switch]
    # ソリューション ディレクトリをクリーニングします。
    $Clean,

    [Parameter(ParameterSetName = 'PreBuildEvent', Mandatory = $true, Position = 0)]
    [switch]
    # ビルド前イベント (PreBuildEvent) のコマンドラインを指定します。
    $PreBuildEvent,

    [Parameter(ParameterSetName = 'PostBuildEvent', Mandatory = $true, Position = 0)]
    [Parameter(ParameterSetName = 'PowerShellModule', Mandatory = $true, Position = 1)]
    [switch]
    # ビルド後イベント (PostBuildEvent) のコマンドラインを指定します。
    $PostBuildEvent,

    [Parameter(ParameterSetName = 'New', Mandatory = $true, Position = 1, HelpMessage = 'ソリューション名を指定します。')]
    [Parameter(ParameterSetName = 'Clean', Mandatory = $true, Position = 1, HelpMessage = 'ソリューション名を指定します。')]
    [Parameter(ParameterSetName = 'PreBuildEvent', Mandatory = $true, Position = 1, HelpMessage = 'ソリューション名を指定します。')]
    [Parameter(ParameterSetName = 'PostBuildEvent', Mandatory = $true, Position = 1, HelpMessage = 'ソリューション名を指定します。')]
    [Parameter(ParameterSetName = 'PowerShellModule', Mandatory = $true, Position = 2, HelpMessage = 'ソリューション名を指定します。')]
    [string]
    # ソリューション名を指定します。
    $SolutionName,

    [Parameter(ParameterSetName = 'New', HelpMessage = 'ライセンスの種類を指定します。')]
    [ValidateSet('MIT')]
    [string]
    # ライセンスの種類を指定します。
    # 既定では MIT License が指定されます。
    $License = 'MIT',

    [Parameter(ParameterSetName = 'PreBuildEvent', Mandatory = $true, Position = 2, HelpMessage = 'プロジェクト名を指定します。')]
    [Parameter(ParameterSetName = 'PostBuildEvent', Mandatory = $true, Position = 2, HelpMessage = 'プロジェクト名を指定します。')]
    [Parameter(ParameterSetName = 'PowerShellModule', Mandatory = $true, Position = 3, HelpMessage = 'プロジェクト名を指定します。')]
    [string]
    # プロジェクト名を指定します。
    $ProjectName,

    [Parameter(ParameterSetName = 'PostBuildEvent', HelpMessage = 'PowerShell モジュールの名前を指定します。')]
    [Parameter(ParameterSetName = 'PowerShellModule', Mandatory = $true, Position = 4, HelpMessage = 'PowerShell モジュールの名前を指定します。')]
    [string]
    # PowerShell モジュールの名前を指定します。
    $PowerShellModuleName,

    [Parameter(ParameterSetName = 'PreBuildEvent', HelpMessage = 'ソリューション構成 (Debug または Release) を指定します。')]
    [Parameter(ParameterSetName = 'PostBuildEvent', HelpMessage = 'ソリューション構成 (Debug または Release) を指定します。')]
    [ValidateSet('Debug', 'Release')]
    [string]
    # ソリューション構成 (Debug または Release) を指定します。
    # このパラメーターを省略するためには、任意のソリューションで
    # EnvDTE (EnvDTE.8.0.2) NuGet パッケージがインストールされている必要があります。
    # 複数の Visual Studio が起動している場合は、最初に起動した Visual Studio のソリューション構成を取得します。
    $ConfigurationName,

    [Parameter(ParameterSetName = 'PostBuildEvent', Mandatory = $true, HelpMessage = '出力ファイルを指定します。')]
    [string]
    # プロジェクトの出力ディレクトリ ($SolutionName\$ProjectName\bin\$ConfigurationName\) から
    # ソリューションの出力ディレクトリ ($SolutionName\bin\$ConfigurationName\) にコピーするファイルを指定します。
    # 複数ファイルの場合は、コンマ区切りで指定してください。
    # PowerShell.exe がひとつの引数として解釈できるように、スペースは含めないでください。
    $TargetFileNames,

    [Parameter(ParameterSetName = 'PreBuildEvent', HelpMessage = '参照ファイルを指定します。')]
    [string]
    # 参照ファイルを指定します。
    # Redistributables ディレクトリ ($SolutionName\$ProjectName\Redistributables\$ConfigurationName\)
    # に配置されているファイルを指定できます。
    # 指定されたファイルは、References ディレクトリ ($SolutionName\$ProjectName\References\) にコピーされます。
    # 複数ファイルの場合は、コンマ区切りで指定してください。
    # PowerShell.exe がひとつの引数として解釈できるように、スペースは含めないでください。
    $ReferenceFileNames
)


$ScriptName = 'BUILDLet Build Configuration Tool'
$ScriptVersion = '1.0.3.0'
$ScriptCopyrightYear = '2018-2019'
$ScriptCopyrightHolder = 'Daiki Sakamoto'
$ScriptTitleMessage = @"
$ScriptName [Version $ScriptVersion]
Copyright (c) $ScriptCopyrightYear $ScriptCopyrightHolder
"@


# for 'AssemblyInfoBase.cs'
$AssemblyVersion = '3.0.1.0'
$AssemblyFileVersion = '3.0.1.0'

$AssemblyCopyrightYear = '2019'
$AssemblyCopyrightHolder = 'Daiki Sakamoto'
$AssemblyCopyright = "Copyright © $AssemblyCopyrightYear $AssemblyCopyrightHolder"

$AssemblyCompany = 'BUILDLet'
$AssemblyTrademark = ''

$AssemblyInfoBaseFileName = 'AssemblyInfoBase.cs'
$AssemblyInfoBaseContent =  @"
using System;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

[assembly: AssemblyCompany("$AssemblyCompany")]
[assembly: AssemblyCopyright("$AssemblyCopyright")]
[assembly: AssemblyTrademark("$AssemblyTrademark")]

// コンパイラーの deterministic オプションを有効 (既定では有効) にすると、AssemblyVersion にワイルドカード (*) を使用できなくなります。  
// PowerShell モジュールをビルドする場合は、AssemblyFileVersion と同じ値を AssemblyVersion に指定してください。
[assembly: AssemblyVersion("$AssemblyVersion")]
[assembly: AssemblyFileVersion("$AssemblyFileVersion")]

// CA1014: 共通言語仕様 (CLS: Common Language Specification) 準拠して、
// 外部から参照可能な型を公開する場合は、このアセンブリの CLSCompliant 属性を true に設定します。
// [assembly: CLSCompliant(true)]
"@


# for License
$LicenseCopyrightYear = '2019'
$LicenseCopyrightHolder = 'Daiki Sakamoto'

# MIT License
$MIT_LicenseContent = @"
The MIT License (MIT)

Copyright (c) $LicenseCopyrightYear $LicenseCopyrightHolder

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@

# License Contents
$LicenseContents = @{
    'MIT' = $MIT_LicenseContent
}


# Directories to be created in SolutionDir
$InitialDirectories = @(
    '.images'     # for image files for README.md
    'Licenses'    # for 'LICENSE'
    'Packages'    # for NuGet Packages
    'Properties'  # for 'AssemblyInfoBase.cs'
    'Readme'
#   'Redistributables'
#   'References'
    'Resources'
    'TestData'
    'TestResults'
)


# Items to be removed by Clearning of Solution
$RemoveItems = @(
#    'bin\*'
#    'obj\*'
    '*\bin'
    '*\obj'
    'TestResults\*'
)

################################################################################
<# Template
Function Verb-Noun {

    # CmdletBinding
    [CmdletBinding()]

    # Parameter(s)
    Param ()

    # Begin
    Begin {}

    # Process
    Process {}

    # End
    End {}
}
#>

################################################################################
# New
Function New-SolutionDir {

    # CmdletBinding
    # [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'high')]

    # Parameters
    # Param ()

    # Begin
    # Begin {}

    # Process
    Process {

        # Validation (SolutionDir: Should NOT Exist)
        if ($SolutionDir | Test-Path) { throw (New-Object -TypeName System.IO.IOException) }


        # Confirmation to Continue
        if ($PSCmdlet.ShouldProcess($SolutionDir, "ソリューション ディレクトリの初期化")) {


            # NEW Directories
            $InitialDirectories | % {

                # NEW Directory
                New-Item -Path ($SolutionDir | Join-Path -ChildPath $_) -ItemType Directory -Verbose:$VerbosePreference -Force > $null
            }


            # CREATE AssemblyInfoBase.cs
            $AssemblyInfoBaseContent `
                | Out-File -FilePath ($SolutionDir | Join-Path -ChildPath 'Properties' | Join-Path -ChildPath $AssemblyInfoBaseFileName) `
                    -Encoding utf8 -Verbose:$VerbosePreference


            # CREATE LICENSE File (Default: MIT License)
            $LicenseContents[$License] `
                | Out-File -FilePath ($SolutionDir | Join-Path -ChildPath 'Licenses' | Join-Path -ChildPath 'LICENSE') `
                    -Encoding utf8 -Verbose:$VerbosePreference
        }
    }

    # End
    # End {}
}

################################################################################
# Clean
Function Clean-SolutionDir {

    # CmdletBinding
    # [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'high')]

    # Parameter(s)
    # Param ()

    # Begin
    # Begin {}

    # Process
    Process {

        # Validation (SolutionDir: Should Exist)
        if (-not ($SolutionDir | Test-Path)) { throw (New-Object -TypeName System.IO.DirectoryNotFoundException) }


        # CREATE Deletion Item (Directory / File) List
        $RemoveItemPaths = @()
        $RemoveItems `
            | ? { ($target_path = $SolutionDir | Join-Path -ChildPath $_) | Test-Path } `
            | % { $target_path | Convert-Path } `
            | % { $RemoveItemPaths += $_ }

        # CREATE Deletion Item (Directory / File) List to be shown for confirmation
        $RemoveItemDisplayList = @('FILE:')
        $RemoveItemPaths | % { $RemoveItemDisplayList += "`n$_" }


        # CONFIRM to CONTINUE
        if ($PSCmdlet.ShouldProcess($RemoveItemDisplayList, "ファイルとディレクトリの削除")) {
            
	        # REMOVE Item(s)
	        $RemoveItemPaths | % {
		        Remove-Item -Path $_ -Recurse -Force -Verbose:$VerbosePreference #-WhatIf
	        }
        }
    }

    # End
    # End {}
}

################################################################################
# PostBuildEvent
Function Process-PostBuildEvent {

    # CmdletBinding
    # [CmdletBinding()]

    # Parameter(s)
    # Param ()

    # Begin
    # Begin {}

    # Process
    Process {

        # COPY Target File(s): TargetDir --> DestinationDir
        $TargetFileNames -split ',' | % {

            # COPY File
            $TargetDir | Join-Path -ChildPath $_ | Copy-Item -Destination $DestinationDir -Verbose:$VerbosePreference

            # OUTPUT
            "$_ --> $DestinationDir (PostBuildEvent)" | Write-Host 
        }
    }

    # End
    # End {}
}

################################################################################
# PreBuildEvent
Function Process-PreBuildEvent {

    # CmdletBinding
    # [CmdletBinding()]

    # Parameter(s)
    # Param ()

    # Begin
    # Begin {}

    # Process
    Process {


        # COPY Reference File(s): RedistDir --> ReferenceDir
        if (-not [string]::IsNullOrWhiteSpace($ReferenceFileNames)) {
            $ReferenceFileNames -split ',' | % {
                
                # COPY File
                $RedistDir | Join-Path -ChildPath $_ | Copy-Item -Destination $ReferenceDir -Verbose:$VerbosePreference

                # OUTPUT
                "$_ --> $ReferenceDir (PreBuildEvent)" | Write-Host
            }
        }


        # Copy Reference File(s): ReferenceDir --> TargetDir
        # N/A: 参照に追加されたアセンブリ (ファイル) は、Visual Studio によって自動的に TargetDir へコピーされる。
    }

    # End
    # End {}
}

################################################################################
# (PreBuildEvent for) PowerShellModule
Function Process-PowerShellModule {

    # CmdletBinding
    # [CmdletBinding()]

    # Parameter(s)
    # Param ()

    # Begin
    # Begin {}

    # Process
    Process {

        # COPY File(s) (*.psd1, *.psm1) of PowerShell Module to Solution TargetDir
        Get-ChildItem -Path ($ProjectDir | Join-Path -ChildPath *) -Include @('*.psd1', '*.psm1') -File | % {

            $src_module_filename = $_.Name
            $src_module_filepath = $_.FullName
            $dest_module_filepath = $DestinationDir | Join-Path -ChildPath $src_module_filename

            # COOPY File(s) to Solution TargetDir
            Copy-Item -Path $src_module_filepath -Destination $DestinationDir -Verbose:$VerbosePreference

            # OUTPUT
            "$src_module_filename --> $dest_module_filepath (PostBuildEvent)" | Write-Host
        }


        # COPY PowerShell Module from Solution TargetDir to Project TargetDir to Test
        if ($ProjectDir | Join-Path -ChildPath '*.Tests.ps1' | Test-Path) {

            $dest_modulepath = $TargetDir `
                | Join-Path -ChildPath 'WindowsPowerShell' `
                | Join-Path -ChildPath 'Modules'

            $dest_module_dirpath = $dest_modulepath | Join-Path -ChildPath $PowerShellModuleName


            # REMOVE Module Directory in Project TargetDir
            if ($dest_modulepath | Test-Path) { Remove-Item -Path $dest_modulepath -Recurse -Force }

            # NEW Module Directory in Project TargetDir
            New-Item -Path $dest_modulepath -ItemType Directory -Force > $null


            # COOPY File(s) from Solution TargetDir to Project TargetDir
            Copy-Item -Path $DestinationDir -Destination $dest_modulepath -Recurse -Verbose:$VerbosePreference

            # OUTPUT
            "$PowerShellModuleName --> $dest_module_dirpath (PostBuildEvent)" | Write-Host
        }
    }

    # End
    # End {}
}
#>

################################################################################
# Main

# OUTPUT
switch ($PSCmdlet.ParameterSetName) {

    # 'PowerShellModule' (only PostBuildEvent) (Verbose Output)
    'PowerShellModule' { "$ScriptName [Version $ScriptVersion] (PostBuildEvent)" | Write-Verbose }

    # 'PostBuildEvent' (Verbose Output)
    'PostBuildEvent' { "$ScriptName [Version $ScriptVersion] (PostBuildEvent)" | Write-Verbose }

    # 'PreBuildEvent' (Verbose Output)
    'PreBuildEvent' { "$ScriptName [Version $ScriptVersion] (PostBuildEvent)" | Write-Verbose }

    # 'New', 'Clean' or 'Version' (Console Output)
    default { $ScriptTitleMessage | Write-Host -ForegroundColor Green }
}

# 'Version': RETURN
if ($PSCmdlet.ParameterSetName -eq 'Version') { return }



# GET SolutionDir
$SolutionDir = $PSCommandPath | Split-Path -Parent | Join-Path -ChildPath $SolutionName

# Prepare Directories for 'PreBuildEvent', 'PostBuildEvent' or 'PowerShellModule'
if ($PSCmdlet.ParameterSetName -like '*BuildEvent' -or $PSCmdlet.ParameterSetName -eq 'PowerShellModule') {
    
    # GET ProjectDir
    $ProjectDir = $SolutionDir | Join-Path -ChildPath $ProjectName


    # GET ConfigurationName from ActiveConfig
    if (-not $ConfigurationName) {

        # IMPORT EnvDTE Module
        if ((Get-Module -Name EnvDTE) -eq $null) { Import-Module -Name ($PSScriptRoot | Join-Path -ChildPath 'EnvDTE.psm1') }

        # SET ConfigurationName
        $ConfigurationName = Get-DTEActiveConfig

        # REMOVE EnvDTE Module
        if ((Get-Module -Name EnvDTE) -ne $null) { Remove-Module -Name EnvDTE }
    }


    # SET TargetDir (for Project)
    $TargetDir = $ProjectDir | Join-Path -ChildPath 'bin' | Join-Path -ChildPath $ConfigurationName


    # SET DestinationDir (for Solution)
    $DestinationDir = $SolutionDir | Join-Path -ChildPath 'bin' | Join-Path -ChildPath $ConfigurationName

    # NEW DestinationDir (for Solution)
    New-Item -Path $DestinationDir -ItemType Directory -Verbose:$VerbosePreference -Force > $null

    # UPDATE / NEW DestinationDir (PowerShell Module for Solution)
    if ($PowerShellModuleName) {

        # UPDATE DestinationDir (PowerShell Module for Solution)
        $DestinationDir = $DestinationDir `
            | Join-Path -ChildPath 'WindowsPowerShell' `
            | Join-Path -ChildPath 'Modules' `
            | Join-Path -ChildPath $PowerShellModuleName

        # NEW DestinationDir (PowerShell Module for Solution)
        New-Item -Path $DestinationDir -ItemType Directory -Verbose:$VerbosePreference -Force > $null
    }


    # for References
    if (-not [string]::IsNullOrWhiteSpace($ReferenceFileNames)) {

        # SET 'Redistributables' Directory
        $RedistDir = $ProjectDir | Join-Path -ChildPath 'Redistributables' | Join-Path -ChildPath $ConfigurationName

        # NEW 'Redistributables' Directory
        New-Item -Path $RedistDir -ItemType Directory -Verbose:$VerbosePreference -Force > $null


        # SET 'References' Directory
        $ReferenceDir = $ProjectDir | Join-Path -ChildPath 'References'

        # NEW 'References' Directory
        New-Item -Path $ReferenceDir -ItemType Directory -Verbose:$VerbosePreference -Force > $null
    }
}



# Process
switch ($PSCmdlet.ParameterSetName) {

    # 'PowerShellModule'
    'PowerShellModule' { Process-PowerShellModule }

    # 'New'
    'New' { New-SolutionDir }

    # 'Clean'
    'Clean' { Clean-SolutionDir }

    # 'PostBuildEvent'
    'PostBuildEvent' { Process-PostBuildEvent }

    # 'PreBuildEvent'
    'PreBuildEvent' { Process-PreBuildEvent }
}
