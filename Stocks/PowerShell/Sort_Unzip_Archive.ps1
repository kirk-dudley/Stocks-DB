$StartDir = "D:\Stock_Data\EODData\EODData_Historic_Zip"
$HasOpenInt = "D:\Stock_Data\EODData\EODData_Historic_Extracted\HasOpenInt"
$NoOpenInt = "D:\Stock_Data\EODData\EODData_Historic_Extracted\NoOpenInt"
$archivedir = "D:\Stock_Data\Archived\EODData\Historic Zip"
$archivefile = ""
$movedir = ""
$files = Get-ChildItem $StartDir -Filter "*.zip"

#Write-Output $HasOpenInt
#Write-Output $NoOpenInt


#if the target directories don't exist, creates them, else clears out existing files
if (Test-Path -Path $HasOpenInt) {
        $removedir = $HasOpenInt + '\*.*'
        Remove-Item $removedir 
} else {
    New-Item -Path $HasOpenInt -ItemType Directory -Force
}

if (Test-Path -Path $NoOpenInt) {
        $removedir = $NoOpenInt + '\*.*'
        Remove-Item $removedir 
} else {
    New-Item -Path $NoOpenInt -ItemType Directory -Force
}

#Write-Output $HasOpenInt
#Write-Output $NoOpenInt


FOREACH ($f IN $files){
    SWITCH -WILDCARD ($F.Name) {
#Files without the openint column
        "ASX*.ZIP" {$movedir = $NoOpenInt}
        "FOREX*.ZIP" {$movedir = $NoOpenInt}
        "INDEX*.ZIP" {$movedir = $NoOpenInt}
        "LSE*.ZIP" {$movedir = $NoOpenInt}
        "NASDAQ*.ZIP" {$movedir = $NoOpenInt}
        "NYSE*.ZIP" {$movedir = $NoOpenInt}
        "OTCBB*.ZIP" {$movedir = $NoOpenInt}
        "SGX*.ZIP" {$movedir = $NoOpenInt}
        "TSX*.ZIP" {$movedir = $NoOpenInt}
        "TSXV*.ZIP" {$movedir = $NoOpenInt}
        "USMF*.ZIP" {$movedir = $NoOpenInt}

#Files with the openint column

        "CFE*.ZIP" {$movedir = $HasOpenInt}
        "EUREX*.ZIP" {$movedir = $HasOpenInt}
        "LIFFE*.ZIP" {$movedir = $HasOpenInt}
        "MGEX*.ZIP" {$movedir = $HasOpenInt}
        "NYBOT*.ZIP" {$movedir = $HasOpenInt}
        "WCE*.ZIP" {$movedir = $HasOpenInt}


#if the file isn"t in either list, $movedir will be set to an empty string to avoid attempting to unzip undefined files
        default {$movedir = ""}
        }

#updates #movedir to include the archive subfolder, ignoring files without a valid target directory. 
#This is soley to make tracking down problematic files easier, all archives could be in one folder
 
    IF ($movedir -ne "") {$movedir = $movedir + "\" + $f.Name -replace ".zip", ""
                          $archivefile = $archivedir + "\" + $f.Name 
                        }

#unzips to the target folder, ignoring files without a valid target directory
    IF ($movedir -ne "") {expand-archive -force -path $f.FullName -destinationpath $movedir
                          Move-Item -Path $f.fullname -destination $archivefile -Force
                          }
}   
