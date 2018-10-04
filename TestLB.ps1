for ($i = 0; $i -lt 100; $i++) {
    Write-Host "Attempt $($i)"

    #use the IP if you want to test the ELB
    #$targetIP = "40.112.151.80"

    #use the IP if you want to test the ILB
    #$targetIP = "10.0.0.5"

    #use the DNS name if you want to test Traffic Manager endpoint
    $targetIP = "rgazurenetworkinglab.trafficmanager.net"
    $url= "http://$($targetIP)/default.html"

    $html = ""
    $html = Invoke-WebRequest -Uri $url -DisableKeepAlive
    $htmlbytes1 = [System.Text.Encoding]::ASCII.GetBytes($html.Content)
    $htmlbytes2 = [System.Text.Encoding]::Convert([System.Text.Encoding]::Unicode, [System.Text.Encoding]::ASCII, $htmlbytes1)
    $chars = New-Object char[] 100
    $out = [System.Text.Encoding]::ASCII.GetChars($htmlbytes2, 0, $htmlbytes2.Length, $chars, 0)
    $html = [System.String]::new($chars)


    if ($html -like "*VM0*")
    {
        write-host $html -ForegroundColor Green
    }

    if ($html -like "*VM1*")
    {
        write-host $html -ForegroundColor Yellow
    }

    if ($html -like "*VM2*")
    {
        write-host $html -ForegroundColor Magenta
    }

    Start-Sleep -Seconds 2
}