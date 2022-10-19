#########  Config  ###########
$LOG_CONSOLE = 1
$DOMAIN = 'your.domain.here'
$SUB_DOMAIN = 'subdomain'
$VERCEL_TOKEN = 'VeRce1_T0keN'

##############################

#########   Code   ###########
$Logfile = "$PSScriptRoot\ddns.log"
$Headers = @{'Authorization' = 'Bearer ' + $VERCEL_TOKEN}
function WriteLog
{
    Param ([string]$LogString)
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    if (!($LOG_CONSOLE)) {
        Add-content $LogFile -value $LogMessage
    }
    else{
        Write-Output $LogString
    }
    
}

try {
    $IPV6_Adress = Invoke-WebRequest 6.ipw.cn -UseBasicParsing | Select-Object -ExpandProperty Content
    WriteLog "IPv6 = $IPV6_Adress"
    if (!(Test-Path -Path $PSScriptRoot\currentV6.ipaddr -PathType Leaf)) {
        Set-Content -Path $PSScriptRoot\currentV6.ipaddr ''
    }
    if (!((Get-Content -Path $PSScriptRoot\currentV6.ipaddr) -eq $IPV6_Adress)) {
        try {
            if ((Test-Path -Path $PSScriptRoot\uid -PathType Leaf) -and !((Get-Content -Path $PSScriptRoot\uid) -eq '')) {
                $uid = Get-Content -Path $PSScriptRoot\uid
                $Uri = "https://api.vercel.com/domains/records/$uid"
                $Body =
                @{
                    'value' = $IPV6_Adress
                } | ConvertTo-Json
                $ServerResponse = Invoke-RestMethod -Method Patch -Uri $Uri -ContentType 'application/json' -Headers $Headers -Body $Body
                $uid = $ServerResponse | Select-Object -ExpandProperty id
                $UpdTime = $ServerResponse | Select-Object -ExpandProperty createdAt
                Set-Content -Path $PSScriptRoot\uid $uid
                $curDate = Get-Date -Format "yyyy/MM/dd HH:mm:ss" -Date((Get-Date -Date "1970-1-1 8:00:00") + ([System.TimeSpan]::FromMilliseconds(($UpdTime))))
                WriteLog "Server : PATCH Updated in $curDate."
                WriteLog "Server : uid=$uid"
            }
            else{
                $Uri = "https://api.vercel.com/domains/$DOMAIN/records"
                $Body = 
                @{
                    'name' = $SUB_DOMAIN
                    'type' = "AAAA"
                    'value' = $IPV6_Adress
                    'ttl' = 60
                } | ConvertTo-Json
                $ServerResponse = Invoke-RestMethod -Method POST -Uri $Uri -ContentType 'application/json' -Headers $Headers -Body $Body
                $uid = $ServerResponse | Select-Object -ExpandProperty uid
                Set-Content -Path $PSScriptRoot\uid $uid
                if ($ServerResponse -match 'updated') {
                    $UpdTime = $ServerResponse  | Select-Object -ExpandProperty updated
                    $curDate = Get-Date -Format "yyyy/MM/dd HH:mm:ss" -Date((Get-Date -Date "1970-1-1 8:00:00") + ([System.TimeSpan]::FromMilliseconds(($UpdTime))))
                    WriteLog "Server : POST Updated in $curDate. uid=$uid."
                }
                else {
                    WriteLog "Server : Created. uid=$uid."
                }
            }
            
        }
        finally {
            Set-Content -Path $PSScriptRoot\currentV6.ipaddr $IPV6_Adress
            WriteLog 'Done.'
        }
    }else {
        WriteLog 'Same address no need to update.'
    }
}
catch {
    $e = $_.Exception
    $msg = $e.Message
    while ($e.InnerException) {
        $e = $e.InnerException
        $msg += "`n" + $e.Message
    }   
    WriteLog $msg
}
