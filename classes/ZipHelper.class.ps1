using namespace System.IO
using namespace System.IO.Compression

class ZipHelper {
	# Returns file contents as a binary array
	static [byte[]] GetBinaryFile ([string]$fileName) {
		$stream = [System.IO.File]::Open($fileName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
		$b = [byte[]]::new($stream.Length)
		try { $stream.Read($b, 0, $b.Length) }
		catch {	throw $_ }
		finally { $stream.Close() }
		return $b
	}
	# Adds a new file entry into an opened ZipArchive object and fills it from the byte array
	static [void] WriteZipFile ([ZipArchive]$zipFile, [string]$fileName, [byte[]]$data) {
		#Remove old file entry if exists
		if ($zipFile.Mode -eq [ZipArchiveMode]::Update) {
			if ($oldEntry = $zipFile.GetEntry($fileName)) {
				$oldEntry.Delete()
			}
		}
		#Create new file entry
		$entry = $zipFile.CreateEntry($fileName)
		$writer = $entry.Open()
		#Write file contents
		$writer.Write($data, 0, $data.Length )
		#Close the stream
		$writer.Close()
	}
	static [psobject[]] GetArchiveItems ([string]$fileName) {
		$zip = [Zipfile]::OpenRead($FileName)
		try {
            $entries = $zip.Entries | Select-Object *
		}
		catch { throw $_ }
        finally { $zip.Dispose() }
		return $entries | Add-Member -MemberType ScriptProperty -Name Folder -Value { Split-Path $this.FullName} -PassThru
	}
	# Returns a specific entry from the archive file
	static [psobject[]] GetArchiveItem ([string]$fileName, [string[]]$itemName) {
		$zip = [Zipfile]::OpenRead($FileName)
		[psobject[]]$output = @()
		try {
			$entries = $zip.Entries | Where-Object { $_.FullName -in $itemName }
			foreach ($entry in $entries) {
				#Read deflate stream
				$stream = [ZipHelper]::ReadDeflateStream($entry.Open())
				try { $bin = $stream.ToArray() }
				catch { throw $_ }
				finally { $stream.Dispose()	}
				
				$output += $entry | Select-Object * | Add-Member -MemberType NoteProperty -Name ByteArray -Value $bin -PassThru
			}
		}
		catch { throw $_ }
		finally { $zip.Dispose() }
		return $output
	}
    static [void] SaveArchiveItem ([string]$fileName, [string]$itemName, [string]$saveTo) {
        $zip = [Zipfile]::OpenRead($fileName)
        try {
            $entry = $zip.Entries | Where-Object { $_.FullName -in $itemName }
            #Open file stream to write
            $writeStream = [System.IO.File]::Create($saveTo)
            #Copy deflate stream to the write stream
			$zipStream = $entry.Open()
            try {
                $zipStream.CopyTo($writeStream)
            }
            catch { throw $_ }
            finally { 
                $zipStream.Close()
                $zipStream.Dispose()
				$writeStream.Close()
                $writeStream.Dispose()
			}
        }
        catch { throw $_ }
        finally { $zip.Dispose() }
	}
	static [string] DecodeBinaryText ([byte[]]$Array) {
		$skipBytes = 0
		# null
        if ($Array.Length -eq 0) {
            return [NullString]::Value
        }
		# EF BB BF (UTF8)
        if ($Array.Length -ge 3 -and $Array[0] -eq 0xef -and $Array[1] -eq 0xbb -and $Array[2] -eq 0xbf) {
            $encoding = [System.Text.Encoding]::UTF8
            $skipBytes = 3
        }
        # 00 00 FE FF (UTF32 Big-Endian)
        elseif ($Array.Length -ge 4 -and $Array[0] -eq 0 -and $Array[1] -eq 0 -and $Array[2] -eq 0xfe -and $Array[3] -eq 0xff) {
            $encoding = [System.Text.Encoding]::UTF32
            $skipBytes = 4
        }
        # FF FE 00 00 (UTF32 Little-Endian)
        elseif ($Array.Length -ge 4 -and $Array[0] -eq 0xff -and $Array[1] -eq 0xfe -and $Array[2] -eq 0 -and $Array[3] -eq 0) {
            $encoding = [System.Text.Encoding]::UTF32
            $skipBytes = 4
        }
        # FE FF  (UTF-16 Big-Endian)
        elseif ($Array.Length -ge 2 -and $Array[0] -eq 0xfe -and $Array[1] -eq 0xff) {
            $encoding = [System.Text.Encoding]::BigEndianUnicode
            $skipBytes = 2
        }
        # FF FE  (UTF-16 Little-Endian)
        elseif ($Array.Length -ge 2 -and $Array[0] -eq 0xff -and $Array[1] -eq 0xfe) {
            $encoding = [System.Text.Encoding]::Unicode
            $skipBytes = 2
        }
        elseif ($Array.Length -ge 4 -and $Array[0] -eq 0x2b -and $Array[1] -eq 0x2f -and $Array[2] -eq 0x76 -and ($Array[3] -eq 0x38 -or $Array[3] -eq 0x39 -or $Array[3] -eq 0x2b -or $Array[3] -eq 0x2f)) {
            $encoding = [System.Text.Encoding]::UTF7
        }
        else {
            $encoding = [System.Text.Encoding]::ASCII
        }
        return $encoding.GetString($Array, $skipBytes, $Array.Length - $skipBytes)
	}
	static [System.IO.MemoryStream] ReadDeflateStream ([Stream]$stream) {
		$memStream = [System.IO.MemoryStream]::new()
		$stream.CopyTo($memStream)
		$stream.Close()
		return $memStream
	}
}