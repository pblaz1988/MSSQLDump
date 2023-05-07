# Backup MSSQL databases with PS
# ------------------
#
#
# DESCRIPTION
# ------------------
#
# version alpha00000001-20220814
#
# PREREQUISITES: MSSQL POWERSHELL MODULE!
#                SCRIPT IS TO BE RAN ON THE SAME SERVER AS MSSQL
#
# This script exports all or just selected databases on Microsoft SQL Server,
# pack them into tarball archive and upload the archive to the SMB network
# location (Windows Share).
# Another functionalities are:
# - mounting the network location it the mountpoint is not persistent
# - cleaning up old files (how long backups should be stored - set the number
#   of days in variable)
# 
# It should not be hard to modify the script to suit your needs (upload just on
# hdd, upload to NFS share etc.
#
# >> CAVEATS: Usage of destination and temporary directory. Backup your server
# >> first.
#
#
# TERMS OF USE
# ------------------
#
# 2022, blaz@overssh.si
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to
# deal in the Software without restriction, including without limitation the 
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
# 
#  - The above copyright notice and this permission notice shall be included 
#    in all copies or substantial portions of the Software.
# 
#  - THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS
#    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
#    THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
#    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
#    DEALINGS IN THE SOFTWARE.

# CONFIGURATION
# ------------------

# database instance name (use host_name\instance_name if you wish to backup
# remote database(s)
$DatabaseInstance    = 'SERVERNAME\INSTANCENAME'

# - if DBNamesIncluded is has elements, only listed databases will be saved and
#   DBNames list will be ignored
# - if DBNamesIncluded is empty list, all databases will be saved, but only those
#   that are not listed in DBNamesExcluded

# databases to be included - or use empty array for all databases
# example: $DBNamesIncluded = @('myDatabase1', 'myDatabase2')
$DBNamesIncluded = @()
# databases to be excluded - ignored when DBNamesIncluded is not empty
$DBNamesExcluded     = @('master','model','msdb','tempdb')

# storage paths - set paths corresponding to your needs, don't
# use trailing backslash
$BackupDirectoryPath = 'E:\DB\Dumps' # must be set
$LogDirectoryPath    = 'E:\DB\Logs'  # or use empty string for no output

# how long should be the database dumps left on hard drive
$global:RetentionDays       = 31     # or use 0 to store forever, but you will
                                     # eventually run out of disk space

function Logger{
  # not implemented (yet)
  (param [String]$Log)
  $LogDate = Get-Date -Format "yyyyMMddHHmmss"
  $CurrentLogOutput.Add($LogDate + ': ' + $Log)
}

function CleanUp {
  # deletes files older than $Days
  param(
    [String]$Path,
    [Int]$Days
  )
  # Logger -Log 'Removing files in ' + $Path + ' older than ' + $Days + ' days.'
  Write-Host Clean Up dir $Path
  if ($Days -gt 0)
  {
    Get-ChildItem $Path | `
      Where-Object {($_.LastWriteTime -lt (Get-Date).AddDays(-$Days))} | `
      Remove-Item
  }
}

function BackupToFile {
  # runs the dump functions
  param(
    [String]$DatabaseInstance,
    [String]$DatabaseName,
    [String]$WriteToPath
  )

  # filename
  $Date = DateTimeNow

  $WriteToPathFull = $WriteToPath + '\' + $Date + '_' + $DatabaseName + '.bkp'
  Write-Host '>>' Database $DatabaseName to $WriteToPathFull
  Backup-SqlDatabase -ServerInstance $DatabaseInstance -Database $DatabaseName -BackupFile $WriteToPathFull
}

# f returns datetime string
function DateTimeNow {
  $DateTimeThisMoment = Get-Date -Format 'yyyyMMdd-HHmmss'
  return $DateTimeThisMoment
}

# GO!

# do directories exist ?

if ((Test-Path -Path $BackupDirectoryPath) `
    -And (Test-Path -Path $LogDirectoryPath) `
    -And ($BackupDirectoryPath -ne $LogDirectoryPath) `
    )
{
  # clean directories
  CleanUp -Path $BackupDirectoryPath -Days $RetentionDays
  CleanUp -Path $LogDirectoryPath -Days $RetentionDays

  # get databases of instance
  $DBNamesInInstance = @(Invoke-Sqlcmd -ServerInstance $DatabaseInstance -Query "select name from sys.databases") | select-object -expand Name

  if ($DBNamesIncluded.Count -gt 0)
  {
    # do if included database list is not empty
    foreach ($DBNameIncluded in $DBNamesIncluded) {
      if ($DBNamesInInstance -contains $DBNameIncluded)
      {
        # call dbdump function
        Write-Host Dump database $DBNameIncluded to $BackupDirectoryPath
        BackupToFile -DatabaseInstance $DatabaseInstance -DatabaseName $DBNameIncluded -WriteToPath $BackupDirectoryPath
      } else
      {
        write-output 'Database does not exist.'
      }
      
    }
  } else
  {
    # dump all databases but ignore excluded
    foreach ($DBNameInInstance in $DBNamesInInstance)
    {
      if ($DBNamesExcluded -NotContains $DBNameInInstance)
      {
        # call dbdump function
        Write-Host Dump database $DBNameInInstance to $BackupDirectoryPath
        BackupToFile -DatabaseInstance $DatabaseInstance -DatabaseName $DBNameInInstance -WriteToPath $BackupDirectoryPath
      } else
      {
        Write-Host Ignored database - excluded: $DBNameInInstance
      }
    }
  }
} 
else
{
  Write-Output "Can t start backup. Check directory configuration."
  exit 0
}
