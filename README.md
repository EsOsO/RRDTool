# RRDTool

#### WARNING
This module is compatible only with rrdtool-1.2.30-win32 right now; 1.2.30 is the last win32 build officialy distributed by Tobias Oetiker

### Abstract
Provide a wrapper around rrdtool.exe (http://oss.oetiker.ch/rrdtool/)

### Installation
* Download the module from [github](https://github.com/EsOsO/RRDTool/archive/master.zip)
* Place the folder RRDTool in your `$PSModulePath` (eg. `%ProgramFiles%\WindowsPowerShell\Modules`)
* Download [rrdtool-1.2.30-win32-perl510.zip](http://oss.oetiker.ch/rrdtool/pub/rrdtool-1.2.30-win32-perl510.zip), extract rrdtool.exe (rrdtool-1.2.30-win32-perl510.zip\data\rrd2\rrdtool-1.2.30\Release) and drop it in the bin folder inside RRDTool Powershell Module  (eg. `%ProgramFiles%\WindowsPowerShell\Modules\RRDTool\bin`)

### Usage

#### RRD file creation
```
$DataSource1 = New-RRDDataSource -Name cpu_kernel -DataSourceType GAUGE -Heartbeat 120 -Min 0 -Max 100
$DataSource2 = New-RRDDataSource -Name cpu_user -DataSourceType GAUGE -Heartbeat 120 -Min 0 -Max 100
$DataSource3 = New-RRDDataSource -Name cpu_queue -DataSourceType GAUGE -Heartbeat 120 -Min 0

$AVERAGE_0 = New-RRDRoundRobinArchive -ConsolidationFunction AVERAGE -Steps 1 -Rows 1440     # 1 day, 1 min pdp
$AVERAGE_1 = New-RRDRoundRobinArchive -ConsolidationFunction AVERAGE -Steps 5 -Rows 2016     # 1 week, 5 min pdp
$AVERAGE_2 = New-RRDRoundRobinArchive -ConsolidationFunction AVERAGE -Steps 60 -Rows 720     # 1 month, 1 hour pdp
$AVERAGE_3 = New-RRDRoundRobinArchive -ConsolidationFunction AVERAGE -Steps 60 -Rows 8760    # 1 year, 1 hour pdp

New-RRD -FileName C:\Temp\cpu.rrd `
        -Step 60 `
        -DS $Datasource1, $DataSource2, $DataSource3 `
        -RRA $AVERAGE_0, $AVERAGE_1, $AVERAGE_2, $AVERAGE_3
```

#### RRD update values
```
$Values = Get-Counter -ComputerName $ComputerName -Counter '\Processor(_total)\% Privileged Time', '\Processor(_total)\% User Time', '\System\Processor Queue Length' | select -ExpandProperty CounterSamples | select -ExpandProperty CookedValue
Update-RRD -FileName C:\Temp\cpu.rrd -Value $Values
```

#### RRD Graph creation
```
Elements = @(
    New-RRDDef -Name 'cpu_kernel' -FileName $CpuRRD -DataSource 'cpu_kernel' -ConsolidationFunction AVERAGE
    New-RRDDef -Name 'cpu_user' -FileName $CpuRRD -DataSource 'cpu_user' -ConsolidationFunction AVERAGE
    New-RRDDef -Name 'cpu_queue' -FileName $CpuRRD -DataSource 'cpu_queue' -ConsolidationFunction AVERAGE

    New-RRDLine -Name 'cpu_kernel' -Color '#FE343E' -Legend '% CPU Kernel Time'
    New-RRDLine -Name 'cpu_user' -Color '#6B46EC' -Legend '% CPU User Time'
    New-RRDLine -Name 'cpu_queue' -Color '#44F432' -Legend 'Processor Queue Lenght'

    New-RRDVdef -Name 'cpukernel_max' -RPNExpression 'cpu_kernel,MAXIMUM'
    New-RRDVdef -Name 'cpukernel_avg' -RPNExpression 'cpu_kernel,AVERAGE'
    New-RRDVdef -Name 'cpukernel_last' -RPNExpression 'cpu_kernel,LAST'
    New-RRDComment -Text '\n'
    New-RRDComment -Text '% CPU Kernel Time:'
    New-RRDComment -Text '\n'
    New-RRDGPrint -Name 'cpukernel_max' -Format 'Max:\t%12.2lf%s'
    New-RRDGPrint -Name 'cpukernel_avg' -Format 'Avg:\t%12.2lf%s'
    New-RRDGPrint -Name 'cpukernel_last' -Format 'Last:\t%12.2lf%s'

    New-RRDVdef -Name 'cpuuser_max' -RPNExpression 'cpu_user,MAXIMUM'
    New-RRDVdef -Name 'cpuuser_avg' -RPNExpression 'cpu_user,AVERAGE'
    New-RRDVdef -Name 'cpuuser_last' -RPNExpression 'cpu_user,LAST'
    New-RRDComment -Text '\n'
    New-RRDComment -Text '% CPU User Time'
    New-RRDComment -Text '\n'
    New-RRDGPrint -Name 'cpuuser_max' -Format 'Max:\t%12.2lf%s'
    New-RRDGPrint -Name 'cpuuser_avg' -Format 'Avg:\t%12.2lf%s'
    New-RRDGPrint -Name 'cpuuser_last' -Format 'Last:\t%12.2lf%s'

    New-RRDVdef -Name 'cpuqueued_max' -RPNExpression 'cpu_queue,MAXIMUM'
    New-RRDVdef -Name 'cpuqueued_avg' -RPNExpression 'cpu_queue,AVERAGE'
    New-RRDVdef -Name 'cpuqueued_last' -RPNExpression 'cpu_queue,LAST'
    New-RRDComment -Text '\n'
    New-RRDComment -Text 'Processor Queue Length:'
    New-RRDComment -Text '\n'
    New-RRDGPrint -Name 'cpuqueued_max' -Format 'Max:\t%12.2lf%s'
    New-RRDGPrint -Name 'cpuqueued_avg' -Format 'Avg:\t%12.2lf%s'
    New-RRDGPrint -Name 'cpuqueued_last' -Format 'Last:\t%12.2lf%s'    
)

Out-RRDGraph -FileName C:\Temp\cpu.png -Title 'CPU Usage - Last day' -Start (Get-Date).AddDays(-7) -LowerLimit 0 -UpperLimit 100 -Rigid $true -Elements $Elements -Verbose
```
