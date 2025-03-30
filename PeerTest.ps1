# PowerShell script to send POST requests to a node p2p port

Add-Type -AssemblyName System.Windows.Forms
Add-Type -Name Window -Namespace Console -MemberDefinition @"
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
"@

# Hide the PowerShell console window
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0)  # 0 = SW_HIDE

function Create-InputForm {
    $form = New-Object Windows.Forms.Form
    $form.Text = "Input"
    $form.Size = New-Object Drawing.Size(400, 200)

    $labelAddress = New-Object Windows.Forms.Label
    $labelAddress.Text = "Enter the address or hostname with port (e.g., hostname:port):"
    $labelAddress.AutoSize = $true
    $labelAddress.Location = New-Object Drawing.Point(10, 10)
    $form.Controls.Add($labelAddress)

    $textBoxAddress = New-Object Windows.Forms.TextBox
    $textBoxAddress.Location = New-Object Drawing.Point(10, 30)
    $textBoxAddress.Size = New-Object Drawing.Size(360, 20)
    $form.Controls.Add($textBoxAddress)

    $labelBRSVersion = New-Object Windows.Forms.Label
    $labelBRSVersion.Text = "Enter the BRS version to use (default is 3.8.4):"
    $labelBRSVersion.AutoSize = $true
    $labelBRSVersion.Location = New-Object Drawing.Point(10, 60)
    $form.Controls.Add($labelBRSVersion)

    $textBoxBRSVersion = New-Object Windows.Forms.TextBox
    $textBoxBRSVersion.Location = New-Object Drawing.Point(10, 80)
    $textBoxBRSVersion.Size = New-Object Drawing.Size(360, 20)
    $form.Controls.Add($textBoxBRSVersion)

    $buttonOk = New-Object Windows.Forms.Button
    $buttonOk.Text = "OK"
    $buttonOk.Location = New-Object Drawing.Point(10, 110)
    $buttonOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $buttonOk
    $form.Controls.Add($buttonOk)

    $form.StartPosition = "CenterScreen"
    $form.Topmost = $true

    $result = $form.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return @{
            Address = $textBoxAddress.Text
            BRSVersion = $textBoxBRSVersion.Text
        }
    }
    return $null
}

function Create-ResponseForm {
    param (
        [hashtable]$responses,
        [bool]$snrPassed,
        [bool]$p2pPassed
    )

    $form = New-Object Windows.Forms.Form
    $form.Text = "Responses from Endpoints"
    $form.Size = New-Object Drawing.Size(600, 900)
    $panel = New-Object Windows.Forms.Panel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $panel.AutoScroll = $true
    $form.Controls.Add($panel)

    $yPos = 10

    foreach ($endpoint in $responses.Keys) {
        $label = New-Object Windows.Forms.Label
        $label.Text = "Response from $($endpoint):"
        $label.AutoSize = $true
        $label.Location = New-Object Drawing.Point(10, $yPos)
        $panel.Controls.Add($label)
        $yPos += 20

        $textBoxResponse = New-Object Windows.Forms.TextBox
        $textBoxResponse.Multiline = $true
        $textBoxResponse.ScrollBars = "Vertical"
        $textBoxResponse.ReadOnly = $true
        $textBoxResponse.Location = New-Object Drawing.Point(10, $yPos)
        $textBoxResponse.Size = New-Object Drawing.Size(560, 150)
        $textBoxResponse.Text = $responses[$endpoint]
        $panel.Controls.Add($textBoxResponse)
        $yPos += 160
    }

    $yPos += 20

    if ($p2pPassed) {
        $labelP2PPassed = New-Object Windows.Forms.Label
        $labelP2PPassed.Text = "P2P PASSED"
        $labelP2PPassed.AutoSize = $true
        $labelP2PPassed.ForeColor = 'Green'
        $labelP2PPassed.Location = New-Object Drawing.Point(10, $yPos)
        $panel.Controls.Add($labelP2PPassed)
    } else {
        $labelP2PFailed = New-Object Windows.Forms.Label
        $labelP2PFailed.Text = "P2P FAILED"
        $labelP2PFailed.AutoSize = $true
        $labelP2PFailed.ForeColor = 'Red'
        $labelP2PFailed.Location = New-Object Drawing.Point(10, $yPos)
        $panel.Controls.Add($labelP2PFailed)
    }

    $yPos += 20

    if ($snrPassed) {
        $labelSNRPassed = New-Object Windows.Forms.Label
        $labelSNRPassed.Text = "SNR PASSED"
        $labelSNRPassed.AutoSize = $true
        $labelSNRPassed.ForeColor = 'Green'
        $labelSNRPassed.Location = New-Object Drawing.Point(10, $yPos)
        $panel.Controls.Add($labelSNRPassed)
    } else {
        $labelSNRFailed = New-Object Windows.Forms.Label
        $labelSNRFailed.Text = "SNR FAILED"
        $labelSNRFailed.AutoSize = $true
        $labelSNRFailed.ForeColor = 'Red'
        $labelSNRFailed.Location = New-Object Drawing.Point(10, $yPos)
        $panel.Controls.Add($labelSNRFailed)
    }

    $yPos += 30

    $buttonClose = New-Object Windows.Forms.Button
    $buttonClose.Text = "Close"
    $buttonClose.Location = New-Object Drawing.Point(10, $yPos)
    $buttonClose.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $panel.Controls.Add($buttonClose)

    $form.StartPosition = "CenterScreen"
    $form.Topmost = $true

    $form.ShowDialog()
}

function Show-CheckingPopup {
    $popup = New-Object Windows.Forms.Form
    $popup.Text = "Checking"
    $popup.Size = New-Object System.Drawing.Size(300, 100)
    $popup.StartPosition = "CenterScreen"

    $textBox = New-Object Windows.Forms.TextBox
    $textBox.Text = "Checking Node P2P...."
    $textBox.ReadOnly = $true
    $textBox.Multiline = $true
    $textBox.BackColor = $popup.BackColor
    $textBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $textBox.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',10,[System.Drawing.FontStyle]::Bold)
    $textBox.Dock = 'Fill'
    $popup.Controls.Add($textBox)

    $popupControl = @{
        Form = $popup
        TextBox = $textBox
    }

    return $popupControl
}

function Close-CheckingPopup {
    param ($popupControl)

    $popupControl.Form.Close()
}

function Send-PostRequest {
    param (
        [string]$address,
        [hashtable]$body,
        [string]$brsVersion
    )

    if ($address -notmatch ":\d+$") {
        $address += ":8123"
    }

    $uri = "http://${address}"
    $headers = @{
        "Content-Type" = "application/json"
        "User-Agent" = "BRS/$brsVersion"
    }

    Write-Host "Sending POST request to ${uri} with body:" -ForegroundColor Yellow
    Write-Host ($body | ConvertTo-Json -Depth 10) -ForegroundColor Yellow

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body ($body | ConvertTo-Json)
        Write-Host "Raw response from ${uri}:" -ForegroundColor Green
        Write-Host ($response | ConvertTo-Json -Depth 10) -ForegroundColor Green

        if ($response -eq $null -or $response.psobject.Properties.Count -eq 0) {
            return "Web server error"
        }

        return $response | ConvertTo-Json -Depth 10 | Out-String
    } catch {
        Write-Error "Failed to send POST request to ${uri}. Error: $_"
        if ($_.Exception.Response) {
            $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $errorResponse = $streamReader.ReadToEnd()
            Write-Host "Error Response Body: $errorResponse" -ForegroundColor Red
            return "Error: $($_.Exception.Message)`nError Response Body: $errorResponse"
        }
        return "Error: $($_.Exception.Message)"
    }
}

$input = Create-InputForm
if ($input -ne $null) {
    $address = $input.Address
    $brsVersion = $input.BRSVersion
    if (-not $brsVersion) {
        $brsVersion = "3.8.4"
    }

    # Ensure the address has a port
    if ($address -notmatch ":\d+$") {
        $address += ":8123"
    }

    $endpoints = @(
        "getPeers",
        "getInfo",
        "getCumulativeDifficulty",
        "getNextBlockIds"
    )

    $responses = @{}
    $snrPassed = $false
    $p2pPassed = $false

    $popupControl = Show-CheckingPopup
    $popupControl.Form.Show()

    Start-Sleep -Seconds 2  # Add a delay to ensure the popup is displayed

    foreach ($endpoint in $endpoints) {
        $body = @{
            "requestType" = $endpoint
            "protocol" = "B1"
        }

        $response = Send-PostRequest -address $address -body $body -brsVersion $brsVersion

        if ($response) {
            Write-Host "Storing response for endpoint ${endpoint}:" -ForegroundColor Cyan
            Write-Host $response -ForegroundColor Cyan
            $responses[$endpoint] = $response

            if ($endpoint -eq "getInfo") {
                $getInfoResponse = $response | ConvertFrom-Json
                if (($getInfoResponse.announcedAddress -eq $address) -and ([regex]::IsMatch($getInfoResponse.platform, "^S-", 'IgnoreCase'))) {
                    $snrPassed = $true
                }
                if ($getInfoResponse.application -eq "BRS") {
                    $p2pPassed = $true
                }
            }
        } else {
            Write-Host "No response from ${endpoint}." -ForegroundColor Red
            $responses[$endpoint] = "No response from ${endpoint}."
        }
    }

    Close-CheckingPopup -popupControl $popupControl

    Create-ResponseForm -responses $responses -snrPassed $snrPassed -p2pPassed $p2pPassed
}
