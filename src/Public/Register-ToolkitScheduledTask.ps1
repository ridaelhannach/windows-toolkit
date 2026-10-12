function Register-ToolkitScheduledTask {
    <#
    .SYNOPSIS
        Manages the weekly automated safe maintenance scheduled task.
    .DESCRIPTION
        Registers, inspects, or unregisters the LaptopToolkit-WeeklyMaintenance scheduled task.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Register", "Unregister", "Status", "RunNow")]
        [string]$Action = "Status",

        [string]$Time = "10:00AM",
        [ValidateSet("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")]
        [string]$DayOfWeek = "Sunday"
    )

    $taskName = "LaptopToolkit-WeeklyMaintenance"
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    switch ($Action) {
        "Status" {
            Write-Host "============================================================" -ForegroundColor Cyan
            Write-Host "           SCHEDULED MAINTENANCE TASK STATUS               " -ForegroundColor Cyan
            Write-Host "============================================================" -ForegroundColor Cyan
            if ($task) {
                Write-Host "Status:        INSTALLED" -ForegroundColor Green
                Write-Host "State:         $($task.State)"
                $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
                if ($info) {
                    Write-Host "Last Run:      $($info.LastRunTime)"
                    Write-Host "Last Result:   $($info.LastTaskResult)"
                    Write-Host "Next Run:      $($info.NextRunTime)"
                }
            } else {
                Write-Host "Status:        NOT INSTALLED" -ForegroundColor Yellow
                Write-Host "Use -Action Register to set up weekly automated maintenance." -ForegroundColor DarkGray
            }
        }
        "Register" {
            $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command `"& { Import-Module LaptopToolkit; Invoke-SafeDiskCleanup -Clean }`""
            $taskTrigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $Time
            $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

            try {
                Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Description "Weekly Automated Safe Maintenance by LaptopToolkit" -Force | Out-Null
                Write-Host "Task '$taskName' registered successfully ($DayOfWeek at $Time)." -ForegroundColor Green
                Write-ToolkitLog "Registered scheduled task: $taskName ($DayOfWeek @ $Time)" "INFO"
            } catch {
                Write-Host "Failed to register task: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        "Unregister" {
            if ($task) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                Write-Host "Task '$taskName' has been removed." -ForegroundColor Green
                Write-ToolkitLog "Unregistered scheduled task: $taskName" "INFO"
            } else {
                Write-Host "Task '$taskName' is not currently registered." -ForegroundColor Yellow
            }
        }
        "RunNow" {
            Write-Host "Executing maintenance routine immediately..." -ForegroundColor Yellow
            Invoke-SafeDiskCleanup -Clean
        }
    }
}
