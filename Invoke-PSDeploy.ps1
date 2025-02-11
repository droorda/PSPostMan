Function Invoke-PSDeploy {
    [CmdletBinding()]
    PARAM(
        [Parameter(Mandatory=$true)]
        [string]
        $Path
        ,
        [Parameter(Mandatory=$true)]
        [string]
        $FeedUrl
        ,
        [Parameter(Mandatory=$true)]
        [securestring]
        $ApiKey
        ,
        [switch]
        $Beta
    )

    Write-Verbose "-------------Start $($myInvocation.InvocationName) -----------------" -Verbose
    Write-Verbose "  From Script:'$($myInvocation.ScriptName)' - At Line:$($myInvocation.ScriptLineNumber) char:$($myInvocation.OffsetInLine)" -Verbose
    Write-Verbose "  Line '$($myInvocation.Line.Trim())'" -Verbose
    $myInvocation.BoundParameters.GetEnumerator()  | ForEach-Object { Write-Verbose "  BoundParameter   : '$($_.key)' = '$($_.Value)'" -Verbose}
    $myInvocation.UnboundArguments | ForEach-Object { Write-Verbose "  UnboundArguments : '$_'" -Verbose}

    Write-Host "Creating Nuget package" -ForegroundColor Cyan

    Try {
        $ModulePackage = New-PMModulePackage -Verbose -PassThru -Path "$Path\$(split-path $Path -Leaf)" -Beta:$Beta
    } Catch {
        Write-Warning "New-PMModulePackage : $($_.exception.message)"
        $_
    }

    Try {
        # $Version = Get-NextPSGalleryVersion -Name $env:BHProjectName -ErrorAction Stop
        Update-Metadata -Path $env:BHPSModuleManifest -PropertyName FunctionsToExport -Value '*' -ErrorAction stop
    } Catch {
        "Failed to set FunctionsToExport for '$env:BHProjectName': $_.`nContinuing with existing version"
    }

    if ($ModulePackage) {
        # $ModulePackage = Move-Item -path $ModulePackage -Destination "$Path\Builds" -PassThru
        Write-Host "Signing Nuget package" -ForegroundColor Cyan
        $Certificate = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert | Where-Object {$_.NotAfter -gt (Get-date)}| Sort-Object NotAfter -Descending | Select-Object -First 1

        $Params = @{
            path = $ModulePackage.fullname
            CertificateFingerprint = $Certificate.Thumbprint
            Timestamper = 'http://timestamp.digicert.com'
            Verbose =$VerbosePreference
        }
        Try {
            Set-PMPackageCert @Params
            $PackageSigned = $True
        } Catch {
            Write-Warning "Set-PMPackageCert : $($_.exception.message)"
            $PackageSigned = $false
        }
        if ($PackageSigned) {
            Write-Host "Publishing Nuget package" -ForegroundColor Cyan
            $Params = @{
                Path = $ModulePackage.fullname
                FeedUrl = $FeedUrl
                ApiKey = $([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ApiKey)))
                Verbose = $VerbosePreference
            }
            Write-Verbose "Publish-PMPackage`n$($Params | Format-Table | Out-String)"
            Try {
                Publish-PMPackage @Params
            } Catch {
                Write-Warning "Publish-PMPackage : $($_.exception.message)"
            }
        }
        Remove-Item -Path $ModulePackage -Force
    }
}