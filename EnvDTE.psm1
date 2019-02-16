<###############################################################################
 The MIT License (MIT)

 Copyright (c) 2019 Daiki Sakamoto

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
################################################################################>

Function Get-DTEActiveConfig {

<#

.SYNOPSIS
Visual Studio の現在のソリューション構成を取得します。

.DESCRIPTION
このファイルは BuildConfig.ps1 と共に、ソリューション ディレクトリのひとつ上の階層に配置してください。
任意のソリューションで EnvDTE (EnvDTE.8.0.2) NuGet パッケージがインストールされている必要があります。
複数の Visual Studio が起動している場合は、最初に起動した Visual Studio のソリューション構成を取得します。

.INPUTS
なし
このスクリプトはパイプラインからの入力を受け取りません。

.OUTPUTS
System.String
Visual Studio の現在のソリューション構成を返します。

.LINK
https://github.com/buildlet/BuildConfig

#>

    # CmdletBinding
    [CmdletBinding()]

    # Parameter(s)
    Param ()

    # Begin
    # Begin {}

    # Process
    Process {

        # NuGet Package Path of EnvDTE.dll (EnvDTE: EnvDTE.8.0.2)
        $EnvDTENuGetPackageFilePath = $PSScriptRoot | Join-Path -ChildPath '*\Packages\EnvDTE.8.0.2\lib\net10\EnvDTE.dll'

        # Validation
        if (-not ($EnvDTENuGetPackageFilePath | Test-Path)) { throw New-Object System.IO.FileNotFoundException }

        # GET File Path of EnvDTE.dll
        $EnvDTEFilePath = ($EnvDTENuGetPackageFilePath | Resolve-Path)[0]

        # IMPORT EnvDTE.dll
        if ((Get-Module -Name EnvDTE) -eq $null) { Import-Module -Name $EnvDTEFilePath }

        # NEW DTE Object
        $dte = [System.Runtime.InteropServices.Marshal]::GetActiveObject('VisualStudio.DTE')

        # RETURN ActiveConfig
        Return ([string]$dte.DTE.Solution.Properties.Item('ActiveConfig').Value).Split('|')[0]
    }

    # End
    # End {}
}

Export-ModuleMember -Function *
