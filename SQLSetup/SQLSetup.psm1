<#
	My Function
#>
function Set-SQLServerMemory {

}


function Set-AnalysisServicesMemory {

}

<#

-- find the tempdb drive, if its spread across more that one drive then bail

-- get the size of the drive 

-- divide the size of the dri

#>

<# Get the drive letter for tempdb, bail if tempdb data files are on more than one drive  #>
function Get-TempDbDrive () 
{
    Param
    (
        [parameter(Mandatory=$True)][string] $ServerInstance
    )

    $sql = "SELECT  DISTINCT
            LEFT(physical_name, CHARINDEX(':', physical_name)) AS TempDbDataDrive
    FROM    sys.master_files
    WHERE   type_desc = 'ROWS'
            AND database_id = DB_ID('tempdb');"

    $tempDBDriveLetters = Invoke-SqlCmd -ServerInstance $ServerInstance -Database master -Query $sql

    if ($tempDBDriveLetters.ItemArray.Count -eq 1) {
        $TempDBDrive = $tempDBDriveLetters[0] 
    }
    else {
        throw [Exception] "TempDB Data files are on more than one drive"
    }

    return $TempDBDrive

}



<# Get the drive size and free space of the drive passed in #>
ffunction Get-TempDbDriveSize {
 [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [String]$TempDbDataDrive
   ) 

   if (-not $TempDbDataDrive.EndsWith(':')) {
	$TempDbDataDrive + ":"
   }

	$DataDriveStats = Get-WMIObject Win32_Logicaldisk -filter "deviceid='C:'"  | Select @{Name="SizeGB";Expression={$_.Size/1GB -as [int]}},
	@{Name="FreeGB";Expression={[math]::Round($_.Freespace/1GB,2)}},@{Name="SizeMB";Expression={$_.Size/1MB -as [int]}} 

	return $DataDriveStats
}


<# 
calculate the size of an individual tempdb data file based on the number of files specified, the amount of free
space to leave on the tempdb data drive and the size of the tempdb data file drive
#>
function Get-TempDataFileSize  {
    Param
    (
		[parameter(Mandatory=$True)][string] $ServerInstance = "(local)",
        [parameter(Mandatory=$False)][int32] $TempDbFileCount,
		[parameter(Mandatory=$False)][int32] $TempDbDriveFreeSpacePctToLeave = 15 # leave 15% free space on drive
    )
	
	$TempDrive = Get-TempDbDrive -ServerInstance $ServerInstance
	$TempDriveStats = Get-TempDDriveSize -TempDbDataDrive $TempDrive

	$SpaceToLeave = ($TempDbDriveFreeSpacePctToLeave/100) * $TempDriveStats.SizeGB
	$TempDbFileSize = [math]::round(($TempDriveStats.SizeGB - $SpaceToLeave) / $TempDbFileCount)

	return $TempDbFileSize
}


<#output a script to set the tempdb database size #>
function Set-TempDbSize  {
    Param
    (
		[parameter(Mandatory=$True)][string] $ServerInstance = "(local)",
        [parameter(Mandatory=$False)][int32] $TempDbFileCount = 8,
		[parameter(Mandatory=$False)][int32] $TempDbDriveFreeSpacePctToLeave = 15, # leave 15% free space on drive
		[parameter(Mandatory=$False)][int32] $LogFileSizeMB = 5000 # 5GB log 
    )
	
	$TempDrive = Get-TempDbDrive -ServerInstance $ServerInstance
	$TempDriveStats = Get-TempDbDriveSize -TempDbDataDrive $TempDrive

	$SpaceToLeave = ($TempDbDriveFreeSpacePctToLeave/100) * $TempDriveStats.SizeMB
    $TempDbSpace = [math]::round(($TempDriveStats.SizeMB - $SpaceToLeave))

    Set-SqlTempDbConfiguration -SqlServer saltwick -DataFileSizeMB $TempDbSpace -DataFileCount $TempDbFileCount -Script #-LogFileSizeMB 
}


