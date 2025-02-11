Function Invoke-PSDeploy {
    PARAM(
        [string]
        $Repository
        ,
        [string]
        $BHPSModuleManifest
        ,
        [Version]
        $BuildVersion
        ,
        [Switch]
        $Beta
    )

    Write-Verbose "-------------Start $($myInvocation.InvocationName) -----------------" -Verbose
    Write-Verbose "  From Script:'$($myInvocation.ScriptName)' - At Line:$($myInvocation.ScriptLineNumber) char:$($myInvocation.OffsetInLine)" -Verbose
    Write-Verbose "  Line '$($myInvocation.Line.Trim())'" -Verbose
    $myInvocation.BoundParameters.GetEnumerator()  | ForEach-Object { Write-Verbose "  BoundParameter   : '$($_.key)' = '$($_.Value)'" -Verbose}
    $myInvocation.UnboundArguments | ForEach-Object { Write-Verbose "  UnboundArguments : '$_'" -Verbose}

    Write-Host "Checking $Repository" -ForegroundColor Cyan
    $GitStatus = Get-GitStatus
    if ($GitStatus.AheadBy -gt 0) {
        Write-Host "  Pushing changes" -ForegroundColor Magenta
        git push #| Write-Verbose
    }
    if ($GitStatus.BehindBy -gt 0) {
        Write-Host "Your branch is behind '$($GitStatus.Upstream)' by $($GitStatus.BehindBy) commits" -ForegroundColor Magenta
        if ($GitStatus.Working) {
            Write-Host "  Stashing current changes" -ForegroundColor Magenta
            git stash save "Automated Stash during pull" --include-untracked #| Write-Verbose
            Write-Host "  Pulling branch changes" -ForegroundColor Magenta
            git pull #| Write-Verbose
            # git stash list # By default, git stash pop will re-apply the most recently created stash: stash@{0}
            Write-Host "  Re-applying stashed changes" -ForegroundColor Magenta
            git stash pop #| Write-Verbose
            Start-Sleep -Seconds 1
        } else {
            Write-Host "  Pulling branch changes" -ForegroundColor Magenta
            git pull #| Write-Verbose
        }
        $GitStatus = Get-GitStatus
    }
    git add $BHPSModuleManifest
    Start-Sleep -Seconds 1
    $BuildVersion = $env:Version
    if ($Beta) {
        $BuildVersion = "$BuildVersion-Beta"
    }
    $commitTitle = "Build Version $BuildVersion"
    $commitDescription = "[$env:computername] $((Get-Date).ToString('yyyy:MM:dd-HH:mm:ss'))"
    Write-Host "  Commiting '$commitTitle'" -ForegroundColor Magenta
    git commit -m $commitTitle -m $commitDescription
    git tag "Build-$BuildVersion"
    $GitStatus = Get-GitStatus
    if ($GitStatus.AheadBy -gt 0) {
        Write-Host "  Pushing changes" -ForegroundColor Magenta
        git push #| Write-Verbose
    }

}