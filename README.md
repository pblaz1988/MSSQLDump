# MSSQLDump
Powershell script to dump selected MSSQL databases to local hard drive

PREREQUISITES:
* MSSQL POWERSHELL MODULE!
* SCRIPT IS TO BE RAN ON THE SAME SERVER AS MSSQL

This script exports all or just selected databases on Microsoft SQL Server,
pack them into tarball archive and upload the archive to the SMB network
location (Windows Share).
Another functionalities are:
- mounting the network location it the mountpoint is not persistent
- cleaning up old files (how long backups should be stored - set the number
  of days in variable)

It should not be hard to modify the script to suit your needs (upload just on
hdd, upload to NFS share etc.
