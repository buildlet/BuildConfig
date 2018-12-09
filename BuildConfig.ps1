<###############################################################################
 The MIT License (MIT)

 Copyright (c) 2018 Daiki Sakamoto

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
    PowerShell.exe -File $(SolutionDir)..\BuildConfig.ps1 -PostBuildEvent -SolutionName $(SolutionName) -ProjectName $(ProjectName) -ConfigurationName $(ConfigurationName) -TargetFileNames $(TargetFileName),redist1.dll,redist2.dll
    ビルド後イベント (PostBuildEvent) のコマンドラインを指定します。
    この例では、出力ファイルに $(TargetFileName)、redist1.dll および redist2.dll が指定されています。

    .EXAMPLE
    PowerShell.exe -File $(SolutionDir)..\BuildConfig.ps1 -PreBuildEvent -SolutionName $(SolutionName) -ProjectName $(ProjectName) -ConfigurationName $(ConfigurationName) -ReferenceFileNames redist1.dll,redist2.dll
    ビルド前イベント (PreBuildEvent) のコマンドラインを指定します。
    この例では、参照ファイルに redist1.dll および redist2.dll が指定されています。

    .LINK
    https://github.com/buildlet/BuildConfig
#>


# Parameters
Param(

    # このスクリプトのバージョン情報を表示します。
    [Parameter(ParameterSetName = 'Version', Position = 0)]
    [switch]$Version,

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
    [Parameter(ParameterSetName = 'New', Mandatory = $true, Position = 0)]
    [switch]$New,

    # ソリューション ディレクトリをクリーニングします。
    [Parameter(ParameterSetName = 'Clean', Mandatory = $true, Position = 0)]
    [switch]$Clean,

    # ビルド後イベント (PostBuildEvent) のコマンドラインを指定します。
    [Parameter(ParameterSetName = 'PostBuildEvent', Mandatory = $true, Position = 0)]
    [switch]$PostBuildEvent,

    # ビルド前イベント (PreBuildEvent) のコマンドラインを指定します。
    [Parameter(ParameterSetName = 'PreBuildEvent', Mandatory = $true, Position = 0)]
    [switch]$PreBuildEvent,

    # ソリューション名を指定します。
    [Parameter(ParameterSetName = 'New', Mandatory = $true, Position = 1, HelpMessage = 'ソリューション名を指定します。')]
    [Parameter(ParameterSetName = 'Clean', Mandatory = $true, Position = 1, HelpMessage = 'ソリューション名を指定します。')]
    [Parameter(ParameterSetName = 'PostBuildEvent', Mandatory = $true, Position = 1, HelpMessage = 'ソリューション名を指定します。')]
    [Parameter(ParameterSetName = 'PreBuildEvent', Mandatory = $true, Position = 1, HelpMessage = 'ソリューション名を指定します。')]
    [string]$SolutionName,

    # ライセンスの種類を指定します。
    # 既定では MIT License が指定されます。
    [Parameter(ParameterSetName = 'New', Position = 2, HelpMessage = 'ライセンスの種類を指定します。')]
    [ValidateSet('MIT')]
    [string]$License = 'MIT',

    # プロジェクト名を指定します。
    [Parameter(ParameterSetName = 'PostBuildEvent', Mandatory = $true, Position = 2, HelpMessage = 'プロジェクト名を指定します。')]
    [Parameter(ParameterSetName = 'PreBuildEvent', Mandatory = $true, Position = 2, HelpMessage = 'プロジェクト名を指定します。')]
    [string]$ProjectName,

    # ソリューション構成 (Debug または Release) を指定します。
    [Parameter(ParameterSetName = 'PostBuildEvent', Mandatory = $true, Position = 3, HelpMessage = 'ソリューション構成 (Debug または Release) を指定します。')]
    [Parameter(ParameterSetName = 'PreBuildEvent', Mandatory = $true, Position = 3, HelpMessage = 'ソリューション構成 (Debug または Release) を指定します。')]
    [ValidateSet('Debug', 'Release')]
    [string]$ConfigurationName,

    # PowerShell モジュールの名前を指定します。
    [Parameter(ParameterSetName = 'PostBuildEvent', HelpMessage = 'PowerShell モジュールの名前を指定します。')]
    [string]$PowerShellModuleName,

    # プロジェクトの出力ディレクトリ ($SolutionName\$ProjectName\bin\$ConfigurationName\) から
    # ソリューションの出力ディレクトリ ($SolutionName\bin\$ConfigurationName\) にコピーするファイルを指定します。
    # 複数ファイルの場合は、コンマ区切りで指定してください。
    # PowerShell.exe がひとつの引数として解釈できるように、スペースは含めないでください。
    [Parameter(ParameterSetName = 'PostBuildEvent', Mandatory = $true, HelpMessage = '出力ファイルを指定します。')]
    [string]$TargetFileNames,


    # 再頒布可能ファイルを指定します。
    # 複数ファイルの場合は、コンマ区切りで指定してください。
    # PowerShell.exe がひとつの引数として解釈できるように、スペースは含めないでください。
    # [Parameter(ParameterSetName = 'PreBuildEvent', HelpMessage = '再頒布可能ファイルを指定します。')]
    # [string]$RedistFileNames,


    # 参照ファイルを指定します。
    # Redistributables ディレクトリ ($SolutionName\$ProjectName\Redistributables\$ConfigurationName\) に配置されているファイルを指定できます。
    # 指定されたファイルは、References ディレクトリ ($SolutionName\$ProjectName\References\) にコピーされます。
    # 複数ファイルの場合は、コンマ区切りで指定してください。
    # PowerShell.exe がひとつの引数として解釈できるように、スペースは含めないでください。
    [Parameter(ParameterSetName = 'PreBuildEvent', HelpMessage = '参照ファイルを指定します。')]
    [string]$ReferenceFileNames
)


$ScriptName = 'BUILDLet Build Configuration Tool'
$ScriptVersion = '1.0.0.0'
$ScriptCopyrightYear = '2018'
$ScriptCopyrightHolder = 'Daiki Sakamoto'
$ScriptTitleMessage = @"
$ScriptName [Version $ScriptVersion]
Copyright (c) $ScriptCopyrightYear $ScriptCopyrightHolder
"@


# for 'AssemblyInfoBase.cs'
$AssemblyVersion = '3.0.1.0'
$AssemblyFileVersion = '3.0.1.0'

$AssemblyCopyrightYear = '2014-2018'
$AssemblyCopyrightHolder = 'Daiki Sakamoto'
$AssemblyCopyright = "Copyright © $AssemblyCopyrightYear $AssemblyCopyrightHolder"

$AssemblyCompany = 'BUILDLet'
$AssemblyTrademark = ''

$AssemblyInfoBaseFileName = 'AssemblyInfoBase.cs'
$AssemblyInfoBaseContent =  @"
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
"@


# for License
$LicenseCopyrightYear = '2018'
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
# New
Function New-SolutionDir {

    # CmdletBinding
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'high')]

    # Parameters
    Param ()

    # Begin
    # Begin {}

    # Process
    Process {

        # Validation (SolutionDir: Should NOT Exist)
        if ($SolutionDir | Test-Path) { throw (New-Object -TypeName System.IO.IOException) }


        # Confirmation to Continue
        if ($PSCmdlet.ShouldProcess($SolutionDir, "ソリューション ディレクトリの初期化")) {


            # Create Directories
            $InitialDirectories | % {

                # Create Directory
                New-Item -Path ($SolutionDir | Join-Path -ChildPath $_) -ItemType Directory -Verbose:$VerbosePreference -Force > $null
            }


            # Create AssemblyInfoBase.cs
            $AssemblyInfoBaseContent `
                | Out-File -FilePath ($SolutionDir | Join-Path -ChildPath 'Properties' | Join-Path -ChildPath $AssemblyInfoBaseFileName) `
                    -Encoding utf8 -Verbose:$VerbosePreference


            # Create License File (Default: MIT License)
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
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'high')]

    # Parameter(s)
    Param ()

    # Begin
    # Begin {}

    # Process
    Process {

        # Validation (SolutionDir: Should Exist)
        if (-not ($SolutionDir | Test-Path)) { throw (New-Object -TypeName System.IO.DirectoryNotFoundException) }


        # Create Deletion Item (Directory / File) List
        $RemoveItems_list = @()
        $RemoveItems `
        | ? { ($target_path = $SolutionDir | Join-Path -ChildPath $_) | Test-Path } `
        | % { $target_path | Convert-Path } `
        | % { $RemoveItems_list += $_ }


        # Create Deletion Item (Directory / File) List to be shown for confirmation
        $RemoveItems_display_list = @("`n")
        $RemoveItems_list | % { $RemoveItems_display_list += "$_`n" }


        # Confirmation to Continue
        if ($PSCmdlet.ShouldProcess($RemoveItems_display_list, "ファイルとディレクトリの削除")) {
            
	        # Remove Item(s)
	        $RemoveItems_list | % {
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

        # Copy Target File(s): TargetDir --> DestinationDir
        $TargetFileNames -split ',' | % {

            # Copy File
            $TargetDir | Join-Path -ChildPath $_ | Copy-Item -Destination $DestinationDir -Verbose:$VerbosePreference

            # Console Output
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


       <# Copy Redistributable File(s): RedistDir --> TargetDir
        if (-not [string]::IsNullOrWhiteSpace($RedistFileNames)) {
            $RedistFileNames -split ',' | % {
                
                # Copy File
                $RedistDir | Join-Path -ChildPath $_ | Copy-Item -Destination $TargetDir -Verbose:$VerbosePreference

                # Console Output
                $_ + ' --> ' + $TargetDir
            }
        }
        #>


        # Copy Redistributable File(s): RedistDir --> ReferenceDir
        if (-not [string]::IsNullOrWhiteSpace($ReferenceFileNames)) {
            $ReferenceFileNames -split ',' | % {
                
                # Copy File
                $RedistDir | Join-Path -ChildPath $_ | Copy-Item -Destination $ReferenceDir -Verbose:$VerbosePreference

                # Console Output
                "$_ --> $ReferenceDir (PreBuildEvent)" | Write-Host
            }
        }


        # Copy Reference File(s): ReferenceDir --> TargetDir
        # N/A: 参照に追加されたアセンブリ (ファイル) は、Visual Studio によって自動的に TargetDir へコピーされる。
    }

    # End
    # End {}
}


<################################################################################
# Template
Function Verb-Noun {

    # CmdletBinding
    [CmdletBinding()]

    # Parameter(s)
    Param ()

    # Begin
    Begin {}

    # Process
    Process {
    }

    # End
    End {}
}
#>


################################################################################
# Main

# Show Message
switch ($PSCmdlet.ParameterSetName) {

    # 'PostBuildEvent' (Verbose Output)
    'PostBuildEvent' { 'BUILDLet Build Configuration Tool: PostBuildEvent Script' | Write-Verbose }

    # 'PreBuildEvent' (Verbose Output)
    'PreBuildEvent' { 'BUILDLet Build Configuration Tool: PreBuildEvent Script' | Write-Verbose }

    # 'New', 'Clean' or 'Version' (Console Output)
    default { $ScriptTitleMessage | Write-Host -ForegroundColor Green }
}


# 'Version': RETURN
if ($PSCmdlet.ParameterSetName -eq 'Version') { return }


# Get Solution Directory (SolutionDir)
$SolutionDir = $PSCommandPath | Split-Path -Parent | Join-Path -ChildPath $SolutionName


# PreBuildEvent or PostBuildEvent
if ($PSCmdlet.ParameterSetName -like '*BuildEvent') {

    # Get Project Directory (ProjectDir)
    $ProjectDir = $SolutionDir | Join-Path -ChildPath $ProjectName

    # Set Target Directory (TargetDir)
    $TargetDir = $ProjectDir | Join-Path -ChildPath 'bin' | Join-Path -ChildPath $ConfigurationName


    # Set / Create Destination Directory ('bin') for Solution
    $DestinationDir = $SolutionDir | Join-Path -ChildPath 'bin' | Join-Path -ChildPath $ConfigurationName    
    New-Item -Path $DestinationDir -ItemType Directory -Verbose:$VerbosePreference -Force > $null

    # Update Destination Directory ('bin') for PowerShell Module
    if ($PowerShellModuleName) {
        $DestinationDir = $DestinationDir | Join-Path -ChildPath 'WindowsPowerShell' | Join-Path -ChildPath 'Modules' | Join-Path -ChildPath $PowerShellModuleName
        New-Item -Path $DestinationDir -ItemType Directory -Verbose:$VerbosePreference -Force > $null
    }


    # for References
    if (-not [string]::IsNullOrWhiteSpace($ReferenceFileNames)) {

        # Set / Create 'Redistributables' Directory
        $RedistDir = $ProjectDir | Join-Path -ChildPath 'Redistributables' | Join-Path -ChildPath $ConfigurationName
        New-Item -Path $RedistDir -ItemType Directory -Verbose:$VerbosePreference -Force > $null

        # Set / Create 'References' Directory
        $ReferenceDir = $ProjectDir | Join-Path -ChildPath 'References'
        New-Item -Path $ReferenceDir -ItemType Directory -Verbose:$VerbosePreference -Force > $null
    }
}


# Process
switch ($PSCmdlet.ParameterSetName) {
    'New' { New-SolutionDir }
    'Clean' { Clean-SolutionDir }
    'PostBuildEvent' { Process-PostBuildEvent }
    'PreBuildEvent' { Process-PreBuildEvent }
}
