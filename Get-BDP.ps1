# tool to calculate Bandwidth Delay Product
[CmdletBinding()]
param (
    [decimal]$bdp,
    [decimal]$rtt,
    [decimal]$b,
    [switch]$min,
    [switch]$ui,
    [switch]$demo
)


#region FUNCTIONS

 <#
FORMULAS:

BDP = Bandwidth Delay Product in bytes = RWIN (Recieve Window) = In-Flight data
B = Bandwidth in bps
RTT = Round-Trip Time in ms (converted to decimal seconds)


BDP = B * RTT

B = BDP / RTT

RTT = BDP / B

1B (byte) = 8b (bits)
#>

# FUNCTION: Find-BDP
# PURPOSE: Calculates BDP given rtt(ms) and bandwidth (bps)
# OUTPUT: BDP(Bytes)
function Find-BDP
{
    param(
        [decimal]$rtt = $null,
        [decimal]$b = $null
    )

    # ms to decimal seconds
    $rtt = $rtt / 1000

    return ( ($b * $rtt) / 8 )
} #end Find-BDP


# FUNCTION: Find-Bandwidth
# PURPOSE: Calculates Bandwidth given rtt(ms) and BDP(Bytes)
# OUTPUT: B(bps)
function Find-Bandwidth
{
    param(
        [decimal]$rtt = $null,
        [decimal]$bdp = $null
    )

    # ms to decimal seconds
    $rtt = $rtt / 1000

    return ( ($bdp / $rtt)  * 8 )
} #end Find-Bandwidth

# FUNCTION: Find-RTT
# PURPOSE: Calculates RTT given B(bps) and BDP(Bytes)
# OUTPUT: B(bps)
function Find-RTT
{
    param(
        [decimal]$b = $null,
        [decimal]$bdp = $null
    )

    return ( ($bdp / $b)  * 8 * 1000)  
} #end Find-RTT


function Set-Formula
{
    param(
        $bdp = -1.0,
        $b = -1.0,
        $rtt = -1.0,
        $min = $false
    )

    if ($bdp -eq -1.0)
    {
        Write-Verbose "Finding BDP"
        $bdp = Find-BDP -rtt $rtt -b $b
        Write-Verbose "Raw BDP = $bdp"

        if ($bdp -ge 1GB -and !$min)
        {
            $bdp = $bdp / 1GB
            $unit = "GB"
        }
        elseif ($bdp -ge 1MB -and !$min)
        {
            $bdp = $bdp / 1MB
            $unit = "MB"
        }
        else
        {
            $unit = "B"
        }
        Write-Verbose "Unit = $unit"

        if ($min)
        {
            $bdp = [math]::ROUND($bdp)
            Write-Verbose "Returning: BDP = $($bdp.ToString("#")) $unit"
            return "BDP = $($bdp.ToString("#")) $unit"
        }
        else 
        {
            $bdp = [math]::ROUND($bdp, 3)
            Write-Verbose "Returning: BDP = $($bdp.ToString("#.###")) $unit"
            return "BDP = $($bdp.ToString("#.###")) $unit"    
        }

        
    }
    elseif ($rtt -eq -1.0)
    {
        Write-Verbose "Finding RTT"
        $rtt = Find-RTT -b $b -bdp $bdp

        $rtt = [math]::ROUND($rtt)
        Write-Verbose "Returning: RTT = $($rtt.ToString("#")) ms"
        return "RTT = $($rtt.ToString("#")) ms"
    }
    elseif ($b -eq -1.0) 
    {
        Write-Verbose "Finding Bandwidth"
        $b = Find-Bandwidth -rtt $rtt -bdp $bdp
        Write-Verbose "Raw Bandwidth = $b"

        if ($b -ge 1000000000 -and !$min)
        {
            $b = $b / 1000000000
            $unit = "Gbps"
        }
        elseif ($b -ge 1000000 -and !$min)
        {
            $b = $b / 1000000
            $unit = "Mbps"
        }
        elseif ($b -ge 1000 -and !$min)
        {
            $b = $b / 1000
            $unit = "Kbps"
        }
        else
        {
            $unit = "bps"
        }

        Write-Verbose "Unit = $unit"

        if ($min)
        {
            $b = [math]::ROUND($b)
            Write-Verbose "Returning: B = $($b.ToString("#")) $unit"
            return "B = $($b.ToString("#")) $unit"
        }
        else 
        {
            $b = [math]::ROUND($b, 3)
            Write-Verbose "Returning: B = $($b.ToString("#.###")) $unit"
            return "B = $($b.ToString("#.###")) $unit"
        }
    }

    return $null
}


#endregion FUNCTIONS


if ($demo -or $ui)
{
    # start the UI
    Write-Verbose "Starting UI."

    Add-Type -AssemblyName PresentationFramework

    # where is the XAML file?
    $xamlFile = ".\MainWindow.xaml"

    #create window
    $inputXML = Get-Content $xamlFile -Raw
    $inputXML = $inputXML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
    [XML]$XAML = $inputXML

    #Read XAML
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    try {
        $window = [Windows.Markup.XamlReader]::Load( $reader )
    } catch {
        Write-Warning $_.Exception
        throw
    }

    # Create variables based on form control names.
    # Variable will be named as 'var_<control name>'

    $xaml.SelectNodes("//*[@Name]") | ForEach-Object {
        #"trying item $($_.Name)"
        try {
            Set-Variable -Name "$($_.Name)" -Value $window.FindName($_.Name) -ErrorAction Stop
        } catch {
            throw
        }
    }
    Get-Variable wpf_*

    
    #region UI FUNCTIONS
    function Find-Answer
    {
        # check wpf_tbBndwdth for value
        Write-Verbose "Bandwidth"
        $tmpB = $wpf_tbBndwdth.Text

        if ($tmpB -ne "")
        {
            try 
            {
                $b = [decimal]::Parse($tmpB)
                Write-Verbose "B (raw) = $b"
            }
            catch 
            {
                throw
                $window.Close()
            }

            Write-Verbose "B selection = $($wpf_cbxBndwdth.SelectedItem.Content)"
            switch ($wpf_cbxBndwdth.SelectedItem.Content)
            {
                "Gbps" { $b = $b * 1000000000 }
                "Mbps" { $b = $b * 1000000 }
                "Kbps" { $b = $b * 1000 }
                default { $b = $b }
            }

            Write-Verbose "B = $b"
        }
        else 
        {
            $b = -1.0    
        }

        # check wpf_tbRTT for value
        Write-Verbose "RTT"
        $tmpRTT = $wpf_tbRTT.Text

        if ($tmpRTT -ne "")
        {
            try 
            {
                $rtt = [decimal]::Parse($tmpRTT)
                Write-Verbose "RTT = $rtt"
            }
            catch 
            {
                throw
                $window.Close()
            }
        }
        else 
        {
            $rtt = -1.0    
        }

        # check wpf_tbBDP for value
        Write-Verbose "BDP"
        $tmpBDP = $wpf_tbBDP.Text

        if ($tmpBDP -ne "")
        {
            try 
            {
                $bdp = [decimal]::Parse($tmpBDP)
                Write-Verbose "BDP = $bdp"
            }
            catch 
            {
                throw
                $window.Close()
            }

            Write-Verbose "BDP selection = $($wpf_cbxBDP.SelectedItem.Content)"
            switch ($wpf_cbxBDP.SelectedItem.Content)
            {
                "GB" { $bdp = $bdp * 1GB }
                "MB" { $bdp = $bdp * 1MB }
                "KB" { $bdp = $bdp * 1KB }
                default { $bdp = $bdp }
            }

            Write-Verbose "BDP = $bdp"
        }
        else 
        {
            $bdp = -1.0    
        }

        $result = Set-Formula -bdp $bdp -b $b -rtt $rtt -min $min.IsPresent
        Write-Verbose "Result = $result"

        $wpf_tbxResult.Text = $result

        Write-Verbose "Calculation complete."
    }

    #endregion UI FUNCTIONS


    # Enter key action
    $window.Add_KeyDown({
        #Write-Host "$($_ | fl * | Out-String)"
        if ($_.Key -eq "Enter") 
        {
            Find-Answer
        }
    })

    # Calculate button action
    $wpf_btnCalc.Add_Click({
        Find-Answer
    })


    # set focus to bandwidth textbox
    $wpf_tbBndwdth.Focus()

    # show dialog
    $Null = $window.ShowDialog()
}