param(
	[string]$RRDToolPath = "Undefined"
)

If ($RRDToolPath -eq "Undefined") {
	$RRDTool = '{0}\bin\rrdtool.exe' -f $PSScriptRoot
} Else {
    $RRDTool = $RRDToolPath
}

try {
    & $RRDTool | Out-Null
} catch {
    Write-Error ("$RRDTool isn't a valid location for rrdtool.exe")
    break
}

Function Invoke-NativeCommand {
    Param(
        [String] $Command,
        [switch] $SuppressOutput
    )
    $cmd = '{0} 2>&1' -f $Command
    $Result = Invoke-Expression -Command $cmd
    $Result | %{ $err = '' } {
        if ($_.WriteErrorStream) {
            $err += [string] $_
        } else {
            if (-not $SuppressOutput) {$_}
        }
    } {
        if ($err -ne '') {
            Write-Error $err
        }
    }
}

Function New-RRD {
    Param(
        [Parameter(Mandatory)]
        [String] $FileName,
        [DateTime] $Start = ((Get-Date).AddSeconds(-10)),
        [int] $Step = 300,
        [Parameter(Mandatory)]
        [PSCustomObject[]] $DS,
        [Parameter(Mandatory)]
        [PSCustomObject[]] $RRA
    )

    $StartUnixTime = [int][double]::Parse((Get-Date $Start.ToUniversalTime() -UFormat %s))
    $DSs = $DS -join ' '
    $RRAs = $RRA -join ' '
    $cmd = '{0} create {1} --step {2} --start {3} {4} {5}' -f $RRDTool, $FileName, $Step, $StartUnixTime, $DSs, $RRAs

    Write-Verbose $cmd

    try {
        Invoke-NativeCommand -Command $cmd -SuppressOutput
    } catch {
        Write-Error $Error
    }
}

Function New-RRDDataSource {
    Param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-zA-Z0-9_]{1,19}$')]
        [String] $Name,
        [Parameter(Mandatory)]
        [ValidateSet('GAUGE', 'COUNTER', 'DERIVE', 'DCOUNTER', 'DDERIVE', 'COMPUTE')]
        [alias('DST')]
        [String] $DataSourceType,
        [Parameter(ParameterSetName='NoCompute', Mandatory)]
        [int] $Heartbeat,
        [Parameter(ParameterSetName='NoCompute')]
        $Min = 'U',
        [Parameter(ParameterSetName='NoCompute')]
        $Max = 'U',
        [Parameter(ParameterSetName='Compute', Mandatory)]
        [Scriptblock] $Expression
    )

    $DS = [ordered] @{
        Name = $Name
        DST = $DataSourceType
    }

    if ($PSCmdlet.ParameterSetName -eq 'NoCompute') {
        $DS['Heartbeat'] = $Heartbeat
        $DS['Min'] = $Min
        $DS['Max'] = $Max
    } elseif ($PSCmdlet.ParameterSetName -eq 'Compute') {
        $DS['Expression'] = $Expression
    }

    Write-Output (ConvertFrom-RRD -Object $DS -Type 'DS:')
}

Function New-RRDRoundRobinArchive {
    Param(
        [Parameter(Mandatory)]
        [ValidateSet('AVERAGE', 'MIN', 'MAX', 'LAST')]
        [alias('CF')]
        [String] $ConsolidationFunction,
        [ValidateRange(0,1)]
        [float] $XFilesFactor = 0.5,
        [Parameter(Mandatory)]
        [int] $Steps,
        [Parameter(Mandatory)]
        [int] $Rows
    )

    $RRA = [ordered] @{
        CF = $ConsolidationFunction
        XFF = "$XFilesFactor"
        Steps = $Steps
        Rows = $Rows
    }

    Write-Output (ConvertFrom-RRD -Object $RRA -Type 'RRA:')
}

Function New-RRDPrint {
    Param(
        [Parameter(Mandatory)]
        [String] $Name,
        [Parameter(Mandatory)]
        [String] $Format
    )

    $PRINT = [ordered] @{
        Name = $Name
        Format = '"{0}"' -f ($Format -replace ':', '\:')
    }

    Write-Output (ConvertFrom-RRD -Object $PRINT -Type 'PRINT:')
}

Function New-RRDGPrint {
    Param(
        [Parameter(Mandatory)]
        [String] $Name,
        [Parameter(Mandatory)]
        [String] $Format
    )

    $GPRINT = [ordered] @{
        Name = $Name
        Format = '"{0}"' -f ($Format -replace ':', '\:')
    }

    Write-Output (ConvertFrom-RRD -Object $GPRINT -Type 'GPRINT:')
}

Function New-RRDComment {
    Param(
        [Parameter(Mandatory)]
        [String] $Text
    )
    
    $COMMENT = [ordered] @{
        Text = '"{0}"' -f ($Text -replace ':', '\:')
    }

    Write-Output (ConvertFrom-RRD -Object $COMMENT -Type 'COMMENT:')
}

Function New-RRDShift {
    Param(
        [Parameter(Mandatory)]
        [String] $Name,
        [Parameter(Mandatory)]
        [int] $Offset
    )

    $SHIFT = [ordered] @{
        Name = $Name
        Offset = $Offset
    }

    Write-Output (ConvertFrom-RRD -Object $SHIFT -Type 'SHIFT:')
}

Function New-RRDTick {
    Param(
        [Parameter(Mandatory)]
        [String] $Name,
        [Parameter(Mandatory)]
        [ValidatePattern('^#[\da-fA-F]{6}([\da-fA-F]{2})?$')]
        [String] $Color,
        [float] $Fraction,
        [String] $Legend
    )

    $TICK = [ordered] @{
        Name = '{0}{1}' -f $Name, $Color
    }

    if ($Fraction) {$TICK['Fraction'] = $Fraction}
    if ($Legend -and -not $Fraction) {
        $TICK['Fraction'] = $null
        $TICK['Legend'] = $Legend
    } elseif ($Legend) {
        $TICK['Legend'] = $Legend
    }

    Write-Output (ConvertFrom-RRD -Object $TICK -Type 'TICK:')
}

Function New-RRDHRule {
    Param(
        [Parameter(Mandatory)]
        [String] $Value,
        [Parameter(Mandatory)]
        [ValidatePattern('^#[\da-fA-F]{6}([\da-fA-F]{2})?$')]
        [String] $Color,
        [String] $Legend
    )

    $HRULE = [ordered] @{
        Value = '{0}{1}' -f $Value, $Color
    }
    if ($Legend) {$HRULE['Legend'] = $Legend}

    Write-Output (ConvertFrom-RRD -Object $HRULE -Type 'HRULE:')
}

Function New-RRDVRule {
    Param(
        [Parameter(Mandatory)]
        [String] $Value,
        [Parameter(Mandatory)]
        [ValidatePattern('^#[\da-fA-F]{6}([\da-fA-F]{2})?$')]
        [String] $Color,
        [String] $Legend
    )
    
    $VRULE = [ordered] @{
        Value = '{0}{1}' -f $Value, $Color
    }
    if ($Legend) {$VRULE['Legend'] = $Legend}

    Write-Output (ConvertFrom-RRD -Object $VRULE -Type 'VRULE:')
}

Function New-RRDLine {
    Param(
        [Parameter(Mandatory)]
        [String] $Name,
        [float] $Width = 1,
        [ValidatePattern('^#[\da-fA-F]{6}([\da-fA-F]{2})?$')]
        [String] $Color,
        [String] $Legend,
        [switch] $Stack
    )

    $LINE = [ordered] @{
        Width = "$Width"
        Name = $Name
    }
    
    if ($Color) {$LINE['Name'] += $Color}
    if ($Legend) {$LINE['Legend'] = '"{0}"' -f $Legend}
    if ($Stack -and -not $Legend) {
        $LINE['Legend'] = $null
        $LINE['Stack'] = 'STACK'
    } elseif ($Stack) {
        $LINE['Stack'] = 'STACK'
    }

    Write-Output (ConvertFrom-RRD -Object $LINE -Type 'LINE')
}

Function New-RRDArea {
    Param(
        [Parameter(Mandatory)]
        [String] $Name,
        [ValidatePattern('^#[\da-fA-F]{6}([\da-fA-F]{2})?$')]
        [String] $Color,
        [String] $Legend,
        [switch] $Stack
    )

    $AREA = [ordered] @{
        Name = $Name
    }
    
    if ($Color) {$AREA['Name'] += $Color}
    if ($Legend) {$AREA['Legend'] = '"{0}"' -f $Legend}
    if ($Stack -and -not $Legend) {
        $AREA['Legend'] = $null
        $AREA['Stack'] = 'STACK'
    } elseif ($Stack) {
        $AREA['Stack'] = 'STACK'
    }

    Write-Output (ConvertFrom-RRD -Object $AREA -Type 'AREA:')
}

Function New-RRDDef {
    Param(
        [Parameter(Mandatory)]
        [String] $Name,
        [Parameter(Mandatory)]
        [String] $FileName,
        [Parameter(Mandatory)]
        [String] $DataSource,
        [Parameter(Mandatory)]
        [ValidateSet('AVERAGE', 'MIN', 'MAX', 'LAST')]
        [alias('CF')]
        [String] $ConsolidationFunction,
        [int] $Step,
        [DateTime] $Start,
        [DateTime] $End,
        [ValidateSet('AVERAGE', 'MIN', 'MAX', 'LAST')]
        [String] $Reduce
    )

    $DEF = [ordered] @{
        Name = '{0}={1}' -f $Name, ($FileName -replace ':', '\:')
        DS = $DataSource
        CF = $ConsolidationFunction
    }

    if ($Step) {$DEF['Step'] = 'step={0}' -f $Step}
    if ($Start) {$DEF['Start'] = 'start={0}' -f [int][double]::Parse((Get-Date $Start.ToUniversalTime() -UFormat %s))}
    if ($End) {$DEF['End'] = 'end={0}' -f [int][double]::Parse((Get-Date $End.ToUniversalTime() -UFormat %s))}
    if ($Reduce) {$DEF['Reduce'] = 'reduce={0}' -f $Reduce}

    Write-Output (ConvertFrom-RRD -Object $DEF -Type 'DEF:')
}

Function New-RRDVdef {
    Param(
        [Parameter(Mandatory)]
        [String] $Name,
        [Parameter(Mandatory)]
        [String] $RPNExpression
    )

    $VDEF = [ordered] @{
        Name = '{0}="{1}"' -f $Name, $RPNExpression
    }

    Write-Output (ConvertFrom-RRD -Object $VDEF -Type 'VDEF:')
}

Function New-RRDCdef {
    Param(
        [Parameter(Mandatory)]
        [String] $Name,
        [Parameter(Mandatory)]
        [String] $RPNExpression
    )

    $CDEF = [ordered] @{
        Name = '{0}={1}' -f $Name, $RPNExpression
    }

    Write-Output (ConvertFrom-RRD -Object $CDEF -Type 'CDEF:')
}

Function Update-RRD {
    Param(
        [Parameter(Mandatory)]
        [ValidateScript({Test-Path $_})]
        [String] $FileName,
        [DateTime] $Timestamp = (Get-Date),
        [object[]] $Value
    )

    $UnixTime = [int][double]::Parse((Get-Date $Timestamp.ToUniversalTime() -UFormat %s))
    $cmd = '{0} update {1} {2}:{3}' -f $RRDTool, $FileName, $UnixTime, ($Value -replace ',','.' -join ':')
    Write-Verbose $cmd

    try {
        Invoke-NativeCommand -Command $cmd -SuppressOutput
    } catch {
        Write-Error $Error
    }
}

Function Out-RRDGraph {
    Param(
        [Parameter(Mandatory)]
        [String] $FileName,
        [DateTime] $Start,
        [DateTime] $End,
        [String] $XGrid,
        [switch] $AltYGrid,
        [String] $YGrid,
        [String] $VerticalLabel,
        [int] $Width,
        [String] $RightAxis,
        [String] $RightAxisLabel,
        [String] $RightAxisFormat,
        [int] $Height,
        [switch] $Logarithmic,
        [double] $UpperLimit,
        [double] $LowerLimit,
        [switch] $Lazy,
        [switch] $Rigid,
        [switch] $NoLegend,
        [switch] $ForceRulesLegend,
        [switch] $OnlyGraph,
        [ValidatePattern('^(DEFAULT|TITLE|AXIS|UNIT|LEGEND):\d+(:.*)?$')]
        [String[]] $Font,
        [ValidateScript({$_ -gt 0})]
        [int] $Zoom,
        [switch] $AltAutoscale,
        [switch] $AltAutoscaleMax,
        [ValidateSet('NORMAL', 'LIGHT', 'MONO')]
        [String] $FontRenderMode,
        [float] $FontSmoothingThreshold,
        [switch] $SlopeMode,
        [switch] $NoGridfit,
        [ValidateSet(-18,-15,-12,-9,-6,-3,0,3,6,9,12,15,18)]
        [int] $UnitsExponent,
        [int] $UnitsLength,
        [int] $Step,
        [String] $Imginfo,
        [ValidateSet('PNG','SVG','EPS','PDF','XML','XMLENUM','JSON','JSONTIME','CSV','TSV','SSV')]
        [String] $Imgformat,
        [ValidatePattern('^(BACK|CANVAS|SHADEA|SHADEB|GRID|MGRID|FONT|AXIS|FRAME|ARROW)#[\da-fA-F]{6}([\da-fA-F]{2})?$')]
        [String[]] $Color,
        [String] $Title,
        [String] $Watermark,
        [Parameter(Mandatory)]
        [object[]] $Elements
    )

    $param = ''
    if ($Start -ne $null) {$param += ' --start {0}' -f ([int][double]::Parse((Get-Date $Start.ToUniversalTime() -UFormat %s)))}
    if ($End -ne $null) {$param += ' --end {0}' -f ([int][double]::Parse((Get-Date $End.ToUniversalTime() -UFormat %s)))}
    if ($XGrid) {$param += ' --x-grid "{0}"' -f $XGrid}
    if ($AltYGrid) {$param += ' --alt-y-grid'}
    if ($YGrid) {$param += ' --y-grid "{0}"' -f $YGrid}
    if ($VerticalLabel) {$param += ' --vertical-label "{0}"' -f $VerticalLabel}
    if ($Width) {$param += ' --width {0}' -f $Width}
    if ($RightAxis) {$param += ' --right-axis {0}' -f $RightAxis}
    if ($RightAxisLabel) {$param += ' --right-axis-label "{0}"' -f $RightAxisLabel}
    if ($RightAxisFormat) {$param += ' --right-axis-format "{0}"' -f $RightAxisFormat}
    if ($Height) {$param += ' --height {0}' -f $Height}
    if ($Logarithmic) {$param += ' --logarithmic'}
    if ($UpperLimit) {$param += ' --upper-limit {0}' -f $UpperLimit}
    if ($PSBoundParameters.ContainsKey('LowerLimit')) {$param += ' --lower-limit {0}' -f $LowerLimit}
    if ($Lazy) {$param += ' --lazy'}
    if ($Rigid) {$param += ' --rigid'}
    if ($NoLegend) {$param += ' --no-legend'}
    if ($ForceRulesLegend) {$param += ' --force-rules-legend'}
    if ($OnlyGraph) {$param += ' --only-graph'}
    if ($Font) {$param += $Font | %{' --font {0}' -f $_}}
    if ($Zoom) {$param += ' --zoom {0}' -f $Zoom}
    if ($AltAutoscale) {$param += ' --alt-autoscale'}
    if ($AltAutoscaleMax) {$param += ' --alt-autoscale-max'}
    if ($FontRenderMode) {$param += ' --font-render-mode {0}' -f $FontRenderMode}
    if ($FontSmoothingThreshold) {$param += ' --font-smoothing-threshold {0}' -f $FontSmoothingThreshold}
    if ($SlopeMode) {$param += ' --slope-mode'}
    if ($NoGridfit) {$param += ' --no-gridfit'}
    if ($UnitsExponent) {$param += ' --units-exponent {0}' -f $UnitsExponent}
    if ($UnitsLength) {$param += ' --units-length {0}' -f $UnitsLength}
    if ($Step) {$param += ' --step {0}' -f $Step}
    if ($Imginfo) {$param += ' --imginfo "{0}"' -f $Imginfo}
    if ($Imgformat) {$param += ' --imgformat "{0}"' -f $Imgformat}
    if ($Color) {$param += $Color | %{' --color "{0}"' -f $_}}
    if ($Title) {$param += ' --title "{0}"' -f $Title}
    if ($Watermark) {$param += ' --watermark "{0}"' -f $Watermark}

    $cmd = '{0} graph {1} {2} {3}' -f $RRDTool, $FileName, $param, ($Elements -join ' ')
    Write-Verbose $cmd

    try {
        Invoke-NativeCommand -Command $cmd -SuppressOutput
    } catch {
        Write-Error $Error
    }

}

Function ConvertFrom-RRD {
    Param(
        [Parameter(ValueFromPipeline)]
        [PSCustomObject[]] $Object,
        [ValidateSet('DS:','RRA:','DEF:','CDEF:','VDEF:','AREA:','COMMENT:','GPRINT:','HRULE:','LINE','PRINT:','SHIFT:','TICK:','VRULE:')]
        [String] $Type
    )

    PROCESS {
        foreach ($Obj in $Object) {
            $ret = @()
            foreach ($Val in $Obj.Values) {
                $ret += $Val
            }
            Write-Output ('{0}{1}' -f $Type, ($ret -join ':'))
        }
    }
}


Export-ModuleMember -Function New-RRD
Export-ModuleMember -Function New-RRDArea
Export-ModuleMember -Function New-RRDCDef
Export-ModuleMember -Function New-RRDComment
Export-ModuleMember -Function New-RRDDataSource
Export-ModuleMember -Function New-RRDDef
Export-ModuleMember -Function New-RRDGPrint
Export-ModuleMember -Function New-RRDHRule
Export-ModuleMember -Function New-RRDLine
Export-ModuleMember -Function New-RRDPrint
Export-ModuleMember -Function New-RRDRoundRobinArchive
Export-ModuleMember -Function New-RRDShift
Export-ModuleMember -Function New-RRDTick
Export-ModuleMember -Function New-RRDVDef
Export-ModuleMember -Function New-RRDVRule
Export-ModuleMember -Function Out-RRDGraph
Export-ModuleMember -Function Update-RRD