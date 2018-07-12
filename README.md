# psziphelper
## about
A small Powershell module that helps to manage zip file contents:
- Add items to the archive
- Unarchive individual files from the archive
- Get archived file details: name, size and contents as a binary property (warning: this is memory intensive, as all the contents are stored inside the property)
- Remove specific files from the archive

## Examples

```powershell
# Put two txt files into archive.zip\inner_folder\path\
Add-ArchiveItem -Path c:\temp\myarchive.zip -Item MyFile.txt, Myfile2.txt -InnerFolder inner_folder\path

# Extract two files from the archive
Expand-ArchiveItem -Path c:\temp\myarchive.zip -DestinationPath c:\MyFolder -Item MyFile.txt, Myfile2.txt

# Return an archive file with binary contents
Get-ArchiveItem -Path .\asd.zip -Item asd\file1.txt

# Remove two files from the archive
Remove-ArchiveItem -Path c:\temp\myarchive.zip -Item MyFile.txt, Myfile2.txt
```

	