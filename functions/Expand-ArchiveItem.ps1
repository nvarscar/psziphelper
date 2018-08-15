Function Expand-ArchiveItem {
    <#
	.SYNOPSIS
	Extracts one or more items from the archive
	
	.DESCRIPTION
	Extract specific file or folder from the existing archive
	
	.PARAMETER Path
	Archive path
	
	.PARAMETER DestinationPath
	Destination folder to put the item into
	
	.PARAMETER Item
	Archived item: file or folder
	
	.PARAMETER PassThru
	If specified, returns the unpacked item object

	.PARAMETER Force
	Overwrites existing file(s)

	.PARAMETER Relative
	Extract with relative paths based on the specified item path

	.PARAMETER IgnoreFolders
	Extract all files to the same folder regardless of the paths inside the archive
	
	.EXAMPLE
	Expand-ArchiveItem -Path c:\temp\myarchive.zip -DestinationPath c:\MyFolder -Item MyFile.txt, Myfile2.txt
	
	.NOTES
	General notes
	#>
    [CmdletBinding(SupportsShouldProcess = $true)]
    Param(
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            Position = 1)]
        [string]$Path,
        [Parameter(Mandatory = $true,
            Position = 2)]
        [string]$DestinationPath,
        [Parameter(Mandatory = $true,
            Position = 3)]
        [string[]]$Item,
        [switch]$PassThru,
        [switch]$Force,
        [switch]$Relative,
        [switch]$IgnoreFolders
    )
    begin {
    }
    process {
        $archive = Get-ArchiveItem -Path $Path 
        foreach ($currentItem in $Item) {
            #check if it's a folder
            if ($archive | Where-Object { $_.Folder -eq $currentItem -or $_.Folder -like (Join-Path $currentItem *) }) {
                $currentZipEntries = $archive | Where-Object Path -like (Join-Path $currentItem *)
            }
            else {
                $currentZipEntries = $archive | Where-Object Path -like $currentItem
            }
            if ($Relative) {
                $rootFolder = Split-Path $currentItem -Parent
            }
            if (!$currentZipEntries) {
                Write-Warning -Message "Item $currentItem was not found in $Path"
            }
            foreach ($currentZipItem in $currentZipEntries) {
                # get archive item
                if ($IgnoreFolders) {
                    $itemPath = Split-Path $currentZipItem.Path -Leaf
                }
                elseif ($Relative) {
                    $itemPath = $currentZipItem.Path -replace ("^" + [Regex]::Escape($rootFolder)), ''
                }
                else {
                    $itemPath = $currentZipItem.Path
                }
                # check if item exists
                if (Test-Path $DestinationPath) {
                    $destItem = Get-Item $DestinationPath
                    if ($destItem.PSIsContainer) {
                        $destFolder = $destItem.FullName
                        $itemDestPath = Join-Path $destItem.FullName $itemPath
                    }
                    else {
                        $itemDestPath = $DestinationPath
                    }
                }
                else {
                    $itemDestPath = Join-Path $DestinationPath $itemPath
                }
                
                if ($Force -eq $false -and (Test-Path $itemDestPath)) {
                    Write-Warning -Message "Destination item $itemDestPath already exists. No action performed. Use -Force to overwrite."
                    continue
                }
				
                # create parent directory
                $parent = Split-Path $itemDestPath -Parent
                if (!(Test-Path $parent)) {
                    if ($pscmdlet.ShouldProcess($parent, "Creating parent directory")) {
                        $null = New-Item -Path $parent -ItemType Directory -Force
                    }
                }

                if ($pscmdlet.ShouldProcess($currentZipItem.Path, "Extract archive item to $itemDestPath")) {
                    [ZipHelper]::SaveArchiveItem($Path, $currentZipItem.Path, $itemDestPath)
                }

                # return item object
                if ($PassThru) {
                    Get-Item $itemDestPath
                }
            }
        }
    }
    end {

    }
}